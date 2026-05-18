import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '채팅방 테스트',
      home: ClubChatRoomPage(clubName: '테스트클럽', clubId: 1),
    );
  }
}

class ClubChatRoomPage extends StatefulWidget {
  final String clubName;
  final int clubId;
  const ClubChatRoomPage({
    super.key,
    required this.clubName,
    required this.clubId,
  });

  @override
  State<ClubChatRoomPage> createState() => _ClubChatRoomPageState();
}

class _ClubChatRoomPageState extends State<ClubChatRoomPage> {
  final TextEditingController _msgController = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  bool _isLoading = false;
  int? myUserId;
  String? myProfileImageBase64;
  bool isMember = false;

  @override
  void initState() {
    super.initState();
    _initUserAndMember();
  }

  Future<void> _initUserAndMember() async {
    final prefs = await SharedPreferences.getInstance();
    myUserId = prefs.getInt('user_id');
    myProfileImageBase64 = prefs.getString('profile_image');
    await _checkIsMemberByClubInfo();
    if (isMember) {
      fetchMessages();
    }
    setState(() {});
  }

  Future<void> _checkIsMemberByClubInfo() async {
    // 동아리 상세정보에서 멤버/역할 직접 확인
    if (myUserId == null) return;
    try {
      final response = await http.get(
        Uri.parse('http://192.168.45.204:5000/clubs/${widget.clubId}'),
      );
      if (response.statusCode == 200) {
        final club = jsonDecode(response.body);
        final presidentId = club['president_id'];
        final vicePresidentId = club['vice_president_id'];
        final members = club['members'] as List<dynamic>? ?? [];
        if (presidentId != null && int.tryParse(presidentId.toString()) == myUserId) {
          isMember = true;
        } else if (vicePresidentId != null && int.tryParse(vicePresidentId.toString()) == myUserId) {
          isMember = true;
        } else if (members.any((m) => m['user_id'] == myUserId)) {
          isMember = true;
        } else {
          isMember = false;
        }
      } else {
        isMember = false;
      }
    } catch (_) {
      isMember = false;
    }
  }

  Future<void> fetchMessages() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('http://192.168.45.204:5000/api/clubs/${widget.clubId}/messages'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          messages = data
              .map(
                (msg) => {
                  'user_id': msg['user_id'],
                  'user': msg['user'] ?? '',
                  'user_profile_image': msg['user_profile_image'],
                  'content': msg['content'] ?? '',
                  'created_at': msg['created_at'] ?? '',
                },
              )
              .toList();
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || myUserId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('user_name') ?? "나";

    final response = await http.post(
      Uri.parse('http://192.168.45.204:5000/api/clubs/${widget.clubId}/messages'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        'content': text,
        'user_id': myUserId,
        'user': userName,
      }),
    );
    if (response.statusCode == 201) {
      _msgController.clear();
      fetchMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: FutureBuilder<int>(
          future: _getMemberCount(),
          builder: (context, snapshot) {
            final memberCount = snapshot.data ?? 0;
            return AppBar(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              automaticallyImplyLeading: true,
              centerTitle: true,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      widget.clubName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$memberCount',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: isMember
          ? Column(
              children: [
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          reverse: true,
                          itemCount: messages.length,
                          itemBuilder: (context, idx) {
                            final msg = messages[messages.length - 1 - idx];
                            final bool isMine = msg['user_id'] == myUserId;
                            String timeStr = '';
                            final createdAtRaw = msg['created_at']?.toString() ?? '';
                            if (createdAtRaw.isNotEmpty) {
                              try {
                                DateTime dt;
                                if (createdAtRaw.contains('T')) {
                                  dt = DateTime.parse(createdAtRaw);
                                } else {
                                  dt = DateTime.parse(createdAtRaw.replaceFirst(' ', 'T'));
                                }
                                timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                              } catch (_) {
                                timeStr = '';
                              }
                            }
                            if (isMine) {
                              // 내 메시지(오른쪽)
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // 시간
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6, bottom: 2),
                                      child: Text(
                                        timeStr,
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ),
                                    // 말풍선+이름
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          if ((msg['user'] ?? '').isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(right: 4, bottom: 2),
                                              child: Text(
                                                msg['user'] ?? '',
                                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                                              ),
                                            ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                            margin: const EdgeInsets.only(left: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFE400),
                                              borderRadius: const BorderRadius.only(
                                                topLeft: Radius.circular(16),
                                                topRight: Radius.circular(16),
                                                bottomLeft: Radius.circular(16),
                                                bottomRight: Radius.circular(4),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.05),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              msg['content'] ?? '',
                                              style: const TextStyle(fontSize: 16, color: Colors.black87),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // 내 프로필
                                    const SizedBox(width: 8),
                                    (msg['user_profile_image'] != null && (msg['user_profile_image'] as String).isNotEmpty)
                                        ? CircleAvatar(
                                            radius: 18,
                                            backgroundImage: MemoryImage(base64Decode(msg['user_profile_image'])),
                                          )
                                        : const CircleAvatar(
                                            radius: 18,
                                            backgroundColor: Color(0xFFFFE400),
                                            child: Icon(Icons.person, color: Colors.black),
                                          ),
                                  ],
                                ),
                              );
                            } else {
                              // 상대 메시지(왼쪽)
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // 상대 프로필
                                    (msg['user_profile_image'] != null && (msg['user_profile_image'] as String).isNotEmpty)
                                        ? CircleAvatar(
                                            radius: 18,
                                            backgroundImage: MemoryImage(base64Decode(msg['user_profile_image'])),
                                          )
                                        : CircleAvatar(
                                            radius: 18,
                                            backgroundColor: Colors.grey[300],
                                            child: Text(
                                              (msg['user'] ?? '상대').isNotEmpty ? (msg['user'] ?? '상대')[0] : '?',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                    const SizedBox(width: 8),
                                    // 말풍선+이름
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if ((msg['user'] ?? '').isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 4, bottom: 2),
                                              child: Text(
                                                msg['user'] ?? '',
                                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                                              ),
                                            ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                            margin: const EdgeInsets.only(right: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: const BorderRadius.only(
                                                topLeft: Radius.circular(16),
                                                topRight: Radius.circular(16),
                                                bottomLeft: Radius.circular(4),
                                                bottomRight: Radius.circular(16),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.05),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              msg['content'] ?? '',
                                              style: const TextStyle(fontSize: 16, color: Colors.black87),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // 시간
                                    Padding(
                                      padding: const EdgeInsets.only(left: 6, bottom: 2),
                                      child: Text(
                                        timeStr,
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          decoration: const InputDecoration(
                            hintText: "메시지를 입력하세요",
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: sendMessage,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Center(
              child: Text(
                '동아리 멤버만 채팅방을 이용할 수 있습니다.',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
      backgroundColor: const Color(0xFFFFF7FB),
    );
  }

  Future<int> _getMemberCount() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.45.204:5000/clubs/${widget.clubId}'),
      );
      if (response.statusCode == 200) {
        final club = jsonDecode(response.body);
        return club['member_count'] ?? 0;
      }
    } catch (_) {}
    return 0;
  }
}
