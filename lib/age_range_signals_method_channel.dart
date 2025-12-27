import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'age_range_signals_platform_interface.dart';
import 'src/models/age_signals_result.dart';
import 'src/models/age_signals_mock_data.dart';
import 'src/exceptions/age_signals_exception.dart';

/// An implementation of [AgeRangeSignalsPlatform] that uses method channels.
class MethodChannelAgeRangeSignals extends AgeRangeSignalsPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('age_range_signals');

  @override
  Future<void> initialize({
    List<int>? ageGates,
    bool useMockData = false,
    AgeSignalsMockData? mockData,
  }) async {
    try {
      await methodChannel.invokeMethod<void>('initialize', {
        'ageGates': ageGates,
        'useMockData': useMockData,
        'mockData': mockData?.toMap(),
      });
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  @override
  Future<AgeSignalsResult> checkAgeSignals() async {
    try {
      final result = await methodChannel.invokeMethod<Map>('checkAgeSignals');
      if (result == null) {
        throw const AgeSignalsException('Received null result from platform');
      }
      return AgeSignalsResult.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  AgeSignalsException _handlePlatformException(PlatformException e) {
    final details = e.details?.toString();

    switch (e.code) {
      case 'API_NOT_AVAILABLE':
        return ApiNotAvailableException(
          e.message ?? 'Age verification API is not available',
          e.code,
          details,
        );
      case 'UNSUPPORTED_PLATFORM':
        return UnsupportedPlatformException(
          e.message ?? 'Platform version does not support age verification',
          e.code,
          details,
        );
      case 'NOT_INITIALIZED':
        return NotInitializedException(
          e.message ?? 'Plugin not initialized. Call initialize() first.',
          e.code,
          details,
        );
      case 'MISSING_ENTITLEMENT':
        return MissingEntitlementException(
          e.message ?? 'Required entitlement is missing or not approved',
          e.code,
          details,
        );
      case 'API_ERROR':
        return ApiErrorException(
          e.message ?? 'Platform API error occurred',
          e.code,
          details,
        );
      case 'PLAY_SERVICES_ERROR':
        return PlayServicesException(
          e.message ?? 'Google Play Services is unavailable or outdated',
          e.code,
          details,
        );
      case 'NETWORK_ERROR':
        return NetworkErrorException(
          e.message ?? 'Network error occurred',
          e.code,
          details,
        );
      case 'USER_NOT_SIGNED_IN':
        return UserNotSignedInException(
          e.message ?? 'User is not signed in to Google account',
          e.code,
          details,
        );
      case 'USER_CANCELLED':
        return UserCancelledException(
          e.message ?? 'User cancelled the age verification',
          e.code,
          details,
        );
      default:
        return AgeSignalsException(
          e.message ?? 'An error occurred',
          e.code,
          details,
        );
    }
  }
}
