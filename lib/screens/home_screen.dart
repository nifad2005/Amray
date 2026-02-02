import 'dart:async';
import 'package:flutter/material.dart';
import '../services/p2p_service.dart';
import 'chat_screen.dart';
import 'qr_display_screen.dart';
import 'scanner_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription? _presenceSub;

  @override
  void initState() {
    super.initState();
    P2PService().peerDiscoveryStream.listen((_) {
      if (mounted) setState(() {});
    });

    // Refresh home screen when any friend's status changes
    _presenceSub = P2PService().presenceStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _presenceSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friends = P2PService().friends;

    return Scaffold(
      appBar: AppBar(
        title: const Text('আমরাই', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            onPressed: () => _showScanOptions(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildOnlineStatusHeader(),
          Expanded(
            child: friends.isEmpty
                ? _buildEmptyState(context)
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: friends.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _buildFriendTile(context, friends[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineStatusHeader() {
    return StreamBuilder<ConnectionStatus>(
      stream: P2PService().statusStream,
      initialData: P2PService().currentStatus,
      builder: (context, snapshot) {
        bool isConnected = snapshot.data == ConnectionStatus.connected;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4),
          color: isConnected ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
          child: Center(
            child: Text(
              isConnected ? '● Connected to Amray Network' : '○ Offline',
              style: TextStyle(fontSize: 10, color: isConnected ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text('Welcome to Amray', style: TextStyle(fontSize: 18, color: Colors.white70)),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => _showScanOptions(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            child: const Text('Add Friend', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(BuildContext context, String friendId) {
    bool isFriendOnline = P2PService().isOnline(friendId);
    return Card(
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF2E7D32),
              child: Text(friendId.substring(6, 8).toUpperCase(), style: const TextStyle(color: Colors.white)),
            ),
            if (isFriendOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF1E1E1E), width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text('বন্ধু ${friendId.substring(6, 12)}', style: const TextStyle(color: Colors.white)),
        subtitle: Text(isFriendOnline ? 'Online' : 'Offline', style: TextStyle(color: isFriendOnline ? Colors.greenAccent : Colors.white54, fontSize: 12)),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(peerAddress: friendId))),
      ),
    );
  }

  void _showScanOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.qr_code_scanner, color: Colors.green),
            title: const Text('Scan QR Code'),
            onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen())); },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code, color: Colors.green),
            title: const Text('My QR Code'),
            onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const QRDisplayScreen())); },
          ),
        ],
      ),
    );
  }
}
