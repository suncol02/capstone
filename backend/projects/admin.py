from django.contrib import admin
from .models import Project, ChatRoom, Message, Recruitment, Archive, ProjectEvaluation


@admin.register(Project)
class ProjectAdmin(admin.ModelAdmin):
    """프로젝트 관리 어드민"""
    list_display = ['title', 'category', 'owner', 'status', 'created_at']
    list_filter = ['category', 'status', 'created_at']
    search_fields = ['title', 'description']
    readonly_fields = ['created_at', 'updated_at']


@admin.register(ChatRoom)
class ChatRoomAdmin(admin.ModelAdmin):
    """채팅방 관리 어드민"""
    list_display = ['name', 'project', 'type', 'created_at', 'member_count']
    list_filter = ['project', 'type', 'created_at']
    search_fields = ['name', 'description']
    readonly_fields = ['created_at', 'updated_at']
    filter_horizontal = ['members']
    
    def member_count(self, obj):
        """멤버 수 표시"""
        return obj.members.count()
    member_count.short_description = '멤버 수'


@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    """메시지 관리 어드민"""
    list_display = ['sender', 'chat_room', 'content_preview', 'created_at']
    list_filter = ['chat_room', 'created_at', 'sender']
    search_fields = ['content', 'sender__username']
    readonly_fields = ['created_at']
    
    def content_preview(self, obj):
        """메시지 내용 미리보기"""
        return obj.content[:50] + ('...' if len(obj.content) > 50 else '')
    content_preview.short_description = '내용'


@admin.register(Recruitment)
class RecruitmentAdmin(admin.ModelAdmin):
    """모집 공고 관리 어드민"""
    list_display = ['project', 'role', 'status', 'created_at']
    list_filter = ['project', 'status']
    search_fields = ['role', 'requirements', 'project__title']
    readonly_fields = ['created_at']
    
    def created_at(self, obj):
        """생성 시간 표시"""
        return obj.project.created_at
    created_at.short_description = '생성일'


@admin.register(Archive)
class ArchiveAdmin(admin.ModelAdmin):
    """아카이브 관리 어드민"""
    list_display = ['user', 'project', 'role', 'result', 'archived_at']
    list_filter = ['result', 'archived_at']
    search_fields = ['user__email', 'project__title', 'role']
    readonly_fields = ['archived_at']


@admin.register(ProjectEvaluation)
class ProjectEvaluationAdmin(admin.ModelAdmin):
    """프로젝트 평가 관리 어드민"""
    list_display = ['user', 'project', 'score', 'submitted_at', 'updated_at']
    list_filter = ['submitted_at', 'updated_at', 'score']
    search_fields = ['user__email', 'project__title', 'feedback']
    readonly_fields = ['submitted_at', 'updated_at']
