from flask import Blueprint, request, jsonify
from models import db, Notification
from datetime import datetime

bp = Blueprint('notification', __name__)

# 알림 목록 조회 (user_id로)
@bp.route('/notifications', methods=['GET'])
def get_notifications():
    user_id = request.args.get('user_id', type=int)
    if not user_id:
        return jsonify({'message': 'user_id required'}), 400
    notis = Notification.query.filter_by(user_id=user_id).order_by(Notification.created_at.desc()).all()
    result = []
    for n in notis:
        result.append({
            'id': n.id,
            'title': n.title,
            'body': n.body,
            'created_at': n.created_at.isoformat(),
            'is_read': n.is_read,
        })
    return jsonify(result), 200

# 알림 생성 (테스트용)
@bp.route('/notifications', methods=['POST'])
def create_notification():
    data = request.json or {}
    user_id = data.get('user_id')
    title = data.get('title')
    body = data.get('body')
    if not user_id or not title or not body:
        return jsonify({'message': 'user_id, title, body required'}), 400
    noti = Notification(
        user_id=user_id,
        title=title,
        body=body,
        created_at=datetime.now(),
        is_read=False
    )
    db.session.add(noti)
    db.session.commit()
    return jsonify({'message': '알림이 생성되었습니다.'}), 201

# 알림 읽음 처리
@bp.route('/notifications/<int:noti_id>/read', methods=['POST'])
def read_notification(noti_id):
    noti = Notification.query.get(noti_id)
    if not noti:
        return jsonify({'message': '알림을 찾을 수 없습니다.'}), 404
    noti.is_read = True
    db.session.commit()
    return jsonify({'message': '알림이 읽음 처리되었습니다.'}), 200
