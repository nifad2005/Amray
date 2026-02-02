import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'mqtt_service.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class P2PService {
  static final P2PService _instance = P2PService._internal();
  factory P2PService() => _instance;
  P2PService._internal();

  // Core Identity
  late String _myId;
  String _myName = "বন্ধু";
  String? _myImageBase64;

  // Streams for UI communication
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _presenceController = StreamController<Map<String, dynamic>>.broadcast();
  final _peerDiscoveryController = StreamController<String>.broadcast();
  final _callSignalingController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get presenceStream => _presenceController.stream;
  Stream<String> get peerDiscoveryStream => _peerDiscoveryController.stream;
  Stream<Map<String, dynamic>> get callSignalingStream => _callSignalingController.stream;

  // Operational State
  ConnectionStatus _currentStatus = ConnectionStatus.disconnected;
  ConnectionStatus get currentStatus => _currentStatus;
  List<String> friends = [];
  final Map<String, DateTime> onlineFriends = {};
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  MqttService? _mqttService;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    _myId = prefs.getString('my_id') ?? "amray_${const Uuid().v4().substring(0, 8)}";
    await prefs.setString('my_id', _myId);
    
    _myName = prefs.getString('user_name') ?? "বন্ধু";
    _myImageBase64 = prefs.getString('profile_image_base64');
    friends = prefs.getStringList('friends') ?? [];
    
    _isInitialized = true;
    _connect();
  }

  void _updateStatus(ConnectionStatus status) {
    if (_currentStatus == status) return;
    _currentStatus = status;
    _statusController.add(status);
    print("[P2P Service] Global Status: $status");
  }

  void _connect() {
    _reconnectTimer?.cancel();
    _mqttService?.dispose();
    
    _updateStatus(ConnectionStatus.connecting);
    
    _mqttService = MqttService(myId: _myId);
    _mqttService!.onConnectedCallback = _handleConnected;
    _mqttService!.onDisconnectedCallback = _handleDisconnected;
    _mqttService!.connect();
    
    _mqttService!.incomingMessages.listen(_processIncomingPayload, 
      onError: (e) => print("[P2P Service] Data Stream Error: $e"));
  }

  void _handleConnected() {
    _updateStatus(ConnectionStatus.connected);
    _startMaintenanceTimers();
    // Announce presence to known friends
    for (var id in friends) {
      _sendPresence(id, 'online');
    }
  }

  void _handleDisconnected() {
    _updateStatus(ConnectionStatus.disconnected);
    _stopMaintenanceTimers();
    
    // Attempt exponential backoff or simple delayed retry
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_currentStatus != ConnectionStatus.connected) {
        print("[P2P Service] Attempting auto-reconnect...");
        _connect();
      }
    });
  }

  void _processIncomingPayload(Map<String, dynamic> payload) {
    final String? senderId = payload['senderId'];
    if (senderId == null || senderId == _myId) return;

    final String type = payload['type'] ?? 'message';

    switch (type) {
      case 'handshake':
        addFriend(senderId);
        sendHandshakeReply(senderId);
        break;
      case 'handshake_reply':
        addFriend(senderId);
        break;
      case 'presence':
        if (payload['status'] == 'online') onlineFriends[senderId] = DateTime.now();
        _presenceController.add(payload);
        break;
      case 'message':
        final msg = {
          ...payload,
          'isMe': false,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'peerId': senderId,
        };
        _messageController.add(msg);
        _saveToHistory(senderId, msg);
        break;
      case 'call_signaling':
        _callSignalingController.add(payload);
        break;
    }
  }

  // --- Public Methods ---

  void sendTextMessage(String remoteId, String text) {
    final payload = {
      'senderId': _myId,
      'senderName': _myName,
      'senderImage': _myImageBase64,
      'text': text,
      'type': 'message',
    };
    _mqttService?.publish("amray/user/$remoteId", payload);

    final localMsg = {
      ...payload,
      'isMe': true,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'peerId': remoteId,
    };
    _messageController.add(localMsg);
    _saveToHistory(remoteId, localMsg);
  }

  void sendHandshake(String remoteId) {
    addFriend(remoteId); // Optimistic add
    _mqttService?.publish("amray/user/$remoteId", {
      'senderId': _myId,
      'senderName': _myName,
      'senderImage': _myImageBase64,
      'type': 'handshake'
    });
  }

  void sendHandshakeReply(String remoteId) {
    _mqttService?.publish("amray/user/$remoteId", {
      'senderId': _myId,
      'senderName': _myName,
      'senderImage': _myImageBase64,
      'type': 'handshake_reply'
    });
  }

  void _sendPresence(String remoteId, String status) {
    _mqttService?.publish("amray/user/$remoteId", {
      'senderId': _myId,
      'senderName': _myName,
      'senderImage': _myImageBase64,
      'type': 'presence',
      'status': status,
    });
  }

  void setTyping(String remoteId) => _sendPresence(remoteId, 'typing');

  // --- Internals ---

  void _startMaintenanceTimers() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 40), (timer) {
      for (var id in friends) {
        _sendPresence(id, 'online');
      }
    });
  }

  void _stopMaintenanceTimers() {
    _heartbeatTimer?.cancel();
  }

  Future<void> addFriend(String? friendId) async {
    if (friendId == null || friendId.isEmpty || friendId == _myId || friends.contains(friendId)) return;
    friends.add(friendId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('friends', friends);
    _peerDiscoveryController.add(friendId);
  }

  bool isOnline(String friendId) {
    if (!onlineFriends.containsKey(friendId)) return false;
    return DateTime.now().difference(onlineFriends[friendId]!).inSeconds < 100;
  }

  Future<void> _saveToHistory(String peerId, Map<String, dynamic> msg) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_$peerId';
    final history = prefs.getStringList(key) ?? [];
    history.add(jsonEncode(msg));
    if (history.length > 150) history.removeAt(0);
    await prefs.setStringList(key, history);
  }

  Future<List<Map<String, dynamic>>> getChatHistory(String peerId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_$peerId';
    return (prefs.getStringList(key) ?? []).map((e) {
      try {
        return jsonDecode(e) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((m) => m.isNotEmpty).toList();
  }

  String getMyAddress() => _myId;

  void dispose() {
    _messageController.close();
    _statusController.close();
    _presenceController.close();
    _peerDiscoveryController.close();
    _callSignalingController.close();
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _mqttService?.dispose();
  }
}
