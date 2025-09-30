# update_manager

A Flutter package for managing app updates with **Firebase Remote Config**.  
It helps you implement **force updates** and **optional updates** easily, so users always stay on the right app version.

---

## ✨ Features
- 🚀 Force update when a critical version is required
- 📢 Optional update when a newer version is available
- 🔧 Configurable via Firebase Remote Config
- 🎯 Simple integration with callback support
- 🛠️ Example app included

---

## 📦 Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  update_manager: ^1.0.0
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

class UpdateExampleWidget extends StatefulWidget {
  const UpdateExampleWidget({super.key});

  @override
  State<UpdateExampleWidget> createState() => _UpdateExampleWidgetState();
}

class _UpdateExampleWidgetState extends State<UpdateExampleWidget> {
  late final RemoteConfigService _remoteService;
  UpdateType _updateType = UpdateType.none;

  @override
  void initState() {
    super.initState();
    _initializeUpdateService();
  }

  Future<void> _initializeUpdateService() async {
    final packageInfo = await PackageInfo.fromPlatform();

    _remoteService = RemoteConfigService(
      packageInfo: packageInfo,
      onUpdate: (type) {
        setState(() {
          _updateType = type;
        });

        switch (type) {
          case UpdateType.force:
          // Show force update dialog
            break;
          case UpdateType.optional:
          // Show optional update suggestion
            break;
          case UpdateType.none:
          // No update available
            break;
        }
      },
    );

    await _remoteService.initialiseAndCheck();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Update Status: $_updateType'),
    );
  }
}

```


---

## ⚙️ Firebase Setup

1. Enable **Remote Config** in Firebase Console
2. Add these default parameters:

| Key                    | Example Value | Description                     |
|------------------------|---------------|---------------------------------|
| `min_required_version` | `1.0.0`       | Minimum app version allowed     |
| `latest_version`       | `1.1.0`       | Latest available version        |


---

## 📱 Example

See the [`example/`](example) folder for a full demo project.

---

## Future Enhancements

- Planned integration with Shorebird for patch updates.

---


## 📄 License
This project is licensed under the [MIT License](LICENSE).
