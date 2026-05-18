import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ClubApplyDetailPage extends StatefulWidget {
  final int clubId;
  final Map<String, dynamic> applicant;
  const ClubApplyDetailPage({super.key, required this.clubId, required this.applicant});

  @override
  State<ClubApplyDetailPage> createState() => _ClubApplyDetailPageState();
}

class _ClubApplyDetailPageState extends State<ClubApplyDetailPage> {
  bool _isLoading = false;

  Future<void> _accept() async {
    setState(() => _isLoading = true);
    final response = await http.post(
      Uri.parse('http://192.168.45.204:5000/clubs/${widget.clubId}/apply/${widget.applicant['id']}/accept'),
    );
    setState(() => _isLoading = false);
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가입 신청을 수락했습니다.')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수락 실패')),
      );
    }
  }

  Future<void> _reject() async {
    setState(() => _isLoading = true);
    final response = await http.post(
      Uri.parse('http://192.168.45.204:5000/clubs/${widget.clubId}/apply/${widget.applicant['id']}/reject'),
    );
    setState(() => _isLoading = false);
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가입 신청을 거절했습니다.')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('거절 실패')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.applicant;
    return Scaffold(
      appBar: AppBar(title: const Text('가입 신청 상세')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이름: ${a['user_name'] ?? ''}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('이메일: ${a['user_email'] ?? ''}'),
            const SizedBox(height: 8),
            Text('성별: ${a['gender'] ?? ''}'),
            const SizedBox(height: 8),
            Text('학과/학번: ${a['major'] ?? ''}'),
            const SizedBox(height: 8),
            Text('전화번호: ${a['phone'] ?? ''}'),
            const SizedBox(height: 8),
            Text('자기소개: ${a['intro'] ?? ''}'),
            const Spacer(),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _accept,
                          child: const Text('가입 수락'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _reject,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('가입 거절'),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
