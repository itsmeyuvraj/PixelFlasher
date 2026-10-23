import Foundation
import Combine

@MainActor
public final class DeviceMonitor: ObservableObject {
    public static let shared = DeviceMonitor()

    @Published public var devices: [ConnectedDevice] = []
    @Published public var selectedDevice: ConnectedDevice?
    @Published public var isScanning: Bool = false
    @Published public var lastScanDate: Date?

    private var timer: Timer?

    public init() {
        startPolling()
    }

    public func startPolling() {
        stopPolling()
        Task {
            await self.scanDevices()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.scanDevices()
            }
        }
    }

    public func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    public func scanDevices() async {
        isScanning = true
        defer {
            isScanning = false
            lastScanDate = Date()
        }

        // Poll both fastboot and adb
        async let fastbootDevices = FastbootService.shared.listDevices()
        async let adbDevices = ADBService.shared.listDevices()

        let fb = await fastbootDevices
        let adb = await adbDevices

        var combined: [ConnectedDevice] = []
        // Fastboot takes precedence if a device is in fastboot mode
        let fbSerials = Set(fb.map { $0.serial })
        combined.append(contentsOf: fb)

        for dev in adb {
            if !fbSerials.contains(dev.serial) {
                combined.append(dev)
            }
        }

        self.devices = combined

        // Maintain or update selection
        if let current = selectedDevice {
            if let updated = combined.first(where: { $0.serial == current.serial }) {
                self.selectedDevice = updated
            } else if !combined.isEmpty {
                self.selectedDevice = combined.first
            } else {
                self.selectedDevice = nil
            }
        } else if let first = combined.first {
            self.selectedDevice = first
        }
    }

    public func selectDevice(_ device: ConnectedDevice) {
        self.selectedDevice = device
    }
}
