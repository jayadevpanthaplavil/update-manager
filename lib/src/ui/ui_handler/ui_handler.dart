import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../update_manager.dart';

typedef DownloadPatchCallback = Future<void> Function();

class UpdateUIConfig {
  final UpdateUIStyle dialogStyle;
  final PatchUIStyle patchUIStyle;
  final String? androidPlayStoreUrl;
  final String? iosAppStoreUrl;
  final String? iosTestFlightUrl;
  final bool showDefaultUI;
  final Color? primaryColor;
  final Color? accentColor;

  UpdateUIConfig({
    this.dialogStyle = UpdateUIStyle.material,
    this.patchUIStyle = PatchUIStyle.snackbar,
    this.androidPlayStoreUrl,
    this.iosAppStoreUrl,
    this.iosTestFlightUrl,
    this.showDefaultUI = true,
    this.primaryColor,
    this.accentColor,
  });
}

class UpdateUIHandler {
  final UpdateUIConfig config;
  final BuildContext context;
  final DownloadPatchCallback? onDownloadPatch;

  // Track active UI components with keys
  final Map<String, dynamic> _activeUIComponents = {};

  // Keys for different UI types
  static const String _storeUpdateDialogKey = 'store_update_dialog';
  static const String _patchBannerKey = 'patch_banner';
  static const String _patchOverlayKey = 'patch_overlay';

  // Remote Config Service
  final remoteConfigService = RemoteConfigService.instance;

  UpdateUIHandler({
    required this.context,
    required this.config,
    this.onDownloadPatch,
  });

  /// Dismiss all active update UI components
  void dismissAllUpdateUI() {
    _dismissStoreUpdateDialog();
    _dismissPatchBanner();
    _dismissPatchOverlay();
    _activeUIComponents.clear();
  }

  /// Dismiss only store update dialogs
  void dismissStoreUpdateUI() {
    _dismissStoreUpdateDialog();
  }

  /// Dismiss only patch-related UI
  void dismissPatchUI() {
    _dismissPatchBanner();
    _dismissPatchOverlay();
  }

  /// Check if any UI is currently active
  bool get hasActiveUI => _activeUIComponents.isNotEmpty;

  // Private dismissal methods
  void _dismissStoreUpdateDialog() {
    if (_activeUIComponents.containsKey(_storeUpdateDialogKey)) {
      try {
        Navigator.of(context).pop();
      } catch (e) {
        debugPrint('Error dismissing store update dialog: $e');
      }
      _activeUIComponents.remove(_storeUpdateDialogKey);
    }
  }

  void _dismissPatchBanner() {
    if (_activeUIComponents.containsKey(_patchBannerKey)) {
      try {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      } catch (e) {
        debugPrint('Error dismissing patch banner: $e');
      }
      _activeUIComponents.remove(_patchBannerKey);
    }
  }

  void _dismissPatchOverlay() {
    if (_activeUIComponents.containsKey(_patchOverlayKey)) {
      final entry = _activeUIComponents[_patchOverlayKey] as OverlayEntry?;
      try {
        entry?.remove();
      } catch (e) {
        debugPrint('Error dismissing patch overlay: $e');
      }
      _activeUIComponents.remove(_patchOverlayKey);
    }
  }

  Future<void> handleStoreUpdate({
    required UpdateType type,
    required UpdateSource source,
  }) async {
    if (!config.showDefaultUI) return;

    // Always dismiss any existing store update dialog first
    _dismissStoreUpdateDialog();

    // Give the navigator time to process the pop
    await Future.delayed(const Duration(milliseconds: 100));

    if (!context.mounted) return;
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final isForceUpdate = type == UpdateType.force;

    if (config.dialogStyle == UpdateUIStyle.material || isAndroid) {
      await _showMaterialUpdateDialog(
        type: type,
        isForceUpdate: isForceUpdate,
      );
    } else {
      await _showCupertinoUpdateDialog(
        type: type,
        isForceUpdate: isForceUpdate,
      );
    }
  }

