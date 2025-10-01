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

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final packageInfo = await PackageInfo.fromPlatform();

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
    );

    try {
      await _updateManager?.initialise();
    } catch (e) {
      debugPrint("UpdateManager init error: $e");
    }

    debugPrint("Initial update status: ${_updateManager?.updateTypeStatus}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text("Update Type: $_currentUpdateType"),
            const SizedBox(height: 8),
            Text("Update Source: ${_currentUpdateSource ?? '-'}"),
            const SizedBox(height: 8),
            Text("Patch Number: ${_patchNumber ?? '-'}"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Manually check Shorebird patch updates
          await _updateManager?.checkShorebirdPatch();
        },
        child: const Icon(Icons.refresh),
        tooltip: "Check for Shorebird patch",
      ),
    );
  }
}