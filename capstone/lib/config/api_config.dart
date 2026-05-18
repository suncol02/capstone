import 'dart:async';
import 'package:http/http.dart' as http;

class ApiConfig {
  // DDNS 주소 - 포트 3000 사용
  static const String baseUrl = 'http://testtype.iptime.org:3000';

  // 백업 URL (로컬 네트워크용)
  static const String localBaseUrl = 'http://192.168.0.3:3000';

  // WebSocket 서버 URL 추가
  static const String websocketUrl = 'http://testtype.iptime.org:4001';
  static const String localWebsocketUrl = 'http://192.168.0.3:4001';

  // 연결 테스트용
  static const String healthCheckUrl = '$baseUrl/health';

  // 현재 활성 URL들을 저장
  static String _currentBaseUrl = baseUrl;
  static String _currentWebsocketUrl = websocketUrl;

  // Posts
  static String get postsUrl => '$_currentBaseUrl/posts';

  // Auth
  static String get loginUrl => '$_currentBaseUrl/login';
  static String get registerUrl => '$_currentBaseUrl/register';
  static String get checkEmailUrl => '$_currentBaseUrl/check-email';
  static String get updateProfileUrl => '$_currentBaseUrl/update-profile';

  // Clubs
  static String get clubsUrl => '$_currentBaseUrl/clubs';

  // API
  static String get apiUsersUrl => '$_currentBaseUrl/api/user';
  static String get apiClubMessagesUrl => '$_currentBaseUrl/api/clubs';

  // WebSocket URL getter
  static String get currentWebsocketUrl => _currentWebsocketUrl;

  // Helper methods for dynamic URLs
  static String clubDetailUrl(int clubId) => '$clubsUrl/$clubId';
  static String clubPostsUrl(int clubId) => '$clubsUrl/$clubId/posts';
  static String clubApplyUrl(int clubId) => '$clubsUrl/$clubId/apply';
  static String clubApplyStatusUrl(int clubId, int userId) =>
      '$clubsUrl/$clubId/apply/status/$userId';
  static String clubApplyAcceptUrl(int clubId, int applyId) =>
      '$clubsUrl/$clubId/apply/$applyId/accept';
  static String clubApplyRejectUrl(int clubId, int applyId) =>
      '$clubsUrl/$clubId/apply/$applyId/reject';
  static String clubMembersUrl(int clubId) => '$clubsUrl/$clubId/members';
  static String clubMemberRoleUrl(int clubId, int memberId) =>
      '$clubsUrl/$clubId/members/$memberId/role';
  static String clubMessagesUrl(int clubId) =>
      '$apiClubMessagesUrl/$clubId/messages';
  static String userDetailUrl(int userId) => '$apiUsersUrl/$userId';
  static String postRepliesUrl(int postId) => '$postsUrl/$postId/replies';
  static String postLikeUrl(int postId) => '$postsUrl/$postId/like';
  static String postUnlikeUrl(int postId) => '$postsUrl/$postId/unlike';
  static String replyUrl(int replyId) => '$_currentBaseUrl/replies/$replyId';
  static String deleteMemberUrl(int clubId, int userId) =>
      '$clubsUrl/$clubId/members/$userId';

  // 연결 테스트 헬퍼 메서드 (향상된 버전)
  static Future<bool> testConnection([String? testUrl]) async {
    final urlToTest = testUrl ?? baseUrl;
    try {
      final response = await http.get(
        Uri.parse('$urlToTest/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed for $urlToTest: $e');
      return false;
    }
  }

  // WebSocket 연결 테스트
  static Future<bool> testWebSocketConnection([String? testUrl]) async {
    final urlToTest = testUrl ?? websocketUrl;
    try {
      final response = await http.get(
        Uri.parse('$urlToTest/connected_users'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('WebSocket connection test failed for $urlToTest: $e');
      return false;
    }
  }

  // 동적 URL 초기화 (앱 시작시 호출)
  static Future<void> initializeUrls() async {
    // 메인 서버 연결 테스트
    if (await testConnection(baseUrl)) {
      _currentBaseUrl = baseUrl;
      print('✅ DDNS 서버 연결 성공: $baseUrl');
    } else if (await testConnection(localBaseUrl)) {
      _currentBaseUrl = localBaseUrl;
      print('⚠️ DDNS 연결 실패, 로컬 서버 사용: $localBaseUrl');
    } else {
      print('❌ 모든 서버 연결 실패');
    }

    // WebSocket 서버 연결 테스트
    if (await testWebSocketConnection(websocketUrl)) {
      _currentWebsocketUrl = websocketUrl;
      print('✅ DDNS WebSocket 서버 연결 성공: $websocketUrl');
    } else if (await testWebSocketConnection(localWebsocketUrl)) {
      _currentWebsocketUrl = localWebsocketUrl;
      print('⚠️ DDNS WebSocket 연결 실패, 로컬 WebSocket 사용: $localWebsocketUrl');
    } else {
      print('❌ 모든 WebSocket 서버 연결 실패');
    }
  }

  // 동적 URL 선택 (DDNS 실패시 로컬 사용) - 호환성을 위해 유지
  static Future<String> getActiveBaseUrl() async {
    if (_currentBaseUrl != baseUrl && _currentBaseUrl != localBaseUrl) {
      await initializeUrls();
    }
    return _currentBaseUrl;
  }
}
