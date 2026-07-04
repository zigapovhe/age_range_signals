import 'package:age_range_signals/age_range_signals.dart';
import 'package:age_range_signals/age_range_signals_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePlatform extends AgeRangeSignalsPlatform
    with MockPlatformInterfaceMixin {
  Set<AgeRegulatoryFeature> features = const {};
  String? lastUpdateDescription;

  @override
  Future<Set<AgeRegulatoryFeature>> getRequiredRegulatoryFeatures() async =>
      features;

  @override
  Future<void> showSignificantUpdateAcknowledgment({
    required String updateDescription,
  }) async {
    lastUpdateDescription = updateDescription;
  }
}

void main() {
  test('getRequiredRegulatoryFeatures delegates to the platform', () async {
    final fake = _FakePlatform()
      ..features = {AgeRegulatoryFeature.declaredAgeRangeRequired};
    AgeRangeSignalsPlatform.instance = fake;

    final features = await AgeRangeSignals.instance
        .getRequiredRegulatoryFeatures();
    expect(features, {AgeRegulatoryFeature.declaredAgeRangeRequired});
  });

  test(
    'showSignificantUpdateAcknowledgment delegates to the platform',
    () async {
      final fake = _FakePlatform();
      AgeRangeSignalsPlatform.instance = fake;

      await AgeRangeSignals.instance.showSignificantUpdateAcknowledgment(
        updateDescription: 'New chat',
      );
      expect(fake.lastUpdateDescription, 'New chat');
    },
  );
}
