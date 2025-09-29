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
  RemoteConfigService? _remoteService;


  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final packageInfo = await PackageInfo.fromPlatform();

    _remoteService = RemoteConfigService(
      packageInfo: packageInfo,
      onUpdate: (type) async {
        if (!mounted) return;
        setState(() {}); // rebuild UI when update occurs
        debugPrint("Update type changed: $type");
      },
    );

    try {
      await _remoteService?.initialiseAndCheck();
    } catch (e) {
      debugPrint("RemoteConfig init error: $e");
    }

    debugPrint("Current update status: ${_remoteService?.updateTypeStatus}");

    if (!mounted) return;
    setState(() {});
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
            Text("Update Type: ${_remoteService?.updateTypeStatus}"),
            Text(
              '',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }
}
