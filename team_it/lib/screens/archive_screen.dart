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
  bool _isLoading = true;
  String _displayName = '사용자';
  List<Map<String, dynamic>> _completedProjects = [];

  @override
  void initState() {
    super.initState();
    _loadArchive();
  }

  Future<void> _loadArchive() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? '';
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
        _displayName = email.contains('@') ? email.split('@')[0] : (email.isEmpty ? '사용자' : email);
        _completedProjects = projects;
        _isLoading = false;
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
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        title: const Text('나의 아카이브'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: content,
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: const Color(0xFFF3F3F3),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text(
            '나의 아카이브',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          _ArchiveProfile(name: _displayName),
          const SizedBox(height: 18),
          _ArchiveProgress(completedCount: _completedProjects.length),
          const SizedBox(height: 18),
          Text(
            '완료한 활동 ${_completedProjects.length}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (_completedProjects.isEmpty)
            const _EmptyArchive()
          else
            ..._completedProjects.map((project) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CompletedActivityTile(project: project),
              );
            }),
        ],
      ),
    );
  }
}

class _ArchiveProfile extends StatelessWidget {
  final String name;

  const _ArchiveProfile({required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey.shade300,
          child: const Icon(Icons.person, color: Colors.white, size: 42),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          '컴퓨터공학과',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }
}

class _ArchiveProgress extends StatelessWidget {
  final int completedCount;

  const _ArchiveProgress({required this.completedCount});

  @override
  Widget build(BuildContext context) {
    final percent = (completedCount / 10).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('프로젝트 완료율', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            '${(percent * 100).round()}%',
            style: const TextStyle(color: Color(0xFFFF8F1F), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              color: const Color(0xFFFFC46B),
              backgroundColor: Colors.grey.shade200,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedActivityTile extends StatelessWidget {
  final Map<String, dynamic> project;

  const _CompletedActivityTile({required this.project});

  String _text(List<String> keys, String fallback) {
    for (final key in keys) {
      final value = project[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final title = _text(['name', 'title'], '완료 프로젝트');
    final period = _text(['period', 'date_range', 'application_period', 'recruitment_period'], '기간 정보 없음');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.brown.shade100,
            child: const Icon(Icons.groups, color: Colors.brown),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  period,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.black54),
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(Icons.archive_outlined, size: 44, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          const Text(
            '완료한 활동이 없습니다.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
