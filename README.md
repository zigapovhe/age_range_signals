# age_range_signals

A Flutter plugin for age verification that supports Google Play Age Signals API (Android) and Apple's DeclaredAgeRange API (iOS 26+).

## Table of Contents

- [Features](#features)
- [Platform Support](#platform-support)
- [Platform Setup](#platform-setup)
  - [Android](#android)
  - [iOS](#ios)
- [Usage](#usage)
  - [Basic Example](#basic-example)
  - [Complete Example](#complete-example)
  - [18+ Only App](#18-only-app)
  - [Generally Available App (No Age Restrictions)](#generally-available-app-no-age-restrictions)
- [API Reference](#api-reference)
  - [AgeRangeSignals](#agerangesignals)
  - [AgeSignalsResult](#agesignalsresult)
  - [AgeSignalsStatus](#agesignalsstatus)
  - [AgeDeclarationSource](#agedeclarationsource)
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
  - [Android](#android-2)
  - [iOS](#ios-2)
- [Example App](#example-app)
- [Contributing](#contributing)
- [License](#license)
- [References](#references)
- [Support](#support)

## Features

- ✅ Cross-platform support for Android and iOS
- ✅ Google Play Age Signals API integration for Android (API 21+)
- ✅ Apple DeclaredAgeRange API integration for iOS (26.0+)
- ✅ Swift Package Manager (SPM) support for iOS
- ✅ Configurable age gates for iOS
- ✅ Type-safe Dart API with comprehensive error handling
- ✅ Full null safety support

## Platform Support

| Platform | Minimum App Version | API Available From | API |
|----------|----------------|-----|-----|
| Android  | API 21 (Android 5.0) | API 21+ | Google Play Age Signals API |
| iOS      | iOS 13.0+ (flexible) | iOS 26.0+ | DeclaredAgeRange API |

**Note:** The iOS DeclaredAgeRange API is only available on iOS 26.0+. On older iOS versions, the plugin will return an `UnsupportedPlatformException`. Your app can support older iOS versions and handle this gracefully.

## Platform Setup

### Android

1. Add the Play Age Signals dependency to your app's `build.gradle` (this is handled automatically by the plugin).

2. The Play Age Signals API requires Google Play Services to be installed and up to date.

**Important:** The Play Age Signals API is currently in beta and will return mock data until January 1, 2026. After this date, it will return real age verification data in supported US states.

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

2. Request the entitlement from Apple Developer Portal for your app identifier.

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
    } else if (result.status == AgeSignalsStatus.supervised) {
      // User may be under supervision, show restricted content
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

- `Future<void> initialize({List<int>? ageGates})` - Initializes the plugin. On iOS, `ageGates` specifies age thresholds (e.g., `[13, 16, 18]`). Required for iOS, optional for Android.

- `Future<AgeSignalsResult> checkAgeSignals()` - Checks the age signals for the current user.

### AgeSignalsResult

Result object containing age verification information.

#### Properties

- `AgeSignalsStatus status` - The verification status
- `int? ageLower` - Lower bound of age range (both platforms; iOS: when user consents, Android: for supervised users)
- `int? ageUpper` - Upper bound of age range (both platforms; iOS: when user consents, Android: for supervised users)
- `AgeDeclarationSource? source` - Source of age declaration (iOS only)
- `String? installId` - Installation identifier (Android only)

#### When are ageLower and ageUpper populated?

**Android (Google Play Age Signals API):**

| userStatus | ageLower/ageUpper | installId | Notes |
|------------|-------------------|-----------|-------|
| `verified` | `null` / `null` | `null` | User is 18+, no supervision needed |
| `supervised` | Populated / Populated† | Populated | Supervised account with approved age range |
| `supervisedApprovalPending` | Populated / Populated† | Populated | Awaiting parent approval for changes |
| `supervisedApprovalDenied` | Populated / Populated† | Populated | Parent denied changes; use previous approved age |
| `unknown` | `null` / `null` | `null` | User unverified/unsupervised in applicable region |
| `null` | `null` / `null` | `null` | User outside applicable jurisdictions |

**†Edge case:** For supervised users, `ageUpper` may be `null` if the parent-attested age is over 18 (e.g., `ageLower=18, ageUpper=null`).

**Note:** On Android, age ranges are determined by Google Play's parental control settings and returned as predefined age bands (0-12, 13-15, 16-17, 18+). The `ageGates` parameter is **not used** on Android - it's iOS-only. You cannot customize these age bands through the plugin; they're controlled by Google Play and can optionally be customized in Play Console.

**iOS (DeclaredAgeRange API):**

| userStatus | ageLower/ageUpper | source | Notes |
|------------|-------------------|--------|-------|
| `verified` | Populated | Populated | User consented; lower bound ≥ highest configured gate |
| `supervised` | Populated | Populated | User consented; lower bound < highest configured gate |
| `declined` | `null` | `null` | User declined to share age information |
| `unknown` | `null` | `null` | User outside applicable region (iOS 26.2+) |

### AgeSignalsStatus

Enum representing the verification status:

- `verified` - User is verified as above age threshold (both platforms)
- `supervised` - User is under parental supervision (Android) or declared age is below configured age gates (iOS)
- `supervisedApprovalPending` - User is supervised and awaiting guardian approval (Android only)
- `supervisedApprovalDenied` - User is supervised and guardian denied approval (Android only)
- `declined` - User declined to share age (iOS only)
- `unknown` - Age information not available or user is outside applicable region (both platforms)

### AgeDeclarationSource

Enum representing the source of age declaration (iOS only):

- `selfDeclared` - Age was self-declared by the user
- `guardianDeclared` - Age was declared by a guardian

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

You have full control over when to use mock data via the `useMockData` parameter (Android only; ignored on iOS):

```dart
// For testing with mock data (recommended before January 1, 2026)
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
- `useMockData: true` - Always uses `FakeAgeSignalsManager` for testing
- `useMockData: false` (default) - Always uses real Play Age Signals API
- You control this behavior explicitly in your code

**To test different scenarios**, modify the fake result in `AgeRangeSignalsPlugin.kt`:

```kotlin
// Default: supervised user aged 13-15 (demonstrates age range feature)
val fakeResult = AgeSignalsResult.builder()
    .setUserStatus(AgeSignalsVerificationStatus.SUPERVISED)
    .setAgeLower(13)
    .setAgeUpper(15)
    .setInstallId("test_install_id_12345")
    .build()

// For testing verified users (18+)
val fakeResult = AgeSignalsResult.builder()
    .setUserStatus(AgeSignalsVerificationStatus.VERIFIED)
    .setAgeLower(null)
    .setAgeUpper(null)
    .setInstallId(null)
    .build()
```

**Note**: The Google Play Age Signals API returns `ageLower` and `ageUpper` as integer values for supervised users. These represent the bounds of predefined age bands (default bands: 0-12, 13-15, 16-17, and 18+). For example, a supervised user aged 13-15 would have `ageLower=13` and `ageUpper=15`. For verified users (18+), these values are typically `null` since they don't need supervision. Age bands can be customized in Play Console based on your app's requirements.

### iOS Testing

**Regional Eligibility (iOS 26.2+)**

Starting with iOS 26.2, the plugin automatically checks if the user is eligible for age features using `isEligibleForAgeFeatures`. This determines if the user is in an applicable region (e.g., regulated US states):

```dart
final result = await AgeRangeSignals.instance.checkAgeSignals();

if (result.status == AgeSignalsStatus.unknown) {
  // User is outside applicable region
  // App should decide how to handle:
  // - Allow access by default (permissive)
  // - Use alternative verification
  // - Deny access (restrictive)
}
```

**Behavior:**
- **iOS 26.2+**: Checks `isEligibleForAgeFeatures` first, returns `unknown` if user is outside applicable region
- **iOS 26.0-26.1**: Uses try-catch fallback (check happens in API call)
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
- Real API returns "Not yet implemented" until January 1, 2026
- **Before Jan 1, 2026**: Use `useMockData: true` to test with `FakeAgeSignalsManager`
- **After Jan 1, 2026**: Use `useMockData: false` (default) to get real user data
- After launch, only returns real data for users in applicable US states
- Requires Google Play Services to be installed and up to date

### iOS
- DeclaredAgeRange API only available on iOS 26.0+
- Requires the `com.apple.developer.declared-age-range` entitlement
- Throws `UnsupportedPlatformException` on iOS versions below 26.0
- Returns `AgeSignalsStatus.unknown` for users outside applicable regions (iOS 26.2+)
- User can decline to share age information
- Cannot detect falsified birthdates in Apple ID

## Troubleshooting

### Common Errors

**MissingEntitlementException (iOS)**
- The `com.apple.developer.declared-age-range` entitlement is not configured or not approved by Apple
- **Solution**:
  1. Add `Runner.entitlements` file with the required entitlement (see iOS Setup)
  2. Request the entitlement from Apple Developer Portal for your App ID
  3. Wait for Apple's approval
  4. Regenerate provisioning profiles

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
- After January 1, 2026, check if device is in a supported US state

**iOS**

**UNSUPPORTED_PLATFORM**
- This error is expected on iOS versions below 26.0
- The DeclaredAgeRange API is only available on iOS 26.0+
- Handle this gracefully in your app (e.g., use alternative age verification or skip the check)

**NOT_INITIALIZED**
- Call `initialize()` with age gates before calling `checkAgeSignals()`

**AgeSignalsStatus.unknown**
- On iOS 26.2+, indicates user is outside applicable region (e.g., not in regulated US states)
- App should decide how to handle based on requirements

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
