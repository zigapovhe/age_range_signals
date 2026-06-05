## 0.6.0

* **iOS**: Fixed `checkAgeSignals()` hanging indefinitely on iOS 26.2+
  * The plugin awaited `AgeRangeService.isEligibleForAgeFeatures` up front (added in 0.4.0 for regional gating). That property is unreliable in the current iOS 26.2.x window: it can never return (hanging the whole call) and reports `false` before any prompt is accepted, only updating on a later relaunch (reported on the Apple Developer Forums)
  * Per Apple's guidance, the plugin no longer gates on `isEligibleForAgeFeatures`; it calls `requestAgeRange()` directly, which is the source of truth
  * **Behavior change**: iOS no longer returns `AgeSignalsStatus.unknown` from the eligibility pre-check. Region eligibility is now reflected by `requestAgeRange()` itself. Verified on-device against all of Apple's sandbox Age Assurance scenarios
* **Android**: Raised `minSdk` from 21 to 23 to match the `com.google.android.play:age-signals` dependency (which declares `minSdkVersion 23`)
  * Previously, consuming apps building at `minSdk 21` would hit a Gradle manifest-merge failure
* **Android**: Fixed `useMockData: true` not working when Google Play Services / the real Age Signals API is unavailable
  * The real-manager null check ran before the mock branch, so on emulators/devices without Play Services, mock mode incorrectly returned `API_NOT_AVAILABLE` instead of the mock result
  * The mock path now runs independently of the real manager
* **Android**: Mock data can now reproduce the open-ended top-bucket edge case (`ageLower=18, ageUpper=null`)
  * An explicitly-provided null `ageUpper` is now honored instead of defaulting to 15 (the default still applies when no custom mock data is supplied)
* **Documentation**: Updated legal/regulatory status
  * **Texas SB 2420**: Reframed from "enforcement paused" to in effect as of June 4, 2026 under a temporary Fifth Circuit stay (not a final ruling)
  * **Australia** and **Singapore**: Added as applicable regions for Apple's DeclaredAgeRange API
  * **Utah** and **Louisiana**: Noted statutory compliance deadlines delayed to 2027 (HB 498 / HB 977)
  * **Brazil**: Updated to reflect the Digital ECA being enforceable since March 17, 2026
* **Documentation**: Corrected the Android minimum API in the README from 21 to 23
* **Documentation**: Clarified iOS `AgeSignalsResult` nullability: `source` may be null for unrecognized declaration types, and `ageUpper` may be null for open-ended (18+) ranges
* **Documentation**: Documented the iOS 1–3 age-gate limit on `initialize(ageGates:)`
* **Android**: Migrated to AGP built-in Kotlin support (AGP 9+); removed the explicit `kotlin-android` plugin and moved `jvmTarget` to the `kotlin { compilerOptions {} }` DSL ([Flutter migration guide](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors))
* **Build**: Raised the minimum supported versions to Flutter 3.44 / Dart 3.12, required by the built-in Kotlin migration
* **Example**: Updated the example app to Android Gradle Plugin 9.0.1 and removed its `kotlin-android` plugin

## 0.5.1

