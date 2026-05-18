from flask import Blueprint, request, jsonify
from models import db, Post, User, Club  # Club을 반드시 import

bp = Blueprint('post', __name__)


@bp.route('/posts', methods=['GET'])
def get_posts():
    # 이 함수가 /posts GET 요청(게시글 목록 조회)에 대한 응답을 담당합니다.
    # 실제 게시글 리스트를 내려주는 백엔드 엔드포인트입니다.
    posts = Post.query.order_by(Post.id.desc()).all()
    result = []
    for post in posts:
        # 작성자 프로필 이미지 가져오기
        user = User.query.filter_by(email=post.email).first()
        profile_image = user.profile_image if user and user.profile_image else ''

        # 동아리 정보 가져오기
        club = Club.query.get(getattr(post, 'club_id', None)) if getattr(
            post, 'club_id', None) else None
        club_name = club.name if club else ''
        club_image = club.image if club else ''

        result.append({
            'id': post.id,
            'email': post.email,
            'name': getattr(post, 'name', ''),
            'image': post.image or '',
            'caption': post.caption or '',
            'likes': post.likes,
            'club_id': getattr(post, 'club_id', None),
            'club_name': club_name,  # 동아리 이름 추가
            'club_image': club_image,  # 동아리 이미지 추가
            'profile_image': profile_image,
        })
    return jsonify(result), 200


@bp.route('/posts', methods=['POST'])
def create_post():
    data = request.json or {}
    email = data.get('email')
    name = data.get('name', '')
    image = data.get('image')
    caption = data.get('caption')
    club_id = data.get('club_id')  # 동아리 게시글용

    # club_id가 없으면 업로드 거부
    if not club_id:
        return jsonify({'error': 'club_id는 필수입니다.'}), 400

    post = Post(
        email=email,
        name=name,
        image=image,
        caption=caption,
        club_id=club_id
    )
    db.session.add(post)
    db.session.commit()
    # 게시글 생성 후 바로 최신 게시글 목록 반환 (자동 새로고침 효과)
    posts = Post.query.order_by(Post.id.desc()).all()
    result = []
    for post in posts:
        user = User.query.filter_by(email=post.email).first()
        result.append({
            'id': post.id,
            'email': post.email,
            'name': post.name if hasattr(post, 'name') else (user.name if user else ''),
            'image': post.image or '',
            'caption': post.caption or '',
            'likes': post.likes,
            'profile_image': user.profile_image if user and user.profile_image else '',
            'club_id': post.club_id,  # ← 반드시 포함!
        })
    return jsonify({'message': '게시글 생성 완료', 'id': post.id, 'posts': result}), 201


@bp.route('/posts/<int:post_id>', methods=['DELETE'])
def delete_post(post_id):
    post = Post.query.get(post_id)
    if not post:
        return jsonify({'message': '게시글을 찾을 수 없습니다.'}), 404

    # 권한 체크: 클라이언트에서 email, user_id, role을 body로 보내야 함
    user_email = request.json.get('email') if request.is_json else None
    user_id = request.json.get('user_id') if request.is_json else None
    user_role = request.json.get('role') if request.is_json else None

    club = Club.query.get(post.club_id) if post.club_id else None
    # vice_president_id가 Club 모델에 없으면 getattr로 안전하게 가져오기
    vice_president_id = getattr(
        club, 'vice_president_id', None) if club else None
    is_president = club and user_id and club.president_id == user_id
    is_vice_president = club and user_id and vice_president_id == user_id
    is_author = post.email == user_email
    is_admin = user_role == 'admin'

    if not (is_president or is_vice_president or is_author or is_admin):
        return jsonify({'message': '게시글 삭제 권한이 없습니다.'}), 403

    db.session.delete(post)
    db.session.commit()
    return jsonify({'message': '게시글이 삭제되었습니다.'}), 200
