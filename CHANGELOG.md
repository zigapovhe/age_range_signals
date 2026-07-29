## 0.8.0

* **Android**: Migrated to `com.google.android.play:age-signals` 0.0.4, which removes `userStatus` in favour of `ageRangeSource` and `significantChangeStatus`.
* **Android**: Added `requestAgeSignalsAccess()`, the first of 0.0.4's two calls. It may show Play's in-app sharing prompt (the plugin is now `ActivityAware`) and returns `shared`, `notShared` or `verificationRequired`. Call it before `checkAgeSignals()`.
* **iOS**: `requestAgeSignalsAccess()` returns `shared`, since Apple gathers consent inside `checkAgeSignals()`, but it raises the version and initialization errors `checkAgeSignals()` used to raise. Widen your `try` to cover both calls.
* **Android**: `AgeSignalsResult` now exposes `ageRangeSource` (tierA-tierD) and `significantChangeStatus`.
* **Breaking**: `status` now comes from the reported age band measured against your highest age gate, not from the assurance tier. Pass `ageGates` on Android too; it uses 18 until you do.
* **Breaking**: `AgeSignalsStatus.declared` is deprecated and no longer returned; read `ageRangeSource == AgeRangeSource.tierA` instead.
* **Breaking**: Renamed `mostRecentApprovalDate` to `significantChangeApprovalDate`, matching the upstream rename. The old name still works as a deprecated alias, and `fromMap` accepts the old key.
* **Breaking**: `useMockData: true` now throws `MockDataNotAllowedException` outside debuggable builds, so a release can't reach the fake manager.
* **Android**: `AgeSignalsMockData` gained `accessStatus` plus explicit `ageRangeSource` / `significantChangeStatus` overrides.
* **Docs**: Refreshed regulatory status (Texas in effect; Utah and Louisiana delayed to 2027, though Apple already shares age categories there; Singapore added). Added badges, `context7.json` and `llms.txt`.
* **Example**: Added the access step and a mock-data toggle for hitting the real API on device.

## 0.7.0

* **iOS**: Added `getRequiredRegulatoryFeatures()` (iOS 26.4+), which reports whether Apple requires the current user to share an age range and whether significant-change notification or parental consent applies (#31). Calls are guarded by a 10-second deadline. Throws `UnsupportedPlatformException` below iOS 26.4 (and in apps built with an SDK older than iOS 26.4) so an empty set always means Apple affirmatively reports nothing is required; on Android the set is always empty.
* **iOS**: Added `showSignificantUpdateAcknowledgment(updateDescription:)`, the system sheet for significant app changes (iOS 26.4+). Throws `UnsupportedPlatformException` where unavailable instead of silently succeeding.
* **iOS**: `AgeSignalsResult` now includes `activeParentalControls`.
* **Android**: `AgeSignalsResult` now includes `mostRecentApprovalDate`; mockable via `AgeSignalsMockData`.
* **iOS**: `checkAgeSignals()` now reports `ApiNotAvailableException` when Apple says age range sharing is unavailable for the user or region. Earlier versions misreported that state as `MissingEntitlementException` even on correctly entitled apps.
* **iOS**: `PRESENTATION_CONTEXT_UNAVAILABLE` errors now surface as `ApiErrorException` instead of the base `AgeSignalsException`.
* **Docs**: Documented Apple's rule that age gates must be at least 2 years apart.
* **Example**: The iOS example now wires `Runner.entitlements` into signing via `CODE_SIGN_ENTITLEMENTS` (it was previously never applied) and adds buttons for the regulatory features API.

## 0.6.2

* **Android**: Fixed the Gradle build on hosts not using AGP 9 built-in Kotlin. The Kotlin plugin is now applied only when the host needs it (AGP <9, or `android.builtInKotlin=false`), so the plugin works with AGP 9 built-in Kotlin as well as AGP 8.x + KGP 2.0+. No changes required in consuming apps.
* **Android**: Removed the unused standalone Gradle wrapper from `android/`.
* **Docs**: Added an integration levels table (#30), consolidated regulatory status into one section, fixed broken table-of-contents links, and clarified why iOS never returns `supervisedApprovalDenied` (#24).

## 0.6.1

* **iOS**: Fixed SwiftPM build failure from 0.6.0 caused by a wrong argument order in `Package.swift`. CocoaPods was not affected.
* **Example**: Migrated the iOS example to Swift Package Manager (dropped CocoaPods).

## 0.6.0

* **iOS**: Fixed `checkAgeSignals()` hanging indefinitely on iOS 26.2+. The plugin no longer gates on Apple's `isEligibleForAgeFeatures` (which can hang, and returns `false` before any prompt is accepted); it calls `requestAgeRange()` directly, per Apple's guidance.
  * **Breaking**: iOS no longer returns `AgeSignalsStatus.unknown` from the eligibility pre-check. Region eligibility is now reflected by `requestAgeRange()` itself.
* **Android**: Raised `minSdk` from 21 to 23 (the `com.google.android.play:age-signals` AAR declares `minSdkVersion 23`; lower values fail the Gradle manifest merge).
* **Android**: Fixed `useMockData: true` returning `API_NOT_AVAILABLE` when Play Services is unavailable; the mock path now runs independently of the real manager.
* **Android**: Mock data can now reproduce the open-ended top bucket (`ageLower=18, ageUpper=null`).
* **Build**: Migrated to AGP 9 built-in Kotlin support and raised the minimums to Flutter 3.44 / Dart 3.12. Declared the `FlutterFramework` dependency in `Package.swift` (required by Flutter 3.41+ SPM; removes the build warning).
* **Docs**: Updated regulatory status (Texas SB 2420 in effect under a temporary stay; Brazil, Australia, and Singapore applicable; Utah and Louisiana delayed to 2027), corrected the Android minimum API to 23, clarified `AgeSignalsResult` nullability, and documented the iOS 1-3 age-gate limit.
* **Example**: Updated to AGP 9.0.1 and migrated to the UIScene lifecycle.

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
