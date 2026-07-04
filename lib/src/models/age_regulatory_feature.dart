/// A regulatory action Apple reports as required for the current user
/// (iOS 26.4+ only).
///
/// Returned by `AgeRangeSignals.instance.getRequiredRegulatoryFeatures()`.
/// The set is derived from the user's region and account settings, so it
/// tells you what the App Store requires for this specific person.
///
/// Android has no equivalent concept; the Play Age Signals API implicitly
/// returns data only in regions where it is legally required.
enum AgeRegulatoryFeature {
  /// The user is required to share their age range with your app.
  ///
  /// When present, call `checkAgeSignals()` so the user can declare their
  /// range. When absent, Apple imposes no obligation to prompt this user.
  declaredAgeRangeRequired,

  /// Adult users must acknowledge a significant change to your app.
  ///
  /// Present the system sheet via
  /// `showSignificantUpdateAcknowledgment(updateDescription:)`.
  significantAppChangeRequiresAdultNotification,

  /// A parent or guardian must consent before a child keeps using your app
  /// after a significant change.
  ///
  /// The consent flow itself runs through Apple's PermissionKit and App
  /// Store Server Notifications, which this plugin does not wrap; this
  /// value tells you the flow is required.
  significantAppChangeRequiresParentalConsent;

  /// Parses a feature name coming over the platform channel.
  ///
  /// Returns null for names this version does not know, so future Apple
  /// additions degrade gracefully instead of crashing the parse.
  static AgeRegulatoryFeature? fromName(String name) =>
      AgeRegulatoryFeature.values.asNameMap()[name];
}
