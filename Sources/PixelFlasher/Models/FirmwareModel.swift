import Foundation

public enum FirmwareType: String, CaseIterable, Identifiable, Codable, Sendable {
    case factory = "Factory Image"
    case ota = "Full OTA"
    case beta = "Android Beta"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .factory: return "bolt.shield.fill"
        case .ota: return "arrow.down.doc.fill"
        case .beta: return "flask.fill"
        }
    }

    public var flashMethodDescription: String {
        switch self {
        case .factory:
            return "Flashed via Fastboot. Flashes bootloader, radio, system partitions. Supports clean wiping and locking bootloader."
        case .ota:
            return "Flashed via Recovery ADB Sideload. Seamless update that preserves personal data."
        case .beta:
            return "Preview beta firmware from Google Developer / Android Beta program."
        }
    }
}

public struct FirmwareRelease: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let deviceCodename: String
    public let versionName: String
    public let buildId: String
    public let androidVersion: String
    public let type: FirmwareType
    public let downloadURL: URL
    public let sha256: String
    public let releaseDate: String
    public let securityPatch: String
    public let approximateSizeMB: Int
    public let isBeta: Bool

    public init(
        deviceCodename: String,
        versionName: String,
        buildId: String,
        androidVersion: String,
        type: FirmwareType,
        downloadURL: URL,
        sha256: String,
        releaseDate: String,
        securityPatch: String,
        approximateSizeMB: Int,
        isBeta: Bool = false
    ) {
        self.id = "\(deviceCodename)-\(buildId)-\(type.rawValue)"
        self.deviceCodename = deviceCodename
        self.versionName = versionName
        self.buildId = buildId
        self.androidVersion = androidVersion
        self.type = type
        self.downloadURL = downloadURL
        self.sha256 = sha256
        self.releaseDate = releaseDate
        self.securityPatch = securityPatch
        self.approximateSizeMB = approximateSizeMB
        self.isBeta = isBeta
    }
}
