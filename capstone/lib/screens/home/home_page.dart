// 파일 위치: capstone/screens/home/home_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../club/club_list_page.dart';
import '../notifications/notifications_page.dart';
import '../profile/profile_page.dart';
import '../chat/chat_list_page.dart'; // 상단에 import 추가
import '../club/club_post_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/scheduler.dart'; // 추가

class Post {
  final int id;
  final String email;
  final String name;
  final String imageBase64;
  final String caption;
  int likes;
  bool isLiked;
  final String profileImageBase64;
  final int? clubId;
  final String? clubName; // 동아리 이름 추가
  final String? clubImage; // 동아리 프로필 이미지 추가

  Post({
    required this.id,
    required this.email,
    required this.name,
    required this.imageBase64,
    required this.caption,
    required this.likes,
    this.isLiked = false,
    this.profileImageBase64 = '',
    this.clubId,
    this.clubName,
    this.clubImage,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      email: json['email'],
      name: json['name'] ?? '',
      imageBase64: json['image'] ?? '',
      caption: json['caption'] ?? '',
      likes: json['likes'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      profileImageBase64: json['profile_image'] ?? '',
      clubId: json['club_id'],
      clubName: json['club_name'], // 동아리 이름
      clubImage: json['club_image'], // 동아리 프로필 이미지(base64)
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late Future<List<Map<String, dynamic>>> futureReplies;
  int _selectedIndex = 0;
  late Future<List<Post>> futurePosts;

  // 댓글 및 좋아요 상태 관리
  Map<int, List<Map<String, dynamic>>> postReplies = {};
  Map<int, bool> postIsLiked = {};
  Map<int, int> postLikes = {};
  Map<int, bool> showReplies = {}; // 댓글창 열림 여부

  @override
  void initState() {
    super.initState();
    futurePosts = fetchPosts().then((posts) {
      // 게시글 목록을 받아온 후 각 게시글에 대해 초기화
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final post in posts) {
          fetchReplies(post.id);
          fetchLikeStatus(post.id);
          postLikes[post.id] = post.likes;
        }
      });
      return posts;
    });
    futureReplies = Future.value([]);
    WidgetsBinding.instance.addObserver(this); // 앱 상태 감지
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 해제
    super.dispose();
  }

