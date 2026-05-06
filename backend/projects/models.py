"""프로젝트 관련 데이터베이스 모델 모듈

프로젝트(Project), 팀(Team), 작업(Task) 등 프로젝트 관리
관련 데이터베이스 구조를 정의합니다.
"""

from django.db import models
from accounts.models import User


class Project(models.Model):
    """프로젝트 모델
    
    팀 프로젝트의 기본 정보를 저장합니다.
    
    Attributes:
        title (CharField): 프로젝트 제목
        description (TextField): 프로젝트 설명
        category (CharField): 프로젝트 카테고리 (수업/대외활동)
        owner (ForeignKey): 프로젝트 생성자 (User)
        status (CharField): 프로젝트 상태
        created_at (DateTimeField): 프로젝트 생성 시간
        updated_at (DateTimeField): 프로젝트 수정 시간
    """
    CATEGORY_CHOICES = [
        ('수업', '수업'),
        ('대외활동', '대외활동'),
    ]
    STATUS_CHOICES = [
        ('모집중', '모집중'),
        ('진행중', '진행중'),
        ('완료', '완료'),
    ]
    
    # 프로젝트 제목
    title = models.CharField(
        max_length=200,
        help_text="프로젝트의 제목"
    )
    
    # 프로젝트 상세 설명
    description = models.TextField(
        blank=True,
        help_text="프로젝트 상세 설명"
    )
    
    # 카테고리
    category = models.CharField(
        max_length=20,
        choices=CATEGORY_CHOICES,
        default='수업',
        help_text="프로젝트 카테고리"
    )
    
    # 프로젝트 생성자 (프로젝트 소유자)
    owner = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='projects',
        help_text="프로젝트를 생성한 사용자"
    )
    
    # 프로젝트 상태
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='모집중',
        help_text="프로젝트 진행 상태"
    )
    
    # 생성 시간 (자동으로 현재 시간 설정)
    created_at = models.DateTimeField(auto_now_add=True)
    
    # 수정 시간 (수정될 때마다 자동으로 갱신)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        """모델 메타 설정"""
        verbose_name = "프로젝트"
        verbose_name_plural = "프로젝트들"
        ordering = ['-created_at']
    
    def __str__(self):
        """프로젝트 객체의 문자열 표현
        
        Returns:
            str: 프로젝트 이름
        """
        return self.name


class ChatRoom(models.Model):
    """채팅방 모델
    
    프로젝트별 그룹 채팅방을 관리합니다.
    
    Attributes:
        project (ForeignKey): 채팅방이 속한 프로젝트
        name (CharField): 채팅방 이름
        description (TextField): 채팅방 설명
        type (CharField): 채팅 종류 (개인/팀)
        members (ManyToManyField): 채팅방 멤버
        created_at (DateTimeField): 채팅방 생성 시간
        updated_at (DateTimeField): 채팅방 수정 시간
    """
    CHAT_TYPE_CHOICES = [
        ('개인', '개인'),
        ('팀', '팀'),
    ]
    
    # 채팅방이 속한 프로젝트
    project = models.ForeignKey(
        Project,
        on_delete=models.CASCADE,
        related_name='chat_rooms',
        help_text="채팅방이 속한 프로젝트"
    )
    
    # 채팅방 이름
    name = models.CharField(
        max_length=200,
        help_text="채팅방의 이름"
    )
    
    # 채팅방 설명
    description = models.TextField(
        blank=True,
        help_text="채팅방 설명"
    )
    
    # 채팅 종류 (개인/팀)
    type = models.CharField(
        max_length=20,
        choices=CHAT_TYPE_CHOICES,
        default='팀',
        help_text="채팅 종류"
    )
    
    # 채팅방 멤버
    members = models.ManyToManyField(
        User,
        related_name='chat_rooms',
        help_text="채팅방에 참여하는 사용자들"
    )
    
    # 생성 시간
    created_at = models.DateTimeField(auto_now_add=True)
    
    # 수정 시간
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        """모델 메타 설정"""
        verbose_name = "채팅방"
        verbose_name_plural = "채팅방들"
        ordering = ['-created_at']
    
    def __str__(self):
        """채팅방 객체의 문자열 표현
        
        Returns:
            str: 채팅방 이름
        """
        return self.name


