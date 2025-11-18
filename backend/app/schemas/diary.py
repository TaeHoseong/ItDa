"""
데이트 일기 관련 Pydantic 스키마
"""
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime


class DiaryPage(BaseModel):
    """일기 페이지 (코스의 각 슬롯에 대응)"""
    slot_index: int  # 코스 슬롯 인덱스 (0부터 시작)
    slot_type: str  # 슬롯 타입 (lunch, cafe, activity, etc.)
    place_name: str  # 장소 이름

    # 일기 내용
    content: Optional[str] = None  # 자유 텍스트
    rating: Optional[int] = None  # 1-5 별점
    photos: Optional[List[str]] = None  # 사진 URL 리스트
    visited_at: Optional[datetime] = None  # 실제 방문 시각

    # 감정/태그
    mood: Optional[str] = None  # happy, romantic, calm, exciting, etc.
    tags: Optional[List[str]] = None  # ["맛있었어요", "분위기좋음", "재방문의사있음"]


class DiaryEntry(BaseModel):
    """데이트 코스 일기"""
    entry_id: str  # UUID
    course_id: str  # 연결된 코스 ID
    couple_id: str  # 커플 ID (두 user가 공유)

    # 일기 메타데이터
    title: Optional[str] = None  # 일기 제목 (예: "송도 데이트")
    date: str  # 데이트 날짜 (YYYY-MM-DD)
    overall_rating: Optional[int] = None  # 전체 평점 1-5

    # 일기 페이지들 (각 슬롯에 대응)
    pages: List[DiaryPage]

    # 전체 일기 메모
    summary: Optional[str] = None  # 전체 데이트 요약

    # 타임스탬프
    created_at: datetime
    updated_at: datetime

    class Config:
        json_schema_extra = {
            "example": {
                "entry_id": "660e8400-e29b-41d4-a716-446655440000",
                "course_id": "550e8400-e29b-41d4-a716-446655440000",
                "couple_id": "couple_abc123",
                "title": "송도 데이트",
                "date": "2025-11-20",
                "overall_rating": 5,
                "pages": [
                    {
                        "slot_index": 0,
                        "slot_type": "lunch",
                        "place_name": "파스타 레스토랑",
                        "content": "파스타가 정말 맛있었어요!",
                        "rating": 5,
                        "photos": ["https://example.com/photo1.jpg"],
                        "visited_at": "2025-11-20T12:30:00",
                        "mood": "happy",
                        "tags": ["맛있었어요", "분위기좋음"]
                    },
                    {
                        "slot_index": 1,
                        "slot_type": "cafe",
                        "place_name": "스타벅스",
                        "content": "커피 마시며 대화 나눴어요",
                        "rating": 4,
                        "photos": [],
                        "visited_at": "2025-11-20T14:00:00",
                        "mood": "romantic",
                        "tags": ["분위기좋음"]
                    }
                ],
                "summary": "정말 좋은 하루였어요!",
                "created_at": "2025-11-20T20:00:00",
                "updated_at": "2025-11-20T20:30:00"
            }
        }


class DiaryCreate(BaseModel):
    """일기 생성 요청"""
    course_id: str
    title: Optional[str] = None
    overall_rating: Optional[int] = None
    pages: List[DiaryPage] = []
    summary: Optional[str] = None


class DiaryUpdate(BaseModel):
    """일기 수정 요청"""
    title: Optional[str] = None
    overall_rating: Optional[int] = None
    pages: Optional[List[DiaryPage]] = None
    summary: Optional[str] = None


class DiaryResponse(BaseModel):
    """일기 응답"""
    entry_id: str
    course_id: str
    couple_id: str
    title: Optional[str]
    date: str
    overall_rating: Optional[int]
    pages: List[DiaryPage]
    summary: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
