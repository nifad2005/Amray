import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class P2PService {
  static final P2PService _instance = P2PService._internal();
  factory P2PService() => _instance;
  P2PService._internal();

  late String _myId;
  String _myName = "User";
  String? _myImageBase64;
  
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  final _peerDiscoveryController = StreamController<String>.broadcast();
  Stream<String> get peerDiscoveryStream => _peerDiscoveryController.stream;

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  final _presenceController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get presenceStream => _presenceController.stream;

  final _callSignalingController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get callSignalingStream => _callSignalingController.stream;

  ConnectionStatus _currentStatus = ConnectionStatus.disconnected;
  ConnectionStatus get currentStatus => _currentStatus;

  bool _isListening = false;
  List<String> friends = [];
  Timer? _heartbeatTimer;
  http.Client? _client;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _myId = prefs.getString('my_id') ?? "amray_${const Uuid().v4().substring(0, 8)}";
    await prefs.setString('my_id', _myId);
    
    _myName = prefs.getString('user_name') ?? "বন্ধু";
    _myImageBase64 = prefs.getString('profile_image_base64'); // We'll store a small base64 version for P2P
    
    friends = prefs.getStringList('friends') ?? [];

    if (_isListening) return;
    _startListening();
    _startHeartbeat();
  }

  void _updateStatus(ConnectionStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_currentStatus == ConnectionStatus.connected) {
        for (var friendId in friends) {
          _sendPresence(friendId, 'online');
        }
      }
    });
  }

  Future<void> addFriend(String? friendId) async {
    if (friendId == null || friendId.isEmpty || friendId == _myId) return;
    if (!friends.contains(friendId)) {
      friends.add(friendId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('friends', friends);
      _peerDiscoveryController.add(friendId);
      print("Friend added successfully: $friendId");
    }
  }

  void _startListening() async {
    if (_isListening) return;
    _isListening = true;
    _updateStatus(ConnectionStatus.connecting);

    _client?.close();
    _client = http.Client();
    final url = Uri.parse("https://ntfy.sh/$_myId/json");

    try {
      final request = http.Request("GET", url);
      final response = await _client!.send(request);
      
      if (response.statusCode == 200) {
        _updateStatus(ConnectionStatus.connected);
      }

      response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) async {
        if (line.trim().isEmpty) return;
        try {
          final data = jsonDecode(line);
          if (data['event'] != 'message' || data['message'] == null) return;
          
          final Map<String, dynamic> payload = jsonDecode(data['message']);
          final String? senderId = payload['senderId'];
          final String type = payload['type'] ?? 'message';

          if (senderId == null || senderId == _myId) return;

          if (type == 'call_signaling') {
            _callSignalingController.add(payload);
          } else if (type == 'presence') {
            _presenceController.add({
              'senderId': senderId, 
              'status': payload['status'],
              'senderName': payload['senderName'],
              'senderImage': payload['senderImage'],
            });
          } else if (type == 'handshake') {
            await addFriend(senderId);
          } else if (type == 'message') {
            final String text = payload['text']?.toString().trim() ?? "";
            if (text.isNotEmpty) {
              final msg = {
                'senderId': senderId,
                'peerId': senderId,
                'senderName': payload['senderName'] ?? "বন্ধু",
                'senderImage': payload['senderImage'],
                'text': text,
                'isMe': false,
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              };
              _messageController.add(msg);
              _saveMessage(senderId, msg);
            }
          }
        } catch (e) {
          print("Payload processing error: $e");
        }
      }, onDone: () {
        _isListening = false;
        _updateStatus(ConnectionStatus.disconnected);
        Future.delayed(const Duration(seconds: 3), () => _startListening());
      }, onError: (e) {
        _isListening = false;
        _updateStatus(ConnectionStatus.error);
        Future.delayed(const Duration(seconds: 5), () => _startListening());
      });
    } catch (e) {
      _isListening = false;
      _updateStatus(ConnectionStatus.error);
      Future.delayed(const Duration(seconds: 5), () => _startListening());
    }
  }

  Future<void> _saveMessage(String peerId, Map<String, dynamic> msg) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = 'chat_$peerId';
    List<String> history = prefs.getStringList(key) ?? [];
    history.add(jsonEncode(msg));
    if (history.length > 100) history.removeAt(0);
    await prefs.setStringList(key, history);
  }

  Future<List<Map<String, dynamic>>> getChatHistory(String peerId) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = 'chat_$peerId';
    List<String> history = prefs.getStringList(key) ?? [];
    return history.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  void sendCallSignaling(String remoteId, Map<String, dynamic> signal) {
    _sendRaw(remoteId, {
      'senderId': _myId, 
      'senderName': _myName,
      'type': 'call_signaling', 
      ...signal
    });
  }

  void sendMessage(String remoteId, String message) async {
    final text = message.trim();
    if (text.isEmpty) return;
    final msg = {
      'senderId': _myId, 
      'peerId': remoteId, 
      'text': text, 
      'isMe': true, 
      'timestamp': DateTime.now().millisecondsSinceEpoch
    };
    _messageController.add(msg);
    _saveMessage(remoteId, msg);
    _sendRaw(remoteId, {
      'senderId': _myId, 
      'senderName': _myName,
      'senderImage': _myImageBase64,
      'text': text, 
      'type': 'message'
    });
  }

  void _sendPresence(String remoteId, String status) {
    _sendRaw(remoteId, {
      'senderId': _myId, 
      'senderName': _myName,
      'senderImage': _myImageBase64,
      'type': 'presence', 
      'status': status
    });
  }

  void setTyping(String remoteId) => _sendPresence(remoteId, 'typing');

  String getMyAddress() => _myId;

  void sendHandshake(String remoteId) {
    addFriend(remoteId);
    _sendRaw(remoteId, {
      'senderId': _myId, 
      'senderName': _myName,
      'senderImage': _myImageBase64,
      'type': 'handshake'
    });
  }

  Future<void> _sendRaw(String topic, Map<String, dynamic> data) async {
    try {
      await http.post(
        Uri.parse("https://ntfy.sh/$topic"), 
        body: jsonEncode(data),
        headers: {'Title': 'Amray Signal'}
      );
    } catch (e) {
      print("Send error: $e");
    }
  }
}
