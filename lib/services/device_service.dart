
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

    final deviceName = LocalStorageService.getDeviceName();

    if (deviceName == null || deviceName.isEmpty) {
      await LocalStorageService.saveDeviceName('আমার ফোন');
    }

    final location = LocalStorageService.getDeviceLocation();

    if (location == null) {
      await LocalStorageService.saveDeviceLocation('');
    }

    return deviceId;
  }

  static String get deviceId =>
      LocalStorageService.getDeviceId() ?? '';

  static String get deviceName =>
      LocalStorageService.getDeviceName() ?? 'আমার ফোন';

  static String get deviceLocation =>
      LocalStorageService.getDeviceLocation() ?? '';

  static Future<void> setDeviceName(String name) async {
    final value = name.trim();

    if (value.isNotEmpty) {
      await LocalStorageService.saveDeviceName(value);
    }
  }

  static Future<void> setDeviceLocation(String location) async {
    await LocalStorageService.saveDeviceLocation(location.trim());
  }
}
