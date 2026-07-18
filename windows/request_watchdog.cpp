#include "request_watchdog.h"

#include <map>

namespace webcontent_converter {

namespace {

// Multiple RequestWatchdogs could in principle be armed at once (today they
// aren't, since the plugin only ever runs one request at a time -- see
// WebcontentConverterPlugin::request_in_flight_ -- but this class is meant
// to be a general-purpose reusable utility, not tied to that assumption).
std::map<UINT_PTR, RequestWatchdog*>& WatchdogRegistry() {
  static std::map<UINT_PTR, RequestWatchdog*> registry;
  return registry;
}

}  // namespace

RequestWatchdog::~RequestWatchdog() { Disarm(); }

void RequestWatchdog::Arm(UINT timeout_ms, std::function<void()> on_timeout) {
  Disarm();
  on_timeout_ = std::move(on_timeout);
  timer_id_ = ::SetTimer(nullptr, 0, timeout_ms, TimerProc);
  WatchdogRegistry()[timer_id_] = this;
}

void RequestWatchdog::Disarm() {
  if (timer_id_ != 0) {
    ::KillTimer(nullptr, timer_id_);
    WatchdogRegistry().erase(timer_id_);
    timer_id_ = 0;
  }
  on_timeout_ = nullptr;
}

void CALLBACK RequestWatchdog::TimerProc(HWND, UINT, UINT_PTR id, DWORD) {
  auto& registry = WatchdogRegistry();
  auto it = registry.find(id);
  if (it == registry.end()) return;
  RequestWatchdog* watchdog = it->second;
  registry.erase(it);
  ::KillTimer(nullptr, id);
  watchdog->OnTimeout();
}

void RequestWatchdog::OnTimeout() {
  timer_id_ = 0;  // Already killed by TimerProc.
  auto callback = std::move(on_timeout_);
  on_timeout_ = nullptr;
  if (callback) callback();
}

}  // namespace webcontent_converter
