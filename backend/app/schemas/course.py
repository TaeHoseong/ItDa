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
    date: str
    template: str
    slots: List[CourseSlot]
    total_distance: float  # 총 이동 거리 (km)
    total_duration: int  # 총 소요 시간 (분)
    start_time: str
    end_time: str

    class Config:
        json_schema_extra = {
            "example": {
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
                "end_time": "19:00"
            }
        }
