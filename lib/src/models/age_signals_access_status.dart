/// Outcome of requesting access to the user's age signals.
///
/// Returned by `AgeRangeSignals.instance.requestAgeSignalsAccess()`. Since
/// age-signals 0.0.4 Google Play splits age signals across two calls: the
/// access request (which may show Play's in-app age sharing prompt) and
/// `checkAgeSignals()`, which only carries signals once access is [shared].
enum AgeSignalsAccessStatus {
  /// Age signals are shared; proceed to `checkAgeSignals()`.
  ///
  /// Play reports this when the user or their parent agreed to share, or in
  /// regions where sharing is automatic. Always returned on iOS, where
  /// consent is gathered inside `checkAgeSignals()` itself and a refusal
  /// surfaces there as `AgeSignalsStatus.declined`.
  shared,

  /// The user is not sharing age signals.
  ///
  /// The user declined the prompt or previously chose not to share, a
  /// parent rejected sharing, or the user is not eligible. A decline is a
  /// normal outcome, not an error; `checkAgeSignals()` carries no signals
  /// in this state.
  notShared,

  /// The user must verify their age in the Play Store first.
  ///
  /// Reported in regions with mandatory verification laws when the age is
  /// unknown. Play does not show the in-app prompt here; the user completes
  /// verification in the Play Store app.
  verificationRequired,

  /// Play reported a state this plugin version does not recognize.
  unknown;

  /// Parses a status name coming over the platform channel.
  ///
  /// Falls back to [unknown] for names this version does not know, so
  /// future Google additions degrade gracefully instead of crashing the
  /// parse.
  static AgeSignalsAccessStatus fromName(String name) =>
      AgeSignalsAccessStatus.values.asNameMap()[name] ??
      AgeSignalsAccessStatus.unknown;
}
