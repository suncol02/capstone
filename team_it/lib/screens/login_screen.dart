import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'main_screen.dart'; // MainScreen 임포트
import 'register_screen.dart'; // RegisterScreen 임포트

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // 서버에 로그인 요청
  Future<void> _login() async {
    final String id = _idController.text.trim();
    final String password = _passwordController.text.trim();

    // 유효성 검사
    if (id.isEmpty || password.isEmpty) {
      _showErrorDialog('아이디와 패스워드를 입력하세요.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 로컬 Django 서버 URL
      final String serverUrl = 'http://team-it.iptime.org:8000/accounts/login/';
      final Map<String, String> requestBody = {'id': id, 'password': password};

      print('[DEBUG] 요청 URL: $serverUrl');
      print('[DEBUG] 요청 헤더: Content-Type: application/json');
      print('[DEBUG] 요청 본문: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            Uri.parse(serverUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id': id, 'password': password}),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('서버 연결 시간 초과');
            },
          );

      // 응답 처리
      if (response.statusCode == 200) {
        // 로그인 성공
        final responseData = jsonDecode(response.body);
        print('[DEBUG] 로그인 응답 전체: $responseData');
        final String token = responseData['token'];
        final String email = responseData['email'];
        final String? department = responseData['department']; // 학과 가져오기
        final String? userId = responseData['id']?.toString() ?? responseData['user_id']?.toString();
        final String? firstName = responseData['first_name']?.toString(); 

        // SharedPreferences에 토큰 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setString('user_email', email);
        if (department != null) {
          await prefs.setString('user_major', department);
        }
        if (userId != null) {
          await prefs.setString('user_id', userId);
        }
        if (firstName != null && firstName.isNotEmpty) { 
          await prefs.setString('first_name', firstName);
        }

        // 메인 화면으로 이동
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen()));
        }
      } else if (response.statusCode == 401) {
        // 인증 실패 (아이디 또는 패스워드 오류)
        _showErrorDialog('아이디 또는 패스워드가 올바르지 않습니다.');
      } else {
        // 기타 서버 오류
        _showErrorDialog('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog('오류: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그인 오류'),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
      ),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            // Team-it 로고
            const Text(
              'team_it',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 40),
            // 이메일 입력
            TextField(
              controller: _idController,
              decoration: const InputDecoration(hintText: '이메일 주소', border: OutlineInputBorder()),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 12),
            // 패스워드 입력
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(hintText: '패스워드', border: OutlineInputBorder()),
              obscureText: true,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 24),
            // 로그인 버튼
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : const Text('로그인', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 12),
            // 회원가입 버튼
            OutlinedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey,
              ),
              child: const Text('회원가입', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
