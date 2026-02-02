import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_server_client/mqtt_server_client.dart';

class MqttService {
  final String _broker = 'broker.emqx.io';
  final String _clientId;
  final String _topic;
  MqttServerClient? _client;
  Function? onConnectedCallback;
  Function? onDisconnectedCallback;
  bool _isDisposed = false;

  final _incomingMessageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get incomingMessages => _incomingMessageController.stream;

  MqttService({required String myId}) 
      : _clientId = 'amray_client_$myId',
        _topic = 'amray/user/$myId';

  Future<void> connect() async {
    if (_isDisposed) return;
    
    _client = MqttServerClient(_broker, _clientId);
    _client!.port = 1883;
    _client!.keepAlivePeriod = 60;
    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.logging(on: false);

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(_clientId)
        .startClean()
        .withWillTopic('amray/presence/$_clientId')
        .withWillMessage(jsonEncode({'status': 'offline'}))
        .withWillQos(MqttQos.atLeastOnce);
    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect();
    } catch (e) {
      debugPrint('[MQTT Engine] Connection failed: $e');
      _onDisconnected();
    }

    _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      if (_isDisposed) return;
      try {
        final MqttPublishMessage recMessage = c[0].payload as MqttPublishMessage;
        final List<int> messageBytes = recMessage.payload.message;
        
        if (messageBytes.isEmpty) return;

        // Decode bytes to string
        String payloadString = utf8.decode(messageBytes, allowMalformed: true);
        
        // --- CRITICAL FIX: Sanitize the string ---
        // Remove null bytes and other control characters that break jsonDecode
        payloadString = payloadString.replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), '');
        payloadString = payloadString.trim();
        
        if (payloadString.isEmpty) return;

        // Now attempt to parse the cleaned JSON
        final dynamic decoded = jsonDecode(payloadString);
        if (decoded is Map<String, dynamic>) {
          _incomingMessageController.add(decoded);
        }
      } catch (e) {
        debugPrint('[MQTT Engine] Error processing incoming bytes: $e');
      }
    });
  }

  void _onConnected() {
    if (_isDisposed) return;
    debugPrint('[MQTT Engine] Connected successfully.');
    _client!.subscribe(_topic, MqttQos.atLeastOnce);
    onConnectedCallback?.call();
  }

  void _onDisconnected() {
    if (_isDisposed) return;
    debugPrint('[MQTT Engine] Connection lost.');
    onDisconnectedCallback?.call();
  }

  void publish(String topic, Map<String, dynamic> payload) {
    if (_isDisposed) return;
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      try {
        final builder = MqttClientPayloadBuilder();
        final String jsonString = jsonEncode(payload);
        builder.addString(jsonString);
        _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      } catch (e) {
        debugPrint('[MQTT Engine] Publish error: $e');
      }
    }
  }

  void dispose() {
    _isDisposed = true;
    _incomingMessageController.close();
    _client?.disconnect();
    _client = null;
  }
}
