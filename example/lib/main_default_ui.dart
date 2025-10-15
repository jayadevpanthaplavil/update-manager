import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:update_manager/update_manager.dart';

const UpdateTrack kAppUpdateTrack = UpdateTrack.stable;

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
        useMaterial3: true,
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
  final UpdateTrack _currentTrack = kAppUpdateTrack;
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

    if (!mounted) return;

    // Configure UI preferences
    final uiConfig = UpdateUIConfig(
      dialogStyle: UpdateUIStyle.material,
      patchUIStyle: PatchUIStyle.snackbar,
      androidPlayStoreUrl:
          'https://drive.google.com/file/d/1-Zk_pYgj0WreW9u8Pgo57w1YFAQJW_JB/view?usp=sharing',
      iosAppStoreUrl: 'https://apps.apple.com/app/xxxxx',
      showDefaultUI: true, // Set to false if using custom callbacks only
      primaryColor: Colors.deepPurple,
      accentColor: Colors.amber,
    );

    _updateManager = UpdateManager(
      enableShorebird: true,
      packageInfo: packageInfo,
      uiConfig: uiConfig,
      context: context,
    );

    try {
      await _updateManager?.initialise(shorebirdTrack: _currentTrack);
      final installedPatch = await _updateManager?.shorebirdService
          ?.readCurrentPatch();
      if (mounted) {
        setState(() {
          _currentPatchNumber = installedPatch;
        });
      }
    } catch (e) {
      debugPrint("UpdateManager init error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Version Info Card
            Card(
              color: theme.colorScheme.primaryContainer,
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
                        Icon(Icons.info_outline, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Installed Patch: ${_currentPatchNumber ?? 'None'}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
