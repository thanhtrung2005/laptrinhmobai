import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DonationHistoryScreen extends StatelessWidget {
  const DonationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Lịch sử hiến máu"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: currentUserUid == null
          ? const Center(child: Text("Vui lòng đăng nhập để xem lịch sử"))
          : StreamBuilder<QuerySnapshot>(
              // TRUY VẤN: Lấy các bài viết mà mình có tên trong danh sách tình nguyện viên
              stream: FirebaseFirestore.instance
                  .collection('sos_requests')
                  .where('volunteers', arrayContains: currentUserUid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Lỗi: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text("Bạn chưa có lịch sử hiến máu nào.", style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    Timestamp? t = data['created_at'];
                    String dateStr = t != null ? DateFormat('dd/MM/yyyy').format(t.toDate()) : "N/A";

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.red[50], shape: BoxShape.circle),
                          child: const Icon(Icons.favorite, color: Colors.red),
                        ),
                        title: Text(
                          "Hiến máu tại: ${data['location_text'] ?? 'Không rõ địa điểm'}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text("Nhóm máu: ${data['blood_type'] ?? '?'}"),
                            Text("Ngày đăng ký: $dateStr", style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}