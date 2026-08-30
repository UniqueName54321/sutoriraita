import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    FlutterMethodChannel(name: "sutoriraita/documents",
      binaryMessenger: flutterViewController.engine.binaryMessenger).setMethodCallHandler { call, result in
        guard call.method == "nextDocument" else { result(FlutterMethodNotImplemented); return }
        DocumentInbox.next(result)
      }

    super.awakeFromNib()
  }
}
