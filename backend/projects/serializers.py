"""프로젝트 관련 직렬화(Serializers) 모듈

프로젝트, 채팅방, 메시지 등의 모델 데이터를
JSON 형식으로 변환하기 위한 Serializer들을 정의합니다.
"""

from rest_framework import serializers
from .models import Project, ChatRoom, Message
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
    
    class Meta:
        model = Project
        fields = ['id', 'name', 'description', 'owner', 'chat_rooms', 'created_at', 'updated_at']
        read_only_fields = ['owner', 'created_at', 'updated_at']


class ProjectListSerializer(serializers.ModelSerializer):
    """프로젝트 목록용 직렬화"""
    owner = UserSimpleSerializer(read_only=True)
    chat_room_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Project
        fields = ['id', 'name', 'description', 'owner', 'chat_room_count', 'created_at', 'updated_at']
        read_only_fields = ['owner', 'created_at', 'updated_at']
    
    def get_chat_room_count(self, obj):
        """프로젝트의 채팅방 수 반환"""
        return obj.chat_rooms.count()
