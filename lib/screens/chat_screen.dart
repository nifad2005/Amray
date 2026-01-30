import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/p2p_service.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String peerAddress;
  const ChatScreen({super.key, required this.peerAddress});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Map<String, dynamic>> _messages = [];
  bool _isPeerTyping = false;
  bool _isPeerOnline = false;
  String _peerName = "";
  String? _peerImageBase64;
  
  Timer? _typingTimer;
  Timer? _onlineTimer;
  StreamSubscription? _messageSub;
  StreamSubscription? _presenceSub;
  StreamSubscription? _callSub;

  @override
  void initState() {
    super.initState();
    _peerName = 'বন্ধু ${widget.peerAddress.substring(widget.peerAddress.length - 6)}';
    _loadHistory();
    
    _messageSub = P2PService().messageStream.listen((message) {
      if (mounted && (message['peerId'] == widget.peerAddress || message['senderId'] == widget.peerAddress)) {
        setState(() {
          _messages.add(message);
          if (message['senderName'] != null && message['senderName'] != "বন্ধু") {
            _peerName = message['senderName'];
          }
          if (message['senderImage'] != null) {
            _peerImageBase64 = message['senderImage'];
          }
        });
      }
    });

    _presenceSub = P2PService().presenceStream.listen((presence) {
      if (mounted && presence['senderId'] == widget.peerAddress) {
        setState(() {
          if (presence['senderName'] != null && presence['senderName'] != "বন্ধু") {
            _peerName = presence['senderName'];
          }
          if (presence['senderImage'] != null) {
            _peerImageBase64 = presence['senderImage'];
          }
        });

        if (presence['status'] == 'typing') {
          setState(() => _isPeerTyping = true);
          _typingTimer?.cancel();
          _typingTimer = Timer(const Duration(seconds: 3), () => setState(() => _isPeerTyping = false));
        } else if (presence['status'] == 'online') {
          setState(() => _isPeerOnline = true);
          _onlineTimer?.cancel();
          _onlineTimer = Timer(const Duration(seconds: 35), () => setState(() => _isPeerOnline = false));
        }
      }
    });

    _callSub = P2PService().callSignalingStream.listen((data) {
      if (mounted && data.containsKey('offer') && data['senderId'] == widget.peerAddress) {
        final offer = RTCSessionDescription(data['offer']['sdp'], data['offer']['type']);
        _showIncomingCallDialog(data['senderId'], data['isVideo'] ?? true, offer);
      }
    });
  }

  void _showIncomingCallDialog(String senderId, bool isVideo, RTCSessionDescription offer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(isVideo ? Icons.videocam : Icons.call, color: const Color(0xFF2E7D32)),
            const SizedBox(width: 10),
            Text(isVideo ? 'Video Call' : 'Audio Call', style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text('Incoming call from $_peerName', 
          style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child: const Text('Decline', style: TextStyle(color: Colors.redAccent)),
            onPressed: () {
              P2PService().sendCallSignaling(senderId, {'type': 'hangup'});
              Navigator.pop(context);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            child: const Text('Accept', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => CallScreen(
                  peerId: senderId, 
                  isVideo: isVideo, 
                  isIncoming: true, 
                  remoteOffer: offer
                ),
              ));
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _presenceSub?.cancel();
    _callSub?.cancel();
    _typingTimer?.cancel();
    _onlineTimer?.cancel();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await P2PService().getChatHistory(widget.peerAddress);
    if (mounted) {
      setState(() {
        _messages = history;
        // Extract peer info from history if available
        for (var msg in history.reversed) {
          if (!msg['isMe']) {
            if (msg['senderName'] != null) _peerName = msg['senderName'];
            if (msg['senderImage'] != null) _peerImageBase64 = msg['senderImage'];
            break;
          }
        }
      });
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    P2PService().sendMessage(widget.peerAddress, text);
    _messageController.clear();
  }

  void _handleKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      final bool isControlPressed = event.isControlPressed;
      final bool isShiftPressed = event.isShiftPressed;

      if (!isControlPressed && !isShiftPressed) {
        // Only Enter -> Send
        _sendMessage();
      } else {
        // Control/Shift + Enter -> New Line
        final text = _messageController.text;
        final selection = _messageController.selection;
        final newText = text.replaceRange(selection.start, selection.end, "\n");
        _messageController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start + 1),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF2E7D32),
              backgroundImage: _peerImageBase64 != null 
                  ? MemoryImage(base64Decode(_peerImageBase64!)) 
                  : null,
              child: _peerImageBase64 == null ? const Icon(Icons.person, size: 20, color: Colors.white) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_peerName, 
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    overflow: TextOverflow.ellipsis),
                  Text(_isPeerTyping ? 'typing...' : (_isPeerOnline ? 'online' : 'offline'),
                    style: TextStyle(color: _isPeerTyping ? Colors.yellowAccent : (_isPeerOnline ? Colors.lightGreenAccent : Colors.white70), fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.call), onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (context) => CallScreen(peerId: widget.peerAddress, isVideo: false, isIncoming: false),
          ))),
          IconButton(icon: const Icon(Icons.videocam), onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (context) => CallScreen(peerId: widget.peerAddress, isVideo: true, isIncoming: false),
          ))),
        ],
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
                final bool isMe = msg['isMe'] == true;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF2E7D32) : const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(msg['text'] ?? "", style: const TextStyle(color: Colors.white)),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            color: const Color(0xFF1E1E1E),
            child: Row(
              children: [
                Expanded(
                  child: RawKeyboardListener(
                    focusNode: FocusNode(), // Separate focus node for the listener
                    onKey: _handleKey,
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      onChanged: (v) => P2PService().setTyping(widget.peerAddress),
                      style: const TextStyle(color: Colors.white),
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'বার্তা লিখুন...', 
                        hintStyle: TextStyle(color: Colors.white54), 
                        border: InputBorder.none
                      ),
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: Color(0xFF2E7D32)), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
