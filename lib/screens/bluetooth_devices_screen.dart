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
  bool _advertising = false;

  final Set<String> _connectingAddresses = {};
  final Set<String> _waitingAddresses = {};
  final Set<String> _connectedAddresses = {};

  String? _error;
  String _status = 'Bluetooth সংযোগ শুরু করুন';

  @override
  void initState() {
    super.initState();

    _advertising = _bluetoothService.isAdvertising;
    _connectedAddresses.addAll(
      _bluetoothService.connectedDeviceAddresses,
    );

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
        final address =
            event.substring('connection_pending:'.length);
        _connectingAddresses.remove(address);
        _waitingAddresses.add(address);
        _connecting = _connectingAddresses.isNotEmpty;
        _status = 'অন্য ফোনের অনুমতির অপেক্ষায় আছি';
      } else if (event.startsWith('connection_accepted:')) {
        final address =
            event.substring('connection_accepted:'.length);
        _waitingAddresses.remove(address);
        _connectedAddresses.add(address);
        _status = 'একটি ফোনের সংযোগ অনুমোদিত হয়েছে';
      } else if (event == 'connection_accepted') {
        _waitingAddresses.clear();
        _connectedAddresses.addAll(
          _bluetoothService.connectedDeviceAddresses,
        );
        _status = 'সংযোগ অনুমোদিত হয়েছে';
      } else if (event.startsWith('connection_request_sent')) {
        _status = 'অনুরোধ পাঠানো হয়েছে। গ্রহণের অপেক্ষায় আছি';
      } else if (event.startsWith('already_connected:')) {
        final address =
            event.substring('already_connected:'.length);
        _connectedAddresses.add(address);
        _status = 'এই ফোনটি ইতিমধ্যে সংযুক্ত';
      } else if (event.startsWith('disconnected:')) {
        final address = event.substring('disconnected:'.length);
        _connectedAddresses.remove(address);
        _waitingAddresses.remove(address);
        _connectingAddresses.remove(address);
        _status = 'একটি ফোন বিচ্ছিন্ন হয়েছে';
      } else if (event == 'disconnected' ||
          event == 'server_disconnected') {
        _connectedAddresses.removeWhere(
          (address) =>
              !_bluetoothService.connectedDeviceAddresses
                  .contains(address),
        );
        _status = 'Bluetooth সংযোগের অবস্থা পরিবর্তিত হয়েছে';
      } else if (event == 'advertising_started') {
        _advertising = true;
        _status = 'আপনার ফোন অন্য ফোনের জন্য প্রস্তুত';
      } else if (event.startsWith('error:')) {
        _error = event.substring('error:'.length);
        _connectingAddresses.clear();
        _connecting = false;
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
      final permitted =
          await _bluetoothService.requestPermissions();

      if (!permitted) {
        throw Exception(
          'Bluetooth permission দিন এবং ফোনের Bluetooth চালু করুন।',
        );
      }

      final available =
          await _bluetoothService.isBluetoothAvailable();

      if (!available) {
        throw Exception('ফোনের Bluetooth চালু করুন।');
      }

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
        _status = _devices.isEmpty
            ? 'ফোন পাওয়া যায়নি। অন্য ফোনে অ্যাপ ও Bluetooth চালু করুন।'
            : '${_devices.length}টি ফোন পাওয়া গেছে';
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
    final device = result.device;
    final address = device.remoteId.str;

    if (_connectingAddresses.contains(address) ||
        _waitingAddresses.contains(address) ||
        _connectedAddresses.contains(address)) {
      return;
    }

    setState(() {
      _error = null;
      _connectingAddresses.add(address);
      _connecting = true;
      _status = '$address ফোনে সংযোগ করা হচ্ছে...';
    });

    try {
      await _bluetoothService.connectToDevice(device);

      await _bluetoothService.requestConnection(
        senderId: DeviceService.deviceId,
        senderName: DeviceService.deviceName,
        deviceAddress: address,
      );

      if (!mounted) return;

      setState(() {
        _connectingAddresses.remove(address);
        _waitingAddresses.add(address);
        _connecting = _connectingAddresses.isNotEmpty;
        _status = 'অন্য ফোনের অনুমতির অপেক্ষায় আছি';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _connectingAddresses.remove(address);
        _connecting = _connectingAddresses.isNotEmpty;
        _error = e.toString();
        _status = 'সংযোগ করা যায়নি';
      });
    }
  }

  Future<void> _disconnectDevice(String address) async {
    try {
      await _bluetoothService.disconnectDevice(address);

      if (!mounted) return;

      setState(() {
        _connectedAddresses.remove(address);
        _waitingAddresses.remove(address);
        _connectingAddresses.remove(address);
        _status = 'নির্বাচিত ফোন বিচ্ছিন্ন হয়েছে';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _stopAdvertising() async {
    try {
      await _bluetoothService.stopAdvertising();

      if (!mounted) return;

      setState(() {
        _advertising = false;
        _status = 'Advertising বন্ধ করা হয়েছে';
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
                    const SizedBox(height: 8),
                    Text(
                      'অনুমোদিত ফোন: ${_connectedAddresses.length}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (_waitingAddresses.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'অনুমতির অপেক্ষায়: ${_waitingAddresses.length}টি ফোন',
                        style: theme.textTheme.bodyMedium,
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
                onPressed: _scanning || _connecting
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
                      : 'আরও ফোন খুঁজুন',
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed:
                  _advertising ? _stopAdvertising : _startConnectionSearch,
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
                final address = device.remoteId.str;
                final name = device.platformName.isNotEmpty
                    ? device.platformName
                    : 'অজানা Bluetooth ডিভাইস';

                final connected =
                    _connectedAddresses.contains(address);
                final waiting =
                    _waitingAddresses.contains(address);
                final connecting =
                    _connectingAddresses.contains(address);

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        connected
                            ? Icons.bluetooth_connected
                            : Icons.phone_android,
                      ),
                    ),
                    title: Text(name),
                    subtitle: Text(
                      '$address\n'
                      'Signal: ${result.rssi} dBm\n'
                      '${connected ? 'সংযুক্ত' : waiting ? 'অনুমতির অপেক্ষায়' : connecting ? 'সংযোগ হচ্ছে...' : 'সংযুক্ত নয়'}',
                    ),
                    isThreeLine: true,
                    trailing: connected
                        ? IconButton(
                            tooltip: 'Disconnect',
                            onPressed: () =>
                                _disconnectDevice(address),
                            icon: const Icon(Icons.link_off),
                          )
                        : waiting || connecting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton(
                                tooltip: 'Connect',
                                onPressed: () =>
                                    _connectToDevice(result),
                                icon: const Icon(Icons.link),
                              ),
                    onTap: connected ||
                            waiting ||
                            connecting
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
                  'নতুন ফোন যোগ করতে আবার ফোন খুঁজুন। '
                  'আগের ফোনের সংযোগ বিচ্ছিন্ন হবে না। '
                  'অন্য ফোনে অনুরোধ গ্রহণ করতে হবে।',
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
