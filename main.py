from fastapi import FastAPI
from app.database import engine, Base
from app.models import *
from sqlalchemy import text
from app.routers import auth
app = FastAPI()

Base.metadata.create_all(bind=engine)


@app.get("/")
def health_check():
    return {"status": "API Running"}

@app.get("/test-db")
def test_db():
    try:
        with engine.connect() as connection:
            result = connection.execute(text("SELECT 1"))
            return {"db_status": "connected"}
    except Exception as e:
        return {"db_status": "error", "details": str(e)}
    

app.include_router(auth.router)

@app.get("/")
def root():
    return {"message": "Server is running"}