from pydantic import BaseModel
from typing import Optional

class PlaceBase(BaseModel):
    place_id: str
    name: str
    category: Optional[str] = None
    address: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    rating: Optional[float] = None
    price_range: Optional[str] = None
    opening_hours: Optional[str] = None
    reviews: Optional[str] = None

class PlaceResponse(PlaceBase):
    id: int
    
    class Config:
        from_attributes = True

class PlaceUpdate(BaseModel):
    name: Optional[str] = None
    category: Optional[str] = None
    address: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    rating: Optional[float] = None
    price_range: Optional[str] = None
    opening_hours: Optional[str] = None
    reviews: Optional[str] = None