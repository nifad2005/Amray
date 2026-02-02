import 'package:flutter/material.dart';

class CallScreen extends StatefulWidget {
  final String peerId;
  final bool isVideo;
  final bool isIncoming;
  
  const CallScreen({super.key, required this.peerId, required this.isVideo, required this.isIncoming, remoteOffer});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isVideo ? 'Video Call' : 'Audio Call'),
      ),
      body: const Center(
        child: Text('Calling feature is currently under development.'),
      ),
    );
  }
}
