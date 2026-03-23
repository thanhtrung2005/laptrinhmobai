import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class BloodDriveScreen extends StatefulWidget {
  const BloodDriveScreen({super.key});

  @override
  State<BloodDriveScreen> createState() => _BloodDriveScreenState();
}

class _BloodDriveScreenState extends State<BloodDriveScreen> {
  // Tập hợp các ID sự kiện mà người dùng hiện tại đã đăng ký tham gia
  final Set<String> _joinedEventIds = {};

  @override
  void initState() {
    super.initState();
    _checkJoinedEvents();
  }

  // --- CÁCH MỚI: Kiểm tra từ collection 'users' để không bị lỗi Index ---
  void _checkJoinedEvents() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data()!.containsKey('joinedEvents')) {
        List<dynamic> events = userDoc.data()!['joinedEvents'];
        if (mounted) {
          setState(() {
            _joinedEventIds.addAll(events.map((e) => e.toString()));
          });
        }
      }
    } catch (e) {
      debugPrint("Lỗi khi kiểm tra đăng ký: $e");
    }
  }

  // --- CÁCH MỚI: Đăng ký dùng arrayUnion (Không cần tạo Index) ---
  Future<void> _registerEvent(String eventId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng đăng nhập để tham gia!")),
      );
      return;
    }

    if (_joinedEventIds.contains(eventId)) return;

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. Tăng số lượng hiển thị cho Web Admin
      DocumentReference eventRef =
          FirebaseFirestore.instance.collection('events').doc(eventId);
      batch.update(eventRef, {'registered_count': FieldValue.increment(1)});

      // 2. Lưu ID sự kiện vào mảng 'joinedEvents' của User
      DocumentReference userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      batch.update(userRef, {
        'joinedEvents': FieldValue.arrayUnion([eventId])
      });

      await batch.commit();

      if (!mounted) return;
      setState(() {
        _joinedEventIds.add(eventId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Đăng ký thành công! Hẹn gặp bạn tại điểm hiến máu."),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Xử lý trường hợp User chưa có document hoặc field
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'joinedEvents': [eventId]
        }, SetOptions(merge: true));
        
        if (mounted) {
          setState(() { _joinedEventIds.add(eventId); });
        }
      } catch (err) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi: ${err.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Điểm Hiến Máu Lưu Động"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .orderBy('date', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Hiện chưa có sự kiện hiến máu nào."));
          }

          final events = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: events.length,
            itemBuilder: (context, index) {
              var doc = events[index];
              var event = doc.data() as Map<String, dynamic>;
              String eventId = doc.id;

              Timestamp? t = event['date'];
              String formattedDate = t != null
                  ? DateFormat('dd/MM/yyyy').format(t.toDate())
                  : "Chưa cập nhật";

              bool isJoined = _joinedEventIds.contains(eventId);

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(15)),
                      ),
                      child: const Icon(Icons.campaign,
                          size: 40, color: Colors.red),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event['title'] ?? "Sự kiện hiến máu",
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 16, color: Colors.red),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  event['location'] ?? "Chưa rõ địa điểm",
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(Icons.calendar_month,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 5),
                              Text("Ngày: $formattedDate",
                                  style: const TextStyle(color: Colors.grey)),
                              const Spacer(),
                              const Icon(Icons.group,
                                  size: 16, color: Colors.blue),
                              const SizedBox(width: 5),
                              Text("${event['registered_count'] ?? 0} người",
                                  style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(height: 25),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isJoined
                                  ? null
                                  : () => _registerEvent(eventId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isJoined ? Colors.grey : Colors.red,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey[400],
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                  isJoined ? "ĐÃ ĐĂNG KÝ" : "ĐĂNG KÝ THAM GIA"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}