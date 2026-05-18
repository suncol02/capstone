import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ClubPostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;
  final Map<String, dynamic>? club; // club 정보도 받을 수 있게 추가

  const ClubPostDetailPage({super.key, required this.post, this.club});

  @override
  State<ClubPostDetailPage> createState() => _ClubPostDetailPageState();
}

class _ClubPostDetailPageState extends State<ClubPostDetailPage> {
  late int likes;
  late bool isLiked;
  List<Map<String, dynamic>> replies = [];
  final TextEditingController _replyController = TextEditingController();
  String? myEmail;
  Map<String, dynamic>? club;
  String? myRole; // 관리자 여부 확인용
  int? myUserId;

  @override
  void initState() {
    super.initState();
    likes = widget.post['likes'] ?? 0;
    isLiked = false;
    fetchReplies();
    checkLiked();
    _loadMyEmail();
    _loadMyUserInfo();

    // club 정보를 생성자에서 받았으면 바로 할당, 없으면 fetch
    club = widget.club;
    if (club == null) {
      fetchClubInfo();
    }
  }

  Future<void> _loadMyEmail() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      myEmail = prefs.getString('email');
    });
  }

  Future<void> _loadMyUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      myUserId = prefs.getInt('user_id');
      myRole = prefs.getString('role');
    });
  }

  Future<void> fetchClubInfo() async {
    final clubId = widget.post['club_id'];
    if (clubId == null) return;
    try {
      final response = await http.get(
        Uri.parse('http://192.168.45.204:5000/clubs/$clubId'),
      );
      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          club = jsonDecode(response.body);
        });
      }
    } catch (e) {
      // 에러 처리
    }
  }

  Future<void> checkLiked() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    if (email == null) return;
    final postId = widget.post['id'];
    final response = await http.get(
      Uri.parse('http://192.168.45.204:5000/posts/$postId/is_liked?email=$email'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() {
        isLiked = data['isLiked'] ?? false;
      });
    }
  }

  Future<void> fetchReplies() async {
    final postId = widget.post['id'];
    final response = await http.get(
      Uri.parse('http://192.168.45.204:5000/posts/$postId/replies'),
    );
    if (response.statusCode == 200) {
      if (!mounted) return; // State가 이미 dispose된 경우 setState 호출 금지
      setState(() {
        replies = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      });
    }
  }

  Future<void> _toggleLike() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    if (email == null) return;
    final endpoint =
        isLiked
            ? 'http://192.168.45.204:5000/posts/${widget.post['id']}/unlike'
            : 'http://192.168.45.204:5000/posts/${widget.post['id']}/like';
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        likes = data['likes'];
        isLiked = data['isLiked']; // 서버에서 받은 값을 직접 반영
      });
    }
  }

  Future<void> _submitReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('name') ?? '익명';
    final userEmail = prefs.getString('email') ?? '';
    final postId = widget.post['id'];
    final response = await http.post(
      Uri.parse('http://192.168.45.204:5000/posts/$postId/replies'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        'user': userName,
        'email': userEmail,
        'content': content,
      }),
    );
    if (response.statusCode == 201) {
      _replyController.clear();
      fetchReplies();
    }
  }

  Future<void> _deleteReply(int replyId) async {
    final response = await http.delete(
      Uri.parse('http://192.168.45.204:5000/replies/$replyId'),
    );
    if (response.statusCode == 200) {
      fetchReplies();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('댓글 삭제 실패')));
    }
  }

  Future<void> _editReply(int replyId, String oldContent) async {
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
        if (!mounted) return;
        fetchReplies();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('댓글 수정 실패')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 동아리 이름과 프로필 이미지(base64)
    final clubName =
        club != null && club!['name'] != null
            ? club!['name'].toString()
            : (widget.post['club_name'] ?? '');
    final clubProfileImage =
        club != null &&
                club!['image'] != null &&
                club!['image'].toString().isNotEmpty
            ? club!['image'].toString()
            : (widget.post['club_image'] ?? '');

    // print('club: $club');
    // print('clubProfileImage: $clubProfileImage');
    // 게시글 이미지, 캡션, 작성자 이메일
    final image = widget.post['image'];
    final caption = (widget.post['caption'] ?? '').toString().trim();
    final email = widget.post['email'] ?? '';

    // 게시글 작성자의 user_id(학번)와 직책 판별
    int? authorUserId;
    if (widget.post.containsKey('user_id')) {
      authorUserId =
          widget.post['user_id'] is int
              ? widget.post['user_id']
              : int.tryParse(widget.post['user_id'].toString());
    }
    String position = '';
    if (club != null && authorUserId != null) {
      final presidentId = club?['president_id'];
      final vicePresidentId = club?['vice_president_id'];
      if (presidentId != null && presidentId == authorUserId) {
        position = '동아리장';
      } else if (vicePresidentId != null && vicePresidentId == authorUserId) {
        position = '부회장';
      } else {
        position = '';
      }
    }

    // 동아리장/부회장/작성자인지 판별 (예시: 실제 권한 체크는 club 정보와 로그인 정보 활용)
    final bool isOwnerOrVice =
        (club?['president_id'] == myUserId) ||
        (club?['vice_president_id'] == myUserId);
    final bool isAuthor = (myEmail != null && myEmail == email);
    final bool isAdmin = (myRole == 'admin');
    final bool canDeletePost = isOwnerOrVice || isAuthor || isAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F3FA),
      appBar: AppBar(
        title: const Text('게시글'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                // 동아리 프로필 이미지
                (clubProfileImage.isNotEmpty)
                    ? CircleAvatar(
                      backgroundColor: Colors.grey[300],
                      radius: 22,
                      backgroundImage: MemoryImage(
                        base64Decode(clubProfileImage),
                      ),
                    )
                    : CircleAvatar(
                      backgroundColor: Colors.purple[100],
                      radius: 22,
                      child: Text(
                        clubName.isNotEmpty ? clubName[0] : '?',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                        ),
                      ),
                    ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clubName.isNotEmpty ? clubName : '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (position.isNotEmpty)
                      Text(
                        position,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                if (canDeletePost)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('게시글 삭제'),
                                content: const Text('정말로 이 게시글을 삭제하시겠습니까?'),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, false),
                                    child: const Text('취소'),
                                  ),
                                  ElevatedButton(
                                    onPressed:
                                        () => Navigator.pop(context, true),
                                    child: const Text('삭제'),
                                  ),
                                ],
                              ),
                        );
                        if (confirm == true) {
                          final prefs = await SharedPreferences.getInstance();
                          final email = prefs.getString('email');
                          final userId = prefs.getInt('user_id');
                          final role = prefs.getString('role');
                          final response = await http.delete(
                            Uri.parse(
                              'http://192.168.45.204:5000/posts/${widget.post['id']}',
                            ),
                            headers: {"Content-Type": "application/json"},
                            body: jsonEncode({
                              'email': email,
                              'user_id': userId,
                              'role': role,
                            }),
                          );
                          if (response.statusCode == 200) {
                            if (mounted) {
                              Navigator.pop(context, true); // 삭제 후 뒤로가기
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('게시글 삭제 실패')),
                            );
                          }
                        }
                      }
                    },
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('게시글 삭제'),
                          ),
                        ],
                  ),
              ],
            ),
          ),
          if (image != null && image != "")
            ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: Image.memory(
                base64Decode(image),
                fit: BoxFit.cover,
                width: double.infinity,
                height: 350,
              ),
            ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              caption.isNotEmpty ? caption : '내용이 없습니다.',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.pink : Colors.grey,
                  ),
                  onPressed: _toggleLike,
                ),
                Text('$likes'),
                const SizedBox(width: 16),
                Icon(Icons.chat_bubble_outline, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${replies.length}'),
              ],
            ),
          ),
          const Divider(height: 32),
          // 댓글 목록
          ...replies.map(
            (reply) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.grey[300],
                    child: Text(
                      reply['user'] != null && reply['user'].isNotEmpty
                          ? reply['user'][0]
                          : '익',
                      style: const TextStyle(fontSize: 13, color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reply['user'] ?? '익명',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    reply['content'] ?? '',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            if (myEmail != null && reply['email'] == myEmail)
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editReply(
                                      reply['id'],
                                      reply['content'] ?? '',
                                    );
                                  } else if (value == 'delete') {
                                    _deleteReply(reply['id']);
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
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 댓글 입력창
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
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
                  onPressed: _submitReply,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
