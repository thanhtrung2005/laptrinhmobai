import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class VietnamAddressPicker extends StatefulWidget {
  final Function(String fullAddress, String province, String district, String ward) onAddressChanged;

  const VietnamAddressPicker({super.key, required this.onAddressChanged});

  @override
  State<VietnamAddressPicker> createState() => _VietnamAddressPickerState();
}

class _VietnamAddressPickerState extends State<VietnamAddressPicker> {
  List<dynamic> _provinces = [];
  List<dynamic> _districts = [];
  List<dynamic> _wards = [];

  dynamic _selectedProvince;
  dynamic _selectedDistrict;
  dynamic _selectedWard;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Hàm tự động đọc file JSON từ máy
  Future<void> _loadData() async {
    final String response = await rootBundle.loadString('assets/provinces.json');
    final data = await json.decode(response);
    setState(() {
      _provinces = data;
      _isLoading = false;
    });
  }

  void _updateParent() {
    if (_selectedProvince != null && _selectedDistrict != null && _selectedWard != null) {
      String fullAddr = "${_selectedWard['name']}, ${_selectedDistrict['name']}, ${_selectedProvince['name']}";
      widget.onAddressChanged(
        fullAddr, 
        _selectedProvince['name'], 
        _selectedDistrict['name'], 
        _selectedWard['name']
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<dynamic>(
          decoration: const InputDecoration(
            labelText: "Tỉnh / Thành phố", 
            prefixIcon: Icon(Icons.map),
            border: OutlineInputBorder(),
          ),
          value: _selectedProvince,
          isExpanded: true,
          items: _provinces.map((p) => DropdownMenuItem(value: p, child: Text(p['name']))).toList(),
          onChanged: (val) {
            setState(() {
              _selectedProvince = val;
              _selectedDistrict = null;
              _selectedWard = null;
              // Lấy danh sách quận/huyện nằm trong tỉnh/thành phố đó
              _districts = val['districts'] ?? [];
              _wards = [];
            });
          },
        ),
        const SizedBox(height: 12),

        DropdownButtonFormField<dynamic>(
          decoration: const InputDecoration(
            labelText: "Quận / Huyện", 
            prefixIcon: Icon(Icons.location_city),
            border: OutlineInputBorder(),
          ),
          value: _selectedDistrict,
          isExpanded: true,
          items: _districts.map((d) => DropdownMenuItem(value: d, child: Text(d['name']))).toList(),
          onChanged: _selectedProvince == null ? null : (val) {
            setState(() {
              _selectedDistrict = val;
              _selectedWard = null;
              // Lấy danh sách phường/xã nằm trong quận/huyện đó
              _wards = val['wards'] ?? [];
            });
          },
        ),
        const SizedBox(height: 12),

        DropdownButtonFormField<dynamic>(
          decoration: const InputDecoration(
            labelText: "Phường / Xã", 
            prefixIcon: Icon(Icons.holiday_village),
            border: OutlineInputBorder(),
          ),
          value: _selectedWard,
          isExpanded: true,
          items: _wards.map((w) => DropdownMenuItem(value: w, child: Text(w['name']))).toList(),
          onChanged: _selectedDistrict == null ? null : (val) {
            setState(() {
              _selectedWard = val;
              _updateParent();
            });
          },
        ),
      ],
    );
  }
}