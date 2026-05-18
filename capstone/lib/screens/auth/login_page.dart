import 'package:flutter/material.dart';
import '../home/home_page.dart';
import '../auth/signup_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  Future login(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    var url = Uri.parse('http://192.168.45.204:5000/login');

    try {
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'email': emailController.text,
          'password': passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final responseJson = json.decode(response.body);
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('email', emailController.text);
        await prefs.setString('name', responseJson['name']);
        // user_id 저장 추가
        if (responseJson['user_id'] != null) {
          await prefs.setInt('user_id', responseJson['user_id']);
        }
        // 프로필 이미지가 null/빈 문자열이 아닐 때만 저장
        final serverProfileImage = responseJson['profile_image'];
        if (serverProfileImage != null &&
            serverProfileImage.toString().isNotEmpty) {
          await prefs.setString('profile_image', serverProfileImage);
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('로그인 실패'),
                content: const Text('이메일 또는 비밀번호가 잘못되었습니다.'),
                actions: [
                  TextButton(
                    child: const Text('확인'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('에러'),
              content: const Text('서버에 연결할 수 없습니다.'),
              actions: [
                TextButton(
                  child: const Text('확인'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF6FC),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              Image.asset(
                'image/university_logo.png',
                width: 100,
                errorBuilder: (context, error, stackTrace) {
                  return const Text(
                    '이미지를 불러올 수 없습니다.',
                    style: TextStyle(color: Colors.red),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                '배재클럽 - 배재인 동아리 커뮤니티',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Login to your account',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // ID 입력
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'ID',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(height: 20),

              // Password 입력
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed:
                          () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible,
                          ),
                    ),
                  ),
                  obscureText: !_isPasswordVisible,
                ),
              ),
              const SizedBox(height: 40),

              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                    onPressed: () => login(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlueAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 100,
                        vertical: 20,
                      ),
                    ),
                    child: const Text(
                      "Login",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),

              const SizedBox(height: 20),

              // ➕ Signup 버튼
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignUpPage()),
                  );
                },
                child: const Text(
                  'Signup',
                  style: TextStyle(
                    color: Colors.grey,
                    decoration: TextDecoration.underline,
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
