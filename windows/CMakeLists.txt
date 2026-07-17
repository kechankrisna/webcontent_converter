# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "webcontent_converter")
project(${PROJECT_NAME} LANGUAGES CXX)

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "webcontent_converter_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "webcontent_converter_plugin.cpp"
  "webcontent_converter_plugin.h"
  "webview2_session.cpp"
  "webview2_session.h"
  "pdf_conversion_request.cpp"
  "pdf_conversion_request.h"
  "image_capture_request.cpp"
  "image_capture_request.h"
  "request_watchdog.cpp"
  "request_watchdog.h"
  "png_encoder.cpp"
  "png_encoder.h"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/webcontent_converter/webcontent_converter_plugin_c_api.h"
  "webcontent_converter_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

# Vendored WebView2 SDK: headers + a statically-linked loader so consumers of
# this plugin don't need to ship WebView2Loader.dll alongside their app (the
# WebView2 Runtime itself is still required on the target machine, but that
# ships with Windows 11 / recent Windows 10 via Edge).
if(CMAKE_VS_PLATFORM_NAME STREQUAL "ARM64")
  set(WEBVIEW2_ARCH "arm64")
elseif(CMAKE_SIZEOF_VOID_P EQUAL 8)
  set(WEBVIEW2_ARCH "x64")
else()
  set(WEBVIEW2_ARCH "x86")
endif()

target_include_directories(${PLUGIN_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/third_party/webview2/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/third_party/webview2/${WEBVIEW2_ARCH}/WebView2LoaderStatic.lib")

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)
# Ole32 provides CoTaskMemAlloc/Free (used by the vendored
# CoreWebView2EnvironmentOptions template) and CreateStreamOnHGlobal (used to
# encode the PrintWindow-captured bitmap in memory); Gdiplus does that PNG
# encoding for contentToImage.
target_link_libraries(${PLUGIN_NAME} PRIVATE "Shlwapi.lib" "Ole32.lib" "Gdiplus.lib" "Crypt32.lib")

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file. The WebView2 loader is
# statically linked above, so nothing needs to be bundled at runtime.
set(webcontent_converter_bundled_libraries
  ""
  PARENT_SCOPE
)
