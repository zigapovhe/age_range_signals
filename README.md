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

That's the core flow. `status` is the age verdict measured against your highest gate, not a claim about identity or supervision ([How It Works](#how-it-works) has the details). [Basic Example](#basic-example) adds error handling and [Handling Every Status and Error](#handling-every-status-and-error) is the exhaustive version.

## Table of Contents

- [Features](#features)
- [Platform Support](#platform-support)
- [Regulatory Status](#regulatory-status)
- [Platform Setup](#platform-setup)
- [How It Works](#how-it-works)
- [Choosing Your Integration Level](#choosing-your-integration-level)
- [Usage](#usage)
    - [Basic Example](#basic-example)
    - [Handling Every Status and Error](#handling-every-status-and-error)
    - [Handling verificationRequired (Android)](#handling-verificationrequired-android)
    - [Regional Eligibility](#regional-eligibility)
    - [Regulatory Features](#regulatory-features)
    - [18+ Only App](#18-only-app)
    - [Generally Available App](#generally-available-app-no-age-restrictions)
- [API Reference](#api-reference)
- [Legal Compliance](#legal-compliance)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Migrating to 0.8.0](#migrating-to-080)
- [Example App](#example-app)

## Features

- ✅ Google Play Age Signals API on Android (API 24+), including Play's age sharing prompt
- ✅ Apple DeclaredAgeRange API on iOS 26.0+
- ✅ One `status` that means the same thing on both platforms, measured against your own age gates
- ✅ Regional eligibility check: Apple's on iOS 26.2+, Play's mandatory-sharing check on Android
- ✅ Regulatory feature detection (iOS 26.4+ and Android) and the significant update acknowledgment sheet (iOS 26.4+)
- ✅ Mock data on Android through Google's `FakeAgeSignalsManager`
- ✅ A typed exception for every failure mode
- ✅ Swift Package Manager and CocoaPods

## Platform Support

| Platform | Minimum app version | API available from | API |
|----------|---------------------|--------------------|-----|
| Android  | API 24 (Android 7.0) | API 24 | Google Play Age Signals |
| iOS      | iOS 13.0 | iOS 26.0 (eligibility 26.2, regulatory features 26.4) | DeclaredAgeRange |

Your iOS app doesn't need a deployment target of 26.0. The plugin checks at runtime and throws `UnsupportedPlatformException` on older iOS versions, and in apps built with an SDK that lacks the API, so you can keep supporting older devices.

On Android, `com.google.android.play:age-signals` declares `minSdkVersion 24` since 0.0.6 (Google's docs still say 23), so your app's `minSdk` (`minSdkVersion` in older projects) must be 24 or higher. Anything lower fails Gradle's manifest merge.

## Regulatory Status

These laws are in flux, but the advice doesn't change: keep the plugin integrated and rely on the runtime signal rather than hard-coding which regions are live. Dates are current as of this release.

> **Google Play is going worldwide.** Google says age-signals 0.0.6, which this plugin uses since 0.11.0, will return responses for all users by December 11, 2026. Plugin versions 0.8.0 to 0.10.1 use 0.0.4, which keeps returning responses in selected regions ([Google docs](https://developer.android.com/google/play/age-signals/overview), [by region](https://developer.android.com/distribute/age-appropriate-experiences/regional-protections)). Outside regions with a sharing mandate, users choose whether to share, and anyone whose Play setting is "Ask before sharing" can see the prompt. To skip the prompt where no law requires sharing, see [Regional Eligibility](#regional-eligibility).

- **Brazil (Lei 15.211, Digital ECA):** Enforceable since March 17, 2026, when Play started returning age signals for Brazilian users. From January 2027, Play shares age information in Brazil on a mandatory basis ([Google docs](https://developer.android.com/distribute/age-appropriate-experiences/regional-protections)). On the Apple side, from February 24, 2026 the App Store blocks Brazilian users from downloading 18+ apps unless confirmed adult, and apps declaring loot boxes are automatically rated 18+ on the Brazil storefront. [Law](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2025/lei/L15211.htm) · [Google docs](https://support.google.com/googleplay/android-developer/answer/6223646?hl=en#digital_eca_requirements) · [Apple News](https://developer.apple.com/news/?id=f5zj08ey)
- **Australia:** An applicable region for Apple's DeclaredAgeRange API. From February 24, 2026, Apple blocks users in Australia from downloading 18+ apps unless confirmed adult. Separate from the [Social Media Minimum Age Act](https://www.esafety.gov.au/about-us/industry-regulation/social-media-age-restrictions) (in effect December 10, 2025), and from App Store content *ratings*, which this plugin does not handle. eSafety's [Age-Restricted Material Codes](https://www.esafety.gov.au/industry/codes/register-online-industry-codes-standards) separately require every app store to check age before an 18+ download; that store-level check is required from September 9, 2026 and, like content ratings, sits outside this plugin. [Apple News](https://developer.apple.com/news/?id=f5zj08ey)
- **Singapore:** An applicable region for Apple's DeclaredAgeRange API. From February 24, 2026, Apple blocks users in Singapore from downloading 18+ apps unless confirmed adult. [Apple News](https://developer.apple.com/news/?id=f5zj08ey)
- **Texas (SB 2420):** In effect since June 4, 2026. The Fifth Circuit [stayed](https://www.texastribune.org/2026/05/28/texas-apple-google-app-store-age-verification/) the December 2025 injunction pending appeal, and in July 2026 the Supreme Court [declined to intervene](https://www.scotusblog.com/2026/07/supreme-court-allows-texas-to-enforce-law-requiring-age-verification-and-parental-consent-on-app/), so the law is in force. Apple applies it to new Apple Accounts in Texas from June 4, 2026 ([Apple News](https://developer.apple.com/news/?id=sg176nne)); Google verifies the ages of eligible users there ([Google docs](https://developer.android.com/distribute/age-appropriate-experiences/regional-protections)). The merits appeal was argued August 4, 2026; a decision is still pending. See [Issue #21](https://github.com/zigapovhe/age_range_signals/issues/21).
- **California (AB 1043):** From January 2027, Play shares age ranges in California on a mandatory basis. [Google docs](https://developer.android.com/distribute/age-appropriate-experiences/regional-protections)
- **Alabama (HB 161):** Due to take effect January 1, 2027 ([source](https://www.alstonprivacy.com/louisiana-delays-app-store-accountability-effective-date-to-july-2027/)). Google lists the Play details as coming soon. [Google docs](https://developer.android.com/distribute/age-appropriate-experiences/regional-protections)
- **Utah and Louisiana:** Statutory obligations are delayed, but Apple already shares age categories for these users. Utah's ASAA moved to May 6, 2027 ([HB 498](https://www.wiley.law/wiley-connect/utah-amends-app-store-accountability-act-asaa-key-obligations-delayed-until-may-6-2027), which also removed the AG's enforcement authority, leaving only a private right of action for minors and their guardians); Louisiana moved to July 1, 2027 ([HB 977](https://www.alstonprivacy.com/louisiana-delays-app-store-accountability-effective-date-to-july-2027/)). Independently of those dates, Apple shares age categories through DeclaredAgeRange for new Apple Accounts created in Utah since May 6, 2026 and in Louisiana since July 1, 2026, so `checkAgeSignals()` can return real data for those users today. [Apple News](https://developer.apple.com/news/?id=f5zj08ey)
- **Apple Time Allowances (iOS 27):** Not a law, but an App Store requirement. Parents can limit time in Entertainment, Games and Social Media apps, and since September 2026 every submission has to say whether the app has social media capabilities. Apps that do get a minimum 13+ rating and land in the Social Media category. If those features are disabled for anyone under 13, the app stays out of that category for under-13s, but Apple then requires you to check age ranges with the Declared Age Range API at a minimum (a gate at 13 gives you that split). [Apple News](https://developer.apple.com/news/?id=0d2gpmml)

## Platform Setup

### Android

There's nothing to add to Gradle; the plugin depends on `com.google.android.play:age-signals` 0.0.6 itself. You need:

- `minSdk` 24 or higher
- The Google Play Store and Google Play Services installed and up to date on the device
- Your app installed from Google Play. Play blocks sideloaded installs unless the device's Google account is a license tester (see [Android Testing](#android-testing))
- Flutter 3.47 or newer. Works with AGP 9's built-in Kotlin, and with `android.builtInKotlin=false` or AGP 8, where Flutter applies the Kotlin Gradle plugin itself (Flutter 3.50 needs AGP 9.1.1 or newer)

The Play Age Signals API is still in beta. With age-signals 0.0.6 (plugin 0.11.0 and later) it is going worldwide by December 11, 2026: outside regions where a law makes sharing mandatory, users choose whether to share (see [Regulatory Status](#regulatory-status) and [Regional Eligibility](#regional-eligibility)). Use [mock data](#android-testing) to test scenarios you can't reach with a real account.

### iOS

1. Add the entitlement to your app's entitlements file (`ios/Runner/Runner.entitlements`):

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

2. Enable the **Declared Age Range** capability on your App ID. In Xcode, open your Runner target → Signing & Capabilities → + Capability → Declared Age Range, or enable it on your App ID in the [Developer portal](https://developer.apple.com/account/resources/identifiers/list). It's self-serve, with no request form or approval from Apple.

Step 2 is the one that gets missed. With the key in `Runner.entitlements` but no capability on the App ID, Xcode's automatic signing silently strips the entitlement at build time and the age range request fails at runtime. To confirm the entitlement made it into your signed build:

```bash
codesign -d --entitlements :- /path/to/YourApp.app | grep declared-age-range
```

If `com.apple.developer.declared-age-range` isn't listed, see [MissingEntitlementException](#missingentitlementexception-ios).

## How It Works

### Two calls

Reading age signals takes two calls, as in Google's API. The plugin uses the same flow on iOS, but each platform shows its UI in a different one.

`requestAgeSignalsAccess()` asks for access. On Android it can show Play's age sharing sheet over your activity, so call it from a foregrounded app. It returns `shared`, `notShared` (the user declined or isn't eligible; not an error), `verificationRequired`, or `unknown` for a state the plugin doesn't recognize. Only call `checkAgeSignals()` after `shared`. If you skip the access call, Play never prompts and `checkAgeSignals()` reports `unknown`. In US states whose laws require app stores to provide verified ages, Play skips the sheet entirely: users who are already verified or supervised come back `shared`, and unverified users come back `verificationRequired` and have to finish in the Play Store ([handling it](#handling-verificationrequired-android)). Where sharing is mandatory without verification, Play [shares without asking](https://support.google.com/googleplay/answer/17232873). Everywhere else it can show the sheet; to skip it there, call `isEligibleForAgeFeatures()` first ([Regional Eligibility](#regional-eligibility)).

On iOS, `requestAgeSignalsAccess()` shows nothing and returns `shared`. It still throws `UnsupportedPlatformException` below iOS 26.0 and `NotInitializedException` when `initialize()` supplied no gates, so it doubles as a pre-flight check.

`checkAgeSignals()` reads the signals. On Android it shows nothing (it takes no `Activity`, so it has nowhere to draw). On iOS it's the call that shows Apple's sharing sheet, and a refusal comes back as `AgeSignalsStatus.declined`.

### Age gates and `status`

Call `initialize()` with the same gates on both platforms, for example `[13, 16, 18]`.

iOS requires them. Apple buckets the user's age against your gates and accepts 1 to 3 of them, at least 2 years apart (it rejects `[13, 14]` with an invalid-request error). Without gates, `requestAgeSignalsAccess()` and `checkAgeSignals()` throw `NotInitializedException`; with more than 3, `checkAgeSignals()` throws `ApiErrorException`. `initialize()` itself doesn't validate them. In some regulated regions people can't decline sharing and the region's own age gates replace yours, so the range you get back may not line up with your gates. Apple also caches the range: when a person ages into a new one, it keeps returning the old range until the anniversary of their original declaration, unless they update it in Settings.

Play ignores them. It reports its default bands, 0-12, 13-15, 16-17 and 18+, unless you set up to three custom minimum ages on the Play Console's Age signals page (at least 2 years apart, changeable once a year). The plugin can't set those for you. When someone ages into a new band, Google [may delay](https://support.google.com/googleplay/answer/17232873) sharing it. The plugin uses your highest gate as the bar for `verified`: 18 until you supply gates, and a later `initialize()` that leaves them out keeps the ones you already set.

`status` is the verdict and follows the same rule on both platforms: `verified` when the reported range starts at or above your highest gate, `supervised` when it falls below. It says nothing about whether a parent manages the account; on Android that's `ageRangeSource == AgeRangeSource.tierB`.

How the age was established is a separate field: `ageRangeSource` (Play's tier) on Android, `source` (the declaration type) on iOS. Any tier can reach `verified`, and a tier is never the verdict on its own: `tierD` means an ID was checked, and that ID can read 12. A self-declared age is whatever the user entered, and nothing here can detect a falsified birthdate. Neither store says which one your app has to require; see [18+ Only App](#18-only-app).

With the default bands, a gate that doesn't sit on a band edge effectively moves up to the next edge on Android. With a gate at 15, a 15-year-old is `verified` on iOS (Apple's range starts at 15) but lands in Play's 13-15 band and reads `supervised` on Android. Gates on band edges (13, 16, 18), or custom Play ages that match your iOS gates, keep the two platforms in agreement.

## Choosing Your Integration Level

The plugin returns one age signal; how far you build on it depends on your app, not only on which laws apply. Start at Level 1 and move up only when you actually gate content on age.

> **Not legal advice.** This maps *plugin usage* to common app shapes. Whether a level meets your obligations depends on your app, regions, and counsel.

| Level | Who it's for | What you do with the plugin |
|-------|--------------|-----------------------------|
| **1. Minimal** | Generally-available apps, no age-gated content | Call `requestAgeSignalsAccess()` then `checkAgeSignals()` once and leave the UX unchanged. Both stores can show their prompt in any region; gate on [`isEligibleForAgeFeatures()`](#regional-eligibility) to skip it where no law requires sharing. See [Generally Available App](#generally-available-app-no-age-restrictions). |
| **2. Targeted** | Apps with age-distinct areas (under/over 18, or 18+ only) | Gate those areas on `status` and the returned age range. See [Basic Example](#basic-example) and [18+ Only App](#18-only-app). |
| **3. Full** | Apps squarely in scope of these laws | Treat the client signal as one input: enforce on your server (the client result can be spoofed; on Android, Google suggests pairing it with the [Play Integrity API](https://developer.android.com/google/play/integrity/overview)), re-check when state changes, and handle every `status` and [exception](#exceptions). |

## Usage

### Basic Example

Enough to paste into an app and run.

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
    showUnrestrictedContent();
  } else {
    // Anything else counts as restricted. Use the range if there is one.
    showAgeAppropriateContent(result.ageLower, result.ageUpper);
  }
} on AgeSignalsException catch (e) {
  print('Age check failed: ${e.message}');
}
```

### Handling Every Status and Error

```dart
import 'package:age_range_signals/age_range_signals.dart';

await AgeRangeSignals.instance.initialize(ageGates: [13, 16, 18]);

try {
  final access = await AgeRangeSignals.instance.requestAgeSignalsAccess();
  if (access != AgeSignalsAccessStatus.shared) {
    print('No age signals to read: $access');
    return;
  }

  final result = await AgeRangeSignals.instance.checkAgeSignals();

  switch (result.status) {
    case AgeSignalsStatus.verified:
      print('At or above the highest gate');
    case AgeSignalsStatus.supervised:
      print('Below the highest gate');
    case AgeSignalsStatus.supervisedApprovalPending:
      print('A significant change is waiting for parent approval');
    case AgeSignalsStatus.supervisedApprovalDenied:
      print('A parent denied the change');
    case AgeSignalsStatus.declined:
      print('User declined to share');
    case AgeSignalsStatus.unknown:
      print('No verdict');
    // Never returned any more, but an exhaustive switch still has to name it.
    // ignore: deprecated_member_use
    case AgeSignalsStatus.declared:
      break;
  }

  // ageUpper is null for the open-ended 18+ band, so test ageLower.
  if (result.ageLower != null) {
    print('Age range: ${result.ageLower} - ${result.ageUpper ?? "open-ended"}');
  }

  if (result.installId != null) {
    print('Install ID: ${result.installId}'); // Android, supervised users
  }
} on MissingEntitlementException catch (e) {
  // iOS: the entitlement isn't in the signed app. See Platform Setup.
  print('Setup required: ${e.details}');
} on UserCancelledException {
  // The user closed the prompt. Let them try again later.
} on NetworkErrorException {
  // Retry, or carry on without a signal.
} on PlayServicesException {
  // Android: the Play Store or Play Services is missing or outdated, or the
  // app needs a newer version of this plugin.
} on UserNotSignedInException {
  // iOS 27+: no eligible Apple Account is signed in.
} on ApiNotAvailableException {
  // Android: outdated Play Store, the app wasn't installed from Google Play,
  // or a device type Play doesn't support.
  // iOS: Apple couldn't share the range (unavailable here, or the person
  // chose not to share at the prompt).
} on UnsupportedPlatformException {
  // iOS below 26.0, or an app built without the DeclaredAgeRange SDK.
} on ApiErrorException catch (e) {
  print('API error: ${e.message} (${e.details})');
} on AgeSignalsException catch (e) {
  // Anything not caught above.
  print('Error: ${e.message}');
}
```

### Handling verificationRequired (Android)

`verificationRequired` has no in-app resolution. The user completes verification in the Play Store app, so all your app can do is explain that and send them there. Google does not document a deep link to the verification flow; their guidance is that users "will be asked to verify or set up supervision when they visit the Play Store app", so opening the store is enough.

There is no callback when they return, so re-check on resume. Otherwise a user verifies, comes back, and your app still treats them as unverified. Only re-check while verification is pending: a store's own prompt also pauses and resumes your app, so checking on every resume would ask again as soon as the prompt closes.

```dart
class _AgeGateState extends State<AgeGate> with WidgetsBindingObserver {
  bool _verificationPending = false;

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
    if (state == AppLifecycleState.resumed && _verificationPending) _check();
  }

  Future<void> _check() async {
    final access = await AgeRangeSignals.instance.requestAgeSignalsAccess();

    _verificationPending =
        access == AgeSignalsAccessStatus.verificationRequired;
    if (_verificationPending) {
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

### Regional Eligibility

Both stores can show their sharing prompt in regions with no age assurance law, where sharing is voluntary. If you only want age signals from people who are subject to age assurance, check first. On iOS 26.2+ this is Apple's eligibility check. On Android it's Play's mandatory-sharing check, which needs a newer Play Store than `checkAgeSignals()` does.

```dart
bool obligated;
try {
  obligated = await AgeRangeSignals.instance.isEligibleForAgeFeatures();
} on AgeSignalsException {
  // The store can't answer here: iOS below 26.2 or a pre-26.2 SDK, or on
  // Android a missing or outdated Play Store. Keep your own regional decision.
  obligated = yourOwnRegionalFallback();
}

if (obligated) {
  final access = await AgeRangeSignals.instance.requestAgeSignalsAccess();
  if (access == AgeSignalsAccessStatus.shared) {
    final result = await AgeRangeSignals.instance.checkAgeSignals();
    // ...
  }
}
```

On Android the answer comes from Play's `getApplicableAgeFeatures()`: `true` when Play reports a law requiring it to share this user's age. It never throws `UnsupportedPlatformException`. It throws `PlayServicesException` when the Play Store is missing or older than this check needs, `ApiNotAvailableException` for device types Play doesn't support and for apps not installed from Google Play (see [Android Testing](#android-testing)), and `NetworkErrorException` or `ApiErrorException` for other failures. Catch `AgeSignalsException` as in the sample; an uncaught one also skips `checkAgeSignals()` on devices that could still run it. The rest of this section is about iOS.

This is the first step in [Apple's documented flow](https://developer.apple.com/documentation/declaredagerange/requesting-people-share-their-age-range-with-your-app#Check-eligibility-for-age-related-features), and `checkAgeSignals()` never runs it for you. Versions 0.4.0 to 0.5.x did, returning `unknown` for users reported as outside an applicable region, and it went wrong in the iOS 26.2.x window: the property could hang indefinitely, taking `checkAgeSignals()` with it. In sandbox it also reported `false` until the user had accepted a prompt, only updating on a later relaunch ([Apple Developer Forums](https://developer.apple.com/forums/thread/809829)). Since 0.6.0, `requestAgeRange()` alone decides the age range.

`getRequiredRegulatoryFeatures()` doesn't replace this check (and needs iOS 26.4, so on 26.2 and 26.3 this is all you have). Apple DTS [states](https://developer.apple.com/forums/thread/815952?answerId=880880022#880880022) that the feature set can be empty while this returns `true`, for regulations newer than the enum, and the obligation still stands. Treat `true` as the obligation and the feature set as the detail.

Because the call throws wherever Apple can't answer, `false` always comes from Apple. Treat it as Apple's current answer, not a stable region flag: Apple has not said whether the value is accurate before the user has accepted a sharing prompt, and devices in a regulated region have been seen flipping from `true` to `false` with no OS or account change ([Apple Developer Forums](https://developer.apple.com/forums/thread/820699)). If a law applies to you regardless, keep a caller-side fallback rather than letting `false` alone suppress the prompt.

The call runs under a 10-second deadline, and a timeout throws `ApiErrorException`. Apple caches the value, so relaunch the app after changing a sandbox scenario.

### Regulatory Features

On iOS 26.4+ and on Android you can ask which regulatory actions apply to the current user before deciding whether to prompt at all:

```dart
try {
  final features =
      await AgeRangeSignals.instance.getRequiredRegulatoryFeatures();

  if (features.contains(AgeRegulatoryFeature.declaredAgeRangeRequired)) {
    // The store requires this user to share an age range with your app.
    final access = await AgeRangeSignals.instance.requestAgeSignalsAccess();
    if (access == AgeSignalsAccessStatus.shared) {
      final result = await AgeRangeSignals.instance.checkAgeSignals();
      // ...
    }
  }

  if (features.contains(
    AgeRegulatoryFeature.significantAppChangeRequiresAdultNotification,
  )) {
    // You shipped a change regulators consider significant; show Apple's sheet.
    await AgeRangeSignals.instance.showSignificantUpdateAcknowledgment(
      updateDescription: 'We added social features and public profiles.',
    );
  }
} on AgeSignalsException {
  // The store can't answer here. Keep your own regional decision.
}
```

An empty set means none of the known `AgeRegulatoryFeature` values apply. That isn't clearance on its own on iOS; check [eligibility](#regional-eligibility) too. On Android the set holds `declaredAgeRangeRequired` exactly when `isEligibleForAgeFeatures()` returns `true`, since both read the same Play check, and the two significant-change values are iOS only. Below iOS 26.4, and in apps built with a pre-26.4 SDK, the call throws `UnsupportedPlatformException` because the requirement can't be checked. On Android it throws the same exceptions as `isEligibleForAgeFeatures()`. Catch `AgeSignalsException` as in the sample and keep your own regional logic for those devices.

### 18+ Only App

Use a single gate at 18 and check the lower bound, as [Google's](https://developer.android.com/google/play/age-signals/request-age-signals) and [Apple's](https://developer.apple.com/documentation/declaredagerange/requesting-people-share-their-age-range-with-your-app) guides do.

```dart
import 'package:age_range_signals/age_range_signals.dart';

await AgeRangeSignals.instance.initialize(ageGates: [18]);

try {
  final access = await AgeRangeSignals.instance.requestAgeSignalsAccess();
  if (access == AgeSignalsAccessStatus.verificationRequired) {
    // Android: ask the user to visit the Play Store to resolve their status.
    return;
  }
  if (access != AgeSignalsAccessStatus.shared) {
    // The user isn't sharing their age.
    return;
  }

  final result = await AgeRangeSignals.instance.checkAgeSignals();
  final ageLower = result.ageLower;

  if (ageLower == null) {
    // The user isn't sharing their age.
  } else if (ageLower >= 18) {
    // 18 or over.
  } else {
    // Under 18.
  }
} on AgeSignalsException {
  // Handle the error. See Exceptions.
}
```

- **Don't require `tierC` or `tierD`.** Play only returns them where age verification is mandatory, such as Texas, and there it returns `verificationRequired` until the user is verified or supervised. Everywhere else an adult who shares [comes back as `tierA`](https://developer.android.com/google/play/age-signals/understand-age-signals-responses), even a verified one.
- **iOS reports the declaration method in `source`.** Apple says to apply controls that fit it and doesn't require a particular one.
- **Custom ages in Play Console need to include 18.** With 13 and 17, for example, everyone 17 and over gets `ageLower: 17`.
- **[Restrict Minor Access](https://support.google.com/googleplay/android-developer/answer/9867159?hl=en)** in Play Console keeps users Google has determined to be minors from finding or installing an adults-only app. Google [requires it](https://support.google.com/googleplay/android-developer/answer/16302250?hl=en) for apps built around real-money gambling, dating, random chat or anonymous chat.

Both stores leave compliance with the law to you.

### Generally Available App (No Age Restrictions)

If your app serves all ages and gates nothing, iOS still needs gates to return a range, so use broad defaults and leave the UX unchanged. Since 0.11.0 this can show Play's sharing prompt anywhere, as Apple's already could; to skip it where no law requires sharing, check [eligibility](#regional-eligibility) first. Don't feed the result into analytics; Play's terms forbid it (see [Legal Compliance](#legal-compliance)).

```dart
import 'package:age_range_signals/age_range_signals.dart';

Future<void> checkAgeSignalsOnce() async {
  await AgeRangeSignals.instance.initialize(ageGates: [13, 16, 18]);

  try {
    final access = await AgeRangeSignals.instance.requestAgeSignalsAccess();
    if (access != AgeSignalsAccessStatus.shared) return;

    final result = await AgeRangeSignals.instance.checkAgeSignals();
    print('Age signals status: ${result.status}');
  } on AgeSignalsException catch (e) {
    // Never block the app on this.
    print('Age signals error: ${e.message}');
  }
}
```

## API Reference

Every public symbol also has dartdoc on [pub.dev](https://pub.dev/documentation/age_range_signals/latest/).

### AgeRangeSignals

Use the singleton `AgeRangeSignals.instance`.

- `Future<void> initialize({List<int>? ageGates, bool useMockData = false, AgeSignalsMockData? mockData})`: sets your age gates (see [Age gates and status](#age-gates-and-status)). `useMockData` and `mockData` are Android only and ignored on iOS; see [Android Testing](#android-testing).
- `Future<AgeSignalsAccessStatus> requestAgeSignalsAccess()`: asks for access to the user's age signals. Call it first and continue only on `shared` (see [Two calls](#two-calls)).
- `Future<AgeSignalsResult> checkAgeSignals()`: reads the age signals.
- `Future<bool> isEligibleForAgeFeatures()`: whether the user is subject to age assurance. Apple's check on iOS 26.2+, Play's mandatory-sharing check on Android. Throws `UnsupportedPlatformException` below iOS 26.2 and in apps built with Xcode older than 26.2, and another `AgeSignalsException` when the store can't answer. See [Regional Eligibility](#regional-eligibility).
- `Future<Set<AgeRegulatoryFeature>> getRequiredRegulatoryFeatures()`: which regulatory actions the store requires for the user (iOS 26.4+ and Android; Android only reports `declaredAgeRangeRequired`). Throws `UnsupportedPlatformException` below iOS 26.4 and in apps built with Xcode older than 26.4, and another `AgeSignalsException` when the store can't answer. See [Regulatory Features](#regulatory-features).
- `Future<void> showSignificantUpdateAcknowledgment({required String updateDescription})`: shows Apple's sheet for acknowledging a significant app change (iOS 26.4+). Returning normally means the person acknowledged it. Every other outcome throws:
    - `UnsupportedPlatformException` on Android, below iOS 26.4 and in apps built with Xcode older than 26.4, rather than silently succeeding, so your compliance flow can't be fooled by a no-op
    - `ApiNotAvailableException` when Apple reports the sheet unavailable. Apple documents no separate error for a dismissed sheet and elsewhere reports a person's refusal the same way, so don't treat this as proof the sheet never appeared
    - `UserCancelledException` on explicit cancellation
    - `ApiErrorException` for other failures

### AgeSignalsResult

- `AgeSignalsStatus status`: the verdict (see [Age gates and status](#age-gates-and-status))
- `int? ageLower`, `int? ageUpper`: the age range, on both platforms. Both are `null` when nothing was shared, and `ageUpper` is also `null` for an open-ended top band such as 18+
- `AgeRangeSource? ageRangeSource` (Android): how Play established the age. The `verified`/`supervised` verdict comes from the band, not from this tier
- `SignificantChangeStatus? significantChangeStatus` (Android, supervised users): parent approval state for significant app changes
- `DateTime? significantChangeApprovalDate` (Android, supervised users): effective date of the most recently approved significant change. Named `mostRecentApprovalDate` before 0.8.0; the old name still works as a deprecated alias
- `String? installId` (Android, supervised users): when a parent revokes approval, Google lists this id on the Play Console's Revoked app approvals tab as a CSV download retained for 90 days. Store it on your backend and ingest revocations within that window if you need to act on them. Google permits no other use
- `AgeDeclarationSource? source` (iOS): how the age was declared
- `List<String>? activeParentalControls` (iOS): parental controls active on the user's account, as raw Apple identifiers such as `communicationLimits`

#### What Android returns

Play doesn't return a single status. The plugin derives it from the age band Play reports, measured against your highest gate, with the tier and the app-version approval state alongside.

| status | ageRangeSource | ageLower / ageUpper | installId | Derived from |
|--------|----------------|---------------------|-----------|--------------|
| `verified` | any tier | Populated / `null` or populated† | `null` or populated | Band starts at or above your highest gate |
| `supervised` | `tierB` | Populated / Populated† | Populated | Parent-managed account below your highest gate |
| `supervised` | `tierA`/`tierC`/`tierD` | Populated / Populated† | `null` | Unsupervised user below your highest gate |
| `supervisedApprovalPending` | `tierB` | Populated†, or `null` with no band yet | Populated | A significant change awaits parent approval |
| `supervisedApprovalDenied` | `tierB` | Populated†, or `null` with no band yet | Populated | Parent denied the change; use the previously approved state |
| `unknown` | `null` or any tier | `null` / `null` | `null` | Access not shared, verification required, or no age band reported |

† `ageUpper` is `null` only for Play's open-ended top band (18+ unless you set custom ages). With a lower gate a `verified` result can carry a closed band (gates `[13]` and Play's 16-17 band give `ageLower: 16, ageUpper: 17`), so don't use `ageUpper == null` as a proxy for "adult".

The two approval statuses are reported whatever the age, because an outstanding parent decision matters either way. That includes users Play has no band for yet.

Android never returns `declined`. Play reports `notShared` both for a genuine refusal and for a user who isn't eligible, and the two are indistinguishable, so the plugin reports `unknown` rather than assert an intent.

#### What iOS returns

| status | ageLower / ageUpper | source | Notes |
|--------|---------------------|--------|-------|
| `verified` | Populated / `null` or populated | Populated* | User shared; lower bound at or above your highest gate (`ageUpper` is `null` for an open-ended top range such as 18+) |
| `supervised` | Populated / Populated | Populated* | User shared; lower bound below your highest gate. For someone under your lowest gate Apple sends no lower bound, and the plugin reports `ageLower: 0`, like Android's youngest band |
| `declined` | `null` / `null` | `null` | User declined to share |
| `unknown` | `null` / `null` | Populated* | User shared, but Apple reported no bounds at all, so there is no verdict |

\* `source` can be `null` for a declaration type the plugin doesn't recognize, even for `verified` or `supervised`. Apple's confirmation methods (payment card, government ID and so on) map to `confirmed`, not `null`.

### AgeSignalsStatus

- `verified`: the reported range starts at or above your highest gate
- `supervised`: the reported range falls below your highest gate. An age verdict, not the supervision relationship
- `supervisedApprovalPending` (Android): a significant change awaits parent approval
- `supervisedApprovalDenied` (Android): the parent denied the significant change
- `declined` (iOS): the user declined to share. On Android a decline is `AgeSignalsAccessStatus.notShared` from the access request
- `unknown`: no verdict. Access wasn't shared or verification is required (Android), or the platform reported a range with no bounds at all. An unavailable API throws instead
- `declared`: deprecated and never returned. It mixed up the verdict with how the age was established, so a self-declared adult could not clear a `verified` gate while `tierC` and `tierD` passed automatically. Read `ageRangeSource == AgeRangeSource.tierA` instead

### AgeSignalsAccessStatus

Returned by `requestAgeSignalsAccess()`:

- `shared`: go ahead with `checkAgeSignals()`. The only value iOS returns
- `notShared`: the user declined or chose earlier not to share, a parent rejected sharing, or the user is not eligible. Not an error
- `verificationRequired`: the user has to verify their age in the Play Store app first (see [Handling verificationRequired](#handling-verificationrequired-android))
- `unknown`: Play reported a state this plugin version doesn't recognize

### AgeRangeSource

How Google Play established the age range (Android only). The tier names and descriptions are Google's:

- `tierA`: the user gave their age to Google, which may or may not have confirmed it
- `tierB`: the age is managed by a parent or guardian
- `tierC`: the age is assessed using a credit card, email address, selfie assessment, government ID, or tax ID. Only returned where age verification is mandatory
- `tierD`: the age is checked using a government ID plus selfie assessment, or a Digital ID. Only returned where age verification is mandatory

### SignificantChangeStatus

Parent approval of significant app changes you report on the Play Console's Age signals page (Android only, supervised users). Approval is cumulative: one parent approval covers every change still pending since the last one.

- `approved`: the parent approved the most recent change(s); `significantChangeApprovalDate` carries the effective date
- `pending`: approval requested but not answered yet; restrict the functionality behind the change
- `declined`: the parent denied the change(s); restrict the functionality behind them

### AgeDeclarationSource

How the age was declared (iOS only):

- `selfDeclared`: by the user
- `guardianDeclared`: by a guardian
- `confirmed`: confirmed through a method such as a payment card or government ID, by the user or a guardian (iOS 26.2+). iOS 26.2 added a separate value for each method, and the iOS 26.5 SDK deprecates those in favour of `confirmed`. The plugin reports `confirmed` for all of them

### AgeRegulatoryFeature

Regulatory actions the store can require, returned by `getRequiredRegulatoryFeatures()`. iOS 26.4+ reports all three; Android only reports `declaredAgeRangeRequired`:

- `declaredAgeRangeRequired`: the user must share their age range with your app
- `significantAppChangeRequiresAdultNotification`: adult users must acknowledge your significant app change (use `showSignificantUpdateAcknowledgment()`)
- `significantAppChangeRequiresParentalConsent`: a parent must consent before a child continues after a significant change. The consent flow itself runs through Apple's PermissionKit and App Store Server Notifications, which this plugin does not wrap

### AgeSignalsMockData

Configures Google's `FakeAgeSignalsManager` for [Android testing](#android-testing). Android only; ignored on iOS.

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
  bool? mandatorySharing,
  DateTime? significantChangeApprovalDate,
})
```

- `status`: the status to mock. The result's `status` is still re-derived from the resulting band, exactly as with a real response, so a mock whose band contradicts its `status` comes back with the band's verdict. `status: declared` therefore returns `supervised` on its default 13-15 band; give it `ageLower: 18` to model a self-declared adult
- `ageLower`, `ageUpper`: the mocked band
- `ageRangeSource`: the mocked tier. When `null` it's derived from `status`: `verified` maps to `tierC`, `declared` to `tierA`, the supervised family to `tierB`
- `significantChangeStatus`: when `null` it's derived from `status` (`supervisedApprovalPending` maps to `pending`, `supervisedApprovalDenied` to `declined`)
- `significantChangeApprovalDate`: the mocked approval date
- `accessStatus`: what `requestAgeSignalsAccess()` returns; `shared` when `null`
- `mandatorySharing`: whether Play reports sharing as mandatory for the mocked user, which drives `isEligibleForAgeFeatures()` and `getRequiredRegulatoryFeatures()`; `true` when `null`
- `installId`: the mocked install id
- `source`: iOS-flavoured and not read on Android; use `ageRangeSource` to pick the Play tier

### Exceptions

Every exception extends `AgeSignalsException` and carries a human-readable `message`, a `code` for programmatic handling, and `details` with platform diagnostics (error domain, code, exception type) when the platform supplies them.

| Exception | Thrown when |
|-----------|-------------|
| `ApiNotAvailableException` | The API isn't available. On Android: an outdated Play Store, an app not installed from Google Play, or a device type Play doesn't support ([details](#api_not_available-android)). On iOS: Apple couldn't share the age range, because sharing isn't available for this user or region or because the person was prompted and chose not to share. An app without the entitlement can get this too |
| `UnsupportedPlatformException` | The OS version, or the SDK the app was built with, doesn't support the call |
| `NotInitializedException` | iOS: `initialize()` hasn't supplied any gates |
| `MissingEntitlementException` | iOS: the entitlement is missing from the signed app ([fix](#missingentitlementexception-ios)) |
| `UserCancelledException` | iOS: the user cancelled the prompt, or (iOS 27+) declined the age range sharing setup |
| `UserNotSignedInException` | iOS 27+: no Apple Account is signed in, or the account (such as a managed one) isn't eligible for age range sharing |
| `NetworkErrorException` | A network or server issue stopped the request |
| `PlayServicesException` | Android: the Play Store or Play Services is missing, outdated, or can't be reached, or the app needs a newer version of this plugin because Play dropped its library version. The eligibility calls need a newer Play Store than the rest |
| `MockDataNotAllowedException` | Android: `useMockData: true` in a non-debuggable build ([why](#android-testing)) |
| `ApiErrorException` | Any other platform API error |

## Legal Compliance

Google's [terms](https://developer.android.com/google/play/age-signals/overview#terms-service) only allow information from the Play Age Signals API to be used to provide age-appropriate content and experiences in compliance with laws, and only by the app that requested it. The [Play policy](https://support.google.com/googleplay/android-developer/answer/16585319#age_signals) spells out what's prohibited: advertising, marketing or personalization (including targeted ads), data analytics, user profiling or business intelligence, and selling, sharing or transferring the data to any third party except as strictly required by law. Using it for a prohibited purpose can get your API access terminated and your apps suspended or taken down from Google Play.

The plugin doesn't collect or store any user data; age data comes straight from the platform APIs. Make sure your app's privacy policy describes how you use it.

## Testing

### Android Testing

> **Debuggable builds only.** `useMockData: true` throws `MockDataNotAllowedException` in a non-debuggable build. The fake manager forges age signals, so leaving it enabled in a shipped release would hand a fabricated age gate to real users. If you need mock data on a release-like artifact, build a debuggable release variant.

`useMockData: true` swaps the real API for Google's `FakeAgeSignalsManager`. Without `mockData` it returns a supervised user in Play's 13-15 band (0-12 if your highest gate is 15 or lower):

```dart
await AgeRangeSignals.instance.initialize(
  ageGates: [13, 16, 18],
  useMockData: true,
);

final result = await AgeRangeSignals.instance.checkAgeSignals();
print(result.status);    // AgeSignalsStatus.supervised
print(result.ageLower);  // 13
print(result.ageUpper);  // 15
print(result.installId); // "test_install_id_12345"
```

Pass `mockData` to cover any other scenario from Dart, without touching Kotlin:

```dart
await AgeRangeSignals.instance.initialize(
  ageGates: [13, 16, 18],
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
| ID-checked adult | `status: verified, ageRangeSource: AgeRangeSource.tierD` | `verified` pinned to `tierD` |
| Awaiting parent approval | `status: supervisedApprovalPending, ageLower: 13, ageUpper: 15` | `supervisedApprovalPending`, change status `pending` |
| Parent denied the change | `status: supervisedApprovalDenied, ageLower: 13, ageUpper: 15` | `supervisedApprovalDenied`, change status `declined` |
| No signals at all | `status: unknown` | `unknown`, no band, no tier |
| Sharing declined | `status: unknown, accessStatus: AgeSignalsAccessStatus.notShared, mandatorySharing: false` | `requestAgeSignalsAccess()` returns `notShared`; `checkAgeSignals()` reports `unknown`. Users can only decline where sharing isn't mandatory |
| Not a mandatory region | `status: verified, ageRangeSource: AgeRangeSource.tierA, ageLower: 18, mandatorySharing: false` | `isEligibleForAgeFeatures()` returns `false`; the regulatory set is empty |

Bands the mock fills in for you are real Play bands (0-12, 13-15, 16-17), with one exception: because the verdict is derived from the band, a verified mock defaults to an open-ended band starting at your highest gate (18 until you supply gates), with `ageUpper: null`. A real verified response reports Play's 18+ band (`ageLower: 18, ageUpper: null`), so pass `ageLower: 18` to mirror it exactly.

To hit the real API from a sideloaded debug build, add the device's Google account as a license tester in Play Console. Otherwise Play blocks apps that weren't installed from Google Play with `APP_NOT_OWNED`, which the plugin reports as `ApiNotAvailableException`. The package name has to match the app configured in Play Console ([Google's guide](https://developer.android.com/google/play/age-signals/test-age-signals-api)). If a sideloaded build still gets `APP_NOT_OWNED`, install it from the internal testing track instead.

### iOS Testing

`useMockData` and `mockData` are ignored on iOS, because Apple provides no in-process mock for DeclaredAgeRange. Instead, Apple offers sandbox Age Assurance scenarios (iOS 26.2+) for getting real responses on a device. You need:

- A real iOS 26.2+ device with Developer Mode enabled (no simulator support)
- The `com.apple.developer.declared-age-range` capability registered on your App ID (see [iOS setup](#ios); a hand-edited entitlements key alone gets stripped at signing)
- A Sandbox Apple Account signed in only under Settings → Developer → Sandbox Apple Account (not the normal iCloud sign-in, or eligibility misbehaves), with its App Store territory set to a region where Apple's age assurance applies (see [Regulatory Status](#regulatory-status))

Then open Settings → Developer → Sandbox Apple Account → Manage → Age Assurance on the device, select a scenario, relaunch your app (the value is cached) and call `checkAgeSignals()`. You can also configure test scenarios in App Store Connect.

With age gates `[13, 16, 18]`, Apple's scenarios come through the plugin as follows:

| Sandbox scenario | `status` | ageLower | ageUpper | source |
|---|---|---|---|---|
| Under 13, significant change approved | `supervised` | 0 | 12 | `guardianDeclared` |
| 13 - 15, significant change approved | `supervised` | 13 | 15 | `guardianDeclared` |
| 16 - 17, significant change declined | `supervised` | 16 | 17 | `guardianDeclared` |
| 18+, age not confirmed, significant change not applicable | `verified` | 18 | `null` | `selfDeclared` |
| 18+, age confirmed, significant change not applicable | `verified` | 18 | `null` | `confirmed` |
| 18+, age confirmed, significant change applicable | `verified` | 18 | `null` | `confirmed` |

The `source` column is what Apple documents for each scenario. The same Manage screen also offers Revoke App Consent, which only exercises App Store Server Notifications and changes nothing this plugin returns.

> **The two "declines" are different.** A `declined` *status* means the user refused to share their age (DeclaredAgeRange `.declinedSharing`). The "16 - 17, significant change **declined**" sandbox scenario is not that. It still returns the 16-17 range via DeclaredAgeRange, so the plugin reports `supervised`. The "declined" there is a PermissionKit guardian-permission response, a separate Apple framework this plugin does not wrap. DeclaredAgeRange has no "denied" state, so a guardian decline surfaces as the user's real age range (`supervised`), not a distinct denied status. A revoked consent never reaches the plugin either: Apple stops the app from launching and notifies your server with `RESCIND_CONSENT` ([Apple's age assurance Q&A](https://developer.apple.com/support/age-assurance/)). If you need the guardian approve/deny signal itself, use PermissionKit plus App Store Server Notifications.

Apple's guide: [Testing age assurance in sandbox](https://developer.apple.com/documentation/storekit/testing-age-assurance-in-sandbox).

## Troubleshooting

### MissingEntitlementException (iOS)

The `com.apple.developer.declared-age-range` entitlement isn't in the signed app at runtime. Usually the key is in `Runner.entitlements` but the capability isn't registered on your App ID (Xcode falls back to a wildcard profile without it), or the entitlements file exists but no `CODE_SIGN_ENTITLEMENTS` build setting points at it, so it never enters the signature.

1. Add the key to `Runner.entitlements` (see [iOS setup](#ios)).
2. Make sure the Runner target's `CODE_SIGN_ENTITLEMENTS` build setting references that file. Adding the capability in Xcode's Signing & Capabilities tab does this for you.
3. Enable the Declared Age Range capability on your App ID via Xcode → Signing & Capabilities → + Capability.
4. Let Xcode regenerate the provisioning profile (toggle the team or hit "Try Again" under Signing if needed).
5. Verify with `codesign -d --entitlements :- YourApp.app | grep declared-age-range`.

Versions before 0.7.0 also misreported "age range sharing not available for this user or region" as `MissingEntitlementException`, even on correctly entitled apps. Since 0.7.0 that state is `ApiNotAvailableException`.

### Regulatory features time out (iOS)

`ApiErrorException: "requiredRegulatoryFeatures failed: Timed out after 10.0s"` means Apple's call hung instead of returning, and the plugin's 10-second deadline turned the hang into an error. It has been seen on a real iOS 26.5 device in debug builds, even with the correct entitlement and a covered-region sandbox account, while the identical app in release mode answered in about 140 ms. Treat it as transient and test regulatory features on release (or TestFlight) builds.

### API_NOT_AVAILABLE (Android)

Play reports this when the installed Play Store is too old for the API; ask the user to update it. The plugin also maps Play's `APP_NOT_OWNED` here, which means the app wasn't installed from Google Play. Sideloaded debug builds hit this unless the device's Google account is a license tester (see [Android Testing](#android-testing)). Play's `DEVICE_NOT_SUPPORTED` lands here too: the API covers phones, foldables and tablets, so other device types get it.

### PRESENTATION_CONTEXT_UNAVAILABLE (Android)

`requestAgeSignalsAccess()` was called with no foreground activity to show Play's age sharing prompt on, for example from a background isolate or before the first frame. It surfaces as `ApiErrorException`. The plugin picks up the activity on its own, so call it from a foregrounded app.

### Play's prompt never appears (Android)

The prompt is only shown to unsupervised users whose Play setting is "Ask before sharing". "Always Share" and "Never Share" resolve without a prompt, parents manage sharing for supervised users in Family Link, where sharing is mandatory Play shares without asking, and in US states that require verified ages, unverified users get `verificationRequired` instead of a prompt. If the user dismisses or declines it, Play shows it a few more times and then suppresses it for a while, answering `notShared` in the meantime. Users can also switch sharing on or off for your app in the Play Store under Settings → Age sharing and family → [Age range sharing](https://support.google.com/googleplay/answer/17232873).

### checkAgeSignals() hangs (iOS, before 0.6.0)

Versions before 0.6.0 awaited Apple's `isEligibleForAgeFeatures`, which can hang in the iOS 26.2.x window. Upgrade to 0.6.0 or later.

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

On Android, skipping the access call means `checkAgeSignals()` reports `unknown`. Also pass `ageGates` on Android now, since your highest gate sets the bar for `verified`.

On iOS nothing changes in behaviour, with one catch: `requestAgeSignalsAccess()` throws `UnsupportedPlatformException` below iOS 26.0 and `NotInitializedException` without gates, so the errors you used to catch around `checkAgeSignals()` can now come from the first call. If your `try` only wrapped `checkAgeSignals()`, widen it to cover both calls.

Every other breaking change lists its migration step in the [CHANGELOG](CHANGELOG.md). Two notes for older versions: the `mostRecentApprovalDate` rename only affects 0.7.x, since the field arrived in 0.7.0, and coming from 0.10.x or earlier also needs `minSdk` 24.

## Example App

[`example/lib/main.dart`](example/lib/main.dart) runs on both platforms. It goes through the access request and the check, has a mock data switch with a scenario picker on Android, and has buttons for the eligibility check, regulatory features and the significant update sheet.

## Contributing

Issues and pull requests are welcome on [GitHub](https://github.com/zigapovhe/age_range_signals/issues).

## License

MIT, see [LICENSE](LICENSE).

## References

- [Google Play Age Signals API](https://developer.android.com/google/play/age-signals/overview)
- [Apple DeclaredAgeRange](https://developer.apple.com/documentation/declaredagerange/)
