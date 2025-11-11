from sqlalchemy import Column, String, Integer, Float, DateTime, ForeignKey
from datetime import datetime
from app.core.database import Base


class Schedule(Base):
    __tablename__ = "schedules"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(String, ForeignKey("users.user_id"), nullable=False, index=True)

    # 일정 기본 정보
    title = Column(String, nullable=False)
    date = Column(DateTime, nullable=False, index=True)
    time = Column(String, nullable=True)

    # 장소 정보 (옵션)
    place_name = Column(String, nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    address = Column(String, nullable=True)

    # 메타데이터
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
