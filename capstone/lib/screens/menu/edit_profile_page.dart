import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfilePage extends StatefulWidget {
  final String currentName;
  final String currentEmail;

  const EditProfilePage({
    super.key,
    required this.currentName,
    required this.currentEmail,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  File? _imageFile;
  String? _base64Image;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _emailController = TextEditingController(text: widget.currentEmail);
    // 기존 프로필 이미지를 SharedPreferences에서 불러와서 초기화
    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        _base64Image = prefs.getString('profile_image') ?? '';
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _base64Image = base64Encode(bytes);
      });
    }
  }

  void _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', _nameController.text.trim());
    await prefs.setString('email', _emailController.text.trim());
    // 항상 저장 (빈 문자열도 저장)
    await prefs.setString('profile_image', _base64Image ?? '');

    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'profileImage': _base64Image,
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('내 정보가 수정되었습니다!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 정보 수정'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('프로필 사진', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage: _imageFile != null
                      ? FileImage(_imageFile!)
                      : null,
                  child: _imageFile == null
                      ? const Icon(Icons.camera_alt, size: 40)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text('이름', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: '이름 입력'),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 135, 197, 65),
                ),
                child: const Text('저장하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


