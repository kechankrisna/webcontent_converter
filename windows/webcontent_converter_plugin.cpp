#include "webcontent_converter_plugin.h"

#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <shellapi.h>
#include <shlwapi.h>

#include <sstream>

namespace webcontent_converter {

namespace {

// Purely a sanity/memory-exhaustion guard -- WebView2Session loads content
// via a temp file rather than NavigateToString specifically so there's no
// WebView2-imposed size ceiling to track here (NavigateToString hard-fails
// past ~2MB, which real-world HTML with embedded images/fonts hits easily).
const size_t kMaxContentSizeBytes = 100 * 1024 * 1024;

// PDF and image requests share one busy slot (see request_in_flight_), so a
// caller firing several conversions without awaiting each one queues rather
// than immediately failing with TOO_MANY_REQUESTS. This just bounds how far
// that queue is allowed to grow -- a generous number of legitimate queued
// conversions, not a concurrency limit.
const size_t kMaxQueuedRequests = 32;

using flutter::EncodableMap;
using flutter::EncodableValue;

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  int size = ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                    static_cast<int>(utf8.size()), nullptr, 0);
  std::wstring result(size, L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                         result.data(), size);
  return result;
}

const EncodableMap* GetMap(const EncodableMap& args, const char* key) {
  auto it = args.find(EncodableValue(key));
  if (it == args.end()) return nullptr;
  return std::get_if<EncodableMap>(&it->second);
}

std::optional<std::string> GetString(const EncodableMap& args,
                                      const char* key) {
  auto it = args.find(EncodableValue(key));
  if (it == args.end()) return std::nullopt;
  if (auto* value = std::get_if<std::string>(&it->second)) return *value;
  return std::nullopt;
}

double GetDouble(const EncodableMap& map, const char* key, double fallback) {
  auto it = map.find(EncodableValue(key));
  if (it == map.end()) return fallback;
  if (auto* value = std::get_if<double>(&it->second)) return *value;
  if (auto* value = std::get_if<int32_t>(&it->second))
    return static_cast<double>(*value);
  if (auto* value = std::get_if<int64_t>(&it->second))
    return static_cast<double>(*value);
  return fallback;
}

}  // namespace

