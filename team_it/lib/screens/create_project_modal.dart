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

  String? selectedType;
  List<String> selectedRequirements = [];
  int recruitCount = 1;
  bool _isLoading = false;

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

  Future<void> _postProject() async {
    // 필수 항목 검증
    if (selectedType == null || projectNameController.text.isEmpty || descriptionController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('필수 항목을 모두 입력해주세요.')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
        return;
      }

      // 요청 데이터 구성
      final Map<String, dynamic> requestBody = {
        'name': projectNameController.text,
        'description': descriptionController.text,
        'category': selectedType,
        'recruit_count': recruitCount,
        'requirements': selectedRequirements,
      };

      print('[DEBUG] 프로젝트 생성 요청: $requestBody');

      final response = await http.post(
        Uri.parse('$API_BASE_URL/projects/'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
        body: jsonEncode(requestBody),
      );

      print('[DEBUG] 응답 상태 코드: ${response.statusCode}');
      print('[DEBUG] 응답 본문: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        // 프로젝트 생성 성공
        final responseData = jsonDecode(response.body);

        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('프로젝트가 생성되었습니다!'), duration: Duration(seconds: 2)));

        // 콜백 함수 호출 (부모 위젯에 프로젝트 생성 완료 알림)
        widget.onProjectCreated();

        // 모달 닫기
        if (!mounted) return;
        Navigator.pop(context);
      } else if (response.statusCode == 401) {
        // 인증 실패
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('인증이 만료되었습니다. 다시 로그인해주세요.')));
      } else {
        // 기타 오류
        if (!mounted) return;
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData.toString();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('프로젝트 생성 실패: $errorMessage')));
      }
    } catch (e) {
      print('[DEBUG] 예외 발생: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
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

              const Text('유형', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Row(children: [_buildTypeButton('팀플'), const SizedBox(width: 8), _buildTypeButton('대외활동')]),
              const SizedBox(height: 20),

              const Text('프로젝트명', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: projectNameController,
                decoration: InputDecoration(
                  hintText: '프로젝트 이름을 입력해주세요',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              const Text('모집 인원', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                  Text('최대 인원: $recruitCount명', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 16),

              const Text('요구사항', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: requirementController,
                decoration: InputDecoration(
                  hintText: 'ex) Figma, 디자인, ...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
                          label: Text(req, style: const TextStyle(fontSize: 12)),
                          onDeleted: () => _removeRequirement(req),
                          backgroundColor: Colors.blue[100],
                          deleteIcon: const Icon(Icons.close, size: 16),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 16),

              const Text('프로젝트 설명', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: '프로젝트에 대해 설명해주세요.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.grey),
                      ),
                      child: const Text('취소', style: TextStyle(color: Colors.black)),
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
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
            style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
