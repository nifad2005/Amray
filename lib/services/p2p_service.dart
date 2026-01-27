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
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  final _peerDiscoveryController = StreamController<String>.broadcast();
  Stream<String> get peerDiscoveryStream => _peerDiscoveryController.stream;

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  ConnectionStatus _currentStatus = ConnectionStatus.disconnected;
  ConnectionStatus get currentStatus => _currentStatus;

  bool _isListening = false;
  List<String> friends = [];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load or create my ID
    _myId = prefs.getString('my_id') ?? "amray_${const Uuid().v4().substring(0, 8)}";
    await prefs.setString('my_id', _myId);
    print("My Unique ID: $_myId");

    // Load friends
    friends = prefs.getStringList('friends') ?? [];

    if (_isListening) return;
    _updateStatus(ConnectionStatus.connecting);
    _isListening = true;
    _startListening();
  }

  void _updateStatus(ConnectionStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  Future<void> addFriend(String friendId) async {
    if (!friends.contains(friendId)) {
      friends.add(friendId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('friends', friends);
      _peerDiscoveryController.add(friendId); // Notify UI
      print("Friend added: $friendId");
    }
  }

  void _startListening() async {
    final url = Uri.parse("https://ntfy.sh/$_myId/json");
    print("Listening for messages on: https://ntfy.sh/$_myId");
    
    try {
      final request = http.Request("GET", url);
      final response = await http.Client().send(request);
      _updateStatus(ConnectionStatus.connected);

      response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.trim().isEmpty) return;
        
        try {
          final data = jsonDecode(line);
          if (data['event'] != 'message' || data['message'] == null) return;
          
          final Map<String, dynamic> payload = jsonDecode(data['message']);
          final String senderId = payload['senderId'];
          final String type = payload['type'] ?? 'message';

          if (type == 'handshake') {
            print("Handshake received from $senderId");
            addFriend(senderId);
          } else {
            print("Message received: ${payload['text']}");
            _messageController.add({
              'senderId': senderId,
              'text': payload['text'],
              'isMe': false,
            });
          }
        } catch (e) {
          print("Error parsing incoming line: $e");
        }
      }, onDone: () {
        print("Listening stream closed, reconnecting...");
        _isListening = false;
        Future.delayed(const Duration(seconds: 2), () => _startListening());
      }, onError: (e) {
        print("Stream error: $e");
        _isListening = false;
        _updateStatus(ConnectionStatus.error);
      });
    } catch (e) {
      print("Failed to start listening: $e");
      _isListening = false;
      _updateStatus(ConnectionStatus.error);
      Future.delayed(const Duration(seconds: 5), () => _startListening());
    }
  }

  String getMyAddress() => _myId;

  void sendHandshake(String remoteId) {
    print("Sending handshake to $remoteId");
    addFriend(remoteId);
    _sendRaw(remoteId, {'senderId': _myId, 'type': 'handshake'});
  }

  void sendMessage(String remoteId, String message) {
    print("Sending message to $remoteId: $message");
    _sendRaw(remoteId, {'senderId': _myId, 'text': message, 'type': 'message'});
    _messageController.add({'senderId': _myId, 'text': message, 'isMe': true});
  }

  Future<void> _sendRaw(String topic, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse("https://ntfy.sh/$topic"),
        body: jsonEncode(data),
        headers: {
          'Content-Type': 'application/json',
          'Title': 'Amray Message',
        },
      );
      if (response.statusCode == 200) {
        print("Message sent successfully to $topic");
      } else {
        print("Failed to send message. Status: ${response.statusCode}");
      }
    } catch (e) {
      print("Error in _sendRaw: $e");
    }
  }
}
