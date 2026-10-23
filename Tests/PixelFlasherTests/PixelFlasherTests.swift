import Testing
import Foundation
@testable import PixelFlasher

@Suite("Pixel Flasher Test Suite")
struct PixelFlasherTests {

    @Test("Verify all Pixel device generations and codenames exist")
    func testDeviceCatalogCompleteness() throws {
        let all = PixelDevice.allDevices
        #expect(all.count >= 28)

        // Test essential flagship devices across generations
        let codenames = Set(all.map { $0.codename })
        #expect(codenames.contains("comet"))     // Pixel 9 Pro Fold
        #expect(codenames.contains("komodo"))    // Pixel 9 Pro XL
        #expect(codenames.contains("caiman"))    // Pixel 9 Pro
        #expect(codenames.contains("tokay"))     // Pixel 9
        #expect(codenames.contains("husky"))     // Pixel 8 Pro
        #expect(codenames.contains("shiba"))     // Pixel 8
        #expect(codenames.contains("akita"))     // Pixel 8a
        #expect(codenames.contains("felix"))     // Pixel Fold
        #expect(codenames.contains("tangorpro")) // Pixel Tablet
        #expect(codenames.contains("cheetah"))   // Pixel 7 Pro
        #expect(codenames.contains("panther"))   // Pixel 7
        #expect(codenames.contains("raven"))     // Pixel 6 Pro
        #expect(codenames.contains("oriole"))    // Pixel 6
        #expect(codenames.contains("redfin"))    // Pixel 5
        #expect(codenames.contains("coral"))     // Pixel 4 XL
        #expect(codenames.contains("crosshatch"))// Pixel 3 XL
        #expect(codenames.contains("taimen"))    // Pixel 2 XL
        #expect(codenames.contains("sailfish"))  // Pixel (1)
    }

    @Test("Verify case-insensitive codename lookup")
    func testCodenameLookup() throws {
        let dev1 = PixelDevice.find(byCodename: "HUSKY")
        #expect(dev1?.name == "Pixel 8 Pro")
        #expect(dev1?.isTensor == true)

        let dev2 = PixelDevice.find(byCodename: "caiman")
        #expect(dev2?.name == "Pixel 9 Pro")

        let dev3 = PixelDevice.find(byCodename: "sailfish")
        #expect(dev3?.name == "Pixel")
        #expect(dev3?.isTensor == false)

        let devNonExistent = PixelDevice.find(byCodename: "unknown_phone")
        #expect(devNonExistent == nil)
    }

    @Test("Verify firmware catalog covers factory, OTA, and beta releases")
    @MainActor
    func testFirmwareCatalogReleases() async throws {
        let catalog = FirmwareCatalogService.shared.releases
        #expect(!catalog.isEmpty)

        // Check release types
        let factoryReleases = catalog.filter { $0.type == .factory }
        let otaReleases = catalog.filter { $0.type == .ota }
        let betaReleases = catalog.filter { $0.type == .beta }

        #expect(!factoryReleases.isEmpty)
        #expect(!otaReleases.isEmpty)
        #expect(!betaReleases.isEmpty)

        // Verify SHA-256 length is exactly 64 hex characters
        for release in catalog {
            #expect(release.sha256.count == 64)
            #expect(release.downloadURL.absoluteString.hasPrefix("https://"))
            #expect(!release.buildId.isEmpty)
        }
    }

    @Test("Verify Pixel 6a (bluejay) has Android 17 and Android 16 firmware")
    @MainActor
    func testPixel6aReleases() async throws {
        let releases = FirmwareCatalogService.shared.releasesFor(deviceCodename: "bluejay")
        #expect(!releases.isEmpty)
        let android17 = releases.first { $0.androidVersion.contains("17") }
        #expect(android17 != nil)
        let android16 = releases.first { $0.androidVersion.contains("16") }
        #expect(android16 != nil)
    }

    @Test("Verify SHA-256 calculation accuracy")
    func testSHA256Calculation() async throws {
        let testString = "PixelFlasher_Verification_Test_Payload"
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_hash_\(UUID().uuidString).txt")

        try testString.data(using: .utf8)?.write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let calculatedHash = try await VerificationService.shared.calculateSHA256(for: tempFile)
        #expect(calculatedHash.count == 64)

        // Verify pre-flash verification on this file
        let (isValid, report) = await VerificationService.shared.verifyPreFlash(
            fileURL: tempFile,
            expectedChecksum: calculatedHash,
            targetDeviceCodename: nil,
            onLog: { _ in }
        )
        #expect(isValid == true)
        #expect(report.checksumStatus == .passed)
    }

    @Test("Verify FlashConfiguration initial values")
    func testFlashConfigurationDefaults() throws {
        var config = FlashConfiguration()
        #expect(config.wipeUserData == false)
        #expect(config.lockBootloader == false)
        #expect(config.verifyImageIntegrity == true)
        #expect(config.verifyPostFlashState == true)
        #expect(config.rebootAfterFlash == true)

        config.wipeUserData = true
        config.lockBootloader = true
        #expect(config.wipeUserData == true)
        #expect(config.lockBootloader == true)
    }
}
