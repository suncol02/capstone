"""프로젝트 관련 직렬화(Serializers) 모듈

프로젝트, 채팅방, 메시지 등의 모델 데이터를
JSON 형식으로 변환하기 위한 Serializer들을 정의합니다.
"""

from rest_framework import serializers
from .models import Project, ChatRoom, Message, Archive, Application
from accounts.models import User


class UserSimpleSerializer(serializers.ModelSerializer):
    """사용자 간단 정보 직렬화"""
    
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name']


class MessageSerializer(serializers.ModelSerializer):
    """메시지 직렬화"""
    sender = UserSimpleSerializer(read_only=True)
    
    class Meta:
        model = Message
        fields = ['id', 'chat_room', 'sender', 'content', 'created_at']
        read_only_fields = ['sender', 'created_at']


class ChatRoomSerializer(serializers.ModelSerializer):
    """채팅방 직렬화"""
    members = UserSimpleSerializer(many=True, read_only=True)
    messages = MessageSerializer(many=True, read_only=True)
    member_count = serializers.SerializerMethodField()
    
    class Meta:
        model = ChatRoom
        fields = [
            'id', 'project', 'name', 'description', 
            'members', 'member_count', 'messages', 
            'created_at', 'updated_at'
        ]
        read_only_fields = ['created_at', 'updated_at']
    
    def get_member_count(self, obj):
        """채팅방 멤버 수 반환"""
        return obj.members.count()


class ChatRoomListSerializer(serializers.ModelSerializer):
    """채팅방 목록용 직렬화 (메시지 제외)"""
    members = UserSimpleSerializer(many=True, read_only=True)
    member_count = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()
    
    class Meta:
        model = ChatRoom
        fields = [
            'id', 'project', 'name', 'description',
            'members', 'member_count', 'last_message',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['created_at', 'updated_at']
    
    def get_member_count(self, obj):
        """채팅방 멤버 수 반환"""
        return obj.members.count()
    
    def get_last_message(self, obj):
        """마지막 메시지 정보 반환"""
        last_message = obj.messages.last()
        if last_message:
            return {
                'content': last_message.content,
                'sender': last_message.sender.username,
                'created_at': last_message.created_at
            }
        return None


class ProjectSerializer(serializers.ModelSerializer):
    """프로젝트 직렬화"""
    owner = UserSimpleSerializer(read_only=True)
    chat_rooms = ChatRoomListSerializer(many=True, read_only=True)
    name = serializers.CharField(source='title', read_only=True)  # title을 name으로 매핑
    requirements_list = serializers.SerializerMethodField()
    
    class Meta:
        model = Project
        fields = [
            'id', 'title', 'name', 'description', 'category', 'owner', 
            'status', 'recruit_count', 'requirements', 'requirements_list',
            'chat_rooms', 'created_at', 'updated_at'
        ]
        read_only_fields = ['owner', 'created_at', 'updated_at']
    
    def get_requirements_list(self, obj):
        """요구사항을 리스트로 반환"""
        if obj.requirements:
            return [req.strip() for req in obj.requirements.split(',')]
        return []


class ProjectListSerializer(serializers.ModelSerializer):
    """프로젝트 목록용 직렬화"""
    owner = UserSimpleSerializer(read_only=True)
    chat_room_count = serializers.SerializerMethodField()
    name = serializers.CharField(source='title', read_only=True)  # title을 name으로 매핑
    requirements_list = serializers.SerializerMethodField()
    
    class Meta:
        model = Project
        fields = [
            'id', 'title', 'name', 'description', 'category', 'owner', 
            'status', 'recruit_count', 'requirements', 'requirements_list',
            'chat_room_count', 'created_at', 'updated_at'
        ]
        read_only_fields = ['owner', 'created_at', 'updated_at']
    
    def get_chat_room_count(self, obj):
        """채팅방 수 반환"""
        return obj.chat_rooms.count()
    
    def get_requirements_list(self, obj):
        """요구사항을 리스트로 반환"""
        if obj.requirements:
            return [req.strip() for req in obj.requirements.split(',')]
        return []


class ProjectCreateSerializer(serializers.ModelSerializer):
    """프로젝트 생성용 직렬화
    
    Flutter 클라이언트에서 'name'으로 받은 데이터를 'title'로 변환합니다.
    """
    name = serializers.CharField(write_only=True, required=True)  # name으로 입력받음
    requirements = serializers.ListField(
        child=serializers.CharField(),
        write_only=True,
        required=False
    )
    
    class Meta:
        model = Project
        fields = [
            'name', 'description', 'category', 'recruit_count', 'requirements'
        ]
    
    def create(self, validated_data):
        """프로젝트 생성"""
        name = validated_data.pop('name')
        requirements_list = validated_data.pop('requirements', [])
        
        # requirements 리스트를 쉼표로 구분된 문자열로 변환
        requirements_str = ', '.join(requirements_list) if requirements_list else ''
        
        project = Project.objects.create(
            title=name,
            requirements=requirements_str,
            **validated_data
        )
        return project


class ArchiveSerializer(serializers.ModelSerializer):
    """아카이브 항목 직렬화"""
    user = UserSimpleSerializer(read_only=True)
    project_detail = ProjectSerializer(source='project', read_only=True)

    class Meta:
        model = Archive
        fields = ['id', 'user', 'project', 'project_detail', 'role', 'result', 'archived_at']
        read_only_fields = ['user', 'archived_at']


class ApplicationSerializer(serializers.ModelSerializer):
    """프로젝트 신청 항목 직렬화"""
    user = UserSimpleSerializer(read_only=True)
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    username = serializers.CharField(source='user.username', read_only=True)
    name = serializers.SerializerMethodField()
    email = serializers.EmailField(source='user.email', read_only=True)

    class Meta:
        model = Application
        fields = [
            'id', 'user', 'user_id', 'username', 'name', 'email',
            'project', 'status', 'created_at'
        ]
        read_only_fields = ['user', 'created_at']

    def get_name(self, obj):
        full_name = obj.user.get_full_name()
        return full_name or obj.user.username or obj.user.email
