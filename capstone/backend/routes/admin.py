from flask import Blueprint, request, jsonify
from models import db, User
from decorators import admin_required

bp = Blueprint('admin', __name__)

# 모든 사용자 목록 조회 (관리자만)
@bp.route('/admin/users', methods=['GET'])
@admin_required
def get_users():
    users = User.query.all()
    result = []
    for user in users:
        result.append({
            'id': user.id,
            'email': user.email,
            'name': user.name,
            'role': user.role
        })
    return jsonify(result), 200

# 사용자 권한 변경 (관리자만)
@bp.route('/admin/users/<int:user_id>/role', methods=['PUT'])
@admin_required
def change_user_role(user_id):
    data = request.json or {}
    new_role = data.get('role')
    if not new_role:
        return jsonify({'message': 'role 값이 필요합니다.'}), 400
    user = User.query.get(user_id)
    if not user:
        return jsonify({'message': '사용자를 찾을 수 없습니다.'}), 404
    user.role = new_role
    db.session.commit()
    return jsonify({'message': '권한이 변경되었습니다.'}), 200