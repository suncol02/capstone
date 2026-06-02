import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

const String API_BASE_URL = 'http://team-it.iptime.org:8000/api'; 

class ProjectEvaluationScreen extends StatefulWidget {
  final Map<String, dynamic> project;

  const ProjectEvaluationScreen({super.key, required this.project});

  @override
  State<ProjectEvaluationScreen> createState() => _ProjectEvaluationScreenState();
}

class _ProjectEvaluationScreenState extends State<ProjectEvaluationScreen> {
  final List<Map<String, String>> _availableTags = [
    {'emoji': '👍', 'text': '소통이 잘 돼요'},
    {'emoji': '😎', 'text': '피드백이 정확해요'},
    {'emoji': '⏱️', 'text': '마감일을 잘 지켜요'},
    {'emoji': '🔥', 'text': '열정적이에요'},
  ];

  final List<String> _selectedTags = [];

  String _formatDateText(dynamic value) {
    if (value == null) return '';
    final text = value.toString().trim();
    if (text.isEmpty) return '';
    return text.replaceAll('-', '/');
  }

  String _getProjectPeriod() {
    final direct = widget.project['application_period'] ??
        widget.project['recruitment_period'] ??
        widget.project['period'] ??
        widget.project['date_range'];

    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString();
    }

    final start = _formatDateText(
      widget.project['application_start_date'] ??
          widget.project['recruitment_start_date'] ??
          widget.project['start_date'],
    );
    final end = _formatDateText(
      widget.project['application_end_date'] ??
          widget.project['recruitment_end_date'] ??
          widget.project['end_date'],
    );

    if (start.isNotEmpty && end.isNotEmpty) return '$start~$end';

    return '모집 기간 정보가 없습니다.';
  }

  bool _isSubmitting = false;

Future<void> _completeAndArchive() async {
  if (_isSubmitting) return;
  setState(() => _isSubmitting = true);

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final projectId = widget.project['id'] ?? widget.project['pk'];

    if (token == null || projectId == null) return;

    final feedback = _selectedTags.join(', ');

    final response = await http.post(
      Uri.parse('$API_BASE_URL/projects/$projectId/evaluate/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
      body: jsonEncode({'feedback': feedback}),
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final allSubmitted = data['all_members_submitted'] ?? false;

      if (allSubmitted) {
        // 모든 멤버 제출 완료 → 로컬 아카이브 저장 후 이동
        final archiveJson = prefs.getString('archived_activities') ?? '[]';
        List<dynamic> archiveList = jsonDecode(archiveJson);
        archiveList.insert(0, {
          'id': projectId.toString(),
          'title': widget.project['name'] ?? widget.project['title'] ?? '프로젝트',
          'period': _getProjectPeriod(),
          'description': widget.project['description'] ?? '',
          'tags': _selectedTags.isNotEmpty ? _selectedTags : [],
        });
        await prefs.setString('archived_activities', jsonEncode(archiveList));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('모든 팀원이 평가를 완료했습니다! 아카이브에 등록되었습니다.')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        final submitted = data['submitted_members_count'] ?? 0;
        final required = data['required_members_count'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('평가를 제출했습니다. ($submitted/$required 명 완료)')),
        );
        Navigator.pop(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('평가 제출에 실패했습니다.')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  } finally {
    if (mounted) setState(() => _isSubmitting = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('프로젝트 팀원 평가', 
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '함께한 팀원들에게 상호 평가 피드백을 남겨주세요.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: ListView.builder(
                itemCount: _availableTags.length,
                itemBuilder: (context, index) {
                  final item = _availableTags[index];
                  final tagString = '${item['emoji']} ${item['text']}';
                  final isSelected = _selectedTags.contains(tagString);

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CheckboxListTile(
                      title: Text(
                        tagString,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      value: isSelected,
                      activeColor: const Color(0xFF9B98EB),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedTags.add(tagString);
                          } else {
                            _selectedTags.remove(tagString);
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _completeAndArchive,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B98EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '평가 완료 및 활동 종료',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}