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
  });

  /// The verification status returned by the platform.
  final AgeSignalsStatus status;

  /// The lower bound of the user's age range (iOS only).
  ///
  /// Available when user consents to share age information on iOS.
  /// May be null if user declined or on Android.
  final int? ageLower;

  /// The upper bound of the user's age range (iOS only).
  ///
  /// Available when user consents to share age information on iOS.
  /// May be null if user declined or on Android.
  final int? ageUpper;

  /// The source of the age declaration (iOS only).
  ///
  /// Indicates whether the age was self-declared or declared by a guardian.
  /// Only available on iOS when user consents to share.
  final AgeDeclarationSource? source;

  /// Unique identifier for this app installation (Android only).
  ///
  /// Can be used for compliance tracking and auditing purposes.
  /// Only available on Android.
  final String? installId;

  /// Creates a copy of this result with the given fields replaced with new values.
  AgeSignalsResult copyWith({
    AgeSignalsStatus? status,
    int? ageLower,
    int? ageUpper,
    AgeDeclarationSource? source,
    String? installId,
  }) {
    return AgeSignalsResult(
      status: status ?? this.status,
      ageLower: ageLower ?? this.ageLower,
      ageUpper: ageUpper ?? this.ageUpper,
      source: source ?? this.source,
      installId: installId ?? this.installId,
    );
  }

  @override
  String toString() {
    return 'AgeSignalsResult(status: $status, ageLower: $ageLower, '
        'ageUpper: $ageUpper, source: $source, installId: $installId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AgeSignalsResult &&
        other.status == status &&
        other.ageLower == ageLower &&
        other.ageUpper == ageUpper &&
        other.source == source &&
        other.installId == installId;
  }

  @override
  int get hashCode {
    return Object.hash(status, ageLower, ageUpper, source, installId);
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

    return AgeSignalsResult(
      status: AgeSignalsStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AgeSignalsStatus.unknown,
      ),
      ageLower: map['ageLower'] as int?,
      ageUpper: map['ageUpper'] as int?,
      source: source,
      installId: map['installId'] as String?,
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
    };
  }
}

/// Status of the age verification check.
enum AgeSignalsStatus {
  /// User is verified as being over the age threshold.
  ///
  /// On Android, this means the user's parental controls indicate they are
  /// above the required age. On iOS, this is determined by the declared age
  /// range relative to the configured age gates (e.g., highest gate met).
  verified,

  /// User's age could not be determined.
  ///
  /// This may occur when:
  /// - User has not set up parental controls (Android)
  /// - Age verification data is not available
  /// - API is not available in the user's region
  unknown,

  /// User declined to share their age information (iOS only).
  ///
  /// On iOS, the user explicitly chose not to share their age range
  /// with the app.
  declined,

  /// User is under parental supervision or below age threshold.
  ///
  /// On Android, indicates the user is managed by parental controls
  /// and may be below the required age threshold. On iOS, this value is
  /// returned when the declared age range does not meet the configured gates.
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
  supervisedApprovalDenied,
}

/// Source of the age declaration (iOS only).
enum AgeDeclarationSource {
  /// Age was self-declared by the user.
  selfDeclared,

  /// Age was declared by a guardian in Family Sharing.
  guardianDeclared,
}
