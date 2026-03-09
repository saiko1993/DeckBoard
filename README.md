# DeskBoard — iOS / iPadOS Shortcut Dashboard

A native **Apple ecosystem app** that turns your iPhone into a customizable shortcut dashboard / control deck, allowing it to control another iPhone, iPad, or Mac over your local Wi-Fi network.

> This project is managed with [Rork](https://rork.com). Changes made via Rork will be committed automatically to this GitHub repo.

---

## ✨ Feature Overview

| Feature | Description |
|---|---|
| 🎛 **Dashboard Grid** | Grid of large, customizable shortcut buttons with icons, colors, and titles |
| 📱 **Multiple Pages** | Organize buttons into multiple pages within each dashboard |
| 📡 **Local Networking** | MultipeerConnectivity for fast, private, LAN-only communication |
| 🔗 **Auto Discovery** | Automatically find nearby devices on the same Wi-Fi network |
| 🔒 **Secure Pairing** | Approval-based pairing with trusted device list |
| 📷 **QR Code Pairing** | Pair instantly by scanning a QR code |
| 🔢 **Pairing Code** | Display a 6-digit code for manual pairing |
| ⚡ **Actions** | Media control, presentation slides, URLs, text snippets, keyboard shortcuts |
| 📲 **Haptic Feedback** | Optional haptic feedback on button press |
| 🌙 **Dark / Light / System** | Full theme support |
| 📤 **Import / Export** | Export dashboards as JSON for backup or sharing |
| 🎯 **Sender & Receiver modes** | Each device chooses its role independently |

---

## 🏗 Architecture

```
Sources/DeskBoard/
├── App/                        # Entry point, AppDelegate, AppState, RootView
├── Core/
│   ├── Models/                 # Dashboard, DeskButton, ButtonAction, CommandMessage, PairedDevice
│   ├── Networking/             # PeerSession (MultipeerConnectivity), CommandEncoder
│   ├── Storage/                # DashboardStore (UserDefaults), TrustedDeviceStore (Keychain)
│   ├── Utilities/              # HapticManager, AppConfiguration
│   └── Extensions/             # Color+hex, String, Date, View extensions
└── Features/
    ├── Onboarding/             # Role selection + welcome screens
    ├── Sender/                 # Dashboard grid, button editor, page picker
    ├── Receiver/               # Incoming command view, permission settings
    ├── Pairing/                # Nearby devices, QR code, pairing code
    └── Settings/               # Device name, role, theme, trusted devices
```

**Design patterns:**
- **MVVM** — All ViewModels with `@Published` + `Combine`
- **@MainActor** — All ViewModels isolated to the main actor
- **SwiftUI** — Fully declarative UI targeting iOS 16+
- **EnvironmentObject** — AppState shared across the entire app

---

## 📡 Connectivity

DeskBoard uses **MultipeerConnectivity** (Apple's peer-to-peer framework) for local network communication:

- Automatic peer discovery using Bonjour service type `_deskboard-v1._tcp`
- Encrypted sessions (`MCEncryptionRequired`)
- No internet or cloud required

### Background Wake (Optional but Recommended)

For stronger reconnection while apps are in background / screen locked, DeskBoard supports APNs silent wake:

- Each device registers its APNs token + stable UUID to a push gateway
- On disconnect, the paired device can trigger `silent push` to wake and reconnect
- Included worker implementation: [`backend/push-gateway/README.md`](/Users/ahmed/Downloads/DeckBoard/backend/push-gateway/README.md)

### Mac Receiver Relay (Optional)

For actions that iOS cannot execute while the receiver app is in background, DeskBoard can forward commands to a Mac relay on the same LAN:

- Configure in app: **Settings -> Mac Receiver Relay**
- Included relay implementation: [`backend/mac-receiver/README.md`](/Users/ahmed/Downloads/DeckBoard/backend/mac-receiver/README.md)
- Relay capability endpoint: `GET /v1/capabilities`

---

## ⚡ Supported Actions

| Category | Actions | iOS Receiver Background |
|---|---|---|
| **Media** | Play/Pause, Next/Previous, Volume Up/Down, Mute | ✅ |
| **General** | Send Text | ✅ |
| **Display** | Brightness Up/Down | ✅ |
| **Apps / URL / Deep link** | Open app, open URL, deep link | ⚠️ Foreground required |
| **Shortcuts** | Run Siri Shortcut / script-like shortcuts | ⚠️ Foreground required |
| **Presentation** | Next/Prev/Start/End (shortcut based) | ⚠️ Foreground required |
| **Macro** | Sequence of actions | Mixed (depends on each step) |

Notes:
- DeskBoard now labels actions in editor with background support status.
- Foreground-required actions are queued and auto-run when receiver returns to foreground.
- If Mac Relay is enabled, blocked background actions are forwarded to macOS instead of being dropped.
- Sender receives execution acknowledgements (`queued`, `success`, `failed`, `timeout`) and shows live button state.

---

## 📦 Dependencies

| Package | Purpose |
|---|---|
| [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) | Secure storage for trusted device list |

System frameworks: `MultipeerConnectivity`, `CoreImage` (QR generation), `UIKit`

---

## 🚀 Getting Started

### Prerequisites

- macOS 13+ with **Xcode 15+**
- [Homebrew](https://brew.sh)
- Apple Developer account

### 1. Bootstrap

```bash
bash scripts/setup.sh
```

### 2. Configure

```bash
# Fill in .env with your Apple Developer credentials
APPLE_ID=you@email.com
TEAM_ID=XXXXXXXXXX
```

### 3. Build & Run

Open `DeskBoard.xcodeproj` in Xcode, select your device/simulator, and press **Run (⌘R)**.

Or build from the command line:

```bash
bundle exec fastlane generate    # Generate Xcode project
bundle exec fastlane test        # Run unit tests
bundle exec fastlane build_debug # Build Debug IPA
```

---

## 🧪 Tests

```bash
bundle exec fastlane test
```

Test coverage:
- `DashboardModelTests` — Dashboard, Page, Button, Color extension, SampleData
- `CommandMessageTests` — Round-trip encoding for all command types
- `ButtonActionTests` — Action display names, system images, categories, Codable, PairedDevice, ConnectionState

### **Use your preferred code editor**

If you want to work locally using your own code editor, you can clone this repo and push changes. Pushed changes will also be reflected in Rork.

If you are new to coding and unsure which editor to use, we recommend Cursor. If you're familiar with terminals, try Claude Code.

The only requirement is having Node.js & Bun installed - [install Node.js with nvm](https://github.com/nvm-sh/nvm) and [install Bun](https://bun.sh/docs/installation)

Follow these steps:

```bash
# Step 1: Clone the repository using the project's Git URL.
git clone <YOUR_GIT_URL>

# Step 2: Navigate to the project directory.
cd <YOUR_PROJECT_NAME>

# Step 3: Install the necessary dependencies.
bun i

# Step 4: Start the instant web preview of your Rork app in your browser, with auto-reloading of your changes
bun run start-web

# Step 5: Start iOS preview
# Option A (recommended):
bun run start  # then press "i" in the terminal to open iOS Simulator
# Option B (if supported by your environment):
bun run start -- --ios
```

### **Edit a file directly in GitHub**

- Navigate to the desired file(s).
- Click the "Edit" button (pencil icon) at the top right of the file view.
- Make your changes and commit the changes.

## What technologies are used for this project?

This project is built with the most popular native mobile cross-platform technical stack:

- **React Native** - Cross-platform native mobile development framework created by Meta and used for Instagram, Airbnb, and lots of top apps in the App Store
- **Expo** - Extension of React Native + platform used by Discord, Shopify, Coinbase, Telsa, Starlink, Eightsleep, and more
- **Expo Router** - File-based routing system for React Native with support for web, server functions and SSR
- **TypeScript** - Type-safe JavaScript
- **React Query** - Server state management
- **Lucide React Native** - Beautiful icons

## How can I test my app?

### **On your phone (Recommended)**

1. **iOS**: Download the [Rork app from the App Store](https://apps.apple.com/app/rork) or [Expo Go](https://apps.apple.com/app/expo-go/id982107779)
2. **Android**: Download the [Expo Go app from Google Play](https://play.google.com/store/apps/details?id=host.exp.exponent)
3. Run `bun run start` and scan the QR code from your development server

### **In your browser**

Run `bun start-web` to test in a web browser. Note: The browser preview is great for quick testing, but some native features may not be available.

### **iOS Simulator / Android Emulator**

You can test Rork apps in Expo Go or Rork iOS app. You don't need XCode or Android Studio for most features.

**When do you need Custom Development Builds?**

- Native authentication (Face ID, Touch ID, Apple Sign In)
- In-app purchases and subscriptions
- Push notifications
- Custom native modules

Learn more: [Expo Custom Development Builds Guide](https://docs.expo.dev/develop/development-builds/introduction/)

If you have XCode (iOS) or Android Studio installed:

```bash
# iOS Simulator
bun run start -- --ios

# Android Emulator
bun run start -- --android
```

## How can I deploy this project?

### **Publish to App Store (iOS)**

1. **Install EAS CLI**:

   ```bash
   bun i -g @expo/eas-cli
   ```

2. **Configure your project**:

   ```bash
   eas build:configure
   ```

3. **Build for iOS**:

   ```bash
   eas build --platform ios
   ```

4. **Submit to App Store**:
   ```bash
   eas submit --platform ios
   ```

For detailed instructions, visit [Expo's App Store deployment guide](https://docs.expo.dev/submit/ios/).

### **Publish to Google Play (Android)**

1. **Build for Android**:

   ```bash
   eas build --platform android
   ```

2. **Submit to Google Play**:
   ```bash
   eas submit --platform android
   ```

For detailed instructions, visit [Expo's Google Play deployment guide](https://docs.expo.dev/submit/android/).

### **Publish as a Website**

Your React Native app can also run on the web:

1. **Build for web**:

   ```bash
   eas build --platform web
   ```

2. **Deploy with EAS Hosting**:
   ```bash
   eas hosting:configure
   eas hosting:deploy
   ```

Alternative web deployment options:

- **Vercel**: Deploy directly from your GitHub repository
- **Netlify**: Connect your GitHub repo to Netlify for automatic deployments

## App Features

This template includes:

- **Cross-platform compatibility** - Works on iOS, Android, and Web
- **File-based routing** with Expo Router
- **Tab navigation** with customizable tabs
- **Modal screens** for overlays and dialogs
- **TypeScript support** for better development experience
- **Async storage** for local data persistence
- **Vector icons** with Lucide React Native

## Project Structure

```
├── app/                    # App screens (Expo Router)
│   ├── (tabs)/            # Tab navigation screens
│   │   ├── _layout.tsx    # Tab layout configuration
│   │   └── index.tsx      # Home tab screen
│   ├── _layout.tsx        # Root layout
│   ├── modal.tsx          # Modal screen example
│   └── +not-found.tsx     # 404 screen
├── assets/                # Static assets
│   └── images/           # App icons and images
├── constants/            # App constants and configuration
├── app.json             # Expo configuration
├── package.json         # Dependencies and scripts
└── tsconfig.json        # TypeScript configuration
```

## Custom Development Builds

For advanced native features, you'll need to create a Custom Development Build instead of using Expo Go.

### **When do you need a Custom Development Build?**

- **Native Authentication**: Face ID, Touch ID, Apple Sign In, Google Sign In
- **In-App Purchases**: App Store and Google Play subscriptions
- **Advanced Native Features**: Third-party SDKs, platform-specifc features (e.g. Widgets on iOS)
- **Background Processing**: Background tasks, location tracking

### **Creating a Custom Development Build**

```bash
# Install EAS CLI
bun i -g @expo/eas-cli

# Configure your project for development builds
eas build:configure

# Create a development build for your device
eas build --profile development --platform ios
eas build --profile development --platform android

# Install the development build on your device and start developing
bun start --dev-client
```

**Learn more:**

- [Development Builds Introduction](https://docs.expo.dev/develop/development-builds/introduction/)
- [Creating Development Builds](https://docs.expo.dev/develop/development-builds/create-a-build/)
- [Installing Development Builds](https://docs.expo.dev/develop/development-builds/installation/)

## Advanced Features

### **Add a Database**

Integrate with backend services:

- **Supabase** - PostgreSQL database with real-time features
- **Firebase** - Google's mobile development platform
- **Custom API** - Connect to your own backend

### **Add Authentication**

Implement user authentication:

**Basic Authentication (works in Expo Go):**

- **Expo AuthSession** - OAuth providers (Google, Facebook, Apple) - [Guide](https://docs.expo.dev/guides/authentication/)
- **Supabase Auth** - Email/password and social login - [Integration Guide](https://supabase.com/docs/guides/getting-started/tutorials/with-expo-react-native)
- **Firebase Auth** - Comprehensive authentication solution - [Setup Guide](https://docs.expo.dev/guides/using-firebase/)

**Native Authentication (requires Custom Development Build):**

- **Apple Sign In** - Native Apple authentication - [Implementation Guide](https://docs.expo.dev/versions/latest/sdk/apple-authentication/)
- **Google Sign In** - Native Google authentication - [Setup Guide](https://docs.expo.dev/guides/google-authentication/)

### **Add Push Notifications**

Send notifications to your users:

- **Expo Notifications** - Cross-platform push notifications
- **Firebase Cloud Messaging** - Advanced notification features

### **Add Payments**

Monetize your app:

**Web & Credit Card Payments (works in Expo Go):**

- **Stripe** - Credit card payments and subscriptions - [Expo + Stripe Guide](https://docs.expo.dev/guides/using-stripe/)
- **PayPal** - PayPal payments integration - [Setup Guide](https://developer.paypal.com/docs/checkout/mobile/react-native/)

**Native In-App Purchases (requires Custom Development Build):**

- **RevenueCat** - Cross-platform in-app purchases and subscriptions - [Expo Integration Guide](https://www.revenuecat.com/docs/expo)
- **Expo In-App Purchases** - Direct App Store/Google Play integration - [Implementation Guide](https://docs.expo.dev/versions/latest/sdk/in-app-purchases/)

**Paywall Optimization:**

- **Superwall** - Paywall A/B testing and optimization - [React Native SDK](https://docs.superwall.com/docs/react-native)
- **Adapty** - Mobile subscription analytics and paywalls - [Expo Integration](https://docs.adapty.io/docs/expo)

## I want to use a custom domain - is that possible?

For web deployments, you can use custom domains with:

- **EAS Hosting** - Custom domains available on paid plans
- **Netlify** - Free custom domain support
- **Vercel** - Custom domains with automatic SSL

For mobile apps, you'll configure your app's deep linking scheme in `app.json`.

## Troubleshooting

### **App not loading on device?**

1. Make sure your phone and computer are on the same WiFi network
2. Try using tunnel mode: `bun start -- --tunnel`
3. Check if your firewall is blocking the connection

### **Build failing?**

1. Clear your cache: `bunx expo start --clear`
2. Delete `node_modules` and reinstall: `rm -rf node_modules && bun install`
3. Check [Expo's troubleshooting guide](https://docs.expo.dev/troubleshooting/build-errors/)

### **Need help with native features?**

- Check [Expo's documentation](https://docs.expo.dev/) for native APIs
- Browse [React Native's documentation](https://reactnative.dev/docs/getting-started) for core components
- Visit [Rork's FAQ](https://rork.com/faq) for platform-specific questions

## About Rork

Rork builds fully native mobile apps using React Native and Expo - the same technology stack used by Discord, Shopify, Coinbase, Instagram, and nearly 30% of the top 100 apps on the App Store.

Your Rork app is production-ready and can be published to both the App Store and Google Play Store. You can also export your app to run on the web, making it truly cross-platform.
