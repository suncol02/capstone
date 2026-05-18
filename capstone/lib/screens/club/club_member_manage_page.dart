import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ClubMemberManagePage extends StatefulWidget {
  final int clubId;
  const ClubMemberManagePage({super.key, required this.clubId});

  @override
  State<ClubMemberManagePage> createState() => _ClubMemberManagePageState();
}

class _ClubMemberManagePageState extends State<ClubMemberManagePage> {
  List<Map<String, dynamic>> members = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchMembers();
  }

  Future<void> fetchMembers() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('http://192.168.45.204:5000/clubs/${widget.clubId}'),
      );
      if (response.statusCode == 200) {
        final club = jsonDecode(response.body);
        // 본인 정보 가져오기 (SharedPreferences에서)
        final prefs = await SharedPreferences.getInstance();
        final myUserId = prefs.getInt('user_id') ?? 1; // 실제 로그인 유저 id
        final myName = prefs.getString('name') ?? '';
        final myProfileImage = prefs.getString('profile_image') ?? '';
        final myRole =
            club['president_id'] == myUserId
                ? '회장'
                : (club['vice_president_id'] == myUserId ? '부회장' : '동아리원');

        List<Map<String, dynamic>> loadedMembers = [];
        if (club['members'] != null && club['members'] is List) {
          loadedMembers = List<Map<String, dynamic>>.from(club['members']);
        }
        // 본인이 members에 없으면 추가
        final alreadyInList = loadedMembers.any(
          (m) => m['user_id'] == myUserId,
        );
        if (!alreadyInList) {
          loadedMembers.insert(0, {
            'user_id': myUserId,
            'name': myName,
            'role': myRole,
            'profile_image': myProfileImage,
          });
        }
        // 각 멤버의 프로필 이미지를 서버에서 받아오기 (email 또는 user_id 기준)
        for (var member in loadedMembers) {
          if (member['profile_image'] == null ||
              member['profile_image'].toString().isEmpty) {
            // 서버에서 프로필 이미지 요청 (email 또는 user_id 필요)
            final userId = member['user_id'];
            if (userId != null) {
              try {
                final userRes = await http.get(
                  Uri.parse('http://192.168.45.204:5000/api/user/$userId'),
                );
                if (userRes.statusCode == 200) {
                  final userJson = jsonDecode(userRes.body);
                  member['profile_image'] = userJson['profile_image'] ?? '';
                }
              } catch (_) {}
            }
          }
        }
        setState(() {
          members = loadedMembers;
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _changeRole(int memberId, String newRole) async {
    // 실제 서버에 PATCH/PUT 요청 필요
    final response = await http.patch(
      Uri.parse(
        'http://192.168.45.204:5000/clubs/${widget.clubId}/members/$memberId/role',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'role': newRole}),
    );
    if (response.statusCode == 200) {
      fetchMembers();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('역할이 변경되었습니다.')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('역할 변경 실패')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('멤버 관리')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: members.length,
              itemBuilder: (context, idx) {
                final member = members[idx];
                final String currentRole = member['role'] ?? '동아리원';
                final int memberId = member['user_id'] ?? member['id'] ?? 0;
                final String memberName = member['name'] ?? '';
                final String profileImage = member['profile_image'] ?? '';
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        profileImage.isNotEmpty
                            ? CircleAvatar(
                                radius: 20,
                                backgroundImage: MemoryImage(
                                  base64Decode(profileImage),
                                ),
                              )
                            : const CircleAvatar(
                                radius: 20,
                                child: Icon(Icons.person),
                              ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            memberName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // 부회장만 부여할 수 있도록 드롭다운 제한
                        DropdownButton<String>(
                          value: currentRole,
                          items: const [
                            DropdownMenuItem(
                              value: '동아리원',
                              child: Text('동아리원'),
                            ),
                            DropdownMenuItem(
                              value: '부회장',
                              child: Text('부회장'),
                            ),
                            DropdownMenuItem(
                              value: '회장',
                              child: Text('회장'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null && value != currentRole) {
                              // 회장은 한 명만 가능, 부회장은 여러 명 가능(정책에 따라)
                              if (value == '회장') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('회장은 멤버 관리에서 직접 변경할 수 없습니다.'),
                                  ),
                                );
                                return;
                              }
                              _changeRole(memberId, value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
