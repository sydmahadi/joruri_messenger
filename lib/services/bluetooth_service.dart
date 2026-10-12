
import 'dart:async';
import 'dart:convert';
import 'dart:collection';

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
  final Map<String, StreamSubscription<List<int>>> _notificationSubs = {};
  final Map<String, StreamSubscription<BluetoothConnectionState>>
      _stateSubs = {};

  final Set<String> _approvedPeers = {};
  final Set<String> _pendingPeers = {};
  final Set<String> _seenMessageIds = {};

  final Queue<String> _relayQueue = Queue<String>();

  Stream<List<ScanResult>> get devicesStream =>
      _devicesController.stream;

  Stream<String> get messageStream => _messagesController.stream;

  Stream<String> get connectionStream => _connectionController.stream;

  bool _advertising = false;
  bool _disposed = false;
  bool _processingRelay = false;

  bool get isAdvertising => _advertising;

  bool get isConnected => _approvedPeers.isNotEmpty;

  int get connectedPeerCount => _approvedPeers.length;

  List<String> get connectedPeerAddresses =>
      List.unmodifiable(_approvedPeers);

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
        final value = call.arguments;
        if (value is String) {
          await _handleIncomingRaw(value, sourceAddress: 'native');
        } else if (value is Map) {
          final raw = value['message']?.toString();
          final address = value['address']?.toString() ?? 'native';
          if (raw != null) {
            await _handleIncomingRaw(raw, sourceAddress: address);
          }
        }
        break;

      case 'deviceConnected':
        final address = call.arguments?.toString() ?? '';
        if (address.isNotEmpty) {
          _connectionController.add('server_pending:$address');
        }
        break;

      case 'deviceDisconnected':
        final address = call.arguments?.toString() ?? '';
        _approvedPeers.remove(address);
        _pendingPeers.remove(address);
        _connectionController.add('peer_disconnected:$address');
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

  Future<void> startAdvertising() async {
    if (_disposed) return;

    if (!await requestPermissions()) {
      _connectionController.add(
        'error:Bluetooth permission denied',
      );
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
    } catch (_) {}

    _advertising = false;
  }

  Future<void> startScan() async {
    if (_disposed) return;

    if (!await requestPermissions()) {
      _connectionController.add(
        'error:Bluetooth permission denied',
      );
      return;
    }

    await stopScan();
    _devices.clear();
    _devicesController.add([]);

    try {
      await FlutterBluePlus.startScan(
        withServices: [serviceUuid],
        timeout: const Duration(seconds: 12),
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final index = _devices.indexWhere(
            (item) =>
                item.device.remoteId == result.device.remoteId,
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

  StreamSubscription<List<ScanResult>>? _scanSubscription;

  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    if (_disposed) return;

    if (!await requestPermissions()) {
      throw Exception('Bluetooth permission পাওয়া যায়নি');
    }

    final address = device.remoteId.str;

    if (_connectedDevices.containsKey(address)) {
      return;
    }

    try {
      await device.connect(
        timeout: const Duration(seconds: 20),
        license: License.free,
      );

      try {
        await device.requestMtu(247);
      } catch (_) {}

      final services = await device.discoverServices();

      BluetoothCharacteristic? found;

      for (final service in services) {
        if (service.uuid != serviceUuid) continue;

        for (final characteristic in service.characteristics) {
          if (characteristic.uuid == characteristicUuid) {
            found = characteristic;
            break;
          }
        }

        if (found != null) break;
      }

      if (found == null) {
        throw Exception('Bluetooth service পাওয়া যায়নি');
      }

      _connectedDevices[address] = device;
      _characteristics[address] = found;

      _stateSubs[address] = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _removePeer(address);
        }
      });

      _notificationSubs[address] = found.onValueReceived.listen((value) {
        if (value.isEmpty) return;

        final raw = utf8.decode(value, allowMalformed: true);
        _handleIncomingRaw(raw, sourceAddress: address);
      });

      await found.setNotifyValue(true);

      _pendingPeers.add(address);
      _connectionController.add('connection_pending:$address');
    } catch (e) {
      await _removePeer(address, disconnectDevice: true);
      _connectionController.add('error:$e');
      rethrow;
    }
  }

  Future<void> requestConnection({
    required String senderId,
    required String senderName,
  }) async {
    if (_connectedDevices.isEmpty) {
      throw Exception('প্রথমে কাছের ফোনে Connect করুন');
    }

    final request = jsonEncode({
      'type': 'connection_request',
      'senderId': senderId,
      'senderName': senderName,
      'createdAt': DateTime.now().toIso8601String(),
    });

    for (final address in _connectedDevices.keys.toList()) {
      await _writeToPeer(address, request);
    }

    _connectionController.add('connection_request_sent');
  }

  Future<void> respondToConnectionRequest({
    required bool accepted,
    required String requesterId,
  }) async {
    final response = jsonEncode({
      'type': accepted
          ? 'connection_accepted'
          : 'connection_rejected',
      'requesterId': requesterId,
      'createdAt': DateTime.now().toIso8601String(),
    });

    var sent = false;

    for (final address in _connectedDevices.keys.toList()) {
      try {
        await _writeToPeer(address, response);
        if (accepted) {
          _approvedPeers.add(address);
          _pendingPeers.remove(address);
        } else {
          _pendingPeers.remove(address);
        }
        sent = true;
      } catch (_) {}
    }

    if (!sent) {
      try {
        final result = await _nativeChannel.invokeMethod<bool>(
          'sendMessage',
          {'message': response},
        );
        sent = result == true;
      } catch (_) {}
    }

    if (!sent) {
      throw Exception('উত্তর পাঠানো যায়নি');
    }

    _connectionController.add(
      accepted ? 'connection_accepted' : 'connection_rejected',
    );
  }

  Future<void> _writeToPeer(String address, String raw) async {
    final characteristic = _characteristics[address];

    if (characteristic == null) {
      throw Exception('এই ফোনের Bluetooth সংযোগ নেই');
    }

    final bytes = utf8.encode(raw);

    if (bytes.length > 480) {
      throw Exception('মেসেজ অনেক বড়। ছোট মেসেজ পাঠান');
    }

    await characteristic.write(
      bytes,
      withoutResponse: false,
      timeout: 15,
    );
  }

  Future<void> sendMessage(String raw) async {
    if (_disposed) {
      throw Exception('Bluetooth service বন্ধ আছে');
    }

    final decoded = jsonDecode(raw);

    if (decoded is! Map) {
      throw Exception('মেসেজের ফরম্যাট সঠিক নয়');
    }

    final type = decoded['type']?.toString();

    if (type == 'connection_request' ||
        type == 'connection_accepted' ||
        type == 'connection_rejected') {
      await _broadcast(raw);
      return;
    }

    final messageId = decoded['id']?.toString();

    if (messageId != null && messageId.isNotEmpty) {
      _seenMessageIds.add(messageId);
    }

    if (_approvedPeers.isEmpty) {
      try {
        final sent = await _nativeChannel.invokeMethod<bool>(
          'sendMessage',
          {'message': raw},
        );

        if (sent == true) return;
      } catch (_) {}

      throw Exception('অনুমোদিত Mesh সংযোগ নেই');
    }

    await _broadcast(raw);
  }

  Future<void> _broadcast(
    String raw, {
    String? excludeAddress,
  }) async {
    final addresses = _approvedPeers.toList();
    var successCount = 0;

    for (final address in addresses) {
      if (address == excludeAddress) continue;

      try {
        await _writeToPeer(address, raw);
        successCount++;
      } catch (e) {
        _connectionController.add('peer_send_error:$address:$e');
      }
    }

    if (successCount == 0 && excludeAddress == null) {
      try {
        final sent = await _nativeChannel.invokeMethod<bool>(
          'sendMessage',
          {'message': raw},
        );

        if (sent == true) return;
      } catch (_) {}

      throw Exception('কোনো সংযুক্ত ফোনে মেসেজ পাঠানো যায়নি');
    }
  }

  Future<void> _handleIncomingRaw(
    String raw, {
    required String sourceAddress,
  }) async {
    Map<String, dynamic>? decoded;

    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic>) {
        decoded = value;
      }
    } catch (_) {}

    if (decoded == null) {
      if (!_messagesController.isClosed) {
        _messagesController.add(raw);
      }
      return;
    }

    final type = decoded['type']?.toString();

    if (type == 'connection_request') {
      _pendingPeers.add(sourceAddress);
      if (!_messagesController.isClosed) {
        _messagesController.add(raw);
      }
      _connectionController.add('connection_request_received');
      return;
    }

    if (type == 'connection_accepted') {
      if (sourceAddress != 'native') {
        _approvedPeers.add(sourceAddress);
        _pendingPeers.remove(sourceAddress);
      }
      _connectionController.add('connection_accepted');
      return;
    }

    if (type == 'connection_rejected') {
      _pendingPeers.remove(sourceAddress);
      _connectionController.add('connection_rejected');
      return;
    }

    final id = decoded['id']?.toString();

    if (id == null || id.isEmpty) {
      if (!_messagesController.isClosed) {
        _messagesController.add(raw);
      }
      return;
    }

    if (_seenMessageIds.contains(id)) {
      return;
    }

    _seenMessageIds.add(id);

    // Limit memory use for duplicate detection.
    if (_seenMessageIds.length > 2000) {
      _seenMessageIds.clear();
      _seenMessageIds.add(id);
    }

    final hopCount =
        int.tryParse(decoded['hopCount']?.toString() ?? '') ?? 0;
    final maxHops =
        int.tryParse(decoded['maxHops']?.toString() ?? '') ?? 5;

    if (!_messagesController.isClosed) {
      _messagesController.add(raw);
    }

    if (hopCount >= maxHops) return;

    final forwarded = Map<String, dynamic>.from(decoded);
    forwarded['hopCount'] = hopCount + 1;

    _relayQueue.add(jsonEncode(forwarded));
    _processRelayQueue(sourceAddress);
  }

  Future<void> _processRelayQueue(String sourceAddress) async {
    if (_processingRelay) return;

    _processingRelay = true;

    try {
      while (_relayQueue.isNotEmpty) {
        final raw = _relayQueue.removeFirst();
        await _broadcast(raw, excludeAddress: sourceAddress);
      }
    } finally {
      _processingRelay = false;
    }
  }

  Future<void> _removePeer(
    String address, {
    bool disconnectDevice = false,
  }) async {
    await _notificationSubs.remove(address)?.cancel();
    await _stateSubs.remove(address)?.cancel();

    final device = _connectedDevices.remove(address);
    _characteristics.remove(address);
    _approvedPeers.remove(address);
    _pendingPeers.remove(address);

    if (disconnectDevice && device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }

    _connectionController.add('peer_disconnected:$address');
  }

  Future<void> disconnect() async {
    final addresses = _connectedDevices.keys.toList();

    for (final address in addresses) {
      await _removePeer(address, disconnectDevice: true);
    }

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
