from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.core.database import get_db
from app.core.security import get_current_user
from app.schemas.schedule import ScheduleCreate, ScheduleUpdate, ScheduleResponse
from app.services.schedule_service import ScheduleService

router = APIRouter()


@router.post("", response_model=ScheduleResponse, status_code=201)
def create_schedule(
    schedule_data: ScheduleCreate,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """일정 생성 (JWT 인증 필요)"""
    service = ScheduleService(db)
    user_id = current_user["user_id"]

    schedule = service.create(
        user_id=user_id,
        data=schedule_data.dict()
    )
    return schedule


@router.get("", response_model=List[ScheduleResponse])
def get_schedules(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """사용자 전체 일정 조회 (JWT에서 user_id 추출)"""
    service = ScheduleService(db)
    user_id = current_user["user_id"]

    schedules = service.get_by_user(user_id)
    return schedules


@router.get("/{schedule_id}", response_model=ScheduleResponse)
def get_schedule(
    schedule_id: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """특정 일정 조회"""
    service = ScheduleService(db)
    schedule = service.get_by_id(schedule_id)

    if not schedule:
        raise HTTPException(status_code=404, detail="일정을 찾을 수 없습니다")

    # 본인의 일정인지 확인
    if schedule.user_id != current_user["user_id"]:
        raise HTTPException(status_code=403, detail="권한이 없습니다")

    return schedule


@router.put("/{schedule_id}", response_model=ScheduleResponse)
def update_schedule(
    schedule_id: int,
    schedule_data: ScheduleUpdate,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """일정 수정"""
    service = ScheduleService(db)

    # 일정 존재 및 권한 확인
    schedule = service.get_by_id(schedule_id)
    if not schedule:
        raise HTTPException(status_code=404, detail="일정을 찾을 수 없습니다")

    if schedule.user_id != current_user["user_id"]:
        raise HTTPException(status_code=403, detail="권한이 없습니다")

    # 수정
    updated_schedule = service.update(
        schedule_id=schedule_id,
        data=schedule_data.dict(exclude_unset=True)
    )
    return updated_schedule


@router.delete("/{schedule_id}", status_code=204)
def delete_schedule(
    schedule_id: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """일정 삭제"""
    service = ScheduleService(db)

    # 일정 존재 및 권한 확인
    schedule = service.get_by_id(schedule_id)
    if not schedule:
        raise HTTPException(status_code=404, detail="일정을 찾을 수 없습니다")

    if schedule.user_id != current_user["user_id"]:
        raise HTTPException(status_code=403, detail="권한이 없습니다")

    # 삭제
    service.delete(schedule_id)
    return None
