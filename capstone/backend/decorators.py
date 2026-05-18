from flask import request, jsonify
from functools import wraps
from models import User

def roles_required(*allowed_roles):
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            data = request.json or {}
            user_id = data.get('user_id')
            if not user_id:
                return jsonify({'message': 'user_id가 필요합니다.'}), 400
            user = User.query.get(user_id)
            if not user or user.role not in allowed_roles:
                return jsonify({'message': '권한이 부족합니다.'}), 403
            return func(*args, **kwargs)
        return wrapper
    return decorator

president_required = roles_required('회장')
vice_president_required = roles_required('부회장')
student_required = roles_required('학생')
admin_required = roles_required('admin')  # 이 줄을 추가하세요!