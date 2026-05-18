import os
from flask import Blueprint, jsonify, request
from werkzeug.utils import secure_filename
from models import db, Club, Post, ClubMember, ClubRole

bp = Blueprint('clubs', __name__)

UPLOAD_FOLDER = 'static/club_images'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@bp.route('/clubs', methods=['GET'])
def get_clubs():
    user_id = request.args.get('user_id', type=int)
    clubs = Club.query.all()
    result = []
    for club in clubs:
        is_joined = False
        if user_id:
            is_joined = ClubMember.query.filter_by(
                club_id=club.id, user_id=user_id).first() is not None

        actual_member_count = ClubMember.query.filter_by(
            club_id=club.id).count()

        result.append({
            'id': club.id,
            'name': club.name,
            'description': club.description,
            'image': club.image,
            'is_joined': is_joined,
            'member_count': actual_member_count,
        })
    return jsonify(result)

@bp.route('/clubs', methods=['POST'])
def create_club():
    # Multipart/form-data 요청 우선 처리
    if 'name' in request.form:
        name = request.form.get('name')
        description = request.form.get('description')
        member_count = request.form.get('member_count')
        president_id = request.form.get('president_id')
        profile_image = None

        # 이미지 파일 처리
        if 'image' in request.files:
            file = request.files['image']
            if file and allowed_file(file.filename):
                filename = secure_filename(file.filename)
                save_path = os.path.join(UPLOAD_FOLDER, filename)
                os.makedirs(UPLOAD_FOLDER, exist_ok=True)
                file.save(save_path)
                profile_image = save_path

        club = Club(
            name=name,
            description=description,
            member_count=1,  # 동아리장 1명으로 시작
            president_id=int(president_id),
            image=profile_image
        )
        db.session.add(club)
        db.session.commit()

        # 동아리장 ClubMember로 자동 등록
        club_member = ClubMember(
            club_id=club.id,
            user_id=int(president_id),
            role=ClubRole.회장
        )
        db.session.add(club_member)
        db.session.commit()

        return jsonify({'result': 'success', 'club_id': club.id}), 201

    # JSON 요청 처리 (이미지 파일이 아니라 문자열로 전달되는 경우)
    if request.is_json:
        data = request.get_json()
        name = data.get('name')
        description = data.get('description')
        member_count = data.get('member_count')
        president_id = data.get('president_id')
        profile_image = data.get('image')  # 문자열(base64 등)로 바로 저장

        club = Club(
            name=name,
            description=description,
            member_count=1,
            president_id=int(president_id),
            image=profile_image
        )
        db.session.add(club)
        db.session.commit()

        club_member = ClubMember(
            club_id=club.id,
            user_id=int(president_id),
            role=ClubRole.회장
        )
        db.session.add(club_member)
        db.session.commit()

        return jsonify({'result': 'success', 'club_id': club.id}), 201

    return jsonify({'error': 'Bad Request'}), 400

@bp.route('/clubs/<int:club_id>', methods=['GET'])
def get_club(club_id):
    club = Club.query.get_or_404(club_id)
    members = ClubMember.query.filter_by(club_id=club_id).all()
    members_data = []
    for member in members:
        from models import User
        user = User.query.get(member.user_id)
        if user:
            members_data.append({
                'user_id': member.user_id,
                'name': user.name,
                'email': user.email,
                'role': member.role.value if member.role else '동아리원',
                'join_date': member.join_date.isoformat() if member.join_date else None
            })

    return jsonify({
        'id': club.id,
        'name': club.name,
        'description': club.description,
        'president_id': club.president_id,
        'vice_president_id': getattr(club, 'vice_president_id', None),
        'max_members': getattr(club, 'max_members', None),
        'image': club.image or '',
        'members': members_data,
        'member_count': len(members_data),
    }), 200

@bp.route('/clubs/<int:club_id>', methods=['PATCH'])
def update_club(club_id):
    club = Club.query.get_or_404(club_id)
    data = request.get_json()
    name = data.get('name')
    description = data.get('description')
    image = data.get('image')

    if name is not None:
        club.name = name
    if description is not None:
        club.description = description
    if image is not None:
        club.image = image
    db.session.commit()
    return jsonify({
        'id': club.id,
        'name': club.name,
        'description': club.description,
        'president_id': club.president_id,
        'vice_president_id': getattr(club, 'vice_president_id', None),
        'image': club.image or '',
    }), 200

@bp.route('/clubs/<int:club_id>/posts', methods=['GET'])
def get_club_posts(club_id):
    posts = Post.query.filter_by(
        club_id=club_id).order_by(Post.id.desc()).all()
    club = Club.query.get(club_id)
    club_name = club.name if club else ''
    club_image = club.image if club else ''
    result = []
    for post in posts:
        result.append({
            'id': post.id,
            'email': post.email,
            'name': getattr(post, 'name', ''),
            'user_id': getattr(post, 'user_id', None),
            'club_name': club_name,
            'club_image': club_image,
            'image': post.image,
            'caption': post.caption,
            'likes': post.likes,
        })
    return jsonify(result), 200

@bp.route('/clubs/<int:club_id>/members/<int:member_id>/role', methods=['PATCH'])
def change_member_role(club_id, member_id):
    from models import ClubMember, ClubRole
    data = request.get_json() or {}
    new_role = data.get('role')
    if new_role not in ['회장', '부회장', '동아리원']:
        return jsonify({'message': '유효하지 않은 역할입니다.'}), 400
    member = ClubMember.query.filter_by(
        club_id=club_id, user_id=member_id).first()
    if not member:
        return jsonify({'message': '멤버를 찾을 수 없습니다.'}), 404
    member.role = getattr(ClubRole, new_role)
    db.session.commit()
    return jsonify({'message': '역할이 변경되었습니다.'}), 200

@bp.route('/clubs/<int:club_id>/members/<int:user_id>', methods=['DELETE'])
def leave_club(club_id, user_id):
    from models import ClubMember
    member = ClubMember.query.filter_by(
        club_id=club_id, user_id=user_id).first()
    if not member:
        return jsonify({'message': '동아리원을 찾을 수 없습니다.'}), 404
    db.session.delete(member)
    db.session.commit()
    return jsonify({'message': '동아리 탈퇴 완료'}), 200

@bp.route('/clubs/<int:club_id>', methods=['DELETE'])
def delete_club(club_id):
    club = Club.query.get(club_id)
    if not club:
        return jsonify({'message': '동아리를 찾을 수 없습니다.'}), 404
    db.session.delete(club)
    db.session.commit()
    return jsonify({'message': '동아리가 삭제되었습니다.'}), 200

