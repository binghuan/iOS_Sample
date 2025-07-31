# iOS Sample Projects

A collection of iOS sample applications demonstrating various iOS SDK features and extension points. This repository contains four main projects showcasing different aspects of iOS development including Action Extensions, Photo Editing Extensions, Unit Conversion, and Network Extensions.

## Projects Overview

### 1. ConvertMe ObjC - Action Extension Demo
**Location:** `ConvertMe ObjC/`

A demonstration of iOS Action Extensions that allows users to convert measurements (meters to feet and vice versa) directly from Safari or other apps using the share sheet.

**Features:**
- Action Extension for unit conversion
- Supports meter to feet conversion
- Supports feet to meter conversion
- Uses regular expressions to find and replace measurements in web content
- Integrates with iOS share sheet

**Key Files:**
- `ActionViewController.m` - Main extension logic with conversion algorithms
- `extension_js.js` - JavaScript preprocessing for web content
- Conversion rates: 1 meter = 3.2808399 feet, 1 foot = 0.3048 meters

**Requirements:** iOS 8.0+

### 2. ImageInverter - Creating Action Extensions
**Location:** `ImageInverterCreatingActionExtensions/`

Sample code demonstrating how to create Action Extensions with view controllers for image manipulation.

**Features:**
- Action extension for image processing
- Vertical image flipping functionality
- Communication between host app and extension using NSExtensionItem and NSItemProvider
- Integration with UIActivityViewController

**Key Components:**
- Host app with image sharing capabilities
- Extension that processes and returns modified images
- Basic NSExtensionContext interaction

**Requirements:** iOS 8.0+ SDK, Xcode 6.0+

### 3. Photo Filter - Photo Editing Extension
**Location:** `SamplePhotoEditingExtension/`

Implementation of a Photo Editing Extension that integrates with the Photos app to apply various filter effects.

**Features:**
- Photo Editing Extension for Photos app integration
- Multiple filter effects:
  - Sepia Tone (CISepiaTone)
  - Chrome Effect (CIPhotoEffectChrome)
  - Instant/Fade Effect (CIPhotoEffectInstant)
  - Color Invert (CIColorInvert)
  - Posterize (CIColorPosterize)
- Support for both photos and videos
- Preview thumbnails for each filter

**Setup Instructions:**
1. Run the Photo Filter app to install it
2. Edit a photo/video in Photos app
3. Tap the extension icon (three dots in circle)
4. Tap "More" and enable "Photo Filter"

**Requirements:** iOS 8.0+ SDK

### 4. SimpleTunnel - Network Extension Framework
**Location:** `SimpleTunnelCustomizedNetworkingUsingtheNetworkExtensionFramework/`

Comprehensive example demonstrating all four extension points of the Network Extension framework.

**Network Extension Points:**

1. **Packet Tunnel Provider** (`PacketTunnel/`)
   - Custom network tunneling protocol
   - Encapsulates network data as IP packets
   - Client-side tunnel implementation

2. **App Proxy Provider** (`AppProxy/`)
   - Custom network proxy protocol
   - Handles application network data flows
   - Supports both TCP and UDP flows

3. **Filter Data Provider** (`FilterDataProvider/`)
   - On-device network content filtering
   - Examines network data for pass/block decisions
   - Sandboxed for security

4. **Filter Control Provider** (`FilterControlProvider/`)
   - Updates filtering rules
   - Network communication and disk access
   - Manages filter configurations

**Additional Components:**
- **SimpleTunnel App** - Main application with extension management
- **Tunnel Server** (`tunnel_server/`) - macOS command-line server implementation
- **Shared Services** (`SimpleTunnelServices/`) - Common networking code

**Server Usage:**
```bash
sudo tunnel_server <port> <path-to-config-plist>
```

**Requirements:**
- **Runtime:** iOS 9.0+ / macOS 11.0+
- **Build:** Xcode 8.0+, iOS 9.0 SDK / macOS 11.0 SDK
- **Special Entitlement Required:**
  ```xml
  <key>com.apple.developer.networking.networkextension</key>
  <array>
      <string>packet-tunnel-provider</string>
      <string>app-proxy-provider</string>
      <string>content-filter-provider</string>
  </array>
  ```
  Request entitlement by emailing: networkextension@apple.com

## Development Environment

- **Platform:** iOS Development
- **Language:** Objective-C (primarily), Swift (SimpleTunnel)
- **IDE:** Xcode
- **Frameworks:** UIKit, Network Extension, Photos, Core Image, Mobile Core Services

## Getting Started

1. Clone the repository
2. Open the desired project's `.xcodeproj` file in Xcode
3. For Network Extension projects, ensure proper entitlements are configured
4. Build and run on device (extensions require device testing)

## Extension Integration

Most projects demonstrate iOS App Extensions which require:
- Installation of the host app
- Manual enabling of extensions in iOS Settings or through share sheets
- Device testing (extensions don't work in simulator for full functionality)

## References

- [Apple Developer Documentation - App Extensions](https://developer.apple.com/app-extensions/)
- [Network Extension Framework](https://developer.apple.com/documentation/networkextension)
- [Photos Framework](https://developer.apple.com/documentation/photos)

---

*This repository serves as a learning resource for iOS extension development and advanced networking capabilities.*
