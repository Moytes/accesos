import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let screenSecurityChannelName = "com.controlplus/screen_security"
  private var screenSecurityChannel: FlutterMethodChannel?
  private var isSecureModeEnabled = false
  private var privacyOverlayView: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: screenSecurityChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(false)
          return
        }
        switch call.method {
        case "enableSecureMode":
          self.isSecureModeEnabled = true
          self.syncPrivacyShield()
          result(true)
        case "disableSecureMode":
          self.isSecureModeEnabled = false
          self.removePrivacyShield()
          result(true)
        case "isScreenCaptured":
          result(UIScreen.main.isCaptured)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      screenSecurityChannel = channel
    }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleScreenCaptureChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleUserDidTakeScreenshot),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    if isSecureModeEnabled {
      showPrivacyShield()
    }
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    syncPrivacyShield()
  }

  @objc private func handleScreenCaptureChanged() {
    syncPrivacyShield()
    screenSecurityChannel?.invokeMethod("onCaptureChanged", arguments: UIScreen.main.isCaptured)
  }

  @objc private func handleUserDidTakeScreenshot() {
    if isSecureModeEnabled {
      screenSecurityChannel?.invokeMethod("onScreenshotTaken", arguments: nil)
    }
  }

  private func syncPrivacyShield() {
    if isSecureModeEnabled && UIScreen.main.isCaptured {
      showPrivacyShield()
    } else if !UIScreen.main.isCaptured {
      removePrivacyShield()
    }
  }

  private func showPrivacyShield() {
    guard privacyOverlayView == nil, let targetWindow = window else { return }
    let overlay = UIView(frame: targetWindow.bounds)
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlay.backgroundColor = UIColor(red: 0.0, green: 0.2, blue: 0.4, alpha: 1.0)

    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "CONTROL+\nContenido protegido contra captura"
    label.numberOfLines = 0
    label.textAlignment = .center
    label.textColor = .white
    label.font = UIFont.boldSystemFont(ofSize: 18)

    overlay.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
      label.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 24),
      label.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -24),
    ])

    targetWindow.addSubview(overlay)
    privacyOverlayView = overlay
  }

  private func removePrivacyShield() {
    privacyOverlayView?.removeFromSuperview()
    privacyOverlayView = nil
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}
