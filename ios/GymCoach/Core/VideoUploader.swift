import AVFoundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// What the server says about video uploads.
struct StorageStatus: Codable {
    let configured: Bool
    let maxMb: Int
}

struct SignedUpload: Codable {
    let key: String
    let contentType: String
    let uploadUrl: String
    let publicUrl: String
}

struct UploadTargets: Codable {
    let video: SignedUpload
    let thumbnail: SignedUpload?
}

struct UploadResult {
    let videoUrl: String
    let thumbnailUrl: String?
    let storageKey: String
    let thumbnailKey: String?
    let durationSec: Int
}

enum UploadError: LocalizedError {
    case unreadable, exportFailed(String), tooLarge(Int), rejected(Int), notConfigured

    var errorDescription: String? {
        switch self {
        case .unreadable: return "That video could not be read."
        case .exportFailed(let why): return "The video could not be prepared: \(why)"
        case .tooLarge(let mb): return "The video is larger than \(mb) MB even after optimizing. Trim it or use a shorter clip."
        case .rejected(let code):
            return code == 403
                ? "Storage rejected the upload (403). Check the R2 keys and bucket on the server."
                : "The upload failed (\(code)). Try again."
        case .notConfigured: return "Video storage is not connected yet. Paste a link instead."
        }
    }
}

/// A movie picked from Photos, copied to a temporary file so a big video is
/// never held in memory.
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
            try FileManager.default.copyItem(at: received.file, to: destination)
            return PickedMovie(url: destination)
        }
    }
}

/// Prepares a video (iPhone friendly MP4 that starts playing before it has
/// fully downloaded), makes a thumbnail, and uploads both straight to storage
/// with a signed link.
@MainActor
@Observable
final class VideoUploader {
    var stage = ""
    var progress = 0.0
    var isWorking = false

    func upload(source: URL, title: String, maxMb: Int) async throws -> UploadResult {
        isWorking = true
        defer { isWorking = false; progress = 0; stage = "" }

        let asset = AVURLAsset(url: source)
        guard let duration = try? await asset.load(.duration), duration.seconds.isFinite, duration.seconds > 0 else {
            throw UploadError.unreadable
        }

        stage = "Making the thumbnail"
        let thumbnailData = await Self.thumbnail(for: asset)

        stage = "Optimizing the video"
        let optimized = try await export(asset)
        defer { try? FileManager.default.removeItem(at: optimized) }

        let size = (try? FileManager.default.attributesOfItem(atPath: optimized.path)[.size] as? Int) ?? 0
        if size > maxMb * 1024 * 1024 { throw UploadError.tooLarge(maxMb) }

        stage = "Preparing the upload"
        var request: [String: Any] = [
            "fileName": Self.fileName(from: title) + ".mp4", "contentType": "video/mp4", "sizeBytes": size,
        ]
        if thumbnailData != nil { request["thumbnail"] = ["fileName": "thumbnail.jpg", "contentType": "image/jpeg"] }
        let targets: UploadTargets
        do {
            targets = try await APIClient.shared.send("POST", "/api/admin/videos/upload-url", json: request)
        } catch let error as APIError {
            if case .server(let message) = error, message.contains("not connected") { throw UploadError.notConfigured }
            throw error
        }

        if let thumbnailData, let target = targets.thumbnail {
            stage = "Uploading the thumbnail"
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
            try thumbnailData.write(to: temp)
            defer { try? FileManager.default.removeItem(at: temp) }
            try await put(file: temp, to: target) { _ in }
        }

        stage = "Uploading the video"
        try await put(file: optimized, to: targets.video) { [weak self] fraction in
            Task { @MainActor in self?.progress = fraction }
        }

        return UploadResult(
            videoUrl: targets.video.publicUrl,
            thumbnailUrl: targets.thumbnail.flatMap { thumbnailData == nil ? nil : $0.publicUrl },
            storageKey: targets.video.key,
            thumbnailKey: thumbnailData == nil ? nil : targets.thumbnail?.key,
            durationSec: Int(duration.seconds.rounded()))
    }

    // MARK: Steps

    private static func fileName(from title: String) -> String {
        let cleaned = title.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
        return cleaned.isEmpty ? "clip" : String(cleaned.prefix(50))
    }

    private static func thumbnail(for asset: AVURLAsset) async -> Data? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 900, height: 1600)
        guard let result = try? await generator.image(at: CMTime(seconds: 0.6, preferredTimescale: 600)) else { return nil }
        return UIImage(cgImage: result.image).jpegData(compressionQuality: 0.82)
    }

    /// Re-encodes to an H.264 MP4 with the index at the front ("optimize for network use").
    private func export(_ asset: AVAsset) async throws -> URL {
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1920x1080) else {
            throw UploadError.exportFailed("no encoder")
        }
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
        session.outputURL = output
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true

        let watcher = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.progress = Double(session.progress)
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
        defer { watcher.cancel() }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { continuation.resume() }
        }
        guard session.status == .completed else {
            try? FileManager.default.removeItem(at: output)
            throw UploadError.exportFailed(session.error?.localizedDescription ?? "export failed")
        }
        return output
    }

    /// Uploads a file with a signed URL. A separate session with no cookies:
    /// the app's login must never be sent to the storage host.
    private func put(file: URL, to target: SignedUpload, progress: @escaping (Double) -> Void) async throws {
        guard let url = URL(string: target.uploadUrl) else { throw UploadError.rejected(0) }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(target.contentType, forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 600

        let delegate = ProgressDelegate(onProgress: progress)
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        let (_, response) = try await session.upload(for: request, fromFile: file, delegate: delegate)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw UploadError.rejected(status) }
    }
}

private final class ProgressDelegate: NSObject, URLSessionTaskDelegate {
    let onProgress: (Double) -> Void

    init(onProgress: @escaping (Double) -> Void) { self.onProgress = onProgress }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        onProgress(Double(totalBytesSent) / Double(totalBytesExpectedToSend))
    }
}
