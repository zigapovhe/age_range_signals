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
    this.ageRangeSource,
    this.significantChangeStatus,
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
  /// On Android, available whenever age signals are shared; verified 18+
  /// users report the open-ended band (`ageLower: 18, ageUpper: null`).
  /// May be null if user declined (iOS) or if not available from the platform.
  final int? ageLower;

  /// The upper bound of the user's age range.
  ///
  /// On iOS, available when user consents to share age information.
  /// On Android, available whenever age signals are shared. Null for the
  /// open-ended 18+ band on both platforms.
  /// May be null if user declined (iOS) or if not available from the platform.
  final int? ageUpper;

  /// The source of the age declaration (iOS only).
  ///
  /// Indicates whether the age was self-declared or declared by a guardian.
  /// Only available on iOS when user consents to share. Android reports how
  /// an age range was established through [ageRangeSource] instead.
  final AgeDeclarationSource? source;

  /// Unique identifier for this app installation (Android only).
  ///
  /// Reported for supervised users. When a parent revokes approval, Google
  /// lists the id on the Play Console's Revoked app approvals tab as a CSV
  /// download, retained for 90 days - so store it on your backend and
  /// ingest revocations within that window if you need to act on them.
  /// Google permits no other use. Only available on Android.
  final String? installId;

  /// Parental controls active on the user's account (iOS only).
  ///
  /// Stable identifiers as reported by Apple's DeclaredAgeRange framework:
  /// `communicationLimits` (iOS 26.0+) and
  /// `significantAppChangeApprovalRequired` (iOS 26.2+). Controls this
  /// plugin version does not recognize are omitted. Null on Android and
  /// when Apple reports none.
  final List<String>? activeParentalControls;

  /// How Google Play established the age range (Android only).
  ///
  /// [status] is not derived from this tier: the verdict comes from the
  /// reported age band measured against your highest configured age gate.
  /// This says how much assurance backs that band. Null on iOS, and null on
  /// Android when age signals are not shared or verification is still
  /// required.
  final AgeRangeSource? ageRangeSource;

  /// Parent approval state for significant app changes (Android only).
  ///
  /// Only supervised accounts carry this. Null on iOS, for unsupervised
  /// users, and when no significant change has been recorded.
  final SignificantChangeStatus? significantChangeStatus;

  /// Effective date of the most recently approved significant change
  /// (Android only).
  ///
  /// Reported by the Play Age Signals API for supervised users; when a
  /// parent grants approval it moves to the newest approved change's
  /// effective-from date. Values parsed from the platform are UTC; equality
  /// compares the instant, not the time zone. Null on iOS and when Google
  /// does not report it.
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
    AgeRangeSource? ageRangeSource,
    SignificantChangeStatus? significantChangeStatus,
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
      ageRangeSource: ageRangeSource ?? this.ageRangeSource,
      significantChangeStatus:
          significantChangeStatus ?? this.significantChangeStatus,
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
        'ageRangeSource: $ageRangeSource, '
        'significantChangeStatus: $significantChangeStatus, '
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
        other.ageRangeSource == ageRangeSource &&
        other.significantChangeStatus == significantChangeStatus &&
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
      ageRangeSource,
      significantChangeStatus,
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

    final ageRangeSourceValue = map['ageRangeSource'];
    final significantChangeStatusValue = map['significantChangeStatus'];

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
      ageRangeSource: ageRangeSourceValue is String
          ? AgeRangeSource.fromName(ageRangeSourceValue)
          : null,
      significantChangeStatus: significantChangeStatusValue is String
          ? SignificantChangeStatus.fromName(significantChangeStatusValue)
          : null,
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
      'ageRangeSource': ageRangeSource?.name,
      'significantChangeStatus': significantChangeStatus?.name,
      'significantChangeApprovalDate':
          significantChangeApprovalDate?.millisecondsSinceEpoch,
    };
  }
}

/// Status of the age verification check.
enum AgeSignalsStatus {
  /// The reported age range starts at or above your highest configured age
  /// gate.
  ///
  /// Both platforms apply the same rule; Android falls back to 18 when
  /// `initialize()` is called without gates. Any tier can reach this, so a
  /// self-declared band clears the gate just as an ID-verified one does.
  /// Check [AgeSignalsResult.ageRangeSource] if you need a minimum assurance
  /// level.
  verified,

  /// User's age could not be determined.
  ///
  /// This may occur when:
  /// - Age signals are not shared (Android; request access first, and note
  ///   the user may have declined or may still need to verify)
  /// - Age verification data is not available
  /// - API is not available in the user's region
  unknown,

