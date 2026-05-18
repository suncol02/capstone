import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 배경색 흰색
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 학교 로고 이미지
            Image.asset(
              'image/university_logo.png', // 이미지 경로
              width: 100, // 이미지 크기
              errorBuilder: (context, error, stackTrace) {
                return const Text(
                  '이미지를 불러올 수 없습니다.',
                  style: TextStyle(color: Colors.red),
                );
              },
            ),
            const SizedBox(height: 20),

            // 제목 텍스트 (한 줄로 표시)
            const Text(
              '배재톡:배재인 동아리의 커뮤니티',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),

            // 추가된 텍스트
            const Text(
              'Login to your account',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 40),

            // 로그인 버튼
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login'); // 로그인 페이지로 이동
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent, // 버튼 배경색
                foregroundColor: Colors.white, // 텍스트 색상
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30), // 둥근 모서리
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 80, vertical: 15), // 버튼 크기 조정
              ),
              child: const Text(
                '로그인',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        
            const SizedBox(height: 20), // 버튼 간격

             ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/signup'); // 회원가입 페이지로 이동
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlueAccent, // 버튼 배경색
                foregroundColor: Colors.white, // 텍스트 색상
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30), // 둥근 모서리
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 80, vertical: 15), // 버튼 크기 조정
              ),
              child: const Text(
                '회원가입',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 20), // 버튼 간격)  

          ],
        ),
      ),
    );
  }
}
