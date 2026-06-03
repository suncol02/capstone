import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'edit_project_modal.dart';
import 'applicants_modal.dart';
import 'project_evaluation_screen.dart';

const String API_BASE_URL = 'http://team-it.iptime.org:8000/api';

class ProjectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  bool _isApplying = false;
  bool _hasApplied = false;
  bool _isOwner = false;
  String? _localApplicationPeriod;
  String _applicationStatus = 'none';

  @override
  void initState() {
    super.initState();
    _loadLocalProjectMeta();
    _checkApplicationStatus();
    _saveRecentlyViewedProject();
    _refreshProjectData();
  }

  int _parseInt(dynamic value, {required int defaultValue}) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  List<String> _parseRequirements(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  String _projectTitle() {
    return '${widget.project['name'] ?? widget.project['title'] ?? '제목 없음'}';
  }

  String? _projectId() {
    final value =
        widget.project['id'] ??
        widget.project['pk'] ??
        widget.project['project_id'];
    if (value == null || value.toString().trim().isEmpty) return null;
    return value.toString();
  }

  String? _ownerValue() {
    final owner =
        widget.project['owner'] ??
        widget.project['leader'] ??
        widget.project['created_by'] ??
        widget.project['user'];

    if (owner is Map) {
      final value =
          owner['email'] ??
          owner['username'] ??
          owner['name'] ??
          owner['id']?.toString() ??
          owner['pk']?.toString();
      return value?.toString();
    }

    final value =
        widget.project['owner_email'] ??
        widget.project['leader_email'] ??
        widget.project['creator_email'] ??
        widget.project['owner_id'];

    return value?.toString() ?? owner?.toString();
  }

  Future<void> _loadLocalProjectMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    final userId = prefs.getString('user_id');
    final projectId = _projectId();
    final owner = _ownerValue();
    final title = _projectTitle();

    String? period;
    bool localOwner = false;
    if (projectId != null) {
      period = prefs.getString('project_period_$projectId');
      localOwner = prefs.getBool('project_owner_$projectId') ?? false;

      if (prefs.getBool('applied_$projectId') == true) {
        _hasApplied = true;
        _applicationStatus = 'pending';
      }
    }


    final ownsProject =
        owner != null &&
        owner.trim().isNotEmpty &&
        (owner == email ||
            owner == userId ||
            owner == prefs.getString('username') ||
            owner == prefs.getString('user_id'));

    if (!mounted) return;
    setState(() {
      _localApplicationPeriod = period;
      _isOwner = localOwner || ownsProject;
    });
  }

  Future<void> _checkApplicationStatus() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final projectId = _projectId();
    if (token == null || projectId == null) return;

    final response = await http.get(
      Uri.parse('$API_BASE_URL/projects/$projectId/my_application/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200 && mounted) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final appStatus = decoded['status'] ?? 'none';
      setState(() {
        _applicationStatus = appStatus;
        _hasApplied = (appStatus == 'pending' || appStatus == 'accepted');
      });
    }
  } catch (e) {
    print('[DEBUG] 지원 현황 검증 오류: $e');
  }
}

  Future<void> _refreshProjectData() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  final projectId = _projectId();
  if (token == null || projectId == null) return;

  final response = await http.get(
    Uri.parse('$API_BASE_URL/projects/$projectId/'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    },
  );

  if (response.statusCode == 200 && mounted) {
  final data = jsonDecode(utf8.decode(response.bodyBytes));
  setState(() {
    widget.project['current_participants'] = data['current_participants']; 
    widget.project['current_members'] = data['current_members'];
    widget.project['member_count'] = data['member_count'];
    widget.project['members'] = data['members'];
    widget.project['status'] = data['status'];
    });
  }
}

// 프로젝트 완료 API 호출
Future<void> _completeProject() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  final projectId = _projectId();
  if (token == null || projectId == null) return;

  final response = await http.post(
    Uri.parse('$API_BASE_URL/projects/$projectId/complete/'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    },
  );

  if (response.statusCode == 200 && mounted) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    setState(() {
      widget.project['status'] = data['project_status'];
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectEvaluationScreen(project: widget.project),
      ),
    );
  }
}

