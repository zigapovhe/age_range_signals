# Migration guide

What to change in your code when you upgrade. Find the version you're on, then go through every version above it, starting with the oldest. Versions not listed here need no code changes. The [CHANGELOG](CHANGELOG.md) has every change.

Steps marked **Test stubs** only matter if your tests replace the plugin with a class that implements `AgeRangeSignalsPlatform`, like this one. Add the listed methods to that class.

```dart
class FakeAgeRangeSignals
    with MockPlatformInterfaceMixin
    implements AgeRangeSignalsPlatform {
  @override
  Future<bool> isEligibleForAgeFeatures() async => true;

  // ...the other methods
}
```

## 0.11.0

1. Update to Flutter 3.47 or newer (Dart 3.13).
2. Set Android `minSdk` to 24 or higher in `android/app/build.gradle.kts` (or `build.gradle`). A lower value fails the build.

   ```kotlin
   defaultConfig {
       minSdk = 24
   }
   ```

3. Catch `AgeSignalsException` around `isEligibleForAgeFeatures()` and `getRequiredRegulatoryFeatures()`. On Android they used to always throw `UnsupportedPlatformException` and always return an empty set. Now they return Play's answer and can throw any `AgeSignalsException`.

   ```dart
   // Before
   } on UnsupportedPlatformException {

   // After
   } on AgeSignalsException {
   ```

   With mock data, both now follow `AgeSignalsMockData.mandatorySharing`, which is `true` when you don't set it. Set `mandatorySharing: false` to mock a user no sharing law applies to.

