from flask import Blueprint, request, jsonify
from models import db, ClubChatMessage, User, get_kst_now
from datetime import datetime

bp = Blueprint('club_chat', __name__)

# 동아리 채팅 메시지 목록 조회
@bp.route('/api/clubs/<int:club_id>/messages', methods=['GET'])
def get_club_messages(club_id):
    messages = ClubChatMessage.query.filter_by(club_id=club_id).order_by(ClubChatMessage.created_at.asc()).all()
    # 동아리 정보 가져오기
    from models import Club  # 상단에 이미 import 되어 있다면 생략
    club = Club.query.get(club_id)
    club_image = club.image if club else None  # 실제 이미지 필드명 사용

    result = []
    for msg in messages:
        user = User.query.get(msg.user_id)
        result.append({
            'id': msg.id,
            'user_id': msg.user_id,
            'user': user.name if user else '알수없음',
            'user_profile_image': user.profile_image if user and user.profile_image else None,
            'content': msg.content,
            'created_at': msg.created_at.strftime('%Y-%m-%d %H:%M:%S') if msg.created_at else '',
            'club_image': club_image  # 동아리 프로필 이미지(base64)
        })
    return jsonify(result), 200

# 동아리 채팅 메시지 전송
@bp.route('/api/clubs/<int:club_id>/messages', methods=['POST'])
def send_club_message(club_id):
    data = request.json or {}
    content = data.get('content')
    user_id = data.get('user_id', 1)  # 실제 서비스에서는 로그인 사용자 ID를 받아야 함
    if not content:
        return jsonify({'message': '메시지 내용이 필요합니다.'}), 400
    msg = ClubChatMessage(
        club_id=club_id,
        user_id=user_id,
        content=content,
        created_at=get_kst_now()
    )
    db.session.add(msg)
    db.session.commit()
    user = User.query.get(user_id)
    return jsonify({
        'id': msg.id,
        'user_id': msg.user_id,
        'user': user.name if user else '알수없음',
        'user_profile_image': user.profile_image if user and user.profile_image else None,
        'content': msg.content,
        'created_at': msg.created_at.strftime('%Y-%m-%d %H:%M:%S')
    }), 201
