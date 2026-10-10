import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothService {
  BluetoothService._();

  static final BluetoothService instance = BluetoothService._();

  factory BluetoothService() => instance;

  static const MethodChannel _nativeChannel =
      MethodChannel('joruri_messenger/bluetooth');

  static final Guid serviceUuid =
      Guid('0000fee0-0000-1000-8000-00805f9b34fb');

  static final Guid characteristicUuid =
      Guid('0000fee1-0000-1000-8000-00805f9b34fb');

  final StreamController<List<ScanResult>> _devicesController =
      StreamController<List<ScanResult>>.broadcast();

  final StreamController<String> _messagesController =
      StreamController<String>.broadcast();

  final StreamController<String> _connectionController =
      StreamController<String>.broadcast();

  final List<ScanResult> _devices = [];

  Stream<List<ScanResult>> get devicesStream =>
      _devicesController.stream;

  Stream<String> get messageStream => _messagesController.stream;

  Stream<String> get connectionStream => _connectionController.stream;

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _characteristic;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _notificationSubscription;
  StreamSubscription<BluetoothConnectionState>? _stateSubscription;

  bool _advertising = false;
  bool _connectionApproved = false;
  bool _serverConnectionApproved = false;
  bool _disposed = false;

  String? _localRequesterId;
  String? _serverConnectedAddress;
  String? _pendingRequesterId;

  bool get isAdvertising => _advertising;

  bool get isConnected =>
      (_connectedDevice != null && _connectionApproved) ||
      (_serverConnectedAddress != null && _serverConnectionApproved);

  Future<bool> requestPermissions() async {
    try {
      final permissions = <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
      ];

      final results = await permissions.request();

      if (results.values.any((status) => status.isPermanentlyDenied)) {
        return false;
      }

      return results.values.every((status) => status.isGranted);
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBluetoothAvailable() async {
    try {
      return await FlutterBluePlus.isSupported &&
          await FlutterBluePlus.adapterState.first ==
              BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleNativeMethod(MethodCall call) async {
    switch (call.method) {
      case 'messageReceived':
        final message = call.arguments;
        if (message is String) {
          _handleIncomingRaw(message);
        }
        break;

      case 'deviceConnected':
        _serverConnectedAddress = call.arguments?.toString();
        _serverConnectionApproved = false;
        _pendingRequesterId = null;
        _connectionController.add(
          'server_pending:${_serverConnectedAddress ?? ''}',
        );
        break;

      case 'deviceDisconnected':
        _serverConnectedAddress = null;
        _serverConnectionApproved = false;
        _pendingRequesterId = null;
        _connectionController.add('server_disconnected');
        break;

      case 'advertisingStarted':
        _advertising = true;
        _connectionController.add('advertising_started');
        break;

      case 'messageSent':
        break;

      case 'bluetoothError':
        _connectionController.add('error:${call.arguments}');
        break;
    }
  }

  void _handleIncomingRaw(String raw) {
    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map<String, dynamic>) {
        final type = decoded['type']?.toString();

        if (type == 'connection_request') {
          _pendingRequesterId = decoded['senderId']?.toString();
          _messagesController.add(raw);
          _connectionController.add('connection_request_received');
          return;
        }

        if (type == 'connection_accepted') {
          final requesterId = decoded['requesterId']?.toString();

          if (requesterId == null ||
              requesterId == _localRequesterId) {
            _connectionApproved = true;
            _connectionController.add('connection_accepted');
          }
          return;
        }

        if (type == 'connection_rejected') {
          final requesterId = decoded['requesterId']?.toString();

          if (requesterId == null ||
              requesterId == _localRequesterId) {
            _connectionApproved = false;
            _connectionController.add('connection_rejected');
          }
          return;
        }
      }
    } catch (_) {
      // Ordinary chat messages may not be JSON.
    }

    _messagesController.add(raw);
  }

  Future<void> startAdvertising() async {
    if (_disposed) return;

    final permitted = await requestPermissions();
    if (!permitted) {
      _connectionController.add('error:Bluetooth permission denied');
      return;
    }

    _nativeChannel.setMethodCallHandler(_handleNativeMethod);

    try {
      await _nativeChannel.invokeMethod<bool>('startAdvertising');
      _advertising = true;
    } catch (e) {
      _connectionController.add('error:$e');
      rethrow;
    }
  }

  Future<void> stopAdvertising() async {
    try {
      await _nativeChannel.invokeMethod<bool>('stopAdvertising');
    } catch (_) {
      // The native service may already be stopped.
    }

    _advertising = false;
  }

  Future<void> startScan() async {
    if (_disposed) return;

    final permitted = await requestPermissions();
    if (!permitted) {
      _connectionController.add('error:Bluetooth permission denied');
      return;
    }

    await stopScan();
    _devices.clear();
    _devicesController.add(List.unmodifiable(_devices));

    try {
      await FlutterBluePlus.startScan(
        withServices: [serviceUuid],
        timeout: const Duration(seconds: 10),
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final index = _devices.indexWhere(
            (item) => item.device.remoteId == result.device.remoteId,
          );

          if (index >= 0) {
            _devices[index] = result;
          } else {
            _devices.add(result);
          }
        }

        if (!_devicesController.isClosed) {
          _devicesController.add(List.unmodifiable(_devices));
        }
      });
    } catch (e) {
      _connectionController.add('error:$e');
    }
  }

  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    if (_disposed) return;

    final permitted = await requestPermissions();
    if (!permitted) {
      _connectionController.add('error:Bluetooth permission denied');
      return;
    }

    await disconnect();

    _connectedDevice = device;
    _connectionApproved = false;

    try {
      await device.connect(
        timeout: const Duration(seconds: 15),
        license: License.free,
      );

      _stateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectionApproved = false;
          _connectedDevice = null;
          _characteristic = null;
          _connectionController.add('disconnected');
        }
      });

      final services = await device.discoverServices();

      BluetoothCharacteristic? foundCharacteristic;

      for (final service in services) {
        if (service.uuid == serviceUuid) {
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid == characteristicUuid) {
              foundCharacteristic = characteristic;
              break;
            }
          }
        }
      }

      if (foundCharacteristic == null) {
        throw Exception('প্রয়োজনীয় Bluetooth service পাওয়া যায়নি');
      }

      _characteristic = foundCharacteristic;

      await _notificationSubscription?.cancel();
      await foundCharacteristic.setNotifyValue(true);

      _notificationSubscription =
          foundCharacteristic.onValueReceived.listen((value) {
        if (value.isNotEmpty) {
          _handleIncomingRaw(utf8.decode(value, allowMalformed: true));
        }
      });

      _connectionController.add(
        'connection_pending:${device.remoteId.str}',
      );
    } catch (e) {
      _connectionApproved = false;
      _connectedDevice = null;
      _characteristic = null;
      _connectionController.add('error:$e');
      rethrow;
    }
  }

  Future<void> requestConnection({
    required String senderId,
    required String senderName,
  }) async {
    if (_connectedDevice == null || _characteristic == null) {
      throw Exception('প্রথমে অন্য ফোনের সঙ্গে Bluetooth সংযোগ করুন');
    }

    _localRequesterId = senderId;
    _connectionApproved = false;

    final request = jsonEncode({
      'type': 'connection_request',
      'senderId': senderId,
      'senderName': senderName,
      'createdAt': DateTime.now().toIso8601String(),
    });

    await _writeToConnectedDevice(request);
    _connectionController.add('connection_request_sent');
  }

  Future<void> respondToConnectionRequest({
    required bool accepted,
    required String requesterId,
  }) async {
    if (_serverConnectedAddress == null) {
      throw Exception('অনুরোধকারী ফোনের Bluetooth সংযোগ পাওয়া যায়নি');
    }

    if (_pendingRequesterId != null &&
        _pendingRequesterId != requesterId) {
      throw Exception('এই অনুরোধটি আর সক্রিয় নেই');
    }

    final response = jsonEncode({
      'type': accepted ? 'connection_accepted' : 'connection_rejected',
      'requesterId': requesterId,
      'createdAt': DateTime.now().toIso8601String(),
    });

    final sent = await _nativeChannel.invokeMethod<bool>(
      'sendMessage',
      {'message': response},
    );

    if (sent != true) {
      throw Exception('উত্তর পাঠানো যায়নি। আবার চেষ্টা করুন');
    }

    _serverConnectionApproved = accepted;
    _pendingRequesterId = null;

    _connectionController.add(
      accepted ? 'connection_accepted' : 'connection_rejected',
    );

    if (!accepted) {
      _connectionController.add('server_rejected');
    }
  }

  Future<void> _writeToConnectedDevice(String message) async {
    final characteristic = _characteristic;

    if (_connectedDevice == null || characteristic == null) {
      throw Exception('Bluetooth সংযোগ পাওয়া যায়নি');
    }

    final payload = utf8.encode(message);

    if (payload.length > 180) {
      throw Exception('মেসেজটি খুব বড়। ছোট করে আবার পাঠান');
    }

    await characteristic.write(
      payload,
      withoutResponse: false,
    );
  }

  Future<void> sendMessage(String message) async {
    if (!isConnected) {
      throw Exception('অন্য ফোনের অনুমোদন এখনো পাওয়া যায়নি');
    }

    if (_connectedDevice != null && _characteristic != null) {
      await _writeToConnectedDevice(message);
      return;
    }

    if (_serverConnectedAddress != null &&
        _serverConnectionApproved) {
      final sent = await _nativeChannel.invokeMethod<bool>(
        'sendMessage',
        {'message': message},
      );

      if (sent != true) {
        throw Exception('মেসেজ পাঠানো যায়নি');
      }
      return;
    }

    throw Exception('Bluetooth সংযোগ পাওয়া যায়নি');
  }

  Future<void> disconnect() async {
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;

    await _stateSubscription?.cancel();
    _stateSubscription = null;

    final device = _connectedDevice;
    _connectedDevice = null;
    _characteristic = null;
    _connectionApproved = false;
    _localRequesterId = null;

    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }

    _connectionController.add('disconnected');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await stopScan();
    await disconnect();
    await stopAdvertising();

    await _devicesController.close();
    await _messagesController.close();
    await _connectionController.close();
  }
}
