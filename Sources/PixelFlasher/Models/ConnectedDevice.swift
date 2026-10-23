import Foundation

public enum DeviceMode: String, CaseIterable, Identifiable, Sendable {
    case adb = "ADB (System)"
    case fastboot = "Fastboot (Bootloader)"
    case fastbootd = "Fastbootd"
    case recovery = "Recovery"
    case sideload = "ADB Sideload"
    case unauthorized = "Unauthorized"
    case offline = "Offline"
    case unknown = "Unknown"

    public var id: String { rawValue }

    public var badgeColor: String {
        switch self {
        case .adb: return "blue"
        case .fastboot: return "green"
        case .fastbootd: return "purple"
        case .sideload: return "orange"
        case .recovery: return "yellow"
        case .unauthorized: return "red"
        case .offline, .unknown: return "gray"
        }
    }

    public var iconName: String {
        switch self {
        case .adb: return "iphone.gen3"
        case .fastboot: return "wrench.and.screwdriver.fill"
        case .fastbootd: return "cpu"
        case .sideload: return "arrow.down.to.line.compact"
        case .recovery: return "cross.case.fill"
        case .unauthorized: return "lock.trianglebadge.exclamationmark"
        case .offline, .unknown: return "bolt.horizontal.circle"
        }
    }
}

public enum BootloaderLockState: String, Sendable {
    case locked = "Locked"
    case unlocked = "Unlocked"
    case unknown = "Unknown"
}

public struct ConnectedDevice: Identifiable, Hashable, Sendable {
    public let id: String
    public var serial: String
    public var mode: DeviceMode
    public var productCodename: String?
    public var matchedDevice: PixelDevice?
    public var bootloaderState: BootloaderLockState
    public var currentSlot: String?
    public var bootloaderVersion: String?
    public var basebandVersion: String?
    public var buildId: String?
    public var batteryLevel: String?

    public init(
        serial: String,
        mode: DeviceMode,
        productCodename: String? = nil,
        matchedDevice: PixelDevice? = nil,
        bootloaderState: BootloaderLockState = .unknown,
        currentSlot: String? = nil,
        bootloaderVersion: String? = nil,
        basebandVersion: String? = nil,
        buildId: String? = nil,
        batteryLevel: String? = nil
    ) {
        self.id = serial
        self.serial = serial
        self.mode = mode
        self.productCodename = productCodename
        self.matchedDevice = matchedDevice ?? (productCodename != nil ? PixelDevice.find(byCodename: productCodename!) : nil)
        self.bootloaderState = bootloaderState
        self.currentSlot = currentSlot
        self.bootloaderVersion = bootloaderVersion
        self.basebandVersion = basebandVersion
        self.buildId = buildId
        self.batteryLevel = batteryLevel
    }

    public var displayName: String {
        if let matched = matchedDevice {
            return matched.name
        } else if let codename = productCodename, !codename.isEmpty {
            return "Pixel (\(codename))"
        } else {
            return "Device (\(serial))"
        }
    }
}
