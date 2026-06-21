# extensions.py
# ============================================================
#  Inisialisasi ekstensi Flask secara terpusat.
#  File ini mencegah circular import antara app.py dan model.
# ============================================================

from flask_sqlalchemy import SQLAlchemy
from flask_bcrypt     import Bcrypt
from flask_jwt_extended import JWTManager

# Instance ekstensi dibuat tanpa mengikat ke app terlebih dahulu.
# Pengikatan dilakukan di app.py melalui fungsi init_app().
db     = SQLAlchemy()
bcrypt = Bcrypt()
jwt    = JWTManager()
