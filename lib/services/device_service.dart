import 'package:uuid/uuid.dart';

import 'local_storage_service.dart';

class DeviceService {
  static const Uuid _uuid = Uuid();

  static Future<String> initialize() async {
    String? deviceId = LocalStorageService.getDeviceId();

    if (deviceId == null || deviceId.isEmpty) {
      deviceId = _uuid.v4();
      await LocalStorageService.saveDeviceId(deviceId);
    }

    String? deviceName = LocalStorageService.getDeviceName();

    if (deviceName == null || deviceName.isEmpty) {
      await LocalStorageService.saveDeviceName('আমার ফোন');
    }

    return deviceId;
  }

  static String get deviceId {
    return LocalStorageService.getDeviceId() ?? '';
  }

  static String get deviceName {
    return LocalStorageService.getDeviceName() ?? 'আমার ফোন';
  }

  static Future<void> setDeviceName(String name) async {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      return;
    }

    await LocalStorageService.saveDeviceName(trimmedName);
  }
}
