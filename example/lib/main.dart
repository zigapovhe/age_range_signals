import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

import 'package:age_range_signals/age_range_signals.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Age Range Signals Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
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

  final List<int> _ageGates = [13, 16, 18];

  @override
  void initState() {
    super.initState();
    _initializePlugin();
  }

  Future<void> _initializePlugin() async {
    if (Platform.isIOS) {
      try {
        await AgeRangeSignals.instance.initialize(ageGates: _ageGates);
        setState(() {
          _isInitialized = true;
        });
      } catch (e) {
        setState(() {
          _error = 'Initialization failed: $e';
        });
      }
    } else {
      setState(() {
        _isInitialized = true;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Age Range Signals'),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildCheckButton(),
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
                  ? 'Note: The Play Age Signals API will return mock data until January 1, 2026.'
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
            Text(
              _error ?? '',
              style: TextStyle(color: Colors.red[900]),
            ),
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
          Expanded(
            child: Text(value),
          ),
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
}
