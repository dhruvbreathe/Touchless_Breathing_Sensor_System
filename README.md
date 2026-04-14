# Touchless Breathing Sensor System

An iOS app that detects breathing phases (inhale/exhale) by measuring temperature differences at the nostrils using a **FLIR ONE Edge Pro** thermal camera. Built on top of the Teledyne FLIR Atlas Thermal SDK.

## How it works

Exhaled breath is ~32–34 °C; inhaled ambient air is ~20–22 °C. Pointing the thermal camera at the nostrils and averaging the temperature over a region of interest (ROI) gives a signal that oscillates at breathing frequency (~0.2–0.5 Hz). The peaks are exhales, the troughs are inhales.

The app:

- Discovers and connects to a FLIR ONE Edge Pro over BLE + Wi‑Fi (same handshake the FLIR ONE consumer app uses).
- Streams the thermal frame and overlays an MSX-aligned visible-light image.
- Draws a yellow dashed rectangle marking the ROI on top of the thermal feed.
- Computes **average / min / max** temperature across the ROI every frame and displays them in °C.

## Hardware

- iPhone running iOS 14+.
- FLIR ONE Edge Pro (Wi‑Fi thermal camera). Other FLIR One / Edge models should also work — see `cameraDiscovered(_:)` in `ViewController.swift`.

## Project setup

The FLIR Atlas SDK binaries are **not checked in** (they're large vendor-supplied frameworks). Download them from the FLIR developer portal and drop them into the expected location before building.

### 1. Download the Atlas iOS SDK 2.18.0

Get `atlas-objc-sdk-ios-xcode15-arm64-2.18.0` from the [FLIR developer portal](https://flir.custhelp.com/app/answers/detail/a_id/3220/).

### 2. Place frameworks

The Xcode project references frameworks at `../<Framework>.framework` (i.e. one directory above this project folder). Create that parent layout:

```
<parent>/
├── FLIROneCameraSwift/              ← this repo
├── ThermalSDK.framework
├── liblive666.dylib.framework
├── libavutil.60.dylib.framework
├── libavcodec.62.dylib.framework
├── libavformat.62.dylib.framework
├── libavdevice.62.dylib.framework
├── libavfilter.11.dylib.framework
├── libswscale.9.dylib.framework
└── libswresample.6.dylib.framework
```

### 3. Configure signing

Open `FLIROneCameraSwift.xcodeproj`, select the target → **Signing & Capabilities** → set your Team + a unique Bundle Identifier.

### 4. Build & run on a physical iPhone

Simulator can't connect to the camera's BLE/Wi‑Fi. Use a real device.

## Using the app

1. Launch. Grant Bluetooth permission on first prompt.
2. Power on the FLIR ONE Edge Pro.
3. Tap **Connect Device**. The SDK handles BLE pairing + Wi‑Fi handshake automatically.
4. Once the thermal stream appears, point the camera so your nostrils fall inside the yellow dashed ROI (~15–20 cm away).
5. Watch the avg/min/max label oscillate with each breath — `max` is the clearest breathing signal.

### Recommended VividIR settings for breathing detection

- **Upscale**: Trilateral (no temporal smoothing)
- **Latency**: lowest
- **Denoise**: OFF

These preserve the per-frame signal needed for accurate phase detection.

## Configuration points in `ViewController.swift`

- `ironPalette` (line 16) — `true` for iron (orange/yellow) palette, `false` for grayscale.
- ROI size — currently 30 % × 20 % of the frame, centered. Adjust in `onImageReceived()` (`rectW`, `rectH`) and in `updateROILayer()` together.
- Temperature unit — set to `.CELSIUS` in the `withThermalImage` closure.

## License

The Atlas SDK is proprietary to Teledyne FLIR. This project's source is for educational/research use; refer to FLIR's SDK license for the binaries.
