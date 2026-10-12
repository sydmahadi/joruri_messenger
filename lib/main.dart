import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'models/message.dart';
import 'screens/bluetooth_devices_screen.dart';
import 'screens/connection_screen.dart';
import 'services/bluetooth_service.dart';
import 'services/device_service.dart';
import 'services/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalStorageService.init();
  await DeviceService.initialize();

  final bluetoothService = BluetoothService();
  await bluetoothService.initialize();

  runApp(
    JoruriMessengerApp(
      bluetoothService: bluetoothService,
    ),
  );
}

class JoruriMessengerApp extends StatefulWidget {
  final BluetoothService bluetoothService;

  const JoruriMessengerApp({
    super.key,
    required this.bluetoothService,
  });

  @override
  State<JoruriMessengerApp> createState() =>
      _JoruriMessengerAppState();
}

class _JoruriMessengerAppState extends State<JoruriMessengerApp> {
  final List<Map<String, String>> _pendingRequests = [];

  StreamSubscription<String>? _messageSubscription;
  bool _showingRequestDialog = false;

  BluetoothService get _bluetooth => widget.bluetoothService;

  @override
  void initState() {
    super.initState();

    _messageSubscription = _bluetooth.messageStream.listen(
      _handleIncomingMessage,
      onError: (Object error) {
        debugPrint('Message stream error: $error');
      },
    );
  }

  void _handleIncomingMessage(String rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage);

      if (decoded is! Map) return;

      if (decoded['type']?.toString() != 'connection_request') {
        return;
      }

      // BluetoothService sends senderId and senderName.
      final requesterId = decoded['senderId']?.toString() ?? '';

      final name = decoded['senderName']?.toString().trim();
      final requesterName =
          (name == null || name.isEmpty) ? 'অজানা ডিভাইস' : name;

      if (requesterId.isEmpty) {
        debugPrint('Connection request এ senderId নেই: $rawMessage');
        return;
      }

      if (_pendingRequests.any(
        (request) => request['requesterId'] == requesterId,
      )) {
        return;
      }

      if (!mounted) return;

      _pendingRequests.add({
        'requesterId': requesterId,
        'requesterName': requesterName,
      });

