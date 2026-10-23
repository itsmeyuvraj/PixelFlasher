import Foundation

public actor PlatformToolsManager {
    public static let shared = PlatformToolsManager()

    public private(set) var adbPath: String?
    public private(set) var fastbootPath: String?
    public private(set) var isReady: Bool = false
    public private(set) var toolVersion: String = ""

    private let standardSearchPaths = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        NSHomeDirectory() + "/Library/Android/sdk/platform-tools",
        NSHomeDirectory() + "/.android-sdk/platform-tools",
        "/usr/bin"
    ]

    public init() {}

    public func detectTools(customAdb: String? = nil, customFastboot: String? = nil) async -> Bool {
        // Check custom paths if provided
        if let customAdb = customAdb, FileManager.default.isExecutableFile(atPath: customAdb) {
            self.adbPath = customAdb
        }
        if let customFastboot = customFastboot, FileManager.default.isExecutableFile(atPath: customFastboot) {
            self.fastbootPath = customFastboot
        }

        // Search default locations
        if self.adbPath == nil {
            for dir in standardSearchPaths {
                let candidate = "\(dir)/adb"
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    self.adbPath = candidate
                    break
                }
            }
        }

        if self.fastbootPath == nil {
            for dir in standardSearchPaths {
                let candidate = "\(dir)/fastboot"
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    self.fastbootPath = candidate
                    break
                }
            }
        }

        if self.adbPath != nil, let fastboot = self.fastbootPath {
            self.isReady = true
            // Read fastboot version
            do {
                let res = try await ProcessRunner.shared.run(executable: fastboot, arguments: ["--version"])
                self.toolVersion = res.stdout.components(separatedBy: .newlines).first ?? "Fastboot detected"
            } catch {
                self.toolVersion = "Fastboot present"
            }
            return true
        } else {
            self.isReady = false
            return false
        }
    }

    public func getFastbootPath() -> String {
        return fastbootPath ?? "/opt/homebrew/bin/fastboot"
    }

    public func getAdbPath() -> String {
        return adbPath ?? "/opt/homebrew/bin/adb"
    }

    /// Automatically download official Google platform-tools for macOS if missing
    public func downloadGooglePlatformTools(progressHandler: @escaping @Sendable (Double, String) -> Void) async throws {
        let downloadURL = URL(string: "https://dl.google.com/android/repository/platform-tools-latest-darwin.zip")!
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PixelFlasher/platform-tools", isDirectory: true)

        try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        let destinationZip = supportDir.appendingPathComponent("platform-tools.zip")

        progressHandler(0.1, "Downloading Android Platform-Tools from Google...")

        let (tempURL, _) = try await URLSession.shared.download(from: downloadURL)
        if FileManager.default.fileExists(atPath: destinationZip.path) {
            try FileManager.default.removeItem(at: destinationZip)
        }
        try FileManager.default.moveItem(at: tempURL, to: destinationZip)

        progressHandler(0.7, "Extracting platform-tools...")

        // Unzip via system unzip
        let unzipRes = try await ProcessRunner.shared.run(
            executable: "/usr/bin/unzip",
            arguments: ["-o", destinationZip.path, "-d", supportDir.path]
        )
        guard unzipRes.isSuccess else {
            throw NSError(domain: "PlatformToolsManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to unzip platform tools: \(unzipRes.stderr)"])
        }

        let downloadedAdb = supportDir.appendingPathComponent("platform-tools/adb").path
        let downloadedFastboot = supportDir.appendingPathComponent("platform-tools/fastboot").path

        // Make executable
        _ = try? await ProcessRunner.shared.run(executable: "/bin/chmod", arguments: ["+x", downloadedAdb, downloadedFastboot])

        self.adbPath = downloadedAdb
        self.fastbootPath = downloadedFastboot
        self.isReady = true
        progressHandler(1.0, "Platform tools installed successfully!")
    }
}
