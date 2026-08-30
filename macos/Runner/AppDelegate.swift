import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls { DocumentInbox.add(url) }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

// Keep the security scope alive until Dart consumes the launch document.
enum DocumentInbox {
  static var urls: [(URL, Bool)] = []
  static func add(_ url: URL) {
    urls.append((url, url.startAccessingSecurityScopedResource()))
  }
  static func next(_ result: FlutterResult) {
    guard !urls.isEmpty else { result(nil); return }
    let (url, scoped) = urls.removeFirst()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    do {
      let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      guard size <= 128 * 1024 * 1024 else {
        result(FlutterError(code: "document", message: "Project exceeds 128 MiB", details: nil)); return
      }
      result(FlutterStandardTypedData(bytes: try Data(contentsOf: url)))
    } catch {
      result(FlutterError(code: "document", message: error.localizedDescription, details: nil))
    }
  }
}
