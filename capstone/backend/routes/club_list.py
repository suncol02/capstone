from flask import Blueprint, jsonify, request
from models import db, Club, ClubMember

bp = Blueprint('club_list', __name__)


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
