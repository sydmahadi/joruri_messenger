import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'models/message.dart';
import 'screens/connection_screen.dart';
import 'screens/home_screen.dart';
import 'services/bluetooth_service.dart';
import 'services/device_service.dart';
import 'services/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalStorageService.init();
  await DeviceService.initialize();

  runApp(const JoruriMessengerApp());
}

class JoruriMessengerApp extends StatelessWidget {
  const JoruriMessengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'জরুরি মেসেঞ্জার',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        brightness: Brightness.light,
      ),
      home: const HomeScreen(),
      routes: {
        '/chat': (_) => const ChatScreen(),
        '/connection': (_) => const ConnectionScreen(),
      },
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController =
      TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final BluetoothService _bluetoothService = BluetoothService();

  final List<Message> _messages = [];

  StreamSubscription<String>? _messageSubscription;
  StreamSubscription<String>? _connectionSubscription;

  bool _isLoading = true;
  bool _isSending = false;
  bool _showingConnectionRequest = false;
  bool _connectionApproved = false;

  @override
  void initState() {
    super.initState();

    _loadMessages();
    _listenForBluetoothMessages();
    _listenForConnectionStatus();
  }

  Future<void> _loadMessages() async {
    final savedMessages = LocalStorageService.getMessages();

    final chatMessages = savedMessages.where((message) {
      return message.messageType == 'chat' &&
          !message.senderName.startsWith('ঘোষণা • ');
    }).toList();

    if (!mounted) return;

    setState(() {
      _messages
        ..clear()
        ..addAll(chatMessages);

      _isLoading = false;
    });

    _scrollToBottom();
  }

  void _listenForBluetoothMessages() {
    _messageSubscription = _bluetoothService.messageStream.listen(
      _receiveBluetoothMessage,
      onError: (Object error) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bluetooth মেসেজ গ্রহণে সমস্যা: $error'),
          ),
        );
      },
    );
  }

  void _listenForConnectionStatus() {
    _connectionSubscription =
        _bluetoothService.connectionStream.listen((event) {
      if (!mounted) return;

      if (event == 'connection_accepted') {
        setState(() {
          _connectionApproved = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('সংযোগের অনুরোধ গ্রহণ করা হয়েছে।'),
          ),
        );
      } else if (event == 'connection_rejected' ||
          event == 'disconnected' ||
          event == 'server_disconnected') {
        setState(() {
          _connectionApproved = false;
        });
      }
    });
  }

  Future<void> _receiveBluetoothMessage(String rawMessage) async {
    final text = rawMessage.trim();

    if (text.isEmpty) return;

    // সংযোগের অনুরোধ গ্রহণ বা প্রত্যাখ্যানের ব্যবস্থা।
    try {
      final decoded = jsonDecode(text);

      if (decoded is Map) {
        final data = Map<String, dynamic>.from(decoded);

        if (data['type'] == 'connection_request') {
          final requesterId = data['senderId']?.toString() ?? '';
          final requesterName =
              data['senderName']?.toString() ?? 'অজানা ফোন';

          if (requesterId.isNotEmpty) {
            await _showConnectionRequestDialog(
              requesterId: requesterId,
              requesterName: requesterName,
            );
          }

          return;
        }

        // Connection protocol message যেন সাধারণ চ্যাটে না আসে।
        if (data['type'] == 'connection_accepted' ||
            data['type'] == 'connection_rejected') {
          return;
        }
      }
    } catch (_) {
      // নিচে সাধারণ মেসেজের নিয়ম চলবে।
    }

    Message? receivedMessage;
    bool isStructuredMessage = false;

    try {
      final decoded = jsonDecode(text);

      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);

        if (map.containsKey('id') &&
            map.containsKey('senderId') &&
            map.containsKey('text') &&
            map.containsKey('createdAt')) {
          isStructuredMessage = true;

          try {
            receivedMessage = Message.fromMap(map);
          } catch (_) {
            return;
          }
        }
      }
    } catch (_) {
      // ভুল JSON সাধারণ টেক্সট হিসেবে গ্রহণ করা হবে না।
      if (text.startsWith('{') || text.startsWith('[')) {
        return;
      }
    }

    if (isStructuredMessage && receivedMessage == null) {
      return;
    }

    // পুরোনো সংস্করণের সাধারণ টেক্সট মেসেজ।
    receivedMessage ??= Message(
      id: const Uuid().v4(),
      senderId: 'bluetooth-peer',
      senderName: 'Bluetooth ফোন',
      text: text,
      createdAt: DateTime.now(),
      messageType: 'chat',
    );

    final message = receivedMessage;

    if (message.senderId == DeviceService.deviceId) {
      return;
    }

    if (message.messageType == 'private') {
      if (message.recipientId == null ||
          message.recipientId != DeviceService.deviceId) {
        return;
      }
    }

    final savedMessages = LocalStorageService.getMessages();

    final alreadyExists = savedMessages.any(
      (saved) => saved.id == message.id,
    );

    if (alreadyExists) return;

    try {
      await LocalStorageService.saveMessage(message);

      if (!mounted) return;

      if (message.messageType != 'chat' ||
          message.senderName.startsWith('ঘোষণা • ')) {
        return;
      }

      setState(() {
        _messages.add(message);

        _messages.sort(
          (a, b) => a.createdAt.compareTo(b.createdAt),
        );
      });

      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('আসা মেসেজ সেভ করা যায়নি: $error'),
        ),
      );
    }
  }

  Future<void> _showConnectionRequestDialog({
    required String requesterId,
    required String requesterName,
  }) async {
    if (!mounted || _showingConnectionRequest) return;

    _showingConnectionRequest = true;

    try {
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('সংযোগের অনুরোধ'),
            content: Text(
              '$requesterName আপনার ফোনের সঙ্গে '
              'সংযুক্ত হতে চায়। আপনি কি অনুমতি দেবেন?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('প্রত্যাখ্যান করুন'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('গ্রহণ করুন'),
              ),
            ],
          );
        },
      );

      if (!mounted || accepted == null) return;

      await _bluetoothService.respondToConnectionRequest(
        accepted: accepted,
        requesterId: requesterId,
      );

      if (!mounted) return;

      setState(() {
        _connectionApproved = accepted;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accepted
                ? 'অনুরোধ গ্রহণ করা হয়েছে।'
                : 'অনুরোধ প্রত্যাখ্যান করা হয়েছে।',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('অনুরোধের উত্তর পাঠানো যায়নি: $error'),
        ),
      );
    } finally {
      _showingConnectionRequest = false;
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();

    _messageController.dispose();
    _scrollController.dispose();

    // BluetoothService singleton হওয়ায় এখানে dispose করা যাবে না।
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;

    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    if (!_bluetoothService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'আগে অন্য ফোনের সংযোগের অনুরোধ গ্রহণ করাতে হবে।',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    final message = Message(
      id: const Uuid().v4(),
      senderId: DeviceService.deviceId,
      senderName: DeviceService.deviceName,
      text: text,
      createdAt: DateTime.now(),
      messageType: 'chat',
    );

    try {
      await LocalStorageService.saveMessage(message);

      if (!mounted) return;

      setState(() {
        _messages.add(message);
      });

      _messageController.clear();
      _scrollToBottom();

      try {
        await _bluetoothService.sendMessage(
          jsonEncode(message.toMap()),
        );
      } catch (error) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'মেসেজ ফোনে সেভ হয়েছে, কিন্তু Bluetooth-এ '
              'পাঠানো যায়নি। সংযোগ পরীক্ষা করুন।',
            ),
            action: SnackBarAction(
              label: 'বিস্তারিত',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$error')),
                );
              },
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('মেসেজ সেভ করা যায়নি: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
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

  String _shortDeviceId(String id) {
    if (id.length <= 8) return id;
    return id.substring(0, 8);
  }

  void _openConnectionScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ConnectionScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothConnected = _bluetoothService.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'বর্তমান চ্যাট',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Connection',
            onPressed: _openConnectionScreen,
            icon: const Icon(Icons.link),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!bluetoothConnected)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                child: Text(
                  _connectionApproved
                      ? 'সংযোগের অবস্থা যাচাই হচ্ছে...'
                      : 'চ্যাট করতে আগে অনুমোদিত Bluetooth সংযোগ করুন।',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _messages.isEmpty
                      ? const _EmptyChatView()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(
                            12,
                            16,
                            12,
                            16,
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];

                            final isMine =
                                message.senderId ==
                                DeviceService.deviceId;

                            return _MessageBubble(
                              message: message,
                              deviceId: _shortDeviceId(
                                message.senderId,
                              ),
                              isMine: isMine,
                            );
                          },
                        ),
            ),
            _MessageInputBar(
              controller: _messageController,
              isSending: _isSending,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChatView extends StatelessWidget {
  const _EmptyChatView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            const Text(
              'কোনো মেসেজ নেই',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connection থেকে কাছাকাছি ফোনের '
              'সাথে সংযোগ করুন।',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final String deviceId;
  final bool isMine;

  const _MessageBubble({
    required this.message,
    required this.deviceId,
    required this.isMine,
  });

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment:
          isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isMine
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 16,
                height: 1.4,
                color: isMine
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${isMine ? 'আমি' : message.senderName}: '
              '$deviceId • ${_formatTime(message.createdAt)}',
              style: TextStyle(
                fontSize: 10,
                color: isMine
                    ? theme.colorScheme.onPrimary
                        .withValues(alpha: 0.75)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _MessageInputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'মেসেজ লিখুন...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: isSending ? null : onSend,
            icon: isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send),
            iconSize: 22,
          ),
        ],
      ),
    );
  }
}
