import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:translator/translator.dart';
import '../services/p2p_service.dart';

class ChatScreen extends StatefulWidget {
  final String peerAddress;
  const ChatScreen({super.key, required this.peerAddress});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GoogleTranslator _translator = GoogleTranslator();
  
  List<Map<String, dynamic>> _messages = [];
  bool _isPeerTyping = false;
  bool _isPeerOnline = false;
  String _peerName = "";
  String? _peerImageBase64;
  
  // Translation States
  bool _isOutgoingTranslationEnabled = false;
  String _targetLangCode = 'en'; // Default target for outgoing
  final Map<int, String?> _translatedMessages = {}; // Local cache for received translations
  bool _isTranslating = false;

  Timer? _typingTimer;
  Timer? _onlineTimer;
  StreamSubscription? _messageSub;
  StreamSubscription? _presenceSub;

  final List<Map<String, String>> _languages = [
    {'code': 'bn', 'name': 'Bengali'},
    {'code': 'en', 'name': 'English'},
    {'code': 'ar', 'name': 'Arabic'},
    {'code': 'hi', 'name': 'Hindi'},
    {'code': 'es', 'name': 'Spanish'},
    {'code': 'fr', 'name': 'French'},
  ];

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
  }

  // --- Translation Logic ---

  Future<void> _translateAndSend() async {
    String text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_isOutgoingTranslationEnabled) {
      setState(() => _isTranslating = true);
      try {
        var translation = await _translator.translate(text, to: _targetLangCode);
        text = translation.text;
      } catch (e) {
        debugPrint("Translation error: $e");
      }
      setState(() => _isTranslating = false);
    }

    P2PService().sendTextMessage(widget.peerAddress, text);
    _messageController.clear();
  }

  Future<void> _translateReceivedMessage(int index, String text) async {
    if (_translatedMessages.containsKey(index)) {
      setState(() => _translatedMessages.remove(index));
      return;
    }

    setState(() => _isTranslating = true);
    try {
      // Auto detect to Bengali (or user's preferred lang)
      var translation = await _translator.translate(text, to: 'bn'); 
      setState(() => _translatedMessages[index] = translation.text);
    } catch (e) {
      debugPrint("Translation error: $e");
    }
    setState(() => _isTranslating = false);
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _presenceSub?.cancel();
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
        for (var msg in history.reversed) {
          // Safety Check: Avoid Null errors on 'isMe'
          final bool isMe = msg['isMe'] == true;
          if (!isMe) {
            if (msg['senderName'] != null) _peerName = msg['senderName'];
            if (msg['senderImage'] != null) _peerImageBase64 = msg['senderImage'];
            break;
          }
        }
      });
    }
  }

  void _handleKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      final bool isControlPressed = event.isControlPressed;
      final bool isShiftPressed = event.isShiftPressed;

      if (!isControlPressed && !isShiftPressed) {
        _translateAndSend();
      } else {
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
        actions: const [],
      ),
      body: Column(
        children: [
          if (_isTranslating) const LinearProgressIndicator(backgroundColor: Colors.transparent, color: Color(0xFF2E7D32), minHeight: 2),
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(15),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msgIndex = _messages.length - 1 - index;
                final msg = _messages[msgIndex];
                // Safety Check: Handle null 'isMe' safely
                final bool isMe = msg['isMe'] == true;
                final String text = msg['text'] ?? "";
                final String? translatedText = _translatedMessages[msgIndex];

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onLongPress: () => _translateReceivedMessage(msgIndex, text),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFF2E7D32) : const Color(0xFF2C2C2C),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(text, style: const TextStyle(color: Colors.white)),
                              if (translatedText != null) ...[
                                const Divider(color: Colors.white24),
                                Text(translatedText, style: const TextStyle(color: Colors.yellowAccent, fontSize: 13, fontStyle: FontStyle.italic)),
                              ]
                            ],
                          ),
                        ),
                      ),
                      if (!isMe && translatedText == null)
                        Padding(
                          padding: const EdgeInsets.only(left: 5, bottom: 8),
                          child: InkWell(
                            onTap: () => _translateReceivedMessage(msgIndex, text),
                            child: const Text('Translate', style: TextStyle(color: Colors.white54, fontSize: 10)),
                          ),
                        )
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Translation Controls for Outgoing
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            color: const Color(0xFF1E1E1E),
            child: Row(
              children: [
                const Icon(Icons.g_translate, size: 16, color: Colors.white54),
                const SizedBox(width: 8),
                const Text('Auto-translate outgoing:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: _isOutgoingTranslationEnabled,
                    onChanged: (val) => setState(() => _isOutgoingTranslationEnabled = val),
                    activeColor: const Color(0xFF2E7D32),
                  ),
                ),
                if (_isOutgoingTranslationEnabled)
                  DropdownButton<String>(
                    value: _targetLangCode,
                    dropdownColor: const Color(0xFF1E1E1E),
                    underline: const SizedBox(),
                    items: _languages.map((l) => DropdownMenuItem(
                      value: l['code'],
                      child: Text(l['name']!, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    )).toList(),
                    onChanged: (val) => setState(() => _targetLangCode = val!),
                  ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(10),
            color: const Color(0xFF1E1E1E),
            child: Row(
              children: [
                Expanded(
                  child: RawKeyboardListener(
                    focusNode: FocusNode(),
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
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF2E7D32)), 
                  onPressed: _translateAndSend
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
