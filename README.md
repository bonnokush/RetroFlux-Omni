# RetroFlux Omni

> **Universal Cross-Platform File Converter & Media Studio**  
> *Version: 1.0.0+1 • Production Release*

RetroFlux Omni is an enterprise-grade, privacy-first universal file conversion studio built natively with Flutter, Dart isolates, and high-performance system engines. It features a Google Pixel-inspired **Material 3 (Material You)** dynamic interface, offline cryptographic license gating, and multi-format batch conversion across Media, Images, Documents, and Data.

---

## Key Highlights

- **Google Pixel Material 3 (Material You)**:
  - Native tonal surface hierarchy (`surfaceContainerLow`, `surfaceContainer`, `surfaceContainerHigh`) with zero 1px borders or synthetic neon glows.
  - Smooth 24px–28px radii and capsule stadium buttons (`BorderRadius.circular(100)`).
  - Dynamic wallpaper accent extraction via `dynamic_color` with 5 built-in Google Pixel seed presets (Bay Blue, Sage Green, Obsidian Lavender, Terracotta, Amber Gold).
- **Google Product Sans Typography**:
  - Embedded native Product Sans TrueType fonts (Regular, Bold, Italic, Bold-Italic) for pixel-perfect rendering across Windows, Linux, Android, iOS, and Web.
- **Dedicated Studios**:
  - **Microsoft Office & Docs Studio**: Standalone native OpenXML parsing and generation for Word (`.docx`, `.doc`), Excel (`.xlsx`, `.xls`), PowerPoint (`.pptx`, `.ppt`), PDF, Markdown, HTML, CSV, and JSON without needing Microsoft Office installed.
  - **Media Studio**: Audio & video transcoding (AV1, HEVC, ProRes, WebM, MP4, MP3, FLAC, Opus) with hardware acceleration options (NVENC, QSV, VideoToolbox).
  - **Image Studio & Compressor**: Multi-format image conversion (PNG, JPG, WebP, AVIF, SVG, ICO) with quality and resolution downscaling.
  - **Universal Batch Queue & History**: Drag-and-drop file ingestion, isolate-powered non-blocking worker pools, and export history management.
- **Offline Cryptographic Licensing**:
  - Zero-DRM offline validation powered by HMAC-SHA256 tokenization.
  - Free Tier (max 3 batch items, 1080p cap, standard formats) vs PRO Tier (unlimited queue, 4K export, AV1/HEVC hardware acceleration).

---

## Architecture Overview

```
RetroFlux-Omni/
├── assets/
│   └── fonts/                 # Embedded Google Product Sans TTF font family
├── lib/
│   ├── core/
│   │   ├── engine_bridge.dart    # Abstract multi-engine dispatcher (FFmpeg, C++, OpenXML)
│   │   ├── license_service.dart  # Offline HMAC-SHA256 signature validation & storage
│   │   ├── office_engine.dart    # Native OpenXML Word, Excel, PPT & PDF processor
│   │   ├── theme_controller.dart # Reactive Material You dynamic theme & Pixel seeds
│   │   └── worker_isolate.dart   # Background isolate worker pools for zero UI thread blocking
│   ├── ui/
│   │   ├── adaptive_scaffold.dart# Responsive layout (Desktop multi-column vs Mobile drawer)
│   │   ├── dashboard_screen.dart # Universal Drag-and-Drop Drop Zone & Batch Queue
│   │   ├── palette_switcher.dart # Live Material You accent palette & theme modal
│   │   ├── pro_modal.dart        # PRO tier activation dialog & offline license manager
│   │   ├── theme.dart            # M3 dark/light tonal tokens & color palette
│   │   └── studios/
│   │       ├── docs_studio.dart  # Microsoft Office & Document Conversion Studio
│   │       ├── history_view.dart # Export history & file reveal manager
│   │       ├── image_studio.dart # Image Studio & Multi-format Compressor
│   │       └── media_studio.dart # Video & Audio Transcoder Studio
│   └── main.dart                 # Application entry point with DynamicColorBuilder
├── test/
│   ├── e2e_ui_audit_test.dart        # Comprehensive E2E automated UI audit
│   ├── material_you_theme_test.dart  # Theme controller & palette switching tests
│   └── office_and_studios_test.dart  # OpenXML engine & studio navigation tests
└── pubspec.yaml
```

---

## Getting Started

### Prerequisites
- **Flutter SDK**: `>= 3.24.0` (Dart SDK `>= 3.5.0`)
- **Desktop C++ Build Tools**: Visual Studio 2022 (with "Desktop development with C++") on Windows; standard toolchains on Linux/macOS.
- **Chrome / Web Browser**: For instant zero-restriction web preview.

### Installation & Dependency Setup
```powershell
# Clone or navigate to the repository
cd RetroFlux-Omni

# Fetch dependencies
flutter pub get
```

### Running the App

#### Web (Chrome / Edge)
```powershell
flutter run -d chrome --web-port=8080
```
Then navigate to `http://localhost:8080`.

#### Windows Desktop
```powershell
flutter run -d windows
```

#### Android
```powershell
# Launch emulator
flutter emulators --launch KinemotoTestDevice

# Run debug build
flutter run -d KinemotoTestDevice
```

---

## Automated Testing & Quality Assurance

Run the complete test suite and static code analyzer:

```powershell
# Run static analysis (0 warnings / 0 errors required)
flutter analyze

# Run all automated unit, widget, and E2E integration tests
flutter test
```

### Test Coverage
- **E2E UI & Behavior Audit**: Launch tree integrity, sidebar navigation, free-tier queue overflow modals, responsive breakpoint scaling.
- **Office Engine Tests**: OpenXML generation for Word, Excel, PowerPoint, and PDF document pipelines.
- **Theme & Dynamic Palette Tests**: Seed color switching, dark/light mode switches, dynamic color persistence.

---

## License

Proprietary software. All rights reserved.
Built with Google Flutter & Material 3.
