import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String API_BASE_URL = 'http://team-it.iptime.org:8000/api';

class CreateProjectModal extends StatefulWidget {
  final Function onProjectCreated; // 프로젝트 생성 후 콜백 함수

  const CreateProjectModal({super.key, required this.onProjectCreated});

  @override
  State<CreateProjectModal> createState() => _CreateProjectModalState();
}

class _CreateProjectModalState extends State<CreateProjectModal> {
  final TextEditingController projectNameController = TextEditingController();
  final TextEditingController requirementController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController recruitmentPeriodController =
      TextEditingController();

  String? selectedType;
  List<String> selectedRequirements = [];
  int recruitCount = 1;
  bool _isLoading = false;
  DateTime? _recruitmentStartDate;
  DateTime? _recruitmentEndDate;

  final List<String> availableRequirements = [
    'Figma',
    '디자인',
    'Flutter',
    'React',
    'Node.js',
    'Python',
    'AI/ML',
    '데이터분석',
  ];

  void _addRequirement(String req) {
    if (!selectedRequirements.contains(req)) {
      setState(() {
        selectedRequirements.add(req);
      });
    }
  }

  void _removeRequirement(String req) {
    setState(() {
      selectedRequirements.remove(req);
    });
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year/$month/$day';
  }

  String _formatApiDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _pickRecruitmentPeriod() async {
    final now = DateTime.now();
    final initialDateRange =
        _recruitmentStartDate != null && _recruitmentEndDate != null
        ? DateTimeRange(
            start: _recruitmentStartDate!,
            end: _recruitmentEndDate!,
          )
        : DateTimeRange(start: now, end: now.add(const Duration(days: 7)));

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      initialDateRange: initialDateRange,
      helpText: '모집 기간 선택',
      saveText: '선택',
      cancelText: '취소',
      fieldStartLabelText: '시작일',
      fieldEndLabelText: '종료일',
    );

    if (picked == null) return;

