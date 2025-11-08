from pydantic import BaseModel
from typing import Dict


class GoogleLoginRequest(BaseModel):
    """Request schema for Google OAuth login"""
    id_token: str
    client_type: str = "flutter-mobile"


class TokenResponse(BaseModel):
    """Response schema for successful authentication"""
    access_token: str
    token_type: str = "bearer"
    user: Dict  # Contains user_id, email, name, persona_completed
