"""계정 관련 데이터베이스 모델 모듈

사용자(User) 모델 및 계정 관련 데이터베이스 구조를 정의합니다.
"""

from django.db import models
from django.contrib.auth.models import AbstractUser, Group, Permission


class User(AbstractUser):
    """사용자 계정 모델
    
    Django의 기본 User 모델을 확장하여 추가 정보를 저장합니다.
    
    Attributes:
        department (CharField): 사용자의 부서/학과
        personality_type (CharField): 사용자의 성격 유형 (예: MBTI)
        profile_score (IntegerField): 사용자 프로필 점수
        completed_projects (IntegerField): 완료한 프로젝트 수
    """
    # 사용자의 부서 또는 학과 정보
    department = models.CharField(
        max_length=100,
        blank=True,
        help_text="사용자가 소속된 부서 또는 학과"
    )
    
    # 사용자의 성격 유형 (MBTI 등)
    personality_type = models.CharField(
        max_length=50,
        blank=True,
        help_text="사용자의 성격 유형 (예: INTJ, ENFP 등)"
    )
    
    # 프로필 점수
    profile_score = models.IntegerField(
        default=0,
        help_text="사용자 프로필 점수"
    )
    
    # 완료한 프로젝트 수
    completed_projects = models.IntegerField(
        default=0,
        help_text="완료한 프로젝트 수"
    )
    
    # 그룹 권한
    groups = models.ManyToManyField(
        Group,
        related_name="accounts_user_set",  # 충돌 회피
        blank=True,
        help_text="그룹 권한"
    )
    # 개별 권한
    user_permissions = models.ManyToManyField(
        Permission,
        related_name="accounts_user_permissions_set",  # 충돌 회피
        blank=True,
        help_text="개별 권한"
    )
    
    class Meta:
        """모델 메타 설정"""
        verbose_name = "사용자"
        verbose_name_plural = "사용자들"
        ordering = ['-date_joined']
    
    def __str__(self):
        """사용자 객체의 문자열 표현
        
        Returns:
            str: 사용자의 이메일
        """
        return self.email
