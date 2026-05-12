import 'package:flutter/material.dart';

class CreateProjectModal extends StatefulWidget {
  const CreateProjectModal({super.key});

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

  void _postProject() {
    if (selectedType == null ||
        projectNameController.text.isEmpty ||
        descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필수 항목을 모두 입력해주세요.')),
      );
      return;
    }

    print('프로젝트 생성: $selectedType, ${projectNameController.text}, 인원: $recruitCount');
    Navigator.pop(context);
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
              Row(
                children: [
                  _buildTypeButton('팀플'),
                  const SizedBox(width: 8),
                  _buildTypeButton('대외활동'),
                ],
              ),
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
                  Text(
                    '최대 인원: $recruitCount명',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
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
                      onPressed: () => Navigator.pop(context),
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
                      onPressed: _postProject,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('게시하기'),
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
