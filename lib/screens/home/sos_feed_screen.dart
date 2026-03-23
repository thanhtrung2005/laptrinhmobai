import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; 
import 'package:geolocator/geolocator.dart'; 
import 'package:share_plus/share_plus.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import '../sos/create_sos_screen.dart';
import 'notification_screen.dart'; 

class SosFeedScreen extends StatefulWidget {
  const SosFeedScreen({super.key});

  @override
  State<SosFeedScreen> createState() => _SosFeedScreenState();
}

class _SosFeedScreenState extends State<SosFeedScreen> {
  final String? currentUserUid = FirebaseAuth.instance.currentUser?.uid;
  Position? _currentUserPosition;

  String _searchQuery = "";
  String _selectedBloodFilter = "Tất cả";
  final List<String> _bloodTypesFilter = ['Tất cả', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low);
      setState(() {
        _currentUserPosition = position;
      });
    } catch (e) {
      debugPrint("Không lấy được vị trí: $e");
    }
  }

  double _calculateDistance(double? postLat, double? postLng) {
    if (_currentUserPosition == null || postLat == null || postLng == null) return -1.0;
    return Geolocator.distanceBetween(
      _currentUserPosition!.latitude,
      _currentUserPosition!.longitude,
      postLat,
      postLng,
    ) / 1000; // Trả về km
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Tìm kiếm & Bộ lọc", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  hintText: "Tìm theo địa chỉ hoặc nội dung...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.toLowerCase());
                },
              ),
              const SizedBox(height: 20),
              const Text("Chọn nhóm máu:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: _bloodTypesFilter.map((type) {
                  bool isSelected = _selectedBloodFilter == type;
                  return ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    selectedColor: Colors.red,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                    onSelected: (selected) {
                      setModalState(() => _selectedBloodFilter = type);
                      setState(() => _selectedBloodFilter = type);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, 
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ),
                  child: const Text("ÁP DỤNG BỘ LỌC", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completeSosRequest(String documentId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận"),
        content: const Text("Bạn đã nhận đủ lượng máu cần thiết cho ca này?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Chưa")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Đã đủ", style: TextStyle(color: Colors.green))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('sos_requests').doc(documentId).update({
        'status': 'completed'
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chúc mừng! Ca SOS đã hoàn thành."), backgroundColor: Colors.green));
      }
    }
  }

  void _shareSosRequest(Map<String, dynamic> request) {
    String shareContent = "🚨 CẦN MÁU GẤP [Nhóm ${request['blood_type']}]\n📍 Địa điểm: ${request['location_text']}\n📝 Nội dung: ${request['content']}\n👉 Tải ứng dụng Hiến Máu để hỗ trợ ngay!";
    Share.share(shareContent);
  }

  void _showVolunteersList(BuildContext context, List<dynamic> details) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 15),
            const Text("Danh sách tình nguyện viên", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            const Divider(),
            details.isEmpty 
              ? const Padding(padding: EdgeInsets.all(30), child: Text("Chưa có ai đăng ký ca này."))
              : Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: details.length,
                    itemBuilder: (context, i) {
                      var v = details[i] as Map<String, dynamic>;
                      String phone = v['phone'] ?? '';
                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.person, color: Colors.white)),
                        title: Text(v['name'] ?? 'Người dùng ẩn danh', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("SĐT: $phone"),
                        trailing: IconButton(
                          icon: const Icon(Icons.phone_in_talk, color: Colors.green, size: 28),
                          onPressed: () async {
                            if (phone.isNotEmpty && phone != 'Chưa cập nhật SĐT') {
                              final Uri launchUri = Uri(scheme: 'tel', path: phone);
                              if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerToDonate(String documentId, String creatorId) async {
    if (currentUserUid == null) return;
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserUid).get();
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      await FirebaseFirestore.instance.collection('sos_requests').doc(documentId).update({
        'volunteers': FieldValue.arrayUnion([currentUserUid]),
        'volunteer_details': FieldValue.arrayUnion([{'uid': currentUserUid, 'name': userData['fullName'] ?? 'Người dùng', 'phone': userData['phone'] ?? 'Chưa cập nhật SĐT'}])
      });
      if (creatorId.isNotEmpty && currentUserUid != creatorId) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'receiver_id': creatorId, 'sender_id': currentUserUid, 'message': 'Có người vừa đăng ký hiến máu cho ca SOS của bạn!', 'created_at': FieldValue.serverTimestamp(), 'is_read': false, 'type': 'volunteer',
        });
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đăng ký thành công!'), backgroundColor: Colors.green));
    } catch (e) { print(e); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 1, automaticallyImplyLeading: false,
        title: const Row(children: [Icon(Icons.water_drop, color: Colors.red, size: 28), SizedBox(width: 10), Text("Bảng tin Hiến máu", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.red),
            onPressed: _showFilterDialog,
          ),
          IconButton(icon: const Icon(Icons.notifications, color: Colors.red), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationScreen()))),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateSosScreen())),
        label: const Text("SOS", style: TextStyle(fontWeight: FontWeight.bold)), icon: const Icon(Icons.add_alert), backgroundColor: Colors.red, foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sos_requests').orderBy('created_at', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final allDocs = snapshot.data!.docs;
          final filteredData = allDocs.where((doc) {
            var request = doc.data() as Map<String, dynamic>;
            String blood = request['blood_type'] ?? "";
            String location = (request['location_text'] ?? "").toString().toLowerCase();
            String content = (request['content'] ?? "").toString().toLowerCase();

            bool matchesBlood = _selectedBloodFilter == "Tất cả" || blood == _selectedBloodFilter;
            bool matchesQuery = location.contains(_searchQuery) || content.contains(_searchQuery);

            return matchesBlood && matchesQuery;
          }).toList();

          if (filteredData.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text("Không tìm thấy ca SOS phù hợp", style: TextStyle(color: Colors.grey, fontSize: 16)),
                  TextButton(
                    onPressed: () => setState(() { _searchQuery = ""; _selectedBloodFilter = "Tất cả"; }),
                    child: const Text("Xóa bộ lọc")
                  )
                ],
              )
            );
          }

          return ListView.builder(
            itemCount: filteredData.length,
            itemBuilder: (context, index) {
              final document = filteredData[index];
              var request = document.data() as Map<String, dynamic>;
              String creatorId = request['user_id'] ?? '';
              bool isCompleted = request['status'] == 'completed';
              
              // 1. XỬ LÝ NGÀY GIỜ ĐĂNG BÀI
              String formattedTime = "Vừa xong";
              if (request['created_at'] != null) {
                Timestamp t = request['created_at'];
                formattedTime = DateFormat('HH:mm - dd/MM/yyyy').format(t.toDate());
              }

              // 2. XỬ LÝ KHOẢNG CÁCH
              double dist = _calculateDistance(request['lat'], request['lng']);
              
              // LOGIC "Ở GẦN BẠN": Chỉ hiện khi khoảng cách từ 0.1km đến 10km 
              // (Loại bỏ 0.0km vì đó thường là bài của chính mình đăng khi đang ngồi tại chỗ)
              bool showNearLabel = dist > 0.1 && dist < 10.0;
              String distStr = dist < 0 ? "..." : "${dist.toStringAsFixed(1)} km";

              List<dynamic> volunteers = request['volunteers'] ?? [];
              bool hasRegistered = currentUserUid != null && volunteers.contains(currentUserUid);
              bool isMyPost = currentUserUid == creatorId;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15), 
                  side: showNearLabel ? const BorderSide(color: Colors.green, width: 2) : BorderSide.none
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 65, height: 75,
                            decoration: BoxDecoration(
                              color: Colors.red[700],
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(35), topRight: Radius.circular(35), bottomLeft: Radius.circular(10), bottomRight: Radius.circular(35)),
                              boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 6, offset: const Offset(2, 4))],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.water_drop, color: Colors.white, size: 18),
                                Text(request['blood_type'] ?? '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(request['location_text'] ?? 'Địa chỉ trống', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 6),
                                
                                // HIỂN THỊ NGÀY GIỜ
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(formattedTime, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                
                                // HIỂN THỊ KHOẢNG CÁCH
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min, 
                                    children: [
                                      const Icon(Icons.near_me, size: 14, color: Colors.blue), 
                                      const SizedBox(width: 4), 
                                      Text("Cách bạn $distStr", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12))
                                    ]
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.share_outlined, color: Colors.grey, size: 24), onPressed: () => _shareSosRequest(request)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Chỉ hiện nhãn Ở GẦN BẠN nếu thỏa mãn logic cách từ 0.1km -> 10km
                          if (showNearLabel && !isCompleted) 
                            Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)), child: const Text("Ở GẦN BẠN", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                          if (isCompleted) 
                            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.blueGrey, borderRadius: BorderRadius.circular(8)), child: const Text("ĐÃ NHẬN ĐỦ MÁU", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const Divider(height: 25),
                      Text(request['content'] ?? '', style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4)),
                      const SizedBox(height: 16),
                      if (isCompleted)
                        const SizedBox(width: double.infinity, child: Center(child: Text("Ca hiến máu này đã hoàn tất. Cảm ơn cộng đồng!", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))))
                      else if (isMyPost)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showVolunteersList(context, request['volunteer_details'] ?? []),
                                icon: const Icon(Icons.people, size: 18, color: Colors.green),
                                label: Text("LIÊN HỆ (${volunteers.length})", style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.green), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _completeSosRequest(document.id),
                                icon: const Icon(Icons.check_circle, size: 18),
                                label: const Text("XÁC NHẬN ĐỦ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              ),
                            ),
                          ],
                        )
                      else
                        SizedBox(
                          width: double.infinity, height: 50,
                          child: ElevatedButton.icon(
                            onPressed: hasRegistered ? null : () => _registerToDonate(document.id, creatorId),
                            icon: Icon(hasRegistered ? Icons.check_circle : Icons.volunteer_activism),
                            label: Text(hasRegistered ? "ĐÃ ĐĂNG KÝ" : "TÔI MUỐN HIẾN MÁU", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            style: ElevatedButton.styleFrom(backgroundColor: hasRegistered ? Colors.grey : Colors.red[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          ),
                        )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}