"""계정 관련 뷰(API 엔드포인트) 모듈

사용자 인증 및 회원가입 관련 API 엔드포인트를 정의합니다.
"""

from rest_framework import status
from rest_framework.response import Response
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.authtoken.models import Token
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth import authenticate

from .serializers import SignUpSerializer
from .models import User


@api_view(['POST'])
@permission_classes([AllowAny])
@csrf_exempt
def signup(request):
    """사용자 회원가입 API 엔드포인트
    
    POST 요청으로 사용자 데이터를 받아 새로운 계정을 생성합니다.
    
    Args:
        request: HTTP 요청 객체
               - body: {email, password, department, personality_type}
    
    Returns:
        Response: 
            - 성공(201): {"message": "회원가입 성공!", "token": token_key}
            - 실패(400): 검증 스 오류 메세지 (예: 필드 누락, 형식 오류 등)
    
    Example:
        POST /accounts/signup/
        Content-Type: application/json
        
        {
            "email": "user@example.com",
            "password": "secure_password",
            "department": "Computer Science",
            "personality_type": "INTJ"
        }
    """
    try:
        # 요청 데이터로 시리얼라이저 인스턴스 생성
        print(f"[DEBUG] 회원가입 요청 데이터: {request.data}")
        serializer = SignUpSerializer(data=request.data)
        
        # 데이터 검증 수행
        if serializer.is_valid():
            # 검증 완료된 데이터로 새로운 사용자 생성
            user = serializer.save()
            print(f"[DEBUG] 사용자 생성 완료: {user.username}")
            
            # 토큰 생성
            token, created = Token.objects.get_or_create(user=user)
            print(f"[DEBUG] 토큰 생성 완료: {token.key}")
            
            # 성공 응답 반환 (201 Created)
            return Response({
                "message": "회원가입 성공!",
                "token": token.key,
                "email": user.email
            }, status=status.HTTP_201_CREATED)
        
        # 검증 실패 시 오류 메세지와 함께 400 응답 반환
        print(f"[DEBUG] 회원가입 검증 실패: {serializer.errors}")
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        print(f"[DEBUG] 회원가입 예외 발생: {type(e).__name__}: {str(e)}")
        import traceback
        traceback.print_exc()
        return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([AllowAny])
@csrf_exempt
def login(request):
    """사용자 로그인 API 엔드포인트"""
    try:
        print(f"[DEBUG] ===== 로그인 요청 시작 =====")
        print(f"[DEBUG] Content-Type: {request.META.get('CONTENT_TYPE')}")
        print(f"[DEBUG] 요청 메서드: {request.method}")
        print(f"[DEBUG] 요청 바디 타입: {type(request.body)}")
        print(f"[DEBUG] 요청 바디: {request.body}")
        print(f"[DEBUG] request.data: {request.data}")
        print(f"[DEBUG] request.data 타입: {type(request.data)}")
        
        # 요청 데이터에서 아이디와 패스워드 가져오기
        id_or_email = request.data.get('id') or request.data.get('email', '')
        password = request.data.get('password', '')
        
        print(f"[DEBUG] 로그인 요청 - id/email: {id_or_email}, password: {'*' * len(password) if password else 'None'}")
        print(f"[DEBUG] 요청 데이터 전체: {request.data}")
        
        # 유효성 검사
        if not id_or_email or not password:
            print(f"[DEBUG] 입력 필드 누락: id_or_email={id_or_email}, password={password}")
            return Response(
                {"error": "아이디와 패스워드를 입력하세요."},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # username(이메일)으로 사용자 찾기
        print(f"[DEBUG] 사용자 검색 시작 - username: {id_or_email}")
        users = User.objects.filter(username=id_or_email)
        print(f"[DEBUG] 검색 결과: {users.count()}명")
        
        if not users.exists():
            print(f"[DEBUG] 사용자 없음: {id_or_email}")
            print(f"[DEBUG] 존재하는 사용자: {list(User.objects.values_list('username', flat=True))}")
            return Response(
                {"error": "아이디 또는 패스워드가 올바르지 않습니다."},
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        user = users.first()
        print(f"[DEBUG] 사용자 찾음: {user.username}")
        
        # 패스워드 확인
        if user.check_password(password):
            print(f"[DEBUG] 패스워드 일치")
            # 토큰 생성 또는 조회
            token, created = Token.objects.get_or_create(user=user)
            print(f"[DEBUG] 토큰 생성/조회 완료: {token.key}")
            return Response({
                "message": "로그인 성공!",
                "user_id": user.id,
                "email": user.email,
                "department": user.department,
                "token": token.key,
                "first_name": user.first_name,
            }, status=status.HTTP_200_OK)
        else:
            print(f"[DEBUG] 패스워드 불일치")
            return Response(
                {"error": "아이디 또는 패스워드가 올바르지 않습니다."},
                status=status.HTTP_401_UNAUTHORIZED
            )
    except Exception as e:
        print(f"[DEBUG] 로그인 예외 발생: {type(e).__name__}: {str(e)}")
        import traceback
        traceback.print_exc()
        return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)