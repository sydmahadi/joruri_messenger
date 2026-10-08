import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothService {
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  final StreamController<List<ScanResult>> _devicesController =
      StreamController<List<ScanResult>>.broadcast();

  Stream<List<ScanResult>> get devicesStream => _devicesController.stream;

  final Map<String, ScanResult> _devices = {};

  Future<bool> requestPermissions() async {
    final permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ];

    final result = await permissions.request();

    return result.values.every(
      (status) => status.isGranted,
    );
  }

  Future<bool> isBluetoothAvailable() async {
    try {
      final state = await FlutterBluePlus.adapterState.first;

      return state == BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  Future<void> startScan() async {
    final permissionGranted = await requestPermissions();

    if (!permissionGranted) {
      throw Exception('Bluetooth permission denied');
    }

    final bluetoothOn = await isBluetoothAvailable();

    if (!bluetoothOn) {
      throw Exception('Bluetooth is turned off');
    }

    _devices.clear();
    _devicesController.add([]);

    await stopScan();

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        for (final result in results) {
          final device = result.device;

          if (device.remoteId.str.isEmpty) {
            continue;
          }

          _devices[device.remoteId.str] = result;
        }

        final sortedDevices = _devices.values.toList();

        sortedDevices.sort(
          (a, b) => b.rssi.compareTo(a.rssi),
        );

        _devicesController.add(sortedDevices);
      },
    );

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10),
    );
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {
      // Scan may already be stopped.
    }

    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  Future<void> dispose() async {
    await stopScan();
    await _devicesController.close();
  }
}
