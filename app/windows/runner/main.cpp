#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <shellapi.h>

#include <algorithm>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Files on the command line, as Explorer's "Convert with Arcvert" passes them: everything that isn't
// a switch such as --hidden.
std::vector<std::wstring> FilesToOpen() {
  std::vector<std::wstring> files;
  int count = 0;
  wchar_t** arguments = ::CommandLineToArgvW(::GetCommandLineW(), &count);
  if (arguments == nullptr) return files;
  for (int i = 1; i < count; i++) {
    std::wstring argument = arguments[i];
    if (!argument.empty() && argument.rfind(L"--", 0) != 0) files.push_back(argument);
  }
  ::LocalFree(arguments);
  return files;
}

// Hands |files| to the copy already running, which opens them together with any others sent close
// by, as Explorer starts a copy for each file chosen.
void SendFilesToOpen(HWND window, const std::vector<std::wstring>& files) {
  std::wstring joined;
  for (const auto& file : files) {
    joined += file;
    joined.push_back(L'\0');
  }
  COPYDATASTRUCT data = {};
  data.dwData = kOpenFilesData;
  data.cbData = static_cast<DWORD>(joined.size() * sizeof(wchar_t));
  data.lpData = joined.data();
  // This copy was started by the user, so it may hand the other one the right to come forward.
  DWORD process = 0;
  ::GetWindowThreadProcessId(window, &process);
  ::AllowSetForegroundWindow(process);
  ::SendMessageW(window, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&data));
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Closing the window only hides it, so opening the app again usually means bringing it back. A
  // second copy would also show a second Shift-drag menu.
  // Read first: anything between making the mutex and GetLastError would hide that it already existed.
  const std::vector<std::wstring> files = FilesToOpen();
  HANDLE running = ::CreateMutexW(nullptr, TRUE, L"Arcvert.SingleInstance");
  if (running != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND window = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Arcvert");
    // The first of several copies Explorer starts may still be making its window.
    for (int tries = 0; window == nullptr && !files.empty() && tries < 50; tries++) {
      ::Sleep(100);
      window = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Arcvert");
    }
    if (window != nullptr && !files.empty()) {
      SendFilesToOpen(window, files);
    } else if (window != nullptr) {
      ::ShowWindow(window, SW_RESTORE);
      ::SetForegroundWindow(window);
    }
    ::CloseHandle(running);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  // Signing in opens the app with this, to wait in the notification area for a Shift-drag.
  const bool hidden = std::find(command_line_arguments.begin(), command_line_arguments.end(),
                                "--hidden") != command_line_arguments.end();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, hidden && files.empty(), files);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Arcvert", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