* **Android**: Updated `com.google.android.play:age-signals` to version 0.0.3 (#25, thanks to @nathanael540)
  * **Brazilian Digital ECA Law (Lei 15.211) Support**: Version 0.0.3 is required for apps targeting Brazil
  * New user status: `DECLARED` for users who have declared their age through Google Play
  * Refactored error handling to use structured `AgeSignalsException.errorCode` instead of string matching
  * Added `SDK_VERSION_OUTDATED` error handling

## 0.5.0

* **Android**: Added `mockData` parameter for customizable testing
  * New `AgeSignalsMockData` class allows testing different scenarios
  * Uses Google's official `FakeAgeSignalsManager` from `com.google.android.play.agesignals.testing` package
  * Can customize status, age ranges, and installId for testing
  * Defaults to supervised user (13-15) for backward compatibility with existing tests

* **Documentation**: Major updates and improvements
  * Added Texas SB 2420 federal court injunction notice (December 23, 2025)
  * Comprehensive testing documentation for both platforms
  * Clarified that `mockData` is Android-only (iOS has no official testing utilities from Apple)
  * Updated README with accurate testing requirements and platform-specific limitations
  * Improved example app comments to explain platform differences

* **iOS**: No changes
  * Continues to ignore `useMockData` and `mockData` parameters (same as 0.4.2)
  * Apple does not provide testing utilities for DeclaredAgeRange API
  * iOS testing requires real iOS 26.2+ devices with actual Apple IDs

## 0.4.2

* **Android**: Fixed `ageLower` and `ageUpper` to read actual values from Google Play Age Signals API
  * Previously these fields were hardcoded to `null`, now they correctly return age range values for supervised users
  * Age ranges are returned as integer bounds (e.g., `ageLower=13`, `ageUpper=15` for a 13-15 age band)
  * Values are `null` for verified users (18+) as expected
* **iOS**: Simplified plugin implementation
* **Example App**: Added iOS warning explaining that example app cannot run DeclaredAgeRange API without proper entitlement
* **Documentation**: Updated README to accurately document mock data behavior (returns supervised_13_15 by default, not verified)

## 0.4.1

* Fixed code formatting issues to improve pub.dev score

## 0.4.0

* **Android**: Added distinct status values for guardian approval states (#10, thanks to @kumamotone)
  * `AgeSignalsStatus.supervisedApprovalPending` - awaiting guardian response
  * `AgeSignalsStatus.supervisedApprovalDenied` - guardian denied access

* **iOS**: Added regional eligibility check for iOS 26.2+ (#9, thanks to @rokarnus)
  * Returns `AgeSignalsStatus.unknown` for users outside applicable regions
  * Avoids unnecessary API calls when age verification is not available

* **Error Handling**: Added 6 new exception types with detailed diagnostics
  * `MissingEntitlementException`, `ApiErrorException`, `NetworkErrorException`
  * `UserCancelledException`, `PlayServicesException`, `UserNotSignedInException`
  * All exceptions now include a `details` field with platform-specific diagnostic information
  * Enhanced error detection for Play Services, network issues, authentication, and user cancellation

## 0.3.0

* **IMPORTANT**: Critical update to ensure compatibility with Google Play Age Signals API requirements (effective January 1, 2026)

* **Android**: ⚠️ Google has **updated their requirements again** - the Play Age Signals API now requires version `0.0.2` or higher (previously `0.0.1` in v0.2.0). Beta versions and `0.0.1` will throw exceptions starting January 1, 2026. (thanks to @JenniO for reporting this in #7)
  * Updated to `com.google.android.play:age-signals:0.0.2` (latest required version)
  * Updated build tools to match Flutter's official plugins for improved compatibility and future-proofing

* **Migration**: No code changes required - just update your dependency version in `pubspec.yaml`

## 0.2.0

* **Android**: ⚠️ **CRITICAL UPDATE** - Bumped Play Age Signals API library version to non-beta stable release `com.google.android.play:age-signals:0.0.1` (thanks to @rokarnus for reporting this in #5)
  
* **ACTION REQUIRED**: Users must upgrade to version 0.2.0 or higher before January 1, 2026
  * **Why**: From January 1, 2026, all beta versions (0.0.1-beta*) of the Play Age Signals API will throw exceptions
  * **Impact**: Apps using older versions of this plugin (with beta API) will stop working after January 1, 2026
  * To receive live responses from January 1, 2026, you must upgrade to this library version (0.2.0 or higher)

## 0.1.3

* **iOS**: Fixed compilation error: renamed `range.source` to `range.ageRangeDeclaration` to match Apple's DeclaredAgeRange API (#3)

## 0.1.2

* **iOS**: Added Swift Package Manager (SPM) support
* **Example**: Migrated example project from CocoaPods to Swift Package Manager

## 0.1.1

* **Android**: Add `useMockData` parameter for testing
* **iOS**: Fix critical `requestAgeRange` method call syntax
* **iOS**: Add support for 1-3 age gates (previously 2-3)
* **iOS**: Support for Swift Package Manager
* Add pub.dev topics and formatted code for better score
* Documentation improvements and usage examples

## 0.1.0

* Initial release
* Support for Google Play Age Signals API on Android (API 21+)
* Support for Apple's DeclaredAgeRange API on iOS (26.0+)
* Configurable age gates for iOS
* Comprehensive example app with mock data support
