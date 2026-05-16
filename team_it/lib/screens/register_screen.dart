import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:team_it/widgets/password_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // 프로젝트 성향 옵션
  final List<String> personalities = ['외향적(E)', '내향적(I)', '계획적(J)', '즉흥적(P)'];
  String? selectedPersonality;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController departmentController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    departmentController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();
    final department = departmentController.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty || department.isEmpty || selectedPersonality == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('모든 항목을 입력해주세요.')));
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse('http://team-it.iptime.org:8000/accounts/signup/');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': name,
          'department': department,
          'personality_type': selectedPersonality,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('회원가입이 완료되었습니다. 로그인 해주세요.')));
        Navigator.pop(context);
      } else {
        final respBody = response.body.isNotEmpty ? jsonDecode(response.body) : null;
        print('회원가입 에러 응답: $respBody'); // 디버그용
        final errorMsg = respBody is Map
            ? respBody.values.map((value) => value.toString()).join('\n')
            : '회원가입에 실패했습니다. (응답: ${response.statusCode}, ${response.body})';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('네트워크 오류: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '팀잇 회원가입',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            const SizedBox(height: 32),

            // 학교 웹메일
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: '학교 웹메일',
                hintText: '1234567@pcu.ac.kr',
                border: OutlineInputBorder(),
                helperText: '학교 인증을 위해 웹메일이 필요합니다.',
              ),
            ),
            const SizedBox(height: 16),

            // 이름
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '이름', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            //비밀번호
            HoverPasswordField(label: '비밀번호', controller: passwordController),

            const SizedBox(height: 16),

            // 학과
            TextField(
              controller: departmentController,
              decoration: const InputDecoration(labelText: '학과', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            // 프로젝트 성향 선택
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: '프로젝트 성향', border: OutlineInputBorder()),
              items: personalities.map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
              }).toList(),
              onChanged: (val) => setState(() => selectedPersonality = val),
            ),
            const SizedBox(height: 32),

            // 가입 버튼
            ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('가입하기'),
            ),
          ],
        ),
      ),
    );
  }
}
