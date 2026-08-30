import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ app: UIApplication, open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    DocumentInbox.add(url)
    return true
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FlutterMethodChannel(name: "sutoriraita/documents",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()).setMethodCallHandler { call, result in
        guard call.method == "nextDocument" else { result(FlutterMethodNotImplemented); return }
        DocumentInbox.next(result)
      }
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