class Message(models.Model):
    """메시지 모델
    
    채팅방의 메시지를 저장합니다.
    
    Attributes:
        chat_room (ForeignKey): 메시지가 속한 채팅방
        sender (ForeignKey): 메시지 발신자
        content (TextField): 메시지 내용
        created_at (DateTimeField): 메시지 생성 시간
    """
    # 메시지가 속한 채팅방
    chat_room = models.ForeignKey(
        ChatRoom,
        on_delete=models.CASCADE,
        related_name='messages',
        help_text="메시지가 속한 채팅방"
    )
    
    # 메시지 발신자
    sender = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='messages',
        help_text="메시지를 보낸 사용자"
    )
    
    # 메시지 내용
    content = models.TextField(
        help_text="메시지 내용"
    )
    
    # 생성 시간
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        """모델 메타 설정"""
        verbose_name = "메시지"
        verbose_name_plural = "메시지들"
        ordering = ['created_at']
    
    def __str__(self):
        """메시지 객체의 문자열 표현
        
        Returns:
            str: 발신자와 메시지 내용 요약
        """
        return f"{self.sender.username}: {self.content[:50]}"


class Recruitment(models.Model):
    """모집 공고 모델
    
    프로젝트의 팀원 모집 공고를 관리합니다.
    
    Attributes:
        project (ForeignKey): 모집 관련 프로젝트
        role (CharField): 모집 역할
        requirements (TextField): 모집 요구사항
        status (CharField): 모집 상태 (모집중/마감)
    """
    RECRUITMENT_STATUS_CHOICES = [
        ('모집중', '모집중'),
        ('마감', '마감'),
    ]
    
    # 모집 관련 프로젝트
    project = models.ForeignKey(
        Project,
        on_delete=models.CASCADE,
        related_name='recruitments',
        help_text="모집 관련 프로젝트"
    )
    
    # 모집 역할
    role = models.CharField(
        max_length=100,
        help_text="모집하는 역할 (예: 백엔드, 디자인 등)"
    )
    
    # 모집 요구사항
    requirements = models.TextField(
        blank=True,
        help_text="모집 요구사항 및 설명"
    )
    
    # 모집 상태
    status = models.CharField(
        max_length=20,
        choices=RECRUITMENT_STATUS_CHOICES,
        default='모집중',
        help_text="모집 상태"
    )
    
    class Meta:
        """모델 메타 설정"""
        verbose_name = "모집 공고"
        verbose_name_plural = "모집 공고들"
        ordering = ['-project__created_at']
    
    def __str__(self):
        """모집 공고 객체의 문자열 표현
        
        Returns:
            str: 프로젝트명과 역할
        """
        return f"{self.project.title} - {self.role}"


class Archive(models.Model):
    """아카이브 모델
    
    사용자가 완료하거나 중도 탈퇴한 프로젝트 기록을 저장합니다.
    
    Attributes:
        user (ForeignKey): 아카이브 주인
        project (ForeignKey): 아카이브된 프로젝트
        role (CharField): 프로젝트에서의 역할
        result (CharField): 결과 (완료/중도탈퇴)
        archived_at (DateTimeField): 아카이브 시간
    """
    ARCHIVE_RESULT_CHOICES = [
        ('완료', '완료'),
        ('중도탈퇴', '중도탈퇴'),
    ]
    
    # 아카이브 주인
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='archives',
        help_text="아카이브된 프로젝트의 사용자"
    )
    
    # 아카이브된 프로젝트
    project = models.ForeignKey(
        Project,
        on_delete=models.CASCADE,
        related_name='archives',
        help_text="아카이브된 프로젝트"
    )
    
    # 프로젝트에서의 역할
    role = models.CharField(
        max_length=100,
        blank=True,
        help_text="프로젝트에서의 역할"
    )
    
    # 결과
    result = models.CharField(
        max_length=20,
        choices=ARCHIVE_RESULT_CHOICES,
        help_text="프로젝트 결과"
    )
    
    # 아카이브 시간
    archived_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        """모델 메타 설정"""
        verbose_name = "아카이브"
        verbose_name_plural = "아카이브들"
        ordering = ['-archived_at']
    
    def __str__(self):
        """아카이브 객체의 문자열 표현
        
        Returns:
            str: 사용자명과 프로젝트명
        """
        return f"{self.user.email} - {self.project.title} ({self.result})"
