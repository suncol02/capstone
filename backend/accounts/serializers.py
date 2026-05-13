"""계정 관련 시리얼라이저 모듈

DRF(Django Rest Framework) 시리얼라이저를 사용하여 사용자 회원가입 데이터의
검증 및 변환을 처리합니다.
"""

from rest_framework import serializers
from .models import User


class SignUpSerializer(serializers.ModelSerializer):
    """회원가입 시리얼라이저
    
    사용자의 회원가입 요청 데이터를 검증하고 새로운 사용자를 생성합니다.
    - email: 사용자의 이메일 (필수)
    - password: 사용자의 비밀번호 (필수, write_only로 설정하여 응답에 포함되지 않음)
    - name: 사용자의 이름 (필수)
    - department: 사용자의 부서/학과 (선택)
    - personality_type: 사용자의 성격 유형 (선택)
    """
    
    # 비밀번호는 write_only로 설정하여 응답에 포함되지 않도록 보안 처리
    password = serializers.CharField(write_only=True)
    name = serializers.CharField(required=True)
    department = serializers.CharField(required=False, allow_blank=True)
    personality_type = serializers.CharField(required=False, allow_blank=True)

    def validate_email(self, value):
        """이메일 중복 체크
        
        이미 등록된 이메일인지 확인합니다.
        
        Args:
            value (str): 검증할 이메일 주소
            
        Returns:
            str: 검증된 이메일 주소
            
        Raises:
            serializers.ValidationError: 이메일이 이미 존재하는 경우
        """
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("이미 사용 중인 이메일입니다.")
        return value

    def create(self, validated_data):
        """검증된 데이터로 새로운 사용자 객체 생성
        
        Args:
            validated_data: 검증이 완료된 사용자 데이터 딕셔너리
        
        Returns:
            User: 생성된 사용자 객체
        """
        # create_user 메서드를 사용하여 비밀번호를 자동으로 해싱 처리
        user = User.objects.create_user(
            # 이메일을 username으로 사용하여 고유성 보장
            username=validated_data['email'],
            email=validated_data['email'],
            password=validated_data['password'],
            # first_name에 이름 저장
            first_name=validated_data.get('name', ''),
            # get()을 사용하여 선택적 필드는 기본값 설정
            department=validated_data.get('department', ''),
            personality_type=validated_data.get('personality_type', '')
        )
        return user

    class Meta:
        model = User
        fields = ('email', 'password', 'name', 'department', 'personality_type')
        extra_kwargs = {
            'password': {'write_only': True},
        }