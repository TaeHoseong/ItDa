from fastapi import APIRouter
from app.api.v1.endpoints import persona, places, schedules

api_router = APIRouter()

# 페르소나 챗봇
api_router.include_router(
    persona.router,
    prefix="/persona",
    tags=["persona"]
)

# 맵/장소 관리
api_router.include_router(
    places.router,
    prefix="/places",
    tags=["places"]
)

#일정 관리/수정
api_router.include_router(
    schedules.router,
    prefix="/schedules",
    tags=["schedules"]
)