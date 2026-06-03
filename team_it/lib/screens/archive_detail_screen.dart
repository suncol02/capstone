import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String API_BASE_URL = 'http://team-it.iptime.org:8000/api';

class ArchiveDetailScreen extends StatefulWidget {
  final Map<String, dynamic> activity;

  const ArchiveDetailScreen({super.key, required this.activity});

  @override
  State<ArchiveDetailScreen> createState() => _ArchiveDetailScreenState();
}

class _ArchiveDetailScreenState extends State<ArchiveDetailScreen> {
  String _major = '정보 없음';
  List<dynamic> _tags = [];

  @override
  void initState() {
    super.initState();
    _loadUserMajor();
    _loadTags();
  }

  Future<void> _loadUserMajor() async {
    final prefs = await SharedPreferences.getInstance();
    final majorData = prefs.getString('user_major') ?? '';
    if (mounted) {
      setState(() {
        _major = majorData.trim().isNotEmpty ? majorData.trim() : '정보 없음';
      });
    }
  }

  Future<void> _loadTags() async {
    final projectDetail = widget.activity['project_detail'] as Map<String, dynamic>?;
    final projectId = projectDetail?['id'] ?? widget.activity['project'];
    if (projectId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    final response = await http.get(
      Uri.parse('$API_BASE_URL/projects/$projectId/my_tags/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200 && mounted) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        _tags = data['tags'] ?? [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectDetail = widget.activity['project_detail'] as Map<String, dynamic>?;

    // ✅ project_detail에서 이름 우선 읽기
    final String title = projectDetail?['name']
        ?? projectDetail?['title']
        ?? widget.activity['title']
        ?? widget.activity['name']
        ?? '완료 프로젝트';

    final String description = projectDetail?['description']
        ?? widget.activity['description']
        ?? '상세 설명 정보가 없습니다.';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: Color(0xFFEBEBEB),
                  child: Icon(Icons.emoji_emotions_outlined, size: 28, color: Color(0xFF9B98EB)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _major,
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('프로젝트 상세 설명', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                description,
                style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
              ),
            ),
            const SizedBox(height: 24),
            const Text('획득한 태그', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            _tags.isEmpty
                ? const Text('획득한 태그가 없습니다.', style: TextStyle(fontSize: 13, color: Colors.black54))
                : Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: _tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFEBEBEB)),
                        ),
                        child: Text(
                          tag.toString(),
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 28),
            const Text('증빙 파일 또는 링크', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.link, color: Colors.black87, size: 20),
                  SizedBox(width: 10),
                  Expanded(child: Text('', style: TextStyle(fontSize: 14))),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.description_outlined, color: Colors.black87, size: 20),
                  SizedBox(width: 10),
                  Expanded(child: Text('', style: TextStyle(fontSize: 14))),
                  Icon(Icons.download_rounded, color: Colors.black87, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}