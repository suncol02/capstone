import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'project_detail_screen.dart';

const String API_BASE_URL = 'http://team-it.iptime.org:8000/api';

class RecentlyViewedScreen extends StatefulWidget {
  const RecentlyViewedScreen({super.key});

  @override
  State<RecentlyViewedScreen> createState() => _RecentlyViewedScreenState();
}

class _RecentlyViewedScreenState extends State<RecentlyViewedScreen> {
  List<Map<String, dynamic>> _recentlyViewed = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentlyViewed();
  }

  Future<void> _loadRecentlyViewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentlyViewedJson =
          prefs.getString('recently_viewed_projects') ?? '[]';
      final List<dynamic> parsed = jsonDecode(recentlyViewedJson);

      setState(() {
        _recentlyViewed =
            parsed.cast<Map<String, dynamic>>().toList();
        _isLoading = false;
      });
    } catch (e) {
      print('[DEBUG] 최근 본 프로젝트 로드 실패: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchProjectDetails(String projectId) async {
    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/projects/$projectId/'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      print('[DEBUG] 프로젝트 상세 조회 실패: $e');
    }
    return null;
  }

  void _openProjectDetail(Map<String, dynamic> project) async {
    // 상세 정보가 없으면 API에서 조회
    if (project['current_participants'] == null) {
      final details = await _fetchProjectDetails(project['id'].toString());
      if (details != null) {
        project = {...project, ...details};
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailScreen(project: project),
      ),
    ).then((_) {
      // 돌아올 때 목록 새로고침
      _loadRecentlyViewed();
    });
  }

  Future<void> _removeFromRecentlyViewed(String projectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentlyViewedJson =
          prefs.getString('recently_viewed_projects') ?? '[]';
      List<dynamic> recentlyViewed = jsonDecode(recentlyViewedJson);

      recentlyViewed
          .removeWhere((p) => p['id'].toString() == projectId.toString());

      await prefs.setString(
        'recently_viewed_projects',
        jsonEncode(recentlyViewed),
      );

      setState(() {
        _recentlyViewed.removeWhere((p) => p['id'].toString() == projectId.toString());
      });
    } catch (e) {
      print('[DEBUG] 최근 본 프로젝트 삭제 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('최근 본 글'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recentlyViewed.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '최근 본 글이 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _recentlyViewed.length,
                  itemBuilder: (context, index) {
                    final project = _recentlyViewed[index];
                    final projectId = project['id'].toString();
                    final title =
                        project['name'] ?? project['title'] ?? '제목 없음';
                    final timestamp = project['timestamp'] != null
                        ? DateTime.parse(project['timestamp'])
                        : null;
                    final timeAgo = timestamp != null
                        ? _formatTimeAgo(timestamp)
                        : '방금 전';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.folder_outlined,
                            color: Colors.indigo,
                          ),
                        ),
                        title: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        trailing: SizedBox(
                          width: 48,
                          child: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'remove') {
                                _removeFromRecentlyViewed(projectId);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'remove',
                                child: Text('삭제'),
                              ),
                            ],
                          ),
                        ),
                        onTap: () => _openProjectDetail(project),
                      ),
                    );
                  },
                ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${dateTime.month}월 ${dateTime.day}일';
    }
  }
}
