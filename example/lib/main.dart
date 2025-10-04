import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:update_manager/update_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Update Manager Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Update Manager Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  UpdateManager? _updateManager;
  UpdateType _currentUpdateType = UpdateType.none;
  UpdateSource? _currentUpdateSource;
  int? _patchNumber;
  ShorebirdUpdateStatus _shorebirdStatus = ShorebirdUpdateStatus.idle;
  String? _errorMessage;
  UpdateTrack _currentTrack = UpdateTrack.stable;
  bool _isCheckingForUpdates = false;
  String _currentVersion = '';
  int? _currentPatchNumber;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final packageInfo = await PackageInfo.fromPlatform();

    setState(() {
      _currentVersion = packageInfo.version;
    });

    _updateManager = UpdateManager(
      enableShorebird: true,
      packageInfo: packageInfo,
      onUpdate: ({
        required UpdateType type,
        UpdateSource source = UpdateSource.release,
        int? patchNumber,
      }) async {
        if (!mounted) return;
        setState(() {
          _currentUpdateType = type;
          _currentUpdateSource = source;
          _patchNumber = patchNumber;
        });
        debugPrint(
          "Update detected → Type: $type, Source: $source, Patch: $patchNumber",
        );
      },
      onShorebirdStatusChange: ({
        required ShorebirdUpdateStatus status,
        UpdateType? type,
        int? patchNumber,
        String? errorMessage,
      }) async {
        if (!mounted) return;
        setState(() {
          _shorebirdStatus = status;
          _errorMessage = errorMessage;
          if (patchNumber != null) _patchNumber = patchNumber;

          // Reset checking flag when we get a final status
          if (status != ShorebirdUpdateStatus.checking &&
              status != ShorebirdUpdateStatus.downloading) {
            _isCheckingForUpdates = false;
          }
        });

        // Show appropriate UI based on status
        _handleShorebirdStatus(status, errorMessage);

        // If restart is required or checking, refresh current patch number
        if (status == ShorebirdUpdateStatus.restartRequired ||
            status == ShorebirdUpdateStatus.checking) {
          _refreshCurrentPatch();
        }
      },
    );

    try {
      await _updateManager?.initialise(shorebirdTrack: _currentTrack);

      // Read current installed patch
      final installedPatch = await _updateManager?.shorebirdService?.readCurrentPatch();
      if (mounted) {
        setState(() {
          _currentPatchNumber = installedPatch;
        });

        // Show success message if patch was just applied
        // if (installedPatch != null && installedPatch > 0) {
        //   debugPrint('✅ Running on patch: $installedPatch');
        //   Future.delayed(const Duration(seconds: 1), () {
        //     if (mounted) {
        //       ScaffoldMessenger.of(context).showSnackBar(
        //         SnackBar(
        //           content: Text('✅ Running on patch $installedPatch'),
        //           backgroundColor: Colors.green,
        //           duration: const Duration(seconds: 3),
        //         ),
        //       );
        //     }
        //   });
        // }
      }
    } catch (e) {
      debugPrint("UpdateManager init error: $e");
    }
  }

  Future<void> _refreshCurrentPatch() async {
    final installedPatch = await _updateManager?.shorebirdService?.readCurrentPatch();
    if (mounted) {
      setState(() {
        _currentPatchNumber = installedPatch;
      });
    }
  }

  void _handleShorebirdStatus(ShorebirdUpdateStatus status, String? errorMessage) {
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();

    switch (status) {
      case ShorebirdUpdateStatus.checking:
        _showCheckingBanner();
        break;
      case ShorebirdUpdateStatus.updateAvailable:
        _showUpdateAvailableBanner();
        break;
      case ShorebirdUpdateStatus.downloading:
        _showDownloadingBanner();
        break;
      case ShorebirdUpdateStatus.restartRequired:
        _showRestartBanner();
        break;
      case ShorebirdUpdateStatus.upToDate:
        _showUpToDateBanner();
        break;
      case ShorebirdUpdateStatus.unavailable:
      // Already shown in build method
        break;
      case ShorebirdUpdateStatus.error:
        _showErrorBanner(errorMessage ?? 'Unknown error');
        break;
      case ShorebirdUpdateStatus.idle:
      // Do nothing
        break;
    }
  }

  void _showCheckingBanner() {
    ScaffoldMessenger.of(context).showMaterialBanner(
      const MaterialBanner(
        content: Text('Checking for updates...'),
        actions: [
          SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ),
    );
  }

  void _showUpdateAvailableBanner() {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text('Update available for the ${_currentTrack.name} track.'),
        actions: [
          TextButton(
            onPressed: () async {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              await _updateManager?.downloadShorebirdPatch(track: _currentTrack);
            },
            child: const Text('Download'),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  void _showDownloadingBanner() {
    ScaffoldMessenger.of(context).showMaterialBanner(
      const MaterialBanner(
        content: Text('Downloading patch...'),
        actions: [
          SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ),
    );
  }

  void _showRestartBanner() {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: Colors.green.shade100,
        content: const Text(
          'Patch downloaded successfully!\n'
              '⚠️ You must close and reopen the app to apply the patch.\n'
              'Hot restart will NOT work.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showUpToDateBanner() {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text('No update available on the ${_currentTrack.name} track.'),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  void _showErrorBanner(String error) {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: Colors.red.shade100,
        content: Text('Error: $error'),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdate() async {
    if (_isCheckingForUpdates) return;

    setState(() => _isCheckingForUpdates = true);

    try {
      await _updateManager?.checkShorebirdPatch(track: _currentTrack);
    } catch (e) {
      debugPrint('Error checking for update: $e');
      if (mounted) {
        setState(() => _isCheckingForUpdates = false);
      }
    }
    // Note: _isCheckingForUpdates will be reset to false in the status callback
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUpdaterUnavailable = _shorebirdStatus == ShorebirdUpdateStatus.unavailable;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          if (isUpdaterUnavailable)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.red.shade100,
              child: Text(
                'Shorebird is not available.\n'
                    'Please ensure the app was built with `shorebird release`\n'
                    'and is running in release mode.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.red.shade900,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Current Version & Patch Info
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'Current Version',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentVersion,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _shorebirdStatus == ShorebirdUpdateStatus.restartRequired
                                  ? Icons.warning_amber
                                  : Icons.info_outline,
                              size: 20,
                              color: _shorebirdStatus == ShorebirdUpdateStatus.restartRequired
                                  ? Colors.orange
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Installed Patch: ${_currentPatchNumber ?? 'None'}',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (_shorebirdStatus == ShorebirdUpdateStatus.restartRequired &&
                            _patchNumber != null &&
                            _patchNumber != _currentPatchNumber) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '→ Will update to patch $_patchNumber on restart',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _StatusCard(
                  title: 'Update Type',
                  value: _currentUpdateType.name,
                ),
                const SizedBox(height: 12),
                _StatusCard(
                  title: 'Update Source',
                  value: _currentUpdateSource?.name ?? '-',
                ),
                const SizedBox(height: 12),
                _StatusCard(
                  title: 'Available Patch',
                  value: _patchNumber?.toString() ?? '-',
                ),
                const SizedBox(height: 12),
                _StatusCard(
                  title: 'Shorebird Status',
                  value: _shorebirdStatus.name,
                  valueColor: _getStatusColor(_shorebirdStatus),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Update Track:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SegmentedButton<UpdateTrack>(
                  segments: const [
                    ButtonSegment(
                      label: Text('Stable'),
                      value: UpdateTrack.stable,
                    ),
                    ButtonSegment(
                      label: Text('Beta'),
                      icon: Icon(Icons.science, size: 16),
                      value: UpdateTrack.beta,
                    ),
                    ButtonSegment(
                      label: Text('Staging'),
                      icon: Icon(Icons.construction, size: 16),
                      value: UpdateTrack.staging,
                    ),
                  ],
                  selected: {_currentTrack},
                  onSelectionChanged: (tracks) {
                    setState(() => _currentTrack = tracks.single);
                  },
                ),
              ],
            ),
          ),
          const Spacer(),
          const SizedBox(height: 16),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCheckingForUpdates ? null : _checkForUpdate,
        tooltip: 'Check for update',
        icon: _isCheckingForUpdates
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : const Icon(Icons.refresh),
        label: const Text('Check Update'),
      ),
    );
  }

  Color _getStatusColor(ShorebirdUpdateStatus status) {
    switch (status) {
      case ShorebirdUpdateStatus.upToDate:
        return Colors.green;
      case ShorebirdUpdateStatus.updateAvailable:
        return Colors.orange;
      case ShorebirdUpdateStatus.restartRequired:
        return Colors.blue;
      case ShorebirdUpdateStatus.error:
      case ShorebirdUpdateStatus.unavailable:
        return Colors.red;
      case ShorebirdUpdateStatus.checking:
      case ShorebirdUpdateStatus.downloading:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.value,
    this.valueColor,
  });

  final String title;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$title:',
              style: theme.textTheme.bodyLarge,
            ),
            Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}