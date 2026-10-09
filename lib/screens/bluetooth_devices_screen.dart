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

  List<ScanResult> _devices = [];

  StreamSubscription<List<ScanResult>>? _devicesSubscription;
  StreamSubscription<String>? _connectionSubscription;

  bool _scanning = false;
  bool _connecting = false;
  bool _connected = false;
  bool _advertising = false;
  bool _waitingForApproval = false;

  String? _connectedAddress;
  String? _error;
  String _status = 'Bluetooth সংযোগ শুরু করুন';

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
        _bluetoothService.connectionStream.listen(
      _handleConnectionEvent,
    );
  }

  void _handleConnectionEvent(String event) {
    if (!mounted) return;

    setState(() {
      if (event.startsWith('connection_pending:')) {
        _waitingForApproval = true;
        _connecting = false;
        _connected = false;
        _status = 'অন্য ফোনের অনুমতির অপেক্ষায় আছি';
      } else if (event.startsWith('connected:')) {
        _connectedAddress = event.substring('connected:'.length);
        _connected = _bluetoothService.isConnected;
        _waitingForApproval = !_connected;
        _connecting = false;
        _status = _connected
            ? 'Bluetooth সংযোগ হয়েছে'
            : 'অনুমতির অপেক্ষায় আছি';
      } else if (event == 'connection_request_sent') {
        _waitingForApproval = true;
        _status = 'অনুরোধ পাঠানো হয়েছে। গ্রহণের অপেক্ষায় আছি';
      } else if (event == 'connection_accepted') {
        _connected = _bluetoothService.isConnected;
        _waitingForApproval = !_connected;
        _connecting = false;
        _status = _connected
            ? 'সংযোগ অনুমোদিত হয়েছে'
            : 'অনুমোদন পাওয়া গেছে; সংযোগ যাচাই হচ্ছে';
      } else if (event == 'connection_rejected') {
        _connected = false;
        _waitingForApproval = false;
        _connecting = false;
        _status = 'অন্য ফোন সংযোগের অনুরোধ প্রত্যাখ্যান করেছে';
      } else if (event.startsWith('server_pending:')) {
        _connectedAddress =
            event.substring('server_pending:'.length);
        _status = 'অন্য ফোন থেকে সংযোগের অনুরোধ আসছে';
      } else if (event == 'server_disconnected' ||
          event == 'disconnected') {
        _connected = false;
        _waitingForApproval = false;
        _connecting = false;
        _connectedAddress = null;
        _status = 'সংযোগ বিচ্ছিন্ন হয়েছে';
      } else if (event == 'advertising_started') {
        _advertising = true;
        _status = 'আপনার ফোন অন্য ফোনের জন্য প্রস্তুত';
      } else if (event.startsWith('error:')) {
        _error = event.substring('error:'.length);
        _connecting = false;
        _scanning = false;
        _status = 'একটি সমস্যা হয়েছে';
      }
    });
  }

  Future<void> _startConnectionSearch() async {
    if (_scanning || _connecting) return;

    setState(() {
      _error = null;
      _scanning = true;
      _status = 'Bluetooth চালু করা হচ্ছে...';
      _devices = [];
    });

    try {
      final permitted = await _bluetoothService.requestPermissions();

      if (!permitted) {
        throw Exception(
          'Bluetooth permission দিন এবং ফোনের Bluetooth চালু করুন।',
        );
      }

      final available =
          await _bluetoothService.isBluetoothAvailable();

      if (!available) {
        throw Exception(
          'ফোনের Bluetooth চালু করুন।',
        );
      }

      // এই ফোনকে অন্য ফোনের সংযোগ গ্রহণের জন্য প্রস্তুত করা।
      await _bluetoothService.startAdvertising();

      if (!mounted) return;

      setState(() {
        _advertising = true;
        _status = 'কাছাকাছি ফোন খোঁজা হচ্ছে...';
      });

      await _bluetoothService.startScan();

      await Future<void>.delayed(
        const Duration(seconds: 10),
      );

      await _bluetoothService.stopScan();

      if (!mounted) return;

      setState(() {
        _scanning = false;

        if (_devices.isEmpty) {
          _status =
              'ফোন পাওয়া যায়নি। অন্য ফোনেও Bluetooth চালু আছে কি না দেখুন।';
        } else {
          _status = '${_devices.length}টি ফোন পাওয়া গেছে';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _scanning = false;
        _error = e.toString();
        _status = 'Bluetooth চালু করা যায়নি';
      });
    }
  }

  Future<void> _connectToDevice(ScanResult result) async {
    if (_connecting || _waitingForApproval) return;

    final device = result.device;

    setState(() {
      _error = null;
      _connecting = true;
      _status = '${device.remoteId.str} ফোনে সংযোগ করা হচ্ছে...';
    });

    try {
      await _bluetoothService.connectToDevice(device);

      await _bluetoothService.requestConnection(
        senderId: DeviceService.deviceId,
        senderName: DeviceService.deviceName,
      );

      if (!mounted) return;

      setState(() {
        _connectedAddress = device.remoteId.str;
        _connecting = false;
        _waitingForApproval = true;
        _connected = _bluetoothService.isConnected;
        _status = 'অন্য ফোনের অনুমতির অপেক্ষায় আছি';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _connecting = false;
        _waitingForApproval = false;
        _connected = false;
        _error = e.toString();
        _status = 'সংযোগ করা যায়নি';
      });
    }
  }

  Future<void> _disconnect() async {
    try {
      await _bluetoothService.disconnect();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
      });
    }

    if (!mounted) return;

    setState(() {
      _connected = false;
      _waitingForApproval = false;
      _connecting = false;
      _connectedAddress = null;
      _status = 'সংযোগ বিচ্ছিন্ন হয়েছে';
    });
  }

  Future<void> _stopAdvertising() async {
    try {
      await _bluetoothService.stopAdvertising();

      if (!mounted) return;

      setState(() {
        _advertising = false;
        _status = 'Bluetooth advertising বন্ধ করা হয়েছে';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _devicesSubscription?.cancel();
    _connectionSubscription?.cancel();

    // Singleton BluetoothService এখানে dispose করা হবে না।
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bluetooth Connection',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.bluetooth,
                          size: 34,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Bluetooth সংযোগ',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _status,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    if (_connectedAddress != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Device: $_connectedAddress',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (_waitingForApproval) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text(
                        'অন্য ফোনে Accept করতে হবে।',
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed:
                    (_scanning || _connecting || _connected)
                        ? null
                        : _startConnectionSearch,
                icon: _scanning
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(
                  _scanning
                      ? 'ফোন খোঁজা হচ্ছে...'
                      : 'কাছাকাছি ফোন খুঁজুন',
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _advertising
                  ? _stopAdvertising
                  : _startConnectionSearch,
              icon: Icon(
                _advertising
                    ? Icons.bluetooth_disabled
                    : Icons.bluetooth_searching,
              ),
              label: Text(
                _advertising
                    ? 'Advertising বন্ধ করুন'
                    : 'এই ফোনকে সংযোগের জন্য প্রস্তুত করুন',
              ),
            ),
            if (_connected || _waitingForApproval) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _disconnect,
                icon: const Icon(Icons.link_off),
                label: const Text('সংযোগ বিচ্ছিন্ন করুন'),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'পাওয়া Bluetooth ডিভাইস (${_devices.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_devices.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'এখনো কোনো ডিভাইস পাওয়া যায়নি। '
                    'দুই ফোনে অ্যাপ খুলে Bluetooth চালু করুন।',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ..._devices.map((result) {
                final device = result.device;
                final name = device.platformName.isNotEmpty
                    ? device.platformName
                    : 'অজানা Bluetooth ডিভাইস';

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.phone_android),
                    ),
                    title: Text(name),
                    subtitle: Text(
                      '${device.remoteId.str}\n'
                      'Signal: ${result.rssi} dBm',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Connect',
                      onPressed:
                          (_connecting ||
                                  _connected ||
                                  _waitingForApproval)
                              ? null
                              : () => _connectToDevice(result),
                      icon: const Icon(Icons.link),
                    ),
                    onTap:
                        (_connecting ||
                                _connected ||
                                _waitingForApproval)
                            ? null
                            : () => _connectToDevice(result),
                  ),
                );
              }),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'মনে রাখুন: অন্য ফোনে অ্যাপের Bluetooth '
                  'সার্ভিস চালু থাকতে হবে। সংযোগের অনুরোধ '
                  'গ্রহণ না করা পর্যন্ত চ্যাট অনুমোদিত হবে না।',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
