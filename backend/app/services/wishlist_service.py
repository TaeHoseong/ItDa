from typing import List, Optional
from app.core.supabase_client import get_supabase
from app.schemas.wishlist import WishlistCreate, WishlistResponse


class WishlistService:
    """찜목록 서비스"""

    @staticmethod
    def get_wishlists_by_couple(couple_id: str) -> List[dict]:
        """커플의 찜목록 조회"""
        supabase = get_supabase()
        response = supabase.table("wishlists") \
            .select("*") \
            .eq("couple_id", couple_id) \
            .order("created_at", desc=True) \
            .execute()
        return response.data

    @staticmethod
    def add_wishlist(couple_id: str, user_id: str, data: WishlistCreate) -> dict:
        """찜 추가"""
        supabase = get_supabase()
        insert_data = {
            "couple_id": couple_id,
            "user_id": user_id,
            "place_name": data.place_name,
            "address": data.address,
            "category": data.category,
            "latitude": data.latitude,
            "longitude": data.longitude,
            "memo": data.memo,
            "link": data.link,
        }
        response = supabase.table("wishlists").insert(insert_data).execute()
        return response.data[0] if response.data else None

    @staticmethod
    def delete_wishlist(wishlist_id: str, couple_id: str) -> bool:
        """찜 삭제 (couple_id 검증 포함)"""
        supabase = get_supabase()
        response = supabase.table("wishlists") \
            .delete() \
            .eq("id", wishlist_id) \
            .eq("couple_id", couple_id) \
            .execute()
        return len(response.data) > 0

    @staticmethod
    def check_wishlist(couple_id: str, latitude: float, longitude: float) -> Optional[dict]:
        """특정 좌표의 찜 여부 확인 (오차 범위 0.0001도 ≈ 11m)"""
        supabase = get_supabase()
        tolerance = 0.0001

        response = supabase.table("wishlists") \
            .select("*") \
            .eq("couple_id", couple_id) \
            .gte("latitude", latitude - tolerance) \
            .lte("latitude", latitude + tolerance) \
            .gte("longitude", longitude - tolerance) \
            .lte("longitude", longitude + tolerance) \
            .execute()

        return response.data[0] if response.data else None
