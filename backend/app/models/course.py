"""
Course (데이트 코스) 모델
Phase 10.4: Course 기반 CRUD
"""
from sqlalchemy import Column, String, Float, Integer, DateTime, JSON, ForeignKey
from datetime import datetime
from app.core.database import Base


class Course(Base):
    __tablename__ = "courses"

    # Primary Key
    course_id = Column(String, primary_key=True, index=True)  # UUID

    # Foreign Keys
    user_id = Column(String, ForeignKey("users.user_id"), nullable=False, index=True)  # 생성자 (Phase 10.2 호환)
    couple_id = Column(String, nullable=True, index=True)  # 커플 ID (Phase 10.3에서 활용)

    # 코스 기본 정보
    date = Column(String, nullable=False, index=True)  # "YYYY-MM-DD" 형식
    template = Column(String, nullable=False)  # full_day, half_day_lunch, cafe_date 등

    # 코스 상세 정보 (JSON 형태로 저장)
    slots = Column(JSON, nullable=False)  # List[CourseSlot] - 슬롯 리스트

    # 코스 통계
    total_distance = Column(Float, default=0.0, nullable=False)  # 총 이동 거리 (km)
    total_duration = Column(Integer, default=0, nullable=False)  # 총 소요 시간 (분)
    start_time = Column(String, nullable=False)  # "HH:MM" 형식
    end_time = Column(String, nullable=False)  # "HH:MM" 형식

    # Metadata
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