Widget _buildBottomButton(bool isFull, String title, bool canApply, String buttonText) {
  final projectStatus = widget.project['status'] ?? '';
  final isCompleted = projectStatus == '완료';

  print('[DEBUG] projectStatus: $projectStatus');
  print('[DEBUG] isCompleted: $isCompleted');
  print('[DEBUG] _applicationStatus: $_applicationStatus');
  print('[DEBUG] _isOwner: $_isOwner');

  if (isCompleted && (_isOwner || _applicationStatus == 'accepted')) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectEvaluationScreen(project: widget.project),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF9B98EB),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: const Text(
        '평가하기',
        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  if (_isOwner) {
    return isFull
        ? ElevatedButton(
            onPressed: _completeProject,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B98EB),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              '프로젝트 완료',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          )
        : OutlinedButton.icon(
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (context) => ApplicantsModal(
                  projectId: _projectId() ?? '',
                  projectTitle: title,
                ),
              );
              if (mounted) await _refreshProjectData();
            },
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('신청 인원 확인'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6F6CDF),
              side: const BorderSide(color: Color(0xFF9B98EB)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          );
  }

  // 팀원
  return ElevatedButton(
    onPressed: canApply ? _applyToProject : null,
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF9B98EB),
      disabledBackgroundColor: Colors.grey.shade400,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    child: _isApplying
        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Text(buttonText, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
  );
}

  Future<void> _saveRecentlyViewedProject() async {
    final prefs = await SharedPreferences.getInstance();
    final projectId = _projectId();
    if (projectId == null) return;

    try {
      final recentlyViewedJson =
          prefs.getString('recently_viewed_projects') ?? '[]';
      List<dynamic> recentlyViewed = jsonDecode(recentlyViewedJson);

      final newProject = {
        'id': projectId,
        'name': _projectTitle(),
        'title': _projectTitle(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      recentlyViewed
          .removeWhere((p) => p['id'].toString() == projectId.toString());

      recentlyViewed.insert(0, newProject);

      if (recentlyViewed.length > 10) {
        recentlyViewed = recentlyViewed.sublist(0, 10);
      }

      await prefs.setString(
        'recently_viewed_projects',
        jsonEncode(recentlyViewed),
      );
    } catch (e) {
      print('[DEBUG] 최근 본 프로젝트 저장 실패: $e');
    }
  }

  String _formatDateText(dynamic value) {
    if (value == null) return '';
    final text = value.toString().trim();
    if (text.isEmpty) return '';
    return text.replaceAll('-', '/');
  }

  String _applicationPeriod() {
    final direct =
        widget.project['application_period'] ??
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
    if (_localApplicationPeriod != null &&
        _localApplicationPeriod!.trim().isNotEmpty) {
      return _localApplicationPeriod!;
    }

    return '모집 기간 정보가 없습니다.';
  }

  String _responseMessage(http.Response response, String fallback) {
    if (response.body.isEmpty) return fallback;

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        final message =
            decoded['message'] ?? decoded['detail'] ?? decoded['error'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }
      return decoded.toString();
    } catch (_) {
      final contentType = response.headers['content-type'] ?? '';
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final trimmed = body.trimLeft().toLowerCase();
      if (contentType.contains('text/html') ||
          trimmed.startsWith('<!doctype html') ||
          trimmed.startsWith('<html')) {
        return fallback;
      }
      return body.trim().isEmpty ? fallback : body;
    }
  }

  Future<http.Response> _sendApplyRequest(
    String projectId,
    String token,
  ) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    };

    final projectApply = await http.post(
      Uri.parse('$API_BASE_URL/projects/$projectId/apply/'),
      headers: headers,
    );

    if (projectApply.statusCode != 404) return projectApply;

    return await http.post(
      Uri.parse('$API_BASE_URL/projects/$projectId/join/'),
      headers: headers,
    );
  }

  Future<void> _applyToProject() async {
    if (_isApplying || _hasApplied) return;

    final projectId = _projectId();
    if (projectId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('프로젝트 정보를 찾을 수 없습니다.')));
      return;
    }

    setState(() {
      _isApplying = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
        return;
      }

      final response = await _sendApplyRequest(projectId, token);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final currentCount = _parseInt(
          widget.project['current_participants'] ??
              widget.project['current_members'] ??
              widget.project['member_count'],
          defaultValue: 0,
        );

        await prefs.setBool('applied_$projectId', true);

        if (!mounted) return;
        setState(() {
          _hasApplied = true;
          _applicationStatus = 'pending';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_responseMessage(response, '신청이 완료되었습니다.'))),
        );
      } else if (response.statusCode == 400 || response.statusCode == 409) {
        await prefs.setBool('applied_$projectId', true);
        if (!mounted) return;
        setState(() {
          _hasApplied = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_responseMessage(response, '이미 신청한 프로젝트입니다.')),
          ),
        );
      } else if (response.statusCode == 401) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인증이 만료되었습니다. 다시 로그인해주세요.')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_responseMessage(response, '신청에 실패했습니다.'))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  Future<void> _deleteProject() async {
    final projectId = _projectId();
    if (projectId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('삭제할 프로젝트 정보를 찾을 수 없습니다.')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('프로젝트 삭제'),
        content: const Text('이 프로젝트를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
        return;
      }

      final response = await http.delete(
        Uri.parse('$API_BASE_URL/projects/$projectId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (!mounted) return;
      if (response.statusCode == 200 ||
          response.statusCode == 202 ||
          response.statusCode == 204) {
        await prefs.remove('project_period_$projectId');
        await prefs.remove('project_owner_$projectId');
        await prefs.remove('project_period_title_${_projectTitle()}');
        await prefs.remove('project_owner_title_${_projectTitle()}');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('프로젝트가 삭제되었습니다.')));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_responseMessage(response, '삭제에 실패했습니다.'))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
    }
  }

  void _handleOwnerMenu(String value) {
    if (value == 'edit') {
      showDialog<Map<String, dynamic>?>(
        context: context,
        builder: (context) => EditProjectModal(
          project: widget.project,
          onProjectUpdated: () {
            setState(() {});
          },
        ),
      ).then((result) {
        if (result != null) {
          setState(() {
            widget.project['name'] = result['name'];
            widget.project['title'] = result['name'];
            widget.project['description'] = result['description'];
            widget.project['recruit_count'] = result['recruit_count'];
            widget.project['requirements_list'] = result['requirements_list'];
            widget.project['requirements'] = result['requirements_list'];
            widget.project['application_period'] = result['application_period'];
            widget.project['recruitment_period'] = result['recruitment_period'];
            widget.project['period'] = result['period'];
            if (result['application_start_date'] != null) {
              widget.project['application_start_date'] =
                  result['application_start_date'];
            }
            if (result['application_end_date'] != null) {
              widget.project['application_end_date'] =
                  result['application_end_date'];
            }
          });
        }
      });
      return;
    }

    if (value == 'delete') {
      _deleteProject();
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final title = _projectTitle();
    final description = '${project['description'] ?? '프로젝트 설명'}';
    final applicationPeriod = _applicationPeriod();

    final maxCount = _parseInt(project['recruit_count'], defaultValue: 3);
    final currentCount = _parseInt(
      project['current_participants'] ??
          project['current_members'] ??
          project['member_count'],
      defaultValue: 1,
    );
    final progress = maxCount > 0
        ? (currentCount / maxCount).clamp(0.0, 1.0)
        : 0.0;
    final isOpen = currentCount < maxCount;
    final isFull = currentCount >= maxCount; // ★ 추가: 인원이 찼는지 확인
    final requirements = _parseRequirements(
      project['requirements_list'] ?? project['requirements'],
    );

    String buttonText = '신청하기';
    bool canApply = isOpen && !_isApplying && !_hasApplied && _applicationStatus != 'accepted' && _applicationStatus != 'rejected';

    if (_applicationStatus == 'accepted') {
      buttonText = '가입된 프로젝트입니다.';
      canApply = false;
    } else if (_applicationStatus == 'pending' || _hasApplied) {
      buttonText = '신청 완료';
      canApply = false;
    } else if (_applicationStatus == 'rejected') {
      buttonText = '신청 거절됨';
      canApply = false;
    } else if (!isOpen) {
      buttonText = '모집 마감';
      canApply = false;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (_isOwner)
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_horiz),
                                    onSelected: _handleOwnerMenu,
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('수정'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('삭제'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isOpen
                                    ? const Color(0xFFDDF3D7)
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                isOpen ? '모집중' : '모집마감',
                                style: TextStyle(
                                  color: isOpen
                                      ? const Color(0xFF6DAA5B)
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F7),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            size: 18,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 18,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$currentCount/$maxCount 명',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF9FC3F9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Divider(color: Colors.grey.shade300),
                  const SizedBox(height: 20),
                  const Text(
                    '요구사항',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  if (requirements.isEmpty)
                    Text(
                      '요구사항 정보가 없습니다.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: requirements.map((req) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8ECFF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            req,
                            style: const TextStyle(
                              color: Color(0xFF7B8EDB),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 28),
                  Divider(color: Colors.grey.shade300),
                  const SizedBox(height: 20),
                  const Text(
                    '모집 기간',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    applicationPeriod,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Divider(color: Colors.grey.shade300),
                  const SizedBox(height: 20),
                  const Text(
                    '프로젝트 설명',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: _buildBottomButton(isFull, title, canApply, buttonText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}