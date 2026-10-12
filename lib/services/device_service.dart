import 'package:uuid/uuid.dart';
import 'local_storage_service.dart';

class DeviceService {
  DeviceService._();

  static final DeviceService instance = DeviceService._();

  static const Uuid _uuid = Uuid();

  static String _deviceId = '';
  static String _deviceName = 'আমার ফোন';
  static String _deviceLocation = '';

  /// Initialize device information
  static Future<void> initialize() async {
    // Load or create device ID
    String? savedDeviceId = LocalStorageService.getDeviceId();

    if (savedDeviceId == null || savedDeviceId.trim().isEmpty) {
      savedDeviceId = _uuid.v4();
      await LocalStorageService.saveDeviceId(savedDeviceId);
    }

    _deviceId = savedDeviceId;

    // Load or create device name
    final savedDeviceName = LocalStorageService.getDeviceName();

    if (savedDeviceName == null || savedDeviceName.trim().isEmpty) {
      await LocalStorageService.saveDeviceName('আমার ফোন');
      _deviceName = 'আমার ফোন';
    } else {
      _deviceName = savedDeviceName;
    }

    // Load device location
    final savedLocation = LocalStorageService.getDeviceLocation();

    if (savedLocation == null) {
      await LocalStorageService.saveDeviceLocation('');
      _deviceLocation = '';
    } else {
      _deviceLocation = savedLocation;
    }
  }

  /// Get device ID
  static String get deviceId {
    if (_deviceId.isNotEmpty) return _deviceId;

    return LocalStorageService.getDeviceId() ?? '';
  }

  /// Get device name
  static String get deviceName {
    if (_deviceName.isNotEmpty) return _deviceName;

    return LocalStorageService.getDeviceName() ?? 'আমার ফোন';
  }

  /// Get device location
  static String get deviceLocation {
    return _deviceLocation.isNotEmpty
        ? _deviceLocation
        : (LocalStorageService.getDeviceLocation() ?? '');
  }

  /// Update device name
  static Future<void> setDeviceName(String value) async {
    final name = value.trim();

    if (name.isEmpty) return;

    await LocalStorageService.saveDeviceName(name);
    _deviceName = name;
  }

  /// Update device location
  static Future<void> setDeviceLocation(String location) async {
    final value = location.trim();

    await LocalStorageService.saveDeviceLocation(value);
    _deviceLocation = value;
  }
}
