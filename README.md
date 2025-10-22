# update_manager

A Flutter package for managing app updates with **Firebase Remote Config** and **Shorebird patch updates**.  
It helps you implement **force updates**, **optional updates**, and **patch updates** easily.

---

## ✨ Features
- 🚀 Force update when a critical version is required
- 📢 Optional update when a newer version is available
- ⚡ Patch updates via Shorebird
- 🔧 Configurable via Firebase Remote Config
- 🎯 Simple integration with callback support
- 🛠️ Example app included

---
## 📦 Installation

### 1. Add Dependencies
Add this to your `pubspec.yaml`:
```yaml
dependencies:
  update_manager: ^1.2.0
  # Required dependencies
  firebase_core: ^4.1.1
  package_info_plus: ^9.0.0
```

### 2. Install Packages
Run:
```sh
flutter pub get
```

### 3. Configure Firebase
This package requires Firebase to be configured in your project. Follow the [official Firebase setup guide](https://firebase.google.com/docs/flutter/setup) for your platform:

- [Android setup](https://firebase.google.com/docs/flutter/setup?platform=android)
- [iOS setup](https://firebase.google.com/docs/flutter/setup?platform=ios)

Make sure to initialize Firebase in your `main.dart`:
```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}
```


### 4. Setup Shorebird for Code Push Updates

#### Install Shorebird CLI

### Install Shorebird
[Shorebird Quickstart](https://docs.shorebird.dev/getting-started/)

```sh
# Verify installation
shorebird --version
```

For more information, visit the [Shorebird documentation](https://docs.shorebird.dev/).

---

## 🚀 Usage

## Main Entry Points in [`Example/`](example)

- **`main.dart`** – Standard setup. Requires manual configuration of update checks and UI.
- **`main_default_ui.dart`** – Comes with built-in update dialogs and patch UI. Minimal configuration required.

**Tip:** For quick setup with default UI, use `main_default_ui.dart`.

```dart
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
      androidPlayStoreUrl: 'redirection link',
      iosAppStoreUrl: 'redirection link',
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
```

---

## ⚙️ Firebase Setup

1. Enable **Remote Config** in your Firebase Console.
2. Add the following default parameters and values.
3. Refer to [`example/remoteconfig.template.json`](example/remoteconfig.template.json) for a complete example.

| Key                    | Example Value                                                                                                                                                                                                                                                                                                                                                                                                  | Description                                                                                                               |
|------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------|
| `min_required_version` | `{"stable": "1.0.0", "beta": "1.0.5", "staging": "1.0.10"}`                                                                                                                                                                                                                                                                                                                                                    | Minimum app version required **per track**. JSON map of track versions (`{"stable": "1.0.0", "beta": "1.0.5"}`).          |
| `latest_version`       | `{"stable": "1.0.29", "beta": "1.0.30", "staging": "1.0.31"}`                                                                                                                                                                                                                                                                                                                                                  | Latest available version **per track**. JSON map of track versions (`{"stable": "1.0.29", "beta": "1.0.30"}`).            |
| `patch_enabled`        | `true`                                                                                                                                                                                                                                                                                                                                                                                                         | Global flag to enable or disable patch checking.                                                                          |
| `patch_info`           | `{ "1.0.25": { "stable": 1, "beta": 0, "staging": 0 }, "1.0.1": { "stable": 1, "beta": 2, "staging": 3 } }`                                                                                                                                                                                                                                                                                                    | Patch numbers per version and track. The format is `{ "version": { "track": patchNumber } }`.                             |
| `redirect_url`         | `{ "android": { "stable": "https://play.google.com/store/apps/details?id=com.example.stable", "beta": "https://play.google.com/store/apps/details?id=com.example.beta", "staging": "https://play.google.com/store/apps/details?id=com.example.staging"}, "ios": {"stable": "https://apps.apple.com/app/idxxxx", "beta": "https://apps.apple.com/app/idxxxx", "staging": "https://apps.apple.com/app/idxxxx"}}` | Redirection URLs for each platform and track. JSON {"android": {"stable": "<url>", ...}, "ios": {"stable": "<url>", ...}} | 

**Example `patch_info` value:**

```json
{
  "1.0.25": { "stable": 1, "beta": 0, "staging": 0 },
  "1.0.1": { "stable": 1, "beta": 2, "staging": 3 }
}
```


---

## 📄 Changelog

See the [Changelog](CHANGELOG.md)

---

## 📱 Example

See the [`example/`](example) folder for a full demo project.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

