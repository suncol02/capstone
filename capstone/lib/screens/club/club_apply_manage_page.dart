import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ClubApplyManagePage extends StatefulWidget {
  final int clubId;
  const ClubApplyManagePage({super.key, required this.clubId});

  @override
  State<ClubApplyManagePage> createState() => _ClubApplyManagePageState();
}

class _ClubApplyManagePageState extends State<ClubApplyManagePage> {
  List<dynamic> applicants = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    fetchApplicants();
  }

  Future<void> fetchApplicants() async {
    setState(() => _loading = true);
    final response = await http.get(
      Uri.parse('http://192.168.45.204:5000/clubs/${widget.clubId}/apply'),
    );
    if (response.statusCode == 200) {
      setState(() {
        applicants = jsonDecode(response.body);
      });
    }
    setState(() => _loading = false);
  }

  Future<void> acceptApplicant(int applyId) async {
    final response = await http.post(
      Uri.parse('http://192.168.45.204:5000/clubs/${widget.clubId}/apply/$applyId/accept'),
    );
    if (response.statusCode == 200) {
      // 수락 성공 시 바로 동아리원으로 처리됨 (백엔드에서 ClubMember로 등록)
      fetchApplicants();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가입 신청을 수락했습니다. 동아리원으로 등록되었습니다.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('수락 실패: ${response.body}')),
      );
    }
  }

  Future<void> rejectApplicant(int applyId) async {
    final response = await http.post(
      Uri.parse('http://192.168.45.204:5000/clubs/${widget.clubId}/apply/$applyId/reject'),
    );
    if (response.statusCode == 200) {
      fetchApplicants();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가입 신청을 거절했습니다.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('거절 실패: ${response.body}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('가입 신청자 관리')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : applicants.isEmpty
              ? const Center(child: Text('가입 신청자가 없습니다.'))
              : ListView.builder(
                  itemCount: applicants.length,
                  itemBuilder: (context, idx) {
                    final a = applicants[idx];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(a['user_name'] ?? '이름없음'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('이메일: ${a['user_email'] ?? ''}'),
                            Text('성별: ${a['gender'] ?? ''}'),
                            Text('학과/학번: ${a['major'] ?? ''}'),
                            Text('전화번호: ${a['phone'] ?? ''}'),
                            Text('자기소개: ${a['intro'] ?? ''}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: () => acceptApplicant(a['id']),
                              child: const Text('수락'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => rejectApplicant(a['id']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('거절'),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }
}
