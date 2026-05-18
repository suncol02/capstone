import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MyClubsPage extends StatefulWidget {
  final int userId; // 로그인한 유저 id

  const MyClubsPage({super.key, required this.userId});

  @override
  State<MyClubsPage> createState() => _MyClubsPageState();
}

class _MyClubsPageState extends State<MyClubsPage> {
  List<Map<String, dynamic>> myClubs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchMyClubs();
  }

  Future<void> fetchMyClubs() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // clubs API에서 user_id 파라미터로 내가 가입한 동아리만 필터링
      final response = await http.get(
        Uri.parse('http://192.168.45.204:5000/clubs?user_id=${widget.userId}'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        // 동아리의 members에 내 userId가 포함된 경우만 추출
        setState(() {
          myClubs = data
              .where((club) {
                // 동아리의 members에 내 userId가 포함된 경우만 추출
                final members = club['members'] as List<dynamic>? ?? [];
                return members.any((m) => m['user_id'] == widget.userId);
              })
              .cast<Map<String, dynamic>>()
              .toList();
        });
      } else {
        setState(() {
          myClubs = [];
        });
      }
    } catch (e) {
      setState(() {
        myClubs = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 동아리 가입(버튼 클릭 시 호출)
  Future<void> joinClub(int clubId) async {
    final response = await http.post(
      Uri.parse('http://192.168.45.204:5000/join_club'),
      body: {'user_id': widget.userId.toString(), 'club_id': clubId.toString()},
    );
    if (response.statusCode == 200) {
      // 가입 성공 시 목록 새로고침
      fetchMyClubs();
    }
  }

  // 동아리 생성 후 목록 새로고침 (동아리 생성 페이지에서 Navigator.pop 후 호출)
  void refreshClubs() {
    fetchMyClubs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내가 가입한 동아리'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : myClubs.isEmpty
              ? const Center(child: Text('가입한 동아리가 없습니다.'))
              : Padding(
                padding: const EdgeInsets.all(12.0),
                child: GridView.builder(
                  itemCount: myClubs.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 2개씩 한 줄에
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.9,
                  ),
                  itemBuilder: (context, index) {
                    final club = myClubs[index];
                    Widget avatar;
                    if (club['image'] != null &&
                        club['image'].toString().isNotEmpty) {
                      avatar = CircleAvatar(
                        radius: 36,
                        backgroundImage: MemoryImage(
                          base64Decode(club['image']),
                        ),
                        backgroundColor: Colors.purple[100],
                      );
                    } else {
                      avatar = CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.purple[100],
                        child: const Icon(
                          Icons.group,
                          color: Colors.white,
                          size: 36,
                        ),
                      );
                    }
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 3,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          // TODO: 동아리 상세 페이지로 이동 등
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 18,
                            horizontal: 8,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              avatar,
                              const SizedBox(height: 12),
                              Text(
                                club['name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                club['description'] ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
