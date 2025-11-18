from fastapi import APIRouter, HTTPException, Depends
from typing import Dict
from sqlalchemy.orm import Session
from app.schemas.persona import ChatRequest, ChatResponse
from app.services.persona_service import PersonaService

router = APIRouter()

# 세션 저장소
sessions: Dict[str, dict] = {}

@router.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """페르소나 챗봇 대화"""
    try:
        service = PersonaService(sessions)
        return await service.process_message(request)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/sessions/{session_id}")
async def clear_session(session_id: str):
    """세션 초기화"""
    if session_id in sessions:
        sessions.pop(session_id)
    return {"message": "세션 초기화 완료"}

@router.get("/sessions/{session_id}")
async def get_session(session_id: str):
    """세션 정보 조회"""
    if session_id not in sessions:
        raise HTTPException(status_code=404, detail="세션을 찾을 수 없습니다")
    return {
        "session_id": session_id,
        "history_count": len(sessions[session_id].get("history", [])),
        "pending_data": sessions[session_id].get("pending_data", {})
    }