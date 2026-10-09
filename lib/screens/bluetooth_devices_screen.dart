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

class _BluetoothDevicesScreenState extends State<BluetoothDevicesScreen> {
  final BluetoothService _bluetoothService = BluetoothService();

  StreamSubscription<List<ScanResult>>? _devicesSubscription;
  StreamSubscription<String>? _connectionSubscription;

  List<ScanResult> _devices = [];

  bool _scanning = false;
  bool _connecting = false;
  bool _connected = false;
  bool _advertising = false;

  String? _connectedAddress;
  String? _error;

  @override
  void initState() {
    super.initState();

    _devicesSubscription =
        _bluetoothService.devicesStream.listen((devices) {
      if (!mounted) return;

      setState(() {
        _devices = devices;
      });
    });

    _connectionSubscription =
        _bluetoothService.connectionStream.listen((event) {
      if (!mounted) return;

      setState(() {
        if (event.startsWith('connected:')) {
          _connected = true;
          _connecting = false;
          _connectedAddress = event.substring('connected:'.length);
          _error = null;
        } else if (event == 'disconnected') {
          _connected = false;
          _connecting = false;
          _connectedAddress = null;
        } else if (event.startsWith('error:')) {
          _error = event.substring('error:'.length);
          _connecting = false;
        }
      });
    });
  }

  Future<void> _scanDevices() async {
    if (_scanning || _connecting) return;

    setState(() {
      _scanning = true;
      _error = null;
      _devices = [];
    });

    try {
      await _bluetoothService.startScan();

      await Future.delayed(const Duration(seconds: 10));
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'ডিভাইস খুঁজতে সমস্যা হয়েছে: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
        });
      }
    }
  }

  Future<void> _connectToDevice(ScanResult result) async {
    if (_connecting) return;

    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      await _bluetoothService.connectToDevice(result);

      if (!mounted) return;

      setState(() {
        _connected = true;
        _connectedAddress = result.device.remoteId.toString();
        _connecting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bluetooth সংযোগ সফল হয়েছে।'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _connecting = false;
        _connected = false;
        _error = 'সংযোগ করা যায়নি: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('সংযোগ ব্যর্থ: $e'),
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    try {
      await _bluetoothService.disconnect();

      if (!mounted) return;

      setState(() {
        _connected = false;
        _connectedAddress = null;
        _connecting = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'সংযোগ বিচ্ছিন্ন করতে সমস্যা হয়েছে: $e';
      });
    }
  }

  Future<void> _startAdvertising() async {
    try {
      setState(() {
        _error = null;
      });

      await _bluetoothService.startAdvertising();

      if (!mounted) return;

      setState(() {
        _advertising = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bluetooth চালু করার অনুরোধ পাঠানো হয়েছে। '
            'অন্য ফোন থেকে স্ক্যান করে দেখুন।',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Bluetooth চালু করা যায়নি: $e';
      });
    }
  }

  Future<void> _stopAdvertising() async {
    try {
      await _bluetoothService.stopAdvertising();

      if (!mounted) return;

      setState(() {
        _advertising = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Bluetooth বন্ধ করতে সমস্যা হয়েছে: $e';
      });
    }
  }

  String _deviceName(ScanResult result) {
    final platformName = result.device.platformName.trim();
    final advertisedName = result.advertisementData.advName.trim();

    if (platformName.isNotEmpty) return platformName;
    if (advertisedName.isNotEmpty) return advertisedName;

    return 'অজানা Bluetooth ডিভাইস';
  }

  @override
  void dispose() {
    // শুধু এই স্ক্রিনের নিজস্ব subscription বন্ধ হবে।
    // BluetoothService একটি singleton; এখানে dispose করা যাবে না।
    _devicesSubscription?.cancel();
    _connectionSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth সংযোগ'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bluetooth, size: 30),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'কাছের ফোনের সঙ্গে সংযোগ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'দুটি ফোনেই জরুরি মেসেঞ্জার চালু রাখুন। '
                    'একটি ফোনে Bluetooth বিজ্ঞাপন চালু করুন, '
                    'অন্য ফোনে স্ক্যান করে ডিভাইসটি নির্বাচন করুন।',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _scanning || _connecting ? null : _scanDevices,
                      icon: _scanning
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.search),
                      label: Text(
                        _scanning
                            ? 'খোঁজা হচ্ছে...'
                            : 'কাছের ফোন খুঁজুন',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _advertising
                          ? _stopAdvertising
                          : _startAdvertising,
                      icon: Icon(
                        _advertising
                            ? Icons.bluetooth_disabled
                            : Icons.bluetooth_searching,
                      ),
                      label: Text(
                        _advertising
                            ? 'Bluetooth বিজ্ঞাপন বন্ধ করুন'
                            : 'আমার ফোনকে খুঁজে পাওয়ার জন্য চালু করুন',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (_connected)
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ফোন সংযুক্ত',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _connectedAddress ?? 'সংযুক্ত ডিভাইস',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _disconnect,
                        icon: const Icon(Icons.link_off),
                        label: const Text('সংযোগ বিচ্ছিন্ন করুন'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'পাওয়া ডিভাইস',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text('${_devices.length}টি'),
            ],
          ),
          const SizedBox(height: 8),
          if (_devices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  Icon(Icons.bluetooth_searching, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'এখনো কোনো ডিভাইস পাওয়া যায়নি।',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'অন্য ফোনে Bluetooth বিজ্ঞাপন চালু করে আবার খুঁজুন।',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ..._devices.map((result) {
              final name = _deviceName(result);
              final address = result.device.remoteId.toString();

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.phone_android),
                  ),
                  title: Text(name),
                  subtitle: Text(address),
                  trailing: _connecting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _connecting || _connected
                      ? null
                      : () => _connectToDevice(result),
                ),
              );
            }),
          const SizedBox(height: 20),
          const Text(
            'মনে রাখবেন: Bluetooth চালু থাকা, প্রয়োজনীয় অনুমতি দেওয়া '
            'এবং অন্য ফোনে অ্যাপের বিজ্ঞাপন চালু থাকা প্রয়োজন। '
            'বাস্তব ফোনে পরীক্ষা না করা পর্যন্ত সংযোগ ও বার্তা আদান-প্রদান '
            'সম্পূর্ণ কাজ করছে বলে নিশ্চিত হওয়া যাবে না।',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
