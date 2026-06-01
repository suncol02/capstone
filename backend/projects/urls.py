"""프로젝트 관련 URL 라우팅 모듈

프로젝트, 채팅방, 메시지 관련 API 엔드포인트의
URL 경로를 정의합니다.
"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import ProjectViewSet, ChatRoomViewSet, MessageViewSet, ArchiveViewSet

# DefaultRouter를 사용하여 자동으로 URL 패턴 생성
router = DefaultRouter()
router.register(r'projects', ProjectViewSet, basename='project')
router.register(r'chat-rooms', ChatRoomViewSet, basename='chat-room')
router.register(r'messages', MessageViewSet, basename='message')
router.register(r'archives', ArchiveViewSet, basename='archive')

urlpatterns = [
    path('', include(router.urls)),
]
