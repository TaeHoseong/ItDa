from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from app.services.schedule_service import ScheduleService

router = APIRouter()
schedule_service = ScheduleService()

class ScheduleUpdate(BaseModel):
    title: Optional[str] = None
    date: Optional[str] = None
    time: Optional[str] = None
    description: Optional[str] = None

@router.get("/by-date/{date}")
async def get_schedules_by_date(date: str):
    """특정 날짜의 일정 조회 (YYYY-MM-DD)"""
    schedules = await schedule_service.get_all()
    filtered = [s for s in schedules if s.get("date") == date]

    return {
        "success": True,
        "date": date,
        "count": len(filtered),
        "schedules": filtered
    }

@router.get("/range")
async def get_schedules_by_range(start_date: str, end_date: str):
    """날짜 범위로 일정 조회"""
    schedules = await schedule_service.get_all()
    filtered = [
        s for s in schedules
        if start_date <= s.get("date", "") <= end_date
    ]

    return {
        "success": True,
        "start_date": start_date,
        "end_date": end_date,
        "count": len(filtered),
        "schedules": filtered
    }

@router.patch("/{schedule_id}")
async def update_schedule(schedule_id: str, update: ScheduleUpdate):
    """일정 수정"""
    updates = {k: v for k, v in update.dict().items() if v is not None}

    if not updates:
        raise HTTPException(status_code=400, detail="수정할 내용이 없습니다")

    updated = await schedule_service.update(schedule_id, updates)

    if not updated:
        raise HTTPException(status_code=404, detail="일정을 찾을 수 없습니다")

    return {
        "success": True,
        "message": "일정이 수정되었습니다",
        "schedule": updated
    }