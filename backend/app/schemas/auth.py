from pydantic import BaseModel, EmailStr, Field
from typing import Dict, Optional


class GoogleLoginRequest(BaseModel):
    """Request schema for Google OAuth login"""
    id_token: str
    client_type: str = "flutter-mobile"


class UserRegisterRequest(BaseModel):
    """Request schema for general user registration with password"""
    email: EmailStr
    password: str = Field(..., min_length=8, description="Password (min 8 characters)")
    name: Optional[str] = None
    nickname: Optional[str] = None
    birthday: Optional[str] = None  # Format: "YYYY-MM-DD"
    gender: Optional[str] = None    # "M" or "F"


class UserLoginRequest(BaseModel):
    """Request schema for general user login with password"""
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    """Response schema for successful authentication"""
    access_token: str
    token_type: str = "bearer"
    user: Dict  # Contains user_id, email, name, survey_done
