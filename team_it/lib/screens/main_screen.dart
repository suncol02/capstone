import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'login_screen.dart';
import 'create_project_modal.dart';
import 'my_info_screen.dart';
import 'archive_screen.dart';
import 'project_detail_screen.dart';

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
  final GlobalKey<_ProjectListState> _projectListKey = GlobalKey();

  // 각 탭에 대응하는 화면 리스트
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      ProjectList(key: _projectListKey, category: '전체'),
      const MyInfoScreen(),
      const ArchiveScreen(showAppBar: false),
    ];
  }

  void _openChat() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('채팅은 프로젝트 상세 화면에서 이용할 수 있습니다.')),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_email');

    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
  }

  void _refreshProjectList() {
    _projectListKey.currentState?._loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 1
          ? null
          : AppBar(
              title: const Text(
                'Team-it(로고)',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              ),
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              actions: [
                _selectedIndex == 0
                    ? IconButton(
                        icon: const Icon(Icons.chat_bubble_outline),
                        tooltip: '채팅',
                        onPressed: _openChat,
                      )
                    : IconButton(
                        icon: const Icon(Icons.logout),
                        tooltip: '로그아웃',
                        onPressed: _logout,
                      ),
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
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: '프로젝트'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '내 정보'),
          BottomNavigationBarItem(icon: Icon(Icons.archive), label: '아카이브'),
        ],
      ),

      // 팀원 모집 글쓰기 버튼
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => CreateProjectModal(onProjectCreated: _refreshProjectList),
                );
              },
              backgroundColor: const Color(0xFF8E8CF1),
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white, size: 34),
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
  String _searchQuery = '';
  String _selectedCategory = '팀플';
  String _selectedStatus = '전체';
  final TextEditingController _searchController = TextEditingController();

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

      // 전체 탭에서는 모든 프로젝트를 조회하고, 필요하면 카테고리별 조회도 지원
      final uri = widget.category == '전체'
          ? Uri.parse('$API_BASE_URL/projects/')
          : Uri.parse('$API_BASE_URL/projects/by_category/?category=${widget.category}');

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
    setState(() {
      _searchQuery = query;
    });
  }

  int _parseInt(dynamic value, {required int defaultValue}) {
    if (value is int) return value;
    return int.tryParse('$value') ?? defaultValue;
  }

  String _projectTitle(dynamic project) {
    return '${project['name'] ?? project['title'] ?? '제목 없음'}';
  }

  String _projectCategory(dynamic project) {
    return '${project['category'] ?? ''}';
  }

  int _maxCount(dynamic project) {
    return _parseInt(project['recruit_count'], defaultValue: 3);
  }

  int _currentCount(dynamic project) {
    return project['current_participants'] is int
        ? project['current_participants']
        : project['current_members'] is int
        ? project['current_members']
        : project['member_count'] is int
        ? project['member_count']
        : _parseInt(
            project['current_participants'] ?? project['current_members'] ?? project['member_count'],
            defaultValue: 1,
          );
  }

  bool _isOpen(dynamic project) => _currentCount(project) < _maxCount(project);

  bool _isClosingSoon(dynamic project) {
    final remaining = _maxCount(project) - _currentCount(project);
    return remaining > 0 && remaining <= 2;
  }

  List<String> _requirements(dynamic project) {
    final value = project['requirements_list'] ?? project['requirements'];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) {
      return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return <String>[];
  }

  List<dynamic> _projectsForCategory() {
    return _projects.where((project) {
      final category = _projectCategory(project);
      if (_selectedCategory == '팀플') {
        return category.isEmpty || category == '팀플' || category == '수업 팀플';
      }
      return category == '대외활동' || category == '대외 활동';
    }).toList();
  }

  List<dynamic> _visibleProjects() {
    final lowerQuery = _searchQuery.toLowerCase();

    return _projectsForCategory().where((project) {
      final title = _projectTitle(project).toLowerCase();
      final description = '${project['description'] ?? ''}'.toLowerCase();
      final matchesSearch = lowerQuery.isEmpty || title.contains(lowerQuery) || description.contains(lowerQuery);

      if (!matchesSearch) return false;
      if (_selectedStatus == '모집중') return _isOpen(project);
      if (_selectedStatus == '마감임박') return _isClosingSoon(project);
      return true;
    }).toList();
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

    final categoryProjects = _projectsForCategory();
    final visibleProjects = _visibleProjects();
    final openCount = categoryProjects.where(_isOpen).length;
    final closingCount = categoryProjects.where(_isClosingSoon).length;

    return Container(
      color: const Color(0xFFF7F7F7),
      child: Column(
        children: [
          _CategoryTabs(
            selectedCategory: _selectedCategory,
            onChanged: (category) {
              setState(() {
                _selectedCategory = category;
                _selectedStatus = '전체';
              });
            },
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(19, 28, 19, 96),
              children: [
                _SearchFilterPanel(
                  controller: _searchController,
                  onSearchChanged: _filterProjects,
                  selectedStatus: _selectedStatus,
                  totalCount: categoryProjects.length,
                  openCount: openCount,
                  closingCount: closingCount,
                  onStatusChanged: (status) => setState(() => _selectedStatus = status),
                ),
                const SizedBox(height: 16),
                Text(
                  '${visibleProjects.length} projects found',
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 12),
                ),
                const SizedBox(height: 16),
                if (_projects.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.only(top: 80), child: Text('프로젝트가 없습니다.')))
                else if (visibleProjects.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.only(top: 80), child: Text('검색 결과가 없습니다.')))
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visibleProjects.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 38,
                      childAspectRatio: 0.97,
                    ),
                    itemBuilder: (context, index) {
                      final project = visibleProjects[index];
                      return _ProjectGridCard(
                        title: _projectTitle(project),
                        currentCount: _currentCount(project),
                        maxCount: _maxCount(project),
                        isOpen: _isOpen(project),
                        isClosingSoon: _isClosingSoon(project),
                        requirements: _requirements(project),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ProjectDetailScreen(project: project)),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onChanged;

  const _CategoryTabs({
    required this.selectedCategory,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          _CategoryTab(
            label: '수업 팀플',
            isSelected: selectedCategory == '팀플',
            onTap: () => onChanged('팀플'),
          ),
          _CategoryTab(
            label: '대외 활동',
            isSelected: selectedCategory == '대외활동',
            onTap: () => onChanged('대외활동'),
          ),
        ],
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            const SizedBox(height: 18),
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 78,
              height: 3,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF8E8CF1) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchFilterPanel extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final String selectedStatus;
  final int totalCount;
  final int openCount;
  final int closingCount;
  final ValueChanged<String> onStatusChanged;

  const _SearchFilterPanel({
    required this.controller,
    required this.onSearchChanged,
    required this.selectedStatus,
    required this.totalCount,
    required this.openCount,
    required this.closingCount,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 38,
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: '프로젝트 검색',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: Colors.black87, size: 24),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.blueGrey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF8E8CF1)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _StatusChip(
                label: 'All($totalCount)',
                isSelected: selectedStatus == '전체',
                background: Colors.black,
                foreground: Colors.white,
                onTap: () => onStatusChanged('전체'),
              ),
              const SizedBox(width: 8),
              _StatusChip(
                label: '모집중($openCount)',
                isSelected: selectedStatus == '모집중',
                background: const Color(0xFFD9F4CF),
                foreground: const Color(0xFF5DB75B),
                onTap: () => onStatusChanged('모집중'),
              ),
              const SizedBox(width: 8),
              _StatusChip(
                label: '마감임박($closingCount)',
                isSelected: selectedStatus == '마감임박',
                background: const Color(0xFFFFF1B8),
                foreground: const Color(0xFFFFA620),
                onTap: () => onStatusChanged('마감임박'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.isSelected,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? background : background.withOpacity(0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: isSelected ? background : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ProjectGridCard extends StatefulWidget {
  final String title;
  final int currentCount;
  final int maxCount;
  final bool isOpen;
  final bool isClosingSoon;
  final List<String> requirements;
  final VoidCallback onTap;

  const _ProjectGridCard({
    required this.title,
    required this.currentCount,
    required this.maxCount,
    required this.isOpen,
    required this.isClosingSoon,
    required this.requirements,
    required this.onTap,
  });

  @override
  State<_ProjectGridCard> createState() => _ProjectGridCardState();
}

class _ProjectGridCardState extends State<_ProjectGridCard> {
  bool isFavorite = false;

  Future<void> toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();

    List<String> favorites = prefs.getStringList('favorite_projects') ?? [];

    if (favorites.contains(widget.title)) {
      favorites.remove(widget.title);
      isFavorite = false;
    } else {
      favorites.add(widget.title);
      isFavorite = true;
    }

    await prefs.setStringList('favorite_projects', favorites);

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    loadFavorite();
  }

  Future<void> loadFavorite() async {
    final prefs = await SharedPreferences.getInstance();

    List<String> favorites = prefs.getStringList('favorite_projects') ?? [];

    setState(() {
      isFavorite = favorites.contains(widget.title);
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel =
        widget.isOpen
            ? (widget.isClosingSoon ? '마감 임박' : '모집중')
            : '마감';

    final statusBg =
        widget.isOpen
            ? (widget.isClosingSoon
                ? const Color(0xFFFFF1B8)
                : const Color(0xFFD9F4CF))
            : Colors.grey.shade200;

    final statusColor =
        widget.isOpen
            ? (widget.isClosingSoon
                ? const Color(0xFFFFA620)
                : const Color(0xFF5DB75B))
            : Colors.grey.shade700;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: toggleFavorite,
                    child: Icon(
                      isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 17,
                      color:
                          isFavorite ? Colors.red : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.people_alt, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.currentCount}/${widget.maxCount}명',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children:
                    widget.requirements.take(2).map((req) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9ECFF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          req,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF7A82F0),
                            fontSize: 9,
                          ),
                        ),
                      );
                    }).toList(),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 20,
                child: OutlinedButton(
                  onPressed: widget.onTap,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: const BorderSide(
                      color: Color(0xFF8E8CF1),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'View Details',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.black87,
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