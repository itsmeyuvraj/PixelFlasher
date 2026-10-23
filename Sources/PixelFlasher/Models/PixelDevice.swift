import Foundation

public struct PixelDevice: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let codename: String
    public let generation: String
    public let releaseYear: Int
    public let soc: String
    public let hasABSlots: Bool
    public let usesFastbootd: Bool
    public let isTensor: Bool
    public let latestAndroidVersion: String

    public init(
        codename: String,
        name: String,
        generation: String,
        releaseYear: Int,
        soc: String,
        hasABSlots: Bool = true,
        usesFastbootd: Bool = true,
        isTensor: Bool = false,
        latestAndroidVersion: String = "Android 15"
    ) {
        self.id = codename
        self.name = name
        self.codename = codename
        self.generation = generation
        self.releaseYear = releaseYear
        self.soc = soc
        self.hasABSlots = hasABSlots
        self.usesFastbootd = usesFastbootd
        self.isTensor = isTensor
        self.latestAndroidVersion = latestAndroidVersion
    }

    /// Complete catalog of all Google Pixel devices
    public static let allDevices: [PixelDevice] = [
        // Pixel 9 Series (Tensor G4)
        PixelDevice(codename: "comet", name: "Pixel 9 Pro Fold", generation: "Pixel 9 Series", releaseYear: 2024, soc: "Google Tensor G4", isTensor: true, latestAndroidVersion: "Android 17"),
        PixelDevice(codename: "komodo", name: "Pixel 9 Pro XL", generation: "Pixel 9 Series", releaseYear: 2024, soc: "Google Tensor G4", isTensor: true, latestAndroidVersion: "Android 17"),
        PixelDevice(codename: "caiman", name: "Pixel 9 Pro", generation: "Pixel 9 Series", releaseYear: 2024, soc: "Google Tensor G4", isTensor: true, latestAndroidVersion: "Android 17"),
        PixelDevice(codename: "tokay", name: "Pixel 9", generation: "Pixel 9 Series", releaseYear: 2024, soc: "Google Tensor G4", isTensor: true, latestAndroidVersion: "Android 17"),

        // Pixel 8 Series (Tensor G3)
        PixelDevice(codename: "akita", name: "Pixel 8a", generation: "Pixel 8 Series", releaseYear: 2024, soc: "Google Tensor G3", isTensor: true, latestAndroidVersion: "Android 17"),
        PixelDevice(codename: "husky", name: "Pixel 8 Pro", generation: "Pixel 8 Series", releaseYear: 2023, soc: "Google Tensor G3", isTensor: true, latestAndroidVersion: "Android 17"),
        PixelDevice(codename: "shiba", name: "Pixel 8", generation: "Pixel 8 Series", releaseYear: 2023, soc: "Google Tensor G3", isTensor: true, latestAndroidVersion: "Android 17"),

        // Pixel Fold & Tablet
        PixelDevice(codename: "felix", name: "Pixel Fold", generation: "Foldable & Tablet", releaseYear: 2023, soc: "Google Tensor G2", isTensor: true, latestAndroidVersion: "Android 17"),
        PixelDevice(codename: "tangorpro", name: "Pixel Tablet", generation: "Foldable & Tablet", releaseYear: 2023, soc: "Google Tensor G2", isTensor: true, latestAndroidVersion: "Android 17"),

        // Pixel 7 Series (Tensor G2)
        PixelDevice(codename: "lynx", name: "Pixel 7a", generation: "Pixel 7 Series", releaseYear: 2023, soc: "Google Tensor G2", isTensor: true, latestAndroidVersion: "Android 17"),
        PixelDevice(codename: "cheetah", name: "Pixel 7 Pro", generation: "Pixel 7 Series", releaseYear: 2022, soc: "Google Tensor G2", isTensor: true, latestAndroidVersion: "Android 17"),
        PixelDevice(codename: "panther", name: "Pixel 7", generation: "Pixel 7 Series", releaseYear: 2022, soc: "Google Tensor G2", isTensor: true, latestAndroidVersion: "Android 17"),

        // Pixel 6 Series (Tensor G1)
        PixelDevice(codename: "bluejay", name: "Pixel 6a", generation: "Pixel 6 Series", releaseYear: 2022, soc: "Google Tensor", isTensor: true, latestAndroidVersion: "Android 17"),
        PixelDevice(codename: "raven", name: "Pixel 6 Pro", generation: "Pixel 6 Series", releaseYear: 2021, soc: "Google Tensor", isTensor: true, latestAndroidVersion: "Android 17"),
        PixelDevice(codename: "oriole", name: "Pixel 6", generation: "Pixel 6 Series", releaseYear: 2021, soc: "Google Tensor", isTensor: true, latestAndroidVersion: "Android 17"),

        // Pixel 5 Series (Snapdragon)
        PixelDevice(codename: "barbet", name: "Pixel 5a (5G)", generation: "Pixel 5 Series", releaseYear: 2021, soc: "Qualcomm Snapdragon 765G", isTensor: false, latestAndroidVersion: "Android 14"),
        PixelDevice(codename: "redfin", name: "Pixel 5", generation: "Pixel 5 Series", releaseYear: 2020, soc: "Qualcomm Snapdragon 765G", isTensor: false, latestAndroidVersion: "Android 14"),

        // Pixel 4 Series
        PixelDevice(codename: "bramble", name: "Pixel 4a (5G)", generation: "Pixel 4 Series", releaseYear: 2020, soc: "Qualcomm Snapdragon 765G", isTensor: false, latestAndroidVersion: "Android 14"),
        PixelDevice(codename: "sunfish", name: "Pixel 4a", generation: "Pixel 4 Series", releaseYear: 2020, soc: "Qualcomm Snapdragon 730G", isTensor: false, latestAndroidVersion: "Android 13"),
        PixelDevice(codename: "coral", name: "Pixel 4 XL", generation: "Pixel 4 Series", releaseYear: 2019, soc: "Qualcomm Snapdragon 855", isTensor: false, latestAndroidVersion: "Android 13"),
        PixelDevice(codename: "flame", name: "Pixel 4", generation: "Pixel 4 Series", releaseYear: 2019, soc: "Qualcomm Snapdragon 855", isTensor: false, latestAndroidVersion: "Android 13"),

        // Pixel 3 Series
        PixelDevice(codename: "bonito", name: "Pixel 3a XL", generation: "Pixel 3 Series", releaseYear: 2019, soc: "Qualcomm Snapdragon 670", isTensor: false, latestAndroidVersion: "Android 12"),
        PixelDevice(codename: "sargo", name: "Pixel 3a", generation: "Pixel 3 Series", releaseYear: 2019, soc: "Qualcomm Snapdragon 670", isTensor: false, latestAndroidVersion: "Android 12"),
        PixelDevice(codename: "crosshatch", name: "Pixel 3 XL", generation: "Pixel 3 Series", releaseYear: 2018, soc: "Qualcomm Snapdragon 845", isTensor: false, latestAndroidVersion: "Android 12"),
        PixelDevice(codename: "blueline", name: "Pixel 3", generation: "Pixel 3 Series", releaseYear: 2018, soc: "Qualcomm Snapdragon 845", isTensor: false, latestAndroidVersion: "Android 12"),

        // Pixel 2 Series
        PixelDevice(codename: "taimen", name: "Pixel 2 XL", generation: "Pixel 2 Series", releaseYear: 2017, soc: "Qualcomm Snapdragon 835", usesFastbootd: false, isTensor: false, latestAndroidVersion: "Android 11"),
        PixelDevice(codename: "walleye", name: "Pixel 2", generation: "Pixel 2 Series", releaseYear: 2017, soc: "Qualcomm Snapdragon 835", usesFastbootd: false, isTensor: false, latestAndroidVersion: "Android 11"),

        // Pixel 1 Series (Original)
        PixelDevice(codename: "marlin", name: "Pixel XL", generation: "Pixel 1 Series", releaseYear: 2016, soc: "Qualcomm Snapdragon 821", usesFastbootd: false, isTensor: false, latestAndroidVersion: "Android 10"),
        PixelDevice(codename: "sailfish", name: "Pixel", generation: "Pixel 1 Series", releaseYear: 2016, soc: "Qualcomm Snapdragon 821", usesFastbootd: false, isTensor: false, latestAndroidVersion: "Android 10")
    ]

    public static func find(byCodename codename: String) -> PixelDevice? {
        let clean = codename.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allDevices.first { $0.codename.lowercased() == clean }
    }

    public static var generations: [String] {
        var ordered: [String] = []
        for device in allDevices {
            if !ordered.contains(device.generation) {
                ordered.append(device.generation)
            }
        }
        return ordered
    }
}
