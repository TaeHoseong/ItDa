from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class ScheduleBase(BaseModel):
    """일정 기본 스키마"""
    title: str
    date: datetime
    time: Optional[str] = None
    place_name: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    address: Optional[str] = None


class ScheduleCreate(ScheduleBase):
    """일정 생성 요청 스키마"""
    pass


class ScheduleUpdate(BaseModel):
    """일정 수정 요청 스키마 (모든 필드 optional)"""
    title: Optional[str] = None
    date: Optional[datetime] = None
    time: Optional[str] = None
    place_name: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    address: Optional[str] = None


class ScheduleResponse(ScheduleBase):
    """일정 응답 스키마"""
    id: int
    user_id: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
