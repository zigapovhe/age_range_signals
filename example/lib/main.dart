import 'dart:async';
import 'dart:io';

import 'package:age_range_signals/age_range_signals.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Age Range Signals Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const AgeSignalsDemo(),
    );
  }
}

class AgeSignalsDemo extends StatefulWidget {
  const AgeSignalsDemo({super.key});

  @override
  State<AgeSignalsDemo> createState() => _AgeSignalsDemoState();
}

class _AgeSignalsDemoState extends State<AgeSignalsDemo> {
  AgeSignalsResult? _result;
  String? _error;
  bool _isLoading = false;
  bool _isInitialized = false;
  final bool _isIos = Platform.isIOS;
  String _currentScenario = 'Default (Supervised 13-15)';
  String? _accessOutcome;
  String? _regulatoryOutcome;
  String? _acknowledgmentOutcome;

  final List<int> _ageGates = [13, 16, 18];

  @override
  void initState() {
    super.initState();
    _initializePlugin();
  }

  Future<void> _initializePlugin({AgeSignalsMockData? mockData}) async {
    try {
      await AgeRangeSignals.instance.initialize(
        ageGates: _ageGates,
        // useMockData: Android only - uses Google's FakeAgeSignalsManager
        // On iOS, this is ignored and the real DeclaredAgeRange API is always used
        useMockData: true, // Set to true for testing, false for production
        mockData: mockData, // Android only - custom mock data for testing
      );
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _error = 'Initialization failed: $e';
      });
    }
  }

  Future<void> _reinitializeWithScenario(
    String scenarioName,
    AgeSignalsMockData mockData,
  ) async {
    setState(() {
      _currentScenario = scenarioName;
      _result = null;
      _error = null;
      _accessOutcome = null;
    });
    await _initializePlugin(mockData: mockData);
  }

  Future<void> _requestAccess() async {
    setState(() {
      _accessOutcome = 'Requesting...';
    });
    try {
      final status = await AgeRangeSignals.instance.requestAgeSignalsAccess();
      setState(() {
        _accessOutcome = _getAccessStatusText(status);
      });
    } on AgeSignalsException catch (e) {
      setState(() {
        _accessOutcome = '${e.runtimeType}: ${e.message}';
      });
    }
  }

  Future<void> _checkAgeSignals() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await AgeRangeSignals.instance.checkAgeSignals();
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } on ApiNotAvailableException catch (e) {
      setState(() {
        _error = 'API Not Available: ${e.message}';
        _isLoading = false;
      });
    } on UnsupportedPlatformException catch (e) {
      setState(() {
        _error = 'Unsupported Platform: ${e.message}';
        _isLoading = false;
      });
    } on NotInitializedException catch (e) {
      setState(() {
        _error = 'Not Initialized: ${e.message}';
        _isLoading = false;
      });
    } on MissingEntitlementException catch (e) {
      setState(() {
        _error = 'Missing Entitlement: ${e.message}';
        _isLoading = false;
      });
    } on AgeSignalsException catch (e) {
      setState(() {
        _error = 'Error: ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unexpected error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _getRegulatoryFeatures() async {
    setState(() {
      _regulatoryOutcome = 'Checking...';
    });
    final stopwatch = Stopwatch()..start();
    try {
      final features = await AgeRangeSignals.instance
          .getRequiredRegulatoryFeatures();
      stopwatch.stop();
      setState(() {
        _regulatoryOutcome = features.isEmpty
            ? 'Empty set (Apple reports nothing required) '
                  'in ${stopwatch.elapsedMilliseconds} ms'
            : '${features.map((f) => f.name).join(', ')} '
                  'in ${stopwatch.elapsedMilliseconds} ms';
      });
    } on AgeSignalsException catch (e) {
      stopwatch.stop();
      setState(() {
        _regulatoryOutcome =
            '${e.runtimeType}: ${e.message} '
            '(${stopwatch.elapsedMilliseconds} ms)';
      });
    }
  }

  Future<void> _showSignificantUpdate() async {
    setState(() {
      _acknowledgmentOutcome = 'Presenting...';
    });
    try {
      await AgeRangeSignals.instance.showSignificantUpdateAcknowledgment(
        updateDescription:
            'We added social features and public profiles to this app.',
      );
      setState(() {
        _acknowledgmentOutcome = 'Acknowledged';
      });
    } on AgeSignalsException catch (e) {
      setState(() {
        _acknowledgmentOutcome = '${e.runtimeType}: ${e.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Age Range Signals'), elevation: 2),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard(),
            if (_isIos) ...[const SizedBox(height: 12), _buildIosWarningCard()],
            if (!_isIos) ...[const SizedBox(height: 12), _buildScenarioCard()],
            const SizedBox(height: 16),
            _buildAccessButton(),
            const SizedBox(height: 12),
            _buildCheckButton(),
            const SizedBox(height: 12),
            _buildRegulatoryCard(),
            const SizedBox(height: 24),
            if (_isLoading) _buildLoadingIndicator(),
            if (_error != null) _buildErrorCard(),
            if (_result != null) _buildResultCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Platform: ${Platform.isAndroid ? 'Android' : 'iOS'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (Platform.isIOS) ...[
              Text(
                'Age Gates: ${_ageGates.join(", ")}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Status: ${_isInitialized ? "Initialized" : "Not initialized"}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _isInitialized ? Colors.green : Colors.orange,
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              Platform.isAndroid
                  ? 'Note: This example uses mock data (useMockData: true) for testing. You can test different scenarios using the chips below.'
                  : 'Note: DeclaredAgeRange requires iOS 26.0 or later. On older iOS versions, you will receive an UnsupportedPlatformException.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Scenarios',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Current: $_currentScenario',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.blue[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildScenarioChip(
                  'Default (Supervised 13-15)',
                  AgeSignalsMockData(
                    status: AgeSignalsStatus.supervised,
                    ageLower: 13,
                    ageUpper: 15,
                    installId: 'test_install_id_12345',
                  ),
                ),
                _buildScenarioChip(
                  'Supervised 16-17',
                  AgeSignalsMockData(
                    status: AgeSignalsStatus.supervised,
                    ageLower: 16,
                    ageUpper: 17,
                    installId: 'test_install_id_12345',
                  ),
                ),
                _buildScenarioChip(
                  'Verified (18+)',
                  const AgeSignalsMockData(status: AgeSignalsStatus.verified),
                ),
                _buildScenarioChip(
                  'Approval Pending',
                  AgeSignalsMockData(
                    status: AgeSignalsStatus.supervisedApprovalPending,
                    ageLower: 13,
                    ageUpper: 15,
                    installId: 'test_install_id_12345',
                  ),
                ),
                _buildScenarioChip(
                  'Approval Denied',
                  AgeSignalsMockData(
                    status: AgeSignalsStatus.supervisedApprovalDenied,
                    ageLower: 13,
                    ageUpper: 15,
                    installId: 'test_install_id_12345',
                  ),
                ),
                _buildScenarioChip(
                  'Declared Age',
                  const AgeSignalsMockData(
                    status: AgeSignalsStatus.declared,
                    ageLower: 13,
                    ageUpper: 15,
                  ),
                ),
                _buildScenarioChip(
                  'Unknown',
                  const AgeSignalsMockData(status: AgeSignalsStatus.unknown),
                ),
                _buildScenarioChip(
                  'Access Not Shared',
                  const AgeSignalsMockData(
                    status: AgeSignalsStatus.unknown,
                    accessStatus: AgeSignalsAccessStatus.notShared,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioChip(String label, AgeSignalsMockData mockData) {
    return ActionChip(
      label: Text(label),
      onPressed: () => _reinitializeWithScenario(label, mockData),
    );
  }

  Widget _buildAccessButton() {
    // Step 1 of the Play flow: ask for access (may show Play's age sharing
    // prompt). On iOS this resolves to "shared" without showing anything.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _isLoading || !_isInitialized ? null : _requestAccess,
          icon: const Icon(Icons.lock_open),
          label: const Text('Request Age Signals Access'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        if (_accessOutcome != null) ...[
          const SizedBox(height: 8),
          Text(
            'Access: $_accessOutcome',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _buildCheckButton() {
    return FilledButton.icon(
      onPressed: _isLoading || !_isInitialized ? null : _checkAgeSignals,
      icon: const Icon(Icons.verified_user),
      label: const Text('Check Age Signals'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildRegulatoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Regulatory Features (iOS 26.4+)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _getRegulatoryFeatures,
              icon: const Icon(Icons.policy_outlined),
              label: const Text('Get Required Regulatory Features'),
            ),
            if (_regulatoryOutcome != null) ...[
              const SizedBox(height: 8),
              Text(
                _regulatoryOutcome!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showSignificantUpdate,
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Show Significant Update Sheet'),
            ),
            if (_acknowledgmentOutcome != null) ...[
              const SizedBox(height: 8),
              Text(
                _acknowledgmentOutcome!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIosWarningCard() {
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.orange[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'iOS real-device test',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.orange[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Runs the real DeclaredAgeRange API (iOS 26.2+). The project references Runner.entitlements, so device signing requires the com.apple.developer.declared-age-range capability registered on your App ID; register it in the developer portal or point the bundle ID at an App ID that has it. To exercise real responses, sign into a Sandbox Apple Account set to an applicable region (Settings > Developer) and pick a scenario under Age Assurance. Prefer release builds for this: debug builds have been seen to stall on the regulatory features call (the plugin times out after 10 seconds). See the iOS Testing section of the README.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[700]),
                const SizedBox(width: 8),
                Text(
                  'Error',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_error ?? '', style: TextStyle(color: Colors.red[900])),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'Result',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildResultRow('Status', _getStatusText(_result!.status)),
            if (_result!.ageLower != null)
              _buildResultRow('Age Lower Bound', _result!.ageLower.toString()),
            if (_result!.ageUpper != null)
              _buildResultRow('Age Upper Bound', _result!.ageUpper.toString()),
            if (_result!.source != null)
              _buildResultRow('Source', _getSourceText(_result!.source!)),
            if (_result!.ageRangeSource != null)
              _buildResultRow(
                'Range Source',
                _getAgeRangeSourceText(_result!.ageRangeSource!),
              ),
            if (_result!.significantChangeStatus != null)
              _buildResultRow(
                'Change Status',
                _getChangeStatusText(_result!.significantChangeStatus!),
              ),
            if (_result!.significantChangeApprovalDate != null)
              _buildResultRow(
                'Change Approved',
                _result!.significantChangeApprovalDate!.toIso8601String(),
              ),
            if (_result!.installId != null)
              _buildResultRow('Install ID', _result!.installId!),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _getStatusText(AgeSignalsStatus status) {
    switch (status) {
      case AgeSignalsStatus.verified:
        return 'Verified (User is above age threshold)';
      case AgeSignalsStatus.supervised:
        return 'Supervised (User may be under age threshold)';
      case AgeSignalsStatus.supervisedApprovalPending:
        return 'Supervised (Awaiting guardian approval)';
      case AgeSignalsStatus.supervisedApprovalDenied:
        return 'Supervised (Guardian denied approval)';
      case AgeSignalsStatus.declared:
        return 'Declared (User has declared their age)';
      case AgeSignalsStatus.declined:
        return 'Declined (User chose not to share)';
      case AgeSignalsStatus.unknown:
        return 'Unknown (Age information not available)';
    }
  }

  String _getSourceText(AgeDeclarationSource source) {
    switch (source) {
      case AgeDeclarationSource.selfDeclared:
        return 'Self Declared';
      case AgeDeclarationSource.guardianDeclared:
        return 'Guardian Declared';
    }
  }

  String _getAccessStatusText(AgeSignalsAccessStatus status) {
    switch (status) {
      case AgeSignalsAccessStatus.shared:
        return 'Shared (age signals available)';
      case AgeSignalsAccessStatus.notShared:
        return 'Not shared (user or parent declined)';
      case AgeSignalsAccessStatus.verificationRequired:
        return 'Verification required (completed in the Play Store)';
      case AgeSignalsAccessStatus.unknown:
        return 'Unknown';
    }
  }

  String _getAgeRangeSourceText(AgeRangeSource source) {
    switch (source) {
      case AgeRangeSource.tierA:
        return 'Tier A (self-declared)';
      case AgeRangeSource.tierB:
        return 'Tier B (parent-managed account)';
      case AgeRangeSource.tierC:
        return 'Tier C (verified)';
      case AgeRangeSource.tierD:
        return 'Tier D (strongly verified)';
    }
  }

  String _getChangeStatusText(SignificantChangeStatus status) {
    switch (status) {
      case SignificantChangeStatus.approved:
        return 'Approved (parent approved the latest change)';
      case SignificantChangeStatus.pending:
        return 'Pending (waiting for parent approval)';
      case SignificantChangeStatus.declined:
        return 'Declined (parent denied the change)';
    }
  }
}
