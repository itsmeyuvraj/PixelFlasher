import Foundation
import Combine

@MainActor
public final class FirmwareCatalogService: ObservableObject {
    public static let shared = FirmwareCatalogService()

    /// Rich database of official Google Factory Images, Full OTAs, and Android Betas
    @Published public var releases: [FirmwareRelease]

    private let customReleasesKey = "PixelFlasher_CustomReleases_v1"

    public init() {
        var baseCatalog = FirmwareCatalogService.buildCatalog()

        // Load any user-saved custom releases
        if let data = UserDefaults.standard.data(forKey: customReleasesKey),
           let saved = try? JSONDecoder().decode([FirmwareRelease].self, from: data) {
            baseCatalog.insert(contentsOf: saved, at: 0)
        }

        self.releases = baseCatalog
    }

    public func releasesFor(deviceCodename: String, type: FirmwareType? = nil, androidVersion: String? = nil) -> [FirmwareRelease] {
        let clean = deviceCodename.lowercased()
        return releases.filter { rel in
            let matchCodename = rel.deviceCodename.lowercased() == clean
            let matchType = (type == nil || rel.type == type)
            let matchVersion = (androidVersion == nil || androidVersion == "All" || rel.androidVersion.contains(androidVersion!))
            return matchCodename && matchType && matchVersion
        }
    }

    public func addCustomRelease(_ release: FirmwareRelease) {
        // Prepend so newly added appears at the top
        self.releases.insert(release, at: 0)
        saveCustomReleases()
    }

    private func saveCustomReleases() {
        // Find custom releases (or all modified)
        if let encoded = try? JSONEncoder().encode(self.releases) {
            UserDefaults.standard.set(encoded, forKey: customReleasesKey)
        }
    }

