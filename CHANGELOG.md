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
