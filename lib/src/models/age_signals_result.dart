import 'package:flutter/foundation.dart';

/// Result returned from checking age signals.
///
/// Contains age verification information from the platform's age verification API.
/// Some fields are platform-specific and may be null depending on the platform
/// and user's response.
class AgeSignalsResult {
  /// Creates an [AgeSignalsResult].
  const AgeSignalsResult({
    required this.status,
    this.ageLower,
    this.ageUpper,
    this.source,
    this.installId,
    this.activeParentalControls,
    DateTime? significantChangeApprovalDate,
    @Deprecated(
      'Use significantChangeApprovalDate instead. '
      'This alias will be removed in a future release.',
    )
    DateTime? mostRecentApprovalDate,
  }) : significantChangeApprovalDate =
           significantChangeApprovalDate ?? mostRecentApprovalDate;

  /// The verification status returned by the platform.
  final AgeSignalsStatus status;

  /// The lower bound of the user's age range.
  ///
  /// On iOS, available when user consents to share age information.
  /// On Android, available for supervised users (based on parental controls).
  /// May be null if user declined (iOS) or if not available from the platform.
  final int? ageLower;

  /// The upper bound of the user's age range.
  ///
  /// On iOS, available when user consents to share age information.
  /// On Android, available for supervised users (based on parental controls).
  /// May be null if user declined (iOS) or if not available from the platform.
  final int? ageUpper;

  /// How the age range was established, i.e. how much assurance it carries.
  ///
  /// This is not the verdict; read [status] for that. On Android this is
  /// Play's `AgeRangeSource` tier. It is null when nothing was shared and
  /// when Play reports a tier this version does not recognise, and it can be
  /// non-null even for [AgeSignalsStatus.unknown] (a shared user whose tier is
  /// known but whose age band is missing). On iOS only
  /// [AgeDeclarationSource.selfDeclared] and
  /// [AgeDeclarationSource.guardianDeclared] occur, and only when the user
  /// consents to share.
  final AgeDeclarationSource? source;

  /// Unique identifier for this app installation (Android only).
  ///
  /// Can be used for compliance tracking and auditing purposes.
  /// Only available on Android.
  final String? installId;

  /// Parental controls active on the user's account (iOS only).
  ///
  /// Stable identifiers as reported by Apple's DeclaredAgeRange framework:
  /// `communicationLimits` (iOS 26.0+) and
  /// `significantAppChangeApprovalRequired` (iOS 26.2+). Controls this
  /// plugin version does not recognize are omitted. Null on Android and
  /// when Apple reports none.
  final List<String>? activeParentalControls;

  /// When the current app version was approved for the user (Android only).
  ///
  /// Reported by the Play Age Signals API for supervised users. Useful for
  /// deciding whether a cached signal is fresh enough. Values parsed from
  /// the platform are UTC; equality compares the instant, not the time
  /// zone. Null on iOS and when Google does not report it.
  final DateTime? significantChangeApprovalDate;

  /// Renamed to [significantChangeApprovalDate] in 0.8.0, following Play
  /// age-signals 0.0.4, which renamed the underlying field.
  @Deprecated(
    'Use significantChangeApprovalDate instead. '
    'This alias will be removed in a future release.',
  )
  DateTime? get mostRecentApprovalDate => significantChangeApprovalDate;

  /// Creates a copy of this result with the given fields replaced with new values.
  AgeSignalsResult copyWith({
    AgeSignalsStatus? status,
    int? ageLower,
    int? ageUpper,
    AgeDeclarationSource? source,
    String? installId,
    List<String>? activeParentalControls,
    DateTime? significantChangeApprovalDate,
    @Deprecated(
      'Use significantChangeApprovalDate instead. '
      'This alias will be removed in a future release.',
    )
    DateTime? mostRecentApprovalDate,
  }) {
    return AgeSignalsResult(
      status: status ?? this.status,
      ageLower: ageLower ?? this.ageLower,
      ageUpper: ageUpper ?? this.ageUpper,
      source: source ?? this.source,
      installId: installId ?? this.installId,
      activeParentalControls:
          activeParentalControls ?? this.activeParentalControls,
      significantChangeApprovalDate:
          significantChangeApprovalDate ??
          mostRecentApprovalDate ??
          this.significantChangeApprovalDate,
    );
  }

  @override
  String toString() {
    return 'AgeSignalsResult(status: $status, ageLower: $ageLower, '
        'ageUpper: $ageUpper, source: $source, installId: $installId, '
        'activeParentalControls: $activeParentalControls, '
        'significantChangeApprovalDate: $significantChangeApprovalDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AgeSignalsResult &&
        other.status == status &&
        other.ageLower == ageLower &&
        other.ageUpper == ageUpper &&
        other.source == source &&
        other.installId == installId &&
        listEquals(other.activeParentalControls, activeParentalControls) &&
        other.significantChangeApprovalDate?.millisecondsSinceEpoch ==
            significantChangeApprovalDate?.millisecondsSinceEpoch;
  }

  @override
  int get hashCode {
    return Object.hash(
      status,
      ageLower,
      ageUpper,
      source,
      installId,
      Object.hashAll(activeParentalControls ?? const []),
      significantChangeApprovalDate?.millisecondsSinceEpoch,
    );
  }