      _showNextRequestDialog();
    } catch (error) {
      debugPrint('Connection request parsing error: $error');
    }
  }

  Future<void> _showNextRequestDialog() async {
    if (!mounted ||
        _showingRequestDialog ||
        _pendingRequests.isEmpty) {
      return;
    }

    _showingRequestDialog = true;

    final request = _pendingRequests.removeAt(0);
    final requesterId = request['requesterId']!;
    final requesterName = request['requesterName']!;

    bool? accepted;

    try {
      accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('নতুন সংযোগের অনুরোধ'),
            content: Text(
              '$requesterName আপনার সঙ্গে সংযুক্ত হতে চায়। '
              'আপনি কি অনুমতি দেবেন?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('প্রত্যাখ্যান'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('অনুমতি দিন'),
              ),
            ],
          );
        },
      );

      if (accepted != null) {
        await _bluetooth.respondToConnectionRequest(
          accepted: accepted,
          requesterId: requesterId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                accepted
                    ? '$requesterName-এর সংযোগের অনুমতি পাঠানো হয়েছে।'
                    : '$requesterName-এর অনুরোধ প্রত্যাখ্যান করা হয়েছে।',
              ),
            ),
          );
        }
      }
    } catch (error) {
      debugPrint('Connection response error: $error');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('সংযোগের উত্তর পাঠানো যায়নি: $error'),
          ),
        );
      }
    } finally {
      _showingRequestDialog = false;

      if (mounted && _pendingRequests.isNotEmpty) {
        _showNextRequestDialog();
      }
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'জরুরি মেসেঞ্জার',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: ChatScreen(
        bluetoothService: _bluetooth,
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final BluetoothService bluetoothService;

  const ChatScreen({
    super.key,
    required this.bluetoothService,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController =
      TextEditingController();

  final ScrollController _scrollController = ScrollController();
  final Uuid _uuid = const Uuid();

  final List<Message> _messages = [];

  StreamSubscription<String>? _messageSubscription;
  StreamSubscription<String>? _connectionSubscription;

  bool _sending = false;

  BluetoothService get _bluetooth => widget.bluetoothService;

  @override
  void initState() {
    super.initState();

    _loadMessages();

    _messageSubscription = _bluetooth.messageStream.listen(
      _handleIncomingMessage,
      onError: (Object error) {
        debugPrint('Chat stream error: $error');
      },
    );

    _connectionSubscription = _bluetooth.connectionStream.listen(
      (String event) {
        if (mounted) setState(() {});
      },
      onError: (Object error) {
        debugPrint('Connection stream error: $error');
      },
    );
  }

  Future<void> _loadMessages() async {
    try {
      final savedMessages = LocalStorageService.getMessages();

      if (!mounted) return;

      setState(() {
        _messages
          ..clear()
          ..addAll(savedMessages);
      });

      _scrollToBottom();
    } catch (error) {
      debugPrint('Load messages error: $error');
    }
  }

  void _handleIncomingMessage(String rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage);

      if (decoded is! Map) return;

      final type = decoded['type']?.toString();

      if (type == 'connection_request' ||
          type == 'connection_accepted' ||
          type == 'connection_rejected') {
        return;
      }

      final message = Message.fromMap(
        Map<String, dynamic>.from(decoded),
      );

      if (message.id.isEmpty) return;

      if (_messages.any((item) => item.id == message.id)) {
        return;
      }

      if (!mounted) return;

      setState(() {
        _messages.add(message);
      });

      LocalStorageService.saveMessage(message);
      _scrollToBottom();
    } catch (error) {
      debugPrint('Incoming message error: $error');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _sending) return;

    if (!_bluetooth.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('আগে অন্তত একটি ডিভাইস সংযুক্ত করুন।'),
        ),
      );
      return;
    }

    final message = Message(
      id: _uuid.v4(),
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
      _messageController.clear();
    });

    try {
      await LocalStorageService.saveMessage(message);

      await _bluetooth.sendMessage(
        jsonEncode(message.toMap()),
      );

      _scrollToBottom();
    } catch (error) {
      debugPrint('Send message error: $error');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('বার্তা পাঠানো যায়নি: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openDevices() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const BluetoothDevicesScreen(),
      ),
    );

    if (mounted) setState(() {});
  }

  Future<void> _openConnectionScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ConnectionScreen(),
      ),
    );

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
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
            tooltip: 'Bluetooth ডিভাইস',
            onPressed: _openDevices,
            icon: const Icon(Icons.devices),
          ),
          IconButton(
            tooltip: 'সংযোগ',
            onPressed: _openConnectionScreen,
            icon: const Icon(Icons.bluetooth_connected),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  _bluetooth.isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: _bluetooth.isConnected
                      ? Colors.green
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _bluetooth.isConnected
                        ? 'সংযুক্ত ডিভাইস: '
                            '${_bluetooth.connectedDeviceCount}'
                        : 'কোনো ডিভাইস সংযুক্ত নেই',
                  ),
                ),
                TextButton(
                  onPressed: _openDevices,
                  child: const Text('ডিভাইস'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'এখনো কোনো বার্তা নেই।\n'
                      'Bluetooth ডিভাইস সংযুক্ত করে বার্তা পাঠান।',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
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
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                          ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMine
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMine) ...[
                                Text(
                                  message.senderName,
                                  style: theme.textTheme.labelLarge,
                                ),
                                if (message.senderLocation.isNotEmpty)
                                  Text(
                                    message.senderLocation,
                                    style: theme.textTheme.labelSmall,
                                  ),
                                const SizedBox(height: 4),
                              ],
                              Text(message.text),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  _formatTime(message.createdAt),
                                  style: theme.textTheme.labelSmall,
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
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'বার্তা লিখুন...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _sendMessage,
                    tooltip: 'বার্তা পাঠান',
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

  String _formatTime(DateTime time) {
    final localTime = time.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }
}
