import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'archive_screen.dart';

class MyInfoScreen extends StatefulWidget {
  const MyInfoScreen({super.key});

  @override
  State<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends State<MyInfoScreen> {
  bool _isLoading = true;
  String _email = '';
  String _displayName = '사용자';
  String _major = '컴퓨터공학과';
  int _completedProjects = 0;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? '알 수 없음';
    final completed = prefs.getInt('completed_projects') ?? 0;
    final major = prefs.getString('user_major') ?? '컴퓨터공학과';

    final displayName = email.contains('@') ? email.split('@')[0] : email;

    if (mounted) {
      setState(() {
        _email = email;
        _displayName = displayName;
        _major = major;
        _completedProjects = completed;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text(
            '내 정보',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.person, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayName,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _major,
                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ArchiveScreen(completedProjects: _completedProjects),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.shade400.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                '완료 프로젝트',
                                style: TextStyle(fontSize: 12, color: Colors.white),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$_completedProjects',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 6),
                              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.email, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(child: Text('이메일: $_email')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('프로필 정보는 현재 임시 페이지로 제공됩니다.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('추가 기능', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('• 프로필 편집'),
        ],
      ),
    );
  }
}