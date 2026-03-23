import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/login_screen.dart'; 
import 'donation_history_screen.dart';
import 'package:geolocator/geolocator.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Chưa biết'];

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _updateBloodType(String newValue) async {
    if (currentUser == null) return;
    await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({'bloodType': newValue});
  }

  // HÀM CẬP NHẬT TRẠNG THÁI VÀ VỊ TRÍ MỚI
  Future<void> _updateAvailability(bool isAvailable) async {
    if (currentUser == null) return;

    try {
      if (isAvailable) {
        // 1. Kiểm tra và xin quyền vị trí
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bạn cần cấp quyền vị trí để mọi người có thể tìm thấy bạn')),
              );
            }
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Quyền vị trí bị từ chối vĩnh viễn. Hãy mở cài đặt để cấp quyền.')),
            );
          }
          return;
        }

        // 2. Lấy vị trí hiện tại
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
        );

        // 3. Cập nhật Firestore
        await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
          'isAvailable': true,
          'last_lat': position.latitude,
          'last_lng': position.longitude,
          'last_updated': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã cập nhật vị trí sẵn sàng!'), backgroundColor: Colors.green),
          );
        }
      } else {
        // Nếu tắt sẵn sàng hiến máu
        await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
          'isAvailable': false,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi cập nhật vị trí: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const Center(child: Text("Lỗi đăng nhập"));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hồ sơ cá nhân"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _signOut)],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());

          var userData = snapshot.data!.data() as Map<String, dynamic>;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 50, 
                  backgroundColor: Colors.red, 
                  child: Icon(Icons.person, size: 60, color: Colors.white)
                ),
                const SizedBox(height: 16),
                Text(
                  userData['fullName'] ?? 'Người dùng', 
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
                ),
                Text(userData['email'] ?? '', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),
                
                const Divider(),
                
                ListTile(
                  leading: const Icon(Icons.bloodtype, color: Colors.red),
                  title: const Text("Nhóm máu"),
                  trailing: DropdownButton<String>(
                    value: _bloodTypes.contains(userData['bloodType']) ? userData['bloodType'] : null,
                    hint: const Text("Chọn"),
                    underline: Container(),
                    items: _bloodTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                    onChanged: (val) { if (val != null) _updateBloodType(val); },
                  ),
                ),
                const Divider(),

                ListTile(
                  leading: const Icon(Icons.history, color: Colors.blue),
                  title: const Text("Lịch sử hiến máu"),
                  subtitle: const Text("Xem lại các ca bạn đã đăng ký"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DonationHistoryScreen()),
                    );
                  },
                ),
                const Divider(),

                SwitchListTile(
                  activeColor: Colors.green,
                  title: const Text("Sẵn sàng hiến máu"),
                  subtitle: const Text("Tự động chia sẻ vị trí của bạn để hỗ trợ ca SOS gần nhất"),
                  value: userData['isAvailable'] ?? false,
                  onChanged: _updateAvailability,
                  secondary: const Icon(Icons.volunteer_activism, color: Colors.green),
                ),
                const Divider(),
              ],
            ),
          );
        },
      ),
    );
  }
}