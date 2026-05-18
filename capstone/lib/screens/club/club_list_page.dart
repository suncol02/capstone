import 'package:flutter/material.dart';
import '../club/club_detail_page.dart';
import '../club/club_create_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Club {
  final int id;
  final String name;
  final String description;
  final String? imageBase64;

  Club({
    required this.id,
    required this.name,
    required this.description,
    this.imageBase64,
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      imageBase64: json['image'], // 서버에서 base64로 내려줌
    );
  }
}

class ClubListPage extends StatefulWidget {
  const ClubListPage({super.key});

  @override
  State<ClubListPage> createState() => _ClubListPageState();
}

class _ClubListPageState extends State<ClubListPage> {
  List<Club> allClubs = [];
  String _searchText = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchClubs();
  }

  Future<void> fetchClubs() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // 포트를 5000에서 3000으로 변경
      final response = await http.get(Uri.parse('http://192.168.45.204:5000/clubs'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          allClubs = data.map((e) => Club.fromJson(e)).toList();
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

  void _goToCreateClub() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClubCreatePage()),
    );
    fetchClubs(); // 동아리 생성 후 목록 새로고침
  }

  Future<void> _goToDetailPage(Club club) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClubDetailPage(clubId: club.id)),
    );
    if (result == true) {
      fetchClubs(); // 수정/삭제가 일어났으면 목록 새로고침
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Club> filteredClubs =
        allClubs.where((club) {
          return club.name.contains(_searchText) ||
              club.description.contains(_searchText);
        }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                // 상단: 로고 + 검색창
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8,
                  ),
                  child: Row(
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
                      const SizedBox(width: 12),
                      // Spacer 대신 Expanded로 검색창이 남은 공간을 모두 차지하게 함
                      Expanded(
                        child: TextField(
                          onChanged: (value) {
                            setState(() {
                              _searchText = value;
                            });
                          },
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            hintText: '동아리명, 키워드 등 검색',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            isDense: true,
                            suffixIcon: const Icon(Icons.search),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 제목
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '우리 학교 동아리 list',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.pink),
                        tooltip: '동아리 생성하기',
                        onPressed: _goToCreateClub,
                      ),
                    ],
                  ),
                ),

                // 동아리 리스트
                Expanded(
                  child:
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : filteredClubs.isEmpty
                          ? const Center(child: Text('동아리가 없습니다.'))
                          : ListView.builder(
                            itemCount: filteredClubs.length,
                            itemBuilder: (context, index) {
                              final club = filteredClubs[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading:
                                        club.imageBase64 != null &&
                                                club.imageBase64!.isNotEmpty
                                            ? CircleAvatar(
                                              backgroundImage: MemoryImage(
                                                base64Decode(club.imageBase64!),
                                              ),
                                              radius: 24,
                                            )
                                            : CircleAvatar(
                                              backgroundImage: NetworkImage(
                                                'https://i.pravatar.cc/150?img=${club.id}',
                                              ),
                                              radius: 24,
                                            ),
                                    title: Text(club.name),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          club.description,
                                          style: const TextStyle(
                                            color: Colors.pink,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _goToDetailPage(club),
                                  ),
                                ),
                              );
                            },
                          ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