    setState(() {
      _recruitmentStartDate = picked.start;
      _recruitmentEndDate = picked.end;
      recruitmentPeriodController.text =
          '${_formatDate(picked.start)}~${_formatDate(picked.end)}';
    });
  }

  String? _projectIdFromResponse(http.Response response) {
    if (response.body.isEmpty) return null;

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final value = decoded['id'] ?? decoded['pk'] ?? decoded['project_id'];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<bool> _createProjectChatRoom({
    required String projectId,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('$API_BASE_URL/projects/$projectId/create_chat_room/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
      body: jsonEncode({
        'name': '${projectNameController.text} 채팅방',
        'description': '${projectNameController.text} 프로젝트 채팅방',
      }),
    );

    print('[DEBUG] 채팅방 생성 응답 상태 코드: ${response.statusCode}');
    print('[DEBUG] 채팅방 생성 응답 본문: ${response.body}');

    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<String?> _findCreatedProjectId(String token) async {
    Future<String?> findFrom(Uri uri) async {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) return null;

      final projectName = projectNameController.text.trim();
      for (final project in decoded) {
        if (project is! Map) continue;
        final title = '${project['name'] ?? project['title'] ?? ''}'.trim();
        final id = project['id'] ?? project['pk'] ?? project['project_id'];

        if (title == projectName &&
            id != null &&
            id.toString().trim().isNotEmpty) {
          return id.toString();
        }
      }

      return null;
    }

    return await findFrom(Uri.parse('$API_BASE_URL/projects/?my=true')) ??
        await findFrom(Uri.parse('$API_BASE_URL/projects/'));
  }

  Future<void> _cacheRecruitmentPeriod(String? projectId) async {
    final period = recruitmentPeriodController.text.trim();

    final prefs = await SharedPreferences.getInstance();
    if (projectId != null && projectId.trim().isNotEmpty) {
      if (period.isNotEmpty) {
        await prefs.setString('project_period_$projectId', period);
      }
      await prefs.setBool('project_owner_$projectId', true);
    }

    final title = projectNameController.text.trim();
    if (period.isNotEmpty) {
      await prefs.setString('project_period_title_$title', period);
    }
    await prefs.setBool('project_owner_title_$title', true);
  }

  Future<void> _postProject() async {
    // 필수 항목 검증
    if (selectedType == null ||
        projectNameController.text.isEmpty ||
        recruitmentPeriodController.text.isEmpty ||
        descriptionController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('필수 항목을 모두 입력해주세요.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // SharedPreferences에서 토큰 조회
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
        return;
      }

      // 요청 데이터 구성
      final Map<String, dynamic> requestBody = {
        'name': projectNameController.text,
        'description': descriptionController.text,
        'category': selectedType,
        'recruit_count': recruitCount,
        'requirements': selectedRequirements,
        'application_period': recruitmentPeriodController.text,
        'recruitment_period': recruitmentPeriodController.text,
        'period': recruitmentPeriodController.text,
        if (_recruitmentStartDate != null)
          'application_start_date': _formatApiDate(_recruitmentStartDate!),
        if (_recruitmentEndDate != null)
          'application_end_date': _formatApiDate(_recruitmentEndDate!),
        if (_recruitmentStartDate != null)
          'recruitment_start_date': _formatApiDate(_recruitmentStartDate!),
        if (_recruitmentEndDate != null)
          'recruitment_end_date': _formatApiDate(_recruitmentEndDate!),
      };

      print('[DEBUG] 프로젝트 생성 요청: $requestBody');

      final response = await http.post(
        Uri.parse('$API_BASE_URL/projects/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode(requestBody),
      );

      print('[DEBUG] 응답 상태 코드: ${response.statusCode}');
      print('[DEBUG] 응답 본문: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        // 프로젝트 생성 성공
        final projectId =
            _projectIdFromResponse(response) ??
            await _findCreatedProjectId(token);
        var chatRoomCreated = false;

        if (projectId != null) {
          await _cacheRecruitmentPeriod(projectId);
          chatRoomCreated = await _createProjectChatRoom(
            projectId: projectId,
            token: token,
          );
        } else {
          await _cacheRecruitmentPeriod(null);
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              projectId == null
                  ? '프로젝트가 생성되었습니다. 채팅방은 프로젝트 ID 응답이 오면 생성됩니다.'
                  : chatRoomCreated
                  ? '프로젝트와 채팅방이 생성되었습니다!'
                  : '프로젝트가 생성되었습니다. 채팅방 생성은 실패했습니다.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        // 콜백 함수 호출 (부모 위젯에 프로젝트 생성 완료 알림)
        widget.onProjectCreated();

        // 모달 닫기
        if (!mounted) return;
        Navigator.pop(context);
      } else if (response.statusCode == 401) {
        // 인증 실패
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인증이 만료되었습니다. 다시 로그인해주세요.')),
        );
      } else {
        // 기타 오류
        if (!mounted) return;
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData.toString();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('프로젝트 생성 실패: $errorMessage')));
      }
    } catch (e) {
      print('[DEBUG] 예외 발생: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    projectNameController.dispose();
    requirementController.dispose();
    recruitmentPeriodController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),

              const Text(
                '유형',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildTypeButton('팀플'),
                  const SizedBox(width: 8),
                  _buildTypeButton('대외활동'),
                ],
              ),
              const SizedBox(height: 20),

              const Text(
                '프로젝트명',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: projectNameController,
                decoration: InputDecoration(
                  hintText: '프로젝트 이름을 입력해주세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                '모집 인원',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Column(
                children: [
                  Slider(
                    value: recruitCount.toDouble(),
                    onChanged: (value) {
                      setState(() {
                        recruitCount = value.toInt();
                      });
                    },
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$recruitCount명',
                    activeColor: Colors.indigo,
                  ),
                  Text(
                    '최대 인원: $recruitCount명',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text(
                '요구사항',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: requirementController,
                decoration: InputDecoration(
                  hintText: 'ex) Figma, 디자인, ...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: ElevatedButton(
                      onPressed: () {
                        if (requirementController.text.isNotEmpty) {
                          _addRequirement(requirementController.text.trim());
                          requirementController.clear();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('추가', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (selectedRequirements.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: selectedRequirements
                      .map(
                        (req) => Chip(
                          label: Text(
                            req,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onDeleted: () => _removeRequirement(req),
                          backgroundColor: Colors.blue[100],
                          deleteIcon: const Icon(Icons.close, size: 16),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 16),

              const Text(
                '모집 기간',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: recruitmentPeriodController,
                readOnly: true,
                onTap: _isLoading ? null : _pickRecruitmentPeriod,
                decoration: InputDecoration(
                  hintText: '날짜를 선택해주세요',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today_outlined, size: 20),
                    onPressed: _isLoading ? null : _pickRecruitmentPeriod,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                '프로젝트 설명',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: '프로젝트에 대해 설명해주세요.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.grey),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _postProject,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('게시하기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String type) {
    bool isSelected = selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.white,
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            type,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
