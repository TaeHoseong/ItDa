"""
데이트 코스 관련 Pydantic 스키마
"""
from pydantic import BaseModel, Field
from typing import List, Optional, Dict
from datetime import datetime, time


class SlotConfig(BaseModel):
    """슬롯 설정"""
    slot_type: str  # lunch, cafe, activity, dinner, night_view
    category: str  # food_cafe, activity_sports, culture_art, etc.
    start_time: str  # "12:00"
    duration: int  # 분 단위 (90분)
    emoji: str  # "🍽️"


class CourseSlot(BaseModel):
    """코스 슬롯 (추천된 장소 포함)"""
    slot_type: str
    category: str
    start_time: str
    duration: int
    emoji: str

    # 추천된 장소 정보
    place_name: str
    place_address: Optional[str] = None
    latitude: float
    longitude: float
    rating: Optional[float] = None
    price_range: Optional[str] = None  # DB에서 문자열로 저장됨 (예: "₩1 ~ ₩10000")
    score: float  # 추천 점수

    # 거리 정보
    distance_from_previous: Optional[float] = None  # 이전 장소로부터 거리 (km)


class CoursePreferences(BaseModel):
    """코스 생성 사용자 설정"""
    start_time: Optional[str] = "12:00"  # 시작 시간
    duration: Optional[int] = None  # 총 시간 (분), None이면 템플릿 기본값
    must_include: Optional[List[str]] = None  # 반드시 포함할 슬롯 타입 ["lunch", "cafe"]
    exclude: Optional[List[str]] = None  # 제외할 슬롯 타입 ["activity"]
    max_distance: Optional[float] = 5.0  # 최대 이동 거리 (km)


class CourseGenerateRequest(BaseModel):
    """코스 생성 요청"""
    date: str  # "2025-11-20"
    template: str = "auto"  # auto, full_day, half_day_lunch, half_day_dinner, cafe_date, active_date, culture_date
    preferences: Optional[CoursePreferences] = None


class DateCourse(BaseModel):
    """생성된 데이트 코스"""
    course_id: Optional[str] = None  # DB 저장 시 UUID, 세션 임시 코스는 None
    couple_id: Optional[str] = None  # 커플 ID (DB 저장 시 필수)
    date: str
    template: str
    slots: List[CourseSlot]
    total_distance: float  # 총 이동 거리 (km)
    total_duration: int  # 총 소요 시간 (분)
    start_time: str
    end_time: str
    created_at: Optional[datetime] = None  # 생성 시각
    updated_at: Optional[datetime] = None  # 수정 시각

    class Config:
        json_schema_extra = {
            "example": {
                "course_id": "550e8400-e29b-41d4-a716-446655440000",
                "couple_id": "couple_abc123",
                "date": "2025-11-20",
                "template": "full_day",
                "slots": [
                    {
                        "slot_type": "lunch",
                        "category": "food_cafe",
                        "start_time": "12:00",
                        "duration": 90,
                        "emoji": "🍽️",
                        "place_name": "파스타 레스토랑",
                        "latitude": 37.123,
                        "longitude": 126.456,
                        "rating": 4.5,
                        "score": 0.92,
                        "distance_from_previous": None
                    }
                ],
                "total_distance": 3.5,
                "total_duration": 420,
                "start_time": "12:00",
                "end_time": "19:00",
                "created_at": "2025-11-19T10:30:00",
                "updated_at": "2025-11-19T10:30:00"
            }
        }


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
                    }
                ],
                "summary": "정말 좋은 하루였어요!",
                "created_at": "2025-11-20T20:00:00",
                "updated_at": "2025-11-20T20:30:00"
            }
        }
