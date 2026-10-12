import 'dart:async';
import 'dart:collection';
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

  final Map<String, StreamSubscription<List<int>>> _notificationSubs = {};
  final Map<String, StreamSubscription<BluetoothConnectionState>>
      _stateSubs = {};

  final Set<String> _approvedPeers = {};
  final Set<String> _pendingPeers = {};
  final Set<String> _nativeConnectedAddresses = {};
  final Set<String> _seenMessageIds = {};

  // Connection request ID -> actual source address.
  final Map<String, String> _pendingRequesterAddresses = {};

  final Queue<String> _relayQueue = Queue<String>();

  StreamSubscription<List<ScanResult>>? _scanSubscription;

  Stream<List<ScanResult>> get devicesStream => _devicesController.stream;
  Stream<String> get messageStream => _messagesController.stream;
  Stream<String> get connectionStream => _connectionController.stream;

  bool _advertising = false;
  bool _disposed = false;
  bool _processingRelay = false;
  bool _initialized = false;

  bool get isAdvertising => _advertising;

  bool get isConnected =>
      _approvedPeers.isNotEmpty ||
      _nativeConnectedAddresses.any(_approvedPeers.contains);

  // Compatibility with main.dart.
  int get connectedDeviceCount => _approvedPeers.length;

  // Compatibility with bluetooth_devices_screen.dart.
  List<String> get connectedDeviceAddresses =>
      List.unmodifiable(_approvedPeers);

  // Keep the existing names working too.
  int get connectedPeerCount => connectedDeviceCount;

  List<String> get connectedPeerAddresses => connectedDeviceAddresses;

  Future<void> initialize() async {
    if (_disposed) {
      throw StateError('BluetoothService বন্ধ করা হয়েছে');
    }

    if (_initialized) return;

    _nativeChannel.setMethodCallHandler(_handleNativeMethod);
    _initialized = true;

    // Advertising failure should not prevent the app from opening.
    try {
      await startAdvertising();
    } catch (e) {
      _connectionController.add('error:$e');
    }
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
      final supported = await FlutterBluePlus.isSupported;
      if (!supported) return false;

      return await FlutterBluePlus.adapterState.first ==
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
            await _handleIncomingRaw(
              raw,
              sourceAddress: address,
            );
          }
        }
        break;

      case 'deviceConnected':
        final address = call.arguments?.toString() ?? '';

        if (address.isNotEmpty) {
          _nativeConnectedAddresses.add(address);
          _connectionController.add('server_pending:$address');
        }
        break;

      case 'deviceDisconnected':
        final address = call.arguments?.toString() ?? '';

        _nativeConnectedAddresses.remove(address);
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
      _connectionController.add('error:Bluetooth permission denied');
      return;
    }

    _nativeChannel.setMethodCallHandler(_handleNativeMethod);

    try {
      final result =
          await _nativeChannel.invokeMethod<bool>('startAdvertising');

      _advertising = result ?? true;
    } catch (e) {
      _advertising = false;
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
      _connectionController.add('error:Bluetooth permission denied');
      return;
    }

    await stopScan();
    _devices.clear();

    if (!_devicesController.isClosed) {
      _devicesController.add([]);
    }

    try {
      // Subscribe before starting the scan to avoid missing early results.
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
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
        },
        onError: (Object error) {
          _connectionController.add('error:$error');
        },
      );

      await FlutterBluePlus.startScan(
        withServices: [serviceUuid],
        timeout: const Duration(seconds: 12),
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

    if (!await requestPermissions()) {
      throw Exception('Bluetooth permission পাওয়া যায়নি');
    }

    final address = device.remoteId.str;

    if (_connectedDevices.containsKey(address)) return;

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

      _notificationSubs[address] = found.onValueReceived.listen(
        (value) {
          if (value.isEmpty) return;

          final raw = utf8.decode(value, allowMalformed: true);

          _handleIncomingRaw(
            raw,
            sourceAddress: address,
          );
        },
        onError: (Object error) {
          _connectionController.add('peer_receive_error:$address:$error');
        },
      );

      await found.setNotifyValue(true);

      _pendingPeers.add(address);
      _connectionController.add('connection_pending:$address');
    } catch (e) {
      await _removePeer(address, disconnectDevice: true);
      _connectionController.add('error:$e');
      rethrow;
    }
  }

  // Optional deviceAddress allows the device screen to target one phone.
  Future<void> requestConnection({
    String? deviceAddress,
    required String senderId,
    required String senderName,
  }) async {
    final addresses = deviceAddress == null
        ? _connectedDevices.keys.toList()
        : <String>[deviceAddress];

    final request = jsonEncode({
      'type': 'connection_request',
      'senderId': senderId,
      'senderName': senderName,
      'createdAt': DateTime.now().toIso8601String(),
    });

    var sent = false;

    for (final address in addresses) {
      try {
        if (_characteristics.containsKey(address)) {
          await _writeToPeer(address, request);
          sent = true;
        } else if (_nativeConnectedAddresses.contains(address)) {
          final result = await _nativeChannel.invokeMethod<bool>(
            'sendMessage',
            {
              'message': request,
              'targetAddress': address,
            },
          );
          sent = sent || result == true;
        }
      } catch (e) {
        _connectionController.add('peer_send_error:$address:$e');
      }
    }

    if (!sent) {
      throw Exception('কোনো ফোনে সংযোগের অনুরোধ পাঠানো যায়নি');
    }

    _connectionController.add('connection_request_sent');
  }

  Future<void> respondToConnectionRequest({
    required bool accepted,
    required String requesterId,
  }) async {
    final sourceAddress =
        _pendingRequesterAddresses[requesterId];

    if (sourceAddress == null) {
      throw Exception('অনুরোধকারী ফোনের ঠিকানা পাওয়া যায়নি');
    }

    final response = jsonEncode({
      'type': accepted
          ? 'connection_accepted'
          : 'connection_rejected',
      'requesterId': requesterId,
      'createdAt': DateTime.now().toIso8601String(),
    });

    var sent = false;

    try {
      if (_characteristics.containsKey(sourceAddress)) {
        await _writeToPeer(sourceAddress, response);
        sent = true;
      } else if (sourceAddress == 'native' ||
          _nativeConnectedAddresses.contains(sourceAddress)) {
        final args = <String, dynamic>{'message': response};

        if (sourceAddress != 'native') {
          args['targetAddress'] = sourceAddress;
        }

        final result = await _nativeChannel.invokeMethod<bool>(
          'sendMessage',
          args,
        );

        sent = result == true;
      }
    } catch (e) {
      _connectionController.add('error:$e');
    }

    if (!sent) {
      throw Exception('উত্তর পাঠানো যায়নি');
    }

    if (accepted) {
      _approvedPeers.add(sourceAddress);
      _pendingPeers.remove(sourceAddress);
    } else {
      _pendingPeers.remove(sourceAddress);
    }

    _pendingRequesterAddresses.remove(requesterId);

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

    final decodedValue = jsonDecode(raw);

    if (decodedValue is! Map) {
      throw Exception('মেসেজের ফরম্যাট সঠিক নয়');
    }

    final type = decodedValue['type']?.toString();

    if (type == 'connection_request' ||
        type == 'connection_accepted' ||
        type == 'connection_rejected') {
      await _broadcast(raw);
      return;
    }

    final messageId = decodedValue['id']?.toString();

    if (messageId != null && messageId.isNotEmpty) {
      _seenMessageIds.add(messageId);
    }

    if (_approvedPeers.isEmpty) {
      final sent = await _sendNative(raw);

      if (sent) return;

      throw Exception('অনুমোদিত Bluetooth সংযোগ নেই');
    }

    await _broadcast(raw);
  }

  Future<bool> _sendNative(
    String raw, {
    String? targetAddress,
  }) async {
    try {
      final args = <String, dynamic>{'message': raw};

      if (targetAddress != null) {
        args['targetAddress'] = targetAddress;
      }

      return await _nativeChannel.invokeMethod<bool>(
            'sendMessage',
            args,
          ) ==
          true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _broadcast(
    String raw, {
    String? excludeAddress,
  }) async {
    var successCount = 0;

    final addresses = _approvedPeers.toList();

    for (final address in addresses) {
      if (address == excludeAddress) continue;

      try {
        if (_characteristics.containsKey(address)) {
          await _writeToPeer(address, raw);
          successCount++;
        } else if (_nativeConnectedAddresses.contains(address)) {
          if (await _sendNative(raw, targetAddress: address)) {
            successCount++;
          }
        }
      } catch (e) {
        _connectionController.add('peer_send_error:$address:$e');
      }
    }

    // Use the native channel only when broadcasting normally.
    if (successCount == 0 && excludeAddress == null) {
      if (await _sendNative(raw)) return;

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

      if (value is Map) {
        decoded = Map<String, dynamic>.from(value);
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
      final requesterId = decoded['senderId']?.toString();

      _pendingPeers.add(sourceAddress);

      if (requesterId != null && requesterId.isNotEmpty) {
        _pendingRequesterAddresses[requesterId] = sourceAddress;
      }

      if (!_messagesController.isClosed) {
        _messagesController.add(raw);
      }

      _connectionController.add('connection_request_received');
      return;
    }

    if (type == 'connection_accepted') {
      final requesterId = decoded['requesterId']?.toString();

      if (sourceAddress != 'native') {
        _approvedPeers.add(sourceAddress);
        _pendingPeers.remove(sourceAddress);
      }

      if (requesterId != null) {
        _pendingRequesterAddresses.remove(requesterId);
      }

      _connectionController.add('connection_accepted');
      return;
    }

    if (type == 'connection_rejected') {
      final requesterId = decoded['requesterId']?.toString();

      _pendingPeers.remove(sourceAddress);

      if (requesterId != null) {
        _pendingRequesterAddresses.remove(requesterId);
      }

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

    if (_seenMessageIds.contains(id)) return;

    _seenMessageIds.add(id);

    // Bound the in-memory duplicate cache.
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
    await _processRelayQueue(sourceAddress);
  }

  Future<void> _processRelayQueue(String sourceAddress) async {
    if (_processingRelay) return;

    _processingRelay = true;

    try {
      while (_relayQueue.isNotEmpty) {
        final raw = _relayQueue.removeFirst();

        try {
          await _broadcast(raw, excludeAddress: sourceAddress);
        } catch (_) {
          // A failed relay must not stop later queued messages.
        }
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
    _nativeConnectedAddresses.remove(address);

    _pendingRequesterAddresses.removeWhere(
      (_, savedAddress) => savedAddress == address,
    );

    if (disconnectDevice && device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }

    _connectionController.add('peer_disconnected:$address');
  }

  // Compatibility with bluetooth_devices_screen.dart.
  Future<void> disconnectDevice(String address) async {
    if (_connectedDevices.containsKey(address)) {
      await _removePeer(address, disconnectDevice: true);
      return;
    }

    if (_nativeConnectedAddresses.contains(address)) {
      try {
        await _nativeChannel.invokeMethod<bool>(
          'disconnectDevice',
          {'address': address},
        );
      } catch (_) {
        // The current native implementation may not expose this method.
      }

      _nativeConnectedAddresses.remove(address);
      _approvedPeers.remove(address);
      _pendingPeers.remove(address);

      _connectionController.add('peer_disconnected:$address');
      return;
    }

    _approvedPeers.remove(address);
    _pendingPeers.remove(address);
  }

  Future<void> disconnect() async {
    final addresses = _connectedDevices.keys.toList();

    for (final address in addresses) {
      await _removePeer(address, disconnectDevice: true);
    }

    _approvedPeers.clear();
    _pendingPeers.clear();
    _pendingRequesterAddresses.clear();

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