  Future<void> handlePatchUpdate({
    required ShorebirdUpdateStatus status,
    required int? patchNumber,
    required String? errorMessage,
  }) async {
    if (!config.showDefaultUI) return;

    debugPrint('UIHandler: Handling patch update for status: $status');

    // Show UI for all statuses except idle
    if (status == ShorebirdUpdateStatus.idle) {
      return;
    }

    if (config.patchUIStyle == PatchUIStyle.snackbar) {
      _showPatchSnackbar(
        status: status,
        patchNumber: patchNumber,
        errorMessage: errorMessage,
      );
    } else {
      // Dismiss existing patch UI before showing new state
      _dismissPatchBanner();
      _dismissPatchOverlay();

      final isAndroid = Theme.of(context).platform == TargetPlatform.android;

      if (config.dialogStyle == UpdateUIStyle.material || isAndroid) {
        _showMaterialPatchBanner(
          status: status,
          patchNumber: patchNumber,
          errorMessage: errorMessage,
        );
      } else {
        _showCupertinoPatchBanner(
          status: status,
          patchNumber: patchNumber,
          errorMessage: errorMessage,
        );
      }
    }
  }

  // ============ MATERIAL DIALOGS ============

  Future<void> _showMaterialUpdateDialog({
    required UpdateType type,
    required bool isForceUpdate,
  }) async {
    if (isForceUpdate) {
      return _showMaterialForceUpdateDialog();
    } else {
      return _showMaterialOptionalUpdateDialog();
    }
  }

  // Future<void> _showMaterialForceUpdateDialog() async {
  //   _activeUIComponents[_storeUpdateDialogKey] = true;
  //
  //   await showDialog<void>(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (BuildContext dialogContext) => WillPopScope(
  //       onWillPop: () async => false,
  //       child: AlertDialog(
  //         title: const Text('Update Required'),
  //         content: const Text(
  //           'This version is no longer supported. Please update the app to continue using it.',
  //         ),
  //         actions: [
  //           // TextButton(
  //           //   onPressed: () => _exitApp(),
  //           //   child: const Text('Exit App', style: TextStyle(color: Colors.red)),
  //           // ),
  //           FilledButton(
  //             onPressed: () async {
  //               _activeUIComponents.remove(_storeUpdateDialogKey);
  //               if (dialogContext.mounted) {
  //                 Navigator.of(dialogContext).pop();
  //               }
  //               await _navigateToStore();
  //             },
  //             child: const Text('Update Now'),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  //
  //   _activeUIComponents.remove(_storeUpdateDialogKey);
  // }

  Future<void> _showMaterialForceUpdateDialog() async {
    _activeUIComponents[_storeUpdateDialogKey] = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Update Required'),
          content: const Text(
            'This version is no longer supported. Please update the app to continue using it.',
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                _activeUIComponents.remove(_storeUpdateDialogKey);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                await _navigateToStore();
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );

    _activeUIComponents.remove(_storeUpdateDialogKey);
  }

