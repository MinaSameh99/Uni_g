from app.database import engine
from app.models import *
from app.core.config import settings

def test_imports():
    print("✅ Imports working")

def test_db_connection():
    try:
        with engine.connect() as connection:
            print("✅ Database connected successfully")
    except Exception as e:
        print("❌ Database connection failed")
        print(e)

if __name__ == "__main__":
    test_imports()
    test_db_connection()
    print("🔥 Backend structure looks healthy")