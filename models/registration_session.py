from sqlalchemy import Column, Integer, Boolean, String
from app.database import Base


class RegistrationSession(Base):
    __tablename__ = "registration_sessions"

    id = Column(Integer, primary_key=True, index=True)
    semester = Column(Integer)
    academic_year = Column(String(20))
    is_open = Column(Boolean, default=False)