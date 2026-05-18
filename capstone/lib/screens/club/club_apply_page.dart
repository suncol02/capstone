import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ClubApplyPage extends StatefulWidget {
  final String clubName; // 동아리 이름
  final int clubId; // 동아리 ID 추가

  const ClubApplyPage({super.key, required this.clubName, required this.clubId});

  @override
  State<ClubApplyPage> createState() => _ClubApplyPageState();
}

class _ClubApplyPageState extends State<ClubApplyPage> {
  String? gender;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController majorController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController introController = TextEditingController();

  void submitApplication() async {
    if (gender == null ||
        nameController.text.isEmpty ||
        majorController.text.isEmpty ||
        phoneController.text.isEmpty ||
        introController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 항목을 입력해주세요.')),
      );
      return;
    }

    // 한 번 더 확인 다이얼로그
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          '이대로 제출하시겠습니까?',
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('이어서 작성하기'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('제출하기'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    // 실제 서버에 가입 신청서 제출
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보가 없습니다.')),
      );
      return;
    }

    final response = await http.post(
      Uri.parse('http://192.168.45.204:5000/clubs/${widget.clubId}/apply'), // clubId 사용
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'gender': gender,
        'name': nameController.text,
        'major': majorController.text,
        'phone': phoneController.text,
        'intro': introController.text,
      }),
    );

    if (response.statusCode == 201) {
      // 제출 성공 시 다이얼로그 닫고, 현재 페이지도 닫기
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('제출이 완료되었습니다!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // 다이얼로그 닫기
                  Navigator.of(context).pop(); // club_apply_page.dart 닫기
                },
                child: const Text('확인'),
              ),
            ],
          ),
        );
        // 이미 다이얼로그에서 pop을 두 번 했으므로 추가 pop 불필요
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('신청 실패: ${response.body}')),
      );
    }
  }

  Widget buildInput({required String title, required Widget input}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.pink[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: input,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('가입 신청하기'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text('${widget.clubName} 가입 신청하기',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const Text('가입 질문에 답해주세요.'),
            const SizedBox(height: 8),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    buildInput(
                      title: '1. 성별을 알려주세요.',
                      input: Column(
                        children: [
                          RadioListTile<String>(
                            title: const Text('남성'),
                            value: '남성',
                            groupValue: gender,
                            onChanged: (value) {
                              setState(() {
                                gender = value;
                              });
                            },
                          ),
                          RadioListTile<String>(
                            title: const Text('여성'),
                            value: '여성',
                            groupValue: gender,
                            onChanged: (value) {
                              setState(() {
                                gender = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    buildInput(
                      title: '2. 성함을 알려주세요.',
                      input: TextField(controller: nameController),
                    ),
                    buildInput(
                      title: '3. 학과와 학번을 알려주세요. (예: 23학번 홍길동)',
                      input: TextField(controller: majorController),
                    ),
                    buildInput(
                      title: '4. 전화번호를 알려주세요.',
                      input: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    buildInput(
                      title:
                          '5. 간단하게 자기소개를 해주세요! (지원 동기, 장단점, 취미 등 자유롭게)',
                      input: TextField(
                        controller: introController,
                        maxLines: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 제출 버튼
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: submitApplication,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    '제출하기',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
