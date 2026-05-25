import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ArchiveScreen extends StatefulWidget {
  final bool showAppBar;

  const ArchiveScreen({super.key, this.showAppBar = true});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<Map<String, dynamic>> _completedProjects = [];

  @override
  void initState() {
    super.initState();
    _loadCompletedProjects();
  }

  Future<void> _loadCompletedProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final archive = prefs.getStringList('completed_projects') ?? [];

    final projects = archive
        .map((item) {
          try {
            final decoded = jsonDecode(item);
            return decoded is Map<String, dynamic> ? decoded : null;
          } catch (_) {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    if (mounted) {
      setState(() {
        _completedProjects = projects;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('아카이브'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: content,
    );
  }

  Widget _buildContent() {
    if (_completedProjects.isEmpty) {
      return const _EmptyArchive();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _completedProjects.length,
      itemBuilder: (context, index) {
        return _ArchiveReportCard(project: _completedProjects[index]);
      },
    );
  }
}

class CompletedProjectDetailScreen extends StatelessWidget {
  final Map<String, dynamic> project;

  const CompletedProjectDetailScreen({super.key, required this.project});

  String _text(List<String> keys, String fallback) {
    for (final key in keys) {
      final value = project[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  List<String> _list(List<String> keys, List<String> fallback) {
    for (final key in keys) {
      final value = project[key];
      if (value is List && value.isNotEmpty) {
        return value.map((item) => item.toString()).toList();
      }
      if (value is String && value.trim().isNotEmpty) {
        return value
            .split(RegExp(r'[\n,]'))
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final title = _text(['name', 'title'], '제목 없음');
    final period = _text(['period', 'date_range'], '2026/05/01 ~ 2026/05/23');
    final activity = _text(
      ['activity_method', 'comment', 'description'],
      '팀 활동 방식이 아직 기록되지 않았습니다.',
    );
    final reviews = _list(
      ['member_reviews', 'reviews', 'feedback'],
      const ['전원이 잘 했네요', '피드백이 정확해요'],
    );
    final links = _list(
      ['links', 'result_links', 'outputs'],
      [
        _text(['github_url', 'repository', 'repo_url'], 'www.example.com'),
        _text(['demo_url', 'file_url', 'result_url'], 'result.html'),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('완료 프로젝트'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        children: [
          _ArchiveHeader(title: title, period: period),
          const SizedBox(height: 22),
          const _SectionTitle('활동 방식'),
          const SizedBox(height: 10),
          _ActivityBox(text: activity),
          const SizedBox(height: 24),
          const _SectionTitle('팀원 상호 평가'),
          const SizedBox(height: 12),
          ...reviews.take(3).map(
                (review) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReviewBubble(text: review),
                ),
              ),
          const SizedBox(height: 14),
          const _SectionTitle('깃허브, 피그마 또는 결과물 링크'),
          const SizedBox(height: 12),
          ...links.take(4).map(
                (link) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ResultLinkTile(link: link),
                ),
              ),
        ],
      ),
    );
  }
}

class _EmptyArchive extends StatelessWidget {
  const _EmptyArchive();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.archive_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            '완료된 프로젝트가 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '완료한 팀 활동이 이곳에 저장됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveReportCard extends StatelessWidget {
  final Map<String, dynamic> project;

  const _ArchiveReportCard({required this.project});

  String _text(List<String> keys, String fallback) {
    for (final key in keys) {
      final value = project[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  List<String> _list(List<String> keys, List<String> fallback) {
    for (final key in keys) {
      final value = project[key];
      if (value is List && value.isNotEmpty) {
        return value.map((item) => item.toString()).toList();
      }
      if (value is String && value.trim().isNotEmpty) {
        return value
            .split(RegExp(r'[\n,]'))
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final title = _text(['name', 'title'], '완료 프로젝트');
    final period = _text(['period', 'date_range'], '2026/05/01 ~ 2026/05/23');
    final activity = _text(
      ['activity_method', 'comment', 'description'],
      '팀 활동 방식이 아직 기록되지 않았습니다.',
    );
    final reviews = _list(
      ['member_reviews', 'reviews', 'feedback'],
      const ['전원이 잘 했네요', '피드백이 정확해요'],
    );
    final links = _list(
      ['links', 'result_links', 'outputs'],
      [
        _text(['github_url', 'repository', 'repo_url'], 'www.example.com'),
        _text(['demo_url', 'file_url', 'result_url'], 'result.html'),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ArchiveHeader(title: title, period: period),
          const SizedBox(height: 22),
          const _SectionTitle('활동 방식'),
          const SizedBox(height: 10),
          _ActivityBox(text: activity),
          const SizedBox(height: 22),
          const _SectionTitle('팀원 상호 평가'),
          const SizedBox(height: 12),
          ...reviews.take(3).map(
                (review) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReviewBubble(text: review),
                ),
              ),
          const SizedBox(height: 12),
          const _SectionTitle('깃허브, 피그마 또는 결과물 링크'),
          const SizedBox(height: 12),
          ...links.take(4).map(
                (link) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ResultLinkTile(link: link),
                ),
              ),
        ],
      ),
    );
  }
}

class _ArchiveHeader extends StatelessWidget {
  final String title;
  final String period;

  const _ArchiveHeader({
    required this.title,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: Colors.grey.shade200,
          child: const Icon(Icons.person_outline, color: Colors.black87),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                period,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _ActivityBox extends StatelessWidget {
  final String text;

  const _ActivityBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black87, width: 1.2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, height: 1.45),
      ),
    );
  }
}

class _ReviewBubble extends StatelessWidget {
  final String text;

  const _ReviewBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 30,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black87, width: 1.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.more_horiz, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _ResultLinkTile extends StatelessWidget {
  final String link;

  const _ResultLinkTile({required this.link});

  IconData get _icon {
    final lower = link.toLowerCase();
    if (lower.contains('figma')) return Icons.design_services_outlined;
    if (lower.contains('github') || lower.contains('git')) {
      return Icons.code_outlined;
    }
    if (lower.contains('.html') || lower.contains('http')) {
      return Icons.link_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black87, width: 1.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black87),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icon, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              link,
              maxLines: 1,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
