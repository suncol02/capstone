import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'login_screen.dart';
import 'create_project_modal.dart';
import 'my_info_screen.dart';

// API 기본 URL (백엔드 서버 주소로 변경 필요)
const String API_BASE_URL = 'http://team-it.iptime.org:8000/api';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 현재 선택된 하단 탭 인덱스
  int _selectedIndex = 0;

  // ProjectList의 상태에 접근하기 위한 GlobalKey
  final GlobalKey<_ProjectListState> _projectListKey1 = GlobalKey();
  final GlobalKey<_ProjectListState> _projectListKey2 = GlobalKey();

  // 각 탭에 대응하는 화면 리스트
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      ProjectList(key: _projectListKey1, category: '팀플'),
      ProjectList(key: _projectListKey2, category: '대외활동'),
      const MyInfoScreen(),
      const ProjectList(category: '알림'),
    ];
  }

  // 로그아웃 함수
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_email');

    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
  }

  void _refreshProjectList() {
    // 현재 선택된 탭에 따라 해당하는 ProjectList 새로고침
    if (_selectedIndex == 0) {
      _projectListKey1.currentState?._loadProjects();
    } else if (_selectedIndex == 1) {
      _projectListKey2.currentState?._loadProjects();
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
          BottomNavigationBarItem(icon: Icon(Icons.school), label: '팀플'),
          BottomNavigationBarItem(icon: Icon(Icons.group_work), label: '대외활동'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '내 정보'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: '알림'),
        ],
      ),

      // 팀원 모집 글쓰기 버튼
      floatingActionButton: _selectedIndex < 2
          ? FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => CreateProjectModal(onProjectCreated: _refreshProjectList),
                );
              },
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
  List<dynamic> _filteredProjects = [];
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      // 알림 탭인 경우 특수 처리
      if (widget.category == '알림') {
        setState(() {
          _isLoading = false;
          _projects = [];
        });
        return;
      }

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

      // 카테고리별 필터링 URL
      final uri = Uri.parse('$API_BASE_URL/projects/by_category/?category=${widget.category}');

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
      );

      print('[DEBUG] 카테고리: ${widget.category}, 상태 코드: ${response.statusCode}');
      print('[DEBUG] 응답: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _projects = data;
            _filteredProjects = data;
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        // 인증 실패 - 로그인 화면으로 이동
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
        }
      } else {
        if (mounted) {
          setState(() {
            _error = '프로젝트 로드 실패 (${response.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('[DEBUG] 예외 발생: $e');
      if (mounted) {
        setState(() {
          _error = '오류: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterProjects(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      _searchQuery = query;
      _filteredProjects = _projects.where((project) {
        final title = '${project['name'] ?? ''}'.toLowerCase();
        final description = '${project['description'] ?? ''}'.toLowerCase();
        return title.contains(lowerQuery) || description.contains(lowerQuery);
      }).toList();
    });
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: _filterProjects,
            decoration: InputDecoration(
              hintText: '프로젝트 검색',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
          ),
        ),
        Expanded(
          child: _filteredProjects.isEmpty
              ? const Center(child: Text('검색 결과가 없습니다.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: _filteredProjects.length,
                  itemBuilder: (context, index) {
              final project = _filteredProjects[index];
        final int maxCount = project['recruit_count'] is int
            ? project['recruit_count']
            : int.tryParse('${project['recruit_count']}') ?? 3;
        final int currentCount = project['current_participants'] is int
            ? project['current_participants']
            : project['current_members'] is int
                ? project['current_members']
                : project['member_count'] is int
                    ? project['member_count']
                    : int.tryParse('${project['current_participants'] ?? project['current_members'] ?? project['member_count']}') ?? 1;
        final double progress = maxCount > 0 ? (currentCount / maxCount).clamp(0.0, 1.0) : 0.0;
        final bool isOpen = currentCount < maxCount;
        final List<String> requirements = (project['requirements'] is List)
            ? (project['requirements'] as List).map((e) => e.toString()).toList()
            : project['requirements'] is String
                ? project['requirements'].toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
                : <String>[];

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ProjectDetailScreen(project: project)));
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          project['name'] ?? '제목 없음',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isOpen ? Colors.green.shade100 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isOpen ? '모집중' : '모집마감',
                          style: TextStyle(
                            color: isOpen ? Colors.green.shade800 : Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 18, color: Colors.black87),
                      const SizedBox(width: 6),
                      Text(
                        '$currentCount/$maxCount명',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(isOpen ? Colors.blue : Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (requirements.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: requirements
                          .map(
                            (req) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(req, style: const TextStyle(fontSize: 12, color: Colors.blue)),
                            ),
                          )
                          .toList(),
                    ),
                  if (requirements.isNotEmpty) const SizedBox(height: 12),
                  Text(
                    project['description'] ?? '설명 없음',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'View Details',
                      style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
                ),
        ),
      ],
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
  int _parseInt(dynamic value, {required int defaultValue}) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  List<String> _parseRequirements(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) {
      return value
          .split(',')
          .map((text) => text.trim())
          .where((text) => text.isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final String title = project['name'] ?? '제목 없음';
    final String description = project['description'] ?? '설명이 없습니다';
    final int maxCount = _parseInt(project['recruit_count'], defaultValue: 3);
    final int currentCount = project['current_participants'] is int
        ? project['current_participants']
        : project['current_members'] is int
            ? project['current_members']
            : project['member_count'] is int
                ? project['member_count']
                : _parseInt(project['current_participants'] ?? project['current_members'] ?? project['member_count'], defaultValue: 1);
    final double progress = maxCount > 0 ? (currentCount / maxCount).clamp(0.0, 1.0) : 0.0;
    final bool isOpen = currentCount < maxCount;
    final List<String> requirements = _parseRequirements(project['requirements']);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isOpen ? Colors.green.shade100 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isOpen ? '모집중' : '모집마감',
                      style: TextStyle(
                        color: isOpen ? Colors.green.shade800 : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 18, color: Colors.black54),
                      const SizedBox(width: 8),
                      Text('$currentCount/$maxCount명', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(isOpen ? Colors.blue : Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (requirements.isNotEmpty) ...[
                    const Text('Required Skills', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: requirements
                          .map(
                            (req) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(req, style: const TextStyle(color: Colors.blue, fontSize: 12)),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                  ],
                  const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(description, style: TextStyle(color: Colors.grey.shade800, height: 1.5)),
                  const SizedBox(height: 24),
                  const Text(
                    '지금 바로 신청하고 참여를 시작하세요.',
                    style: TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('신청하기 기능은 준비 중입니다.')));
                      },
                      icon: const Icon(Icons.send, size: 20),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('신청하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
