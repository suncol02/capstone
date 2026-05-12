import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'login_screen.dart';

// API 기본 URL (백엔드 서버 주소로 변경 필요)
const String API_BASE_URL = 'http://team-it.iptime.org/api';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 현재 선택된 하단 탭 인덱스
  int _selectedIndex = 0;

  // 각 탭에 대응하는 화면 리스트
  final List<Widget> _screens = [
    const ProjectList(category: '수업팀플'),
    const ProjectList(category: '대외활동'),
    const ProjectList(category: '알림'),
    const Center(child: Text('내 정보 / 프로필 화면 (준비 중)')),
  ];

  // 로그아웃 함수
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_email');

    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Team-it',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          // 로그아웃 버튼
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),

      // 현재 인덱스에 맞는 화면 표시
      body: _screens[_selectedIndex],

      // 하단 내비게이션 바 (언더바)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // 아이콘 고정
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.school), label: '수업팀플'),
          BottomNavigationBarItem(icon: Icon(Icons.group_work), label: '대외활동'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '내 정보'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: '알림'),
        ],
      ),

      // 팀원 모집 글쓰기 버튼
      floatingActionButton: _selectedIndex != 2
          // '내 정보' 탭에서는 안 보이게 설정 가능
          ? FloatingActionButton(
              onPressed: () => print('글쓰기 버튼 클릭'),
              backgroundColor: Colors.blue,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}

// 프로젝트 리스트 위젯 (재사용 가능하게 분리)
class ProjectList extends StatefulWidget {
  final String category;
  const ProjectList({super.key, required this.category});

  @override
  State<ProjectList> createState() => _ProjectListState();
}

class _ProjectListState extends State<ProjectList> {
  bool _isLoading = true;
  List<dynamic> _projects = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      // SharedPreferences에서 토큰 조회
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      // 토큰이 없으면 로그인 화면으로 이동
      if (token == null) {
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
        }
        return;
      }

      final response = await http.get(
        Uri.parse('$API_BASE_URL/projects/'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _projects = data;
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        // 인증 실패 - 로그인 화면으로 이동
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
        }
      } else {
        setState(() {
          _error = '프로젝트 로드 실패 (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '오류: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadProjects();
              },
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_projects.isEmpty) {
      return const Center(child: Text('프로젝트가 없습니다.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _projects.length,
      itemBuilder: (context, index) {
        final project = _projects[index];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text('${index + 1}', style: const TextStyle(color: Colors.blue)),
            ),
            title: Text(project['name'] ?? '제목 없음', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(project['description'] ?? '설명 없음', maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ProjectDetailScreen(project: project)));
            },
          ),
        );
      },
    );
  }
}

/// 프로젝트 상세 화면
class ProjectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project['name'] ?? 'Project'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 프로젝트 정보
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.project['name'] ?? '제목 없음',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(widget.project['description'] ?? '설명이 없습니다', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
