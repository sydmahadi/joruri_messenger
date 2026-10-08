import 'package:flutter/material.dart';

import 'screens/bluetooth_devices_screen.dart';
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
      home: const ChatScreen(),
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

  final ScrollController _scrollController =
      ScrollController();

  final List<ChatMessage> _messages = [];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();

    if (text.isEmpty) {
      return;
    }

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          senderId: DeviceService.deviceId,
          isMine: true,
          time: DateTime.now(),
        ),
      );
    });

    _messageController.clear();

    _scrollToBottom();

    // Bluetooth / Wi-Fi / Hotspot message sending
    // পরের ধাপে এখানে যুক্ত করা হবে।
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _shortDeviceId(String id) {
    if (id.length <= 8) {
      return id;
    }

    return id.substring(0, 8);
  }

  void _openConnectionScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BluetoothDevicesScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'জরুরি মেসেঞ্জার',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Connection',
            onPressed: _openConnectionScreen,
            icon: const Icon(
              Icons.link,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
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
                        final message =
                            _messages[index];

                        return _MessageBubble(
                          message: message,
                          deviceId: _shortDeviceId(
                            message.senderId,
                          ),
                        );
                      },
                    ),
            ),

            _MessageInputBar(
              controller: _messageController,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final String senderId;
  final bool isMine;
  final DateTime time;

  const ChatMessage({
    required this.text,
    required this.senderId,
    required this.isMine,
    required this.time,
  });
}

class _EmptyChatView extends StatelessWidget {
  const _EmptyChatView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 72,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
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
              'Connection বাটন থেকে কাছাকাছি\n'
              'ডিভাইসের সাথে সংযোগ করুন।',
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
  final ChatMessage message;
  final String deviceId;

  const _MessageBubble({
    required this.message,
    required this.deviceId,
  });

  String _formatTime(DateTime time) {
    final hour =
        time.hour.toString().padLeft(2, '0');

    final minute =
        time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    return Align(
      alignment: message.isMine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context).size.width *
                  0.78,
        ),
        margin: const EdgeInsets.only(
          bottom: 10,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: message.isMine
              ? theme.colorScheme.primary
              : theme.colorScheme
                  .surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft:
                const Radius.circular(16),
            topRight:
                const Radius.circular(16),
            bottomLeft:
                Radius.circular(
              message.isMine ? 16 : 4,
            ),
            bottomRight:
                Radius.circular(
              message.isMine ? 4 : 16,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              message.isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 16,
                height: 1.4,
                color: message.isMine
                    ? theme.colorScheme
                        .onPrimary
                    : theme.colorScheme
                        .onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${message.isMine ? 'আমার ID' : 'Phone ID'}: $deviceId  •  ${_formatTime(message.time)}',
              style: TextStyle(
                fontSize: 10,
                color: message.isMine
                    ? theme.colorScheme
                        .onPrimary
                        .withValues(
                          alpha: 0.75,
                        )
                    : theme.colorScheme
                        .onSurfaceVariant,
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
  final VoidCallback onSend;

  const _MessageInputBar({
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        10,
        8,
        10,
        10,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context)
                .dividerColor,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textInputAction:
                  TextInputAction.newline,
              decoration:
                  InputDecoration(
                hintText:
                    'মেসেজ লিখুন...',
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    24,
                  ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) {
                onSend();
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: onSend,
            icon: const Icon(
              Icons.send,
            ),
            iconSize: 22,
          ),
        ],
      ),
    );
  }
}