  Future<void> _showMaterialOptionalUpdateDialog() async {
    _activeUIComponents[_storeUpdateDialogKey] = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Update Available'),
        content: const Text(
          'A new version of the app is available. Please update to enjoy the latest features and improvements.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              _activeUIComponents.remove(_storeUpdateDialogKey);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              _activeUIComponents.remove(_storeUpdateDialogKey);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              _navigateToStore();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    _activeUIComponents.remove(_storeUpdateDialogKey);
  }

  // ============ CUPERTINO DIALOGS ============

  Future<void> _showCupertinoUpdateDialog({
    required UpdateType type,
    required bool isForceUpdate,
  }) async {
    if (isForceUpdate) {
      return _showCupertinoForceUpdateDialog();
    } else {
      return _showCupertinoOptionalUpdateDialog();
    }
  }

  Future<void> _showCupertinoForceUpdateDialog() async {
    _activeUIComponents[_storeUpdateDialogKey] = true;

    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => PopScope(
        canPop: false,
        child: CupertinoAlertDialog(
          title: const Text('Update Required'),
          content: const Text(
            'This version is no longer supported. Please update the app to continue using it.',
          ),
          actions: [
            // CupertinoDialogAction(
            //   isDestructiveAction: true,
            //   onPressed: () => _exitApp(),
            //   child: const Text('Exit App'),
            // ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                _activeUIComponents.remove(_storeUpdateDialogKey);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                await _navigateToStore();
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );

    _activeUIComponents.remove(_storeUpdateDialogKey);
  }

  Future<void> _showCupertinoOptionalUpdateDialog() async {
    _activeUIComponents[_storeUpdateDialogKey] = true;

    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => CupertinoAlertDialog(
        title: const Text('Update Available'),
        content: const Text(
          'A new version of the app is available. Please update to enjoy the latest features and improvements.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              _activeUIComponents.remove(_storeUpdateDialogKey);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Later'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              _activeUIComponents.remove(_storeUpdateDialogKey);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              _navigateToStore();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    _activeUIComponents.remove(_storeUpdateDialogKey);
  }

  // ============ PATCH SNACKBAR ============

  void _showPatchSnackbar({
    required ShorebirdUpdateStatus status,
    required int? patchNumber,
    required String? errorMessage,
  }) {
    final (text, backgroundColor, actions) =
        _getPatchSnackbarContent(status, errorMessage);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final snackBar = SnackBar(
      content: Text(text),
      backgroundColor: backgroundColor,
      duration: _getSnackbarDuration(status),
      action: actions.isNotEmpty
          ? SnackBarAction(
              label: actions[0]['label'] as String,
              onPressed: actions[0]['onPressed'] as void Function(),
            )
          : null,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
    _activeUIComponents[_patchBannerKey] = true;
  }

  (String, Color, List<Map<String, dynamic>>) _getPatchSnackbarContent(
    ShorebirdUpdateStatus status,
    String? errorMessage,
  ) {
    const defaultBgColor = Color.fromARGB(255, 33, 33, 33);

    switch (status) {
      case ShorebirdUpdateStatus.checking:
        return (
          'Checking for updates...',
          defaultBgColor,
          [],
        );

      case ShorebirdUpdateStatus.updateAvailable:
        return (
          'A patch update is available.',
          defaultBgColor,
          [
            {
              'label': 'Download',
              'onPressed': () async {
                if (onDownloadPatch != null) {
                  await onDownloadPatch!();
                }
              },
            },
          ],
        );

      case ShorebirdUpdateStatus.downloading:
        return (
          'Hang tight, downloading update...',
          defaultBgColor,
          [],
        );

      case ShorebirdUpdateStatus.restartRequired:
        return (
          'Download complete. Please restart the app to finish updating.',
          Colors.green.shade700,
          [
            {
              'label': 'OK',
              'onPressed': () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            },
          ],
        );

      case ShorebirdUpdateStatus.upToDate:
        return (
          'All set! You’re on the latest version.',
          defaultBgColor,
          [],
        );

      case ShorebirdUpdateStatus.unavailable:
        return (
          'Patch update service is not available.',
          Colors.red.shade700,
          [],
        );

      case ShorebirdUpdateStatus.error:
        return (
          'Error: ${errorMessage ?? 'Unknown error'}',
          Colors.red.shade700,
          [],
        );

      case ShorebirdUpdateStatus.idle:
        return ('', defaultBgColor, []);
    }
  }

  Duration _getSnackbarDuration(ShorebirdUpdateStatus status) {
    switch (status) {
      case ShorebirdUpdateStatus.upToDate:
      case ShorebirdUpdateStatus.unavailable:
      case ShorebirdUpdateStatus.error:
        return const Duration(seconds: 4);
      case ShorebirdUpdateStatus.checking:
      case ShorebirdUpdateStatus.downloading:
        return const Duration(seconds: 30);
      default:
        return const Duration(seconds: 5);
    }
  }

  // ============ MATERIAL BANNERS ============

  void _showMaterialPatchBanner({
    required ShorebirdUpdateStatus status,
    required int? patchNumber,
    required String? errorMessage,
  }) {
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();

    late MaterialBanner banner;

    switch (status) {
      case ShorebirdUpdateStatus.checking:
        banner = const MaterialBanner(
          content: Text('Checking for updates...'),
          actions: [
            SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        );
        break;

      case ShorebirdUpdateStatus.updateAvailable:
        banner = MaterialBanner(
          content: const Text('A patch update is available.'),
          actions: [
            TextButton(
              onPressed: () {
                _dismissPatchBanner();
              },
              child: const Text('Dismiss'),
            ),
            FilledButton(
              onPressed: () async {
                if (onDownloadPatch != null) {
                  await onDownloadPatch!();
                }
              },
              child: const Text('Download'),
            ),
          ],
        );
        break;

      case ShorebirdUpdateStatus.downloading:
        banner = const MaterialBanner(
          content: Row(
            children: [
              SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Expanded(
                  child: Text(
                'Hang tight, downloading update...',
              )),
            ],
          ),
          actions: [SizedBox.shrink()],
        );
        break;

      case ShorebirdUpdateStatus.restartRequired:
        banner = MaterialBanner(
          backgroundColor: Colors.green.shade100,
          content: const Text(
            'Download complete. Please restart the app to finish updating.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                _dismissPatchBanner();
              },
              child: const Text('OK'),
            ),
          ],
        );
        break;

      case ShorebirdUpdateStatus.upToDate:
        banner = MaterialBanner(
          content: const Text(
            'All set! You’re on the latest version.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                _dismissPatchBanner();
              },
              child: const Text('Dismiss'),
            ),
          ],
        );
        break;

      case ShorebirdUpdateStatus.unavailable:
        banner = MaterialBanner(
          backgroundColor: Colors.red.shade100,
          content: const Text(
            'Patch update service is not available.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                _dismissPatchBanner();
              },
              child: const Text('Dismiss'),
            ),
          ],
        );
        break;

      case ShorebirdUpdateStatus.error:
        banner = MaterialBanner(
          backgroundColor: Colors.red.shade100,
          content: Text('Error: ${errorMessage ?? 'Unknown error'}'),
          actions: [
            TextButton(
              onPressed: () {
                _dismissPatchBanner();
              },
              child: const Text('Dismiss'),
            ),
          ],
        );
        break;

      case ShorebirdUpdateStatus.idle:
        return;
    }

    ScaffoldMessenger.of(context).showMaterialBanner(banner);
    _activeUIComponents[_patchBannerKey] = true;
  }

  // ============ CUPERTINO BANNERS ============

  void _showCupertinoPatchBanner({
    required ShorebirdUpdateStatus status,
    required int? patchNumber,
    required String? errorMessage,
  }) {
    // Show overlay for all statuses except idle
    if (status != ShorebirdUpdateStatus.idle) {
      _showCupertinoOverlay(
        status: status,
        errorMessage: errorMessage,
      );
    }
  }

  void _showCupertinoOverlay({
    required ShorebirdUpdateStatus status,
    required String? errorMessage,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: CupertinoPopupSurface(
          isSurfacePainted: true,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: _buildCupertinoUpdateContent(status, errorMessage, entry),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    _activeUIComponents[_patchOverlayKey] = entry;

    // Auto-dismiss after delay for specific states
    final autoDismissDelay = _getAutoDismissDuration(status);
    if (autoDismissDelay != null) {
      Future.delayed(autoDismissDelay, () {
        if (_activeUIComponents[_patchOverlayKey] == entry) {
          entry.remove();
          _activeUIComponents.remove(_patchOverlayKey);
        }
      });
    }
  }

  Duration? _getAutoDismissDuration(ShorebirdUpdateStatus status) {
    switch (status) {
      case ShorebirdUpdateStatus.upToDate:
        return const Duration(seconds: 3);
      default:
        return null; // No auto-dismiss
    }
  }

  Widget _buildCupertinoUpdateContent(
    ShorebirdUpdateStatus status,
    String? errorMessage,
    OverlayEntry entry,
  ) {
    switch (status) {
      case ShorebirdUpdateStatus.checking:
        return const Row(
          children: [
            CupertinoActivityIndicator(),
            SizedBox(width: 12),
            Expanded(child: Text('Checking for updates...')),
          ],
        );

      case ShorebirdUpdateStatus.updateAvailable:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update Available',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('A patch update is available.'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  onPressed: () {
                    entry.remove();
                    _activeUIComponents.remove(_patchOverlayKey);
                  },
                  child: const Text('Dismiss'),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  onPressed: () async {
                    if (onDownloadPatch != null) {
                      await onDownloadPatch!();
                    }
                  },
                  child: const Text('Download'),
                ),
              ],
            ),
          ],
        );

      case ShorebirdUpdateStatus.downloading:
        return const Row(
          children: [
            CupertinoActivityIndicator(),
            SizedBox(width: 12),
            Expanded(child: Text('Hang tight, downloading update...')),
          ],
        );

      case ShorebirdUpdateStatus.restartRequired:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(CupertinoIcons.checkmark_circle_fill,
                    color: CupertinoColors.systemGreen),
                SizedBox(width: 8),
                Text(
                  'Update Ready',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Download complete. Please restart the app to finish updating.',
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  onPressed: () {
                    entry.remove();
                    _activeUIComponents.remove(_patchOverlayKey);
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          ],
        );

      case ShorebirdUpdateStatus.upToDate:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(CupertinoIcons.checkmark_circle_fill,
                    color: CupertinoColors.systemGreen),
                SizedBox(width: 8),
                Text(
                  'Up to Date',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('All set! You’re on the latest version.'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  onPressed: () {
                    entry.remove();
                    _activeUIComponents.remove(_patchOverlayKey);
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          ],
        );

      case ShorebirdUpdateStatus.unavailable:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(CupertinoIcons.xmark_circle_fill,
                    color: CupertinoColors.systemRed),
                SizedBox(width: 8),
                Text(
                  'Unavailable',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Patch update service is not available.',
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  onPressed: () {
                    entry.remove();
                    _activeUIComponents.remove(_patchOverlayKey);
                  },
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ],
        );

      case ShorebirdUpdateStatus.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(CupertinoIcons.xmark_circle_fill,
                    color: CupertinoColors.systemRed),
                SizedBox(width: 8),
                Text(
                  'Error',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(errorMessage ?? 'Unknown error'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  onPressed: () {
                    entry.remove();
                    _activeUIComponents.remove(_patchOverlayKey);
                  },
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ],
        );

      case ShorebirdUpdateStatus.idle:
        return const SizedBox.shrink();
    }
  }

  // ============ NAVIGATION ============

  Future<void> _navigateToStore() async {
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;

    final redirectUrl = remoteConfigService.getRedirectUrl();
    final url = (redirectUrl.isEmpty)
        ? (isAndroid
            ? config.androidPlayStoreUrl
            : config.iosAppStoreUrl ?? config.iosTestFlightUrl)
        : redirectUrl;

    if (url != null && await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      // After returning from the store, recheck the update.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _waitForAppResumed();
      });
    } else {
      debugPrint('Could not launch store URL: $url');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(
            const SnackBar(
              content: Text('Could not open store. Please update manually.'),
            ),
          )
          .closed
          .then(
        (value) async {
          // Immediately check for updates here since user didn't leave app
          await remoteConfigService.handleUpdateCheck();
        },
      );
    }
  }

  void _waitForAppResumed() {
    WidgetsBinding.instance.addObserver(
      _AppLifecycleObserver(
        onResumed: () async {
          await remoteConfigService.handleUpdateCheck();
        },
      ),
    );
  }

  // ============ EXIT APP ============

  // void _exitApp() {
  //   exit(0);
  // }
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  final Future<void> Function() onResumed;

  _AppLifecycleObserver({required this.onResumed});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.removeObserver(this);
      onResumed();
    }
  }
}
