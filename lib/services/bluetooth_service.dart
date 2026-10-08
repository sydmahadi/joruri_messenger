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

  StreamSubscription<List<ScanResult>>? _scanSubscription;

  final StreamController<List<ScanResult>> _devicesController =
      StreamController<List<ScanResult>>.broadcast();

  final StreamController<String> _messageController =
      StreamController<String>.broadcast();

  final StreamController<String> _connectionController =
      StreamController<String>.broadcast();

  final Map<String, ScanResult> _devices = {};

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _characteristic;

  Stream<List<ScanResult>> get devicesStream =>
      _devicesController.stream;

  Stream<String> get messageStream =>
      _messageController.stream;

  Stream<String> get connectionStream =>
      _connectionController.stream;

  BluetoothDevice? get connectedDevice =>
      _connectedDevice;

  bool get isConnected =>
      _connectedDevice != null;

  BluetoothService() {
    _nativeChannel.setMethodCallHandler(
      _handleNativeMethod,
    );
  }

  Future<void> _handleNativeMethod(
    MethodCall call,
  ) async {
    switch (call.method) {
      case 'messageReceived':
        final message =
            call.arguments?.toString() ?? '';

        if (message.isNotEmpty) {
          _messageController.add(message);
        }
        break;

      case 'deviceConnected':
        final address =
            call.arguments?.toString() ?? '';

        _connectionController.add(
          'connected:$address',
        );
        break;

      case 'deviceDisconnected':
        final address =
            call.arguments?.toString() ?? '';

        _connectionController.add(
          'disconnected:$address',
        );
        break;

      case 'advertisingStarted':
        _connectionController.add(
          'advertising_started',
        );
        break;

      case 'bluetoothError':
        final error =
            call.arguments?.toString() ??
                'Bluetooth error';

        _connectionController.add(
          'error:$error',
        );
        break;
    }
  }

  Future<bool> requestPermissions() async {
    final permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ];

    final result =
        await permissions.request();

    return result.values.every(
      (status) => status.isGranted,
    );
  }

  Future<bool> isBluetoothAvailable() async {
    try {
      final state =
          await FlutterBluePlus.adapterState.first;

      return state ==
          BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  Future<void> startAdvertising() async {
    final permissionGranted =
        await requestPermissions();

    if (!permissionGranted) {
      throw Exception(
        'Bluetooth permission denied',
      );
    }

    final bluetoothOn =
        await isBluetoothAvailable();

    if (!bluetoothOn) {
      throw Exception(
        'Bluetooth is turned off',
      );
    }

    await _nativeChannel.invokeMethod(
      'startAdvertising',
    );
  }

  Future<void> stopAdvertising() async {
    try {
      await _nativeChannel.invokeMethod(
        'stopAdvertising',
      );
    } catch (_) {}
  }

  Future<void> startScan() async {
    final permissionGranted =
        await requestPermissions();

    if (!permissionGranted) {
      throw Exception(
        'Bluetooth permission denied',
      );
    }

    final bluetoothOn =
        await isBluetoothAvailable();

    if (!bluetoothOn) {
      throw Exception(
        'Bluetooth is turned off',
      );
    }

    _devices.clear();

    _devicesController.add([]);

    await stopScan();

    _scanSubscription =
        FlutterBluePlus.scanResults.listen(
      (results) {
        for (final result in results) {
          final device = result.device;

          if (device.remoteId.str.isEmpty) {
            continue;
          }

          final serviceUuids =
              result.advertisementData.serviceUuids
                  .map(
                    (uuid) =>
                        uuid.toString().toLowerCase(),
                  )
                  .toList();

          final hasOurService =
              serviceUuids.contains(
            serviceUuid,
          );

          if (!hasOurService) {
            continue;
          }

          _devices[device.remoteId.str] =
              result;
        }

        final sortedDevices =
            _devices.values.toList();

        sortedDevices.sort(
          (a, b) => b.rssi.compareTo(a.rssi),
        );

        _devicesController.add(
          sortedDevices,
        );
      },
    );

    await FlutterBluePlus.startScan(
      timeout: const Duration(
        seconds: 10,
      ),
    );
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    await _scanSubscription?.cancel();

    _scanSubscription = null;
  }

  Future<void> connectToDevice(
    ScanResult result,
  ) async {
    final permissionGranted =
        await requestPermissions();

    if (!permissionGranted) {
      throw Exception(
        'Bluetooth permission denied',
      );
    }

    await stopScan();

    final device = result.device;

    try {
      await device.connect(
        timeout: const Duration(
          seconds: 15,
        ),
        autoConnect: false,
        license: License.free,
      );
    } catch (e) {
      final errorText =
          e.toString();

      if (!errorText.contains(
        'already connected',
      )) {
        throw Exception(
          'Connection failed: $errorText',
        );
      }
    }

    _connectedDevice = device;

    final services =
        await device.discoverServices();

    BluetoothCharacteristic?
        targetCharacteristic;

    for (final service in services) {
      if (service.uuid
              .toString()
              .toLowerCase() !=
          serviceUuid) {
        continue;
      }

      for (final characteristic
          in service.characteristics) {
        if (characteristic.uuid
                .toString()
                .toLowerCase() ==
            characteristicUuid) {
          targetCharacteristic =
              characteristic;
          break;
        }
      }

      if (targetCharacteristic !=
          null) {
        break;
      }
    }

    if (targetCharacteristic ==
        null) {
      await disconnect();

      throw Exception(
        'Joruri Messenger service not found',
      );
    }

    _characteristic =
        targetCharacteristic;

    if (targetCharacteristic
        .properties
        .notify) {
      await targetCharacteristic
          .setNotifyValue(true);

      targetCharacteristic
          .lastValueStream
          .listen(
        (value) {
          if (value.isEmpty) {
            return;
          }

          try {
            final message =
                utf8.decode(value);

            _messageController
                .add(message);
          } catch (_) {}
        },
      );
    }

    _connectionController.add(
      'connected:${device.remoteId.str}',
    );
  }

  Future<void> sendMessage(
    String message,
  ) async {
    final characteristic =
        _characteristic;

    if (_connectedDevice == null ||
        characteristic == null) {
      throw Exception(
        'No device connected',
      );
    }

    final data =
        utf8.encode(message);

    await characteristic.write(
      data,
      withoutResponse: false,
    );
  }

  Future<void> disconnect() async {
    final device =
        _connectedDevice;

    _characteristic = null;
    _connectedDevice = null;

    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }

    _connectionController.add(
      'disconnected',
    );
  }

  Future<void> dispose() async {
    await stopScan();

    await disconnect();

    await stopAdvertising();

    await _devicesController.close();

    await _messageController.close();

    await _connectionController.close();
  }
}