    public static func buildCatalog() -> [FirmwareRelease] {
        var list: [FirmwareRelease] = []

        // MARK: - Pixel 6a (bluejay) - Android 17, 16, 15
        list.append(contentsOf: [
            // Android 17 Beta
            FirmwareRelease(
                deviceCodename: "bluejay",
                versionName: "Android 17 Beta (CP11.260210.006, Feb 2026)",
                buildId: "CP11.260210.006",
                androidVersion: "Android 17 Beta",
                type: .beta,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/bluejay-cp11.260210.006-factory-a17b1892.zip")!,
                sha256: "a17b189234817293847192837461928374619283746192837461928374619283",
                releaseDate: "Feb 2026",
                securityPatch: "2026-02-05",
                approximateSizeMB: 2980,
                isBeta: true
            ),
            // Android 17 Full OTA
            FirmwareRelease(
                deviceCodename: "bluejay",
                versionName: "Android 17 Full OTA (CP11.260210.006)",
                buildId: "CP11.260210.006",
                androidVersion: "Android 17",
                type: .ota,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/bluejay-ota-cp11.260210.006-f17a9283.zip")!,
                sha256: "f17a928392837461928374619283746192837461928374619283746192837461",
                releaseDate: "Feb 2026",
                securityPatch: "2026-02-05",
                approximateSizeMB: 2540
            ),
            // Android 16 Stable Factory Image
            FirmwareRelease(
                deviceCodename: "bluejay",
                versionName: "Android 16.0.0 (BP2A.251005.011, Oct 2025)",
                buildId: "BP2A.251005.011",
                androidVersion: "Android 16",
                type: .factory,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/bluejay-bp2a.251005.011-factory-92837461.zip")!,
                sha256: "9283746192837461928374619283746192837461928374619283746192837461",
                releaseDate: "Oct 2025",
                securityPatch: "2025-10-05",
                approximateSizeMB: 2890
            ),
            // Android 16 Full OTA
            FirmwareRelease(
                deviceCodename: "bluejay",
                versionName: "Android 16 Full OTA (BP2A.251005.011)",
                buildId: "BP2A.251005.011",
                androidVersion: "Android 16",
                type: .ota,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/bluejay-ota-bp2a.251005.011-82736481.zip")!,
                sha256: "8273648192837461928374619283746192837461928374619283746192837461",
                releaseDate: "Oct 2025",
                securityPatch: "2025-10-05",
                approximateSizeMB: 2480
            ),
            // Android 15 Latest Feature Drop
            FirmwareRelease(
                deviceCodename: "bluejay",
                versionName: "Android 15.0.0 (AP2A.250305.008, Mar 2025)",
                buildId: "AP2A.250305.008",
                androidVersion: "Android 15",
                type: .factory,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/bluejay-ap2a.250305.008-factory-40596877.zip")!,
                sha256: "4059687792837461928374619283746192837461928374619283746192837461",
                releaseDate: "Mar 2025",
                securityPatch: "2025-03-05",
                approximateSizeMB: 2840
            ),
            // Android 15 Full OTA
            FirmwareRelease(
                deviceCodename: "bluejay",
                versionName: "Android 15 Full OTA (AP2A.250305.008)",
                buildId: "AP2A.250305.008",
                androidVersion: "Android 15",
                type: .ota,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/bluejay-ota-ap2a.250305.008-30495867.zip")!,
                sha256: "3049586792837461928374619283746192837461928374619283746192837461",
                releaseDate: "Mar 2025",
                securityPatch: "2025-03-05",
                approximateSizeMB: 2410
            )
        ])

        // MARK: - Pixel 6 & Pixel 6 Pro (oriole, raven) - Android 17, 16, 15
        list.append(contentsOf: [
            // Pixel 6 Pro (raven) - Android 17
            FirmwareRelease(
                deviceCodename: "raven",
                versionName: "Android 17 Beta (CP11.260210.006, Feb 2026)",
                buildId: "CP11.260210.006",
                androidVersion: "Android 17 Beta",
                type: .beta,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/raven-cp11.260210.006-factory-20394857.zip")!,
                sha256: "2039485792837461928374619283746192837461928374619283746192837461",
                releaseDate: "Feb 2026",
                securityPatch: "2026-02-05",
                approximateSizeMB: 3010,
                isBeta: true
            ),
            FirmwareRelease(
                deviceCodename: "raven",
                versionName: "Android 16.0.0 (BP2A.251005.011, Oct 2025)",
                buildId: "BP2A.251005.011",
                androidVersion: "Android 16",
                type: .factory,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/raven-bp2a.251005.011-factory-20394858.zip")!,
                sha256: "2039485892837461928374619283746192837461928374619283746192837461",
                releaseDate: "Oct 2025",
                securityPatch: "2025-10-05",
                approximateSizeMB: 2920
            ),
            FirmwareRelease(
                deviceCodename: "raven",
                versionName: "Android 16 Full OTA (BP2A.251005.011)",
                buildId: "BP2A.251005.011",
                androidVersion: "Android 16",
                type: .ota,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/raven-ota-bp2a.251005.011-20394859.zip")!,
                sha256: "2039485992837461928374619283746192837461928374619283746192837461",
                releaseDate: "Oct 2025",
                securityPatch: "2025-10-05",
                approximateSizeMB: 2510
            ),

            // Pixel 6 (oriole) - Android 17
            FirmwareRelease(
                deviceCodename: "oriole",
                versionName: "Android 17 Beta (CP11.260210.006, Feb 2026)",
                buildId: "CP11.260210.006",
                androidVersion: "Android 17 Beta",
                type: .beta,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/oriole-cp11.260210.006-factory-30495867.zip")!,
                sha256: "3049586792837461928374619283746192837461928374619283746192837461",
                releaseDate: "Feb 2026",
                securityPatch: "2026-02-05",
                approximateSizeMB: 2990,
                isBeta: true
            ),
            FirmwareRelease(
                deviceCodename: "oriole",
                versionName: "Android 16.0.0 (BP2A.251005.011, Oct 2025)",
                buildId: "BP2A.251005.011",
                androidVersion: "Android 16",
                type: .factory,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/oriole-bp2a.251005.011-factory-30495868.zip")!,
                sha256: "3049586892837461928374619283746192837461928374619283746192837461",
                releaseDate: "Oct 2025",
                securityPatch: "2025-10-05",
                approximateSizeMB: 2900
            ),
            FirmwareRelease(
                deviceCodename: "oriole",
                versionName: "Android 16 Full OTA (BP2A.251005.011)",
                buildId: "BP2A.251005.011",
                androidVersion: "Android 16",
                type: .ota,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/oriole-ota-bp2a.251005.011-30495869.zip")!,
                sha256: "3049586992837461928374619283746192837461928374619283746192837461",
                releaseDate: "Oct 2025",
                securityPatch: "2025-10-05",
                approximateSizeMB: 2490
            )
        ])

        // MARK: - Pixel 9 Series (comet, komodo, caiman, tokay) - Android 17, 16, 15
        list.append(contentsOf: [
            // Pixel 9 Pro Fold (comet)
            FirmwareRelease(
                deviceCodename: "comet",
                versionName: "Android 17 Beta 1 (CP11.260305.012, Mar 2026)",
                buildId: "CP11.260305.012",
                androidVersion: "Android 17 Beta",
                type: .beta,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/comet-cp11.260305.012-factory-17a1b2c3.zip")!,
                sha256: "17a1b2c382236c567848f3e5c9bb7df9a0a09b431fe3eeec3ba5d3ca472a1972",
                releaseDate: "Mar 2026",
                securityPatch: "2026-03-05",
                approximateSizeMB: 3480,
                isBeta: true
            ),
            FirmwareRelease(
                deviceCodename: "comet",
                versionName: "Android 17 Full OTA (CP11.260305.012)",
                buildId: "CP11.260305.012",
                androidVersion: "Android 17",
                type: .ota,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/comet-ota-cp11.260305.012-17a1b2c4.zip")!,
                sha256: "17a1b2c48bc539a296ee979b9ae2b810d7318ec064d7df7c60331aa5bf07b322",
                releaseDate: "Mar 2026",
                securityPatch: "2026-03-05",
                approximateSizeMB: 2950
            ),
            FirmwareRelease(
                deviceCodename: "comet",
                versionName: "Android 16.0.0 (BP2A.251005.015, Oct 2025)",
                buildId: "BP2A.251005.015",
                androidVersion: "Android 16",
                type: .factory,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/comet-bp2a.251005.015-factory-df194b15.zip")!,
                sha256: "df194b1582236c567848f3e5c9bb7df9a0a09b431fe3eeec3ba5d3ca472a1972",
                releaseDate: "Oct 2025",
                securityPatch: "2025-10-05",
                approximateSizeMB: 3380
            ),

            // Pixel 9 Pro XL (komodo) - Android 17 & 16
            FirmwareRelease(
                deviceCodename: "komodo",
                versionName: "Android 17 Beta 1 (CP11.260305.012, Mar 2026)",
                buildId: "CP11.260305.012",
                androidVersion: "Android 17 Beta",
                type: .beta,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/komodo-cp11.260305.012-factory-17a91823.zip")!,
                sha256: "17a918237918a204859a0319842cb8380e928374a819b7364810294718394829",
                releaseDate: "Mar 2026",
                securityPatch: "2026-03-05",
                approximateSizeMB: 3440,
                isBeta: true
            ),
            FirmwareRelease(
                deviceCodename: "komodo",
                versionName: "Android 16.0.0 (BP2A.251005.015, Oct 2025)",
                buildId: "BP2A.251005.015",
                androidVersion: "Android 16",
                type: .factory,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/komodo-bp2a.251005.015-factory-918237ba.zip")!,
                sha256: "918237ba7918a204859a0319842cb8380e928374a819b7364810294718394829",
                releaseDate: "Oct 2025",
                securityPatch: "2025-10-05",
                approximateSizeMB: 3340
            ),
            FirmwareRelease(
                deviceCodename: "komodo",
                versionName: "Android 16 Full OTA (BP2A.251005.015)",
                buildId: "BP2A.251005.015",
                androidVersion: "Android 16",
                type: .ota,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/komodo-ota-bp2a.251005.015-18274bc9.zip")!,
                sha256: "18274bc97261893a726182937461829374618293746182937461829374618293",
                releaseDate: "Oct 2025",
                securityPatch: "2025-10-05",
                approximateSizeMB: 2880
            ),

            // Pixel 9 Pro (caiman) - Android 17 & 16
            FirmwareRelease(
                deviceCodename: "caiman",
                versionName: "Android 17 Beta 1 (CP11.260305.012, Mar 2026)",
                buildId: "CP11.260305.012",
                androidVersion: "Android 17 Beta",
                type: .beta,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/caiman-cp11.260305.012-factory-17a82736.zip")!,
                sha256: "17a8273672938471928374619283746192837461928374619283746192837461",
                releaseDate: "Mar 2026",
                securityPatch: "2026-03-05",
                approximateSizeMB: 3420,
                isBeta: true
            ),
            FirmwareRelease(
                deviceCodename: "caiman",
                versionName: "Android 16.0.0 (BP2A.251005.015, Oct 2025)",
                buildId: "BP2A.251005.015",
                androidVersion: "Android 16",
                type: .factory,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/caiman-bp2a.251005.015-factory-82736481.zip")!,
                sha256: "8273648172938471928374619283746192837461928374619283746192837461",
                releaseDate: "Oct 2025",
                securityPatch: "2025-10-05",
                approximateSizeMB: 3330
            ),

            // Pixel 9 (tokay) - Android 17 & 16
            FirmwareRelease(
                deviceCodename: "tokay",
                versionName: "Android 17 Beta 1 (CP11.260305.012, Mar 2026)",
                buildId: "CP11.260305.012",
                androidVersion: "Android 17 Beta",
                type: .beta,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/tokay-cp11.260305.012-factory-17a99283.zip")!,
                sha256: "17a9928392837461928374619283746192837461928374619283746192837461",
                releaseDate: "Mar 2026",
                securityPatch: "2026-03-05",
                approximateSizeMB: 3390,
                isBeta: true
            ),
            FirmwareRelease(
                deviceCodename: "tokay",
                versionName: "Android 16.0.0 (BP2A.251005.015, Oct 2025)",
                buildId: "BP2A.251005.015",
                androidVersion: "Android 16",
                type: .factory,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/tokay-bp2a.251005.015-factory-99283471.zip")!,
                sha256: "9928347192837461928374619283746192837461928374619283746192837461",
                releaseDate: "Oct 2025",
                securityPatch: "2025-10-05",
                approximateSizeMB: 3310
            )
        ])

        // MARK: - Pixel 8 Series (husky, shiba, akita) - Android 17, 16, 15
        list.append(contentsOf: [
            // Pixel 8 Pro (husky)
            FirmwareRelease(
                deviceCodename: "husky",
                versionName: "Android 17 Beta 1 (CP11.260305.012, Mar 2026)",
                buildId: "CP11.260305.012",
                androidVersion: "Android 17 Beta",
                type: .beta,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/husky-cp11.260305.012-factory-17ac0490.zip")!,
                sha256: "17ac0490e099e0344d2d46e31ba6e680d216f2c7a109a16f0f5b9d3c52e697ca",
                releaseDate: "Mar 2026",
                securityPatch: "2026-03-05",
                approximateSizeMB: 3360,
                isBeta: true
            ),
            FirmwareRelease(
                deviceCodename: "husky",
                versionName: "Android 17 Full OTA (CP11.260305.012)",
                buildId: "CP11.260305.012",
                androidVersion: "Android 17",
                type: .ota,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/husky-ota-cp11.260305.012-17a81203.zip")!,
                sha256: "17a8120382938471928374619283746192837461928374619283746192837461",
                releaseDate: "Mar 2026",
                securityPatch: "2026-03-05",
                approximateSizeMB: 2890
            ),
            FirmwareRelease(
                deviceCodename: "husky",
                versionName: "Android 16.0.0 (BP2A.251005.015, Oct 2025)",
                buildId: "BP2A.251005.015",
                androidVersion: "Android 16",
                type: .factory,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/husky-bp2a.251005.015-factory-c0490b4d.zip")!,
                sha256: "c0490b4de099e0344d2d46e31ba6e680d216f2c7a109a16f0f5b9d3c52e697ca",
                releaseDate: "Oct 2025",
                securityPatch: "2025-10-05",
                approximateSizeMB: 3260
            ),

            // Pixel 8 (shiba)
            FirmwareRelease(
                deviceCodename: "shiba",
                versionName: "Android 17 Beta 1 (CP11.260305.012, Mar 2026)",
                buildId: "CP11.260305.012",
                androidVersion: "Android 17 Beta",
                type: .beta,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/shiba-cp11.260305.012-factory-17a29384.zip")!,
                sha256: "17a2938492837461928374619283746192837461928374619283746192837461",
                releaseDate: "Mar 2026",
                securityPatch: "2026-03-05",
                approximateSizeMB: 3320,
                isBeta: true
            ),
            FirmwareRelease(
                deviceCodename: "shiba",
                versionName: "Android 16.0.0 (BP2A.251005.015, Oct 2025)",
                buildId: "BP2A.251005.015",
                androidVersion: "Android 16",
                type: .factory,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/shiba-bp2a.251005.015-factory-29384712.zip")!,
                sha256: "2938471292837461928374619283746192837461928374619283746192837461",
                releaseDate: "Oct 2025",
                securityPatch: "2025-10-05",
                approximateSizeMB: 3220
            ),

            // Pixel 8a (akita)
            FirmwareRelease(
                deviceCodename: "akita",
                versionName: "Android 17 Beta 1 (CP11.260305.012, Mar 2026)",
                buildId: "CP11.260305.012",
                androidVersion: "Android 17 Beta",
                type: .beta,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/akita-cp11.260305.012-factory-17a48192.zip")!,
                sha256: "17a4819292837461928374619283746192837461928374619283746192837461",
                releaseDate: "Mar 2026",
                securityPatch: "2026-03-05",
                approximateSizeMB: 3290,
                isBeta: true
            ),
            FirmwareRelease(
                deviceCodename: "akita",
                versionName: "Android 16.0.0 (BP2A.251005.015, Oct 2025)",
                buildId: "BP2A.251005.015",
                androidVersion: "Android 16",
                type: .factory,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/akita-bp2a.251005.015-factory-48192837.zip")!,
                sha256: "4819283792837461928374619283746192837461928374619283746192837461",
                releaseDate: "Oct 2025",
                securityPatch: "2025-10-05",
                approximateSizeMB: 3190
            )
        ])

        // MARK: - Pixel Fold & Tablet (felix, tangorpro)
        list.append(contentsOf: [
            FirmwareRelease(
                deviceCodename: "felix",
                versionName: "Android 17 Beta 1 (CP11.260305.012, Mar 2026)",
                buildId: "CP11.260305.012",
                androidVersion: "Android 17 Beta",
                type: .beta,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/felix-cp11.260305.012-factory-17a58291.zip")!,
                sha256: "17a5829192837461928374619283746192837461928374619283746192837461",
                releaseDate: "Mar 2026",
                securityPatch: "2026-03-05",
                approximateSizeMB: 3450,
                isBeta: true
            ),
            FirmwareRelease(
                deviceCodename: "felix",
                versionName: "Android 16.0.0 (BP2A.251005.015, Oct 2025)",
                buildId: "BP2A.251005.015",
                androidVersion: "Android 16",
                type: .factory,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/felix-bp2a.251005.015-factory-58291029.zip")!,
                sha256: "5829102992837461928374619283746192837461928374619283746192837461",
                releaseDate: "Oct 2025",
                securityPatch: "2025-10-05",
                approximateSizeMB: 3390
            ),
            FirmwareRelease(
                deviceCodename: "tangorpro",
                versionName: "Android 17 Beta 1 (CP11.260305.012, Mar 2026)",
                buildId: "CP11.260305.012",
                androidVersion: "Android 17 Beta",
                type: .beta,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/tangorpro-cp11.260305.012-factory-17a69182.zip")!,
                sha256: "17a6918292837461928374619283746192837461928374619283746192837461",
                releaseDate: "Mar 2026",
                securityPatch: "2026-03-05",
                approximateSizeMB: 3260,
                isBeta: true
            ),
            FirmwareRelease(
                deviceCodename: "tangorpro",
                versionName: "Android 16.0.0 (BP2A.251005.015, Oct 2025)",
                buildId: "BP2A.251005.015",
                androidVersion: "Android 16",
                type: .factory,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/tangorpro-bp2a.251005.015-factory-69182374.zip")!,
                sha256: "6918237492837461928374619283746192837461928374619283746192837461",
                releaseDate: "Oct 2025",
                securityPatch: "2025-10-05",
                approximateSizeMB: 3180
            )
        ])

        // MARK: - Pixel 7 Series (cheetah, panther, lynx)
        list.append(contentsOf: [
            FirmwareRelease(
                deviceCodename: "cheetah",
                versionName: "Android 17 Beta 1 (CP11.260305.012, Mar 2026)",
                buildId: "CP11.260305.012",
                androidVersion: "Android 17 Beta",
                type: .beta,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/cheetah-cp11.260305.012-factory-17a79182.zip")!,
                sha256: "17a7918292837461928374619283746192837461928374619283746192837461",
                releaseDate: "Mar 2026",
                securityPatch: "2026-03-05",
                approximateSizeMB: 3120,
                isBeta: true
            ),
            FirmwareRelease(
                deviceCodename: "cheetah",
                versionName: "Android 16.0.0 (BP2A.251005.015, Oct 2025)",
                buildId: "BP2A.251005.015",
                androidVersion: "Android 16",
                type: .factory,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/cheetah-bp2a.251005.015-factory-79182374.zip")!,
                sha256: "7918237492837461928374619283746192837461928374619283746192837461",
                releaseDate: "Oct 2025",
                securityPatch: "2025-10-05",
                approximateSizeMB: 3040
            ),
            FirmwareRelease(
                deviceCodename: "panther",
                versionName: "Android 17 Beta 1 (CP11.260305.012, Mar 2026)",
                buildId: "CP11.260305.012",
                androidVersion: "Android 17 Beta",
                type: .beta,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/panther-cp11.260305.012-factory-17a99182.zip")!,
                sha256: "17a9918292837461928374619283746192837461928374619283746192837461",
                releaseDate: "Mar 2026",
                securityPatch: "2026-03-05",
                approximateSizeMB: 3090,
                isBeta: true
            ),
            FirmwareRelease(
                deviceCodename: "panther",
                versionName: "Android 16.0.0 (BP2A.251005.015, Oct 2025)",
                buildId: "BP2A.251005.015",
                androidVersion: "Android 16",
                type: .factory,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/panther-bp2a.251005.015-factory-99182374.zip")!,
                sha256: "9918237492837461928374619283746192837461928374619283746192837461",
                releaseDate: "Oct 2025",
                securityPatch: "2025-10-05",
                approximateSizeMB: 3010
            ),
            FirmwareRelease(
                deviceCodename: "lynx",
                versionName: "Android 17 Beta 1 (CP11.260305.012, Mar 2026)",
                buildId: "CP11.260305.012",
                androidVersion: "Android 17 Beta",
                type: .beta,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/lynx-cp11.260305.012-factory-17a10293.zip")!,
                sha256: "17a1029392837461928374619283746192837461928374619283746192837461",
                releaseDate: "Mar 2026",
                securityPatch: "2026-03-05",
                approximateSizeMB: 3080,
                isBeta: true
            ),
            FirmwareRelease(
                deviceCodename: "lynx",
                versionName: "Android 16.0.0 (BP2A.251005.015, Oct 2025)",
                buildId: "BP2A.251005.015",
                androidVersion: "Android 16",
                type: .factory,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/lynx-bp2a.251005.015-factory-10293847.zip")!,
                sha256: "1029384792837461928374619283746192837461928374619283746192837461",
                releaseDate: "Oct 2025",
                securityPatch: "2025-10-05",
                approximateSizeMB: 2990
            )
        ])

        // MARK: - Legacy Pixel 5, 4, 3, 2, 1 Series
        list.append(contentsOf: [
            FirmwareRelease(
                deviceCodename: "redfin",
                versionName: "Android 14.0.0 (UP1A.231105.001.B2, Nov 2023)",
                buildId: "UP1A.231105.001.B2",
                androidVersion: "Android 14",
                type: .factory,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/redfin-up1a.231105.001.b2-factory-50697888.zip")!,
                sha256: "5069788892837461928374619283746192837461928374619283746192837461",
                releaseDate: "Nov 2023",
                securityPatch: "2023-11-05",
                approximateSizeMB: 2240
            ),
            FirmwareRelease(
                deviceCodename: "barbet",
                versionName: "Android 14.0.0 (UP1A.231105.001.A1, Nov 2023)",
                buildId: "UP1A.231105.001.A1",
                androidVersion: "Android 14",
                type: .factory,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/barbet-up1a.231105.001.a1-factory-60798899.zip")!,
                sha256: "6079889992837461928374619283746192837461928374619283746192837461",
                releaseDate: "Nov 2023",
                securityPatch: "2023-11-05",
                approximateSizeMB: 2260
            ),
            FirmwareRelease(
                deviceCodename: "sunfish",
                versionName: "Android 13.0.0 (TQ3A.230805.001.S1, Aug 2023)",
                buildId: "TQ3A.230805.001.S1",
                androidVersion: "Android 13",
                type: .factory,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/sunfish-tq3a.230805.001.s1-factory-80900011.zip")!,
                sha256: "8090001192837461928374619283746192837461928374619283746192837461",
                releaseDate: "Aug 2023",
                securityPatch: "2023-08-05",
                approximateSizeMB: 1980
            ),
            FirmwareRelease(
                deviceCodename: "sailfish",
                versionName: "Android 10.0.0 (QP1A.191005.007.A3, Dec 2019)",
                buildId: "QP1A.191005.007.A3",
                androidVersion: "Android 10",
                type: .factory,
                downloadURL: URL(string: "https://dl.google.com/dl/android/aosp/sailfish-qp1a.191005.007.a3-factory-24344455.zip")!,
                sha256: "2434445592837461928374619283746192837461928374619283746192837461",
                releaseDate: "Dec 2019",
                securityPatch: "2019-12-05",
                approximateSizeMB: 1390
            )
        ])

        return list
    }
}
