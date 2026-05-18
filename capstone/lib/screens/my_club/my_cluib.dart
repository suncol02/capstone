import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MyClubPage extends StatefulWidget {
  const MyClubPage({super.key});

  @override
  State<MyClubPage> createState() => _MyClubPageState();
}

class _MyClubPageState extends State<MyClubPage> {
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
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      setState(() {
        myClubs = [];
        _isLoading = false;
      });
      return;
    }
    try {
      final response = await http.get(
        Uri.parse('http://192.168.45.70:5000/clubs?user_id=$userId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          myClubs =
              data
                  .where((club) => club['is_joined'] == true)
                  .cast<Map<String, dynamic>>()
                  .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          myClubs = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        myClubs = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        )
        : Container(
          color: const Color(0xFFFDF6FC),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Image.asset('assets/logo.png', width: 28, height: 28),
                    const SizedBox(width: 8),
                    const Text(
                      '배재클럽',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Stack(
                      children: [
                        Icon(Icons.notifications_none, size: 32),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: const Text(
                              '6',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 90,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.blueAccent,
                              width: 2,
                            ),
                            color: Colors.white,
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('나', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child:
                          myClubs.isEmpty
                              ? const Center(child: Text('가입된 동아리가 없습니다.'))
                              : ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: myClubs.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(width: 12),
                                itemBuilder: (context, idx) {
                                  final club = myClubs[idx];
                                  return Column(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundImage:
                                            (club['image'] != null &&
                                                    club['image']
                                                        .toString()
                                                        .isNotEmpty)
                                                ? MemoryImage(
                                                  base64Decode(club['image']),
                                                )
                                                : null,
                                        backgroundColor: Colors.grey[300],
                                        child:
                                            (club['image'] == null ||
                                                    club['image']
                                                        .toString()
                                                        .isEmpty)
                                                ? const Icon(
                                                  Icons.group,
                                                  color: Colors.white,
                                                )
                                                : null,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        club['name'] ?? '',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
  }
}
