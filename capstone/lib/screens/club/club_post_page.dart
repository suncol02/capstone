import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';

class ClubPostPage extends StatefulWidget {
  final int? clubId;
  const ClubPostPage({super.key, this.clubId});

  @override
  State<ClubPostPage> createState() => _ClubPostPageState();
}

class _ClubPostPageState extends State<ClubPostPage> {
  final TextEditingController _captionController = TextEditingController();
  File? _imageFile;
  String? _base64Image;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // API URL 초기화
    _initializeApi();
  }

  Future<void> _initializeApi() async {
    try {
      await ApiConfig.initializeUrls();
    } catch (e) {
      print('API 초기화 실패: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        final bytes = await imageFile.readAsBytes();
        
        setState(() {
          _imageFile = imageFile;
          _base64Image = base64Encode(bytes);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 선택 실패: $e')),
      );
    }
  }

  Future<void> _submitPost() async {
    final caption = _captionController.text.trim();
    if (_base64Image == null || _base64Image!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지는 필수입니다.')),
      );
      return;
    }
    if (widget.clubId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('동아리 정보가 올바르지 않습니다.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    final name = prefs.getString('name');

    if (email == null || email.isEmpty || name == null || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 이용해 주세요.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 동적 URL 사용
      await ApiConfig.initializeUrls();
      
      final response = await http.post(
        Uri.parse(ApiConfig.postsUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'email': email,
          'name': name,
          'image': _base64Image ?? "",
          'caption': caption,
          'club_id': widget.clubId,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("업로드 실패: ${response.statusCode}")),
        );
      }
    } catch (e) {
      print('게시글 업로드 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("서버에 연결할 수 없습니다.")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("게시글 업로드")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _captionController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: "내용을 입력하세요",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            _imageFile != null
                ? Image.file(_imageFile!, height: 200, fit: BoxFit.cover)
                : const SizedBox.shrink(),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: const Text("이미지 선택"),
            ),
            const SizedBox(height: 16),

            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                  onPressed: _submitPost,
                  child: const Text("업로드"),
                ),
          ],
        ),
      ),
    );
  }
}
