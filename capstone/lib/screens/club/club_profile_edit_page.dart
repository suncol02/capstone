import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class ClubProfileAndDescEditPage extends StatefulWidget {
  final Map<String, dynamic> club;
  const ClubProfileAndDescEditPage({super.key, required this.club});

  @override
  State<ClubProfileAndDescEditPage> createState() =>
      _ClubProfileAndDescEditPageState();
}

class _ClubProfileAndDescEditPageState
    extends State<ClubProfileAndDescEditPage> {
  File? _imageFile;
  String? _base64Image;
  late TextEditingController _nameController;
  late TextEditingController _descController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.club['name'] ?? '');
    _descController = TextEditingController(
      text: widget.club['description'] ?? '',
    );
    if (widget.club['image'] != null &&
        widget.club['image'].toString().isNotEmpty) {
      _base64Image = widget.club['image'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await File(picked.path).readAsBytes();
      setState(() {
        _imageFile = File(picked.path);
        _base64Image = base64Encode(bytes);
      });
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('동아리명을 입력해 주세요.')));
      return;
    }
    setState(() => _isLoading = true);
    final response = await http.patch(
      Uri.parse('http://127.0.0.1:3000/clubs/${widget.club['id']}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'image': _base64Image ?? '', // 반드시 포함
      }),
    );
    setState(() => _isLoading = false);
    if (response.statusCode == 200) {
      // 수정된 정보를 부모로 전달
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('수정 실패: ${response.body}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('동아리 프로필/소개 수정')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage:
                      _base64Image != null && _base64Image!.isNotEmpty
                          ? MemoryImage(base64Decode(_base64Image!))
                          : null,
                  child:
                      _base64Image == null || _base64Image!.isEmpty
                          ? const Icon(Icons.camera_alt, size: 40)
                          : null,
                ),
              ),
            ),
            const SizedBox(height: 24), // 프로필 사진과 입력란 사이 간격
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '동아리명',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
              ),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20), // 동아리명과 소개 사이 간격을 조금 더 넓게
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: '동아리 소개',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
              ),
              maxLines: 1,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24), // 입력란과 버튼 사이 간격
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: _save, child: const Text('저장')),
          ],
        ),
      ),
    );
  }
}
