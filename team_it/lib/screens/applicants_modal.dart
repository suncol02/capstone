import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:team_it/screens/archive_screen.dart';

const String API_BASE_URL = 'http://team-it.iptime.org:8000/api';

class ApplicantsModal extends StatefulWidget {
  final String projectId;
  final String projectTitle;

  const ApplicantsModal({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<ApplicantsModal> createState() => _ApplicantsModalState();
}

class _ApplicantsModalState extends State<ApplicantsModal> {
  List<Map<String, dynamic>> _applicants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApplicants();
  }

  Future<void> _loadApplicants() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 신청자 목록 조회 - 여러 엔드포인트 시도
      List<dynamic> applicantsData = [];
      
      final endpoints = [
        '$API_BASE_URL/projects/${widget.projectId}/applicants/',
        '$API_BASE_URL/projects/${widget.projectId}/applications/',
        '$API_BASE_URL/accounts/applications/?project=${widget.projectId}',
      ];

      http.Response? response;
      int lastStatusCode = 0;
      
      for (var endpoint in endpoints) {
        try {
          response = await http.get(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Token $token',
            },
          ).timeout(const Duration(seconds: 5));
          
          lastStatusCode = response.statusCode;
          if (response.statusCode == 200) break;
        } catch (e) {
          print('[DEBUG] 엔드포인트 실패 ($endpoint): $e');
          continue;
        }
      }

      if (!mounted) return;

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> applicants =
            decoded is List ? decoded : decoded['results'] ?? decoded['data'] ?? [];

        setState(() {
          _applicants = applicants.cast<Map<String, dynamic>>().toList();
          _isLoading = false;
        });
      } else {
        print('[DEBUG] 신청자 목록 로드 실패: $lastStatusCode');
        if (response != null) {
          print('[DEBUG] 응답: ${response.body}');
        }
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('신청자 목록을 불러올 수 없습니다. (상태: $lastStatusCode)'),
          ),
        );
      }
    } catch (e) {
      print('[DEBUG] 신청자 목록 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _approveApplicant(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
        return;
      }

      final response = await http.post(
        Uri.parse(
          '$API_BASE_URL/projects/${widget.projectId}/applicants/$userId/approve/',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신청자를 수락했습니다.')),
        );
        _loadApplicants();
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('수락에 실패했습니다.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }

  Future<void> _rejectApplicant(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
        return;
      }

      final response = await http.post(
        Uri.parse(
          '$API_BASE_URL/projects/${widget.projectId}/applicants/$userId/reject/',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신청자를 거절했습니다.')),
        );
        _loadApplicants();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('거절에 실패했습니다.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '신청 인원 확인',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.projectTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Flexible(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _applicants.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '신청자가 없습니다',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: List.generate(
                            _applicants.length,
                            (index) {
                              final applicant = _applicants[index];
                              final userId = applicant['user_id'] ??
                                  applicant['id'] ??
                                  applicant['user'] ??
                                  '';
                              final email = applicant['email'] ??
                                  applicant['user_email'] ??
                                  '이메일 없음';
                              final name = applicant['name'] ??
                                  applicant['username'] ??
                                  applicant['user_name'] ??
                                  '이름 없음';
                              final status = applicant['status'] ??
                                  applicant['approval_status'] ??
                                  'pending';
                              final isAccepted = status == 'accepted' ||
                                  status == 'approved';

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ArchiveScreen(
                                        userId: userId.toString(),
                                        showAppBar: true,
                                      ),
                                    ),
                                  );
                                },
                                child: Column(
                                  children: [
                                    if (index > 0)
                                      const Divider(height: 1),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor:
                                              Colors.indigo.shade100,
                                          child: Text(
                                            name[0].toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.indigo,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                email,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (status == 'pending' ||
                                            status == 'waiting')
                                          SizedBox(
                                            width: 100,
                                            child: Row(
                                              mainAxisSize:
                                                  MainAxisSize.min,
                                              children: [
                                                Expanded(
                                                  child: ElevatedButton(
                                                    onPressed: () =>
                                                        _approveApplicant(
                                                      userId.toString(),
                                                    ),
                                                    style:
                                                        ElevatedButton
                                                            .styleFrom(
                                                      backgroundColor:
                                                          Colors.green,
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                            horizontal: 6,
                                                            vertical: 6,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      '수락',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: OutlinedButton(
                                                    onPressed: () =>
                                                        _rejectApplicant(
                                                      userId.toString(),
                                                    ),
                                                    style:
                                                        OutlinedButton
                                                            .styleFrom(
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                            horizontal: 6,
                                                            vertical: 6,
                                                          ),
                                                      side: const BorderSide(
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                    child: const Text(
                                                      '거절',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isAccepted
                                                  ? Colors.green.shade100
                                                  : Colors.red.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isAccepted
                                                  ? '수락'
                                                  : '거절',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isAccepted
                                                    ? Colors.green.shade700
                                                    : Colors.red.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                                )
                              );
                            },
                          ),
                        ),
                      ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '총 ${_applicants.length}명',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
