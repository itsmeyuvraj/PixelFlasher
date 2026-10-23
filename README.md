# Pixel Flasher (SwiftUI for macOS)

A native, high-performance macOS GUI application built with **SwiftUI** to download, verify, flash, and manage official firmware on **all Google Pixel devices**.

---

## ✨ Features

- **Device Support Across All Generations**:
  - Full support for **every Google Pixel device ever released**:
    - **Pixel 9 Series**: Pixel 9, Pixel 9 Pro, Pixel 9 Pro XL, Pixel 9 Pro Fold (`tokay`, `caiman`, `komodo`, `comet`)
    - **Pixel 8 Series**: Pixel 8, Pixel 8 Pro, Pixel 8a (`shiba`, `husky`, `akita`)
    - **Foldables & Tablets**: Pixel Fold, Pixel Tablet (`felix`, `tangorpro`)
    - **Pixel 7 Series**: Pixel 7, Pixel 7 Pro, Pixel 7a (`panther`, `cheetah`, `lynx`)
    - **Pixel 6 Series**: Pixel 6, Pixel 6 Pro, Pixel 6a (`oriole`, `raven`, `bluejay`)
    - **Pixel 5 & 4a Series**: Pixel 5, Pixel 5a (5G), Pixel 4a (5G) (`redfin`, `barbet`, `bramble`)
    - **Legacy Pixel Devices**: Pixel 4 / 4 XL, Pixel 3 / 3 XL / 3a, Pixel 2 / 2 XL, and the original Pixel / Pixel XL (`sailfish`, `marlin`).
- **Official Google Firmware, Beta Releases & OTA Updates**:
  - **Factory Images (Fastboot)**: Complete OS installations, updates, downgrades, and unbricking.
  - **Full OTA Packages (Recovery Sideload)**: Seamless Android updates without wiping bootloader or user data.
  - **Android Beta Program**: Direct downloads and flashing for Android Beta preview releases.
  - **Remote Catalog & Downloader**: Integrated catalog with real-time download speed (MB/s), ETA, and direct "Download & Flash" button.
  - **Local Zip Support**: Choose any locally downloaded `.zip` file from disk.
- **Erase / Wipe User Data Option**:
  - Clean Flash toggle (`-w` flag) with visual safety warnings.
  - Erases userdata and cache for factory-fresh state or dirty flash to preserve data.
- **Lock Bootloader Option**:
  - Automatically executes `fastboot flashing lock` upon successful flash completion.
  - Strict safety checks to ensure only 100% verified stock firmware is locked.
  - Guides user through the required physical confirmation on the Pixel screen.
- **Complete Verification Engine (Pre-Flash & Post-Flash)**:
  - **Pre-Flash Checks**:
    - Streaming hardware-accelerated **SHA-256 Checksum** verification against official Google hashes (low memory footprint for 3GB+ files).
    - Archive inspection (`unzip` structure check).
    - Device codename matching (`android-info.txt` product vs connected device).
  - **Post-Flash Checks**:
    - Partition write status (`bootloader`, `radio`, `super`, `system`, `vendor`, `vbmeta`, etc.).
    - Active boot slot inspection (`current-slot`).
    - Slot health check (`slot-successful:_a` / `slot-successful:_b`).
    - Device reported bootloader and baseband versions matching target firmware.
    - Generates a full diagnostic **Verification Report**.
- **Live Terminal Console**:
  - Real-time streaming subprocess logs with syntax highlighting (OKAY, FAILED, Sending, Writing).
  - Filter logs, auto-scroll, and export to text file.
- **Fastboot & ADB Toolbox**:
  - Switch active slot between A and B.
  - Lock / Unlock bootloader controls.
  - Reboot to Bootloader, Recovery, Fastbootd, or System with 1 click.
  - Query all device fastboot variables (`fastboot getvar all`).

---

## 🚀 How to Run

### Method 1: Launch the macOS App Bundle
The release app bundle has been assembled in the project directory:
```bash
open PixelFlasher.app
```
Or run the bundler script:
```bash
./build_app.sh run
```

### Method 2: Launch via Swift Package Manager
```bash
swift run
```

---

## 🛠️ Requirements
- macOS 14.0 (Sonoma) or newer (tested on macOS 14 / Sequoia / Tahoe).
- Android Platform-Tools (`adb` and `fastboot`).
  - Automatically detected if installed via Homebrew (`/opt/homebrew/bin/fastboot`) or Android SDK.
  - If missing, the app includes a **1-click automatic downloader** in the Settings tab to fetch official Google platform-tools.

---

## 🧪 Running Tests
To run the automated test suite verifying device models, catalog, and verification engine:
```bash
swift test
```
