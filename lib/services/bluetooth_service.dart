import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothService {
  static const MethodChannel _nativeChannel =
      MethodChannel('joruri_messenger/bluetooth');

  static const String serviceUuid =
      '0000fee0-0000-1000-8000-00805f9b34fb';

  static const String characteristicUuid =
      '0000fee1-0000-1000-8000-00805f9b34fb';

  static final BluetoothService _instance =
      BluetoothService._internal();

  factory BluetoothService() => _instance;

  BluetoothService._internal() {
    _nativeChannel.setMethodCallHandler(_handleNativeMethod);
  }

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _valueSubscription;

  final StreamController<List<ScanResult>> _devicesController =
      StreamController<List<ScanResult>>.broadcast();

  final StreamController<String> _messageController =
      StreamController<String>.broadcast();

  final StreamController<String> _connectionController =
      StreamController<String>.broadcast();

  final Map<String, ScanResult> _devices = {};

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _characteristic;

  bool _advertising = false;
  bool _disposed = false;

  Stream<List<ScanResult>> get devicesStream =>
      _devicesController.stream;

  Stream<String> get messageStream =>
      _messageController.stream;

  Stream<String> get connectionStream =>
      _connectionController.stream;

  BluetoothDevice? get connectedDevice => _connectedDevice;

  bool get isConnected => _connectedDevice != null;

  bool get isAdvertising => _advertising;

  Future<void> _handleNativeMethod(MethodCall call) async {
    switch (call.method) {
      case 'messageReceived':
        final message = call.arguments?.toString() ?? '';
        if (message.isNotEmpty && !_messageController.isClosed) {
          _messageController.add(message);
        }
        break;

      case 'deviceConnected':
        final address = call.arguments?.toString() ?? '';
        _connectionController.add('server_connected:$address');
        break;

      case 'deviceDisconnected':
        final address = call.arguments?.toString() ?? '';
        _connectionController.add('server_disconnected:$address');
        break;

      case 'advertisingStarted':
        _advertising = true;
        _connectionController.add('advertising_started');
        break;

      case 'messageSent':
        _connectionController.add('message_sent');
        break;

      case 'bluetoothError':
        final error = call.arguments?.toString() ?? 'Bluetooth error';
        _connectionController.add('error:$error');
        break;
    }
  }

  Future<bool> requestPermissions() async {
    final permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ];

    final result = await permissions.request();

    return result.values.every((status) => status.isGranted);
  }

  Future<bool> isBluetoothAvailable() async {
    try {
      return await FlutterBluePlus.adapterState.first ==
          BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  Future<void> startAdvertising() async {
    if (!await requestPermissions()) {
      throw Exception('Bluetooth permission denied');
    }

    if (!await isBluetoothAvailable()) {
      throw Exception('Bluetooth is turned off');
    }

    await _nativeChannel.invokeMethod<void>('startAdvertising');
  }

  Future<void> stopAdvertising() async {
    try {
      await _nativeChannel.invokeMethod<void>('stopAdvertising');
    } catch (_) {}

    _advertising = false;
  }

  Future<void> startScan() async {
    if (!await requestPermissions()) {
      throw Exception('Bluetooth permission denied');
    }

    if (!await isBluetoothAvailable()) {
      throw Exception('Bluetooth is turned off');
    }

    await stopScan();

    _devices.clear();
    _devicesController.add([]);

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final id = result.device.remoteId.str;

        if (id.isEmpty) continue;

        final serviceUuids = result.advertisementData.serviceUuids
            .map((uuid) => uuid.toString().toLowerCase())
            .toList();

        if (serviceUuids.contains(serviceUuid)) {
          _devices[id] = result;
        }
      }

      final sorted = _devices.values.toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));

      if (!_devicesController.isClosed) {
        _devicesController.add(sorted);
      }
    });

    await FlutterBluePlus.startScan(
      withServices: [Guid(serviceUuid)],
      timeout: const Duration(seconds: 10),
    );
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  Future<void> connectToDevice(ScanResult result) async {
    if (!await requestPermissions()) {
      throw Exception('Bluetooth permission denied');
    }

    await stopScan();

    final device = result.device;

    try {
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
        license: License.free,
      );
    } catch (error) {
      if (!error.toString().toLowerCase().contains('already connected')) {
        throw Exception('Connection failed: $error');
      }
    }

    _connectedDevice = device;

    try {
      final services = await device.discoverServices();

      BluetoothCharacteristic? target;

      for (final service in services) {
        if (service.uuid.toString().toLowerCase() != serviceUuid) {
          continue;
        }

        for (final characteristic in service.characteristics) {
          if (characteristic.uuid.toString().toLowerCase() ==
              characteristicUuid) {
            target = characteristic;
            break;
          }
        }

        if (target != null) break;
      }

      if (target == null) {
        throw Exception('Joruri Messenger service not found');
      }

      _characteristic = target;

      await _valueSubscription?.cancel();
      _valueSubscription = null;

      if (target.properties.notify || target.properties.indicate) {
        await target.setNotifyValue(true);

        _valueSubscription = target.lastValueStream.listen((value) {
          if (value.isEmpty || _messageController.isClosed) return;

          try {
            final message = utf8.decode(value);
            _messageController.add(message);
          } catch (_) {
            _connectionController.add('error:Invalid message encoding');
          }
        });
      }

      _connectionController.add('connected:${device.remoteId.str}');
    } catch (error) {
      await disconnect();
      rethrow;
    }
  }

  /// Sends through the client connection when available.
  /// Otherwise asks the native GATT server to notify its connected peer.
  Future<void> sendMessage(String message) async {
    if (message.isEmpty) return;

    final characteristic = _characteristic;
    final device = _connectedDevice;

    if (device != null && characteristic != null) {
      final data = utf8.encode(message);

      // A single GATT write may be limited by the negotiated MTU.
      if (data.length > 180) {
        throw Exception(
          'মেসেজটি খুব বড়। আপাতত ১৮০ বাইটের মধ্যে পাঠান।',
        );
      }

      if (characteristic.properties.write) {
        await characteristic.write(
          data,
          withoutResponse: false,
        );
        return;
      }

      if (characteristic.properties.writeWithoutResponse) {
        await characteristic.write(
          data,
          withoutResponse: true,
        );
        return;
      }

      throw Exception('এই সংযোগে মেসেজ পাঠানোর অনুমতি নেই');
    }

    if (_advertising) {
      await _nativeChannel.invokeMethod<void>(
        'sendMessage',
        <String, dynamic>{'message': message},
      );
      return;
    }

    throw Exception(
      'কোনো Bluetooth ফোন সংযুক্ত নেই। আগে ফোন খুঁজে সংযোগ করুন।',
    );
  }

  Future<void> disconnect() async {
    await _valueSubscription?.cancel();
    _valueSubscription = null;

    final device = _connectedDevice;

    _characteristic = null;
    _connectedDevice = null;

    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }

    _connectionController.add('disconnected');
  }

  /// Call only when the app-wide Bluetooth service is no longer needed.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await stopScan();
    await disconnect();
    await stopAdvertising();

    await _devicesController.close();
    await _messageController.close();
    await _connectionController.close();
  }
}
