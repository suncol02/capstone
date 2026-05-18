from flask import Blueprint, request, jsonify
from models import db, User

bp = Blueprint('auth', __name__)

@bp.route('/check-email', methods=['POST'])
def check_email():
    data = request.json or {}
    email = data.get('email')
    if not email:
        return jsonify({'message': '이메일이 필요합니다.'}), 400
    exists = User.query.filter_by(email=email).first() is not None
    if exists:
        return jsonify({'message': '이미 존재하는 학번입니다.'}), 409
    return jsonify({'message': '사용 가능한 학번입니다.'}), 200

@bp.route('/register', methods=['POST'])
def register():
    return signup()

@bp.route('/signup', methods=['POST'])
def signup():
    data = request.json or {}
    email = data.get('email')
    password = data.get('password')
    name = data.get('name')
    profile_image = data.get('profile_image')  # base64 문자열로 전달됨

    if not email or not password or not name:
        return jsonify({'message': '필수 입력값 누락'}), 400
    if User.query.filter_by(email=email).first():
        return jsonify({'message': '이미 존재하는 학번입니다.'}), 400

    user = User(email=email, password=password, name=name, profile_image=profile_image)
    db.session.add(user)
    db.session.commit()
    return jsonify({'message': '회원가입 성공', 'name': user.name}), 201

@bp.route('/login', methods=['POST'])
def login():
    data = request.json or {}
    email = data.get('email')
    password = data.get('password')
    user = User.query.filter_by(email=email, password=password).first()
    if user:
        return jsonify({
            'message': '로그인 성공',
            'user_id': user.id,
            'name': user.name,
            'profile_image': user.profile_image
        }), 200
    return jsonify({'message': '이메일 또는 비밀번호가 잘못되었습니다.'}), 401

@bp.route('/update-profile', methods=['POST'])
def update_profile():
    data = request.json or {}
    email = data.get('email')
    name = data.get('name')
    profile_image = data.get('profile_image')
    if not email:
        return jsonify({'message': '이메일이 필요합니다.'}), 400
    user = User.query.filter_by(email=email).first()
    if not user:
        return jsonify({'message': '사용자를 찾을 수 없습니다.'}), 404
    if name:
        user.name = name
    if profile_image is not None:
        user.profile_image = profile_image
    db.session.commit()
    return jsonify({'message': '프로필이 수정되었습니다.', 'name': user.name, 'profile_image': user.profile_image or ''}), 200

