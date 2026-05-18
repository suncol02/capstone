import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscureText = true;
  bool _isLoading = false;
  String? _idCheckMessage;

  Future<void> _checkId() async {
    String id = _idController.text.trim();
    if (id.isEmpty) {
      setState(() {
        _idCheckMessage = "학번을 입력하세요.";
      });
      return;
    }

    try {
      var url = Uri.parse('http://192.168.45.204:5000/check-email');
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'email': id}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _idCheckMessage = "사용 가능한 학번입니다.";
        });
      } else if (response.statusCode == 409) {
        setState(() {
          _idCheckMessage = "이미 존재하는 학번입니다.";
        });
      } else {
        setState(() {
          _idCheckMessage = "오류가 발생했습니다.";
        });
      }
    } catch (e) {
      setState(() {
        _idCheckMessage = "서버 오류가 발생했습니다.";
      });
    }
  }

  Future<void> _submitForm() async {
    String id = _idController.text.trim();
    String name = _nameController.text.trim();
    String password = _passwordController.text.trim();

    if (id.isEmpty || name.isEmpty || password.isEmpty) {
      _showDialog("입력 오류", "모든 항목을 입력해주세요.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      var url = Uri.parse('http://192.168.45.204:5000/register');
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'email': id, 'name': name, 'password': password}),
      );

      if (response.statusCode == 201) {
        // 회원가입 성공 시 user_id가 응답에 있다면 저장
        var responseBody = jsonDecode(response.body);
        if (responseBody['user_id'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('user_id', responseBody['user_id']);
        }
        _showDialog(
          "회원가입 성공",
          "가입이 완료되었습니다.",
          onConfirm: () {
            Navigator.pop(context);
          },
        );
      } else {
        var responseBody = jsonDecode(response.body);
        _showDialog("회원가입 실패", responseBody['message'] ?? '오류가 발생했습니다.');
      }
    } catch (e) {
      _showDialog("서버 오류", "서버와 연결할 수 없습니다.");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showDialog(String title, String content, {VoidCallback? onConfirm}) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (onConfirm != null) onConfirm();
                },
                child: const Text("확인"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF6FC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ← 뒤로가기 버튼 (동작 포함)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.pop(context); // ← 동작 추가됨
                  },
                ),
              ),
              const SizedBox(height: 20),

              const Center(
                child: Text(
                  "회원가입",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 30),

              // 학번 입력
              TextField(
                controller: _idController,
                decoration: const InputDecoration(
                  hintText: '학번',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),

              // 중복 확인 버튼 가운데 정렬
              Center(
                child: ElevatedButton(
                  onPressed: _checkId,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "중복확인",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),

              if (_idCheckMessage != null) ...[
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    _idCheckMessage!,
                    style: TextStyle(
                      color:
                          _idCheckMessage == "사용 가능한 학번입니다."
                              ? Colors.green
                              : Colors.red,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // 이름 입력
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: '이름',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 비밀번호 입력
              TextField(
                controller: _passwordController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  hintText: '비밀번호/6~12자 영문 대소문자, 숫자를 사용하세요.',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        '회원가입',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
