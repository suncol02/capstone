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

  List<Map<String, dynamic>> _members = [];
  // { 'id': 1, 'name': '홍길동', 'selectedTags': [] }
  int _currentMemberIndex = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _checkAlreadySubmitted();
  }

  Future<void> _loadMembers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final myUserId = prefs.getString('user_id') ?? '';
      final projectId = widget.project['id'] ?? widget.project['pk'];
      if (token == null || projectId == null) return;

      final response = await http.get(
        Uri.parse('$API_BASE_URL/projects/$projectId/applicants/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      print('상태코드: ${response.statusCode}');
      print('응답본문: ${response.body}');


      if (response.statusCode == 200 && mounted) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> applicants = decoded is List ? decoded : [];
        
        final owner = widget.project['owner'];
        final ownerId = (owner is Map ? owner['id'] : null)?.toString() ?? '';
        final ownerName = owner is Map
            ? (owner['first_name']?.isNotEmpty == true
                ? owner['first_name']
                : owner['username'] ?? owner['email'] ?? '팀장')
            : '팀장';

        List<Map<String, dynamic>> members = [];
        final Set<String> addedIds = {};

        // owner 추가 (본인 제외)
        addedIds.add(ownerId);

        
      print('[DEBUG] myUserId: "$myUserId"');
      print('[DEBUG] ownerId: "$ownerId"');
      print('[DEBUG] 같은가: ${ownerId == myUserId}');

        if (ownerId.isNotEmpty && ownerId != myUserId) {
          members.add({
            'id': int.tryParse(ownerId) ?? 0,
            'name': ownerName,
            'selectedTags': <String>[],
          });
        } 

        // 수락된 팀원 추가 (본인 제외)
        for (var app in applicants) {
          if (app['status'] != 'accepted' &&
              app['status'] != 'joined') {
            continue;
          }

          final user = app['user'];

          final memberId = (
            user?['id'] ??
            app['user_id'] ??
            app['id']
          ).toString();

          // 본인 제외
          if (memberId == myUserId) continue;

          // 중복 제거
          if (addedIds.contains(memberId)) continue;

          addedIds.add(memberId);

          final memberName =
              user?['first_name'] ??
              user?['username'] ??
              user?['email'] ??
              app['name'] ??
              app['username'] ??
              app['email'] ??
              '사용자';

          members.add({
            'id': int.tryParse(memberId) ?? 0,
            'name': memberName.toString(),
            'selectedTags': <String>[],
          });
        }

        print('===== 평가 대상 =====');
        for (var m in members) {
          print('${m['id']} / ${m['name']}');
        }
                

        setState(() {
          _members = members;
          _isLoading = false;
        });
      } else {
          print('[DEBUG] applicants 실패: ${response.statusCode}');
          print('[DEBUG] 응답 내용: ${response.body}');
          if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print('[DEBUG] 멤버 로드 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  

  Future<void> _checkAlreadySubmitted() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final projectId = widget.project['id'] ?? widget.project['pk'];
    if (token == null || projectId == null) return;

    final response = await http.get(
      Uri.parse('$API_BASE_URL/projects/$projectId/my_evaluation/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200 && mounted) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['submitted'] == true) {
        setState(() => _hasSubmitted = true);
      }
    }
  }

  String _formatDateText(dynamic value) {
    if (value == null) return '';
    final text = value.toString().trim();
    if (text.isEmpty) return '';
    return text.replaceAll('-', '/');
  }

  String _getProjectPeriod() {
    final direct = widget.project['application_period'] ??
        widget.project['recruitment_period'] ??
        widget.project['period'];
    if (direct != null && direct.toString().trim().isNotEmpty) return direct.toString();
    final start = _formatDateText(widget.project['start_date']);
    final end = _formatDateText(widget.project['end_date']);
    if (start.isNotEmpty && end.isNotEmpty) return '$start~$end';
    return '모집 기간 정보가 없습니다.';
  }

  void _nextMember() {
    if (_currentMemberIndex < _members.length - 1) {
      setState(() => _currentMemberIndex++);
    }
  }

  void _prevMember() {
    if (_currentMemberIndex > 0) {
      setState(() => _currentMemberIndex--);
    }
  }

  bool get _allMembersEvaluated {
    return _members.every((m) => (m['selectedTags'] as List).isNotEmpty);
  }

  Future<void> _submitEvaluations() async {
    if (_isSubmitting || _hasSubmitted) return;
    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final projectId = widget.project['id'] ?? widget.project['pk'];
      if (token == null || projectId == null) return;

      final evaluations = _members.map((m) => {
        'target_id': m['id'],
        'tags': m['selectedTags'],
      }).toList();

      final response = await http.post(
        Uri.parse('$API_BASE_URL/projects/$projectId/evaluate/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({'evaluations': evaluations}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final allSubmitted = data['all_members_submitted'] ?? false;

        setState(() => _hasSubmitted = true);

        if (allSubmitted) {
          // 내가 받은 태그 조회 후 아카이브 저장
          await _saveToArchive(token, projectId);
          if (!mounted) return;
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

  Future<void> _saveToArchive(String token, dynamic projectId) async {
    try {
      // 내가 받은 태그 조회
      final tagsResponse = await http.get(
        Uri.parse('$API_BASE_URL/projects/$projectId/my_tags/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      List<dynamic> myTags = [];
      if (tagsResponse.statusCode == 200) {
        final tagsData = jsonDecode(utf8.decode(tagsResponse.bodyBytes));
        myTags = tagsData['tags'] ?? [];
      }

      final prefs = await SharedPreferences.getInstance();
      final archiveJson = prefs.getString('archived_activities') ?? '[]';
      List<dynamic> archiveList = jsonDecode(archiveJson);
      archiveList.insert(0, {
        'id': projectId.toString(),
        'title': widget.project['name'] ?? widget.project['title'] ?? '프로젝트',
        'period': _getProjectPeriod(),
        'description': widget.project['description'] ?? '',
        'tags': myTags,
      });
      await prefs.setString('archived_activities', jsonEncode(archiveList));
    } catch (e) {
      print('[DEBUG] 아카이브 저장 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          '프로젝트 팀원 평가',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasSubmitted
          ? _buildAlreadySubmitted()
          : _members.isEmpty
          ? const Center(child: Text('평가할 팀원이 없습니다.'))
          : _buildEvaluationBody(),
    );
  }

  Widget _buildAlreadySubmitted() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF9B98EB)),
          const SizedBox(height: 16),
          const Text(
            '이미 평가를 완료했습니다.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '다른 팀원들의 평가를 기다리는 중입니다.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluationBody() {
    final member = _members[_currentMemberIndex];
    final selectedTags = member['selectedTags'] as List<String>;
    final isLast = _currentMemberIndex == _members.length - 1;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 진행 상황
          Row(
            children: List.generate(_members.length, (i) => Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i <= _currentMemberIndex
                      ? const Color(0xFF9B98EB)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )),
          ),
          const SizedBox(height: 8),
          Text(
            '${_currentMemberIndex + 1} / ${_members.length} 명 평가 중',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 24),

          // 멤버 이름
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFFE8ECFF),
                  child: Text(
                    (member['name'] as String)[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      color: Color(0xFF7A82F0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  member['name'] as String,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '이 팀원을 어떻게 평가하시나요?',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 태그 선택
          Expanded(
            child: ListView.builder(
              itemCount: _availableTags.length,
              itemBuilder: (context, index) {
                final item = _availableTags[index];
                final tagString = '${item['emoji']} ${item['text']}';
                final isSelected = selectedTags.contains(tagString);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF9B98EB) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: CheckboxListTile(
                    title: Text(
                      tagString,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    value: isSelected,
                    activeColor: const Color(0xFF9B98EB),
                    onChanged: (bool? value) {
                      setState(() {
                        selectedTags.clear();
                        if (value == true) {
                          selectedTags.add(tagString);
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // 버튼
          Row(
            children: [
              if (_currentMemberIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _prevMember,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFF9B98EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('이전', style: TextStyle(color: Color(0xFF9B98EB))),
                  ),
                ),
              if (_currentMemberIndex > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: selectedTags.isEmpty
                      ? null
                      : isLast
                          ? (_allMembersEvaluated ? _submitEvaluations : null)
                          : _nextMember,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9B98EB),
                    disabledBackgroundColor: Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                          isLast ? '평가 제출하기' : '다음',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}