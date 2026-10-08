import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/bluetooth_service.dart' as local_bluetooth;

class BluetoothDevicesScreen extends StatefulWidget {
  const BluetoothDevicesScreen({super.key});

  @override
  State<BluetoothDevicesScreen> createState() =>
      _BluetoothDevicesScreenState();
}

class _BluetoothDevicesScreenState
    extends State<BluetoothDevicesScreen> {
  final local_bluetooth.BluetoothService _bluetoothService =
      local_bluetooth.BluetoothService();

  StreamSubscription<List<ScanResult>>? _devicesSubscription;
  StreamSubscription<String>? _connectionSubscription;

  List<ScanResult> _devices = [];

  bool _scanning = false;
  bool _connecting = false;
  bool _connected = false;

  String? _connectedAddress;
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

    _connectionSubscription =
        _bluetoothService.connectionStream.listen((status) {
      if (!mounted) {
        return;
      }

      if (status.startsWith('connected:')) {
        setState(() {
          _connecting = false;
          _connected = true;
          _connectedAddress =
              status.substring('connected:'.length);
          _error = null;
        });

        _showMessage(
          'ডিভাইসের সাথে সংযোগ হয়েছে',
        );
      } else if (status == 'disconnected') {
        setState(() {
          _connecting = false;
          _connected = false;
          _connectedAddress = null;
        });
      } else if (status.startsWith('error:')) {
        setState(() {
          _connecting = false;
          _error = status.substring('error:'.length);
        });
      }
    });
  }

  @override
  void dispose() {
    _devicesSubscription?.cancel();
    _connectionSubscription?.cancel();
    _bluetoothService.dispose();

    super.dispose();
  }

  Future<void> _scanDevices() async {
    if (_connecting || _connected) {
      return;
    }

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
        _error = e.toString().replaceFirst(
              'Exception: ',
              '',
            );
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

  Future<void> _connectToDevice(
    ScanResult result,
  ) async {
    if (_connecting || _connected) {
      return;
    }

    final name = _deviceName(result);

    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      await _bluetoothService.connectToDevice(
        result,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _connected = true;
        _connectedAddress =
            result.device.remoteId.str;
        _connecting = false;
      });

      _showMessage(
        '$name-এর সাথে সংযোগ হয়েছে',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _connecting = false;
        _connected = false;
        _connectedAddress = null;
        _error = e.toString().replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  Future<void> _disconnect() async {
    await _bluetoothService.disconnect();

    if (!mounted) {
      return;
    }

    setState(() {
      _connected = false;
      _connectedAddress = null;
      _connecting = false;
    });

    _showMessage(
      'ডিভাইস থেকে সংযোগ বিচ্ছিন্ন হয়েছে',
    );
  }

  Future<void> _startAdvertising() async {
    try {
      await _bluetoothService.startAdvertising();

      if (!mounted) {
        return;
      }

      _showMessage(
        'আপনার ফোন এখন অন্য জরুরি মেসেঞ্জার ডিভাইসের জন্য প্রস্তুত',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = e.toString().replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  String _deviceName(ScanResult result) {
    final name = result.device.platformName.trim();

    if (name.isNotEmpty) {
      return name;
    }

    final advertisedName =
        result.advertisementData.advName.trim();

    if (advertisedName.isNotEmpty) {
      return advertisedName;
    }

    return 'জরুরি মেসেঞ্জার ডিভাইস';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'কাছাকাছি ডিভাইস',
        ),
        actions: [
          if (_connected)
            IconButton(
              tooltip: 'Disconnect',
              onPressed: _disconnect,
              icon: const Icon(
                Icons.bluetooth_disabled,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_connected)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                0,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bluetooth_connected,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connected',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                        if (_connectedAddress != null)
                          Text(
                            _connectedAddress!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer,
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed:
                        (_scanning ||
                                _connecting ||
                                _connected)
                            ? null
                            : _scanDevices,
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

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed:
                        (_connecting || _connected)
                            ? null
                            : _startAdvertising,
                    icon: const Icon(
                      Icons.bluetooth_audio,
                    ),
                    label: const Text(
                      'আমার ফোনকে খুঁজে পাওয়ার জন্য চালু করুন',
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_connecting)
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: Column(
                children: [
                  LinearProgressIndicator(),
                  SizedBox(height: 8),
                  Text(
                    'ডিভাইসের সাথে সংযোগ করা হচ্ছে...',
                  ),
                ],
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
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
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

          Expanded(
            child: _devices.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'এখনো কোনো জরুরি মেসেঞ্জার ডিভাইস পাওয়া যায়নি।\n\n'
                        'দুই ফোনেই Bluetooth চালু করুন।\n'
                        'অন্য ফোনে "আমার ফোনকে খুঁজে পাওয়ার জন্য চালু করুন" চাপুন।\n'
                        'তারপর এই ফোনে "ডিভাইস খুঁজুন" চাপুন।',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final result = _devices[index];
                      final device = result.device;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(
                              Icons.phone_android,
                            ),
                          ),
                          title: Text(
                            _deviceName(result),
                          ),
                          subtitle: Text(
                            device.remoteId.str,
                          ),
                          trailing: _connecting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.bluetooth_connected,
                                ),
                          onTap: _connecting || _connected
                              ? null
                              : () {
                                  _connectToDevice(
                                    result,
                                  );
                                },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
