import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/login_page.dart';
import 'screens/home/home_page.dart';
import 'screens/auth/signup_page.dart';
import 'screens/welcome/welcome_page.dart';
import 'screens/profile/profile_page.dart';
import 'config/api_config.dart';

void main() async {
  // V1 embedding 문제 방지를 위한 초기화
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 플러그인 초기화 안전성 강화
    try {
      // 시스템 UI 설정
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      );

      // SharedPreferences 초기화 (V2 embedding 호환)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('profile_image');
      await prefs.remove('name');
      await prefs.remove('email');
      
      // API 초기화 (백그라운드에서 실행)
      unawaited(ApiConfig.initializeUrls().catchError((e) {
        print('⚠️ API 초기화 실패: $e');
      }));
      
    } catch (e) {
      print('초기화 오류: $e');
    }
    
    runApp(const MyApp());
  }, (error, stack) {
    print('앱 크래시 방지: $error');
    print('스택 트레이스: $stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '배재톡',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: false,
      ),
      home: const WelcomePage(),
      routes: {
        '/welcome': (context) => const WelcomePage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => const HomePage(),
        '/myInfo': (context) => const ProfilePage(),
      },
    );
  }
}
