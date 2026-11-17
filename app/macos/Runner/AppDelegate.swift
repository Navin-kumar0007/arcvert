import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Shift-drag only works while the app runs, so closing the window leaves it running. Cmd+Q quits.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag { sender.windows.first?.makeKeyAndOrderFront(nil) }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // Open With in Finder, or files dropped on the Dock icon. Arcvert is never anything's default app
  // (`LSHandlerRank` Alternate), so this is only when someone chose it.
  func application(_ application: NSApplication, open urls: [URL]) {
    OpenedFiles.shared.add(urls.filter(\.isFileURL).map(\.path))
  }
}

/// Files to open from outside the app: Open With, the Dock icon, or the Convert with Arcvert service
/// in Finder's right-click menu. Held until Dart listens, as a launch to open files comes before it
/// starts. `shared_files_native.dart` on the other side opens them as if dropped on the window.
final class OpenedFiles: NSObject {
  static let shared = OpenedFiles()

  private var channel: FlutterMethodChannel?
  private var listening = false
  private var waiting: [String] = []
  var showWindow: () -> Void = {}

  func connect(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "radial/open", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "listen" {
        self?.listening = true
        self?.send()
      }
      result(nil)
    }
    self.channel = channel
  }

  func add(_ paths: [String]) {
    guard !paths.isEmpty else { return }
    waiting.append(contentsOf: paths)
    NSApp.activate(ignoringOtherApps: true)
    showWindow()
    send()
  }

  private func send() {
    guard listening, !waiting.isEmpty, let channel else { return }
    let paths = waiting
    waiting = []
    channel.invokeMethod("open", arguments: ["paths": paths])
  }

  /// The service's message, named in Info.plist's `NSServices`.
  @objc func convertWithArcvert(
    _ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>
  ) {
    let urls =
      pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
      as? [URL] ?? []
    add(urls.map(\.path))
  }
}
