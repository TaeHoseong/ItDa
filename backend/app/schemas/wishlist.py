from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class WishlistCreate(BaseModel):
    """찜 추가 요청"""
    place_name: str
    address: Optional[str] = None
    category: Optional[str] = None
    latitude: float
    longitude: float
    memo: Optional[str] = None
    link: Optional[str] = None


class WishlistResponse(BaseModel):
    """찜 응답"""
    id: str
    couple_id: str
    user_id: str
    place_name: str
    address: Optional[str] = None
    category: Optional[str] = None
    latitude: float
    longitude: float
    memo: Optional[str] = None
    link: Optional[str] = None
    created_at: datetime


class WishlistCheckRequest(BaseModel):
    """찜 여부 확인 요청"""
    latitude: float
    longitude: float