4. Decide where Play's sharing prompt may show. It can now show in any region as Google rolls it out. If you only want it where a law requires sharing, call `isEligibleForAgeFeatures()` first (see [Regional Eligibility](README.md#regional-eligibility)). If showing it everywhere is fine, there's nothing to do.
5. If you copied the `verificationRequired` sample from the README of 0.9.0 to 0.10.1, fix it. It checked again every time the app resumed, and a store's prompt pauses and resumes your app, so it kept asking. Only check again while verification is pending:

   ```dart
   bool _verificationPending = false;

   // In didChangeAppLifecycleState
   if (state == AppLifecycleState.resumed && _verificationPending) _check();

   // In _check, right after requestAgeSignalsAccess()
   _verificationPending = access == AgeSignalsAccessStatus.verificationRequired;
   ```

   The full sample is in [Handling verificationRequired](README.md#handling-verificationrequired-android).

## 0.10.1

1. On iOS, users under your lowest age gate now come back `supervised` with `ageLower: 0`. Versions 0.8.0 to 0.10.0 returned `unknown` for them, and earlier versions returned `supervised` with `ageLower: null`. If you looked for these users through `unknown` or `ageLower == null`, check the range instead:

   ```dart
   final belowLowestGate = result.ageLower == 0;
   ```

2. On iOS 27, in apps built with Xcode 27, three new Apple errors now arrive as typed exceptions: `UserCancelledException` (the person declined the age range setup), `UserNotSignedInException` (no eligible Apple Account) and `NetworkErrorException`. If you handle those exceptions, these cases now reach your handlers too.

## 0.10.0

1. **Test stubs:** add `isEligibleForAgeFeatures()`.

## 0.9.0

1. Add `case AgeDeclarationSource.confirmed:` to any exhaustive `switch` on `source`.
2. Replace `source == null` checks for confirmed ages. Before 0.9.0, ages Apple confirmed with a payment card or ID came back with `source: null`. Now they come back `confirmed`.

   ```dart
   // Before
   final confirmed = result.source == null;

   // After
   final confirmed = result.source == AgeDeclarationSource.confirmed;
   ```

## 0.8.0

1. Call `requestAgeSignalsAccess()` before `checkAgeSignals()`, and put both in the same `try`. On Android, skipping the access call makes `checkAgeSignals()` report `unknown`. On iOS, `requestAgeSignalsAccess()` now throws the errors `checkAgeSignals()` used to throw first (`UnsupportedPlatformException` below iOS 26.0, `NotInitializedException` without gates).

   ```dart
   // Before
   try {
     final result = await AgeRangeSignals.instance.checkAgeSignals();
   } on AgeSignalsException catch (e) {
     // ...
   }

   // After
   try {
     final access = await AgeRangeSignals.instance.requestAgeSignalsAccess();
     if (access == AgeSignalsAccessStatus.shared) {
       final result = await AgeRangeSignals.instance.checkAgeSignals();
     }
   } on AgeSignalsException catch (e) {
     // ...
   }
   ```

2. Pass `ageGates` on Android too. Android used to ignore them. Now your highest gate decides `verified` there, and it's 18 until you pass gates.

   ```dart
   // Before
   await AgeRangeSignals.instance.initialize(
     ageGates: Platform.isIOS ? [13, 16, 18] : null,
   );

   // After
   await AgeRangeSignals.instance.initialize(ageGates: [13, 16, 18]);
   ```

3. Check how you read `status` on Android. It used to be Play's own verdict. Now it's the age range compared with your highest gate, the rule iOS already used. So a parent-managed user is `verified` when their range is at or above your highest gate. If you used `supervised` to find parent-managed accounts, check the tier instead:

   ```dart
   // Before
   final parentManaged = result.status == AgeSignalsStatus.supervised;

   // After
   final parentManaged = result.ageRangeSource == AgeRangeSource.tierB;
   ```

4. Replace `declared` checks. Self-declared users now come back `verified` or `supervised`, judged by their range like everyone else. `declared` is deprecated and never returned.

   ```dart
   // Before
   if (result.status == AgeSignalsStatus.declared) {

   // After
   if (result.ageRangeSource == AgeRangeSource.tierA) {
   ```

   An exhaustive `switch` on `status` still needs the `declared` case. Mark it with `// ignore: deprecated_member_use`.

5. On Android, verified adults now come with an age range: `ageLower: 18` and `ageUpper: null`. Before, both were `null`. If you used `ageLower == null` to spot verified adults, check `status == AgeSignalsStatus.verified` instead.
6. Rename `mostRecentApprovalDate` to `significantChangeApprovalDate`, on both `AgeSignalsResult` and `AgeSignalsMockData`. The old name still works but is deprecated. This only affects 0.7.x, where the field was added.

   ```dart
   // Before
   result.mostRecentApprovalDate

   // After
   result.significantChangeApprovalDate
   ```

7. Only turn on mock data in debuggable builds. `useMockData: true` now throws `MockDataNotAllowedException` in a build that isn't debuggable.

   ```dart
   await AgeRangeSignals.instance.initialize(
     ageGates: [13, 16, 18],
     useMockData: kDebugMode,
   );
   ```

8. Check your mock data. Mock results now get their `status` from the mocked age range, like real results, so make the range match the `status` you want. `AgeSignalsMockData.source` never did anything on Android and is now deprecated. Use `ageRangeSource` to pick the Play tier.

   ```dart
   // Before
   const AgeSignalsMockData(
     status: AgeSignalsStatus.declared,
     source: AgeDeclarationSource.selfDeclared,
   )

   // After: a self-declared adult
   const AgeSignalsMockData(
     status: AgeSignalsStatus.verified,
     ageRangeSource: AgeRangeSource.tierA,
     ageLower: 18,
   )
   ```

9. **Test stubs:** add `requestAgeSignalsAccess()`.

## 0.7.0

1. On iOS, "age range sharing is not available for this user or region" now throws `ApiNotAvailableException`. Before, it came as `MissingEntitlementException`, even when the entitlement was set up correctly. If you caught `MissingEntitlementException` for that case, catch `ApiNotAvailableException` instead. `MissingEntitlementException` now means the entitlement really is missing.
2. A missing view controller, window scene or activity (`PRESENTATION_CONTEXT_UNAVAILABLE`) now throws `ApiErrorException` instead of the base `AgeSignalsException`. This only matters if you handle the two differently.
3. **Test stubs:** add `getRequiredRegulatoryFeatures()` and `showSignificantUpdateAcknowledgment()`.

## 0.6.0

1. Update to Flutter 3.44 or newer (Dart 3.12), and set Android `minSdk` to 23 or higher. 0.11.0 raises both again.
2. On iOS, `checkAgeSignals()` no longer returns `unknown` for users outside a covered region. It asks Apple directly instead. If you used `unknown` to skip those users, call `isEligibleForAgeFeatures()` first, which is available from 0.10.0 (see [Regional Eligibility](README.md#regional-eligibility)).

## 0.5.1

1. Add `case AgeSignalsStatus.declared:` to any exhaustive `switch` on `status`. From 0.8.0 it's deprecated, so mark it with `// ignore: deprecated_member_use`.

## 0.5.0

1. **Test stubs:** `initialize()` has a new `mockData` parameter.

   ```dart
   @override
   Future<void> initialize({
     List<int>? ageGates,
     bool useMockData = false,
     AgeSignalsMockData? mockData,
   }) async {}
   ```

## 0.4.2

1. On Android, `ageLower` and `ageUpper` now carry Play's values. Before, they were always `null`. If your code assumed they were `null` on Android, read them now.

## 0.4.0

1. Add `case AgeSignalsStatus.supervisedApprovalPending:` and `case AgeSignalsStatus.supervisedApprovalDenied:` to any exhaustive `switch` on `status`.
2. On iOS 26.2+, users outside a covered region come back `unknown`. 0.6.0 removed this again, so if you're upgrading past 0.6.0 there's nothing to do.

## 0.3.0 and earlier

No code changes. 0.2.0 and 0.3.0 only moved to newer versions of Google's Play library.
