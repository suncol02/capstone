from flask import Flask
from flask_cors import CORS
from models import db
from routes.auth import bp as auth_bp
from routes.post import bp as post_bp
from routes.admin import bp as admin_bp
from routes.like_unlike import bp as post_like_bp
from routes.reply import bp as reply_bp
from routes.club_list import bp as club_list_bp
from routes.club_chat import bp as club_chat_bp
from routes.clubs import bp as clubs_bp
from routes.club_apply import bp as club_apply_bp
from decorators import admin_required
from sqlalchemy import event
from sqlalchemy.engine import Engine
import os


app = Flask(__name__)
CORS(app)
basedir = os.path.abspath(os.path.dirname(__file__))
app.config['SQLALCHEMY_DATABASE_URI'] = f"sqlite:///{os.path.join(basedir, 'db.sqlite')}"
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db.init_app(app)

# 블루프린트 등록
app.register_blueprint(auth_bp)
app.register_blueprint(post_bp)
app.register_blueprint(admin_bp)
app.register_blueprint(post_like_bp)
app.register_blueprint(reply_bp)
app.register_blueprint(club_list_bp)
app.register_blueprint(club_chat_bp)
app.register_blueprint(clubs_bp)
app.register_blueprint(club_apply_bp)

@event.listens_for(Engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()

if __name__ == '__main__':
    with app.app_context():
        db.create_all()   # ← 이 부분에서 DB 파일과 테이블이 생성됩니다!
    app.run(host='0.0.0.0', port=5000, debug=True)
