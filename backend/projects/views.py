"""프로젝트 관련 뷰(API 엔드포인트) 모듈

프로젝트 생성, 조회, 수정, 삭제 및 채팅방, 메시지
관리 관련 API 엔드포인트를 정의합니다.
"""

from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from django.shortcuts import get_object_or_404
from .models import Project, ChatRoom, Message
from .serializers import (
    ProjectSerializer, ProjectListSerializer,
    ChatRoomSerializer, ChatRoomListSerializer,
    MessageSerializer
)


class ProjectViewSet(viewsets.ModelViewSet):
    """프로젝트 관리 ViewSet
    
    프로젝트의 CRUD 연산과 채팅방 관리를 처리합니다.
    """
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        """사용자가 속한 프로젝트 반환"""
        # TODO: 추후 팀 멤버 관계 추가시 수정
        return Project.objects.filter(owner=self.request.user)
    
    def get_serializer_class(self):
        """요청에 따라 적절한 Serializer 선택"""
        if self.action == 'list':
            return ProjectListSerializer
        return ProjectSerializer
    
    def perform_create(self, serializer):
        """프로젝트 생성시 현재 사용자를 owner로 설정"""
        serializer.save(owner=self.request.user)
    
    @action(detail=True, methods=['post'])
    def create_chat_room(self, request, pk=None):
        """프로젝트에 채팅방 생성"""
        project = self.get_object()
        
        # 권한 확인 (프로젝트 소유자만 가능)
        if project.owner != request.user:
            return Response(
                {'error': '프로젝트 소유자만 채팅방을 생성할 수 있습니다.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        name = request.data.get('name')
        description = request.data.get('description', '')
        
        if not name:
            return Response(
                {'error': '채팅방 이름은 필수입니다.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        chat_room = ChatRoom.objects.create(
            project=project,
            name=name,
            description=description
        )
        
        # 기본 멤버 추가 (프로젝트 소유자)
        chat_room.members.add(request.user)
        
        serializer = ChatRoomSerializer(chat_room)
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    
    @action(detail=True, methods=['get'])
    def chat_rooms(self, request, pk=None):
        """프로젝트의 모든 채팅방 조회"""
        project = self.get_object()
        chat_rooms = project.chat_rooms.all()
        serializer = ChatRoomListSerializer(chat_rooms, many=True)
        return Response(serializer.data)


class ChatRoomViewSet(viewsets.ModelViewSet):
    """채팅방 관리 ViewSet
    
    채팅방의 CRUD 연산과 메시지 관리를 처리합니다.
    """
    permission_classes = [IsAuthenticated]
    serializer_class = ChatRoomSerializer
    
    def get_queryset(self):
        """사용자가 속한 채팅방 반환"""
        return ChatRoom.objects.filter(members=self.request.user)
    
    def get_serializer_class(self):
        """요청에 따라 적절한 Serializer 선택"""
        if self.action == 'list':
            return ChatRoomListSerializer
        return ChatRoomSerializer
    
    @action(detail=True, methods=['post'])
    def add_member(self, request, pk=None):
        """채팅방에 사용자 추가"""
        chat_room = self.get_object()
        user_id = request.data.get('user_id')
        
        if not user_id:
            return Response(
                {'error': '사용자 ID는 필수입니다.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            from accounts.models import User
            user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            return Response(
                {'error': '사용자를 찾을 수 없습니다.'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        chat_room.members.add(user)
        serializer = self.get_serializer(chat_room)
        return Response(serializer.data)
    
    @action(detail=True, methods=['post'])
    def remove_member(self, request, pk=None):
        """채팅방에서 사용자 제거"""
        chat_room = self.get_object()
        user_id = request.data.get('user_id')
        
        if not user_id:
            return Response(
                {'error': '사용자 ID는 필수입니다.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            from accounts.models import User
            user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            return Response(
                {'error': '사용자를 찾을 수 없습니다.'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        chat_room.members.remove(user)
        serializer = self.get_serializer(chat_room)
        return Response(serializer.data)
    
    @action(detail=True, methods=['post'])
    def send_message(self, request, pk=None):
        """채팅방에 메시지 전송"""
        chat_room = self.get_object()
        
        # 사용자가 채팅방 멤버인지 확인
        if not chat_room.members.filter(id=request.user.id).exists():
            return Response(
                {'error': '이 채팅방의 멤버가 아닙니다.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        content = request.data.get('content')
        
        if not content or not content.strip():
            return Response(
                {'error': '메시지 내용은 필수입니다.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        message = Message.objects.create(
            chat_room=chat_room,
            sender=request.user,
            content=content
        )
        
        serializer = MessageSerializer(message)
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    
    @action(detail=True, methods=['get'])
    def messages(self, request, pk=None):
        """채팅방의 메시지 조회"""
        chat_room = self.get_object()
        messages = chat_room.messages.all()
        serializer = MessageSerializer(messages, many=True)
        return Response(serializer.data)


class MessageViewSet(viewsets.ModelViewSet):
    """메시지 관리 ViewSet"""
    permission_classes = [IsAuthenticated]
    serializer_class = MessageSerializer
    
    def get_queryset(self):
        """사용자가 속한 채팅방의 메시지만 조회"""
        return Message.objects.filter(chat_room__members=self.request.user)

