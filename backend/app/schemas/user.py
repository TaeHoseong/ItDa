from pydantic import BaseModel, Field
from typing import Optional


class UserPersonaUpdate(BaseModel):
    """Schema for updating user persona (20 dimensions)"""
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


class UserResponse(BaseModel):
    """Schema for user information response"""
    user_id: str
    email: str
    name: Optional[str] = None
    persona_completed: bool

    class Config:
        from_attributes = True  # Pydantic v2 (previously orm_mode = True)
