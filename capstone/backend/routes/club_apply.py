from flask import Blueprint, request, jsonify
from models import db, ClubApply, User, ClubMember

bp = Blueprint('club_apply', __name__)

# 가입 신청서 제출
@bp.route('/clubs/<int:club_id>/apply', methods=['POST'])
def apply_club(club_id):
    data = request.json or {}
    user_id = data.get('user_id')
    gender = data.get('gender')
    name = data.get('name')
    major = data.get('major')
    phone = data.get('phone')
    intro = data.get('intro')
    if not user_id or not name or not major or not phone or not intro or not gender:
        return jsonify({'message': '모든 항목을 입력해주세요.'}), 400

    apply = ClubApply(
        club_id=club_id,
        user_id=user_id,
        gender=gender,
        name=name,
        major=major,
        phone=phone,
        intro=intro,
        status='pending'
    )
    db.session.add(apply)
    db.session.commit()
    return jsonify({'message': '가입 신청이 제출되었습니다.'}), 201

# 가입 신청 목록 조회 (회장/부회장만)
@bp.route('/clubs/<int:club_id>/apply', methods=['GET'])
def get_applications(club_id):
    applies = ClubApply.query.filter_by(club_id=club_id, status='pending').all()
    result = []
    for a in applies:
        user = User.query.get(a.user_id)
        result.append({
            'id': a.id,
            'user_id': a.user_id,
            'user_name': user.name if user else a.name,
            'user_email': user.email if user else '',
            'gender': a.gender,
            'major': a.major,
            'phone': a.phone,
            'intro': a.intro,
            'created_at': a.created_at.isoformat(),
        })
    return jsonify(result), 200

# 가입 신청 수락 (회장/부회장만)
@bp.route('/clubs/<int:club_id>/apply/<int:apply_id>/accept', methods=['POST'])
def accept_application(club_id, apply_id):
    from models import ClubMember, ClubRole
    apply = ClubApply.query.get(apply_id)
    if not apply or apply.club_id != club_id or apply.status != 'pending':
        return jsonify({'message': '신청서를 찾을 수 없습니다.'}), 404
    # 이미 멤버인지 확인
    exists = ClubMember.query.filter_by(club_id=club_id, user_id=apply.user_id).first()
    if exists:
        return jsonify({'message': '이미 동아리원입니다.'}), 400
    # 멤버로 등록
    member = ClubMember(
        club_id=club_id,
        user_id=apply.user_id,
        role=ClubRole.동아리원
    )
    db.session.add(member)
    apply.status = 'approved'
    db.session.commit()
    return jsonify({'message': '가입 신청이 수락되었습니다.'}), 200

# 가입 신청 거절 (선택)
@bp.route('/clubs/<int:club_id>/apply/<int:apply_id>/reject', methods=['POST'])
def reject_application(club_id, apply_id):
    apply = ClubApply.query.get(apply_id)
    if not apply or apply.club_id != club_id or apply.status != 'pending':
        return jsonify({'message': '신청서를 찾을 수 없습니다.'}), 404
    apply.status = 'rejected'
    db.session.commit()
    return jsonify({'message': '가입 신청이 거절되었습니다.'}), 200

# 특정 유저가 이미 해당 동아리에 신청했는지 상태 반환
@bp.route('/clubs/<int:club_id>/apply/status/<int:user_id>', methods=['GET'])
def get_apply_status(club_id, user_id):
    # 동아리원 여부 우선 체크
    member = ClubMember.query.filter_by(club_id=club_id, user_id=user_id).first()
    if member:
        return jsonify({'applied': True, 'status': 'approved'}), 200
    # 최근 신청 내역 확인
    apply = ClubApply.query.filter_by(club_id=club_id, user_id=user_id).order_by(ClubApply.created_at.desc()).first()
    if not apply:
        return jsonify({'applied': False, 'status': None}), 200
    return jsonify({'applied': True, 'status': apply.status}), 200
