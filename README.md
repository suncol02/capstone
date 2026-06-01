# Team-it (팀잇) - 팀 프로젝트 관리 및 단체 채팅 애플리케이션

## 🎯 프로젝트 개요
Team-it은 팀 프로젝트를 효율적으로 관리하고 팀원들과 실시간으로 소통할 수 있는 통합 플랫폼입니다.

### 주요 기능
- **프로젝트 관리**: 프로젝트 생성, 조회, 수정, 삭제
- **단체 채팅**: 프로젝트별 채팅방 생성 및 실시간 메시지
- **팀원 관리**: 채팅방 멤버 추가/제거
- **사용자 인증**: 회원가입, 로그인

## 🏗️ 프로젝트 구조

```
capstone/
├── backend/          # Django REST 백엔드
│   ├── accounts/     # 사용자 인증
│   ├── projects/     # 프로젝트, 채팅방, 메시지
│   ├── config/       # Django 설정
│   └── manage.py
├── team_it/          # Flutter 프론트엔드
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/  # 로그인, 메인, 채팅 화면
│   │   └── widgets/  # 재사용 가능한 위젯
│   └── pubspec.yaml
└── README.md
```

## 🚀 설치 및 실행 방법

### 백엔드 (Django)

#### 1. 가상환경 활성화
```bash
cd backend
source venv/bin/activate  # Linux/Mac
# 또는 Windows에서
# venv\Scripts\activate
```

#### 2. 패키지 설치
```bash
pip install -r requirements.txt
```

#### 3. 마이그레이션 실행
```bash
python manage.py makemigrations
python manage.py migrate
```

#### 4. ASGI 서버 실행
```bash
uvicorn config.asgi:application --host 0.0.0.0 --port 8000
```
- 서버는 `http://localhost:8000`에서 실행됩니다.
- 채팅 WebSocket은 `ws://localhost:8000/ws/chat-rooms/{id}/?token={auth_token}`으로 연결됩니다.

#### 5. Django Admin 생성 (선택사항)
```bash
python manage.py createsuperuser
```
- Django Admin: `http://localhost:8000/admin`

### 프론트엔드 (Flutter)

#### 1. 패키지 설치
```bash
cd team_it
flutter pub get
```

#### 2. Flutter 앱 실행
```bash
flutter run
```

## 📌 API 주요 엔드포인트

### 프로젝트
- `GET /api/projects/` - 프로젝트 목록
- `POST /api/projects/` - 프로젝트 생성
- `GET /api/projects/{id}/` - 프로젝트 상세
- `POST /api/projects/{id}/create_chat_room/` - 채팅방 생성

### 채팅방
- `GET /api/chat-rooms/` - 채팅방 목록
- `GET /api/chat-rooms/{id}/` - 채팅방 상세
- `GET /api/chat-rooms/{id}/messages/` - 메시지 조회
- `POST /api/chat-rooms/{id}/send_message/` - 메시지 전송
- `WS /ws/chat-rooms/{id}/?token={auth_token}` - 실시간 메시지 송수신
- `POST /api/chat-rooms/{id}/add_member/` - 멤버 추가
- `POST /api/chat-rooms/{id}/remove_member/` - 멤버 제거

### 메시지
- `GET /api/messages/` - 메시지 목록

## 🔧 설정

### API URL 설정 (프론트엔드)
`lib/screens/chat_screen.dart`와 `lib/screens/main_screen.dart`에서 API URL을 설정합니다:

```dart
const String API_BASE_URL = 'http://YOUR_SERVER_IP:8000/api';
```

### 인증 토큰 설정
각 API 호출에 JWT 토큰을 추가해야 합니다:

```dart
headers: {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer YOUR_TOKEN',
},
```

## 📱 주요 화면

1. **로그인/회원가입** - 사용자 인증
2. **메인 화면** - 프로젝트 목록 및 카테고리
3. **프로젝트 상세** - 채팅방 목록 및 생성
4. **채팅 화면** - 실시간 메시지 송수신

## 🛒 기술 스택

### 백엔드
- Django 6.0.3
- Django REST Framework 3.14.0
- Django CORS Headers 4.3.1
- SQLite (기본)

### 프론트엔드
- Flutter 3.11.1+
- Dart
- HTTP 1.6.0

## 📝 개발 노트

### 진행 중인 작업
- [x] WebSocket을 활용한 실시간 채팅
- [ ] 이미지/파일 업로드
- [ ] 채팅방 권한 관리 강화
- [ ] 푸시 알림

### 주의사항
- 현재는 토큰 인증이 임시로 TODO로 표시되어 있습니다.
- 로컬 테스트 시 CORS 설정을 확인하세요.
- 프로덕션 배포 전에 SECRET_KEY를 변경하세요.
