import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/p2p_service.dart';

class CallScreen extends StatefulWidget {
  final String peerId;
  final bool isVideo;
  final bool isIncoming;
  final RTCSessionDescription? remoteOffer;

  const CallScreen({
    super.key,
    required this.peerId,
    this.isVideo = true,
    required this.isIncoming,
    this.remoteOffer,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isConnectionEstablished = false;
  StreamSubscription? _signalingSub;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ]
  };

  @override
  void initState() {
    super.initState();
    _initAndStart();
  }

  Future<void> _initAndStart() async {
    await _initRenderers();
    bool hasPermissions = await _requestPermissions();
    if (hasPermissions) {
      await _startCall();
      _listenForSignaling();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions denied. Cannot start call.')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      if (widget.isVideo) Permission.camera,
    ].request();
    
    return statuses.values.every((status) => status.isGranted);
  }

  void _listenForSignaling() {
    _signalingSub = P2PService().callSignalingStream.listen((data) {
      if (data['senderId'] == widget.peerId) {
        _handleSignaling(data);
      }
    });
  }

  Future<void> _startCall() async {
    _peerConnection = await createPeerConnection(_configuration);

    _peerConnection!.onIceCandidate = (candidate) {
      P2PService().sendCallSignaling(widget.peerId, {
        'candidate': candidate.toMap(),
      });
    };

    _peerConnection!.onAddStream = (stream) {
      _remoteRenderer.srcObject = stream;
      if (mounted) setState(() => _isConnectionEstablished = true);
    };

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': widget.isVideo ? {
        'facingMode': 'user',
        'width': 640,
        'height': 480,
      } : false,
    });

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    _localRenderer.srcObject = _localStream;
    if (mounted) setState(() {});

    if (widget.isIncoming && widget.remoteOffer != null) {
      await _peerConnection!.setRemoteDescription(widget.remoteOffer!);
      var answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      P2PService().sendCallSignaling(widget.peerId, {'answer': answer.toMap()});
    } else {
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      P2PService().sendCallSignaling(widget.peerId, {
        'offer': offer.toMap(),
        'isVideo': widget.isVideo,
      });
    }
  }

  void _handleSignaling(Map<String, dynamic> data) async {
    if (data.containsKey('answer')) {
      var answer = RTCSessionDescription(data['answer']['sdp'], data['answer']['type']);
      await _peerConnection!.setRemoteDescription(answer);
    } else if (data.containsKey('candidate')) {
      var candidate = RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);
    } else if (data['type'] == 'hangup') {
      _endCall();
    }
  }

  void _endCall() {
    _signalingSub?.cancel();
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _peerConnection?.close();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _signalingSub?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.dispose();
    _peerConnection?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (widget.isVideo && _isConnectionEstablished)
            Positioned.fill(child: RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),
          
          if (!widget.isVideo || !_isConnectionEstablished)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 60,
                    backgroundColor: Color(0xFF2E7D32),
                    child: Icon(Icons.person, size: 80, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isConnectionEstablished ? 'Connected' : (widget.isIncoming ? 'Incoming...' : 'Calling...'),
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  Text(
                    'বন্ধু ${widget.peerId.substring(widget.peerId.length - 6)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),

          if (widget.isVideo)
            Positioned(
              top: 50,
              right: 20,
              width: 120,
              height: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              ),
            ),

          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionBtn(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  color: _isMuted ? Colors.red : Colors.white24,
                  onPressed: () {
                    setState(() => _isMuted = !_isMuted);
                    _localStream?.getAudioTracks().forEach((track) => track.enabled = !_isMuted);
                  },
                ),
                _buildActionBtn(
                  icon: Icons.call_end,
                  color: Colors.red,
                  size: 35,
                  onPressed: () {
                    P2PService().sendCallSignaling(widget.peerId, {'type': 'hangup'});
                    _endCall();
                  },
                ),
                if (widget.isVideo)
                  _buildActionBtn(
                    icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                    color: _isVideoOff ? Colors.red : Colors.white24,
                    onPressed: () {
                      setState(() => _isVideoOff = !_isVideoOff);
                      _localStream?.getVideoTracks().forEach((track) => track.enabled = !_isVideoOff);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({required IconData icon, required Color color, double size = 25, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: size),
        onPressed: onPressed,
      ),
    );
  }
}
