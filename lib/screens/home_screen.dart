import 'package:flutter/material.dart';
import '../services/p2p_service.dart';
import 'chat_screen.dart';
import 'qr_display_screen.dart';
import 'scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Listen for new peers discovered to refresh the list
    P2PService().peerDiscoveryStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final friends = P2PService().friends;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'আমরাই',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(width: 10),
            StreamBuilder<ConnectionStatus>(
              stream: P2PService().statusStream,
              initialData: P2PService().currentStatus,
              builder: (context, snapshot) {
                Color statusColor;
                String statusText;

                switch (snapshot.data) {
                  case ConnectionStatus.connected:
                    statusColor = Colors.lightGreenAccent;
                    statusText = 'অনলাইন';
                    break;
                  case ConnectionStatus.connecting:
                    statusColor = Colors.orangeAccent;
                    statusText = 'সংযোগ হচ্ছে...';
                    break;
                  case ConnectionStatus.error:
                    statusColor = Colors.redAccent;
                    statusText = 'ত্রুটি';
                    break;
                  default:
                    statusColor = Colors.grey;
                    statusText = 'অফলাইন';
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        statusText,
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            onPressed: () => _showScanOptions(context),
          ),
        ],
      ),
      body: friends.isEmpty
          ? _buildEmptyState(context)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: friends.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final friendId = friends[index];
                return _buildFriendTile(context, friendId);
              },
            ),
      floatingActionButton: friends.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showScanOptions(context),
              backgroundColor: const Color(0xFF2E7D32),
              child: const Icon(Icons.person_add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            'এখনও কোনো বন্ধু নেই',
            style: TextStyle(fontSize: 18, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'চ্যাট শুরু করতে কিউআর কোড স্ক্যান করুন',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black45),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => _showScanOptions(context),
            icon: const Icon(Icons.add),
            label: const Text('নতুন বন্ধু যোগ করুন'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(BuildContext context, String friendId) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Text(friendId.substring(6, 8).toUpperCase(),
              style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
        ),
        title: Text(
          'বন্ধু ${friendId.substring(6, 12)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('মেসেজ করতে ক্লিক করুন'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(peerAddress: friendId),
            ),
          );
        },
      ),
    );
  }

  void _showScanOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.qr_code_scanner, color: Color(0xFF2E7D32)),
                title: const Text('কিউআর কোড স্ক্যান করুন'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ScannerScreen()),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.qr_code, color: Color(0xFF2E7D32)),
                title: const Text('আমার কিউআর কোড'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const QRDisplayScreen()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
