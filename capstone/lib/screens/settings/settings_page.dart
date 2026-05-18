// 새 파일 생성 또는 기존 SettingsPage에 추가

import 'package:flutter/material.dart';
import '../club/club_member_manage_page.dart'; // 멤버 관리 페이지 import
import '../club/club_profile_edit_page.dart'; // 통합 수정 페이지 import
import '../club/club_apply_manage_page.dart'; // 가입 신청자 관리 페이지 import
import 'package:http/http.dart' as http; // http 패키지 import
import 'package:shared_preferences/shared_preferences.dart'; // shared_preferences 패키지 import
import '../home/home_page.dart'; // HomePage import
import '../../config/api_config.dart';

class SettingsPage extends StatelessWidget {
  final Map<String, dynamic> club;
  final VoidCallback? onClubUpdated;

  const SettingsPage({super.key, required this.club, this.onClubUpdated});

  @override
  Widget build(BuildContext context) {
    final bool isOwner = club['president_id'] == 1; // 실제 로그인 유저 id로 대체 필요

    final List<_SettingsMenuItem> menuItems = [
      if (isOwner)
        _SettingsMenuItem(
          icon: Icons.edit,
          title: '동아리 프로필/소개 수정',
          onTap: () async {
            // 통합 수정 페이지로 이동
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClubProfileAndDescEditPage(club: club),
              ),
            );
            if (result == true && onClubUpdated != null) onClubUpdated!();
          },
        ),
      if (isOwner)
        _SettingsMenuItem(
          icon: Icons.group,
          title: '멤버 관리',
          onTap: () async {
            // 멤버 관리 페이지로 이동
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClubMemberManagePage(clubId: club['id']),
              ),
            );
          },
        ),
      if (isOwner)
        _SettingsMenuItem(
          icon: Icons.person_add_alt_1,
          title: '가입 신청자 관리',
          onTap: () async {
            // 가입 신청자 관리 페이지로 이동
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClubApplyManagePage(clubId: club['id']),
              ),
            );
          },
        ),
      _SettingsMenuItem(
        icon: Icons.exit_to_app,
        title: isOwner ? '동아리 삭제' : '동아리 탈퇴',
        onTap: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text(isOwner ? '동아리 삭제' : '동아리 탈퇴'),
                  content: Text(
                    isOwner ? '정말로 동아리를 삭제하시겠습니까?' : '정말로 동아리에서 탈퇴하시겠습니까?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('확인'),
                    ),
                  ],
                ),
          );
          if (confirm == true) {
            if (isOwner) {
              // 동아리 삭제 API 호출
              await ApiConfig.initializeUrls();
              final response = await http.delete(
                Uri.parse('${ApiConfig.clubsUrl}/${club['id']}'),
              );
              if (response.statusCode == 200) {
                if (context.mounted) {
                  // 삭제 팝업
                  await showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('동아리 삭제 완료'),
                          content: const Text('동아리가 삭제되었습니다.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('확인'),
                            ),
                          ],
                        ),
                  );
                  // home_page.dart(HomePage)로 이동, 스택 초기화
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomePage()),
                    (route) => false,
                  );
                  if (onClubUpdated != null) onClubUpdated!();
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('동아리 삭제 실패: ${response.body}')),
                );
              }
            } else {
              // 동아리 탈퇴 API 호출
              final prefs = await SharedPreferences.getInstance();
              final userId = prefs.getInt('user_id');
              if (userId == null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('로그인 정보가 없습니다.')));
                return;
              }
              
              await ApiConfig.initializeUrls();
              final response = await http.delete(
                Uri.parse(ApiConfig.deleteMemberUrl(club['id'], userId)),
              );
              if (response.statusCode == 200) {
                if (context.mounted) {
                  await showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('동아리 탈퇴 완료'),
                          content: const Text('동아리에서 탈퇴되었습니다.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('확인'),
                            ),
                          ],
                        ),
                  );
                  Navigator.popUntil(context, (route) => route.isFirst);
                  if (onClubUpdated != null) onClubUpdated!();
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('동아리 탈퇴 실패: ${response.body}')),
                );
              }
            }
          }
        },
        iconColor: Colors.red,
        textColor: Colors.red,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('동아리 설정'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        children:
            menuItems
                .map(
                  (item) => ListTile(
                    leading: Icon(
                      item.icon,
                      color: item.iconColor ?? Colors.purple,
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(color: item.textColor),
                    ),
                    onTap: item.onTap,
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _SettingsMenuItem {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? textColor;

  _SettingsMenuItem({
    required this.icon,
    required this.title,
    this.onTap,
    this.iconColor,
    this.textColor,
  });
}
