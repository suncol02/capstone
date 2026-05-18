import 'dart:io';
import 'package:flutter/material.dart';

class StoryViewPage extends StatefulWidget {
  final File imageFile;

  const StoryViewPage({super.key, required this.imageFile});

  @override
  State<StoryViewPage> createState() => _StoryViewPageState();
}

class _StoryViewPageState extends State<StoryViewPage> {
  @override
  void initState() {
    super.initState();
    // RawKeyboard 제거 - 안전성 향상
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Stack(
        children: [
          // 중앙 스토리 컨텐츠
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: Container(
                  color: Colors.white,
                  child: Stack(
                    children: [
                      Center(
                        child: Image.file(
                          widget.imageFile,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: NetworkImage(
                                      'https://i.pravatar.cc/150?img=5'),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '오선회',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.black),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 좌측 화살표 (이전)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: Colors.white, size: 32),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('이전 스토리 (미구현)')),
                  );
                },
              ),
            ),
          ),

          // 우측 화살표 (다음)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.arrow_forward_ios,
                    color: Colors.white, size: 32),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('다음 스토리 (미구현)')),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
