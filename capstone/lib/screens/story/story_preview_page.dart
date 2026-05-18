import 'dart:io';
import 'package:flutter/material.dart';

class StoryPreviewPage extends StatelessWidget {
  final File imageFile;
  final void Function(File) onUpload; // ✅ 콜백 추가

  const StoryPreviewPage({
    super.key,
    required this.imageFile,
    required this.onUpload,
  });

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
      body: Stack(
        children: [
          Center(
            child: Image.file(imageFile),
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: () {
                onUpload(imageFile); // ✅ 업로드 상태 저장
                Navigator.popUntil(context, (route) => route.isFirst); // 홈으로 이동
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                "스토리 업로드",
                style: TextStyle(color: Colors.white),
              ),
            ),
          )
        ],
      ),
    );
  }
}
