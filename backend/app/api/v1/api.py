from fastapi import APIRouter
from app.api.v1.endpoints import auth, persona, places, users, courses, match, feedback, search, wishlist, user_places, admin

api_router = APIRouter()

# 인증 (Google OAuth)
api_router.include_router(
    auth.router,
    prefix="/auth",
    tags=["auth"]
)

# 사용자 관리
api_router.include_router(
    users.router,
    prefix="/users",
    tags=["users"]
)

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

# 코스 관리
api_router.include_router(
    courses.router,
    prefix="/courses",
    tags=["courses"]
)

# 커플 매칭
api_router.include_router(
    match.router,
    prefix="/match",
    tags=["match"]
)

# 피드백 학습
api_router.include_router(
    feedback.router,
    prefix="/feedback",
    tags=["feedback"]
)

# 검색
api_router.include_router(
    search.router,
    prefix="/search",
    tags=["search"]
)

# 찜목록
api_router.include_router(
    wishlist.router,
    prefix="/wishlist",
    tags=["wishlist"]
)

# 개인 장소
api_router.include_router(
    user_places.router,
    prefix="/user-places",
    tags=["user-places"]
)

# 관리자
api_router.include_router(
    admin.router,
    prefix="/admin",
    tags=["admin"]
)