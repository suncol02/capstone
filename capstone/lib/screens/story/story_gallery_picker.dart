import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class StoryGalleryPage extends StatefulWidget {
  const StoryGalleryPage({super.key});

  @override
  State<StoryGalleryPage> createState() => _StoryGalleryPageState();
}

class _StoryGalleryPageState extends State<StoryGalleryPage> {
  final ImagePicker _picker = ImagePicker();

  void _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      Navigator.pop(context, File(image.path)); // ✅ File 반환
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void initState() {
    super.initState();
    _pickFromGallery(); // 화면 진입 시 자동 실행
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("스토리에 추가"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          '갤러리에서 선택 중...',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
