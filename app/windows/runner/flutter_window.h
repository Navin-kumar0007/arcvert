#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

// clang-format off
#include <windows.h>
#include <shellapi.h>
// clang-format on

#include <memory>
#include <string>
#include <vector>

#include "shift_drag.h"
#include "win32_window.h"

// Marks a WM_COPYDATA from a second copy of the app as files to open: its paths, each ended by a
// zero, in UTF-16. Explorer's "Convert with Arcvert" starts a copy for each file chosen.
constexpr ULONG_PTR kOpenFilesData = 0x41524356;  // "ARCV"

// A window hosting a Flutter view. Closing it only hides it, leaving an icon in the notification
// area, as the Shift-drag menu needs the app running. The icon's menu is how to quit.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  // With |start_hidden|, the window stays out of sight until opened from the notification area.
  // |open_files| are paths the app was started with, to open once Dart listens.
  FlutterWindow(const flutter::DartProject& project, bool start_hidden = false,
                std::vector<std::wstring> open_files = {});
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // The system-wide Shift-drag menu.
  std::unique_ptr<ShiftDrag> shift_drag_;

  // Files to open, from the command line or a second copy, held until Dart listens. Several copies
  // arrive close together, so they wait a moment and open as one set.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> open_channel_;
  std::vector<std::string> files_to_open_;
  bool open_listening_ = false;
  void AddFilesToOpen(const wchar_t* paths, size_t length);
  void SendFilesToOpen();

  void AddTrayIcon();
  void RemoveTrayIcon();
  void HideToTray();
  void ShowFromTray();
  void ShowTrayMenu();

  NOTIFYICONDATAW tray_ = {};
  bool tray_added_ = false;
  // Said once, so nobody thinks closing the window stopped the app, or that it has crashed.
  bool told_about_tray_ = false;
  bool start_hidden_ = false;
  // Sent when Explorer restarts, which forgets every icon.
  UINT taskbar_created_ = 0;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
