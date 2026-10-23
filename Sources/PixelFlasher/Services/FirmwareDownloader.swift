import Foundation

public struct DownloadProgress: Sendable {
    public let bytesDownloaded: Int64
    public let totalBytes: Int64
    public let fractionCompleted: Double
    public let speedBytesPerSec: Double
    public let etaSeconds: TimeInterval?

    public var speedString: String {
        let mb = speedBytesPerSec / (1024 * 1024)
        return String(format: "%.1f MB/s", mb)
    }

    public var progressPercentageString: String {
        return String(format: "%.0f%%", fractionCompleted * 100)
    }

    public var sizeString: String {
        let downloadedMB = Double(bytesDownloaded) / (1024 * 1024)
        let totalMB = Double(totalBytes) / (1024 * 1024)
        return String(format: "%.1f / %.1f MB", downloadedMB, totalMB)
    }
}

public actor FirmwareDownloader: NSObject {
    public static let shared = FirmwareDownloader()

    public private(set) var isDownloading: Bool = false
    private var downloadTask: URLSessionDownloadTask?
    private var continuation: CheckedContinuation<URL, Error>?
    private var progressCallback: (@Sendable (DownloadProgress) -> Void)?

    private var startTime: Date?
    private var lastBytes: Int64 = 0

    public override init() {
        super.init()
    }

    public func setDownloading(_ value: Bool) {
        self.isDownloading = value
    }

    public func download(
        release: FirmwareRelease,
        onProgress: @escaping @Sendable (DownloadProgress) -> Void
    ) async throws -> URL {
        guard !isDownloading else {
            throw NSError(domain: "FirmwareDownloader", code: 1, userInfo: [NSLocalizedDescriptionKey: "Download already in progress."])
        }

        self.isDownloading = true
        self.progressCallback = onProgress
        self.startTime = Date()
        self.lastBytes = 0

        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PixelFlasher", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        let destinationURL = downloadsDir.appendingPathComponent(release.downloadURL.lastPathComponent)

        // If file already exists and has matching checksum or size, return it directly
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            let attr = try? FileManager.default.attributesOfItem(atPath: destinationURL.path)
            let existingSize = attr?[.size] as? Int64 ?? 0
            if existingSize > 50 * 1024 * 1024 { // larger than 50MB
                self.isDownloading = false
                return destinationURL
            }
        }

        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)

        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: release.downloadURL) { tempURL, response, error in
                Task {
                    await self.setDownloading(false)
                }

                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let tempURL = tempURL else {
                    continuation.resume(throwing: NSError(domain: "FirmwareDownloader", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing temp file."]))
                    return
                }

                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                    continuation.resume(returning: destinationURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            self.downloadTask = task
            task.resume()

            // Observe progress timer
            Task {
                while self.isDownloading {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                    let count = task.countOfBytesReceived
                    let total = task.countOfBytesExpectedToReceive
                    let fraction = total > 0 ? Double(count) / Double(total) : 0.0

                    let elapsed = Date().timeIntervalSince(self.startTime ?? Date())
                    let speed = elapsed > 0 ? Double(count) / elapsed : 0.0

                    let remainingBytes = total > count ? total - count : 0
                    let eta = speed > 0 ? Double(remainingBytes) / speed : nil

                    let p = DownloadProgress(
                        bytesDownloaded: count,
                        totalBytes: total > 0 ? total : Int64(release.approximateSizeMB * 1024 * 1024),
                        fractionCompleted: fraction,
                        speedBytesPerSec: speed,
                        etaSeconds: eta
                    )
                    self.progressCallback?(p)
                }
            }
        }
    }

    public func cancel() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
    }
}
