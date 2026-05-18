import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class StoryCameraPage extends StatefulWidget {
  const StoryCameraPage({super.key});

  @override
  State<StoryCameraPage> createState() => _StoryCameraPageState();
}

class _StoryCameraPageState extends State<StoryCameraPage> {
  final ImagePicker _picker = ImagePicker();

  void _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      Navigator.pop(context, File(photo.path)); // ✅ File 반환
    } else {
      Navigator.pop(context); // 아무것도 선택 안 했을 때
    }
  }

  @override
  void initState() {
    super.initState();
    _takePhoto(); // 화면 진입 시 자동 촬영
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink[100],
      appBar: AppBar(
        backgroundColor: Colors.pink[100],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: Text('카메라 실행 중...', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
