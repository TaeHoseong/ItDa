"""
Match request schemas (Code-based matching)
"""
from pydantic import BaseModel
from datetime import datetime


class MatchCodeResponse(BaseModel):
    """매칭 코드 생성 응답"""
    match_code: str  # 6자리 랜덤 코드
    expires_at: datetime  # 만료 시간


class MatchConnectRequest(BaseModel):
    """매칭 코드 입력"""
    match_code: str  # 입력한 6자리 코드


class MatchConnectResponse(BaseModel):
    """매칭 성공 응답"""
    couple_id: str
    partner_user_id: str
    partner_name: str
    partner_nickname: str
    created_at: datetime
