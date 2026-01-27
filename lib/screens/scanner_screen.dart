import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/p2p_service.dart';
import 'chat_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('কিউআর কোড স্ক্যান করুন', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: MobileScanner(
        onDetect: (capture) {
          if (_isScanned) return;
          
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            final String? code = barcode.rawValue;
            if (code != null && code.startsWith("amray_")) {
              setState(() {
                _isScanned = true;
              });
              
              // Send handshake to the peer so they know we connected
              P2PService().sendHandshake(code);
              
              // Navigate to chat screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(peerAddress: code),
                ),
              );
              break;
            }
          }
        },
      ),
    );
  }
}
