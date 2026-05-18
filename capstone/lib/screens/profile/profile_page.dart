import 'dart:convert';
import 'my_clubs_page.dart';
import '../auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'edit_profile_page.dart'; // 상단에 import 추가

class ProfilePage extends StatefulWidget {
  final String? name;
  final String? email;
  final String? profileImageBase64;

  const ProfilePage({
    super.key,
    this.name,
    this.email,
    this.profileImageBase64,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late String? _name;
  late String? _email;
  late String? _profileImageBase64;

  @override
  void initState() {
    super.initState();
    _name = widget.name;
    _email = widget.email;
    _profileImageBase64 = widget.profileImageBase64;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF6FC),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            // 프로필 사진
            CircleAvatar(
              radius: 48,
              backgroundImage: (_profileImageBase64 != null && _profileImageBase64!.isNotEmpty)
                  ? MemoryImage(base64Decode(_profileImageBase64!))
                  : null,
              child: (_profileImageBase64 == null || _profileImageBase64!.isEmpty)
                  ? const Icon(Icons.person, size: 48)
                  : null,
            ),
            const SizedBox(height: 16),
            // 이름
            Text(_name ?? '', style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            // 학번(이메일)
            Text(
              _email ?? '',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            // 메뉴 리스트
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit, color: Colors.purple),
                    title: const Text('내 정보 수정'),
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfilePage(
                            currentName: _name ?? '',
                            currentEmail: _email ?? '',
                          ),
                        ),
                      );
                      // 수정된 정보가 돌아오면 화면에 반영
                      if (result != null && result is Map) {
                        setState(() {
                          _name = result['name'] ?? _name;
                          _email = result['email'] ?? _email;
                          _profileImageBase64 = result['profileImage'] ?? _profileImageBase64;
                        });
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.group, color: Colors.purple),
                    title: const Text('내가 가입한 동아리'),
                    onTap: () {
                      // 실제로는 로그인한 유저의 id를 사용해야 합니다.
                      // 예시로 1을 사용 (실제 로그인 연동 시 userId 변수로 대체)
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MyClubsPage(userId: 1),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings, color: Colors.purple),
                    title: const Text('앱 설정'),
                    onTap: () => _showNotImplemented(context, '앱 설정'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.feedback, color: Colors.purple),
                    title: const Text('문의/피드백'),
                    onTap: () => _showNotImplemented(context, '문의/피드백'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.info, color: Colors.purple),
                    title: const Text('앱 정보'),
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'capstone',
                      applicationVersion: '1.0.0',
                      applicationLegalese: '© 2025 capstone',
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      '로그아웃',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: _logout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _showNotImplemented(BuildContext context, String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature(은)는 준비 중입니다.')));
  }
}
