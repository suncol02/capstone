import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // SharedPreferences import 추가
import '../club/club_apply_page.dart';
import '../club/club_post_page.dart';
import '../club/club_post_detail_page.dart';
import '../settings/settings_page.dart'; // SettingsPage import 추가

class ClubDetailPage extends StatefulWidget {
  final int clubId;
  const ClubDetailPage({super.key, required this.clubId});

  @override
  State<ClubDetailPage> createState() => _ClubDetailPageState();
}

class _ClubDetailPageState extends State<ClubDetailPage> {
  Map<String, dynamic>? club;
  bool _isLoading = true;
  List<dynamic> posts = [];
  int? currentUserId;
  bool _changed = false;

  // 신청 상태 변수는 클래스 필드로 선언
  bool isApplied = false;
  String applyStatus = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUserIdAndFetchClub();
    fetchPosts();
  }

  Future<void> _loadCurrentUserIdAndFetchClub() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUserId = prefs.getInt('user_id');
    });
    await fetchClub();
    await _fetchApplyStatus(); // club 정보와 신청 상태를 반드시 연속으로 불러옴
  }

  Future<void> fetchClub() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      // clubs.py 기준으로 동아리 상세 정보 호출
      final response = await http.get(
        Uri.parse('http://192.168.45.204:5000/clubs/${widget.clubId}'),
      );
      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          club = jsonDecode(response.body);
        });
      }
    } catch (e) {
      // 에러 처리
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> fetchPosts() async {
    try {
      // clubs.py 기준으로 동아리 게시글 목록 호출
      final response = await http.get(
        Uri.parse('http://192.168.45.204:5000/clubs/${widget.clubId}/posts'),
      );
      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          posts = jsonDecode(response.body);
        });
      }
    } catch (e) {
      // 에러 처리
    }
  }

  @override
  void dispose() {
    // 비동기 작업에서 setState 호출 방지용
    super.dispose();
  }

  // 동아리 소개/설명 수정 다이얼로그
  Future<void> _showEditDialog() async {
    final nameController = TextEditingController(text: club?['name'] ?? '');
    final descController = TextEditingController(
      text: club?['description'] ?? '',
    );
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('동아리 정보 수정'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '동아리명',
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20), // 간격 추가
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: '소개/설명',
                    isDense: true,
                  ),
                  maxLines: 1,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final patchRes = await http.patch(
                    Uri.parse('http://192.168.45.204:5000/clubs/${widget.clubId}'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'name': nameController.text,
                      'description': descController.text,
                    }),
                  );
                  if (patchRes.statusCode == 200) {
                    setState(() {
                      club?['name'] = nameController.text;
                      club?['description'] = descController.text;
                      _changed = true;
                    });
                    Navigator.pop(context, true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('수정에 실패했습니다.')),
                    );
                  }
                },
                child: const Text('저장'),
              ),
            ],
          ),
    );
    if (result == true) {
      setState(() {}); // 화면 갱신
    }
  }

  // 게시글 작성 후 돌아오면 목록 새로고침
  Future<void> _goToPostPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClubPostPage(clubId: widget.clubId), // clubId로 정확히 전달
      ),
    );
    fetchPosts();
  }

  // 신청 상태를 서버에서 받아오는 함수 (클래스 필드 사용)
  Future<void> _fetchApplyStatus() async {
    if (currentUserId == null) return;
    try {
      final res = await http.get(
        Uri.parse('http://192.168.45.204:5000/clubs/${widget.clubId}/apply/status/$currentUserId'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          isApplied = data['applied'] == true;
          applyStatus = data['status'] ?? '';
        });
      }
    } catch (_) {}
  }

  bool get isOwner {
    if (club == null || currentUserId == null) return false;
    final dynamic presidentId = club!['president_id'];
    return presidentId != null && int.tryParse(presidentId.toString()) == currentUserId;
  }
  bool get isVicePresident {
    if (club == null || currentUserId == null) return false;
    // vice_president_id 필드가 있으면 우선 비교
    final dynamic vicePresidentId = club!['vice_president_id'];
    if (vicePresidentId != null && int.tryParse(vicePresidentId.toString()) == currentUserId) {
      return true;
    }
    // members 리스트에서 role이 '부회장'인 멤버가 본인인지 확인
    if (club!['members'] != null) {
      return (club!['members'] as List).any((m) =>
        m['user_id'] == currentUserId && (m['role'] == '부회장')
      );
    }
    return false;
  }
  bool get isMember {
    if (club == null || currentUserId == null) return false;
    // 동아리장/부회장은 무조건 멤버로 간주
    if (isOwner || isVicePresident) return true;
    if (club!['members'] == null) return false;
    return (club!['members'] as List).any((m) {
      final dynamic uid = m['user_id'];
      return uid != null && int.tryParse(uid.toString()) == currentUserId;
    });
  }
  bool get canWritePost => isOwner || isVicePresident;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (club == null) {
      return const Scaffold(body: Center(child: Text('동아리 정보를 불러올 수 없습니다.')));
    }
    // 멤버 수 계산 (동아리원 수)
    final int memberCount =
        club?['members'] != null
            ? (club!['members'] as List).length
            : (club?['member_count'] ?? 0);

    print("oaisdhjfolawejfgioa; $memberCount");
    print('currentUserId: $currentUserId');
    print('club members: ${club?['members']}');


    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (mounted) Navigator.pop(context, _changed);
          },
        ),
        elevation: 0,
        backgroundColor: const Color(0xFFF8F3FA),
        foregroundColor: Colors.black,
        actions: [
          // 동아리장만 설정(톱니바퀴) 버튼 노출
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsPage(
                      club: club!,
                      onClubUpdated: () async {
                        if (!mounted) return;
                        await fetchClub();
                        if (!mounted) return;
                        setState(() {});
                      },
                    ),
                  ),
                );
                if (result == true) {
                  if (!mounted) return;
                  await fetchClub();
                  if (!mounted) return;
                  setState(() {});
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // 상단 동아리 프로필 정보 (디자인 개선)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 동아리 프로필 이미지 표시 (base64)
                      (club?['image'] != null &&
                              club!['image'].toString().isNotEmpty)
                          ? CircleAvatar(
                            radius: 30,
                            backgroundImage: MemoryImage(
                              base64Decode(club!['image']),
                            ),
                          )
                          : CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey[300],
                            child: const Icon(
                              Icons.group,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  club!['name'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (club!['max_members'] != null)
                                  Text(
                                    '최대 인원수: ${club!['max_members']}명',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                            // 설명(소개글) 제거
                            // Text(
                            //   club!['description'] ?? '',
                            //   style: const TextStyle(color: Colors.grey),
                            // ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '게시물 ',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${posts.length}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '멤버 ',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  memberCount > 0 ? '$memberCount' : '-',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!isOwner)
                        ElevatedButton(
                          onPressed: () {
                            // TODO: 관리자 문의
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Colors.black12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text('관리자에게 문의하기'),
                        ),
                    ],
                  ),
                ),

                // 소개글
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            club!['description'] ?? '',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        // 연필 아이콘(소개 수정) 제거
                        // if (isOwner)
                        //   IconButton(
                        //     icon: const Icon(Icons.edit, size: 18),
                        //     tooltip: '소개 수정',
                        //     onPressed: _showEditDialog,
                        //   ),
                      ],
                    ),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.only(top: 8, left: 16, right: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '이 동아리 소개 더보기 >',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 게시글 그리드 (비회원도 항상 볼 수 있음)
                if (posts.isNotEmpty)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: GridView.builder(
                        itemCount: posts.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 1,
                            ),
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ClubPostDetailPage(post: post),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                color: Colors.grey[200],
                                child: post['image'] != null && post['image'] != ""
                                    ? Image.memory(
                                        base64Decode(post['image']),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      )
                                    : Center(
                                        child: Text(
                                          post['caption'] ?? 'No Image',
                                          style: const TextStyle(fontSize: 12),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 64), // 게시글 없을 때 하단 버튼 공간 확보
              ],
            ),
            // 하단 버튼 고정 영역
            if (!isMember)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: isApplied
                        ? ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pinkAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text(
                              '신청 완료, 승인 대기 중',
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ClubApplyPage(
                                    clubName: club!['name'] ?? '',
                                    clubId: club!['id'] ?? 0,
                                  ),
                                ),
                              );
                              await fetchClub();
                              await _fetchApplyStatus();
                              setState(() {});
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pinkAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text(
                              '가입 요청하기',
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ),
                  ),
                ),
              ),
            if (canWritePost)
              Positioned(
                left: 0,
                right: 0,
                bottom: !isMember ? 64 : 0, // 가입요청 버튼이 있으면 위로 띄움
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.create),
                      label: const Text('게시글 작성'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: _goToPostPage,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