// static
void WebcontentConverterPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      registrar->messenger(), "webcontent_converter",
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<WebcontentConverterPlugin>(registrar);
  auto* plugin_pointer = plugin.get();

  channel->SetMethodCallHandler(
      [plugin_pointer](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

WebcontentConverterPlugin::WebcontentConverterPlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {
  // Clean up old temp folders on startup
  CleanupOldTempFolders();
}

WebcontentConverterPlugin::~WebcontentConverterPlugin() {
  // Destructor is intentionally minimal - all cleanup is automatic:
  // - active_pdf_request_/active_image_request_ unique_ptr destructors (if
  //   a request is somehow still outstanding) run first as declaration
  //   order requires, then session_'s destructor releases all WebView2 COM
  //   objects via ~WebView2Session -> ComPtr::Reset().
  // No manual cleanup needed - modern C++ RAII handles everything.
}

WebView2Session* WebcontentConverterPlugin::EnsureSession(
    HWND parent_window) {
  if (!session_) {
    session_ = std::make_unique<WebView2Session>(parent_window);
  }
  return session_.get();
}

bool WebcontentConverterPlugin::IsQueueFull() const {
  return pending_jobs_.size() >= kMaxQueuedRequests;
}

void WebcontentConverterPlugin::StartOrQueue(std::function<void()> job) {
  if (request_in_flight_) {
    pending_jobs_.push_back(std::move(job));
    return;
  }
  request_in_flight_ = true;
  job();
}

void WebcontentConverterPlugin::OnRequestFinished() {
  request_in_flight_ = false;
  if (pending_jobs_.empty()) return;

  auto next_job = std::move(pending_jobs_.front());
  pending_jobs_.pop_front();
  request_in_flight_ = true;
  next_job();
}

void WebcontentConverterPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const auto& method_name = method_call.method_name();

  if (method_name.compare("getPlatformVersion") == 0) {
    result->Success(EncodableValue(std::string("Windows")));
    return;
  }

  const auto* args = std::get_if<EncodableMap>(method_call.arguments());
  if (!args) {
    result->Error("INVALID_ARGUMENT", "Arguments must be a map");
    return;
  }

  if (method_name.compare("contentToPDF") == 0) {
    HandleContentToPdf(*args, std::move(result));
    return;
  }

  if (method_name.compare("contentToImage") == 0) {
    HandleContentToImage(*args, std::move(result));
    return;
  }

  result->NotImplemented();
}

void WebcontentConverterPlugin::HandleContentToPdf(
    const EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  auto content = GetString(args, "content");
  auto saved_path = GetString(args, "savedPath");
  if (!content || !saved_path) {
    result->Error("INVALID_ARGUMENT", "content and savedPath are required");
    return;
  }

  // Validate content size to prevent memory exhaustion
  if (content->size() > kMaxContentSizeBytes) {
    result->Error("CONTENT_TOO_LARGE",
                   "Content exceeds maximum size of 100MB");
    return;
  }

  // Backstop against unbounded growth if a caller is stuck firing requests
  // in a loop -- see StartOrQueue for why a busy session doesn't reject
  // outright.
  if (request_in_flight_ && IsQueueFull()) {
    result->Error("TOO_MANY_REQUESTS",
                   "Too many queued conversions (limit: " +
                       std::to_string(kMaxQueuedRequests) +
                       "). Please wait for earlier ones to complete.");
    return;
  }

  const EncodableMap* format = GetMap(args, "format");
  const EncodableMap* margins = GetMap(args, "margins");

  PdfConversionRequest::PageSettings settings{};
  // Defaults match PaperFormat.a4 / PdfMargins.zero on the Dart side.
  settings.page_width_in = format ? GetDouble(*format, "width", 8.27) : 8.27;
  settings.page_height_in =
      format ? GetDouble(*format, "height", 11.7) : 11.7;
  settings.margin_top_in = margins ? GetDouble(*margins, "top", 0.0) : 0.0;
  settings.margin_bottom_in =
      margins ? GetDouble(*margins, "bottom", 0.0) : 0.0;
  settings.margin_left_in = margins ? GetDouble(*margins, "left", 0.0) : 0.0;
  settings.margin_right_in =
      margins ? GetDouble(*margins, "right", 0.0) : 0.0;

  double duration_ms = GetDouble(args, "duration", 0.0);

  // The MethodResult must outlive HandleContentToPdf -- it's fulfilled
  // asynchronously, possibly after sitting in the queue for a while -- so
  // it's released into the job/completion callback below and rewrapped
  // there.
  auto* raw_result = result.release();

  StartOrQueue([this, content_wide = Utf8ToWide(*content),
                saved_path_wide = Utf8ToWide(*saved_path), duration_ms,
                settings, raw_result]() {
    HWND parent_window = registrar_->GetView()->GetNativeWindow();
    WebView2Session* session = EnsureSession(parent_window);

    active_pdf_request_ = std::make_unique<PdfConversionRequest>(
        session, content_wide, saved_path_wide, duration_ms, settings,
        [this, raw_result](PdfConversionRequest* self,
                            std::optional<std::string> saved_path_result,
                            std::optional<std::string> error) {
          // CRITICAL: Free the busy slot (and start the next queued job, if
          // any) BEFORE sending the result to Flutter, so a subsequent
          // request from Flutter can't race this one.
          if (active_pdf_request_.get() == self) {
            active_pdf_request_.reset();
          }
          OnRequestFinished();

          std::unique_ptr<flutter::MethodResult<EncodableValue>> owned_result(
              raw_result);
          if (saved_path_result) {
            owned_result->Success(EncodableValue(*saved_path_result));
          } else {
            owned_result->Error("CONTENT_TO_PDF_FAILED",
                                 error.value_or("Unknown error"));
          }
        });

    active_pdf_request_->Start();
  });
}

void WebcontentConverterPlugin::HandleContentToImage(
    const EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  auto content = GetString(args, "content");
  if (!content) {
    result->Error("INVALID_ARGUMENT", "content is required");
    return;
  }

  // Validate content size to prevent memory exhaustion
  if (content->size() > kMaxContentSizeBytes) {
    result->Error("CONTENT_TOO_LARGE",
                   "Content exceeds maximum size of 100MB");
    return;
  }

  // Backstop against unbounded growth if a caller is stuck firing requests
  // in a loop -- see StartOrQueue for why a busy session doesn't reject
  // outright.
  if (request_in_flight_ && IsQueueFull()) {
    result->Error("TOO_MANY_REQUESTS",
                   "Too many queued conversions (limit: " +
                       std::to_string(kMaxQueuedRequests) +
                       "). Please wait for earlier ones to complete.");
    return;
  }

  double duration_ms = GetDouble(args, "duration", 0.0);

  // The MethodResult must outlive HandleContentToImage -- it's fulfilled
  // asynchronously, possibly after sitting in the queue for a while -- so
  // it's released into the job/completion callback below and rewrapped
  // there.
  auto* raw_result = result.release();

  StartOrQueue([this, content_wide = Utf8ToWide(*content), duration_ms,
                raw_result]() {
    HWND parent_window = registrar_->GetView()->GetNativeWindow();
    WebView2Session* session = EnsureSession(parent_window);

    active_image_request_ = std::make_unique<ImageCaptureRequest>(
        session, content_wide, duration_ms,
        [this, raw_result](ImageCaptureRequest* self,
                            std::optional<std::vector<uint8_t>> image_bytes,
                            std::optional<std::string> error) {
          // Move data out BEFORE destroying the request to ensure data
          // safety
          std::vector<uint8_t> moved_bytes;
          bool has_bytes = false;
          if (image_bytes) {
            moved_bytes = std::move(*image_bytes);
            has_bytes = true;
          }

          // CRITICAL: Free the busy slot (and start the next queued job, if
          // any) BEFORE sending the result to Flutter, so a subsequent
          // request from Flutter can't race this one.
          if (active_image_request_.get() == self) {
            active_image_request_.reset();
          }
          OnRequestFinished();

          std::unique_ptr<flutter::MethodResult<EncodableValue>> owned_result(
              raw_result);
          if (has_bytes) {
            owned_result->Success(EncodableValue(std::move(moved_bytes)));
          } else {
            owned_result->Error("CONTENT_TO_IMAGE_FAILED",
                                 error.value_or("Unknown error"));
          }
        });

    active_image_request_->Start();
  });
}

void WebcontentConverterPlugin::CleanupOldTempFolders() {
  wchar_t temp_path[MAX_PATH];
  if (!::GetTempPathW(MAX_PATH, temp_path)) {
    return;
  }

  std::wstring search_pattern = std::wstring(temp_path) + L"webcontent_converter_*";
  WIN32_FIND_DATAW find_data;
  HANDLE find_handle = ::FindFirstFileW(search_pattern.c_str(), &find_data);
  
  if (find_handle == INVALID_HANDLE_VALUE) {
    return;
  }

  // Get current time for age comparison (24 hours = 86400 seconds)
  FILETIME current_time;
  ::GetSystemTimeAsFileTime(&current_time);
  ULARGE_INTEGER current_time_uli;
  current_time_uli.LowPart = current_time.dwLowDateTime;
  current_time_uli.HighPart = current_time.dwHighDateTime;

  do {
    // Only process directories, skip files
    if (!(find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) {
      continue;
    }
    
    // Skip "." and ".." directories
    if (wcscmp(find_data.cFileName, L".") == 0 || 
        wcscmp(find_data.cFileName, L"..") == 0) {
      continue;
    }

    // Calculate folder age based on creation time
    ULARGE_INTEGER create_time_uli;
    create_time_uli.LowPart = find_data.ftCreationTime.dwLowDateTime;
    create_time_uli.HighPart = find_data.ftCreationTime.dwHighDateTime;

    // Convert 100-nanosecond intervals to seconds
    ULONGLONG age_seconds = (current_time_uli.QuadPart - create_time_uli.QuadPart) / 10000000ULL;
    
    // Delete folders older than 24 hours
    if (age_seconds > 86400) {
      std::wstring folder_path = std::wstring(temp_path) + find_data.cFileName;
      
      // Try to delete the folder
      // SHFileOperation requires double-null terminated string
      std::vector<wchar_t> path_buffer(folder_path.begin(), folder_path.end());
      path_buffer.push_back(L'\0');  // First null terminator
      path_buffer.push_back(L'\0');  // Second null terminator for SHFileOperation
      
      SHFILEOPSTRUCTW file_op = {};
      file_op.wFunc = FO_DELETE;
      file_op.pFrom = path_buffer.data();
      file_op.fFlags = FOF_NO_UI | FOF_NOCONFIRMATION | FOF_SILENT | FOF_NOERRORUI;
      
      // Ignore errors - folder might be in use or locked by WebView2
      ::SHFileOperationW(&file_op);
    }
  } while (::FindNextFileW(find_handle, &find_data));

  ::FindClose(find_handle);
}

}  // namespace webcontent_converter
