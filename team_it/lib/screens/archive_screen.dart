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

    try {
      if (widget.userId != null) {
        final response = await http.get(
          Uri.parse('$API_BASE_URL/projects/user/${widget.userId}/archives/'),
          headers: {'Authorization': 'Token $token'},
        );

        if (response.statusCode == 200 && mounted) {
          final List<dynamic> data = jsonDecode(response.body);

          final List<Map<String, dynamic>> parsedList = [];
          final Set<int> seenProjectIds = {};

          for (var item in data) {
            if (item is Map) {
              final mappedItem = Map<String, dynamic>.from(item);
              final projectId = mappedItem['project'];

              if (projectId != null && !seenProjectIds.contains(projectId)) {
                seenProjectIds.add(projectId);
                parsedList.add(mappedItem);
              }
            }
          }

          setState(() {
            _displayName = widget.userName ?? '팀원';
            _major = '';
            _completedProjects = parsedList;
            _isLoading = false;
          });
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        final response = await http.get(
          Uri.parse('$API_BASE_URL/archives/'),
          headers: {'Authorization': 'Token $token'},
        );

        final firstName = prefs.getString('first_name') ?? '';
        final displayName = firstName.isNotEmpty
            ? firstName
            : (email.contains('@')
                ? email.split('@')[0]
                : (email.isEmpty ? '사용자' : email));

        if (response.statusCode == 200 && mounted) {
          final List<dynamic> data = jsonDecode(response.body);

          final List<Map<String, dynamic>> parsedList = [];
          final Set<int> seenProjectIds = {};

          for (var item in data) {
            if (item is Map) {
              final mappedItem = Map<String, dynamic>.from(item);
              final projectId = mappedItem['project'];

              if (projectId != null && !seenProjectIds.contains(projectId)) {
                seenProjectIds.add(projectId);
                parsedList.add(mappedItem);
              }
            }
          }

          setState(() {
            _displayName = displayName;
            _major = majorData.trim().isNotEmpty ? majorData.trim() : '정보 없음';
            _completedProjects = parsedList;
            _isLoading = false;
          });
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _averageRating {
    if (_completedProjects.isEmpty) return 0.0;
    final ratings = _completedProjects
        .map((p) => (p['rating'] as num?)?.toDouble() ?? 0.0)
        .toList();
    final total = ratings.reduce((a, b) => a + b);
    return total / ratings.length;
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (!widget.showAppBar) return content;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        title: Text(widget.userName ??
            (widget.userId != null ? '팀원 아카이브' : '나의 아카이브')),
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
            widget.userId != null
                ? '${widget.userName ?? '팀원'}의 아카이브'
                : '나의 아카이브',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          _ArchiveProfile(name: _displayName, major: _major),
          const SizedBox(height: 18),
          _ArchiveProgress(completedCount: _completedProjects.length),
          const SizedBox(height: 12),
          _ArchiveRating(averageRating: _averageRating),
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
        Text(name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(major,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('프로젝트 완료 개수',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Text(
            '$completedCount개',
            style: const TextStyle(
                color: Color(0xFFFF8F1F),
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ArchiveRating extends StatelessWidget {
  final double averageRating;

  const _ArchiveRating({required this.averageRating});

  String get _ratingLabel {
    if (averageRating == 0) return '아직 평가 없음';
    if (averageRating < 1.5) return '별로예요';
    if (averageRating < 2.5) return '아쉬워요';
    if (averageRating < 3.5) return '보통이에요';
    if (averageRating < 4.5) return '좋아요';
    return '최고예요';
  }

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
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('팀원 평균 평점',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Row(
            children: [
              Row(
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  final filled = averageRating >= starIndex;
                  final halfFilled =
                      !filled && averageRating >= starIndex - 0.5;
                  return Icon(
                    filled
                        ? Icons.star
                        : halfFilled
                            ? Icons.star_half
                            : Icons.star_border,
                    color: (filled || halfFilled)
                        ? const Color(0xFFFFBF00)
                        : Colors.grey.shade300,
                    size: 20,
                  );
                }),
              ),
              const SizedBox(width: 8),
              Text(
                averageRating == 0
                    ? '-'
                    : averageRating.toStringAsFixed(1),
                style: const TextStyle(
                    color: Color(0xFFFF8F1F),
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              Text(
                _ratingLabel,
                style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ],
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
    final projectDetail = project['project_detail'] as Map<String, dynamic>?;
    final title = projectDetail?['title'] ??
        projectDetail?['name'] ??
        project['title'] ??
        project['name'] ??
        '완료 프로젝트';

    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    ArchiveDetailScreen(activity: project)));
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
                offset: const Offset(0, 3))
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
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
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
          color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Icon(Icons.archive_outlined, size: 44, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          const Text('완료한 활동이 없습니다.',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}