from flask_sqlalchemy import SQLAlchemy
from datetime import datetime, timedelta, timezone
import enum

db = SQLAlchemy()

# 동아리 내 역할을 Enum으로 정의
class ClubRole(enum.Enum):
    회장 = "회장"
    부회장 = "부회장"
    동아리원 = "동아리원"

# 사용자 테이블
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(120), nullable=False)
    name = db.Column(db.String(120), nullable=False)
    profile_image = db.Column(db.Text, nullable=True)
    role = db.Column(db.String(20), default='user')  # ← 관리자/일반회원 구분

# 게시글 테이블
class Post(db.Model):
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    email = db.Column(db.String(120), nullable=False)
    name = db.Column(db.String(120), nullable=False)
    image = db.Column(db.Text, nullable=True)
    caption = db.Column(db.String(300), nullable=True)
    likes = db.Column(db.Integer, default=0)
    club_id = db.Column(db.Integer, db.ForeignKey('club.id', ondelete='CASCADE'), nullable=True)  # ← 이 줄 추가
    # 게시글에 달린 댓글들
    replies = db.relationship('Reply', backref='post', cascade='all, delete-orphan', passive_deletes=True)

# 댓글 테이블
class Reply(db.Model):
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    post_id = db.Column(db.Integer, db.ForeignKey('post.id', ondelete='CASCADE'), nullable=False)
    user = db.Column(db.String(120), nullable=False)
    content = db.Column(db.Text, nullable=False)
    email = db.Column(db.String(120), nullable=True)
    created_at = db.Column(db.DateTime, nullable=False, default=lambda: get_kst_now())

# 동아리 테이블
class Club(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(80))
    description = db.Column(db.String(200))
    member_count = db.Column(db.Integer)
    max_members = db.Column(db.Integer, nullable=True)  # ← 최대 인원수 필드 추가(선택)
    president_id = db.Column(db.Integer)
    image = db.Column(db.Text)  # 이미지 필드명이 'image'일 경우


# 동아리원(동아리-사용자 관계) 테이블
class ClubMember(db.Model):
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    club_id = db.Column(db.Integer, db.ForeignKey('club.id', ondelete='CASCADE'), nullable=False)  # 소속 동아리
    user_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='CASCADE'), nullable=False)  # 사용자
    join_date = db.Column(db.DateTime, nullable=False, server_default=db.func.now())                # 가입일
    role = db.Column(db.Enum(ClubRole), nullable=False, default=ClubRole.동아리원)                  # 역할(회장/부회장/동아리원)

    # 관계 설정
    club = db.relationship('Club', backref=db.backref('members', cascade='all, delete-orphan'))
    user = db.relationship('User', backref=db.backref('club_memberships', cascade='all, delete-orphan'))

# 동아리 채팅 메시지 테이블
class ClubChatMessage(db.Model):
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    club_id = db.Column(db.Integer, db.ForeignKey('club.id', ondelete='CASCADE'), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='CASCADE'), nullable=False)
    content = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, nullable=False, default=lambda: get_kst_now())

    club = db.relationship('Club', backref=db.backref('chat_messages', cascade='all, delete-orphan'))
    user = db.relationship('User', backref=db.backref('club_chat_messages', cascade='all, delete-orphan'))

# 동아리 가입 신청서 테이블
class ClubApply(db.Model):
    __tablename__ = 'club_apply'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    club_id = db.Column(db.Integer, db.ForeignKey('club.id', ondelete='CASCADE'), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='CASCADE'), nullable=False)
    gender = db.Column(db.String(10))
    name = db.Column(db.String(120))
    major = db.Column(db.String(120))
    phone = db.Column(db.String(30))
    intro = db.Column(db.Text)
    message = db.Column(db.Text)  # 기타 메시지
    created_at = db.Column(db.DateTime, default=db.func.now())
    status = db.Column(db.String(20), nullable=False, default='pending')  # pending/approved/rejected

    club = db.relationship('Club', backref=db.backref('apply_requests', cascade='all, delete-orphan'))
    user = db.relationship('User', backref=db.backref('club_apply_requests', cascade='all, delete-orphan'))

# 게시글 좋아요 테이블
class Like(db.Model):
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    post_id = db.Column(db.Integer, db.ForeignKey('post.id', ondelete='CASCADE'), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='CASCADE'), nullable=False)
    created_at = db.Column(db.DateTime, nullable=False, default=lambda: get_kst_now())

    post = db.relationship('Post', backref=db.backref('like_entries', cascade='all, delete-orphan'))
    user = db.relationship('User', backref=db.backref('like_entries', cascade='all, delete-orphan'))

# 알림 테이블
class Notification(db.Model):
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete='CASCADE'), nullable=False)
    title = db.Column(db.String(200), nullable=False)
    body = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, nullable=False, default=lambda: get_kst_now())
    is_read = db.Column(db.Boolean, default=False)

    user = db.relationship('User', backref=db.backref('notifications', cascade='all, delete-orphan'))

# UTC+9 (KST) 타임존 객체 생성
def get_kst_now():
    return datetime.now(timezone(timedelta(hours=9)))

# 아래 코드를 Flask shell이나 main 실행 부분에 임시로 추가
if __name__ == "__main__":
    from app import app  # Flask app 객체 import 필요
    with app.app_context():
        db.drop_all()    # 모든 테이블 삭제
        db.create_all()  # models.py 기준으로 테이블 재생성