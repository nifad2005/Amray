import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/p2p_service.dart';
import 'chat_screen.dart';

class QRDisplayScreen extends StatefulWidget {
  const QRDisplayScreen({super.key});

  @override
  State<QRDisplayScreen> createState() => _QRDisplayScreenState();
}

class _QRDisplayScreenState extends State<QRDisplayScreen> {
  @override
  void initState() {
    super.initState();
    // Listen for someone scanning us
    P2PService().peerDiscoveryStream.listen((peerId) {
      if (mounted) {
        // Automatically jump to chat when someone connects to us
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(peerAddress: peerId),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final myAddress = P2PService().getMyAddress();

    return Scaffold(
      appBar: AppBar(
        title: const Text('আমার কিউআর কোড', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'আপনার ইউনিক সংযোগ আইডি',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 10),
                  ],
                ),
                child: QrImageView(
                  data: myAddress,
                  version: QrVersions.auto,
                  size: 250.0,
                  foregroundColor: const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 20),
              Text("অপেক্ষা করা হচ্ছে...", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
