# RetroFlux Omni

> **Dedicated High-Performance 4K Media Conversion & Transcoding Studio**  
> *Version: 1.0.0+1 • Production Release*

RetroFlux Omni is a privacy-first, hardware-accelerated media conversion engine built natively with Flutter, C++ runner, Dart Isolates, and native FFmpeg pipelines. Engineered specifically for speed, it excels at **4K UHD video transcoding**, **1-second lossless remuxing**, **high-fidelity audio extraction**, and **multithreaded image processing**. It features a Google Pixel-inspired **Material 3 (Material You)** dynamic tonal interface and offline cryptographic license gating.

---

## ⚡ Key Highlights

### 1. Hardware-Accelerated 4K Video Transcoding
- **Automatic GPU Detection**: Intelligently inspects host hardware and unlocks silicon encoding chips:
  - **Intel Iris Xe / Arc**: Intel QuickSync Video (`hevc_qsv`, `h264_qsv`, `av1_qsv`) via `-hwaccel qsv`
  - **NVIDIA GeForce / RTX**: NVENC (`hevc_nvenc`, `h264_nvenc`, `av1_nvenc`) via `-hwaccel cuda`
  - **AMD Radeon**: AMF (`hevc_amf`, `h264_amf`) via `-hwaccel d3d11va`
  - **Multi-Threaded CPU Fallback**: `libx265` and `libx264` with `-threads 0`
- **Resolution Scaling**: Presets for 4K UHD (2160p), 1440p QHD, 1080p FHD, 720p HD, and Original Source.

### 2. ⚡ Instant Lossless Remuxing (`-c copy`)
- Swap video containers (e.g. `MKV` &rarr; `MP4`, `MOV` &rarr; `MP4`, `TS` &rarr; `MKV`, `WebM` &rarr; `MP4`) in **1–2 seconds for 20GB+ 4K files**.
- Direct bitstream copying (`-c:v copy -c:a copy -map 0`) with zero quality loss and zero CPU re-encoding strain.

### 3. High-Fidelity Audio Extraction & Encoding
- Extract or transcode pure audio tracks directly from videos:
  - **MP3**: 320 kbps high-bitrate LAME stereo
  - **FLAC**: Lossless compression
  - **WAV**: Uncompressed PCM 16-bit
  - **AAC / M4A**: 256 kbps studio audio
  - **Opus / OGG**: Modern 192 kbps voice and music codec

### 4. Real-Time Telemetry & Progress
- Dynamic percentage parsing ($\text{Current Time} / \text{Total Duration}$).
- Real-time transcoding metrics: **FPS** (e.g., `142 FPS`), **Encoding Speed** (e.g., `⚡ 3.4x`), and active encoder label.

### 5. Multi-Threaded Image Studio
- Background Dart isolate pool for non-blocking multi-core image conversion and compression (PNG, JPG, WebP, BMP, ICO).

### 6. Google Pixel Material 3 (Material You) Design
- Dynamic tonal surface hierarchy (`surfaceContainerLow`, `surfaceContainer`, `surfaceContainerHigh`) with zero synthetic 1px borders.
- Smooth 24px–28px container radii and stadium pills (`BorderRadius.circular(100)`).
- Embedded native **Product Sans** TrueType typography.
- 5 built-in Google Pixel seed palettes (Bay Blue, Sage Green, Obsidian Lavender, Terracotta, Amber Gold) plus dynamic OS wallpaper extraction.

---

## 📁 Where is the Executable?

Once built, the standalone executable and its runtime dependencies are located in:

### Release Build (Optimized for Distribution)
```
C:\Projects\RetroFlux-Omni\build\windows\x64\runner\Release\retroflux_omni.exe
```
> **Note**: To run or distribute the portable app, copy the entire `Release\` folder (including `retroflux_omni.exe`, `flutter_windows.dll`, companion plugin `.dll` files, and the `data/` directory).

### Debug Build (Development)
```
C:\Projects\RetroFlux-Omni\build\windows\x64\runner\Debug\retroflux_omni.exe
```

---

## Architecture Overview

```
RetroFlux-Omni/
├── assets/
│   └── fonts/                 # Embedded Google Product Sans TTF font family
├── lib/
│   ├── core/
│   │   ├── engine_bridge.dart    # High-performance 4K FFmpeg & GPU hardware dispatcher
│   │   ├── license_service.dart  # Offline HMAC-SHA256 signature validation & storage
│   │   ├── theme_controller.dart # Reactive Material You dynamic theme & Pixel seeds
│   │   └── worker_isolate.dart   # Background isolate worker pools for zero UI thread blocking
│   ├── ui/
│   │   ├── adaptive_scaffold.dart# Responsive Google Pixel navigation drawer & layout
│   │   ├── dashboard_screen.dart # Universal Drag-and-Drop Drop Zone & Batch Queue
│   │   ├── palette_switcher.dart # Live Material You accent palette & theme modal
│   │   ├── pro_modal.dart        # PRO tier activation dialog & offline license manager
│   │   ├── theme.dart            # M3 dark/light tonal tokens & color palette
│   │   └── studios/
│   │       ├── media_studio.dart # 4K Video Transcoder & Lossless Remux Studio
│   │       ├── image_studio.dart # Image Studio & Multi-format Compressor
│   │       └── history_view.dart # Export history & file reveal manager
│   └── main.dart                 # Application entry point with DynamicColorBuilder
├── test/
│   ├── e2e_ui_audit_test.dart        # End-to-end automated UI & queue audit
│   ├── material_you_theme_test.dart  # Theme controller & palette switching tests
│   ├── media_and_studios_test.dart   # 4K Media Studio & hardware capability tests
│   └── widget_test.dart              # Cryptographic license verification tests
└── pubspec.yaml
```

---

## Getting Started

### Prerequisites
- **Flutter SDK**: `>= 3.24.0` (Dart SDK `>= 3.5.0`)
- **Desktop C++ Build Tools**: Visual Studio 2022 (with "Desktop development with C++") on Windows.
- **FFmpeg**: Automatically detected via WinGet (`winget install Gyan.FFmpeg`) or system `PATH`.

### Dependency Setup
```powershell
# Navigate to repository root
cd C:\Projects\RetroFlux-Omni

# Fetch dependencies
flutter pub get
```

### Running the App
```powershell
# Run in debug mode on Windows Desktop
flutter run -d windows
```

### Building the Executable
```powershell
# Build standalone release executable
flutter build windows --release
```
The output `.exe` will be generated in `build\windows\x64\runner\Release\`.

---

## License & Tiers
- **Free Tier**: Up to 3 batch queue items, 1080p FHD resolution cap, standard codecs.
- **PRO Tier**: Unlimited batch queue, **4K UHD (2160p)** resolution export, **Intel QSV / NVIDIA NVENC / AMD AMF hardware acceleration**, and AV1/HEVC modern codecs.
