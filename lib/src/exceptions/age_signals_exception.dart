/// Base exception for age signals operations.
class AgeSignalsException implements Exception {
  /// Creates an [AgeSignalsException].
  const AgeSignalsException(this.message, [this.code, this.details]);

  /// A description of the error.
  final String message;

  /// An optional error code.
  final String? code;

  /// Optional detailed diagnostic information.
  ///
  /// Contains platform-specific error details such as error domain,
  /// error code, exception type, and other debugging information.
  final String? details;

  @override
  String toString() {
    if (code != null) {
      return 'AgeSignalsException($code): $message';
    }
    return 'AgeSignalsException: $message';
  }
}

/// Exception thrown when the API is not available on the platform.
class ApiNotAvailableException extends AgeSignalsException {
  /// Creates an [ApiNotAvailableException].
  const ApiNotAvailableException(super.message, [super.code, super.details]);
}

/// Exception thrown when the platform version is incompatible.
class UnsupportedPlatformException extends AgeSignalsException {
  /// Creates an [UnsupportedPlatformException].
  const UnsupportedPlatformException(super.message, [super.code, super.details]);
}

/// Exception thrown when the plugin has not been initialized.
class NotInitializedException extends AgeSignalsException {
  /// Creates a [NotInitializedException].
  const NotInitializedException(super.message, [super.code, super.details]);
}

/// Exception thrown when the required entitlement is missing or not approved.
class MissingEntitlementException extends AgeSignalsException {
  /// Creates a [MissingEntitlementException].
  const MissingEntitlementException(super.message, [super.code, super.details]);
}

/// Exception thrown when the platform API encounters an error.
class ApiErrorException extends AgeSignalsException {
  /// Creates an [ApiErrorException].
  const ApiErrorException(super.message, [super.code, super.details]);
}

/// Exception thrown when Google Play Services is unavailable or outdated (Android).
class PlayServicesException extends AgeSignalsException {
  /// Creates a [PlayServicesException].
  const PlayServicesException(super.message, [super.code, super.details]);
}

/// Exception thrown when a network error occurs.
class NetworkErrorException extends AgeSignalsException {
  /// Creates a [NetworkErrorException].
  const NetworkErrorException(super.message, [super.code, super.details]);
}

/// Exception thrown when the user is not signed in (Android).
class UserNotSignedInException extends AgeSignalsException {
  /// Creates a [UserNotSignedInException].
  const UserNotSignedInException(super.message, [super.code, super.details]);
}

/// Exception thrown when the user cancels the age verification prompt.
class UserCancelledException extends AgeSignalsException {
  /// Creates a [UserCancelledException].
  const UserCancelledException(super.message, [super.code, super.details]);
}