  // 앱이 다시 포그라운드로 돌아오거나, 화면이 다시 활성화될 때 자동 새로고침
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {
        futurePosts = fetchPosts();
      });
    }
  }

  // 메인 피드로 돌아올 때마다 자동 새로고침
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Route가 다시 활성화될 때마다 최신 게시글을 불러옴
    Future.microtask(() {
      if (mounted) {
        setState(() {
          futurePosts = fetchPosts();
        });
      }
    });
  }

  Future<List<Post>> fetchPosts() async {
    final response = await http.get(
      Uri.parse('http://192.168.45.204:5000/posts'),
      headers: {"Cache-Control": "no-cache"},
    );
    if (response.statusCode == 200) {
      final List<dynamic> postJson = json.decode(response.body);
      // 디버깅: 실제 club_id 값들을 출력
      // print('--- club_id values from backend ---');
      // for (var json in postJson) {
      // print(json['club_id']);
      // }
      // club_id가 null이 아니고 0도 아닌 게시글만 필터링
      final filtered =
          postJson
              .where((json) => json['club_id'] != null && json['club_id'] != 0)
              .toList();
      print('Filtered posts count: ${filtered.length}');
      return filtered.map((json) => Post.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load posts (status: ${response.statusCode})');
    }
  }

  // 댓글 불러오기
  Future<void> fetchReplies(int postId) async {
    final response = await http.get(
      Uri.parse('http://192.168.45.204:5000/posts/$postId/replies'),
    );
    if (response.statusCode == 200) {
      setState(() {
        postReplies[postId] = List<Map<String, dynamic>>.from(
          jsonDecode(response.body),
        );
      });
    }
  }

  // 좋아요 상태 불러오기 (간단히 false로 시작)
  Future<void> fetchLikeStatus(int postId) async {
    // 실제 구현 시 서버에서 받아와야 함
    setState(() {
      postIsLiked[postId] = false;
    });
  }

  // 좋아요 토글
  Future<void> toggleLike(Post post) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    if (email == null) return;
    final endpoint =
        (postIsLiked[post.id] ?? false)
            ? 'http://192.168.45.204:5000/posts/${post.id}/unlike'
            : 'http://192.168.45.204:5000/posts/${post.id}/like';
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        postLikes[post.id] = data['likes'];
        postIsLiked[post.id] = !(postIsLiked[post.id] ?? false);
      });
    }
  }

  // 댓글 작성
  Future<void> submitReply(Post post, TextEditingController controller) async {
    final content = controller.text.trim();
    if (content.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('name') ?? '익명';
    final userEmail = prefs.getString('email') ?? '';
    final response = await http.post(
      Uri.parse('http://192.168.45.204:5000/posts/${post.id}/replies'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        'user': userName,
        'email': userEmail,
        'content': content,
      }),
    );
    if (response.statusCode == 201) {
      controller.clear();
      fetchReplies(post.id);
    }
  }

  // 댓글 수정
  Future<void> editReply(int replyId, String oldContent, int postId) async {
    final controller = TextEditingController(text: oldContent);
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('댓글 수정'),
            content: TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(hintText: '댓글을 입력하세요'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('저장'),
              ),
            ],
          ),
    );
    if (result != null && result.isNotEmpty && result != oldContent) {
      final response = await http.patch(
        Uri.parse('http://192.168.45.204:5000/replies/$replyId'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'content': result}),
      );
      if (response.statusCode == 200) {
        fetchReplies(postId);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('댓글 수정 실패')));
      }
    }
  }

  // 댓글 삭제
  Future<void> deleteReply(int replyId, int postId) async {
    final response = await http.delete(
      Uri.parse('http://192.168.45.204:5000/replies/$replyId'),
    );
    if (response.statusCode == 200) {
      fetchReplies(postId);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('댓글 삭제 실패')));
    }
  }

  // 댓글 모달(바텀시트) UI
  void _showRepliesModal(BuildContext context, Post post) async {
    final replyController = TextEditingController();
    await fetchReplies(post.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final replies = postReplies[post.id] ?? [];
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: SizedBox(
            height: 420,
            child: Column(
              children: [
                Container(
                  height: 4,
                  width: 40,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child:
                      replies.isEmpty
                          ? const Center(child: Text("댓글이 없습니다"))
                          : ListView(
                            children:
                                replies.map((reply) {
                                  return ListTile(
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.grey[300],
                                      child: Text(
                                        reply['user'] != null &&
                                                reply['user'].isNotEmpty
                                            ? reply['user'][0]
                                            : '익',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      reply['user'] ?? '익명',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    subtitle: Text(
                                      reply['content'] ?? '',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    trailing: FutureBuilder<SharedPreferences>(
                                      future: SharedPreferences.getInstance(),
                                      builder: (context, snapshot) {
                                        final myEmail = snapshot.data
                                            ?.getString('email');
                                        if (myEmail != null &&
                                            reply['email'] == myEmail) {
                                          return PopupMenuButton<String>(
                                            icon: const Icon(
                                              Icons.more_vert,
                                              size: 18,
                                              color: Colors.grey,
                                            ),
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                editReply(
                                                  reply['id'],
                                                  reply['content'] ?? '',
                                                  post.id,
                                                );
                                              } else if (value == 'delete') {
                                                deleteReply(
                                                  reply['id'],
                                                  post.id,
                                                );
                                              }
                                            },
                                            itemBuilder:
                                                (context) => [
                                                  const PopupMenuItem(
                                                    value: 'edit',
                                                    child: Text('수정'),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'delete',
                                                    child: Text('삭제'),
                                                  ),
                                                ],
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  );
                                }).toList(),
                          ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: replyController,
                          decoration: const InputDecoration(
                            hintText: "댓글을 입력하세요",
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () async {
                          await submitReply(post, replyController);
                          await fetchReplies(post.id);
                          // 댓글 등록 후 입력창 유지
                          (context as Element).markNeedsBuild();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 메인피드 게시글 UI
  Widget _buildPostItem(Post post) {
    // print('clubImage: ${post.clubImage}'); // ← base64 문자열이 잘 들어오는지 확인

    // 동아리 정보
    final bool isClubPost = post.clubId != null && post.clubId != 0;
    final String clubName =
        (post.clubName != null && post.clubName!.isNotEmpty)
            ? post.clubName!
            : '알 수 없음';
    final String? clubProfileImage =
        (post.clubImage != null && post.clubImage!.isNotEmpty)
            ? post.clubImage!
            : null;

    Widget profileWidget;
    String displayName;

    if (isClubPost) {
      // 동아리 게시글
      profileWidget =
          (clubProfileImage != null && clubProfileImage.isNotEmpty)
              ? Builder(
                builder: (context) {
                  try {
                    return CircleAvatar(
                      backgroundColor: Colors.grey[300],
                      radius: 22,
                      backgroundImage: MemoryImage(
                        base64Decode(clubProfileImage),
                      ),
                    );
                  } catch (e) {
                    // print('base64 decode error: $e');
                    return CircleAvatar(
                      backgroundColor: Colors.purple[100],
                      radius: 22,
                      child: Text(
                        clubName.isNotEmpty ? clubName[0] : '?',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                        ),
                      ),
                    );
                  }
                },
              )
              : CircleAvatar(
                backgroundColor: Colors.purple[100],
                radius: 22,
                child: Text(
                  clubName.isNotEmpty ? clubName[0] : '?',
                  style: const TextStyle(color: Colors.black, fontSize: 18),
                ),
              );
      displayName = clubName;
    } else {
      // 일반 사용자 게시글
      profileWidget =
          post.profileImageBase64.isNotEmpty
              ? CircleAvatar(
                backgroundColor: Colors.grey[300],
                radius: 22,
                backgroundImage: MemoryImage(
                  base64Decode(post.profileImageBase64),
                ),
              )
              : CircleAvatar(
                backgroundColor: Colors.grey[300],
                radius: 22,
                child: const Icon(Icons.person, color: Colors.white),
              );
      displayName = post.name;
    }

    final isLiked = postIsLiked[post.id] ?? false;
    final likes = postLikes[post.id] ?? post.likes;
    final replies = postReplies[post.id] ?? [];

    return GestureDetector(
      onTap: () {
        // club 정보를 Map 형태로 만듦
        final club = {
          'id': post.clubId,
          'name': post.clubName,
          'image': post.clubImage, // base64 문자열이어야 함
        };
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ClubPostDetailPage(
                  post: {
                    'id': post.id,
                    'email': post.email,
                    'name': post.name,
                    'image': post.imageBase64,
                    'caption': post.caption,
                    'likes': post.likes,
                    'profile_image': post.profileImageBase64,
                    'club_id': post.clubId,
                    'club_name': post.clubName,
                    'club_image': post.clubImage,
                  },
                  club: club, // club 정보를 반드시 전달!
                ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 프로필/이름
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  children: [
                    profileWidget,
                    const SizedBox(width: 12),
                    // 동아리 게시글이면 동아리 이름을 진하게, 아니면 사용자 이름
                    Text(
                      displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color:
                            (post.clubId != null && post.clubId != 0)
                                ? Colors.black
                                : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 1,
                child:
                    post.imageBase64.isNotEmpty
                        ? Image.memory(
                          base64Decode(post.imageBase64),
                          fit: BoxFit.cover,
                        )
                        : Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.image_not_supported),
                          ),
                        ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(post.caption),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.pink : Colors.grey,
                      ),
                      onPressed: () => toggleLike(post),
                    ),
                    Text('$likes'),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.grey,
                      ),
                      onPressed: () => _showRepliesModal(context, post),
                    ),
                    const SizedBox(width: 4),
                    Text('${replies.length}'),
                  ],
                ),
              ),
            ],
          ),
        ),
      )
    );
  }

  Widget _buildHome() {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70), // 앱바 높이 조절
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leadingWidth: 170, // leading 영역 넓이 확보
          leading: Padding(
            padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6, right: 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'image/pct.png',
                  width: 55,
                  height: 55,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 8),
                Text(
                  '배재톡',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3B82F6),
                    shadows: [
                      Shadow(
                        color: Colors.white,
                        blurRadius: 4,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.forum_outlined, color: Colors.black),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatListPage()),
                );
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            futurePosts = fetchPosts();
          });
        },
        child: FutureBuilder<List<Post>>(
          future: futurePosts,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('오류 발생: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("게시글이 없습니다"));
            }
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder:
                  (context, index) => _buildPostItem(snapshot.data![index]),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> pagesWithProfile() {
      return [
        _buildHome(),
        const ClubListPage(),
        const NotificationsPage(),
        FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final prefs = snapshot.data!;
            final name = prefs.getString('name') ?? '';
            final email = prefs.getString('email') ?? '';
            final profileImage = prefs.getString('profile_image') ?? '';
            return ProfilePage(
              name: name,
              email: email,
              profileImageBase64: profileImage,
            );
          },
        ),
      ];
    }

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pagesWithProfile()),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.pink,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            if (index == 0) {
              // Home 탭을 다시 누르면 새로고침
              futurePosts = fetchPosts();
            }
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "List"),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: "Notifications",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: "Menu"),
        ],
      ),
    );
  }
}
