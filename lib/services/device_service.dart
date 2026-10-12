import 'package:uuid/uuid.dart';

import 'local_storage_service.dart';

class DeviceService {
  static const Uuid _uuid = Uuid();

  static Future<String> initialize() async {
    String? deviceId = StorageService.getDeviceId();

    if (deviceId == null || deviceId.isEmpty) {
      deviceId = _uuid.v4();
      await StorageService.saveDeviceId(deviceId);
    }

    String? deviceName = StorageService.getDeviceName();

    if (deviceName == null || deviceName.isEmpty) {
      await StorageService.saveDeviceName('আমার ফোন');
    }

    return deviceId;
  }

  static String get deviceId {
    return StorageService.getDeviceId() ?? '';
  }

  static String get deviceName {
    return StorageService.getDeviceName() ?? 'আমার ফোন';
  }

  static Future<void> setDeviceName(String name) async {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      return;
    }

    await StorageService.saveDeviceName(trimmedName);
  }
}
