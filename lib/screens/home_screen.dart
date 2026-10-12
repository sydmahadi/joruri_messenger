
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../services/bluetooth_service.dart';
import '../services/device_service.dart';
import '../services/local_storage_service.dart';
import 'bluetooth_devices_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BluetoothService _bluetooth = BluetoothService.instance;
  final TextEditingController _messageController =
      TextEditingController();

  final List<Message> _messages = [];
  StreamSubscription<String>? _messageSubscription;

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messages.addAll(LocalStorageService.getMessages());
    _messageSubscription = _bluetooth.messageStream.listen(
      _receiveMessage,
    );
  }

  void _receiveMessage(String raw) {
    try {
      final decoded = jsonDecode(raw);

      if (decoded is! Map<String, dynamic>) return;

      final message = Message.fromMap(decoded);

      if (message.id.isEmpty ||
          message.text.isEmpty ||
          message.messageType != 'chat') {
        return;
      }

      if (_messages.any((item) => item.id == message.id)) {
        return;
      }

      setState(() {
        _messages.add(message);
        _messages.sort(
          (a, b) => a.createdAt.compareTo(b.createdAt),
        );
      });

      LocalStorageService.saveMessage(message);
    } catch (_) {
      // Ignore non-chat Bluetooth protocol messages.
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _sending) return;

    final message = Message(
      id: const Uuid().v4(),
      senderId: DeviceService.deviceId,
      senderName: DeviceService.deviceName,
      senderLocation: DeviceService.deviceLocation,
      text: text,
      createdAt: DateTime.now(),
      messageType: 'chat',
    );

    setState(() {
      _sending = true;
      _messages.add(message);
    });

    _messageController.clear();
    await LocalStorageService.saveMessage(message);

    try {
      await _bluetooth.sendMessage(jsonEncode(message.toMap()));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('মেসেজ পাঠানো হয়েছে'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('পাঠানো যায়নি: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _editProfile() async {
    final nameController = TextEditingController(
      text: DeviceService.deviceName,
    );
    final locationController = TextEditingController(
      text: DeviceService.deviceLocation,
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('আমার পরিচয়'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'আপনার নাম',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'আপনার এলাকা',
                    hintText: 'যেমন: মিরপুর, ঢাকা',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('বাতিল'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('সংরক্ষণ'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await DeviceService.setDeviceName(nameController.text);
      await DeviceService.setDeviceLocation(
        locationController.text,
      );

      if (mounted) setState(() {});
    }

    nameController.dispose();
    locationController.dispose();
  }

  String _formatTime(DateTime time) {
    final localTime = time.toLocal();
    final hour = localTime.hour % 12 == 0
        ? 12
        : localTime.hour % 12;
    final minute = localTime.minute.toString().padLeft(2, '0');
    final period = localTime.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('জরুরি মেসেঞ্জার'),
        actions: [
          IconButton(
            tooltip: 'আমার পরিচয়',
            onPressed: _editProfile,
            icon: const Icon(Icons.account_circle),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: theme.colorScheme.primaryContainer,
            child: Row(
              children: [
                const Icon(Icons.hub_outlined),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'কমন চ্যাট',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Mesh-এ সংযুক্ত ফোনগুলোর বার্তা',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const BluetoothDevicesScreen(),
                      ),
                    );
                  },
                  child: const Text('Mesh সংযোগ'),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text(DeviceService.deviceName),
            subtitle: Text(
              DeviceService.deviceLocation.isEmpty
                  ? 'এলাকা সেট করা হয়নি'
                  : DeviceService.deviceLocation,
            ),
            trailing: IconButton(
              onPressed: _editProfile,
              icon: const Icon(Icons.edit),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 56,
                        ),
                        SizedBox(height: 12),
                        Text('এখনো কোনো মেসেজ নেই'),
                        Text('Mesh-এ যুক্ত হয়ে চ্যাট শুরু করুন'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMine =
                          message.senderId == DeviceService.deviceId;

                      return Align(
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.82,
                          ),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMine
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.senderName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              if (message.senderLocation.isNotEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '📍 ${message.senderLocation}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Text(message.text),
                              const SizedBox(height: 5),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  _formatTime(message.createdAt),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'সবার জন্য মেসেজ লিখুন...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _sendMessage,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