  /// Creates an [AgeSignalsResult] from a map.
  factory AgeSignalsResult.fromMap(Map<String, dynamic> map) {
    AgeDeclarationSource? source;
    final sourceValue = map['source'];
    if (sourceValue is String) {
      for (final candidate in AgeDeclarationSource.values) {
        if (candidate.name == sourceValue) {
          source = candidate;
          break;
        }
      }
    }

    final controls = (map['activeParentalControls'] as List?)
        ?.map((e) => e as String)
        .toList();

    // Accept the pre-0.8.0 key so a result persisted under 0.7.x still
    // round-trips instead of silently losing the date.
    final approvalMillis =
        (map['significantChangeApprovalDate'] ?? map['mostRecentApprovalDate'])
            as int?;
    final approvalDate = approvalMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(approvalMillis, isUtc: true);

    return AgeSignalsResult(
      status: AgeSignalsStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AgeSignalsStatus.unknown,
      ),
      ageLower: map['ageLower'] as int?,
      ageUpper: map['ageUpper'] as int?,
      source: source,
      installId: map['installId'] as String?,
      activeParentalControls: controls,
      significantChangeApprovalDate: approvalDate,
    );
  }

  /// Converts this result to a map.
  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      'ageLower': ageLower,
      'ageUpper': ageUpper,
      'source': source?.name,
      'installId': installId,
      'activeParentalControls': activeParentalControls,
      'significantChangeApprovalDate':
          significantChangeApprovalDate?.millisecondsSinceEpoch,
    };
  }
}

/// Status of the age verification check.
enum AgeSignalsStatus {
  /// The user's age range starts at or above your highest configured age gate.
  ///
  /// Both platforms apply the same rule, so this means the same thing on each.
  /// Android falls back to 18 when [AgeRangeSignals.initialize] is called
  /// without gates, since that is where Play's open-ended top band starts.
  ///
  /// This is the verdict only. Check [AgeSignalsResult.source] for how much
  /// assurance backs the age, and note that a supervised user who clears the
  /// gate reports `verified` with
  /// [AgeDeclarationSource.guardianDeclared], not [supervised].
  verified,

  /// User's age could not be determined.
  ///
  /// This may occur when:
  /// - Play reports `NOT_SHARED`, i.e. the user refused *or* was never asked
  ///   because their region is out of scope (Android cannot distinguish the
  ///   two)
  /// - User has not set up parental controls (Android)
  /// - Age verification data is not available
  /// - API is not available in the user's region
  ///
  /// Treat this as "no signal" and fall back to your own default experience,
  /// not as a refusal.
  unknown,

  /// User explicitly declined to share their age information (iOS only).
  ///
  /// Apple reports a real refusal, so this genuinely means the person was
  /// asked and said no.
  ///
  /// Android never returns this. Play collapses "refused" and "never asked
  /// because the region is out of scope" into one `NOT_SHARED` value, which
  /// cannot be told apart, so the plugin reports [unknown] there rather than
  /// claiming an intent the user may never have expressed.
  declined,

  /// The user must verify their age before signals can be shared
  /// (Android only).
  ///
  /// Play reports `VERIFICATION_REQUIRED` when the user is in a jurisdiction
  /// that requires age verification and their age is not yet established.
  /// Send them to the Play Store app to verify or to set up supervision;
  /// there is no in-app flow for this. iOS never returns this value.
  verificationRequired,

  /// The user's age range falls below your highest configured age gate.
  ///
  /// Both platforms apply the same rule. This describes the age verdict, not
  /// the supervision relationship: read
  /// [AgeDeclarationSource.guardianDeclared] on
  /// [AgeSignalsResult.source] to detect a supervised account, which can also
  /// be [verified] when the attested range clears your gate.
  supervised,

  /// User is supervised and awaiting guardian approval (Android only).
  ///
  /// On Android, this indicates the user is under parental controls and
  /// a request for access has been sent to the guardian, but the guardian
  /// has not yet responded.
  supervisedApprovalPending,

  /// User is supervised and guardian denied approval (Android only).
  ///
  /// On Android, this indicates the user is under parental controls and
  /// the guardian has explicitly denied the access request.
  ///
  /// iOS never returns this: DeclaredAgeRange has no denied state, so a
  /// guardian decline or consent revocation surfaces as [supervised] with
  /// the user's real age range. The guardian approve/deny signal itself
  /// lives in Apple's PermissionKit and App Store Server Notifications,
  /// which this plugin does not wrap.
  supervisedApprovalDenied,

  /// No longer returned. Read [AgeSignalsResult.source] instead.
  ///
  /// This conflated the verdict with how the age was established. A
  /// self-declared adult now reports [verified] with
  /// [AgeDeclarationSource.selfDeclared], so callers can apply their own
  /// assurance policy rather than being unable to clear an adult gate at all.
  /// Retained so existing switches keep compiling.
  @Deprecated(
    'No longer returned. Check source == AgeDeclarationSource.selfDeclared '
    'instead. This value will be removed in a future release.',
  )
  declared,
}

/// How the age range was established, i.e. how much assurance it carries.
///
/// On Android this is Play's `AgeRangeSource` tier. On
/// iOS only [selfDeclared] and [guardianDeclared] occur; Apple reports no
/// equivalent of the estimated or ID-verified tiers.
enum AgeDeclarationSource {
  /// Age was self-declared by an unsupervised user.
  ///
  /// Play `TIER_A`.
  selfDeclared,

  /// Age was attested by a guardian, i.e. the user is supervised.
  ///
  /// Play `TIER_B`. On iOS, declared by a guardian in Family Sharing.
  guardianDeclared,

  /// Age was estimated for an unsupervised user (Android only).
  ///
  /// Play `TIER_C`. Stronger than a bare self-declaration: the age was
  /// assessed from an actual signal such as a credit card, email address,
  /// selfie assessment, government ID or tax ID, rather than typed in.
  estimated,

  /// Age was verified for an unsupervised user by an ID check (Android only).
  ///
  /// Play `TIER_D`, the strongest assurance Play reports: a government ID
  /// combined with a selfie assessment, or a digital ID.
  idVerified,
}
