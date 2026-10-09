import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'
    hide BluetoothService;

import '../services/bluetooth_service.dart';
import '../services/device_service.dart';

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
  StreamSubscription<String>? _connectionSubscription;

  List<ScanResult> _devices = [];

  bool _scanning = false;
  bool _connecting = false;
  bool _connected = false;
  bool _advertising = false;
  bool _waitingForApproval = false;

  String? _connectedAddress;
  String? _error;
  String _status = 'Bluetooth সংযোগ শুরু করতে বোতাম চাপুন।';

  @override
  void initState() {
    super.initState();

    _connected = _bluetoothService.isConnected;
    _advertising = _bluetoothService.isAdvertising;

    _devicesSubscription =
        _bluetoothService.devicesStream.listen((devices) {
      if (!mounted) return;

      setState(() {
        _devices = devices;
      });
    });

    _connectionSubscription =
        _bluetoothService.connectionStream.listen(_handleConnectionEvent);
  }

  void _handleConnectionEvent(String event) {
    if (!mounted) return;

    setState(() {
      if (event.startsWith('connection_pending:')) {
        _connecting = false;
        _waitingForApproval = true;
        _connected = false;
        _connectedAddress =
            event.substring('connection_pending:'.length);
        _status = 'অন্য ফোনের অনুমতির অপেক্ষায়...';
        _error = null;
      } else if (event.startsWith('connected:')) {
        // BLE সংযোগ হলেই অনুমোদিত সংযোগ ধরা হবে না।
        _connecting = false;
        _waitingForApproval = true;
        _connectedAddress = event.substring('connected:'.length);
        _status = 'অন্য ফোনের অনুমতির অপেক্ষায়...';
      } else if (event == 'connection_request_sent') {
        _waitingForApproval = true;
        _status = 'সংযোগের অনুরোধ পাঠানো হয়েছে।';
      } else if (event == 'connection_accepted') {
        _connecting = false;
        _waitingForApproval = false;
        _connected = true;
        _status = 'সংযোগ অনুমোদিত হয়েছে।';
        _error = null;
      } else if (event == 'connection_rejected') {
        _connecting = false;
        _waitingForApproval = false;
        _connected = false;
        _status = 'অন্য ফোন সংযোগের অনুরোধ প্রত্যাখ্যান করেছে।';
      } else if (event == 'server_pending:') {
        _status = 'একটি ফোনের সংযোগের অপেক্ষায় আছে।';
      } else if (event.startsWith('server_pending:')) {
        _status = 'একটি ফোনের সংযোগের অপেক্ষায় আছে।';
      } else if (event == 'disconnected' ||
          event == 'server_disconnected') {
        _connected = false;
        _connecting = false;
        _waitingForApproval = false;
        _connectedAddress = null;
        _status = 'সংযোগ বিচ্ছিন্ন হয়েছে।';
      } else if (event == 'advertising_started') {
        _advertising = true;
        _status = 'এই ফোনকে অন্য ফোন খুঁজে পেতে পারবে।';
      } else if (event.startsWith('error:')) {
        _error = event.substring('error:'.length);
        _connecting = false;
        _status = 'সংযোগে সমস্যা হয়েছে।';
      }
    });
  }

  Future<void> _startConnectionSearch() async {
    if (_scanning || _connecting) return;

    setState(() {
      _scanning = true;
      _error = null;
      _devices = [];
      _status = 'কাছের ফোন খোঁজা হচ্ছে...';
    });

    try {
      // এই ফোনকে অন্য ফোনের কাছে দৃশ্যমান করার চেষ্টা।
      await _bluetoothService.startAdvertising();

      if (!mounted) return;

      setState(() {
        _advertising = true;
      });

      await _bluetoothService.startScan();

      await Future.delayed(const Duration(seconds: 10));

      if (!mounted) return;

      if (_devices.isEmpty) {
        setState(() {
          _status =
              'ফোন পাওয়া যায়নি। অন্য ফোনে অ্যাপ ও Bluetooth চালু রাখুন।';
        });
      } else {
        setState(() {
          _status = 'একটি ফোন নির্বাচন করে অনুরোধ পাঠান।';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'ফোন খুঁজতে সমস্যা হয়েছে: $e';
        _status = 'Bluetooth অনুমতি ও সেটিং পরীক্ষা করুন।';
      });
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
        });
      }
    }
  }

  Future<void> _connectToDevice(ScanResult result) async {
    if (_connecting || _waitingForApproval || _connected) return;

    setState(() {
      _connecting = true;
      _error = null;
      _status = 'ফোনের সঙ্গে সংযোগ করা হচ্ছে...';
    });

    try {
      await _bluetoothService.connectToDevice(result);

      // সংযোগ হলেই চ্যাট অনুমোদিত হবে না।
      await _bluetoothService.requestConnection(
        senderId: DeviceService.deviceId,
        senderName: DeviceService.deviceName,
      );

      if (!mounted) return;

      setState(() {
        _connecting = false;
        _waitingForApproval = true;
        _connected = false;
        _connectedAddress = result.device.remoteId.str;
        _status = 'অন্য ফোনের অনুমতির অপেক্ষায়...';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('সংযোগের অনুরোধ পাঠানো হয়েছে।'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _connecting = false;
        _waitingForApproval = false;
        _connected = false;
        _error = 'সংযোগের অনুরোধ পাঠানো যায়নি: $e';
        _status = 'আবার চেষ্টা করুন।';
      });
    }
  }

  Future<void> _disconnect() async {
    try {
      await _bluetoothService.disconnect();

      if (!mounted) return;

      setState(() {
        _connected = false;
        _connecting = false;
        _waitingForApproval = false;
        _connectedAddress = null;
        _status = 'সংযোগ বিচ্ছিন্ন হয়েছে।';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'সংযোগ বিচ্ছিন্ন করতে সমস্যা হয়েছে: $e';
      });
    }
  }

  Future<void> _stopAdvertising() async {
    try {
      await _bluetoothService.stopAdvertising();

      if (!mounted) return;

      setState(() {
        _advertising = false;
        _status = 'Bluetooth বিজ্ঞাপন বন্ধ করা হয়েছে।';
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
                  const SizedBox(height: 12),
                  Text(_status),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _scanning ||
                              _connecting ||
                              _waitingForApproval ||
                              _connected
                          ? null
                          : _startConnectionSearch,
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
                            ? 'ফোন খোঁজা হচ্ছে...'
                            : 'কাছের ফোন খুঁজুন',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _advertising
                        ? _stopAdvertising
                        : () async {
                            try {
                              await _bluetoothService.startAdvertising();

                              if (!mounted) return;

                              setState(() {
                                _advertising = true;
                                _error = null;
                              });
                            } catch (e) {
                              if (!mounted) return;

                              setState(() {
                                _error = 'Bluetooth চালু করা যায়নি: $e';
                              });
                            }
                          },
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
          if (_connected || _waitingForApproval)
            Card(
              color: _connected
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _connected
                              ? Icons.check_circle
                              : Icons.hourglass_top,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _connected
                                ? 'সংযোগ অনুমোদিত'
                                : 'অনুমতির অপেক্ষায়',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_connectedAddress != null) ...[
                      const SizedBox(height: 8),
                      SelectableText(_connectedAddress!),
                    ],
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
                    'দুই ফোনেই Bluetooth ও জরুরি মেসেঞ্জার চালু রাখুন।',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ..._devices.map((result) {
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.phone_android),
                  ),
                  title: Text(_deviceName(result)),
                  subtitle: Text(result.device.remoteId.str),
                  trailing: _connecting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _connecting ||
                          _waitingForApproval ||
                          _connected
                      ? null
                      : () => _connectToDevice(result),
                ),
              );
            }),
          const SizedBox(height: 20),
          const Text(
            'সংযোগ অনুমোদনের আগে চ্যাটে মেসেজ পাঠানো উচিত নয়। '
            'প্রথম সংস্করণে অন্য ফোনে অ্যাপ খোলা থাকা প্রয়োজন। '
            'দুই ফোনে পরীক্ষা না করে কাজ সম্পূর্ণ হয়েছে ধরে নেবেন না।',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
