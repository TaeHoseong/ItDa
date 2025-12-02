from fastapi import APIRouter, Depends, HTTPException
from typing import List

from app.core.dependencies import get_current_user
from app.core.supabase_client import get_supabase
from app.schemas.wishlist import WishlistCreate, WishlistResponse, WishlistCheckRequest
from app.services.wishlist_service import WishlistService

router = APIRouter()


def _get_couple_id(user_id: str) -> str:
    """사용자의 couple_id 조회"""
    supabase = get_supabase()
    response = supabase.table("users") \
        .select("couple_id") \
        .eq("user_id", user_id) \
        .single() \
        .execute()

    if not response.data or not response.data.get("couple_id"):
        raise HTTPException(status_code=400, detail="커플 매칭이 필요합니다")

    return response.data["couple_id"]


@router.get("", response_model=List[WishlistResponse])
async def get_wishlists(current_user: dict = Depends(get_current_user)):
    """커플 찜목록 조회"""
    user_id = current_user["user_id"]
    couple_id = _get_couple_id(user_id)

    wishlists = WishlistService.get_wishlists_by_couple(couple_id)
    return wishlists


@router.post("", response_model=WishlistResponse)
async def add_wishlist(
    data: WishlistCreate,
    current_user: dict = Depends(get_current_user)
):
    """찜 추가"""
    user_id = current_user["user_id"]
    couple_id = _get_couple_id(user_id)

    # 중복 체크
    existing = WishlistService.check_wishlist(couple_id, data.latitude, data.longitude)
    if existing:
        raise HTTPException(status_code=400, detail="이미 찜한 장소입니다")

    result = WishlistService.add_wishlist(couple_id, user_id, data)
    if not result:
        raise HTTPException(status_code=500, detail="찜 추가 실패")

    return result


@router.delete("/{wishlist_id}")
async def delete_wishlist(
    wishlist_id: str,
    current_user: dict = Depends(get_current_user)
):
    """찜 삭제"""
    user_id = current_user["user_id"]
    couple_id = _get_couple_id(user_id)

    success = WishlistService.delete_wishlist(wishlist_id, couple_id)
    if not success:
        raise HTTPException(status_code=404, detail="찜을 찾을 수 없습니다")

    return {"message": "삭제 완료"}


@router.post("/check")
async def check_wishlist(
    data: WishlistCheckRequest,
    current_user: dict = Depends(get_current_user)
):
    """특정 좌표의 찜 여부 확인"""
    user_id = current_user["user_id"]
    couple_id = _get_couple_id(user_id)

    existing = WishlistService.check_wishlist(couple_id, data.latitude, data.longitude)

    return {
        "is_wishlisted": existing is not None,
        "wishlist": existing
    }
