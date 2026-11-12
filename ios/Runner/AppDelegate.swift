import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ScannerOcr") {
      OcrChannel.register(messenger: registrar.messenger())
    }
  }
}

enum OcrError: Error {
  case koreanUnsupported
}

/// 문서 이미지에서 글자를 읽는다. Apple Vision(기기 안에서 처리, 무료)을 쓰며 한국어와 영어를 인식한다.
enum OcrChannel {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.jinyu74.scanner/ocr", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "recognize",
            let args = call.arguments as? [String: Any],
            let path = args["path"] as? String
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let text = try recognize(path: path)
          DispatchQueue.main.async { result(text) }
        } catch OcrError.koreanUnsupported {
          DispatchQueue.main.async {
            result(FlutterError(code: "korean_unsupported", message: "Korean text recognition is not supported on this device.", details: nil))
          }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "ocr_failed", message: error.localizedDescription, details: nil))
          }
        }
      }
    }
  }

  static func recognize(path: String) throws -> String {
    guard let image = UIImage(contentsOfFile: path), let cgImage = image.cgImage else {
      throw NSError(domain: "ocr", code: 1, userInfo: [NSLocalizedDescriptionKey: "이미지를 읽을 수 없습니다."])
    }
    let request = VNRecognizeTextRequest()
    // 한국어는 Revision3(iOS 16 이상)부터 지원된다. 지원하지 않으면 조용히 영어로만
    // 읽지 않고 분명한 오류를 돌려준다.
    request.revision = VNRecognizeTextRequestRevision3
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    let supported = (try? request.supportedRecognitionLanguages()) ?? []
    guard supported.contains("ko-KR") else {
      throw OcrError.koreanUnsupported
    }
    request.recognitionLanguages = ["ko-KR", "en-US"]
    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: cgOrientation(image.imageOrientation))
    try handler.perform([request])
    let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    return lines.joined(separator: "\n")
  }

  private static func cgOrientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
    switch o {
    case .up: return .up
    case .down: return .down
    case .left: return .left
    case .right: return .right
    case .upMirrored: return .upMirrored
    case .downMirrored: return .downMirrored
    case .leftMirrored: return .leftMirrored
    case .rightMirrored: return .rightMirrored
    @unknown default: return .up
    }
  }
}
