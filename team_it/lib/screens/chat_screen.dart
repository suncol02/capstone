import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String API_BASE_URL = 'http://team-it.iptime.org:8000/api';

class ChatEntryScreen extends StatefulWidget {
  const ChatEntryScreen({super.key});

  @override
  State<ChatEntryScreen> createState() => _ChatEntryScreenState();
}

class _ChatEntryScreenState extends State<ChatEntryScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _chatRooms = [];

  @override
  void initState() {
    super.initState();
    _loadChatRooms();
  }

  Future<void> _loadChatRooms() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          _error = '로그인이 필요합니다.';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('$API_BASE_URL/chat-rooms/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _chatRooms = decoded is List ? decoded : <dynamic>[];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = '채팅방을 불러오지 못했습니다. (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  int? _roomId(dynamic room) {
    if (room is! Map) return null;
    final id = room['id'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id);
    return null;
  }

  String _roomName(dynamic room) {
    if (room is! Map) return '채팅방';
    return '${room['name'] ?? room['title'] ?? '이름 없는 채팅방'}';
  }

  String _roomSubtitle(dynamic room) {
    if (room is! Map) return '메시지가 없습니다.';

    final lastMsg = room['last_message'];
    if (lastMsg is Map && lastMsg['content'] != null) {
      return '${lastMsg['sender']}: ${lastMsg['content']}';
    }

    final count = room['member_count'];
    if (count != null) return '$count명 참여 중';
    return '${room['description'] ?? ''}';
  }

  void _openRoom(dynamic room) {
    final roomId = _roomId(room);
    final roomName = _roomName(room);

    if (roomId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('채팅방 정보를 찾을 수 없습니다.')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChatScreen(chatRoomId: roomId, roomName: roomName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('채팅', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadChatRooms,
        child: Builder(
          builder: (context) {
            if (_isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_error != null) {
              return ListView(
                children: [
                  const SizedBox(height: 180),
                  Center(child: Text(_error!)),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: _loadChatRooms,
                      child: const Text('다시 불러오기'),
                    ),
                  ),
                ],
              );
            }
            if (_chatRooms.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 220),
                  const Center(
                    child: Text(
                      '참여 중인 채팅방이 없습니다.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _chatRooms.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final room = _chatRooms[index];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    onTap: () => _openRoom(room),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8ECFF),
                      child: Icon(
                        Icons.chat_bubble_outline,
                        color: Color(0xFF7A82F0),
                      ),
                    ),
                    title: Text(
                      _roomName(room),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      _roomSubtitle(room),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final int chatRoomId;
  final String roomName;

  const ChatScreen({
    super.key,
    required this.chatRoomId,
    required this.roomName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController controller = TextEditingController();
  final List<dynamic> messages = [];
  bool _isLoadingMessages = true;

  @override
  void initState() {
    super.initState();
    _fetchPreviousMessages();
  }

  // 백엔드 API에서 이전 대화 이력 가져오기
  Future<void> _fetchPreviousMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) throw Exception('인증 토큰이 없습니다.');

      final response = await http
          .get(
            Uri.parse(
              '$API_BASE_URL/chat-rooms/${widget.chatRoomId}/messages/',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Token $token',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> loadedMessages = decoded is List
            ? decoded
            : decoded is Map
            ? decoded['results'] ?? decoded['data'] ?? []
            : [];
        if (mounted) {
          setState(() {
            messages.clear();
            messages.addAll(loadedMessages);
            _isLoadingMessages = false;
          });
        }
      } else {
        print('[DEBUG] 메시지 로드 상태코드: ${response.statusCode}');
        if (mounted) setState(() => _isLoadingMessages = false);
      }
    } catch (e) {
      print('[DEBUG] 기존 메시지 로드 실패: $e');
      if (mounted) setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> sendMessage() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('인증 정보가 없습니다.')));
        return;
      }

      // HTTP POST로 메시지 전송
      final response = await http
          .post(
            Uri.parse(
              '$API_BASE_URL/chat-rooms/${widget.chatRoomId}/send_message/',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Token $token',
            },
            body: jsonEncode({'content': text}),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 201) {
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          setState(() {
            messages.add(decoded);
          });
          controller.clear();
          print('[DEBUG] HTTP로 메시지 전송 완료');
        } catch (e) {
          print('[DEBUG] 응답 파싱 실패: $e');
          controller.clear();
        }
      } else {
        print('[DEBUG] 메시지 전송 실패: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('메시지 전송 실패: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('[DEBUG] 메시지 전송 예외: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('메시지 전송 실패: $e')));
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Map<String, dynamic> _messageAsMap(dynamic message) {
    if (message is Map<String, dynamic>) return message;
    if (message is Map) return Map<String, dynamic>.from(message);
    if (message is String) return {'content': message};
    return {'content': message?.toString() ?? ''};
  }

  String _messageContent(Map<String, dynamic> message) {
    final content = message['content'] ?? message['message'] ?? message['text'];
    return content?.toString() ?? '';
  }

  String _senderName(Map<String, dynamic> message) {
    final sender = message['sender'] ?? message['user'];
    if (sender is Map) {
      return (sender['username'] ??
              sender['name'] ??
              sender['email'] ??
              '알 수 없음')
          .toString();
    }
    if (sender != null) return sender.toString();
    return '알 수 없음';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.roomName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingMessages
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                ? const Center(child: Text('대화 기록이 없습니다.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (_, index) {
                      final msg = _messageAsMap(messages[index]);
                      final content = _messageContent(msg);
                      final senderName = _senderName(msg);

                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 2,
                              ),
                              child: Text(
                                senderName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8ECFF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                content,
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: '메시지 입력',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: sendMessage,
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
