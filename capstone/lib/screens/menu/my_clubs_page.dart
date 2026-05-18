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
      final response = await http.get(
        Uri.parse('http://192.168.45.70:5000/myclubs?user_id=${widget.userId}'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          myClubs = data.cast<Map<String, dynamic>>();
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
      Uri.parse('http://192.168.45.70:5000/join_club'),
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
              : ListView.builder(
                itemCount: myClubs.length,
                itemBuilder: (context, index) {
                  final club = myClubs[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(club['image_url'] ?? ''),
                      backgroundColor: Colors.purple[100],
                    ),
                    title: Text(club['name'] ?? ''),
                    subtitle: Text(club['description'] ?? ''),
                  );
                },
              ),
    );
  }
}
