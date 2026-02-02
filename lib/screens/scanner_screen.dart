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
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      
      // Strict validation for Amray ID format
      if (code != null && code.startsWith("amray_") && code.length > 10) {
        setState(() => _isScanned = true);
        
        // Immediate UI feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('বন্ধু পাওয়া গেছে! সংযোগ করা হচ্ছে...'),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 1),
          ),
        );

        // Send handshake through our rock-solid P2P Service
        P2PService().sendHandshake(code);
        
        // Give the network a moment to process the handshake
        Future.delayed(const Duration(milliseconds: 600), () {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('কিউআর কোড স্ক্যান করুন', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          
          // Stylish Scanner Overlay
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.5),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Green Border for the scanning area
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF2E7D32), width: 3),
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),

          const Positioned(
            bottom: 80,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Icon(Icons.qr_code_scanner, color: Colors.white, size: 40),
                SizedBox(height: 10),
                Text(
                  'বন্ধুর কিউআর কোড ফ্রেমের ভেতরে রাখুন',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
