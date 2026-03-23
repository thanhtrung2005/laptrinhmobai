import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/vietnam_address_picker.dart'; 
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // THÊM IMPORT NÀY

class CreateSosScreen extends StatefulWidget {
  const CreateSosScreen({super.key});

  @override
  State<CreateSosScreen> createState() => _CreateSosScreenState();
}

class _CreateSosScreenState extends State<CreateSosScreen> {
  final _contentController = TextEditingController();
  
  String _addressStr = "";
  String _specificAddress = ""; 
  String _provinceName = "";
  String _districtName = "";
  
  String _selectedBloodType = 'A+';
  bool _isLoading = false;
  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  Future<void> _postSos() async {
    if (_addressStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn địa chỉ hành chính')));
      return;
    }
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập nội dung mô tả')));
      return;
    }

    setState(() => _isLoading = true);
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Bạn chưa đăng nhập')));
      setState(() => _isLoading = false);
      return;
    }

    String finalLocation = _specificAddress.isEmpty ? _addressStr : "$_specificAddress, $_addressStr";

    try {
      // --- CÁCH 2: LẤY TỌA ĐỘ TỪ ĐỊA CHỈ ĐÃ CHỌN ---
      double targetLat = 0;
      double targetLng = 0;

      try {
        // Chúng ta lấy District và Province để Geocoding chính xác nhất ở VN
        String searchAddress = "$_districtName, $_provinceName, Việt Nam";
        List<Location> locations = await locationFromAddress(searchAddress);

        if (locations.isNotEmpty) {
          targetLat = locations.first.latitude;
          targetLng = locations.first.longitude;
        }
      } catch (e) {
        // Nếu địa chỉ không tìm thấy (lỗi Geocoding), dùng GPS máy làm dự phòng
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        targetLat = position.latitude;
        targetLng = position.longitude;
      }

      // 2. LƯU LÊN FIRESTORE
      await FirebaseFirestore.instance.collection('sos_requests').add({
        'user_id': user.uid,
        'email': user.email,
        'content': _contentController.text.trim(),
        'location_text': finalLocation,
        'province': _provinceName,
        'district': _districtName,
        'blood_type': _selectedBloodType,
        'status': 'pending',
        'lat': targetLat, // Tọa độ của địa chỉ được chọn
        'lng': targetLng, // Tọa độ của địa chỉ được chọn
        'created_at': FieldValue.serverTimestamp(),
        'volunteers': [],
        'volunteer_details': [],
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng tin SOS thành công!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      debugPrint("Lỗi: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi hệ thống: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tạo tin khẩn cấp (SOS)"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedBloodType,
              items: _bloodTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _selectedBloodType = val!),
              decoration: const InputDecoration(
                labelText: 'Cần nhóm máu', 
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.bloodtype, color: Colors.red),
              ),
            ),
            const SizedBox(height: 16),
            
            VietnamAddressPicker(
              onAddressChanged: (fullAddr, province, district, ward) {
                setState(() {
                  _addressStr = fullAddr;
                  _provinceName = province;
                  _districtName = district;
                });
              },
            ),
            const SizedBox(height: 10),
            
            TextField(
              onChanged: (val) => _specificAddress = val,
              decoration: const InputDecoration(
                labelText: 'Số nhà, tên đường, tên bệnh viện (Tùy chọn)',
                prefixIcon: Icon(Icons.home),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _contentController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Nội dung (Mô tả tình trạng bệnh nhân...)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            
            _isLoading
                ? const CircularProgressIndicator(color: Colors.red)
                : ElevatedButton.icon(
                    onPressed: _postSos,
                    icon: const Icon(Icons.send),
                    label: const Text("ĐĂNG TIN KHẨN CẤP"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
            const SizedBox(height: 15),
            const Text(
              "Hệ thống sẽ tính khoảng cách dựa trên địa chỉ bạn đã chọn ở trên.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            )
          ],
        ),
      ),
    );
  }
}