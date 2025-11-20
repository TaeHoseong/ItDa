from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class UserCreate(BaseModel):
    """Schema for user registration (used internally by service layer)"""
    email: str
    name: Optional[str] = None
    nickname: Optional[str] = None
    birthday: Optional[str] = None  # YYYY-MM-DD format
    gender: Optional[str] = None    # "M" or "F"
    picture: Optional[str] = None   # Profile picture URL from OAuth

    class Config:
        json_schema_extra = {
            "example": {
                "email": "user@example.com",
                "name": "홍길동",
                "nickname": "gildong",
                "birthday": "1990-01-01",
                "gender": "M",
                "picture": "https://example.com/photo.jpg"
            }
        }


class UserBase(BaseModel):
    """Base user schema with all fields"""
    user_id: str
    email: str
    name: Optional[str] = None
    picture: Optional[str] = None
    nickname: Optional[str] = None
    birthday: Optional[str] = None
    gender: Optional[str] = None
    couple_id: Optional[str] = None
    survey_done: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class UserResponse(BaseModel):
    """Schema for user information response"""
    user_id: str
    email: str
    name: Optional[str] = None
    picture: Optional[str] = None
    nickname: Optional[str] = None
    birthday: Optional[str] = None
    gender: Optional[str] = None
    couple_id: Optional[str] = None
    survey_done: bool

    class Config:
        from_attributes = True  # Pydantic v2 (previously orm_mode = True)


class SurveyUpdate(BaseModel):
    """Schema for survey submission/re-submission (updates persona fields - 20 dimensions)"""
    # Main Category (6 dimensions)
    food_cafe: float = Field(ge=0.0, le=1.0)
    culture_art: float = Field(ge=0.0, le=1.0)
    activity_sports: float = Field(ge=0.0, le=1.0)
    nature_healing: float = Field(ge=0.0, le=1.0)
    craft_experience: float = Field(ge=0.0, le=1.0)
    shopping: float = Field(ge=0.0, le=1.0)

    # Atmosphere (6 dimensions)
    quiet: float = Field(ge=0.0, le=1.0)
    romantic: float = Field(ge=0.0, le=1.0)
    trendy: float = Field(ge=0.0, le=1.0)
    private_vibe: float = Field(ge=0.0, le=1.0)
    artistic: float = Field(ge=0.0, le=1.0)
    energetic: float = Field(ge=0.0, le=1.0)

    # Experience Type (4 dimensions)
    passive_enjoyment: float = Field(ge=0.0, le=1.0)
    active_participation: float = Field(ge=0.0, le=1.0)
    social_bonding: float = Field(ge=0.0, le=1.0)
    relaxation_focused: float = Field(ge=0.0, le=1.0)

    # Space Characteristics (4 dimensions)
    indoor_ratio: float = Field(ge=0.0, le=1.0)
    crowdedness_expected: float = Field(ge=0.0, le=1.0)
    photo_worthiness: float = Field(ge=0.0, le=1.0)
    scenic_view: float = Field(ge=0.0, le=1.0)
