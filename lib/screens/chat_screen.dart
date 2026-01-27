import 'package:flutter/material.dart';
import '../services/p2p_service.dart';

class ChatScreen extends StatefulWidget {
  final String peerAddress;
  const ChatScreen({super.key, required this.peerAddress});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    // Listening for incoming messages from P2PService
    P2PService().messageStream.listen((message) {
      if (mounted) {
        // Since P2PService already filters for 'isMe: false' for received messages
        // and provides the senderId, we just need to check if it's from our current peer
        if (message['senderId'] == widget.peerAddress) {
          setState(() {
            _messages.add({
              'text': message['text'],
              'isMe': false,
            });
          });
        } else if (message['senderId'] == P2PService().getMyAddress() && message['isMe'] == true) {
           // This handles messages sent from this device to show them in the UI
           // (though we also add them in _sendMessage, this ensures sync if needed)
           // To avoid duplicates, we'll rely on _sendMessage for 'isMe' messages for now.
        }
      }
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final text = _messageController.text.trim();
    P2PService().sendMessage(widget.peerAddress, text);

    setState(() {
      _messages.add({
        'text': text,
        'isMe': true,
      });
      _messageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('বন্ধু ${widget.peerAddress.substring(6, 12)}', 
          style: const TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: const Color(0xFF2E7D32),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(15),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[_messages.length - 1 - index];
                return Align(
                  alignment: msg['isMe'] ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    decoration: BoxDecoration(
                      color: msg['isMe'] ? const Color(0xFF2E7D32) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      msg['text'],
                      style: TextStyle(
                        color: msg['isMe'] ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'আপনার বার্তা লিখুন...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF2E7D32)),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
