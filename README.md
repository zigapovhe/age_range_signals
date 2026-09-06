# age_range_signals

[![pub package](https://img.shields.io/pub/v/age_range_signals.svg)](https://pub.dev/packages/age_range_signals)
[![pub points](https://img.shields.io/pub/points/age_range_signals)](https://pub.dev/packages/age_range_signals/score)
[![Flutter](https://github.com/zigapovhe/age_range_signals/actions/workflows/flutter.yml/badge.svg)](https://github.com/zigapovhe/age_range_signals/actions/workflows/flutter.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A Flutter plugin for age verification that supports Google Play Age Signals API (Android) and Apple's DeclaredAgeRange API (iOS 26+).

## Quickstart

```dart
import 'package:age_range_signals/age_range_signals.dart';

await AgeRangeSignals.instance.initialize(ageGates: [18]);

final access = await AgeRangeSignals.instance.requestAgeSignalsAccess();
if (access == AgeSignalsAccessStatus.shared) {
  final result = await AgeRangeSignals.instance.checkAgeSignals();
  if (result.status == AgeSignalsStatus.verified) {
    showAdultContent();
  }
}
```

That is the whole API. `status` is the age verdict measured against your highest
gate, not a claim about identity or supervision. See [Basic Example](#basic-example)
for error handling and [Handling Every Status and Error](#handling-every-status-and-error)
for the exhaustive version.

## Table of Contents

- [Features](#features)
- [Platform Support](#platform-support)
- [Choosing Your Integration Level](#choosing-your-integration-level)
- [Regulatory Status](#regulatory-status)
- [Migrating to 0.8.0](#migrating-to-080)
- [Platform Setup](#platform-setup)
    - [Android](#android)
    - [iOS](#ios)
- [Usage](#usage)
    - [Basic Example](#basic-example)
    - [Handling Every Status and Error](#handling-every-status-and-error)
    - [Handling verificationRequired (Android)](#handling-verificationrequired-android)
    - [Regulatory Features (iOS 26.4+)](#regulatory-features-ios-264)
    - [18+ Only App](#18-only-app)
    - [Generally Available App (No Age Restrictions)](#generally-available-app-no-age-restrictions)
- [API Reference](#api-reference)
    - [AgeRangeSignals](#agerangesignals)
    - [AgeSignalsMockData](#agesignalsmockdata)
    - [AgeSignalsResult](#agesignalsresult)
    - [AgeSignalsStatus](#agesignalsstatus)
    - [AgeSignalsAccessStatus](#agesignalsaccessstatus)
    - [AgeRangeSource](#agerangesource)
    - [SignificantChangeStatus](#significantchangestatus)
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
- ✅ Google Play Age Signals API integration for Android (API 23+), including the age sharing prompt via `requestAgeSignalsAccess()` (age-signals 0.0.4)
- ✅ Apple DeclaredAgeRange API integration for iOS (26.0+)
- ✅ Regulatory feature detection and significant update acknowledgment for iOS (26.4+)
- ✅ Swift Package Manager (SPM) support for iOS
- ✅ Configurable age gates for iOS
- ✅ A typed exception for every failure mode: entitlement, network, cancellation, Play Services

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
| **1. Minimal** | Generally-available apps, no age-gated content | Call `requestAgeSignalsAccess()` then `checkAgeSignals()` once, optionally log the result, leave the UX unchanged. See [Generally Available App](#generally-available-app-no-age-restrictions). |
| **2. Targeted** | Apps with age-distinct areas (under/over 18, or 18+ only) | Gate those areas on `status` and the returned age range. See [Basic Example](#basic-example) and [18+ Only App](#18-only-app). |
| **3. Full** | Apps squarely in scope of these laws | Treat the client signal as one input: enforce on your **server** (the client result can be spoofed), re-check when state changes, and handle every `status` and [exception](#exceptions). |

## Regulatory Status

These laws are in flux. The plugin handles missing data gracefully, so the advice is the same throughout: keep it integrated and rely on the runtime signal rather than hard-coding which regions are live. Dates are current as of this release.

> **Google Play's rollout is wider than the laws.** Google has [announced](https://android-developers.googleblog.com/2026/07/google-play-age-signals-api-safer-experiences.html) Play Age Signals reaching Australia and Canada by mid-August 2026, and a full global rollout later in 2026. The API can therefore return signals for users in places with no age-verification statute at all, which is one more reason to read the runtime signal rather than this list.

- **Brazil (Lei 15.211, Digital ECA):** Enforceable since March 17, 2026. Google requires a recent Play Age Signals library for Brazil, which this plugin bundles; no action needed on your side. On the Apple side, from February 24, 2026 the App Store blocks Brazilian users from downloading 18+ apps unless confirmed adult, and apps declaring loot boxes are automatically rated 18+ on the Brazil storefront. [Law](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2025/lei/L15211.htm) · [Google docs](https://support.google.com/googleplay/android-developer/answer/6223646?hl=en#digital_eca_requirements) · [Apple News](https://developer.apple.com/news/?id=f5zj08ey)
- **Australia:** An applicable region for Apple's DeclaredAgeRange API. From February 24, 2026, Apple blocks users in Australia from downloading 18+ apps unless confirmed adult. Separate from the [Social Media Minimum Age Act](https://www.esafety.gov.au/about-us/industry-regulation/social-media-age-restrictions) (in effect December 10, 2025), and from App Store content *ratings*, which this plugin does not handle. [Apple News](https://developer.apple.com/news/?id=f5zj08ey)
- **Singapore:** An applicable region for Apple's DeclaredAgeRange API. From February 24, 2026, Apple blocks users in Singapore from downloading 18+ apps unless confirmed adult. [Apple News](https://developer.apple.com/news/?id=f5zj08ey)
- **Texas (SB 2420):** In effect since June 4, 2026. The Fifth Circuit [stayed](https://www.texastribune.org/2026/05/28/texas-apple-google-app-store-age-verification/) the December 2025 injunction pending appeal, and in July 2026 the Supreme Court [declined to intervene](https://www.scotusblog.com/2026/07/supreme-court-allows-texas-to-enforce-law-requiring-age-verification-and-parental-consent-on-app/), so the APIs return live data for Texas users. The merits appeal is still pending. See [Issue #21](https://github.com/zigapovhe/age_range_signals/issues/21).
- **Utah and Louisiana:** Statutory obligations are delayed, but **Apple already shares age categories** for these users. Utah's ASAA moved to May 6, 2027 ([HB 498](https://www.wiley.law/wiley-connect/utah-amends-app-store-accountability-act-asaa-key-obligations-delayed-until-may-6-2027), which also removed the AG's enforcement authority, leaving only a private right of action for minors and their guardians); Louisiana moved to July 1, 2027 ([HB 977](https://www.alstonprivacy.com/louisiana-delays-app-store-accountability-effective-date-to-july-2027/)). Independently of those dates, Apple shares age categories through DeclaredAgeRange for **new Apple Accounts created in Utah since May 6, 2026 and in Louisiana since July 1, 2026**, so `checkAgeSignals()` can return real data for those users today. [Apple News](https://developer.apple.com/news/?id=f5zj08ey)

## Migrating to 0.8.0

The call flow changed: request access first, and read signals only if it was granted. The same code works on both platforms.

```dart
// Before
final result = await AgeRangeSignals.instance.checkAgeSignals();

// After
final access = await AgeRangeSignals.instance.requestAgeSignalsAccess();
if (access == AgeSignalsAccessStatus.shared) {
  final result = await AgeRangeSignals.instance.checkAgeSignals();
}
```

On Android, skipping the access call means Play never prompts, so `checkAgeSignals()` reports `unknown`. Also pass `ageGates` on Android now: it sets the bar for `verified`.

On iOS nothing changes behaviourally, since access is always `shared` and Apple gathers consent inside `checkAgeSignals()` itself. One thing to watch: `requestAgeSignalsAccess()` throws `UnsupportedPlatformException` below iOS 26.0 and `NotInitializedException` when no gates were supplied, which are the same exceptions `checkAgeSignals()` used to raise. If your `try` only wrapped `checkAgeSignals()`, widen it to cover both calls.

Every other breaking change lists its migration step in the [CHANGELOG](CHANGELOG.md). Two notes for older versions: the `mostRecentApprovalDate` rename only affects 0.7.x, since the field arrived in 0.7.0, and coming from 0.5.x or earlier also needs `minSdk` 23.

## Platform Setup

### Android

1. Add the Play Age Signals dependency to your app's `build.gradle` (this is handled automatically by the plugin).

2. The Play Age Signals API requires Google Play Services to be installed and up to date.

3. The plugin builds on AGP 9 (built-in Kotlin) as well as AGP 8.x, where it needs the Kotlin Gradle plugin 2.0 or newer on your project's classpath (any recent Flutter template already provides this).

4. Since age-signals 0.0.4, Google Play splits age signals across two calls: `requestAgeSignalsAccess()` asks for access - showing Play's in-app age sharing prompt when the user's Play settings call for asking first - and `checkAgeSignals()` then reads the signals. Call the access request before checking, and only read signals when it returns `AgeSignalsAccessStatus.shared`. The prompt presents over your app's activity; the plugin obtains it automatically, but calling from a headless context (no foreground activity) fails with `PRESENTATION_CONTEXT_UNAVAILABLE`.

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

Enough to paste into an app and run. Call `initialize()` on both platforms,
then request access before reading signals: on Android, skipping the access
call means Play never prompts and `checkAgeSignals()` reports `unknown`.

```dart
import 'package:age_range_signals/age_range_signals.dart';

await AgeRangeSignals.instance.initialize(ageGates: [13, 16, 18]);

try {
  final access = await AgeRangeSignals.instance.requestAgeSignalsAccess();
  if (access != AgeSignalsAccessStatus.shared) {
    // notShared is a decline, not an error. On verificationRequired, point
    // the user at the Play Store to finish verifying.
    showAgeAppropriateContent(null, null);
    return;
  }

  final result = await AgeRangeSignals.instance.checkAgeSignals();

  if (result.status == AgeSignalsStatus.verified) {
    // Above your highest gate.
    showUnrestrictedContent();
  } else {
    // Everything else: treat as age-restricted and use the range if present.
    showAgeAppropriateContent(result.ageLower, result.ageUpper);
  }
} on AgeSignalsException catch (e) {
  // Every failure mode subclasses this.
  print('Age check failed: ${e.message}');
}
```

> **Which call shows UI.** The word "prompt" means something different on each platform, so to be explicit: on **Android**, `requestAgeSignalsAccess()` shows Play's age sharing sheet and `checkAgeSignals()` shows nothing (it takes no `Activity`, so it has nowhere to draw). On **iOS** it is reversed: `requestAgeSignalsAccess()` shows nothing and Apple gathers consent inside `checkAgeSignals()`, where a refusal arrives as `AgeSignalsStatus.declined`. Where this README says *you* should prompt, such as `showAgeVerificationPrompt()` in the examples below, that means your own UI rather than a system sheet.

That covers the common path. Production apps should handle every status and
the specific exception types, shown next.

### Handling Every Status and Error

```dart
import 'package:age_range_signals/age_range_signals.dart';

// Initialize on both platforms: iOS requires the gates, and Android uses
// your highest gate as the bar for `verified`.
// Age gates represent your meaningful thresholds (e.g., child/teen/adult).
await AgeRangeSignals.instance.initialize(ageGates: [13, 16, 18]);

// Check age signals
try {
  // Ask for access first (Android shows Play's age sharing prompt when
  // needed; iOS always reports shared and gathers consent in the check).
  final access = await AgeRangeSignals.instance.requestAgeSignalsAccess();
  if (access != AgeSignalsAccessStatus.shared) {
    // notShared: user or parent declined - not an error, just no signals.
    // verificationRequired: user must verify in the Play Store first.
    print('No age signals to read: $access');
    return;
  }

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
    // Still a member of the enum, so an exhaustive switch has to name it,
    // but neither platform returns it any more. Read ageRangeSource instead.
    // ignore: deprecated_member_use
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
  // Android: Available whenever signals are shared
  // ageUpper is null for the open-ended 18+ band, so check ageLower alone.
  if (result.ageLower != null) {
    print('Age range: ${result.ageLower} - ${result.ageUpper ?? "open-ended"}');
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

### Handling verificationRequired (Android)

`verificationRequired` has no in-app resolution. The user completes verification
in the Play Store app, so all your app can do is explain that and send them
there. Google does not document a deep link to the verification flow; their
guidance is that users "will be asked to verify or set up supervision when they
visit the Play Store app", so opening the store is enough.

There is no callback when they return, so re-check on resume. Otherwise a user
verifies, comes back, and your app still treats them as unverified.

```dart
class _AgeGateState extends State<AgeGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have verified while your app was backgrounded.
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final access = await AgeRangeSignals.instance.requestAgeSignalsAccess();

    if (access == AgeSignalsAccessStatus.verificationRequired) {
      // Your own UI, not a system sheet: explain what is needed and offer
      // a button that opens the Play Store (for example via url_launcher).
      showVerifyInPlayStoreMessage();
      return;
    }

    if (access != AgeSignalsAccessStatus.shared) return;

    final result = await AgeRangeSignals.instance.checkAgeSignals();
    applyAgeGate(result);
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

An empty set means Apple affirmatively reports that nothing is required. On Android the set is always empty (the Play API has no equivalent concept). On iOS below 26.4, and in apps built with a pre-26.4 SDK, the call throws `UnsupportedPlatformException` because the requirement cannot be checked; catch it and keep your own regional logic for those devices:

```dart
Set<AgeRegulatoryFeature> features;
try {
  features = await AgeRangeSignals.instance.getRequiredRegulatoryFeatures();
} on UnsupportedPlatformException {
  // Older iOS: Apple cannot report requirements here. Fall back to your
  // own region-based decision about whether to prompt.
  features = const {};
}
```

### 18+ Only App

If your app is strictly 18+, set a single gate at 18 so the API classifies the user above/below that threshold.

```dart
import 'dart:io';
import 'package:age_range_signals/age_range_signals.dart';

// One gate at 18. Pass it on both platforms: iOS requires it, and Android
// uses your highest gate as the bar for `verified`.
await AgeRangeSignals.instance.initialize(ageGates: [18]);

final access = await AgeRangeSignals.instance.requestAgeSignalsAccess();
if (access != AgeSignalsAccessStatus.shared) {
  // Block; on verificationRequired, point the user at the Play Store
  // to complete verification.
  return;
}

final result = await AgeRangeSignals.instance.checkAgeSignals();

// `verified` only says the band clears your gate. Any tier can reach it,
// including a self-declaration, so a strictly 18+ app should decide what
// assurance it will accept rather than leaving it implicit.
// Apply an assurance floor on both platforms. Android exposes the Play tier;
// iOS exposes the declaration type, where a bare self-declaration is the
// weakest signal Apple reports.
const acceptableTiers = {AgeRangeSource.tierC, AgeRangeSource.tierD};
final assuranceOk = Platform.isIOS
    ? result.source != AgeDeclarationSource.selfDeclared
    : acceptableTiers.contains(result.ageRangeSource);

if (result.status == AgeSignalsStatus.verified && assuranceOk) {
  // User meets 18+ requirement at an assurance level you accept
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
  // Both platforms: iOS requires the gates, Android derives `verified` from
  // your highest one.
  await AgeRangeSignals.instance.initialize(ageGates: defaultAgeGates);
}

Future<void> requestAgeSignals() async {
  try {
    final access = await AgeRangeSignals.instance.requestAgeSignalsAccess();
    if (access != AgeSignalsAccessStatus.shared) {
      // Optional: log the outcome; nothing to read without shared access
      print('Age signals access: $access');
      return;
    }

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
  - `ageGates`: Age thresholds (e.g., `[13, 16, 18]`). Required on iOS. Play ignores them, but Android uses your highest gate as the bar for `verified`, using 18 until you supply gates and keeping them if a later call omits them, so pass them on both platforms. **iOS accepts 1 to 3 gates**; passing 0 or more than 3 gates throws an error (`ApiErrorException`). Gates must be at least 2 years apart (Apple rejects e.g. `[13, 14]` with an invalid-request error).
  - `useMockData`: (Android only) Set to `true` to use Google's `FakeAgeSignalsManager` for testing. Ignored on iOS. Defaults to `false`.
  - `mockData`: (Android only) Optional custom mock data configuration using Google's official testing utilities. Ignored on iOS. If not provided, defaults to supervised user (13-15).

- `Future<AgeSignalsAccessStatus> requestAgeSignalsAccess()` - Requests access to the user's age signals (age-signals 0.0.4). On Android this may show Google Play's in-app age sharing prompt over your activity; only call `checkAgeSignals()` when the result is `shared`. A decline is not an error - it comes back as `notShared`. In mandatory-verification regions Play skips the prompt entirely: already-verified and supervised users come back `shared`, while unverified users come back `verificationRequired` and complete verification in the Play Store app. On iOS it returns `shared` without showing anything, because Apple gathers consent inside `checkAgeSignals()` itself; a refusal surfaces there as `AgeSignalsStatus.declined`. It is not unconditional: iOS throws `UnsupportedPlatformException` below 26.0 and `NotInitializedException` when `initialize()` supplied no gates, so it doubles as a pre-flight there.

- `Future<AgeSignalsResult> checkAgeSignals()` - Checks the age signals for the current user. On Android, call `requestAgeSignalsAccess()` first; without shared access the API returns no signals and `status` is `unknown`.

- `Future<Set<AgeRegulatoryFeature>> getRequiredRegulatoryFeatures()` - Returns which regulatory actions Apple requires for the current user (iOS 26.4+). An empty set means Apple affirmatively reports nothing is required; if `declaredAgeRangeRequired` is absent, you are not required to prompt this user. Returns an empty set on Android (the Play API has no equivalent concept). Throws `UnsupportedPlatformException` on iOS below 26.4 and in apps built with a pre-26.4 SDK (Xcode < 26.4), where the requirement cannot be checked.

- `Future<void> showSignificantUpdateAcknowledgment({required String updateDescription})` - Shows Apple's system sheet for acknowledging a significant app change (iOS 26.4+). Completing normally means the person acknowledged; every other outcome throws. `UnsupportedPlatformException` on Android and on iOS below 26.4 rather than silently succeeding, so your compliance flow can't be fooled by a no-op. `ApiNotAvailableException` when Apple reports the sheet unavailable, which Apple also uses when the person dismisses it, so don't treat that as proof the sheet never appeared. `UserCancelledException` on explicit cancellation and `ApiErrorException` for other failures.

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
  AgeSignalsAccessStatus? accessStatus,
  AgeRangeSource? ageRangeSource,
  SignificantChangeStatus? significantChangeStatus,
  DateTime? significantChangeApprovalDate,
})
```

#### Properties

- `AgeSignalsStatus status` - The mock verification status to return
- `int? ageLower` - Mock lower bound of age range
- `int? ageUpper` - Mock upper bound of age range
- `AgeDeclarationSource? source` - iOS-flavoured declaration source. Not read on Android; use `ageRangeSource` to select the Play tier
- `String? installId` - Mock installation ID (Android only)
- `AgeSignalsAccessStatus? accessStatus` - Mock outcome of `requestAgeSignalsAccess()`; defaults to `shared` when null
- `AgeRangeSource? ageRangeSource` - Explicit mock tier; when null it is derived from `status` (verified maps to `tierC`, declared to `tierA`, the supervised family to `tierB`). The result's `status` is always re-derived from the resulting age band, exactly as with real API responses, so a mock whose band contradicts its `status` comes back with the band's verdict. `status: declared` therefore returns `supervised` on its default 13-15 band; give it `ageLower: 18` to model a self-declared adult
- `SignificantChangeStatus? significantChangeStatus` - Explicit mock change status; when null it is derived from `status` (`supervisedApprovalPending` maps to `pending`, `supervisedApprovalDenied` to `declined`)
- `DateTime? significantChangeApprovalDate` - Mock significant change approval date (Android only)

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
- `int? ageLower` - Lower bound of age range (both platforms; iOS: when user consents, Android: whenever signals are shared - verified 18+ reports `ageLower=18`)
- `int? ageUpper` - Upper bound of age range (both platforms; iOS: when user consents, Android: whenever signals are shared; `null` for the open-ended 18+ band)
- `AgeDeclarationSource? source` - Source of age declaration (iOS only)
- `String? installId` - Installation identifier (Android only, supervised users). When a parent revokes approval, Google lists the id on the Play Console's Revoked app approvals tab as a CSV download retained for 90 days; store it on your backend and ingest revocations within that window if you need to act on them - Google permits no other use.
- `List<String>? activeParentalControls` - Parental controls active on the user's account, as raw Apple identifiers such as `communicationLimits` (iOS only)
- `AgeRangeSource? ageRangeSource` - How Google Play established the age range (Android only). `status` is **not** derived from this tier: the verdict comes from the age band measured against your highest gate. Use this to apply a minimum assurance policy
- `SignificantChangeStatus? significantChangeStatus` - Parent approval state for significant app changes (Android only, supervised users)
- `DateTime? significantChangeApprovalDate` - Effective date of the most recently approved significant change (Android only, supervised users). Named `mostRecentApprovalDate` before 0.8.0; the old name still works as a deprecated alias

#### When are ageLower and ageUpper populated?

**Android (Google Play Age Signals API):**

Play does not return a single status. The plugin derives it from the age band Play reports, measured against your highest configured age gate, with the tier and the app-version approval state alongside.

| status | ageRangeSource | ageLower/ageUpper | installId | Derived from |
|--------|----------------|-------------------|-----------|--------------|
| `verified` | any tier | Populated / `null` or populated† | `null` or populated | Band starts at or above your highest gate |
| `supervised` | `tierB` | Populated / Populated† | Populated | Parent-managed account below your highest gate |
| `supervised` | `tierA`/`tierC`/`tierD` | Populated / Populated† | `null` | Unsupervised user below your highest gate |
| `supervisedApprovalPending` | `tierB` | Populated / Populated† | Populated | Awaiting parent approval of a significant change |
| `supervisedApprovalDenied` | `tierB` | Populated / Populated† | Populated | Parent denied the change; use previous approved state |
| `unknown` | `null` or any tier | `null` / `null` | `null` | Access not shared, verification required, or no age band reported |

**†Edge case:** `ageUpper` is `null` only for Play's open-ended 18+ band. With a lower gate a `verified` result can carry a closed band, e.g. gates `[13]` and Play's 16-17 band give `ageLower: 16, ageUpper: 17`, so do not use `ageUpper == null` as a proxy for "adult".

**Note:** `supervisedApprovalPending` and `supervisedApprovalDenied` are reported whatever the age, including when Play has established no band yet, so their bounds can be `null`.

**Note:** Play reports fixed bands (0-12, 13-15, 16-17, 18+) while iOS buckets against your actual gates, so a gate that does not sit on a band edge quantises upward on Android. With a gate at 15, a 15-year-old is `verified` on iOS (Apple's range starts at 15) but lands in Play's 13-15 band and reads `supervised` on Android. Prefer gates on band edges (13, 16, 18) if you need the two platforms to agree exactly.

**Note:** `ageRangeSource` says **how** an age was established, not what it is. A `tierD` result means an ID was checked, and that ID can read 12, so the tier is never the verdict on its own. `verified` and `supervised` split at your highest configured age gate. Android uses 18 until you supply gates, and a later `initialize()` that omits them keeps the gates you already set. iOS applies the same comparison, so one `status` check means the same thing on both platforms.

**Note:** Android never returns `declined`. Play reports `notShared` both for a genuine refusal and for a user who was never asked because their region is out of scope, and the two are indistinguishable, so the plugin reports `unknown` rather than asserting an intent. Only iOS reports a real refusal.

**Note:** On Android, age ranges are determined by Google Play's parental control settings and returned as predefined age bands (0-12, 13-15, 16-17, 18+). Play itself ignores `ageGates`, but the plugin uses your highest gate as the bar for `verified`, so call `initialize()` with your gates on Android too. You cannot customize these age bands through the plugin; they're controlled by Google Play and can optionally be customized in Play Console.

**iOS (DeclaredAgeRange API):**

| status | ageLower/ageUpper | source | Notes |
|------------|-------------------|--------|-------|
| `verified` | Populated‡ | Populated§ | User consented; lower bound ≥ highest configured gate |
| `supervised` | Populated‡ | Populated§ | User consented; lower bound < highest configured gate |
| `declined` | `null` | `null` | User declined to share age information |
| `unknown` | `null` | Populated§ | User consented but Apple reported no lower bound, so there is no verdict |

**‡ `ageUpper` may be `null`** for an open-ended top bucket (e.g., an 18+ range returns `ageLower=18, ageUpper=null`), mirroring the Android edge case above.

**§ `source` may be `null`** when the declaration type is neither self-declared nor guardian-declared (e.g., Apple's `paymentChecked` / `guardianPaymentChecked`, or an unrecognized/future type), even for `verified`/`supervised`.

**Note:** iOS no longer returns `unknown` from an eligibility pre-check (as of 0.6.0); that check was removed (see [Regional Eligibility](#regional-eligibility-ios-262)). It can still return `unknown` for a shared range that carries no lower bound, since that shape yields no verdict. Android reports `unknown` for the same shape.

### AgeSignalsStatus

Enum representing the verification status:

- `verified` - The reported age range starts at or above your highest configured age gate (both platforms; Android uses 18 until you supply gates). Any tier can reach it: `ageRangeSource` says how the age was established, not what it is
- `supervised` - The reported age range falls below your highest configured age gate. Same rule on both platforms. This is the age verdict, not the supervision relationship: read `ageRangeSource == AgeRangeSource.tierB` for that
- `supervisedApprovalPending` - User is supervised and a significant change awaits parent approval (Android only)
- `supervisedApprovalDenied` - User is supervised and the parent denied the significant change (Android only)
- `declared` - **Deprecated, no longer returned.** It conflated the verdict with how the age was established, so a self-declared adult could not clear a `verified` gate while the stronger `tierC` and `tierD` passed automatically. Read `ageRangeSource == AgeRangeSource.tierA` instead
- `declined` - User declined to share age (iOS only; on Android a decline surfaces as `AgeSignalsAccessStatus.notShared` from the access request)
- `unknown` - No verdict available: access not shared or verification required (Android), the API is unavailable, or the platform reported a range with no lower bound. iOS no longer returns it from an eligibility pre-check (removed in 0.6.0, see [Regional Eligibility](#regional-eligibility-ios-262)), but does for a bandless range

### AgeSignalsAccessStatus

Enum returned by `requestAgeSignalsAccess()` (age-signals 0.0.4):

- `shared` - Age signals are shared; proceed to `checkAgeSignals()`. The only value iOS returns, where consent is gathered inside the check itself; iOS throws instead of returning another value
- `notShared` - The user declined or previously chose not to share, a parent rejected sharing, or the user is not eligible. Not an error
- `verificationRequired` - The user must verify their age in the Play Store app first (mandatory-verification regions, when the age is not already established); Play does not show the in-app prompt
- `unknown` - Play reported a state this plugin version does not recognize

### AgeRangeSource

Enum describing how Google Play established the age range (Android only, age-signals 0.0.4), ordered from weakest to strongest assurance. The tier vocabulary is Google's own:

- `tierA` - Self-declared by the user
- `tierB` - From a parent- or guardian-managed account (the supervised family)
- `tierC` - Verified via credit card, email, selfie, government ID, or tax ID
- `tierD` - Verified via government ID plus selfie, or a Digital ID

### SignificantChangeStatus

Enum describing parent approval of significant app changes you report on the Play Console's Age signals page (Android only, supervised users). Approval is cumulative: one parent approval covers every change still pending since the last approval:

- `approved` - The parent approved the most recent change(s); `significantChangeApprovalDate` carries the effective date
- `pending` - Approval requested but not yet answered; restrict the functionality behind the change
- `declined` - The parent denied the change(s); restrict the functionality behind them

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

#### Build Configuration
- `MockDataNotAllowedException` - `useMockData: true` in a non-debuggable build (Android). `FakeAgeSignalsManager` forges age signals, so it is unreachable in release builds. Build a debuggable variant if you need mock data on a release-like artifact

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

> **Debuggable builds only.** `useMockData: true` throws `MockDataNotAllowedException` in a non-debuggable build. The fake manager forges age signals, so leaving it enabled in a shipped release would hand a fabricated age gate to real users. If you need mock data on a release-like artifact, build a debuggable release variant.

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

Pass `mockData` to cover any scenario from Dart, without touching Kotlin:

```dart
await AgeRangeSignals.instance.initialize(
  useMockData: true,
  mockData: const AgeSignalsMockData(
    status: AgeSignalsStatus.supervised,
    ageLower: 16,
    ageUpper: 17,
    installId: 'test_install_id',
  ),
);
```

Swap the `mockData` argument for any of these:

| Scenario | `mockData` | What you get back |
|---|---|---|
| Supervised teen | `status: supervised, ageLower: 16, ageUpper: 17, installId: 'test_id'` | `supervised`, `tierB`, your install id |
| Verified adult | `status: verified` | `verified`, band open-ended from your highest gate |
| Strongly verified adult | `status: verified, ageRangeSource: AgeRangeSource.tierD` | `verified` pinned to `tierD` |
| Awaiting parent approval | `status: supervisedApprovalPending, ageLower: 13, ageUpper: 15` | `supervisedApprovalPending`, change status `pending` |
| Parent denied the change | `status: supervisedApprovalDenied, ageLower: 13, ageUpper: 15` | `supervisedApprovalDenied`, change status `declined` |
| No signals at all | `status: unknown` | `unknown`, no band, no tier |
| Sharing declined | `status: unknown, accessStatus: AgeSignalsAccessStatus.notShared` | `requestAgeSignalsAccess()` returns `notShared`; `checkAgeSignals()` reports `unknown` |

**Note**: Mock values follow the same predefined age bands as real responses (`0-12`, `13-15`, `16-17`, `18+`). Verified mocks default to the open-ended adult band, with `ageLower` at your highest age gate (18 until you supply gates) and `ageUpper: null`, because the verdict is derived from the band. A real verified response reports Play's open-ended 18+ band (`ageLower: 18, ageUpper: null`), so pass `ageLower: 18` to mirror it exactly. See [AgeSignalsResult](#agesignalsresult) for the full rules.

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
- Play needs an `Activity` to host its sharing prompt. The plugin is `ActivityAware`, but if it is called with no attached Activity, `requestAgeSignalsAccess()` throws `ApiErrorException` with code `PRESENTATION_CONTEXT_UNAVAILABLE`
- `AgeSignalsAccessStatus.verificationRequired`, returned by `requestAgeSignalsAccess()`, has no in-app resolution: the user must complete verification in the Play Store app
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
- Common causes: the key is in `Runner.entitlements` but the **capability isn't registered on your App ID** (Xcode falls back to a wildcard profile without it), or the entitlements file exists but the project has no `CODE_SIGN_ENTITLEMENTS` build setting pointing at it, so it never enters the signature at all
- **Solution**:
    1. Add the key to `Runner.entitlements` (see iOS Setup)
    2. Make sure the Runner target's `CODE_SIGN_ENTITLEMENTS` build setting references that file (adding the capability via Xcode's Signing & Capabilities tab does this for you)
    3. Enable the **Declared Age Range** capability on your App ID via Xcode → Signing & Capabilities → **+ Capability** (self-serve; no Apple approval needed)
    4. Let Xcode regenerate the provisioning profile (toggle the team or hit "Try Again" under Signing if needed)
    5. Verify with `codesign -d --entitlements :- YourApp.app | grep declared-age-range`
- Since 0.7.0, "age range sharing not available for this user or region" is reported as `ApiNotAvailableException`; earlier versions misreported that state as `MissingEntitlementException` even on correctly entitled apps

**ApiErrorException: "requiredRegulatoryFeatures failed: Timed out after 10.0s" (iOS)**
- Apple's regulatory features call can hang instead of returning; the plugin's 10-second deadline converts the hang into this error
- Observed on a real iOS 26.5 device in **debug** builds even with the correct entitlement and a covered-region sandbox account, while the identical app in **release** mode answered in about 140 ms
- **Solution**: treat it as transient; test regulatory features on release (or TestFlight) builds

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

**PRESENTATION_CONTEXT_UNAVAILABLE**
- `requestAgeSignalsAccess()` was called with no foreground activity to present Play's age sharing prompt on (e.g. from a background isolate or before the first frame)
- Call it from a foregrounded app; the plugin picks up the activity automatically

**Prompt never appears from `requestAgeSignalsAccess()`**
- The prompt is only shown to unsupervised users whose Play setting is "Ask before sharing"; "Always share" and "Never share" resolve silently, parents manage sharing for supervised users via Family Link, and in mandatory-verification regions unverified users get `verificationRequired` instead of a prompt
- After repeated dismissals Play suppresses the prompt and keeps answering `notShared`

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