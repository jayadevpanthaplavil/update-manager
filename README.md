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

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  update_manager: ^1.1.0
```

Run:

```sh
flutter pub get
```

---

## 🚀 Usage

```dart
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
      home: const UpdateExampleWidget(),
    );
  }
}

class UpdateExampleWidget extends StatefulWidget {
  const UpdateExampleWidget({super.key});

  @override
  State<UpdateExampleWidget> createState() => _UpdateExampleWidgetState();
}

class _UpdateExampleWidgetState extends State<UpdateExampleWidget> {
  UpdateManager? _updateManager;
  UpdateType _currentUpdateType = UpdateType.none;

  @override
  void initState() {
    super.initState();
    _initializeUpdateService();
  }

  Future<void> _initializeUpdateService() async {
    final packageInfo = await PackageInfo.fromPlatform();

    _updateManager = UpdateManager(
      enableShorebird: true,
      packageInfo: packageInfo,
      onUpdate: ({
        required UpdateType type,
        UpdateSource source = UpdateSource.release,
        int? patchNumber,
      }) async {
        setState(() => _currentUpdateType = type);
      },
    );

    await _updateManager?.initialise(shorebirdTrack: kAppUpdateTrack);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Update Status: $_currentUpdateType')),
    );
  }
}
```

---

## ⚙️ Firebase Setup

1. Enable **Remote Config** in Firebase Console.
2. Add the following default parameters:

| Key                    | Example Value | Description                                                                            |
|------------------------|---------------|----------------------------------------------------------------------------------------|
| `min_required_version` | `1.0.0`       | Minimum app version allowed                                                            |
| `latest_version`       | `1.1.0`       | Latest available version                                                               |
| `patch_enabled`        | `true`        | Enable/disable patch checking                                                          |
| `patch_info`           | JSON string   | Patch numbers per version and track. Format: `{ "version": { "track": patchNumber } }` |

**Example `patch_info` value:**

```json
{
  "1.0.25": { "stable": 1, "beta":0, "staging": 0 },
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

