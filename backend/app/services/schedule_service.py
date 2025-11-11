from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import Session
from fastapi import HTTPException
from app.models.schedule import Schedule


class ScheduleService:
    """일정 관리 서비스 (SQLAlchemy 기반)"""

    def __init__(self, db: Session):
        self.db = db

    def create(self, user_id: str, data: dict) -> Schedule:
        """일정 생성"""
        schedule = Schedule(
            user_id=user_id,
            title=data["title"],
            date=data["date"] if isinstance(data["date"], datetime) else datetime.fromisoformat(data["date"]),
            time=data.get("time", ""),
            place_name=data.get("place_name"),
            latitude=data.get("latitude"),
            longitude=data.get("longitude"),
            address=data.get("address")
        )
        self.db.add(schedule)
        self.db.commit()
        self.db.refresh(schedule)
        return schedule

    def get_by_user(self, user_id: str) -> List[Schedule]:
        """사용자 전체 일정 조회"""
        return self.db.query(Schedule)\
            .filter(Schedule.user_id == user_id)\
            .order_by(Schedule.date.asc())\
            .all()

    def get_by_id(self, schedule_id: int) -> Optional[Schedule]:
        """특정 일정 조회"""
        return self.db.query(Schedule).filter(Schedule.id == schedule_id).first()

    def get_by_date(self, user_id: str, date: datetime) -> List[Schedule]:
        """특정 날짜 일정 조회"""
        start = date.replace(hour=0, minute=0, second=0, microsecond=0)
        end = date.replace(hour=23, minute=59, second=59, microsecond=999999)
        return self.db.query(Schedule)\
            .filter(Schedule.user_id == user_id)\
            .filter(Schedule.date >= start, Schedule.date <= end)\
            .order_by(Schedule.date.asc())\
            .all()

    def update(self, schedule_id: int, data: dict) -> Schedule:
        """일정 수정"""
        schedule = self.get_by_id(schedule_id)
        if not schedule:
            raise HTTPException(status_code=404, detail="일정을 찾을 수 없습니다")

        # 제공된 필드만 업데이트
        for key, value in data.items():
            if value is not None and hasattr(schedule, key):
                if key == "date" and isinstance(value, str):
                    value = datetime.fromisoformat(value)
                setattr(schedule, key, value)

        self.db.commit()
        self.db.refresh(schedule)
        return schedule

    def delete(self, schedule_id: int) -> bool:
        """일정 삭제"""
        schedule = self.get_by_id(schedule_id)
        if not schedule:
            raise HTTPException(status_code=404, detail="일정을 찾을 수 없습니다")

        self.db.delete(schedule)
        self.db.commit()
        return True
