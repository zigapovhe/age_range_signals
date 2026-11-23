# age_range_signals

[![pub package](https://img.shields.io/pub/v/age_range_signals.svg)](https://pub.dev/packages/age_range_signals)
[![pub points](https://img.shields.io/pub/points/age_range_signals)](https://pub.dev/packages/age_range_signals/score)
[![Flutter](https://github.com/zigapovhe/age_range_signals/actions/workflows/flutter.yml/badge.svg)](https://github.com/zigapovhe/age_range_signals/actions/workflows/flutter.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/zigapovhe/age_range_signals/blob/main/LICENSE)

A Flutter plugin for age verification. It uses the Google Play Age Signals API on Android and Apple's DeclaredAgeRange API on iOS 26+.

## Quickstart

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

Call both methods in this order while your app is in the foreground. On Android, Play's sharing prompt can appear during `requestAgeSignalsAccess()`. On iOS, Apple's prompt can appear during `checkAgeSignals()`, and `requestAgeSignalsAccess()` just returns `shared`.

Most apps only need these sections: [Setup](#setup), [What You Get Back](#what-you-get-back), [Regional Eligibility](#regional-eligibility) and [Data Use](#data-use). The rest of this page is reference.

Upgrading from an older version? [MIGRATION.md](https://github.com/zigapovhe/age_range_signals/blob/main/MIGRATION.md) lists what to change in your code.

## Table of Contents

- [Features](#features)
- [Setup](#setup)
- [What You Get Back](#what-you-get-back)
- [Regional Eligibility](#regional-eligibility)
- [Data Use](#data-use)
- [Migrating from an older version](https://github.com/zigapovhe/age_range_signals/blob/main/MIGRATION.md)
- Reference
    - [Regulatory Status](#regulatory-status)
    - [How It Works](#how-it-works)
    - [Choosing Your Integration Level](#choosing-your-integration-level)
    - [More Examples](#more-examples)
        - [Handling verificationRequired (Android)](#handling-verificationrequired-android)
        - [Regulatory Features](#regulatory-features)
        - [18+ Only App](#18-only-app)
        - [Generally Available App](#generally-available-app-no-age-restrictions)
    - [API Reference](#api-reference)
    - [Testing](#testing)
    - [Troubleshooting](#troubleshooting)
    - [Legal Compliance](#legal-compliance)
    - [Example App](#example-app)

## Features

- ✅ Google Play Age Signals API on Android (API 24+), including Play's age sharing prompt
- ✅ Apple DeclaredAgeRange API on iOS 26.0+
- ✅ One `status` that means the same thing on both platforms, measured against your own age gates
- ✅ Eligibility check, to see whether age rules apply to the user (iOS 26.2+ and Android)
- ✅ Regulatory feature check (iOS 26.4+ and Android) and Apple's significant update sheet (iOS 26.4+)
- ✅ Mock data on Android through Google's `FakeAgeSignalsManager`
- ✅ A separate exception type for each kind of error
- ✅ Swift Package Manager and CocoaPods

## Setup

| Platform | Minimum app version | API available from | API |
|----------|---------------------|--------------------|-----|
| Android  | API 24 (Android 7.0) | API 24 | Google Play Age Signals |
| iOS      | iOS 13.0 | iOS 26.0 (eligibility 26.2, regulatory features 26.4) | DeclaredAgeRange |

Your iOS app can still target versions older than 26.0. The plugin checks the version at runtime. On older iOS, or in an app built with an older Xcode, it throws `UnsupportedPlatformException`.

### Android

You don't need to add anything to Gradle. The plugin brings in `com.google.android.play:age-signals` 0.0.6 itself. You need:

- `minSdk` 24 or higher (`minSdkVersion` in older projects). Google's docs still say 23, but age-signals 0.0.6 requires 24, and a lower value fails the build
- The Google Play Store and Google Play Services installed and up to date on the device
- Your app installed from Google Play. Play blocks apps installed any other way, unless the device's Google account is a license tester (see [Android Testing](#android-testing))
- Flutter 3.47 or newer. AGP 9 (with or without built-in Kotlin) and AGP 8 both work. Flutter 3.50 needs AGP 9.1.1 or newer

The Play Age Signals API is still in beta. Use [mock data](#android-testing) to test scenarios you can't reach with a real account.

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

2. Enable the **Declared Age Range** capability on your App ID. In Xcode, open your Runner target → Signing & Capabilities → + Capability → Declared Age Range, or enable it on your App ID in the [Developer portal](https://developer.apple.com/account/resources/identifiers/list). It's self-serve: you don't need to request it or wait for Apple's approval.

Step 2 is easy to miss. If the key is in `Runner.entitlements` but the App ID doesn't have the capability, Xcode quietly removes the entitlement when it signs the app, and the age range request fails at runtime. To check that the entitlement is in your signed build:

```bash
codesign -d --entitlements :- /path/to/YourApp.app | grep declared-age-range
```

If `com.apple.developer.declared-age-range` isn't listed, see [MissingEntitlementException](#missingentitlementexception-ios).

## What You Get Back

`checkAgeSignals()` returns an `AgeSignalsResult`. Most apps only need two of its fields:

- `status` is the result of the age check. `verified` means the user's age range starts at or above your highest age gate, and `supervised` means it's below. Despite the names, `verified` doesn't mean an ID was checked, and `supervised` doesn't mean a parent manages the account.
- `ageLower` and `ageUpper` are the age range. Both are `null` when nothing was shared. `ageUpper` is also `null` for a range with no upper limit, such as 18+.

`declined` (iOS) and `unknown` mean there's no age to check. `supervisedApprovalPending` and `supervisedApprovalDenied` (Android) mean a parent hasn't approved a significant change you reported in Play Console.

Use the same age gates on both platforms. With gates at 13, 16 and 18, Android and iOS give the same result, because those ages match the edges of Play's age bands ([details](#age-gates-and-status)).

## Regional Eligibility

Both stores can also show their sharing prompt where no age law applies and sharing is optional. If you only want to ask people that a law applies to, check first. On iOS 26.2+ this uses Apple's eligibility check. On Android it uses Play's check for mandatory sharing, which needs a newer Play Store than `checkAgeSignals()`.

```dart
bool obligated;
try {
  obligated = await AgeRangeSignals.instance.isEligibleForAgeFeatures();
} on AgeSignalsException {
  // The store can't answer: iOS below 26.2, an app built with an older Xcode,
  // or a missing or outdated Play Store. Decide by region yourself.
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

On iOS this is the first step in [Apple's documented flow](https://developer.apple.com/documentation/declaredagerange/requesting-people-share-their-age-range-with-your-app#Check-eligibility-for-age-related-features). A `false` answer can change later, so if a law applies to you anyway, keep your own fallback ([details](#eligibility-details)).

## Data Use

Google lets you use Play's age signals only to give users age-appropriate content, and only in the app that asked for them. You can't use them for ads, analytics or profiling, or share them with anyone else unless the law requires it ([details](#legal-compliance)).

---

Everything below is reference.

## Regulatory Status

Related laws and store rules include Texas SB 2420, Utah's and Louisiana's App Store Accountability Acts, Alabama HB 161, California AB 1043, Brazil's Digital ECA (Lei 15.211), Apple's age requirements in Australia and Singapore, and Apple's Time Allowances rules for social media apps. Google says Play will return age signals for all users by December 11, 2026. These laws keep changing, so rely on what the plugin returns at runtime instead of hard-coding regions. Current status, dates and sources are in [REGULATORY.md](https://github.com/zigapovhe/age_range_signals/blob/main/REGULATORY.md).

## How It Works

### Two calls

Reading age signals takes two calls, as in Google's API. The plugin uses the same two calls on iOS, but each platform shows its prompt in a different call.

`requestAgeSignalsAccess()` asks for access. On Android it can show Play's age sharing sheet over your activity, so call it while your app is in the foreground. It returns one of these:

- `shared`: go ahead and call `checkAgeSignals()`
- `notShared`: the user declined or isn't eligible. This is not an error
- `verificationRequired`: the user has to verify their age in the Play Store first
- `unknown`: a state the plugin doesn't recognize

Only call `checkAgeSignals()` after `shared`. If you skip the access call, Play never shows its prompt and `checkAgeSignals()` reports `unknown`.

Play doesn't always show the sheet. In US states whose laws require app stores to provide verified ages, it skips the sheet. Users who are already verified or supervised come back `shared`. Unverified users come back `verificationRequired` and have to finish in the Play Store ([handling it](#handling-verificationrequired-android)). Where a law requires sharing but not verification, Play [shares without asking](https://support.google.com/googleplay/answer/17232873). Everywhere else it can show the sheet. To avoid it there, call `isEligibleForAgeFeatures()` first ([Regional Eligibility](#regional-eligibility)).

On iOS, `requestAgeSignalsAccess()` shows nothing and returns `shared`. It still throws `UnsupportedPlatformException` below iOS 26.0, and `NotInitializedException` if `initialize()` got no gates. So it also works as an early check that `checkAgeSignals()` can run.

`checkAgeSignals()` reads the signals. On Android it never shows anything. On iOS it's the call that shows Apple's sharing sheet, and if the user refuses, it returns `AgeSignalsStatus.declined`.

### Age gates and `status`

Call `initialize()` with the same gates on both platforms, for example `[13, 16, 18]`.

iOS requires gates. Apple sorts the user's age into ranges based on your gates. It accepts 1 to 3 gates, at least 2 years apart, so `[13, 14]` is rejected with an invalid-request error. Without gates, `requestAgeSignalsAccess()` and `checkAgeSignals()` throw `NotInitializedException`. With more than 3, `checkAgeSignals()` throws `ApiErrorException`. `initialize()` itself doesn't check them.

In some regions with age laws, people can't decline sharing, and the region's own age gates replace yours. The range you get back there may not match your gates. Apple also caches the range. When someone moves into a new age range, Apple keeps returning the old one until the anniversary of when they first declared their age, unless they update it in Settings.

Play ignores your gates. It reports its default age bands: 0-12, 13-15, 16-17 and 18+. You can replace them with up to three custom minimum ages on the Age signals page in Play Console. They must be at least 2 years apart and can be changed once a year. The plugin can't set them for you. When someone moves into a new band, Google [may wait](https://support.google.com/googleplay/answer/17232873) before sharing it.

On Android the plugin uses your highest gate as the line for `verified`. Until you pass gates, that line is 18. If a later `initialize()` call leaves the gates out, the plugin keeps the ones you already set.

`status` follows the same rule on both platforms. It's `verified` when the age range starts at or above your highest gate, and `supervised` when it's below. It doesn't tell you whether a parent manages the account. On Android, check `ageRangeSource == AgeRangeSource.tierB` for that.

How the age was established is a separate field: `ageRangeSource` (Play's tier) on Android and `source` (how the age was declared) on iOS. Any tier can be `verified`. A tier alone never tells you the age: `tierD` means an ID was checked, but the ID could show the user is 12. A self-declared age is whatever the user typed in, and nothing here can detect a false birthdate. Neither store says which source your app has to require. See [18+ Only App](#18-only-app).

With the default bands, a gate that isn't on a band edge moves up to the next edge on Android. Take a gate at 15. A 15-year-old is `verified` on iOS, because Apple's range starts at 15. On Android they're in Play's 13-15 band, so they're `supervised`. To keep both platforms in agreement, use gates on band edges (13, 16, 18), or set custom Play ages that match your iOS gates.

### Eligibility details

On Android the answer comes from Play's `getApplicableAgeFeatures()`. It's `true` when Play reports that a law requires it to share this user's age. On Android this call never throws `UnsupportedPlatformException`. It can throw:

- `PlayServicesException` when the Play Store is missing or too old for this check
- `ApiNotAvailableException` on device types Play doesn't support, and for apps not installed from Google Play (see [Android Testing](#android-testing))
- `NetworkErrorException` or `ApiErrorException` for other failures

Catch `AgeSignalsException` as in the sample. If you don't, the error also stops you from reaching `checkAgeSignals()` on devices where it would still work.

The rest of this section is about iOS.

This is the first step in [Apple's documented flow](https://developer.apple.com/documentation/declaredagerange/requesting-people-share-their-age-range-with-your-app#Check-eligibility-for-age-related-features), but `checkAgeSignals()` never runs it for you. On iOS 26.2.x, Apple's check could hang forever. In sandbox it also reported `false` until the user had accepted a prompt, and only updated after a relaunch ([Apple Developer Forums](https://developer.apple.com/forums/thread/809829)).

`getRequiredRegulatoryFeatures()` doesn't replace this check. It also needs iOS 26.4, so on 26.2 and 26.3 this check is all you have. Apple DTS [says](https://developer.apple.com/forums/thread/815952?answerId=880880022#880880022) the feature set can be empty while this check returns `true`, when a regulation is newer than the list. The obligation still applies then. So treat `true` as the obligation, and the feature set as the details.

The call throws wherever Apple can't answer, so `false` always comes from Apple. But it's only Apple's answer right now. Apple hasn't said whether the value is accurate before the user has accepted a sharing prompt. Devices in a covered region have also been seen switching from `true` to `false` with no OS or account change ([Apple Developer Forums](https://developer.apple.com/forums/thread/820699)). If a law applies to you anyway, keep your own fallback instead of letting `false` alone hide the prompt.

The call times out after 10 seconds and then throws `ApiErrorException`. Apple caches the value, so relaunch the app after you change a sandbox scenario.

## Choosing Your Integration Level

The plugin gives you one age signal. How much you build on it depends on your app, not only on which laws apply. Start at Level 1, and only move up when you actually restrict content by age.

> **Not legal advice.** This shows how common kinds of apps use the plugin. Whether a level meets your legal obligations depends on your app, your regions and your lawyer.

| Level | Who it's for | What you do with the plugin |
|-------|--------------|-----------------------------|
| **1. Minimal** | Apps for all ages with no age-restricted content | Call `requestAgeSignalsAccess()` and then `checkAgeSignals()` once, and don't change the app. Both stores can show their prompt in any region. To skip it where no law requires sharing, check [`isEligibleForAgeFeatures()`](#regional-eligibility) first. See [Generally Available App](#generally-available-app-no-age-restrictions). |
| **2. Targeted** | Apps with parts for different ages (under/over 18, or 18+ only) | Restrict those parts based on `status` and the age range. See [Quickstart](#quickstart) and [18+ Only App](#18-only-app). |
| **3. Full** | Apps the laws clearly cover | Treat the result on the device as one input. Enforce on your server, because the result on the device can be faked. On Android, Google suggests pairing it with the [Play Integrity API](https://developer.android.com/google/play/integrity/overview). Check again when things change, and handle every `status` and [exception](#exceptions). |

## More Examples

### Handling verificationRequired (Android)

Your app can't resolve `verificationRequired` itself. The user verifies in the Play Store app, so all your app can do is explain that and send them there. Google doesn't document a direct link to the verification screen. It says users "will be asked to verify or set up supervision when they visit the Play Store app", so opening the store is enough.

Nothing tells your app when they come back, so check again when the app resumes. Otherwise a user verifies, comes back, and your app still treats them as unverified. Only check again while verification is pending. A store's own prompt also pauses and resumes your app, so checking on every resume would ask again as soon as the prompt closes.

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

### Regulatory Features

On iOS 26.4+ and on Android, you can ask which legal requirements apply to the current user before you decide whether to show the prompt:

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
  // The store can't answer. Decide by region yourself.
}
```

An empty set means none of the known `AgeRegulatoryFeature` values apply. On iOS that doesn't mean you're in the clear, so check [eligibility](#regional-eligibility) too. On Android the set contains `declaredAgeRangeRequired` exactly when `isEligibleForAgeFeatures()` returns `true`, because both read the same Play check. The two significant-change values are iOS only.

Below iOS 26.4, and in apps built with Xcode older than 26.4, the call throws `UnsupportedPlatformException`, because the requirement can't be checked. On Android it throws the same exceptions as `isEligibleForAgeFeatures()`. Catch `AgeSignalsException` as in the sample, and decide by region yourself on those devices.

### 18+ Only App

Use one gate at 18 and check the lower bound of the range, as [Google's](https://developer.android.com/google/play/age-signals/request-age-signals) and [Apple's](https://developer.apple.com/documentation/declaredagerange/requesting-people-share-their-age-range-with-your-app) guides do.

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

- **Don't require `tierC` or `tierD`.** Play only returns them where the law requires age verification, such as Texas. There it returns `verificationRequired` until the user is verified or supervised. Everywhere else, an adult who shares [comes back as `tierA`](https://developer.android.com/google/play/age-signals/understand-age-signals-responses), even a verified one.
- **iOS reports how the age was declared in `source`.** Apple says to choose controls that fit it, and doesn't require any particular one.
- **Custom ages in Play Console need to include 18.** With 13 and 17, for example, everyone 17 and over gets `ageLower: 17`.
- **[Restrict Minor Access](https://support.google.com/googleplay/android-developer/answer/9867159?hl=en)** in Play Console stops users that Google has identified as minors from finding or installing an adults-only app. Google [requires it](https://support.google.com/googleplay/android-developer/answer/16302250?hl=en) for apps built around real-money gambling, dating, random chat or anonymous chat.

Both stores leave legal compliance up to you.

### Generally Available App (No Age Restrictions)

If your app is for all ages and restricts nothing, iOS still needs gates to return a range. Use broad defaults and don't change the app. Since 0.11.0, Play's sharing prompt can show anywhere, as Apple's already could. To skip it where no law requires sharing, check [eligibility](#regional-eligibility) first. Don't send the result to analytics, because Play's terms forbid it (see [Legal Compliance](#legal-compliance)).

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

Every class, method, field and enum value is documented on [pub.dev](https://pub.dev/documentation/age_range_signals/latest/), from the comments in the code. This section only covers what's easier to see side by side: what each platform returns, and when each exception is thrown.

### What Android returns

Play doesn't return a single status. The plugin works it out by comparing the age band Play reports with your highest gate. The tier and the parent approval state come with it.

| status | ageRangeSource | ageLower / ageUpper | installId | Derived from |
|--------|----------------|---------------------|-----------|--------------|
| `verified` | any tier | Populated / `null` or populated† | `null` or populated | Band starts at or above your highest gate |
| `supervised` | `tierB` | Populated / Populated† | Populated | Parent-managed account below your highest gate |
| `supervised` | `tierA`/`tierC`/`tierD` | Populated / Populated† | `null` | Unsupervised user below your highest gate |
| `supervisedApprovalPending` | `tierB` | Populated†, or `null` with no band yet | Populated | A significant change awaits parent approval |
| `supervisedApprovalDenied` | `tierB` | Populated†, or `null` with no band yet | Populated | Parent denied the change; use the previously approved state |
| `unknown` | `null` or any tier | `null` / `null` | `null` | Access not shared, verification required, or no age band reported |

† `ageUpper` is `null` only for Play's top band, which has no upper limit (18+ unless you set custom ages). With a lower gate, a `verified` result can have an upper limit. For example, gates `[13]` and Play's 16-17 band give `ageLower: 16, ageUpper: 17`. So don't use `ageUpper == null` to mean "adult".

The two approval statuses are reported at any age, because a parent decision that's still open matters either way. That includes users Play has no band for yet.

Android never returns `declined`. Play reports `notShared` both when a user refuses and when they aren't eligible, and you can't tell the two apart. So the plugin reports `unknown` instead of guessing.

### What iOS returns

| status | ageLower / ageUpper | source | Notes |
|--------|---------------------|--------|-------|
| `verified` | Populated / `null` or populated | Populated* | User shared; lower bound at or above your highest gate (`ageUpper` is `null` for a top range with no upper limit, such as 18+) |
| `supervised` | Populated / Populated | Populated* | User shared; lower bound below your highest gate. For someone under your lowest gate Apple sends no lower bound, and the plugin reports `ageLower: 0`, like Android's youngest band |
| `declined` | `null` / `null` | `null` | User declined to share |
| `unknown` | `null` / `null` | Populated* | User shared, but Apple reported no bounds at all, so there's nothing to compare |

\* `source` can be `null` for a declaration type the plugin doesn't recognize, even for `verified` or `supervised`. Apple's confirmation methods (payment card, government ID and so on) map to `confirmed`, not `null`.

### Exceptions

Every exception extends `AgeSignalsException`. Each has a readable `message` and a `code` you can check in code. When the platform provides them, `details` has extra diagnostics such as the error domain, code and exception type.

| Exception | Thrown when |
|-----------|-------------|
| `ApiNotAvailableException` | The API isn't available. On Android: an outdated Play Store, an app not installed from Google Play, or a device type Play doesn't support ([details](#api_not_available-android)). On iOS: Apple couldn't share the age range. Sharing isn't available for this user or region, or the user chose not to share at the prompt. An app without the entitlement can get this too |
| `UnsupportedPlatformException` | The OS version, or the Xcode version the app was built with, doesn't support the call |
| `NotInitializedException` | iOS: `initialize()` hasn't supplied any gates |
| `MissingEntitlementException` | iOS: the entitlement is missing from the signed app ([fix](#missingentitlementexception-ios)) |
| `UserCancelledException` | iOS: the user cancelled the prompt, or (iOS 27+) declined the age range sharing setup |
| `UserNotSignedInException` | iOS 27+: no Apple Account is signed in, or the account (such as a managed one) isn't eligible for age range sharing |
| `NetworkErrorException` | A network or server issue stopped the request |
| `PlayServicesException` | Android: the Play Store or Play Services is missing, outdated or unreachable. It can also mean Play stopped supporting the library version this plugin uses, so you need a newer plugin. The eligibility calls need a newer Play Store than the rest |
| `MockDataNotAllowedException` | Android: `useMockData: true` in a non-debuggable build ([why](#android-testing)) |
| `ApiErrorException` | Any other platform API error |

## Testing

### Android Testing

> **Debug builds only.** `useMockData: true` throws `MockDataNotAllowedException` in a build that isn't debuggable. The fake manager makes up age signals, and leaving it on in a shipped app would give real users fake ages. If you need mock data in a release-like build, make a debuggable release variant.

`useMockData: true` replaces the real API with Google's `FakeAgeSignalsManager`. Without `mockData`, it returns a supervised user in Play's 13-15 band (0-12 if your highest gate is 15 or lower):

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

Pass `mockData` to test any other case from Dart, without touching Kotlin:

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

Replace the `mockData` argument with any of these:

| Scenario | `mockData` | What you get back |
|---|---|---|
| Supervised teen | `status: supervised, ageLower: 16, ageUpper: 17, installId: 'test_id'` | `supervised`, `tierB`, your install id |
| Verified adult | `status: verified` | `verified`, band from your highest gate with no upper limit |
| ID-checked adult | `status: verified, ageRangeSource: AgeRangeSource.tierD` | `verified` pinned to `tierD` |
| Awaiting parent approval | `status: supervisedApprovalPending, ageLower: 13, ageUpper: 15` | `supervisedApprovalPending`, change status `pending` |
| Parent denied the change | `status: supervisedApprovalDenied, ageLower: 13, ageUpper: 15` | `supervisedApprovalDenied`, change status `declined` |
| No signals at all | `status: unknown` | `unknown`, no band, no tier |
| Sharing declined | `status: unknown, accessStatus: AgeSignalsAccessStatus.notShared, mandatorySharing: false` | `requestAgeSignalsAccess()` returns `notShared`; `checkAgeSignals()` reports `unknown`. Users can only decline where sharing isn't mandatory |
| Not a mandatory region | `status: verified, ageRangeSource: AgeRangeSource.tierA, ageLower: 18, mandatorySharing: false` | `isEligibleForAgeFeatures()` returns `false`; the regulatory set is empty |

When the mock picks a band for you, it uses a real Play band (0-12, 13-15, 16-17), with one exception. A verified mock starts its band at your highest gate (18 until you pass gates) with `ageUpper: null`, because the result comes from the band. A real verified response uses Play's 18+ band (`ageLower: 18, ageUpper: null`), so pass `ageLower: 18` to match it exactly.

To call the real API from a debug build you installed yourself, add the device's Google account as a license tester in Play Console. Otherwise Play blocks apps not installed from Google Play with `APP_NOT_OWNED`, which the plugin reports as `ApiNotAvailableException`. The package name has to match the app in Play Console ([Google's guide](https://developer.android.com/google/play/age-signals/test-age-signals-api)). If the build still gets `APP_NOT_OWNED`, install it from the internal testing track instead.

### iOS Testing

iOS ignores `useMockData` and `mockData`, because Apple has no mock for DeclaredAgeRange. Instead, Apple has sandbox Age Assurance scenarios (iOS 26.2+) that give real responses on a device. You need:

- A real iOS 26.2+ device with Developer Mode on (the simulator doesn't work)
- The `com.apple.developer.declared-age-range` capability on your App ID (see [iOS setup](#ios)). Adding the key to the entitlements file by hand isn't enough, because signing removes it
- A Sandbox Apple Account, signed in only under Settings → Developer → Sandbox Apple Account. Don't use the normal iCloud sign-in, or the eligibility check misbehaves. Set its App Store region to one where Apple's age rules apply (see [REGULATORY.md](https://github.com/zigapovhe/age_range_signals/blob/main/REGULATORY.md))

Then on the device, open Settings → Developer → Sandbox Apple Account → Manage → Age Assurance and pick a scenario. Relaunch your app, because the value is cached, and call `checkAgeSignals()`. You can also set up test scenarios in App Store Connect.

With age gates `[13, 16, 18]`, the plugin returns this for each of Apple's scenarios:

| Sandbox scenario | `status` | ageLower | ageUpper | source |
|---|---|---|---|---|
| Under 13, significant change approved | `supervised` | 0 | 12 | `guardianDeclared` |
| 13 - 15, significant change approved | `supervised` | 13 | 15 | `guardianDeclared` |
| 16 - 17, significant change declined | `supervised` | 16 | 17 | `guardianDeclared` |
| 18+, age not confirmed, significant change not applicable | `verified` | 18 | `null` | `selfDeclared` |
| 18+, age confirmed, significant change not applicable | `verified` | 18 | `null` | `confirmed` |
| 18+, age confirmed, significant change applicable | `verified` | 18 | `null` | `confirmed` |

The `source` column is what Apple documents for each scenario. The same Manage screen also has Revoke App Consent. It only tests App Store Server Notifications and doesn't change anything this plugin returns.

> **The two "declines" are different.** A `declined` *status* means the user refused to share their age (DeclaredAgeRange `.declinedSharing`). The "16 - 17, significant change **declined**" sandbox scenario is something else. It still returns the 16-17 range, so the plugin reports `supervised`. The "declined" there is a guardian's answer in PermissionKit, a separate Apple framework this plugin doesn't cover. DeclaredAgeRange has no "denied" state, so a guardian's decline shows up as the user's real age range (`supervised`). A revoked consent never reaches the plugin either. Apple stops the app from launching and tells your server with `RESCIND_CONSENT` ([Apple's age assurance Q&A](https://developer.apple.com/support/age-assurance/)). If you need the guardian's approve or deny answer, use PermissionKit and App Store Server Notifications.

Apple's guide: [Testing age assurance in sandbox](https://developer.apple.com/documentation/storekit/testing-age-assurance-in-sandbox).

## Troubleshooting

### MissingEntitlementException (iOS)

The signed app doesn't have the `com.apple.developer.declared-age-range` entitlement. There are two common causes. The key is in `Runner.entitlements`, but your App ID doesn't have the capability, so Xcode uses a wildcard profile without it. Or the entitlements file exists, but no `CODE_SIGN_ENTITLEMENTS` build setting points to it, so it never gets signed in.

1. Add the key to `Runner.entitlements` (see [iOS setup](#ios)).
2. Make sure the Runner target's `CODE_SIGN_ENTITLEMENTS` build setting references that file. Adding the capability in Xcode's Signing & Capabilities tab does this for you.
3. Enable the Declared Age Range capability on your App ID via Xcode → Signing & Capabilities → + Capability.
4. Let Xcode regenerate the provisioning profile (toggle the team or hit "Try Again" under Signing if needed).
5. Verify with `codesign -d --entitlements :- YourApp.app | grep declared-age-range`.

### Regulatory features time out (iOS)

`ApiErrorException: "requiredRegulatoryFeatures failed: Timed out after 10.0s"` means Apple's call hung, and the plugin gave up after 10 seconds. It has happened on a real iOS 26.5 device in debug builds, even with the right entitlement and a sandbox account in a covered region. The same app in release mode answered in about 140 ms. Treat it as temporary, and test regulatory features in release or TestFlight builds.

### API_NOT_AVAILABLE (Android)

Play reports this when the Play Store is too old for the API. Ask the user to update it. The plugin also reports Play's `APP_NOT_OWNED` this way, which means the app wasn't installed from Google Play. Debug builds you install yourself get it unless the device's Google account is a license tester (see [Android Testing](#android-testing)). Play's `DEVICE_NOT_SUPPORTED` ends up here too. The API covers phones, foldables and tablets, and other device types get this error.

### PRESENTATION_CONTEXT_UNAVAILABLE (Android)

`requestAgeSignalsAccess()` was called when there was no foreground activity to show Play's prompt on, for example from a background isolate or before the first frame. It arrives as `ApiErrorException`. The plugin finds the activity by itself, so just call it while your app is in the foreground.

### Play's prompt never appears (Android)

Play only shows the prompt to unsupervised users whose Play setting is "Ask before sharing". It doesn't show it when:

- The user's setting is "Always Share" or "Never Share"
- The user is supervised. Parents manage sharing in Family Link
- Sharing is mandatory where the user is. Play shares without asking
- The user is in a US state that requires verified ages and isn't verified. They get `verificationRequired` instead

If the user dismisses or declines it, Play shows it a few more times, then stops for a while and answers `notShared` in the meantime. Users can also turn sharing on or off for your app in the Play Store under Settings → Age sharing and family → [Age range sharing](https://support.google.com/googleplay/answer/17232873).

## Legal Compliance

Google's [terms](https://developer.android.com/google/play/age-signals/overview#terms-service) only allow data from the Play Age Signals API to be used for age-appropriate content and experiences that comply with the law, and only by the app that requested it. The [Play policy](https://support.google.com/googleplay/android-developer/answer/16585319#age_signals) lists what's not allowed:

- Advertising, marketing or personalization, including targeted ads
- Data analytics, user profiling or business intelligence
- Selling, sharing or passing the data to any third party, unless the law strictly requires it

If you use it for any of these, Google can cut off your API access and suspend or remove your apps from Google Play.

The plugin doesn't collect or store any user data. Age data comes straight from the platform APIs. Make sure your app's privacy policy says how you use it.

## Example App

[`example/lib/main.dart`](https://github.com/zigapovhe/age_range_signals/blob/main/example/lib/main.dart) runs on both platforms. It walks through the access request and the check, and handles every status. On Android it has a mock data switch with a list of scenarios. It also has buttons for the eligibility check, regulatory features and the significant update sheet.

## Contributing

Issues and pull requests are welcome on [GitHub](https://github.com/zigapovhe/age_range_signals/issues).

## License

MIT, see [LICENSE](https://github.com/zigapovhe/age_range_signals/blob/main/LICENSE).

## References

- [Google Play Age Signals API](https://developer.android.com/google/play/age-signals/overview)
- [Apple DeclaredAgeRange](https://developer.apple.com/documentation/declaredagerange/)