  /// User declined to share their age information (iOS only).
  ///
  /// On iOS, the user explicitly chose not to share their age range
  /// with the app. On Android, a decline surfaces as
  /// `AgeSignalsAccessStatus.notShared` from the access request instead.
  declined,

  /// The reported age range falls below your highest configured age gate.
  ///
  /// Both platforms apply the same rule. This is the age verdict, not the
  /// supervision relationship: any tier can reach it, so read
  /// [AgeSignalsResult.ageRangeSource] to tell a parent-managed account from
  /// an unsupervised one.
  supervised,

  /// User is supervised and a parent approval is pending (Android only).
  ///
  /// On Android, the account is parent-managed and the parent has not yet
  /// approved the most recent significant change reported to Google Play
  /// ([SignificantChangeStatus.pending]). Restrict the functionality behind
  /// the change until it is approved.
  supervisedApprovalPending,

  /// User is supervised and a parent denied approval (Android only).
  ///
  /// On Android, the account is parent-managed and the parent declined the
  /// most recent significant change ([SignificantChangeStatus.declined]).
  ///
  /// iOS never returns this: DeclaredAgeRange has no denied state, so a
  /// guardian decline or consent revocation surfaces as [supervised] with
  /// the user's real age range. The guardian approve/deny signal itself
  /// lives in Apple's PermissionKit and App Store Server Notifications,
  /// which this plugin does not wrap.
  supervisedApprovalDenied,

  /// No longer returned. Read [AgeSignalsResult.ageRangeSource] instead.
  ///
  /// This conflated the verdict with how the age was established. A
  /// self-declared user is now judged by their age range like any other
  /// unsupervised user, so a self-declared adult reports [verified] with
  /// [AgeRangeSource.tierA] rather than being unable to clear an adult gate
  /// at all. Retained so existing switches keep compiling.
  @Deprecated(
    'No longer returned. Check ageRangeSource == AgeRangeSource.tierA '
    'instead. This value will be removed in a future release.',
  )
  declared,
}

/// Source of the age declaration (iOS only).
enum AgeDeclarationSource {
  /// Age was self-declared by the user.
  selfDeclared,

  /// Age was declared by a guardian in Family Sharing.
  guardianDeclared,
}

/// How Google Play established the user's age range (Android only).
///
/// Reported by the Play Age Signals API since age-signals 0.0.4, ordered
/// from weakest to strongest assurance. The tier vocabulary is Google's own;
/// the exact verification methods behind each tier are defined by the Play
/// Age Signals documentation and may evolve.
enum AgeRangeSource {
  /// The user self-declared their age through Google Play.
  tierA,

  /// The age range comes from a parent- or guardian-managed account.
  ///
  /// A pending or declined [AgeSignalsResult.significantChangeStatus] reports
  /// [AgeSignalsStatus.supervisedApprovalPending] or
  /// [AgeSignalsStatus.supervisedApprovalDenied] whatever the age, because an
  /// outstanding guardian decision is actionable either way. Otherwise the
  /// verdict comes from the age band like any other tier, so a supervised
  /// account whose attested band clears your gate reports
  /// [AgeSignalsStatus.verified].
  tierB,

  /// Verified via credit card, email, selfie, government ID, or tax ID.
  tierC,

  /// Verified via government ID plus selfie, or a Digital ID.
  tierD;

  /// Parses a source name coming over the platform channel.
  ///
  /// Returns null for names this version does not know, so future Google
  /// additions degrade gracefully instead of crashing the parse.
  static AgeRangeSource? fromName(String name) =>
      AgeRangeSource.values.asNameMap()[name];
}

/// Parent approval state for significant app changes (Android only).
///
/// Google Play notifies parents of supervised users about significant
/// changes you report on the Age signals page of the Play Console. Approval
/// is cumulative: one parent approval covers every change still pending
/// since the last approval.
enum SignificantChangeStatus {
  /// The parent approved the most recent significant change(s).
  approved,

  /// A parent approval request is active but not yet answered.
  ///
  /// Restrict access to the functionality behind the change until the
  /// parent approves it.
  pending,

  /// The parent denied the significant change(s).
  ///
  /// Restrict access to the functionality behind the declined changes.
  declined;

  /// Parses a status name coming over the platform channel.
  ///
  /// Returns null for names this version does not know, so future Google
  /// additions degrade gracefully instead of crashing the parse.
  static SignificantChangeStatus? fromName(String name) =>
      SignificantChangeStatus.values.asNameMap()[name];
}
