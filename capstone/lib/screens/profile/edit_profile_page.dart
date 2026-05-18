import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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
        // DB를 새로 만들었을 때 SharedPreferences의 프로필 이미지를 초기화
        if (!(prefs.getString('profile_image')?.isNotEmpty ?? false)) {
          _base64Image = '';
        } else {
          _base64Image = prefs.getString('profile_image') ?? '';
        }
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
    await prefs.setString('profile_image', _base64Image ?? '');

    // 서버에도 프로필 정보 업데이트
    final url = Uri.parse('http://192.168.45.204:5000/update-profile');
    await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'profile_image': _base64Image ?? '',
      }),
    );

    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'profileImage': _base64Image,
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('내 정보가 수정되었습니다!')));
  }

  // 로그아웃 시 프로필 이미지를 삭제하지 않는 예시 함수
  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    // 이름, 이메일, 프로필 이미지 모두 삭제
    await prefs.remove('name');
    await prefs.remove('email');
    await prefs.remove('profile_image'); // 프로필 이미지도 삭제
    // ...추가 로그아웃 처리...
    // Navigator.pushReplacementNamed(context, '/login'); // 예시
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
                  backgroundImage:
                      _imageFile != null ? FileImage(_imageFile!) : null,
                  child:
                      _imageFile == null
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
