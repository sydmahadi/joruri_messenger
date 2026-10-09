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

  // Client ফোনের অনুমোদনের অবস্থা।
  bool _connectionApproved = false;

  // Server ফোনের অনুমোদনের অবস্থা।
  bool _serverConnectionApproved = false;

  String? _pendingRequesterId;
  String? _serverConnectedAddress;

  Stream<List<ScanResult>> get devicesStream =>
      _devicesController.stream;

  Stream<String> get messageStream => _messageController.stream;

  Stream<String> get connectionStream => _connectionController.stream;

  BluetoothDevice? get connectedDevice => _connectedDevice;

  bool get isConnected =>
      (_connectedDevice != null && _connectionApproved) ||
      _serverConnectionApproved;

  bool get isConnectionPending =>
      (_connectedDevice != null && !_connectionApproved) ||
      (_serverConnectedAddress != null &&
          !_serverConnectionApproved);

  bool get isAdvertising => _advertising;

  Future<void> _handleNativeMethod(MethodCall call) async {
    switch (call.method) {
      case 'messageReceived':
        _handleIncomingRaw(call.arguments?.toString() ?? '');
        break;

      case 'deviceConnected':
        _serverConnectedAddress = call.arguments?.toString() ?? '';
        _serverConnectionApproved = false;
        _pendingRequesterId = null;

        _connectionController.add(
          'server_pending:$_serverConnectedAddress',
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
        _connectionController.add('message_sent');
        break;

      case 'bluetoothError':
        final error = call.arguments?.toString() ?? 'Bluetooth error';
        _connectionController.add('error:$error');
        break;
    }
  }

  void _handleIncomingRaw(String raw) {
    if (raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map) {
        final data = Map<String, dynamic>.from(decoded);
        final type = data['type']?.toString();

        if (type == 'connection_accepted') {
          final requesterId = data['requesterId']?.toString();

          if (requesterId == null ||
              requesterId == _localRequesterId) {
            _connectionApproved = true;
            _connectionController.add('connection_accepted');
          }
          return;
        }

        if (type == 'connection_rejected') {
          final requesterId = data['requesterId']?.toString();

          if (requesterId == null ||
              requesterId == _localRequesterId) {
            _connectionApproved = false;
            _connectionController.add('connection_rejected');
          }
          return;
        }

        if (type == 'connection_request') {
          _pendingRequesterId = data['senderId']?.toString();
        }
      }
    } catch (_) {
      // সাধারণ চ্যাট মেসেজ হলে নিচে পাঠানো হবে।
    }

    if (!_messageController.isClosed) {
      _messageController.add(raw);
    }
  }

  // সংযোগের অনুরোধকারী ফোনের ID।
  String? _localRequesterId;

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
      throw Exception('Bluetooth বন্ধ আছে');
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
      throw Exception('Bluetooth বন্ধ আছে');
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
    _connectionApproved = false;

    try {
      final services = await device.discoverServices();

      BluetoothCharacteristic? target;

      for (final service in services) {
        if (service.uuid.toString().toLowerCase() != serviceUuid) {
          continue;
        }

        for (final item in service.characteristics) {
          if (item.uuid.toString().toLowerCase() ==
              characteristicUuid) {
            target = item;
            break;
          }
        }

        if (target != null) break;
      }

      if (target == null) {
        throw Exception('Joruri Messenger service পাওয়া যায়নি');
      }

      _characteristic = target;

      await _valueSubscription?.cancel();
      _valueSubscription = null;

      if (target.properties.notify || target.properties.indicate) {
        await target.setNotifyValue(true);

        _valueSubscription = target.lastValueStream.listen((value) {
          if (value.isEmpty) return;

          try {
            _handleIncomingRaw(utf8.decode(value));
          } catch (_) {
            _connectionController.add('error:Invalid message encoding');
          }
        });
      }

      _connectionController.add(
        'connection_pending:${device.remoteId.str}',
      );
    } catch (error) {
      await disconnect();
      rethrow;
    }
  }

  // অন্য ফোনে সংযোগের অনুরোধ পাঠাবে।
  Future<void> requestConnection({
    required String senderId,
    required String senderName,
  }) async {
    final characteristic = _characteristic;

    if (_connectedDevice == null || characteristic == null) {
      throw Exception('আগে একটি ফোন নির্বাচন করুন');
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

  // গ্রহণ বা প্রত্যাখ্যানের উত্তর server ফোন থেকে পাঠাবে।
  Future<void> respondToConnectionRequest({
    required bool accepted,
    required String requesterId,
  }) async {
    if (_serverConnectedAddress == null) {
      throw Exception('অনুরোধকারী ফোন সংযুক্ত নেই');
    }

    final response = jsonEncode({
      'type': accepted
          ? 'connection_accepted'
          : 'connection_rejected',
      'requesterId': requesterId,
      'createdAt': DateTime.now().toIso8601String(),
    });

    // Native sendMessage server-এর connected peer-কে notify করে।
    await _nativeChannel.invokeMethod<void>(
      'sendMessage',
      <String, dynamic>{'message': response},
    );

    if (accepted) {
      _serverConnectionApproved = true;
      _connectionController.add('connection_accepted');
    } else {
      _serverConnectionApproved = false;
      _connectionController.add('connection_rejected');
    }
  }

  Future<void> _writeToConnectedDevice(String message) async {
    final characteristic = _characteristic;

    if (characteristic == null) {
      throw Exception('Bluetooth characteristic পাওয়া যায়নি');
    }

    final data = utf8.encode(message);

    if (data.length > 180) {
      throw Exception('মেসেজটি খুব বড়।');
    }

    if (characteristic.properties.write) {
      await characteristic.write(data, withoutResponse: false);
      return;
    }

    if (characteristic.properties.writeWithoutResponse) {
      await characteristic.write(data, withoutResponse: true);
      return;
    }

    throw Exception('এই সংযোগে মেসেজ পাঠানো যাচ্ছে না');
  }

  Future<void> sendMessage(String message) async {
    if (message.isEmpty) return;

    if (!isConnected) {
      throw Exception(
        'সংযোগ এখনো অনুমোদিত হয়নি। অন্য ফোনে অনুরোধ গ্রহণ করতে হবে।',
      );
    }

    if (_connectedDevice != null && _characteristic != null) {
      await _writeToConnectedDevice(message);
      return;
    }

    if (_advertising && _serverConnectionApproved) {
      await _nativeChannel.invokeMethod<void>(
        'sendMessage',
        <String, dynamic>{'message': message},
      );
      return;
    }

    throw Exception('অনুমোদিত Bluetooth সংযোগ পাওয়া যায়নি');
  }

  Future<void> disconnect() async {
    await _valueSubscription?.cancel();
    _valueSubscription = null;

    final device = _connectedDevice;

    _characteristic = null;
    _connectedDevice = null;
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
    await _messageController.close();
    await _connectionController.close();
  }
}
