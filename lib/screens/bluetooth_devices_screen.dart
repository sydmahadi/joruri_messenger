import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/bluetooth_service.dart';

class BluetoothDevicesScreen extends StatefulWidget {
  const BluetoothDevicesScreen({super.key});

  @override
  State<BluetoothDevicesScreen> createState() =>
      _BluetoothDevicesScreenState();
}

class _BluetoothDevicesScreenState
    extends State<BluetoothDevicesScreen> {
  final BluetoothService _bluetoothService = BluetoothService();

  StreamSubscription<List<ScanResult>>? _devicesSubscription;

  List<ScanResult> _devices = [];

  bool _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _devicesSubscription =
        _bluetoothService.devicesStream.listen((devices) {
      if (!mounted) {
        return;
      }

      setState(() {
        _devices = devices;
      });
    });
  }

  @override
  void dispose() {
    _devicesSubscription?.cancel();
    _bluetoothService.dispose();

    super.dispose();
  }

  Future<void> _scanDevices() async {
    setState(() {
      _scanning = true;
      _error = null;
      _devices = [];
    });

    try {
      await _bluetoothService.startScan();

      await Future<void>.delayed(
        const Duration(seconds: 10),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _scanning = false;
      });
    }
  }

  String _deviceName(ScanResult result) {
    final name = result.device.platformName.trim();

    if (name.isNotEmpty) {
      return name;
    }

    return 'Unknown device';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('কাছাকাছি ডিভাইস'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _scanning ? null : _scanDevices,
                icon: Icon(
                  _scanning
                      ? Icons.sync
                      : Icons.bluetooth_searching,
                ),
                label: Text(
                  _scanning
                      ? 'ডিভাইস খোঁজা হচ্ছে...'
                      : 'ডিভাইস খুঁজুন',
                ),
              ),
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_error!),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_scanning)
            const LinearProgressIndicator(),

          Expanded(
            child: _devices.isEmpty
                ? const Center(
                    child: Text(
                      'এখনো কোনো ডিভাইস পাওয়া যায়নি।\n'
                      'Bluetooth চালু করে আবার চেষ্টা করুন।',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final result = _devices[index];
                      final device = result.device;

                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.phone_android),
                        ),
                        title: Text(
                          _deviceName(result),
                        ),
                        subtitle: Text(
                          device.remoteId.str,
                        ),
                        trailing: Text(
                          '${result.rssi} dBm',
                        ),
                        onTap: () {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Connection feature will be added next.',
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
