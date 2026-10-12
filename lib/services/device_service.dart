import 'package:uuid/uuid.dart';

import 'local_storage_service.dart';

class DeviceService {
  DeviceService._();

  static final DeviceService instance = DeviceService._();

  static const Uuid _uuid = Uuid();

  static String _deviceId = '';
  static String _deviceName = 'আমার ফোন';
  static String _deviceLocation = '';

  static Future<void> initialize() async {
    // Device ID
    String? savedDeviceId =
        LocalStorageService.getDeviceId();

    if (savedDeviceId == null ||
        savedDeviceId.trim().isEmpty) {
      savedDeviceId = _uuid.v4();
      await LocalStorageService.saveDeviceId(
        savedDeviceId,
      );
    }

    _deviceId = savedDeviceId;

    // Device name
    final savedDeviceName =
        LocalStorageService.getDeviceName();

    if (savedDeviceName == null ||
        savedDeviceName.trim().isEmpty) {
      _deviceName = 'আমার ফোন';

      await LocalStorageService.saveDeviceName(
        _deviceName,
      );
    } else {
      _deviceName = savedDeviceName;
    }

    // Device location
    _deviceLocation =
        LocalStorageService.getDeviceLocation() ?? '';

    if (LocalStorageService.getDeviceLocation() == null) {
      await LocalStorageService.saveDeviceLocation('');
    }
  }

  static String get deviceId {
    return _deviceId.isNotEmpty
        ? _deviceId
        : (LocalStorageService.getDeviceId() ?? '');
  }

  static String get deviceName {
    return _deviceName.isNotEmpty
        ? _deviceName
        : (LocalStorageService.getDeviceName() ?? 'আমার ফোন');
  }

  static String get deviceLocation {
    return _deviceLocation;
  }

  static Future<void> setDeviceName(String value) async {
    final name = value.trim();

    if (name.isEmpty) return;

    await LocalStorageService.saveDeviceName(name);
    _deviceName = name;
  }

  static Future<void> setDeviceLocation(
    String location,
  ) async {
    final value = location.trim();

    await LocalStorageService.saveDeviceLocation(value);
    _deviceLocation = value;
  }
}
