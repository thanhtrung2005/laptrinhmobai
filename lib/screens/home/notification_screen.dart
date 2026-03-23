import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy ID của mình để chỉ xem thông báo gửi cho mình
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Thông báo"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: currentUserUid == null
          ? const Center(child: Text("Vui lòng đăng nhập để xem thông báo"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('receiver_id', isEqualTo: currentUserUid) // Chỉ lấy thông báo của mình
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Lỗi: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                var data = snapshot.data!.docs;
                if (data.isEmpty) return const Center(child: Text("Bạn chưa có thông báo nào."));

               
                data.sort((a, b) {
                  Timestamp? tA = (a.data() as Map<String, dynamic>)['created_at'];
                  Timestamp? tB = (b.data() as Map<String, dynamic>)['created_at'];
                  if (tA == null || tB == null) return 0;
                  return tB.compareTo(tA);
                });

                return ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    var notif = data[index].data() as Map<String, dynamic>;
                    bool isRead = notif['is_read'] ?? false; // Trạng thái đã đọc hay chưa
                    
                    Timestamp? t = notif['created_at'];
                    String timeStr = t != null 
                        ? DateFormat('HH:mm dd/MM/yyyy').format(t.toDate()) 
                        : "Vừa xong";

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      elevation: isRead ? 0 : 2, // Chưa đọc thì thẻ nổi lên
                      color: isRead ? Colors.white : Colors.red[50], // Chưa đọc thì nền hồng nhạt
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.red,
                          child: Icon(Icons.favorite, color: Colors.white),
                        ),
                        title: Text(
                          notif['message'] ?? 'Thông báo mới',
                          style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                        ),
                        subtitle: Text(timeStr),
                        onTap: () {
                          // Khi người dùng bấm vào xem -> Đổi trạng thái thành Đã đọc
                          if (!isRead) {
                            FirebaseFirestore.instance
                                .collection('notifications')
                                .doc(data[index].id)
                                .update({'is_read': true});
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}