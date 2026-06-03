import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'archive_detail_screen.dart';
import 'package:http/http.dart' as http;  

const String API_BASE_URL = 'http://team-it.iptime.org:8000/api';

class ArchiveScreen extends StatefulWidget {
  final bool showAppBar;
  final String? userId;
  final String? userName;
  
  const ArchiveScreen({super.key, this.showAppBar = true, this.userId, this.userName});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  bool _isLoading = true;
  String _displayName = '사용자';
  String _major = '정보 없음';
  List<Map<String, dynamic>> _completedProjects = [];

  @override
  void initState() {
    super.initState();
    _loadArchive();
  }

  Future<void> _loadArchive() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  final email = prefs.getString('user_email') ?? '';
  final majorData = prefs.getString('user_major') ?? '';

  if (widget.userId != null) {
    final response = await http.get(
      Uri.parse('$API_BASE_URL/projects/user/${widget.userId}/archives/'),
      headers: {'Authorization': 'Token $token'},
    );
    print('[DEBUG] user_archives 상태코드: ${response.statusCode}');
    print('[DEBUG] user_archives 응답: ${response.body}');
    if (response.statusCode == 200 && mounted) {
      final List<dynamic> data = jsonDecode(response.body);
      setState(() {
        _displayName = widget.userName ?? '팀원'; // ← 이미 넘어온 name 사용
        _major = '';
        _completedProjects = data.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    }
  } else {
    final archiveJson = prefs.getString('archived_activities') ?? '[]';
    final archive = jsonDecode(archiveJson);
    final projects = (archive is List ? archive : [])
        .cast<Map<String, dynamic>>()
        .toList();

    final firstName = prefs.getString('first_name') ?? '';  
    final displayName = firstName.isNotEmpty               
        ? firstName
        : (email.contains('@') ? email.split('@')[0] : (email.isEmpty ? '사용자' : email));

    if (mounted) {
      setState(() {
        _displayName = displayName;  
        _major = majorData.trim().isNotEmpty ? majorData.trim() : '정보 없음';
        _completedProjects = projects;
        _isLoading = false;
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        title: Text(widget.userName ?? (widget.userId != null ? '팀원 아카이브' : '나의 아카이브')),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: content,
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: const Color(0xFFF3F3F3),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            widget.userId != null ? '${widget.userName ?? '팀원'}의 아카이브' : '나의 아카이브',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          _ArchiveProfile(name: _displayName, major: _major),
          const SizedBox(height: 18),
          _ArchiveProgress(completedCount: _completedProjects.length),
          const SizedBox(height: 18),
          Text(
            '완료한 활동 ${_completedProjects.length}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (_completedProjects.isEmpty)
            const _EmptyArchive()
          else
            ..._completedProjects.map((project) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CompletedActivityTile(project: project),
              );
            }),
        ],
      ),
    );
  }
}

class _ArchiveProfile extends StatelessWidget {
  final String name;
  final String major;

  const _ArchiveProfile({required this.name, required this.major});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey.shade300,
          child: const Icon(Icons.person, color: Colors.white, size: 42),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          major,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }
}

class _ArchiveProgress extends StatelessWidget {
  final int completedCount;

  const _ArchiveProgress({required this.completedCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '프로젝트 완료 개수', 
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          Text(
            '$completedCount개',
            style: const TextStyle(
              color: Color(0xFFFF8F1F),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedActivityTile extends StatelessWidget {
  final Map<String, dynamic> project;

  const _CompletedActivityTile({required this.project});

  @override
  Widget build(BuildContext context) {
    final title = project['name'] ?? project['title'] ?? '완료 프로젝트';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArchiveDetailScreen(activity: project),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.brown.shade100,
              child: const Icon(Icons.groups, color: Colors.brown),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}

class _EmptyArchive extends StatelessWidget {
  const _EmptyArchive();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(Icons.archive_outlined, size: 44, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          const Text(
            '완료한 활동이 없습니다.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}