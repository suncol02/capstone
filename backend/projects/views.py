"""프로젝트 관련 뷰(API 엔드포인트) 모듈

프로젝트 생성, 조회, 수정, 삭제 및 채팅방, 메시지
관리 관련 API 엔드포인트를 정의합니다.
"""

from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from django.shortcuts import get_object_or_404
from django.db.models import Q

from .models import Project, ChatRoom, Message, Application, Archive
from .serializers import (
    ProjectSerializer, ProjectListSerializer, ProjectCreateSerializer,
    ChatRoomSerializer, ChatRoomListSerializer,
    MessageSerializer, ArchiveSerializer, ApplicationSerializer
)


class ProjectViewSet(viewsets.ModelViewSet):
    """프로젝트 관리 ViewSet
    
    프로젝트의 CRUD 연산과 채팅방 관리를 처리합니다.
    """
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        """사용자가 생성한 프로젝트 또는 모든 프로젝트 반환
        
        'my' 파라미터가 있으면 사용자가 생성한 프로젝트만 반환
        """
        if self.request.query_params.get('my') == 'true':
            return Project.objects.filter(owner=self.request.user).order_by('-created_at')
        return Project.objects.all().order_by('-created_at')
    
    def get_serializer_class(self):
        """요청에 따라 적절한 Serializer 선택"""
        if self.action == 'list':
            return ProjectListSerializer
        elif self.action == 'create':
            return ProjectCreateSerializer
        return ProjectSerializer
    
    def perform_create(self, serializer):
        """프로젝트 생성시 현재 사용자를 owner로 설정"""
        serializer.save(owner=self.request.user)
    
    @action(detail=False, methods=['get'])
    def by_category(self, request):
        """카테고리별로 프로젝트 조회
        
        쿼리 파라미터: category (팀플, 대외활동)
        """
        category = request.query_params.get('category')
        
        if not category:
            return Response(
                {'error': 'category 파라미터는 필수입니다.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        projects = Project.objects.filter(
            category=category
        ).order_by('-created_at')
        
        serializer = self.get_serializer(projects, many=True)
        return Response(serializer.data)
    
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

    @action(detail=True, methods=['post'])
    def apply(self, request, pk=None):
        """프로젝트 신청 처리

        중복 신청을 방지하고 새로운 Application 레코드를 생성합니다.
        """
        project = self.get_object()
        user = request.user

        # 이미 신청했는지 확인
        if Application.objects.filter(user=user, project=project).exists():
            return Response(
                {'error': '이미 신청한 프로젝트입니다.'},
                status=status.HTTP_409_CONFLICT,
            )

        Application.objects.create(user=user, project=project)
        return Response({'message': '신청이 완료되었습니다.'}, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def join(self, request, pk=None):
        """구식 클라이언트용 대체 엔드포인트 (apply 대체)

        `apply` 엔드포인트가 없을 때 클라이언트가 `join`을 호출하므로
        동일한 동작을 수행하도록 합니다.
        """
        return self.apply(request, pk)

    @action(detail=True, methods=['get'], url_path='applicants')
    def applicants(self, request, pk=None):
        """해당 프로젝트에 신청한 사용자 목록 조회 (소유자만)"""
        project = self.get_object()

        if project.owner != request.user:
            return Response({'error': '권한이 없습니다.'}, status=status.HTTP_403_FORBIDDEN)

        apps = Application.objects.filter(project=project).select_related('user')
        serializer = ApplicationSerializer(apps, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'], url_path=r'applicants/(?P<user_id>[^/.]+)/approve')
    def approve_applicant(self, request, pk=None, user_id=None):
        """특정 신청자 수락"""
        project = self.get_object()

        if project.owner != request.user:
            return Response({'error': '권한이 없습니다.'}, status=status.HTTP_403_FORBIDDEN)

        try:
            app = Application.objects.get(project=project, user__id=user_id)
        except Application.DoesNotExist:
            return Response({'error': '신청자를 찾을 수 없습니다.'}, status=status.HTTP_404_NOT_FOUND)

        app.status = 'accepted'
        app.save()

        chat_rooms = project.chat_rooms.all()
        for chat_room in chat_rooms:
            chat_room.members.add(app.user)

        return Response(
            {
                'message': '신청자를 수락했습니다.',
                'added_chat_rooms': chat_rooms.count(),
            },
            status=status.HTTP_200_OK,
        )

    @action(detail=True, methods=['post'], url_path=r'applicants/(?P<user_id>[^/.]+)/reject')
    def reject_applicant(self, request, pk=None, user_id=None):
        """특정 신청자 거절"""
        project = self.get_object()

        if project.owner != request.user:
            return Response({'error': '권한이 없습니다.'}, status=status.HTTP_403_FORBIDDEN)

        try:
            app = Application.objects.get(project=project, user__id=user_id)
        except Application.DoesNotExist:
            return Response({'error': '신청자를 찾을 수 없습니다.'}, status=status.HTTP_404_NOT_FOUND)

        app.status = 'rejected'
        app.save()

        return Response({'message': '신청자를 거절했습니다.'}, status=status.HTTP_200_OK)

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


class ArchiveViewSet(viewsets.ModelViewSet):
    """아카이브 항목 관리 ViewSet

    사용자는 자신의 아카이브 항목만 조회/생성/삭제할 수 있습니다.
    """
    permission_classes = [IsAuthenticated]
    serializer_class = ArchiveSerializer

    def get_queryset(self):
        return Archive.objects.filter(user=self.request.user).order_by('-archived_at')

    def perform_create(self, serializer):
        # 요청의 user는 현재 로그인 사용자로 설정
        serializer.save(user=self.request.user)
