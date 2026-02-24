from sqlalchemy import Column, Integer, ForeignKey, String
from sqlalchemy.orm import relationship
from app.database import Base

class Enrollment(Base):
    __tablename__ = "enrollments"

    id = Column(Integer, primary_key=True, index=True)

    student_id = Column(Integer, ForeignKey("students.id"))
    course_id = Column(Integer, ForeignKey("courses.id"))

    semester = Column(Integer)
    academic_year = Column(String(20))

    student = relationship("Student", back_populates="enrollments")
    course = relationship("Course", back_populates="enrollments")