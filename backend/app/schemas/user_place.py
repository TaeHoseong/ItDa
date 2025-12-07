"""
개인 장소 (User Places) 스키마
"""
from pydantic import BaseModel, field_validator
from typing import Optional, List, Literal
from datetime import datetime


class UserPlaceCreate(BaseModel):
    """개인 장소 생성 요청"""
    name: str
    address: Optional[str] = None
    category: Optional[str] = None
    latitude: float
    longitude: float
    naver_data: Optional[dict] = None
    added_from: Literal['course', 'wishlist']


class UserPlaceResponse(BaseModel):
    """개인 장소 응답"""
    user_place_id: str
    place_hash: str
    name: str
    address: Optional[str] = None
    category: Optional[str] = None
    latitude: float
    longitude: float
    features: Optional[dict] = None
    features_status: str
    added_from: str
    created_at: datetime

    class Config:
        from_attributes = True


class UserPlaceListResponse(BaseModel):
    """개인 장소 목록 응답"""
    places: List[UserPlaceResponse]
    total: int
