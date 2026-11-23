/// A regulatory action the store reports as required for the current user
/// (iOS 26.4+, and Android with Play age-signals 0.0.6).
///
/// Returned by `AgeRangeSignals.instance.getRequiredRegulatoryFeatures()`.
/// The set is derived from the user's region and account settings, so it
/// tells you what the store requires for this specific person.
///
/// Android only ever reports [declaredAgeRangeRequired], from Play's
/// mandatory-sharing check. The significant-change values are iOS only.
enum AgeRegulatoryFeature {
  /// The user is required to share their age range with your app.
  ///
  /// When present, request access and call `checkAgeSignals()` so the store
  /// can share the user's range. When absent, the store reports no
  /// obligation to prompt this user.
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
