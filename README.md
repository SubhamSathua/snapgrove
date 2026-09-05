<!--
# RULES for README.md
- no emojies.
- the intro description will be design based on: main feature, functionality at first of the sentence as nobody reads full sentence so they must learn just by reading few first words of sentence.
-->

# Snapgrove

**Organize screenshots and images into tagged subfolders instantly.**

Snapgrove is a cross-platform visual screenshot organizer built for Windows, Android, and Web. It allows you to sort cluttered screenshot directories into dedicated folders (tags) with batch selection and responsive grid navigation.

**Use Case:**
Users accumulate hundreds or thousands of screenshots across desktops, phones, and browsers. Instead of navigating tedious file managers, Snapgrove provides a clean visual workspace to batch-select, preview, sort, and move images into custom subfolders in seconds.

---

## # Index
- [Features](#-features)
- [How to install](#-how-to-install)
- [How to contribute](#-how-to-contribute)
- [Requirements](#-requirements)
- [Troubleshooting](#-troubleshooting)
- [License & Legal](#-license--legal)
- [Privacy Policy](#-privacy-policy)
- [Links](#-links)
- [Contact](#-contact)

---

## # Features
- **Tag-Based Organization:** Move screenshots into subfolder tags with single-click batch actions.
- **Cross-Platform Support:** Run natively on Windows, Android (Storage Access Framework), and modern Web browsers.
- **High-Performance Grid:** Render over 2,000 images smoothly with LRU thumbnail caching and virtualized slivers.
- **Natural Sorting:** Organize files by date modified, natural alphanumeric name, or file size in ascending/descending order.
- **Dynamic Theming:** Switch instantly between System, Light, and Dark modes across all views and modals.
- **Safe Selection Mode:** Protect your workflow with custom discard confirmations on Escape or Back navigation.
- **Full-Screen Viewer:** Inspect images with double-tap zoom, gesture panning, and keyboard navigation.

---

## # How to install

> **Releases:** [Download the latest release here](https://github.com/SubhamSathua/snapgrove/releases)

### Windows
1. **Download & Extract:** Unzip the Windows release package to any directory.
2. **Launch Application:** Double-click `snapgrove.exe` to start the organizer.
3. **Select Screenshot Directory:** Click "Browse" or "Screenshot Folder" to begin managing images.

### Android
1. **Install APK:** Download and install `snapgrove.apk` on your Android device.
2. **Grant Directory Access:** Use the system folder picker (Storage Access Framework) to select your screenshot directory.

### Web
1. **Access Web App:** Open the hosted web application in any modern Chromium or WebKit browser.
2. **Pick Directory:** Click "Browse" to authorize directory access via the File System Access API.

---

## # How to contribute
Contributions are welcome. Follow these steps to set up your local development environment:

1. **Clone the Repo:**
   ```bash
   git clone https://github.com/SubhamSathua/snapgrove.git
   cd snapgrove
   ```
2. **Install Dependencies:**
   ```bash
   flutter pub get
   ```
3. **Run Code Analysis & Tests:**
   ```bash
   flutter analyze
   flutter test
   ```
4. **Run Application:**
   ```bash
   flutter run -d windows    # Windows desktop
   flutter run -d chrome     # Web browser
   flutter run -d android    # Android device/emulator
   ```
5. **Bump Version:**
   ```powershell
   .\bump_version.ps1 -Type patch
   ```

---

## # Requirements
- **Flutter:** Flutter SDK 3.24.0 or higher.
- **Dart:** Dart SDK 3.5.0 or higher.
- **Windows:** Windows 10 or 11 (64-bit).
- **Android:** Android 8.0 (API 26) or higher.
- **Web:** Modern browser with File System Access API support (Chrome, Edge, Brave, Opera).

---

## # Troubleshooting
- **No Images Found:** Ensure the selected folder contains valid image formats (`.png`, `.jpg`, `.jpeg`, `.webp`).
- **Android Permission Denied:** Re-select the folder using the system file picker to grant SAF read/write URI permissions.
- **Web Directory Access:** Ensure your browser is not running in an incognito window that blocks File System Access permissions.

---

## # License & Legal
This project is licensed under the **Apache License 2.0**.

**Liability Protection:** The author provides this software "as is" without warranties. By using this software, you agree that the author is not liable for any damages, data loss, or system issues resulting from its use.

**Modifications:** If you modify and distribute this software, you must:
1. Retain all original copyright notices.
2. Include a copy of the Apache License 2.0.
3. Protect the original author from any liability claims arising from your modified version.

---

## # Privacy Policy
- **100% Local:** All image indexing, thumbnail generation, and file operations happen strictly on your local device.
- **No Internet Required:** The application operates completely offline without network connections.
- **No Telemetry:** Zero analytics, zero usage tracking, and zero background telemetry services.

---

## # Links
- [Source Code](https://github.com/SubhamSathua/snapgrove) - GitHub repository.
- [Report an Issue](https://github.com/SubhamSathua/snapgrove/issues) - Bug reports and feature requests.
- [Security Policy](SECURITY.md) - Vulnerability reporting and guidelines.
- [Apache 2.0 License](LICENSE) - Legal licensing details.

---

## # Contact
**Author:** Subham Kumar Sathua
**GitHub:** [@SubhamSathua](https://github.com/SubhamSathua)
**Repository:** [https://github.com/SubhamSathua/snapgrove](https://github.com/SubhamSathua/snapgrove)

---
Copyright (c) 2026 Subham Kumar Sathua. Licensed under the Apache License 2.0.
