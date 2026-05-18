import '../chat/chatting_room_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  List<Map<String, dynamic>> chats = [];
  bool _isLoading = false;
  int? myUserId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });
    _loadUserIdAndFetchClubs();
  }

  Future<void> _loadUserIdAndFetchClubs() async {
    final prefs = await SharedPreferences.getInstance();
    myUserId = prefs.getInt('user_id');
    await fetchClubs();
  }

  Future<void> fetchClubs() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // user_id 파라미터를 붙여서 내가 가입한 동아리만 백엔드에서 받아옴
      final response = await http.get(Uri.parse('http://192.168.45.204:5000/clubs?user_id=$myUserId'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          chats = data
              .where((club) => club['is_joined'] == true)
              .map(
                (club) => {
                  'id': club['id'],
                  'name': club['name'],
                  'message': club['description'] ?? '',
                  'time': '',
                  'unread': false,
                  'avatarBase64': club['image'],
                },
              )
              .toList();
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('동아리 목록을 불러오지 못했습니다.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('네트워크 오류: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredChats =
        chats.where((chat) {
          final name = chat['name'].toString();
          return name.contains(_searchText);
        }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('채팅'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '검색',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                      itemCount: filteredChats.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final chat = filteredChats[index];
                        return ListTile(
                          leading:
                              chat['avatarBase64'] != null &&
                                      (chat['avatarBase64'] as String)
                                          .isNotEmpty
                                  ? CircleAvatar(
                                    backgroundImage: MemoryImage(
                                      base64Decode(chat['avatarBase64']),
                                    ),
                                  )
                                  : CircleAvatar(
                                    backgroundImage: NetworkImage(
                                      'https://i.pravatar.cc/150?img=${chat['id'] ?? 1}',
                                    ),
                                  ),
                          title: Row(
                            children: [
                              Text(
                                chat['name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(chat['message'] as String),
                          trailing: Text(
                            chat['time'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => ClubChatRoomPage(
                                      clubName: chat['name'],
                                      clubId: chat['id'],
                                    ),
                              ),
                            );
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
