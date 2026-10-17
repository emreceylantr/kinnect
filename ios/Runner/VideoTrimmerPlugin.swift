import Flutter
import Foundation
import AVFoundation

class VideoTrimmerPlugin: NSObject {
    static let shared = VideoTrimmerPlugin()
    private let channelName = "com.kinnect.video_trimmer"

    private override init() {}

    func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "trim":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String,
                  let startSeconds = args["startSeconds"] as? Double,
                  let durationSeconds = args["durationSeconds"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "path, startSeconds, durationSeconds gerekli",
                                    details: nil))
                return
            }
            trim(path: path, startSeconds: startSeconds, durationSeconds: durationSeconds, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func trim(path: String, startSeconds: Double, durationSeconds: Double,
                      result: @escaping FlutterResult) {
        let sourceURL = URL(fileURLWithPath: path)
        let asset = AVAsset(url: sourceURL)

        let timescale: CMTimeScale = 600
        let startTime = CMTimeMakeWithSeconds(startSeconds, preferredTimescale: timescale)
        let duration  = CMTimeMakeWithSeconds(durationSeconds, preferredTimescale: timescale)
        let timeRange = CMTimeRangeMake(start: startTime, duration: duration)

        // Build composition with video + audio trimmed to timeRange
        let composition = AVMutableComposition()

        guard let videoTrack = asset.tracks(withMediaType: .video).first,
              let compVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid) else {
            result(FlutterError(code: "NO_VIDEO_TRACK", message: "Video track bulunamadı", details: nil))
            return
        }

        compVideoTrack.preferredTransform = videoTrack.preferredTransform
        do {
            try compVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
        } catch {
            result(FlutterError(code: "INSERT_ERROR", message: error.localizedDescription, details: nil))
            return
        }

        if let audioTrack = asset.tracks(withMediaType: .audio).first,
           let compAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid) {
            try? compAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        }

        // Output to temp file
        let outputPath = NSTemporaryDirectory() + "kinnect_trim_\(UUID().uuidString).mp4"
        let outputURL  = URL(fileURLWithPath: outputPath)
        try? FileManager.default.removeItem(at: outputURL)

        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetMediumQuality) else {
            result(FlutterError(code: "EXPORTER_ERROR", message: "Exporter oluşturulamadı", details: nil))
            return
        }

        exporter.outputURL  = outputURL
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = true

        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                switch exporter.status {
                case .completed:
                    result(outputPath)
                case .failed:
                    result(FlutterError(code: "EXPORT_FAILED",
                                        message: exporter.error?.localizedDescription ?? "Bilinmeyen hata",
                                        details: nil))
                case .cancelled:
                    result(FlutterError(code: "EXPORT_CANCELLED", message: "İptal edildi", details: nil))
                default:
                    result(FlutterError(code: "EXPORT_ERROR",
                                        message: "Beklenmedik durum: \(exporter.status.rawValue)",
                                        details: nil))
                }
            }
        }
    }
}
