import 'dart:io';
import 'package:flutter/material.dart';
import 'story_camera_page.dart';
import 'story_gallery_picker.dart';

class StoryAddModal extends StatelessWidget {
  final void Function(File) onStoryUploaded; // ✅ 콜백 받기

  const StoryAddModal({super.key, required this.onStoryUploaded});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: 200,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOption(
                context,
                icon: Icons.camera_alt_outlined,
                label: '사진 촬영하기',
                onTap: () async {
                  Navigator.pop(context);
                  final imageFile = await Navigator.push<File?>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StoryCameraPage(),
                    ),
                  );
                  if (imageFile != null) {
                    onStoryUploaded(imageFile);
                  }
                },
              ),
              const SizedBox(height: 8),
              _buildOption(
                context,
                icon: Icons.image_outlined,
                label: '갤러리에서 선택하기',
                onTap: () async {
                  Navigator.pop(context);
                  final imageFile = await Navigator.push<File?>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StoryGalleryPage(),
                    ),
                  );
                  if (imageFile != null) {
                    onStoryUploaded(imageFile);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                Icon(icon, size: 24),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
