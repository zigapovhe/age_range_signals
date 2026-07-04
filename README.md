# age_range_signals

A Flutter plugin for age verification that supports Google Play Age Signals API (Android) and Apple's DeclaredAgeRange API (iOS 26+).

## Table of Contents

- [Features](#features)
- [Platform Support](#platform-support)
- [Choosing Your Integration Level](#choosing-your-integration-level)
- [Regulatory Status](#regulatory-status)
- [Platform Setup](#platform-setup)
    - [Android](#android)
    - [iOS](#ios)
- [Usage](#usage)
    - [Basic Example](#basic-example)
    - [Complete Example](#complete-example)
    - [Regulatory Features (iOS 26.4+)](#regulatory-features-ios-264)
    - [18+ Only App](#18-only-app)
    - [Generally Available App (No Age Restrictions)](#generally-available-app-no-age-restrictions)
- [API Reference](#api-reference)
    - [AgeRangeSignals](#agerangesignals)
    - [AgeSignalsMockData](#agesignalsmockdata)
    - [AgeSignalsResult](#agesignalsresult)
    - [AgeSignalsStatus](#agesignalsstatus)
    - [AgeDeclarationSource](#agedeclarationsource)
    - [AgeRegulatoryFeature](#ageregulatoryfeature)
    - [Exceptions](#exceptions)
- [Legal Compliance](#legal-compliance)
    - [Important Usage Restrictions](#important-usage-restrictions)
    - [Privacy Considerations](#privacy-considerations)
- [Testing](#testing)
    - [Android Testing](#android-testing)
    - [iOS Testing](#ios-testing)
- [Limitations](#limitations)
    - [Android](#android-1)
    - [iOS](#ios-1)
- [Troubleshooting](#troubleshooting)
    - [Common Errors](#common-errors)
    - [Platform-Specific Errors](#platform-specific-errors)
- [Example App](#example-app)
- [Contributing](#contributing)
- [License](#license)
- [References](#references)
- [Support](#support)

## Features

- ✅ Cross-platform support for Android and iOS
- ✅ Google Play Age Signals API integration for Android (API 23+)
- ✅ Apple DeclaredAgeRange API integration for iOS (26.0+)
- ✅ Regulatory feature detection and significant update acknowledgment for iOS (26.4+)
- ✅ Swift Package Manager (SPM) support for iOS
- ✅ Configurable age gates for iOS
- ✅ Type-safe Dart API with structured error handling
- ✅ Full null safety support

## Platform Support

| Platform | Minimum App Version | API Available From | API |
|----------|----------------|-----|-----|
| Android  | API 23 (Android 6.0) | API 23+ | Google Play Age Signals API |
| iOS      | iOS 13.0+ (flexible) | iOS 26.0+ | DeclaredAgeRange API |

**Note:** The iOS DeclaredAgeRange API is only available on iOS 26.0+. On older iOS versions, the plugin will return an `UnsupportedPlatformException`. Your app can support older iOS versions and handle this gracefully.

**Note:** The Google Play Age Signals dependency (`com.google.android.play:age-signals`) declares `minSdkVersion 23`, so your app's `minSdk` (`minSdkVersion` in older projects) must be **23 or higher**. Building at a lower `minSdk` will fail Gradle's manifest merge.

## Choosing Your Integration Level

The plugin returns one age signal; how far you build on it depends on your app, not only on which laws apply. Start at Level 1 and move up only when you actually gate content on age.

> **Not legal advice.** This maps *plugin usage* to common app shapes. Whether a level meets your obligations depends on your app, regions, and counsel.

| Level | Who it's for | What you do with the plugin |
|-------|--------------|-----------------------------|
| **1. Minimal** | Generally-available apps, no age-gated content | Call `checkAgeSignals()` once, optionally log the result, leave the UX unchanged. See [Generally Available App](#generally-available-app-no-age-restrictions). |
| **2. Targeted** | Apps with age-distinct areas (under/over 18, or 18+ only) | Gate those areas on `status` and the returned age range. See [Basic Example](#basic-example) and [18+ Only App](#18-only-app). |
| **3. Full** | Apps squarely in scope of these laws | Treat the client signal as one input: enforce on your **server** (the client result can be spoofed), re-check when state changes, and handle every `status` and [exception](#exceptions). |

## Regulatory Status

These laws are in flux. The plugin handles missing data gracefully, so the advice is the same throughout: keep it integrated and rely on the runtime signal rather than hard-coding which regions are live. Dates are current as of this release.

- **Brazil (Lei 15.211, Digital ECA):** Enforceable since March 17, 2026. Requires `com.google.android.play:age-signals` 0.0.3+, which this plugin bundles. [Law](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2025/lei/L15211.htm) · [Google docs](https://support.google.com/googleplay/android-developer/answer/6223646?hl=en#digital_eca_requirements)
- **Australia:** An applicable region for Apple's DeclaredAgeRange API. From February 24, 2026, Apple blocks users in Australia from downloading 18+ apps unless confirmed adult. Separate from the [Social Media Minimum Age Act](https://www.esafety.gov.au/about-us/industry-regulation/social-media-age-restrictions) (in effect December 10, 2025), and from App Store content *ratings*, which this plugin does not handle. [Apple News](https://developer.apple.com/news/?id=f5zj08ey)
- **Texas (SB 2420):** In effect since June 4, 2026 under a [temporary Fifth Circuit stay](https://www.texastribune.org/2026/05/28/texas-apple-google-app-store-age-verification/) of the December 2025 injunction, so the APIs may return live data for Texas users. This is not a final ruling and could be re-blocked. **Utah** delayed to May 2027 ([HB 498](https://technologylaw.fkks.com/post/102mpap/utah-first-state-to-amend-its-app-store-accountability-act)); **Louisiana** to July 1, 2027 ([HB 977](https://www.alstonprivacy.com/louisiana-delays-app-store-accountability-effective-date-to-july-2027/)). See [Issue #21](https://github.com/zigapovhe/age_range_signals/issues/21).

## Platform Setup

### Android

1. Add the Play Age Signals dependency to your app's `build.gradle` (this is handled automatically by the plugin).

2. The Play Age Signals API requires Google Play Services to be installed and up to date.

3. The plugin builds on AGP 9 (built-in Kotlin) as well as AGP 8.x, where it needs the Kotlin Gradle plugin 2.0 or newer on your project's classpath (any recent Flutter template already provides this).

**Important:** The Play Age Signals API is currently in beta and only returns real data for users in regions where the underlying laws are in effect; see [Regulatory Status](#regulatory-status) for current dates. Use `useMockData: true` for testing otherwise.

### iOS

1. Add the required entitlement to your app's entitlements file (`ios/Runner/Runner.entitlements`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.declared-age-range</key>
    <true/>
</dict>
</plist>
```

2. Enable the **Declared Age Range** capability on your App ID. In Xcode, open your Runner target → **Signing & Capabilities** → **+ Capability** → add **Declared Age Range** (or enable it on your App ID in the [Developer portal](https://developer.apple.com/account/resources/identifiers/list)). This is **self-serve**; no request form or approval from Apple is required.

> **Important:** Adding the key to `Runner.entitlements` by hand is **not** enough. The capability must be registered on your App ID, otherwise Xcode's automatic signing **silently strips** the entitlement at build time and `requestAgeRange()` fails with a missing-entitlement error at runtime. To confirm the entitlement actually made it into your signed build:
>
> ```bash
> codesign -d --entitlements :- /path/to/YourApp.app | grep declared-age-range
> ```
>
> If `com.apple.developer.declared-age-range` isn't listed, the capability isn't registered on your App ID.

**Important:** The DeclaredAgeRange API requires iOS 26.0+, but your app does NOT need to set its minimum deployment target to iOS 26.0. The plugin handles version checking at runtime and will throw an `UnsupportedPlatformException` on older iOS versions (or on SDKs without the API), allowing you to handle this gracefully in your app.

## Usage

### Basic Example

```dart
import 'package:age_range_signals/age_range_signals.dart';

// Initialize the plugin (required for iOS, optional for Android)
// Age gates represent your meaningful thresholds (e.g., child/teen/adult).
await AgeRangeSignals.instance.initialize(ageGates: [13, 16, 18]);

// Check age signals
try {
  final result = await AgeRangeSignals.instance.checkAgeSignals();

  switch (result.status) {
    case AgeSignalsStatus.verified:
      print('User is verified as above age threshold');
      break;
    case AgeSignalsStatus.supervised:
      print('User is under parental supervision');
      break;
    case AgeSignalsStatus.supervisedApprovalPending:
      print('Waiting for guardian approval');
      break;
    case AgeSignalsStatus.supervisedApprovalDenied:
      print('Guardian denied access');
      break;
    case AgeSignalsStatus.declared:
      print('User declared their age through Google Play');
      break;
    case AgeSignalsStatus.declined:
      print('User declined to share age information');
      break;
    case AgeSignalsStatus.unknown:
      print('Age information is not available');
      break;
  }

  // Access age range (both platforms)
  // iOS: Available when user consents to share
  // Android: Available for supervised users
  if (result.ageLower != null && result.ageUpper != null) {
    print('Age range: ${result.ageLower} - ${result.ageUpper}');
  }

  // Android-specific: Access install ID
  if (result.installId != null) {
    print('Install ID: ${result.installId}');
  }
} on MissingEntitlementException catch (e) {
  // iOS: Entitlement not configured - show setup instructions
  print('Setup required: ${e.message}');
  print('Debug details: ${e.details}');
} on UserCancelledException catch (e) {
  // User chose not to verify - handle gracefully
  print('User cancelled: ${e.message}');
} on NetworkErrorException catch (e) {
  // Network issue - retry or show offline mode
  print('Network error: ${e.message}');
} on PlayServicesException catch (e) {
  // Android: Prompt user to update Play Services
  print('Play Services required: ${e.message}');
} on UserNotSignedInException catch (e) {
  // Android: Prompt user to sign in
  print('Sign in required: ${e.message}');
} on ApiNotAvailableException catch (e) {
  // API not available in this region or on this device
  print('API not available: ${e.message}');
} on UnsupportedPlatformException catch (e) {
  // Platform version too old
  print('Platform not supported: ${e.message}');
} on ApiErrorException catch (e) {
  // General API error - log for debugging
  print('API error: ${e.message}');
  print('Details: ${e.details}');
} on AgeSignalsException catch (e) {
  // Catch-all for any other errors
  print('Error: ${e.message}');
}
```

### Complete Example

```dart
import 'dart:io';
import 'package:age_range_signals/age_range_signals.dart';

Future<void> checkUserAge() async {
  // Initialize with age gates on iOS (required); Android is a no-op.
  if (Platform.isIOS) {
    await AgeRangeSignals.instance.initialize(
      ageGates: [13, 16, 18],
    );
  }

  // Check age signals
  try {
    final result = await AgeRangeSignals.instance.checkAgeSignals();

    if (result.status == AgeSignalsStatus.verified) {
      // User is verified, proceed with age-appropriate content
      showMainContent();
    } else if (result.status == AgeSignalsStatus.supervised ||
               result.status == AgeSignalsStatus.declared) {
      // User is under supervision or declared their age, check age range
      showRestrictedContent();
    } else {
      // Age unknown or declined, handle accordingly
      showAgeVerificationPrompt();
    }
  } on AgeSignalsException catch (e) {
    // Handle errors appropriately
    print('Age verification error: ${e.message}');
  }
}
```

### Regulatory Features (iOS 26.4+)

On iOS 26.4+ you can ask Apple which regulatory actions apply to the current user before deciding whether to prompt at all:

```dart
final features =
    await AgeRangeSignals.instance.getRequiredRegulatoryFeatures();

if (features.contains(AgeRegulatoryFeature.declaredAgeRangeRequired)) {
  // Apple requires this user to share an age range with your app.
  final result = await AgeRangeSignals.instance.checkAgeSignals();
  // ...
}

if (features
    .contains(AgeRegulatoryFeature.significantAppChangeRequiresAdultNotification)) {
  // You shipped a change regulators consider significant; show Apple's sheet.
  await AgeRangeSignals.instance.showSignificantUpdateAcknowledgment(
    updateDescription: 'We added social features and public profiles.',
  );
}
```

The set is empty on Android and on iOS below 26.4, so treat an empty set as "nothing reportable", not as proof that no law applies; keep your own regional logic for older OS versions.

### 18+ Only App

If your app is strictly 18+, set a single gate at 18 so the API classifies the user above/below that threshold.

```dart
// iOS only: one gate at 18
await AgeRangeSignals.instance.initialize(ageGates: [18]);

final result = await AgeRangeSignals.instance.checkAgeSignals();
if (result.status == AgeSignalsStatus.verified) {
  // User meets 18+ requirement
} else {
  // Block or show appropriate messaging
}
```

### Generally Available App (No Age Restrictions)

If your app serves all ages and does not gate content, you still need to provide age gates on iOS so the DeclaredAgeRange API can return a bucket. Use broad defaults and optionally log the result without changing your UX.

```dart
import 'dart:io';
import 'package:age_range_signals/age_range_signals.dart';

const defaultAgeGates = [13, 16, 18];

Future<void> initAgeSignals() async {
  if (Platform.isIOS) {
    await AgeRangeSignals.instance.initialize(ageGates: defaultAgeGates);
  }
}

Future<void> requestAgeSignals() async {
  try {
    final result = await AgeRangeSignals.instance.checkAgeSignals();
    // Optional: log for compliance/analytics (without gating features)
    print('Age signals status: ${result.status}');
  } on AgeSignalsException catch (e) {
    // Handle or log errors; do not block app usage
    print('Age signals error: ${e.message}');
  }
}
```

## API Reference

### AgeRangeSignals

Main class for interacting with the plugin.

#### Methods

- `Future<void> initialize({List<int>? ageGates, bool useMockData = false, AgeSignalsMockData? mockData})` - Initializes the plugin.
  - `ageGates`: (iOS only) Age thresholds (e.g., `[13, 16, 18]`). Required for iOS, ignored on Android. **iOS accepts 1 to 3 gates**; passing 0 or more than 3 gates throws an error (`ApiErrorException`). Gates must be at least 2 years apart (Apple rejects e.g. `[13, 14]` with an invalid-request error).
  - `useMockData`: (Android only) Set to `true` to use Google's `FakeAgeSignalsManager` for testing. Ignored on iOS. Defaults to `false`.
  - `mockData`: (Android only) Optional custom mock data configuration using Google's official testing utilities. Ignored on iOS. If not provided, defaults to supervised user (13-15).

- `Future<AgeSignalsResult> checkAgeSignals()` - Checks the age signals for the current user.

- `Future<Set<AgeRegulatoryFeature>> getRequiredRegulatoryFeatures()` - Returns which regulatory actions Apple requires for the current user (iOS 26.4+). Empty set on Android and on iOS below 26.4. If `declaredAgeRangeRequired` is absent, you are not required to prompt this user. Requires building with the iOS 26.4 SDK (Xcode 26.4+); on older SDKs it also returns an empty set.

- `Future<void> showSignificantUpdateAcknowledgment({required String updateDescription})` - Shows Apple's system sheet for acknowledging a significant app change (iOS 26.4+). Throws `UnsupportedPlatformException` on Android and on iOS below 26.4 rather than silently succeeding, so your compliance flow can't be fooled by a no-op.

### AgeSignalsMockData

**Android only** - Configuration for custom mock/test data using Google's `FakeAgeSignalsManager`. Ignored on iOS.

#### Constructor

```dart
AgeSignalsMockData({
  required AgeSignalsStatus status,
  int? ageLower,
  int? ageUpper,
  AgeDeclarationSource? source,
  String? installId,
  DateTime? mostRecentApprovalDate,
})
```

#### Properties

- `AgeSignalsStatus status` - The mock verification status to return
- `int? ageLower` - Mock lower bound of age range (for supervised statuses)
- `int? ageUpper` - Mock upper bound of age range (for supervised statuses)
- `AgeDeclarationSource? source` - Reserved for future use (currently unused)
- `String? installId` - Mock installation ID (Android only)
- `DateTime? mostRecentApprovalDate` - Mock guardian approval date (Android only)

#### Example (Android only)

```dart
const mockData = AgeSignalsMockData(
  status: AgeSignalsStatus.supervised,
  ageLower: 16,
  ageUpper: 17,
  installId: 'test_id',
);

await AgeRangeSignals.instance.initialize(
  useMockData: true,  // Ignored on iOS
  mockData: mockData,  // Ignored on iOS
);
```

### AgeSignalsResult

Result object containing age verification information.

#### Properties

- `AgeSignalsStatus status` - The verification status
- `int? ageLower` - Lower bound of age range (both platforms; iOS: when user consents, Android: for supervised users)
- `int? ageUpper` - Upper bound of age range (both platforms; iOS: when user consents, Android: for supervised users)
- `AgeDeclarationSource? source` - Source of age declaration (iOS only)
- `String? installId` - Installation identifier (Android only)
- `List<String>? activeParentalControls` - Parental controls active on the user's account, as raw Apple identifiers such as `communicationLimits` (iOS only)
- `DateTime? mostRecentApprovalDate` - When a guardian most recently approved the age range (Android only, supervised users)

#### When are ageLower and ageUpper populated?

**Android (Google Play Age Signals API):**

| userStatus | ageLower/ageUpper | installId | Notes |
|------------|-------------------|-----------|-------|
| `verified` | `null` / `null` | `null` | User is 18+, no supervision needed |
| `supervised` | Populated / Populated† | Populated | Supervised account with approved age range |
| `supervisedApprovalPending` | Populated / Populated† | Populated | Awaiting parent approval for changes |
| `supervisedApprovalDenied` | Populated / Populated† | Populated | Parent denied changes; use previous approved age |
| `declared` | Populated / Populated† | `null` | User declared their age through Google Play (Brazil only) |
| `unknown` | `null` / `null` | `null` | User unverified/unsupervised, or API unavailable in region |

**†Edge case:** For supervised users, `ageUpper` may be `null` if the parent-attested age is over 18 (e.g., `ageLower=18, ageUpper=null`).

**Note:** On Android, age ranges are determined by Google Play's parental control settings and returned as predefined age bands (0-12, 13-15, 16-17, 18+). The `ageGates` parameter is **not used** on Android - it's iOS-only. You cannot customize these age bands through the plugin; they're controlled by Google Play and can optionally be customized in Play Console.

**iOS (DeclaredAgeRange API):**

| userStatus | ageLower/ageUpper | source | Notes |
|------------|-------------------|--------|-------|
| `verified` | Populated‡ | Populated§ | User consented; lower bound ≥ highest configured gate |
| `supervised` | Populated‡ | Populated§ | User consented; lower bound < highest configured gate |
| `declined` | `null` | `null` | User declined to share age information |

**‡ `ageUpper` may be `null`** for an open-ended top bucket (e.g., an 18+ range returns `ageLower=18, ageUpper=null`), mirroring the Android edge case above.

**§ `source` may be `null`** when the declaration type is neither self-declared nor guardian-declared (e.g., Apple's `paymentChecked` / `guardianPaymentChecked`, or an unrecognized/future type), even for `verified`/`supervised`.

**Note:** iOS does not return `unknown` (as of 0.6.0). The previous `isEligibleForAgeFeatures` pre-check was removed (see [Regional Eligibility](#regional-eligibility-ios-262)).

### AgeSignalsStatus

Enum representing the verification status:

- `verified` - User is verified as above age threshold (both platforms)
- `supervised` - User is under parental supervision (Android) or declared age is below configured age gates (iOS)
- `supervisedApprovalPending` - User is supervised and awaiting guardian approval (Android only)
- `supervisedApprovalDenied` - User is supervised and guardian denied approval (Android only)
- `declared` - User declared their age through Google Play's age declaration flow (Android only)
- `declined` - User declined to share age (iOS only)
- `unknown` - Age information not available / user unverified or unsupervised (Android). As of 0.6.0, iOS no longer returns this (see [Regional Eligibility](#regional-eligibility-ios-262))

### AgeDeclarationSource

Enum representing the source of age declaration (iOS only):

- `selfDeclared` - Age was self-declared by the user
- `guardianDeclared` - Age was declared by a guardian

### AgeRegulatoryFeature

Enum of regulatory actions Apple can require (iOS 26.4+, returned by `getRequiredRegulatoryFeatures()`):

- `declaredAgeRangeRequired` - The user must share their age range with your app
- `significantAppChangeRequiresAdultNotification` - Adult users must acknowledge your significant app change (use `showSignificantUpdateAcknowledgment`)
- `significantAppChangeRequiresParentalConsent` - A parent must consent before a child continues after a significant change (the consent flow itself runs through Apple's PermissionKit and App Store Server Notifications, which this plugin does not wrap)

### Exceptions

The plugin provides specific exception types for different error scenarios, making error handling more precise:

#### Base Exception
- `AgeSignalsException` - Base exception class for all age signals errors

#### Platform Availability
- `ApiNotAvailableException` - API is not available on the device or region
- `UnsupportedPlatformException` - Platform version does not support the API
- `NotInitializedException` - Plugin not initialized (iOS - call `initialize()` first)

#### Configuration Issues
- `MissingEntitlementException` - Required entitlement missing or not approved (iOS - see Setup)

#### User Actions
- `UserCancelledException` - User cancelled the age verification prompt
- `UserNotSignedInException` - User not signed in to Google account (Android)

#### Technical Errors
- `ApiErrorException` - General platform API error (includes full diagnostic details)
- `NetworkErrorException` - Network or connection error
- `PlayServicesException` - Google Play Services unavailable or outdated (Android)

**All exceptions include:**
- `message` - Human-readable error description
- `code` - Error code for programmatic handling
- `details` - Full diagnostic information (error domain, code, exception type)

## Legal Compliance

### Important Usage Restrictions

When using this plugin, you must comply with all applicable laws and platform policies:

#### Google Play Age Signals API

You may only use information from the Play Age Signals API to provide age-appropriate content and experiences in compliance with laws. You may not use the Play Age Signals API for any other purpose including, but not limited to:
- Advertising
- Marketing
- User profiling
- Analytics

Violations may result in API access termination and app suspension.

#### Apple DeclaredAgeRange API

Follow Apple's guidelines for handling age-related data and ensure compliance with applicable privacy laws.

### Privacy Considerations

- This plugin does not collect or store any user data
- Age verification data is provided directly by the platform APIs
- Ensure your app's privacy policy accurately describes how age data is used

## Testing

### Android Testing

You have full control over when to use mock data via the `useMockData` parameter:

```dart
// For testing with default mock data (supervised 13-15)
await AgeRangeSignals.instance.initialize(
  ageGates: [13, 16, 18],
  useMockData: true,  // Uses FakeAgeSignalsManager
);

// For production with real APIs
await AgeRangeSignals.instance.initialize(
  ageGates: [13, 16, 18],
  useMockData: false, // Uses real Play Age Signals API (default)
);

final result = await AgeRangeSignals.instance.checkAgeSignals();
// When useMockData: true, returns a supervised user (13-15) by default
print(result.status);    // AgeSignalsStatus.supervised
print(result.ageLower);  // 13
print(result.ageUpper);  // 15
print(result.installId); // "test_install_id_12345"
```

**How it works:**
- `useMockData: true` - Uses `FakeAgeSignalsManager` for testing
- `useMockData: false` (default) - Uses real Play Age Signals API
- You control this behavior explicitly in your code

#### Testing Different Scenarios

You can now test different scenarios without modifying the plugin source code by using the `mockData` parameter:

```dart
// Test supervised user aged 16-17
await AgeRangeSignals.instance.initialize(
  useMockData: true,
  mockData: AgeSignalsMockData(
    status: AgeSignalsStatus.supervised,
    ageLower: 16,
    ageUpper: 17,
    installId: 'test_install_id',
  ),
);

// Test verified user (18+) - age values should be null
await AgeRangeSignals.instance.initialize(
  useMockData: true,
  mockData: const AgeSignalsMockData(
    status: AgeSignalsStatus.verified,
    // Don't provide ageLower, ageUpper, or installId
    // They will be null as expected for verified users
  ),
);

// Test supervisedApprovalPending status
await AgeRangeSignals.instance.initialize(
  useMockData: true,
  mockData: AgeSignalsMockData(
    status: AgeSignalsStatus.supervisedApprovalPending,
    ageLower: 13,
    ageUpper: 15,
    installId: 'test_install_id',
  ),
);

// Test supervisedApprovalDenied status
await AgeRangeSignals.instance.initialize(
  useMockData: true,
  mockData: AgeSignalsMockData(
    status: AgeSignalsStatus.supervisedApprovalDenied,
    ageLower: 13,
    ageUpper: 15,
    installId: 'test_install_id',
  ),
);

// Test unknown status
await AgeRangeSignals.instance.initialize(
  useMockData: true,
  mockData: const AgeSignalsMockData(
    status: AgeSignalsStatus.unknown,
  ),
);
```

**Benefits:**
- Uses Google's official `FakeAgeSignalsManager` for authentic testing
- Test all scenarios from Dart code - no need to modify Kotlin source files
- Easier automated testing and manual QA
- Default behavior (supervised 13-15) maintained for backward compatibility

**Note**: Mock values follow the same predefined age bands as real responses (`0-12`, `13-15`, `16-17`, `18+`); verified users return `null` for both bounds. See [AgeSignalsResult](#agesignalsresult) for the full rules.

### iOS Testing

**No `mockData` support on iOS**

The `useMockData` and `mockData` parameters are **ignored on iOS**: Apple provides no in-process mock for DeclaredAgeRange. Instead, it offers a **sandbox Age Assurance** mechanism (iOS 26.2+) for exercising real responses on a device.

**Requirements:**
- A real **iOS 26.2+ device** (no simulator support)
- The `com.apple.developer.declared-age-range` capability **registered on your App ID** (see iOS Setup; a hand-edited entitlements key alone gets stripped at signing)
- A **Sandbox Apple Account** signed in **only** under Settings → Developer → Sandbox Apple Account (not the normal iCloud sign-in, or eligibility misbehaves), with its **App Store territory** set to an applicable region (US, Brazil, Australia, Singapore)

**Testing with sandbox Age Assurance scenarios:**
1. On the device: **Settings → Developer → Sandbox Apple Account → Manage → Age Assurance**
2. Select a scenario, then **relaunch your app** (the value is cached) and call `checkAgeSignals()`

With age gates `[13, 16, 18]`, Apple's scenarios map through the plugin as follows:

| Sandbox scenario | `status` | ageLower | ageUpper | source |
|---|---|---|---|---|
| Under 13, approved | `supervised` | 0 | 12 | `null` |
| Ages 13-15, approved | `supervised` | 13 | 15 | `null` |
| Ages 16-17, declined | `supervised` | 16 | 17 | `null` |
| 18+, account verified | `verified` | 18 | `null` | `null` |
| 18+, self declared | `verified` | 18 | `null` | `selfDeclared` |

> **The two "declines" are different.** A `declined` *status* means the user refused to share their age (DeclaredAgeRange `.declinedSharing`). The "Ages 16-17, **declined**" sandbox scenario is not that. It still returns the 16-17 range via DeclaredAgeRange, so the plugin reports `supervised`. The "declined" there is a **PermissionKit** guardian-permission response, a separate Apple framework this plugin does not wrap. DeclaredAgeRange has no "denied" state, so a guardian decline or consent revocation surfaces as the user's real age range (`supervised`), not a distinct denied status. If you need the guardian approve/deny signal itself, use PermissionKit plus App Store Server Notifications.

> Reference: Apple's [Testing age assurance in sandbox](https://developer.apple.com/documentation/storekit/testing-age-assurance-in-sandbox).

For app-level UI/flow testing during development, you can also bypass age verification in debug builds with your own conditional logic.

#### Regional Eligibility (iOS 26.2+)

The plugin calls Apple's `requestAgeRange()` directly and does **not** pre-gate on `isEligibleForAgeFeatures`. Earlier versions (0.4.0-0.5.x) checked `isEligibleForAgeFeatures` first and returned `unknown` for users reported as outside an applicable region, but that property proved unreliable in the iOS 26.2.x window: it can hang indefinitely (which hung `checkAgeSignals()` entirely) and it reports `false` before the user has accepted any prompt, only updating on a later relaunch ([Apple Developer Forums](https://developer.apple.com/forums/thread/809829)). Following Apple's guidance, the plugin now treats `requestAgeRange()` as the source of truth.

As a result, **iOS no longer returns `AgeSignalsStatus.unknown` from an eligibility pre-check** (as of 0.6.0). Region applicability is reflected by `requestAgeRange()` itself.

On iOS 26.4+, `getRequiredRegulatoryFeatures()` is the reliable way to check what Apple requires for the current user before prompting; it answers a more precise question than the old eligibility flag ever did.

**Behavior:**
- **iOS 26.0+**: Calls `requestAgeRange()` directly
- **iOS < 26.0**: Throws `UnsupportedPlatformException`

**Platform Version Testing**

On iOS < 26.0, you'll receive an `UnsupportedPlatformException`, which is the expected behavior. Test your error handling:

```dart
try {
  final result = await AgeRangeSignals.instance.checkAgeSignals();
} on UnsupportedPlatformException {
  // Handle gracefully - this is expected on iOS < 26.0
  print('Age verification not available on this iOS version');
}
```

## Limitations

### Android
- The Play Age Signals API is currently in beta
- Only returns real data in regions where the laws are in effect (see [Regulatory Status](#regulatory-status) for current dates). Platform rollout timing may not align exactly with the statutory dates, so rely on the runtime signal rather than assuming when data becomes available
- Use `useMockData: true` for testing until APIs go live in your target states
- Requires Google Play Services to be installed and up to date

### iOS
- DeclaredAgeRange API only available on iOS 26.0+
- Requires the `com.apple.developer.declared-age-range` capability registered on your App ID (not just the entitlements-file key; see iOS Setup)
- Throws `UnsupportedPlatformException` on iOS versions below 26.0
- User can decline to share age information
- No mock/testing parameter on iOS; testing is via Apple's sandbox Age Assurance scenarios (see iOS Testing)
- Cannot detect falsified birthdates in Apple ID

## Troubleshooting

### Common Errors

**MissingEntitlementException (iOS)**
- The `com.apple.developer.declared-age-range` entitlement isn't present in the signed app at runtime
- Most common cause: the key is in `Runner.entitlements` but the **capability isn't registered on your App ID**, so Xcode silently strips it at signing
- **Solution**:
    1. Add the key to `Runner.entitlements` (see iOS Setup)
    2. Enable the **Declared Age Range** capability on your App ID via Xcode → Signing & Capabilities → **+ Capability** (self-serve; no Apple approval needed)
    3. Let Xcode regenerate the provisioning profile (toggle the team or hit "Try Again" under Signing if needed)
    4. Verify with `codesign -d --entitlements :- YourApp.app | grep declared-age-range`

**UserCancelledException**
- User cancelled the age verification prompt
- **Solution**: Handle gracefully - allow user to retry or use alternative verification

**NetworkErrorException**
- Network or connection error occurred
- **Solution**: Check internet connection, retry, or show offline mode

**PlayServicesException (Android)**
- Google Play Services is unavailable or outdated
- **Solution**: Prompt user to update Google Play Services

**UserNotSignedInException (Android)**
- User is not signed in to a Google account
- **Solution**: Prompt user to sign in to their Google account

### Platform-Specific Errors

**Android**

**API_NOT_AVAILABLE**
- API is not available on the device or in this region
- Ensure Google Play Services is installed and up to date
- Verify the device has an active internet connection
- Check if the user is in a region where the law is currently in effect (see [Regulatory Status](#regulatory-status))

**iOS**

**UNSUPPORTED_PLATFORM**
- This error is expected on iOS versions below 26.0
- The DeclaredAgeRange API is only available on iOS 26.0+
- Handle this gracefully in your app (e.g., use alternative age verification or skip the check)

**NOT_INITIALIZED**
- Call `initialize()` with age gates before calling `checkAgeSignals()`

**`checkAgeSignals()` hangs / never returns (iOS, pre-0.6.0)**
- Caused by awaiting Apple's `isEligibleForAgeFeatures`, which can hang in the iOS 26.2.x window
- Fixed in 0.6.0 (the eligibility pre-check was removed). Upgrade to 0.6.0+

## Example App

See the `example` directory for a complete working example that demonstrates:
- Initializing the plugin on both platforms
- Handling all response types
- Error handling and edge cases
- Platform-specific UI considerations

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## References

- [Google Play Age Signals API Documentation](https://developer.android.com/google/play/age-signals/overview)
- [Apple DeclaredAgeRange Documentation](https://developer.apple.com/documentation/declaredagerange/)

## Support

For issues, questions, or contributions, please visit the [GitHub repository](https://github.com/zigapovhe/age_range_signals/issues).