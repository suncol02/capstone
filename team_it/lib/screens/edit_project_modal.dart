import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String API_BASE_URL = 'http://team-it.iptime.org:8000/api';

class EditProjectModal extends StatefulWidget {
  final Map<String, dynamic> project;
  final Function onProjectUpdated;

  const EditProjectModal({
    super.key,
    required this.project,
    required this.onProjectUpdated,
  });

  @override
  State<EditProjectModal> createState() => _EditProjectModalState();
}

class _EditProjectModalState extends State<EditProjectModal> {
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

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    // 프로젝트명
    projectNameController.text =
        widget.project['name'] ?? widget.project['title'] ?? '';

    // 프로젝트 설명
    descriptionController.text = widget.project['description'] ?? '';

    // 모집 인원
    if (widget.project['recruit_count'] is int) {
      recruitCount = widget.project['recruit_count'];
    } else if (widget.project['recruit_count'] is String) {
      recruitCount =
          int.tryParse(widget.project['recruit_count'].toString()) ?? 1;
    }

    // 요구사항
    _initializeRequirements();

    // 모집 기간
    _initializeRecruitmentPeriod();
  }

  void _initializeRequirements() {
    List<String> requirements = [];

    final reqData =
        widget.project['requirements_list'] ?? widget.project['requirements'];

    if (reqData is List) {
      requirements = reqData.map((e) => e.toString()).toList();
    } else if (reqData is String) {
      requirements =
          reqData.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    setState(() {
      selectedRequirements = requirements;
    });
  }

  void _initializeRecruitmentPeriod() {
    String period = '';

    // 기존 모집 기간 찾기
    final direct = widget.project['application_period'] ??
        widget.project['recruitment_period'] ??
        widget.project['period'] ??
        widget.project['date_range'];

    if (direct != null && direct.toString().trim().isNotEmpty) {
      period = direct.toString();
    } else {
      final startStr = widget.project['application_start_date'] ??
          widget.project['recruitment_start_date'] ??
          widget.project['start_date'];
      final endStr = widget.project['application_end_date'] ??
          widget.project['recruitment_end_date'] ??
          widget.project['end_date'];

      if (startStr != null && endStr != null) {
        period = '${startStr.toString().replaceAll('-', '/')}~${endStr.toString().replaceAll('-', '/')}';

        // DateTime 객체도 설정
        try {
          _recruitmentStartDate = DateTime.parse(startStr.toString());
          _recruitmentEndDate = DateTime.parse(endStr.toString());
        } catch (_) {}
      }
    }

    recruitmentPeriodController.text = period;
  }

  void _addRequirement(String req) {
    if (req.isNotEmpty && !selectedRequirements.contains(req)) {
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

  String? _projectId() {
    final value = widget.project['id'] ??
        widget.project['pk'] ??
        widget.project['project_id'];
    if (value == null || value.toString().trim().isEmpty) return null;
    return value.toString();
  }

  Future<void> _updateProject() async {
    // 필수 항목 검증
    if (projectNameController.text.isEmpty ||
        recruitmentPeriodController.text.isEmpty ||
        descriptionController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필수 항목을 모두 입력해주세요.')),
      );
      return;
    }

    final projectId = _projectId();
    if (projectId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로젝트 정보를 찾을 수 없습니다.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
        return;
      }

      final Map<String, dynamic> requestBody = {
        'name': projectNameController.text,
        'description': descriptionController.text,
        'recruit_count': recruitCount,
        'requirements': selectedRequirements.join(','),
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

      print('[DEBUG] 프로젝트 수정 요청: $requestBody');

      final response = await http.patch(
        Uri.parse('$API_BASE_URL/projects/$projectId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode(requestBody),
      );

      print('[DEBUG] 응답 상태 코드: ${response.statusCode}');
      print('[DEBUG] 응답 본문: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로젝트가 수정되었습니다.')),
        );

        // 수정된 데이터를 반환하며 모달 닫기
        if (!mounted) return;
        Navigator.pop(context, {
          'name': projectNameController.text,
          'description': descriptionController.text,
          'recruit_count': recruitCount,
          'requirements_list': selectedRequirements,
          'application_period': recruitmentPeriodController.text,
          'recruitment_period': recruitmentPeriodController.text,
          'period': recruitmentPeriodController.text,
          if (_recruitmentStartDate != null)
            'application_start_date': _formatApiDate(_recruitmentStartDate!),
          if (_recruitmentEndDate != null)
            'application_end_date': _formatApiDate(_recruitmentEndDate!),
        });
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인증이 만료되었습니다. 다시 로그인해주세요.')),
        );
      } else {
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData.toString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('수정 실패: $errorMessage')),
          );
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('수정에 실패했습니다.')),
          );
        }
      }
    } catch (e) {
      print('[DEBUG] 예외 발생: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
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
                      onPressed: _isLoading ? null : _updateProject,
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
                          : const Text('저장하기'),
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
}
