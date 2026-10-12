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

  final Map<String, BluetoothDevice> _connectedDevices = {};
  final Map<String, BluetoothCharacteristic> _characteristics = {};
  final Map<String, bool> _approvedDevices = {};
  final Map<String, String> _requesterIdsByAddress = {};

  final Map<String, StreamSubscription<List<int>>>
      _notificationSubscriptions = {};

  final Map<String, StreamSubscription<BluetoothConnectionState>>
      _stateSubscriptions = {};

  final Set<String> _approvedServerAddresses = {};
  final Map<String, String> _serverRequesterIdsByAddress = {};

  StreamSubscription<List<ScanResult>>? _scanSubscription;

  bool _advertising = false;
  bool _disposed = false;
  bool _sending = false;
  bool _initialized = false;

  String? _pendingRequesterId;
  String? _serverConnectedAddress;

  Stream<List<ScanResult>> get devicesStream => _devicesController.stream;

  Stream<String> get messageStream => _messagesController.stream;

  Stream<String> get connectionStream => _connectionController.stream;

  bool get isAdvertising => _advertising;

  bool get isConnected =>
      _approvedDevices.values.any((approved) => approved) ||
      _approvedServerAddresses.isNotEmpty;

  int get connectedDeviceCount =>
      _approvedDevices.values.where((approved) => approved).length +
      _approvedServerAddresses.length;

  List<String> get connectedDeviceAddresses =>
      List.unmodifiable(_approvedDevices.keys);

  Future<void> initialize() async {
    if (_disposed || _initialized) return;

    _nativeChannel.setMethodCallHandler(_handleNativeMethod);
    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    try {
      final results = await <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
      ].request();

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
        final address = call.arguments?.toString() ?? '';
        if (address.isNotEmpty) {
          _serverConnectedAddress = address;
          _serverRequesterIdsByAddress.putIfAbsent(address, () => '');
          _connectionController.add('server_pending:$address');
        }
        break;

      case 'deviceDisconnected':
        final address = call.arguments?.toString() ?? '';

        if (address.isNotEmpty) {
          _approvedServerAddresses.remove(address);
          _serverRequesterIdsByAddress.remove(address);
          _connectionController.add('server_disconnected:$address');
        } else {
          _approvedServerAddresses.clear();
          _serverRequesterIdsByAddress.clear();
          _connectionController.add('server_disconnected');
        }

        _serverConnectedAddress =
            _serverRequesterIdsByAddress.keys.isEmpty
                ? null
                : _serverRequesterIdsByAddress.keys.last;
        break;

      case 'advertisingStarted':
        _advertising = true;
        _connectionController.add('advertising_started');
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
          final requesterId = decoded['senderId']?.toString() ?? '';
          final senderAddress = decoded['senderAddress']?.toString();

          _pendingRequesterId = requesterId;

          if (senderAddress != null && senderAddress.isNotEmpty) {
            _serverRequesterIdsByAddress[senderAddress] = requesterId;
          }

          if (!_messagesController.isClosed) {
            _messagesController.add(raw);
          }

          _connectionController.add('connection_request_received');
          return;
        }

        if (type == 'connection_accepted') {
          final requesterId = decoded['requesterId']?.toString();

          for (final entry in _requesterIdsByAddress.entries) {
            if (requesterId == null || entry.value == requesterId) {
              _approvedDevices[entry.key] = true;
              _connectionController.add('connection_accepted');
            }
          }
          return;
        }

        if (type == 'connection_rejected') {
          final requesterId = decoded['requesterId']?.toString();

          for (final entry in _requesterIdsByAddress.entries) {
            if (requesterId == null || entry.value == requesterId) {
              _approvedDevices[entry.key] = false;
              _connectionController.add('connection_rejected');
            }
          }
          return;
        }
      }
    } catch (_) {
      // সাধারণ টেক্সট মেসেজ।
    }

    if (!_messagesController.isClosed) {
      _messagesController.add(raw);
    }
  }

  Future<void> startAdvertising() async {
    if (_disposed) return;

    await initialize();

    final permitted = await requestPermissions();

    if (!permitted) {
      _connectionController.add('error:Bluetooth permission denied');
      return;
    }

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
    } catch (_) {}

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

    if (!_devicesController.isClosed) {
      _devicesController.add(List.unmodifiable(_devices));
    }

    try {
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

      await FlutterBluePlus.startScan(
        withServices: [serviceUuid],
        timeout: const Duration(seconds: 10),
      );
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

    final address = device.remoteId.str;

    if (_connectedDevices.containsKey(address)) {
      _connectionController.add('already_connected:$address');
      return;
    }

    final permitted = await requestPermissions();

    if (!permitted) {
      throw Exception('Bluetooth permission দিন।');
    }

    _connectedDevices[address] = device;
    _approvedDevices[address] = false;

    try {
      await device.connect(
        timeout: const Duration(seconds: 15),
        license: License.free,
      );

      try {
        await device.requestMtu(512);
      } catch (_) {}

      await _stateSubscriptions.remove(address)?.cancel();

      _stateSubscriptions[address] = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _removeDevice(address, disconnectDevice: false);
          _connectionController.add('disconnected:$address');
        }
      });

      final services = await device.discoverServices();

      BluetoothCharacteristic? found;

      for (final service in services) {
        if (service.uuid == serviceUuid) {
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid == characteristicUuid) {
              found = characteristic;
              break;
            }
          }
        }

        if (found != null) break;
      }

      if (found == null) {
        throw Exception('প্রয়োজনীয় Bluetooth service পাওয়া যায়নি।');
      }

      _characteristics[address] = found;

      await _notificationSubscriptions.remove(address)?.cancel();

      _notificationSubscriptions[address] = found.onValueReceived.listen(
        (value) {
          if (value.isNotEmpty) {
            _handleIncomingRaw(utf8.decode(value, allowMalformed: true));
          }
        },
      );

      await found.setNotifyValue(true);

      _connectionController.add('connection_pending:$address');
    } catch (e) {
      await _removeDevice(address, disconnectDevice: true);
      _connectionController.add('error:$e');
      rethrow;
    }
  }

  Future<void> requestConnection({
    required String senderId,
    required String senderName,
    String? deviceAddress,
  }) async {
    final address = deviceAddress ??
        (_connectedDevices.length == 1
            ? _connectedDevices.keys.first
            : null);

    if (address == null ||
        !_connectedDevices.containsKey(address) ||
        !_characteristics.containsKey(address)) {
      throw Exception('যে ফোনে সংযোগ করবেন সেটি নির্বাচন করুন।');
    }

    _requesterIdsByAddress[address] = senderId;
    _approvedDevices[address] = false;

    final request = jsonEncode({
      'type': 'connection_request',
      'senderId': senderId,
      'senderName': senderName,
      'createdAt': DateTime.now().toIso8601String(),
    });

    await _writeToDevice(address, request);
    _connectionController.add('connection_request_sent:$address');
  }

  Future<void> respondToConnectionRequest({
    required bool accepted,
    required String requesterId,
  }) async {
    final response = jsonEncode({
      'type': accepted ? 'connection_accepted' : 'connection_rejected',
      'requesterId': requesterId,
      'createdAt': DateTime.now().toIso8601String(),
    });

    final sent = await _nativeChannel.invokeMethod<bool>(
      'sendMessage',
      {
        'message': response,
        'requesterId': requesterId,
      },
    );

    if (sent != true) {
      throw Exception('উত্তর পাঠানো যায়নি। আবার চেষ্টা করুন।');
    }

    if (accepted) {
      final address = _serverRequesterIdsByAddress.entries
          .where((entry) => entry.value == requesterId)
          .map((entry) => entry.key)
          .firstOrNull;

      if (address != null) {
        _approvedServerAddresses.add(address);
      }
    } else {
      _approvedServerAddresses.removeWhere(
        (address) => _serverRequesterIdsByAddress[address] == requesterId,
      );
    }

    if (_pendingRequesterId == requesterId) {
      _pendingRequesterId = null;
    }

    _connectionController.add(
      accepted ? 'connection_accepted' : 'connection_rejected',
    );
  }

  Future<void> _writeToDevice(String address, String message) async {
    final characteristic = _characteristics[address];

    if (characteristic == null) {
      throw Exception('Bluetooth সংযোগ পাওয়া যায়নি।');
    }

    final payload = utf8.encode(message);

    if (payload.length > 509) {
      throw Exception('মেসেজটি অনেক বড়। আপাতত ছোট মেসেজ পাঠান।');
    }

    await characteristic.write(
      payload,
      withoutResponse: false,
      timeout: 15,
    );
  }

  Future<void> sendMessage(String message) async {
    if (_disposed) {
      throw Exception('Bluetooth service বন্ধ আছে।');
    }

    if (_sending) {
      throw Exception('আগের মেসেজটি পাঠানো হচ্ছে। একটু অপেক্ষা করুন।');
    }

    final outgoing = _approvedDevices.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (outgoing.isEmpty && _approvedServerAddresses.isEmpty) {
      throw Exception('কোনো অনুমোদিত Bluetooth সংযোগ নেই।');
    }

    _sending = true;

    try {
      var sentCount = 0;

      for (final address in outgoing) {
        try {
          await _writeToDevice(address, message);
          sentCount++;
        } catch (error) {
          debugPrint('Send to $address failed: $error');
          _approvedDevices[address] = false;
        }
      }

      if (_approvedServerAddresses.isNotEmpty) {
        try {
          final sent = await _nativeChannel.invokeMethod<bool>(
            'sendMessage',
            {'message': message},
          );

          if (sent == true) sentCount++;
        } catch (error) {
          debugPrint('Native broadcast failed: $error');
        }
      }

      if (sentCount == 0) {
        throw Exception('কোনো ফোনে মেসেজ পাঠানো যায়নি।');
      }
    } finally {
      _sending = false;
    }
  }

  Future<void> _removeDevice(
    String address, {
    required bool disconnectDevice,
  }) async {
    await _notificationSubscriptions.remove(address)?.cancel();
    await _stateSubscriptions.remove(address)?.cancel();

    final device = _connectedDevices.remove(address);

    _characteristics.remove(address);
    _approvedDevices.remove(address);
    _requesterIdsByAddress.remove(address);

    if (disconnectDevice && device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
  }

  Future<void> disconnectDevice(String address) async {
    await _removeDevice(address, disconnectDevice: true);
    _connectionController.add('disconnected:$address');
  }

  Future<void> disconnect() async {
    final addresses = _connectedDevices.keys.toList();

    for (final address in addresses) {
      await _removeDevice(address, disconnectDevice: true);
    }

    _approvedServerAddresses.clear();
    _serverRequesterIdsByAddress.clear();
    _serverConnectedAddress = null;
    _pendingRequesterId = null;

    _connectionController.add('disconnected');
  }

  Future<void> dispose() async {
    if (_disposed) return;

    await stopScan();
    await disconnect();
    await stopAdvertising();

    _disposed = true;

    await _devicesController.close();
    await _messagesController.close();
    await _connectionController.close();
  }
}
