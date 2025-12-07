"""
개인 장소 (User Places) API 엔드포인트
"""
from fastapi import APIRouter, Depends, HTTPException, Response, status
from typing import Optional, List, Union

from app.core.dependencies import get_current_user
from app.schemas.user_place import (
    UserPlaceCreate,
    UserPlaceResponse,
    UserPlaceListResponse
)
from app.services.user_place_service import UserPlaceService

router = APIRouter()


@router.post("", response_model=UserPlaceResponse, responses={204: {"description": "이미 정식 DB에 존재하는 장소"}})
async def add_user_place(
    data: UserPlaceCreate,
    current_user: dict = Depends(get_current_user)
):
    """
    개인 장소 추가

    - 코스에 추가하거나 찜할 때 호출
    - 정식 DB에 이미 있는 장소는 204 No Content 반환
    - 이미 추가한 장소는 기존 데이터 반환
    - 카테고리 기반 기본 features 자동 할당
    """
    service = UserPlaceService()

    try:
        result = service.add_user_place(
            user_id=current_user["user_id"],
            data=data.model_dump()
        )
        # 정식 DB에 있는 장소면 204 No Content
        if result is None:
            return Response(status_code=status.HTTP_204_NO_CONTENT)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("", response_model=UserPlaceListResponse)
async def get_my_places(
    has_features: Optional[bool] = None,
    current_user: dict = Depends(get_current_user)
):
    """
    내 개인 장소 목록 조회

    - has_features=true: features 계산 완료된 것만
    - has_features=false: features 미계산된 것만
    - has_features 생략: 전체
    """
    service = UserPlaceService()

    places = service.get_user_places(
        user_id=current_user["user_id"],
        has_features=has_features
    )

    return {
        "places": places,
        "total": len(places)
    }


@router.get("/{user_place_id}", response_model=UserPlaceResponse)
async def get_user_place(
    user_place_id: str,
    current_user: dict = Depends(get_current_user)
):
    """개인 장소 단건 조회"""
    service = UserPlaceService()

    result = service.get_user_place(
        user_id=current_user["user_id"],
        user_place_id=user_place_id
    )

    if not result:
        raise HTTPException(status_code=404, detail="장소를 찾을 수 없습니다")

    return result


@router.delete("/{user_place_id}")
async def delete_user_place(
    user_place_id: str,
    current_user: dict = Depends(get_current_user)
):
    """개인 장소 삭제"""
    service = UserPlaceService()

    success = service.delete_user_place(
        user_id=current_user["user_id"],
        user_place_id=user_place_id
    )

    if not success:
        raise HTTPException(status_code=404, detail="장소를 찾을 수 없습니다")

    return {"status": "deleted", "user_place_id": user_place_id}
