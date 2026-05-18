from flask import Blueprint, request, jsonify
from models import db, Like, Post, User

like_unlike_bp = Blueprint('like_unlike', __name__)

@like_unlike_bp.route('/posts/<int:post_id>/like', methods=['POST'])
def like_post(post_id):
    data = request.get_json() or {}
    email = data.get('email')
    if not email:
        return jsonify({'message': '이메일이 필요합니다.'}), 400
    user = User.query.filter_by(email=email).first()
    if not user:
        return jsonify({'message': '유저를 찾을 수 없습니다.'}), 404
    post = Post.query.get(post_id)
    if not post:
        return jsonify({'message': '게시글을 찾을 수 없습니다.'}), 404
    # 이미 좋아요 했는지 확인
    like = Like.query.filter_by(post_id=post_id, user_id=user.id).first()
    if not like:
        like = Like(post_id=post_id, user_id=user.id)
        db.session.add(like)
        post.likes += 1
        db.session.commit()
    # 응답에 isLiked 포함
    return jsonify({'message': '좋아요가 추가되었습니다.', 'likes': post.likes, 'isLiked': True}), 200

@like_unlike_bp.route('/posts/<int:post_id>/unlike', methods=['POST'])
def unlike_post(post_id):
    data = request.get_json() or {}
    email = data.get('email')
    if not email:
        return jsonify({'message': '이메일이 필요합니다.'}), 400
    user = User.query.filter_by(email=email).first()
    if not user:
        return jsonify({'message': '유저를 찾을 수 없습니다.'}), 404
    post = Post.query.get(post_id)
    if not post:
        return jsonify({'message': '게시글을 찾을 수 없습니다.'}), 404
    like = Like.query.filter_by(post_id=post_id, user_id=user.id).first()
    if like:
        db.session.delete(like)
        if post.likes > 0:
            post.likes -= 1
        db.session.commit()
    # 응답에 isLiked 포함
    return jsonify({'message': '좋아요가 취소되었습니다.', 'likes': post.likes, 'isLiked': False}), 200

@like_unlike_bp.route('/posts/<int:post_id>/is_liked')
def is_liked(post_id):
    email = request.args.get('email')
    if not email:
        return jsonify({'error': 'email required'}), 400
    user = User.query.filter_by(email=email).first()
    if not user:
        return jsonify({'isLiked': False})
    like = Like.query.filter_by(post_id=post_id, user_id=user.id).first()
    return jsonify({'isLiked': like is not None})

bp = like_unlike_bp