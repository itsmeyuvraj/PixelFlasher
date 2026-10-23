import Foundation

public enum CheckResultStatus: String, Codable, Sendable {
    case passed = "Passed"
    case failed = "Failed"
    case warning = "Warning"
    case skipped = "Skipped"

    public var icon: String {
        switch self {
        case .passed: return "checkmark.seal.fill"
        case .failed: return "xmark.seal.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .skipped: return "minus.circle.fill"
        }
    }

    public var colorName: String {
        switch self {
        case .passed: return "green"
        case .failed: return "red"
        case .warning: return "orange"
        case .skipped: return "gray"
        }
    }
}

public struct PartitionFlashResult: Identifiable, Codable, Sendable {
    public let id: String
    public let partitionName: String
    public let status: CheckResultStatus
    public let message: String
    public let timeElapsedSeconds: Double

    public init(partitionName: String, status: CheckResultStatus, message: String, timeElapsedSeconds: Double = 0.0) {
        self.id = partitionName
        self.partitionName = partitionName
        self.status = status
        self.message = message
        self.timeElapsedSeconds = timeElapsedSeconds
    }
}

public struct VerificationReport: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let deviceSerial: String
    public let deviceModel: String
    public let firmwareFileName: String
    public var firmwareType: FirmwareType

    // Pre-flash checks
    public var checksumStatus: CheckResultStatus
    public var calculatedChecksum: String?
    public var expectedChecksum: String?
    public var codenameMatchStatus: CheckResultStatus
    public var expectedCodename: String?
    public var detectedDeviceCodename: String?

    // Flash execution results
    public var flashExecutionStatus: CheckResultStatus
    public var partitionResults: [PartitionFlashResult]

    // Post-flash checks
    public var postFlashSlotStatus: CheckResultStatus
    public var currentSlot: String?
    public var slotSuccessful: Bool?
    public var bootloaderVersionMatches: CheckResultStatus
    public var reportedBootloaderVersion: String?
    public var reportedBasebandVersion: String?
    public var bootloaderLockedStatus: CheckResultStatus?

    // Overall verdict
    public var overallStatus: CheckResultStatus
    public var summaryMessage: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        deviceSerial: String,
        deviceModel: String,
        firmwareFileName: String,
        firmwareType: FirmwareType,
        checksumStatus: CheckResultStatus = .skipped,
        calculatedChecksum: String? = nil,
        expectedChecksum: String? = nil,
        codenameMatchStatus: CheckResultStatus = .skipped,
        expectedCodename: String? = nil,
        detectedDeviceCodename: String? = nil,
        flashExecutionStatus: CheckResultStatus = .skipped,
        partitionResults: [PartitionFlashResult] = [],
        postFlashSlotStatus: CheckResultStatus = .skipped,
        currentSlot: String? = nil,
        slotSuccessful: Bool? = nil,
        bootloaderVersionMatches: CheckResultStatus = .skipped,
        reportedBootloaderVersion: String? = nil,
        reportedBasebandVersion: String? = nil,
        bootloaderLockedStatus: CheckResultStatus? = nil,
        overallStatus: CheckResultStatus = .passed,
        summaryMessage: String = "Verification completed."
    ) {
        self.id = id
        self.timestamp = timestamp
        self.deviceSerial = deviceSerial
        self.deviceModel = deviceModel
        self.firmwareFileName = firmwareFileName
        self.firmwareType = firmwareType
        self.checksumStatus = checksumStatus
        self.calculatedChecksum = calculatedChecksum
        self.expectedChecksum = expectedChecksum
        self.codenameMatchStatus = codenameMatchStatus
        self.expectedCodename = expectedCodename
        self.detectedDeviceCodename = detectedDeviceCodename
        self.flashExecutionStatus = flashExecutionStatus
        self.partitionResults = partitionResults
        self.postFlashSlotStatus = postFlashSlotStatus
        self.currentSlot = currentSlot
        self.slotSuccessful = slotSuccessful
        self.bootloaderVersionMatches = bootloaderVersionMatches
        self.reportedBootloaderVersion = reportedBootloaderVersion
        self.reportedBasebandVersion = reportedBasebandVersion
        self.bootloaderLockedStatus = bootloaderLockedStatus
        self.overallStatus = overallStatus
        self.summaryMessage = summaryMessage
    }
}
