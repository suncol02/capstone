import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'archive_screen.dart';
import 'profile_detail_screen.dart';
import 'package:team_it/screens/favorite_screen.dart';
import 'package:team_it/screens/recently_viewed_screen.dart';
import 'package:team_it/screens/my_posts_screen.dart';
import 'package:team_it/screens/login_screen.dart';

class MyInfoScreen extends StatefulWidget {
  const MyInfoScreen({super.key});

  @override
  State<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends State<MyInfoScreen> {
  bool _isLoading = true;
  String _email = '';
  String _displayName = '사용자';
  int _completedProjects = 0;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? '알 수 없음';
    final completed = prefs.getInt('completed_projects') ?? 0;
    final displayName = email.contains('@') ? email.split('@')[0] : email;

    if (mounted) {
      setState(() {
        _email = email;
        _displayName = displayName;
        _completedProjects = completed;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: const Color(0xFFF3F3F3),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
        children: [
          _ProfileTitle(
            onLogoutTap: _logout,
          ),
          const SizedBox(height: 12),
          _ProfileSummaryCard(
            name: _displayName,
            email: _email,
            completionPercent: _completionPercent,
            onTap: _openProfileDetail,
          ),
          const SizedBox(height: 16),
          _CompletionCard(
            completedProjects: _completedProjects,
            percent: _completionPercent,
            onTap: _openArchive,
          ),
          const SizedBox(height: 16),
          _QuickActionCard(
            onFavoriteTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FavoriteScreen(),
                ),
              );
            },
            onRecentlyViewedTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecentlyViewedScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _MyActivityCard(
            completedProjects: _completedProjects,
            onWaitingTap: _showComingSoon,
            onProgressTap: _showComingSoon,
            onCompletedTap: _openArchive,
            onMyPostsTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyPostsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  double get _completionPercent => (_completedProjects / 10).clamp(0.0, 1.0);

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_email');
      await prefs.remove('user_id');
      await prefs.remove('username');
      await prefs.remove('user_profile_score');
      await prefs.remove('completed_projects');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃되었습니다.')),
      );

      // 로그인 화면으로 이동
      Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
      (route) => false,
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('로그아웃 실패: $e'),
        ),
      );
    }
  }

  void _openProfileDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileDetailScreen(
          name: _displayName,
          email: _email,
        ),
      ),
    );
  }

  void _openArchive() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ArchiveScreen()),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('준비 중인 기능입니다.')),
    );
  }
}

class _ProfileTitle extends StatelessWidget {
  final VoidCallback onLogoutTap;

  const _ProfileTitle({
    required this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        10,
        12,
        6,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '프로필',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          IconButton(
            onPressed: onLogoutTap,
            icon: const Icon(
              Icons.logout_outlined,
              size: 28,
              color: Colors.black,
            ),
            tooltip: '로그아웃',
          ),
        ],
      ),
    );
  }
}



class _ProfileSummaryCard extends StatelessWidget {
  final String name;
  final String email;
  final double completionPercent;
  final VoidCallback onTap;

  const _ProfileSummaryCard({
    required this.name,
    required this.email,
    required this.completionPercent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey.shade300,
                child: const Icon(Icons.person, color: Colors.white, size: 34),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PercentBadge(percent: completionPercent),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }
}

class _PercentBadge extends StatelessWidget {
  final double percent;

  const _PercentBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0DC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${(percent * 100).round()}%',
        style: const TextStyle(
          color: Color(0xFFFF9F2E),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  final int completedProjects;
  final double percent;
  final VoidCallback onTap;

  const _CompletionCard({
    required this.completedProjects,
    required this.percent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '프로젝트 완료율',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${(percent * 100).round()}%',
                      style: const TextStyle(
                        color: Color(0xFFFF8F1F),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '$completedProjects/10개',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.black54),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: percent,
                  color: const Color(0xFFFFC46B),
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final VoidCallback onFavoriteTap;
  final VoidCallback onRecentlyViewedTap;

  const _QuickActionCard({
    required this.onFavoriteTap,
    required this.onRecentlyViewedTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: SizedBox(
        height: 58,
        child: Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.favorite,
                iconColor: const Color(0xFFFF8585),
                label: '관심 목록',
                onTap: onFavoriteTap,
              ),
            ),
            Container(width: 1, height: 34, color: Colors.grey.shade300),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.schedule,
                iconColor: Colors.black87,
                label: '최근 본 글',
                onTap: onRecentlyViewedTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}


class _MyActivityCard extends StatelessWidget {
  final int completedProjects;
  final VoidCallback onWaitingTap;
  final VoidCallback onProgressTap;
  final VoidCallback onCompletedTap;
  final VoidCallback onMyPostsTap;

  const _MyActivityCard({
    required this.completedProjects,
    required this.onWaitingTap,
    required this.onProgressTap,
    required this.onCompletedTap,
    required this.onMyPostsTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '나의 활동',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            _ActivityRow(
              icon: Icons.hourglass_empty,
              title: '수락 대기 중인 활동',
              onTap: onWaitingTap,
            ),
            _ActivityRow(
              icon: Icons.track_changes,
              title: '진행 중인 활동',
              onTap: onProgressTap,
            ),
            _ActivityRow(
              icon: Icons.edit,
              title: '내가 올린 글',
              onTap: onMyPostsTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailingText;
  final VoidCallback onTap;

  const _ActivityRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(icon, color: Colors.black, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText!,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.11),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
