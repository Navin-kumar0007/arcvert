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
  override func application(_ application: NSApplication, open urls: [URL]) {
    OpenedFiles.shared.add(urls.filter(\.isFileURL).map(\.path))
    // Anything else, such as a link, goes on to plugins as before.
    let others = urls.filter { !$0.isFileURL }
    if !others.isEmpty { super.application(application, open: others) }
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
  /// Shows the Shift-drag menu at the cursor for these files, saying whether it could.
  var showMenu: ([String], @escaping (Bool) -> Void) -> Void = { _, done in done(false) }

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
    showWindow()
    NSApp.activate(ignoringOtherApps: true)
    send()
  }

  private func send() {
    guard listening, !waiting.isEmpty, let channel else { return }
    let paths = waiting
    waiting = []
    channel.invokeMethod("open", arguments: ["paths": paths])
  }

  /// The service's message, named in Info.plist's `NSServices`: the menu at the cursor, over Finder,
  /// as a Shift-drag shows it, and the result saved beside the original.
  @objc func convertWithArcvert(
    _ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>
  ) {
    let urls =
      pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
      as? [URL] ?? []
    menu(for: urls.map(\.path), tries: 20)
  }

  /// Started by the service, the app's Dart side takes a moment to answer, so it's asked again. Once
  /// it has answered with nothing, or never does, the files open in the window instead, which says
  /// why nothing can be made.
  private func menu(for paths: [String], tries: Int) {
    guard !paths.isEmpty else { return }
    showMenu(paths) { [weak self] shown in
      guard let self = self, !shown else { return }
      if tries > 0, !self.listening {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
          self.menu(for: paths, tries: tries - 1)
        }
      } else {
        self.add(paths)
      }
    }
  }
}
