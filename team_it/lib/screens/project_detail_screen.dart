import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String API_BASE_URL = 'http://team-it.iptime.org:8000/api';

class ProjectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> project;

  const ProjectDetailScreen({
    super.key,
    required this.project,
  });

  @override
  State<ProjectDetailScreen> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState
    extends State<ProjectDetailScreen> {
  bool _isApplying = false;
  bool _hasApplied = false;

  int _parseInt(
    dynamic value, {
    required int defaultValue,
  }) {
    if (value is int) return value;

    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }

    return defaultValue;
  }

  List<String> _parseRequirements(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString())
          .toList();
    }

    if (value is String) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return [];
  }

  String? _projectId() {
    final value = widget.project['id'] ??
        widget.project['pk'] ??
        widget.project['project_id'];

    if (value == null ||
        value.toString().trim().isEmpty) {
      return null;
    }

    return value.toString();
  }

  String _responseMessage(
    http.Response response,
    String fallback,
  ) {
    if (response.body.isEmpty) {
      return fallback;
    }

    try {
      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      if (decoded is Map) {
        final message = decoded['message'] ??
            decoded['detail'] ??
            decoded['error'];

        if (message != null &&
            message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }

      return decoded.toString();
    } catch (_) {
      final contentType =
          response.headers['content-type'] ?? '';

      final body = utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );

      final isHtml =
          contentType.contains('text/html') ||
              body
                  .trimLeft()
                  .toLowerCase()
                  .startsWith('<!doctype html') ||
              body
                  .trimLeft()
                  .toLowerCase()
                  .startsWith('<html');

      if (isHtml) {
        return fallback;
      }

      return body.trim().isEmpty
          ? fallback
          : body;
    }
  }

  Future<http.Response> _sendApplyRequest(
    String projectId,
    String token,
  ) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    };

    final projectApply = await http.post(
      Uri.parse(
        '$API_BASE_URL/projects/$projectId/apply/',
      ),
      headers: headers,
    );

    if (projectApply.statusCode != 404) {
      return projectApply;
    }

    return await http.post(
      Uri.parse(
        '$API_BASE_URL/projects/$projectId/join/',
      ),
      headers: headers,
    );
  }

  Future<void> _applyToProject() async {
    if (_isApplying || _hasApplied) return;

    final projectId = _projectId();

    if (projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '프로젝트 정보를 찾을 수 없습니다.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isApplying = true;
    });

    try {
      final prefs =
          await SharedPreferences.getInstance();

      final token =
          prefs.getString('auth_token');

      if (token == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인이 필요합니다.'),
          ),
        );

        return;
      }

      final response = await _sendApplyRequest(
        projectId,
        token,
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        final currentCount = _parseInt(
          widget.project['current_participants'] ??
              widget.project['current_members'] ??
              widget.project['member_count'],
          defaultValue: 0,
        );

        if (!mounted) return;

        setState(() {
          _hasApplied = true;

          widget.project['current_participants'] =
              currentCount + 1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _responseMessage(
                response,
                '신청이 완료되었습니다.',
              ),
            ),
          ),
        );
      } else if (response.statusCode == 400 ||
          response.statusCode == 409) {
        if (!mounted) return;

        setState(() {
          _hasApplied = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _responseMessage(
                response,
                '이미 신청한 프로젝트입니다.',
              ),
            ),
          ),
        );
      } else if (response.statusCode == 401) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '인증이 만료되었습니다. 다시 로그인해주세요.',
            ),
          ),
        );
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _responseMessage(
                response,
                '신청에 실패했습니다.',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '오류가 발생했습니다: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;

    final String title =
        project['name'] ?? '제목 없음';

    final String description =
        project['description'] ??
            '프로젝트 설명';

    final int maxCount = _parseInt(
      project['recruit_count'],
      defaultValue: 3,
    );

    final int currentCount = _parseInt(
      project['current_participants'] ??
          project['current_members'] ??
          project['member_count'],
      defaultValue: 1,
    );

    final double progress = maxCount > 0
        ? (currentCount / maxCount)
            .clamp(0.0, 1.0)
        : 0.0;

    final bool isOpen =
        currentCount < maxCount;

    final List<String> requirements =
        _parseRequirements(
      project['requirements'],
    );

    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F5F5),

      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.all(16),

          children: [
            const SizedBox(height: 20),

            Container(
              padding:
                  const EdgeInsets.all(20),

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius:
                    BorderRadius.circular(20),
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  /// 상단 영역
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,

                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                          children: [
                            Text(
                              title,

                              style:
                                  const TextStyle(
                                fontSize: 26,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),

                            const SizedBox(
                              height: 14,
                            ),

                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),

                              decoration:
                                  BoxDecoration(
                                color: isOpen
                                    ? const Color(
                                        0xFFDDF3D7,
                                      )
                                    : Colors
                                        .grey
                                        .shade300,

                                borderRadius:
                                    BorderRadius.circular(
                                  30,
                                ),
                              ),

                              child: Text(
                                isOpen
                                    ? '모집중'
                                    : '모집마감',

                                style:
                                    TextStyle(
                                  color: isOpen
                                      ? const Color(
                                          0xFF6DAA5B,
                                        )
                                      : Colors
                                          .grey
                                          .shade700,

                                  fontWeight:
                                      FontWeight
                                          .w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      GestureDetector(
                        onTap: () {
                          Navigator.pop(
                            context,
                          );
                        },

                        child: Container(
                          width: 42,
                          height: 42,

                          decoration:
                              BoxDecoration(
                            color: const Color(
                              0xFFF7F7F7,
                            ),

                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),

                            boxShadow: [
                              BoxShadow(
                                color: Colors
                                    .black
                                    .withOpacity(
                                  0.05,
                                ),

                                blurRadius:
                                    10,

                                offset:
                                    const Offset(
                                  0,
                                  4,
                                ),
                              ),
                            ],
                          ),

                          child: const Icon(
                            Icons
                                .arrow_back_ios_new,

                            size: 18,

                            color:
                                Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  Row(
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 18,
                        color: Colors.black54,
                      ),

                      const SizedBox(width: 8),

                      Text(
                        '$currentCount/$maxCount 명',

                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),

                    child:
                        LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,

                      backgroundColor:
                          Colors.grey.shade200,

                      valueColor:
                          const AlwaysStoppedAnimation<
                              Color>(
                        Color(0xFF9FC3F9),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Divider(
                    color:
                        Colors.grey.shade300,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    '요구사항',

                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,

                    children:
                        requirements.map((req) {
                      return Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),

                        decoration:
                            BoxDecoration(
                          color: const Color(
                            0xFFE8ECFF,
                          ),

                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                        ),

                        child: Text(
                          req,

                          style:
                              const TextStyle(
                            color: Color(
                              0xFF7B8EDB,
                            ),

                            fontSize: 12,

                            fontWeight:
                                FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 28),

                  Divider(
                    color:
                        Colors.grey.shade300,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    '프로젝트 설명',

                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 28),

                  Center(
                    child: Text(
                      description,

                      textAlign:
                          TextAlign.center,

                      style: TextStyle(
                        color:
                            Colors.grey.shade700,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ),

                  const SizedBox(height: 80),

                  SizedBox(
                    width: double.infinity,
                    height: 56,

                    child: ElevatedButton(
                      onPressed: isOpen &&
                              !_isApplying &&
                              !_hasApplied
                          ? _applyToProject
                          : null,

                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(
                          0xFF9B98EB,
                        ),

                        disabledBackgroundColor:
                            Colors.grey.shade400,

                        elevation: 0,

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                      ),

                      child: _isApplying
                          ? const SizedBox(
                              width: 24,
                              height: 24,

                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                    Colors.white,
                              ),
                            )
                          : Text(
                              _hasApplied
                                  ? '신청 완료'
                                  : '신청하기',

                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,

                                fontSize: 16,

                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}