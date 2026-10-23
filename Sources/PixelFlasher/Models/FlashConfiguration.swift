import Foundation

public struct FlashConfiguration: Sendable {
    /// Option to wipe user data (-w flag)
    public var wipeUserData: Bool

    /// Option to lock bootloader after flashing
    public var lockBootloader: Bool

    /// Flash both slots A and B for redundancy on A/B devices
    public var forceFlashBothSlots: Bool

    /// Auto reboot device to system after successful flashing
    public var rebootAfterFlash: Bool

    /// Force verification of firmware image checksum and integrity
    public var verifyImageIntegrity: Bool

    /// Verify partition write status and slot health after flash
    public var verifyPostFlashState: Bool

    /// Selected local firmware zip file or extracted directory
    public var localFirmwareURL: URL?

    /// Selected remote firmware release (if downloading/using catalog)
    public var selectedRelease: FirmwareRelease?

    /// Targeted device serial
    public var targetDeviceSerial: String?

    public init(
        wipeUserData: Bool = false,
        lockBootloader: Bool = false,
        forceFlashBothSlots: Bool = false,
        rebootAfterFlash: Bool = true,
        verifyImageIntegrity: Bool = true,
        verifyPostFlashState: Bool = true,
        localFirmwareURL: URL? = nil,
        selectedRelease: FirmwareRelease? = nil,
        targetDeviceSerial: String? = nil
    ) {
        self.wipeUserData = wipeUserData
        self.lockBootloader = lockBootloader
        self.forceFlashBothSlots = forceFlashBothSlots
        self.rebootAfterFlash = rebootAfterFlash
        self.verifyImageIntegrity = verifyImageIntegrity
        self.verifyPostFlashState = verifyPostFlashState
        self.localFirmwareURL = localFirmwareURL
        self.selectedRelease = selectedRelease
        self.targetDeviceSerial = targetDeviceSerial
    }
}
