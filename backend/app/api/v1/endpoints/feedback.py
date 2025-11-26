"""
피드백 학습 API 엔드포인트
일기 별점 기반 커플 페르소나 업데이트
"""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from typing import List, Optional
from app.core.dependencies import get_current_user_full
from app.core.supabase_client import get_supabase
from app.services.feedback_service import FeedbackService


router = APIRouter()


class RecalculateResponse(BaseModel):
    """페르소나 재계산 응답"""
    success: bool
    message: str
    diary_count: int
    feedback_count: int
    base_persona: Optional[List[float]] = None
    old_persona: Optional[List[float]] = None
    new_persona: Optional[List[float]] = None


class PersonaDiffResponse(BaseModel):
    """페르소나 차이 조회 응답"""
    base_persona: Optional[List[float]] = None
    current_features: Optional[List[float]] = None
    diff: Optional[List[float]] = None
    changed_dimensions: Optional[List[int]] = None
    error: Optional[str] = None


@router.post("/recalculate", response_model=RecalculateResponse)
async def recalculate_persona(
    current_user = Depends(get_current_user_full)
):
    """
    현재 사용자의 커플 페르소나 재계산

    - user1, user2의 features로 원본 페르소나 계산
    - 모든 일기 별점을 순회하며 누적 적용
    - 일기가 없으면 원본으로 복원

    일기 저장/수정/삭제 후 호출하면 됨
    """
    couple_id = current_user.get("couple_id")

    if not couple_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="커플이 매칭되지 않았습니다"
        )

    service = FeedbackService()
    result = service.recalculate_couple_persona(couple_id)

    if not result["success"]:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=result["message"]
        )

    return RecalculateResponse(**result)


@router.post("/recalculate/{couple_id}", response_model=RecalculateResponse)
async def recalculate_persona_by_couple_id(
    couple_id: str,
    current_user = Depends(get_current_user_full)
):
    """
    특정 커플의 페르소나 재계산 (couple_id 직접 지정)

    주로 디버깅/테스트 용도
    """
    service = FeedbackService()
    result = service.recalculate_couple_persona(couple_id)

    if not result["success"]:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=result["message"]
        )

    return RecalculateResponse(**result)


@router.get("/diff", response_model=PersonaDiffResponse)
async def get_persona_diff(
    current_user = Depends(get_current_user_full)
):
    """
    원본 페르소나와 현재 features의 차이 조회

    - base_persona: user1, user2 features로 계산된 원본
    - current_features: 피드백 적용된 현재 값
    - diff: 각 차원별 차이 (current - base)
    - changed_dimensions: 변화가 있는 차원 인덱스 목록
    """
    couple_id = current_user.get("couple_id")

    if not couple_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="커플이 매칭되지 않았습니다"
        )

    service = FeedbackService()
    result = service.get_persona_diff(couple_id)

    if "error" in result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=result["error"]
        )

    return PersonaDiffResponse(**result)


@router.get("/diff/{couple_id}", response_model=PersonaDiffResponse)
async def get_persona_diff_by_couple_id(
    couple_id: str,
    current_user = Depends(get_current_user_full)
):
    """
    특정 커플의 페르소나 차이 조회 (couple_id 직접 지정)

    주로 디버깅/테스트 용도
    """
    service = FeedbackService()
    result = service.get_persona_diff(couple_id)

    if "error" in result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=result["error"]
        )

    return PersonaDiffResponse(**result)


# ========== 테스트용 엔드포인트 ==========

class TestDiarySlot(BaseModel):
    """테스트용 일기 슬롯"""
    place_name: str
    rating: int  # 1-5


class TestDiaryRequest(BaseModel):
    """테스트용 일기 생성 요청"""
    couple_id: str
    slots: List[TestDiarySlot]


@router.post("/test/create-diary")
async def create_test_diary(
    request: TestDiaryRequest,
    current_user = Depends(get_current_user_full)
):
    """
    테스트용 일기 생성 (디버깅 전용)

    실제 코스 없이 일기만 생성하여 피드백 학습 테스트
    """
    import uuid

    supabase = get_supabase()

    # 테스트용 코스 ID 생성
    course_id = str(uuid.uuid4())

    # 일기 데이터 생성
    diary_json = [
        {"place_name": slot.place_name, "rating": slot.rating}
        for slot in request.slots
    ]

    # diary 테이블에 삽입
    supabase.table("diary").insert({
        "course_id": course_id,
        "couple_id": request.couple_id,
        "template": "test",
        "json": diary_json
    }).execute()

    return {
        "success": True,
        "course_id": course_id,
        "diary_slots": diary_json
    }


@router.delete("/test/delete-diaries/{couple_id}")
async def delete_test_diaries(
    couple_id: str,
    current_user = Depends(get_current_user_full)
):
    """
    테스트용 일기 전체 삭제 (디버깅 전용)
    """
    supabase = get_supabase()
    supabase.table("diary").delete().eq("couple_id", couple_id).execute()

    return {"success": True, "message": f"Deleted all diaries for couple {couple_id}"}
