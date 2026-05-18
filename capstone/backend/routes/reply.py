from flask import Blueprint, request, jsonify
from models import db, Post
from datetime import datetime

bp = Blueprint('reply', __name__)

# 댓글 목록 조회
@bp.route('/posts/<int:post_id>/replies', methods=['GET'])
def get_replies(post_id):
    from models import Reply
    replies = Reply.query.filter_by(post_id=post_id).order_by(Reply.created_at.asc()).all()
    result = []
    for reply in replies:
        result.append({
            'id': reply.id,
            'user': reply.user,
            'email': getattr(reply, 'email', None),
            'content': reply.content,
            'created_at': reply.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            'createdAt': reply.created_at.strftime('%Y-%m-%d %H:%M:%S'),  # camelCase도 함께 반환
        })
    return jsonify(result), 200

# 댓글 작성
@bp.route('/posts/<int:post_id>/replies', methods=['POST'])
def create_reply(post_id):
    from models import Reply
    data = request.json or {}
    user = data.get('user')
    email = data.get('email')  # email도 받음
    content = data.get('content')
    # 클라이언트에서 createdAt(ISO8601)로 보낼 경우 파싱, 없으면 현재시간
    created_at_str = data.get('createdAt')
    if created_at_str:
        try:
            created_at = datetime.fromisoformat(created_at_str)
        except Exception:
            created_at = datetime.now()
    else:
        created_at = datetime.now()
    if not user or not content:
        return jsonify({'message': 'user와 content가 필요합니다.'}), 400
    reply = Reply(post_id=post_id, user=user, content=content, email=email, created_at=created_at)  # ← created_at 저장
    db.session.add(reply)
    db.session.commit()
    # 댓글 작성 직후 DB에서 저장된 created_at 값을 사용하여 반환
    return jsonify({
        'message': '댓글이 등록되었습니다.',
        'id': reply.id,
        'user': reply.user,
        'email': reply.email,
        'content': reply.content,
        'created_at': reply.created_at.strftime('%Y-%m-%d %H:%M:%S'),  # DB에 저장된 실제 작성시간 반환
        'createdAt': reply.created_at.strftime('%Y-%m-%d %H:%M:%S'),   # camelCase도 함께 반환
    }), 201

# 댓글 수정
@bp.route('/replies/<int:reply_id>', methods=['PATCH'])
def edit_reply(reply_id):
    from models import Reply
    reply = Reply.query.get(reply_id)
    if not reply:
        return jsonify({'message': '댓글을 찾을 수 없습니다.'}), 404
    data = request.json or {}
    content = data.get('content')
    if not content:
        return jsonify({'message': '수정할 내용이 필요합니다.'}), 400
    reply.content = content
    db.session.commit()
    return jsonify({'message': '댓글이 수정되었습니다.'}), 200

# 댓글 삭제
@bp.route('/replies/<int:reply_id>', methods=['DELETE'])
def delete_reply(reply_id):
    from models import Reply
    reply = Reply.query.get(reply_id)
    if not reply:
        return jsonify({'message': '댓글을 찾을 수 없습니다.'}), 404
    db.session.delete(reply)
    db.session.commit()
    return jsonify({'message': '댓글이 삭제되었습니다.'}), 200