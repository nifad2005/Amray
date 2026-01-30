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
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_isScanned) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null && code.startsWith("amray_")) {
                  setState(() {
                    _isScanned = true;
                  });
                  
                  // Show loading feedback
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Connecting with friend...')),
                  );

                  // Send handshake to the peer
                  P2PService().sendHandshake(code);
                  
                  // Small delay to ensure handshake is sent
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(peerAddress: code),
                        ),
                      );
                    }
                  });
                  break;
                }
              }
            },
          ),
          // Scanner Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF2E7D32), width: 4),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'বন্ধুর কিউআর কোড ফ্রেমের ভেতরে রাখুন',
                style: TextStyle(color: Colors.white, backgroundColor: Colors.black54, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
