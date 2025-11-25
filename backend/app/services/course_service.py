"""
데이트 코스 생성 서비스
"""
import sys
import math
from pathlib import Path
from typing import List, Dict, Optional, Tuple
from datetime import datetime, timedelta

# algorithm.py import를 위한 경로 설정
backend_path = Path(__file__).parent.parent.parent
sys.path.insert(0, str(backend_path))

import algorithm
from app.schemas.course import (
    DateCourse, CourseSlot, SlotConfig, CoursePreferences
)
from app.services.suggest_service import SuggestService
from app.core.supabase_client import get_supabase

class CourseService:
    """데이트 코스 생성 서비스"""

    # 템플릿 정의
    TEMPLATES = {
        "full_day": [
            {"slot_type": "lunch", "category": "food_cafe", "start_time": "12:00", "duration": 90, "emoji": "🍽️"},
            {"slot_type": "cafe", "category": "food_cafe", "start_time": "14:00", "duration": 60, "emoji": "☕"},
            {"slot_type": "activity", "category": "activity_sports", "start_time": "15:30", "duration": 120, "emoji": "⚽"},
            {"slot_type": "dinner", "category": "food_cafe", "start_time": "18:00", "duration": 90, "emoji": "🍴"},
            {"slot_type": "night_view", "category": "nature_healing", "start_time": "20:00", "duration": 60, "emoji": "🌃"},
        ],
        "half_day_lunch": [
            {"slot_type": "lunch", "category": "food_cafe", "start_time": "12:00", "duration": 90, "emoji": "🍽️"},
            {"slot_type": "cafe", "category": "food_cafe", "start_time": "14:00", "duration": 60, "emoji": "☕"},
            {"slot_type": "activity", "category": "culture_art", "start_time": "15:30", "duration": 120, "emoji": "🎨"},
        ],
        "half_day_dinner": [
            {"slot_type": "cafe", "category": "food_cafe", "start_time": "16:00", "duration": 60, "emoji": "☕"},
            {"slot_type": "dinner", "category": "food_cafe", "start_time": "18:00", "duration": 90, "emoji": "🍴"},
            {"slot_type": "night_view", "category": "nature_healing", "start_time": "20:00", "duration": 60, "emoji": "🌃"},
        ],
        "cafe_date": [
            {"slot_type": "cafe", "category": "food_cafe", "start_time": "14:00", "duration": 90, "emoji": "☕"},
            {"slot_type": "dessert", "category": "food_cafe", "start_time": "16:00", "duration": 60, "emoji": "🍰"},
            {"slot_type": "walk", "category": "nature_healing", "start_time": "17:30", "duration": 60, "emoji": "🚶"},
        ],
        "active_date": [
            {"slot_type": "lunch", "category": "food_cafe", "start_time": "12:00", "duration": 60, "emoji": "🍽️"},
            {"slot_type": "activity", "category": "activity_sports", "start_time": "13:30", "duration": 150, "emoji": "⚽"},
            {"slot_type": "cafe", "category": "food_cafe", "start_time": "16:30", "duration": 60, "emoji": "☕"},
        ],
        "culture_date": [
            {"slot_type": "lunch", "category": "food_cafe", "start_time": "12:00", "duration": 90, "emoji": "🍽️"},
            {"slot_type": "exhibition", "category": "culture_art", "start_time": "14:00", "duration": 120, "emoji": "🎨"},
            {"slot_type": "cafe", "category": "food_cafe", "start_time": "16:30", "duration": 60, "emoji": "☕"},
        ],
    }

    def __init__(self):
        self.suggest_service = SuggestService()
        self.supabase = get_supabase()
        
    def generate_date_course(
        self,
        user_id: str,
        date: str,
        template: str = "auto",
        preferences: Optional[CoursePreferences] = None
    ) -> DateCourse:
        """
        데이트 코스 생성 메인 함수

        Args:
            user_id: 사용자 ID
            date: 날짜 (YYYY-MM-DD)
            template: 템플릿 이름 (auto면 페르소나 기반 자동 선택)
            preferences: 사용자 커스터마이징 설정

        Returns:
            DateCourse: 생성된 데이트 코스
        """
        print(f"\n{'='*60}")
        print(f"[COURSE GENERATION START]")
        print(f"   User ID: {user_id}")
        print(f"   Date: {date}")
        print(f"   Template: {template}")
        print(f"   Preferences: {preferences}")
        print(f"{'='*60}\n")

        # 1. 템플릿 선택
        if template == "auto":
            template = self._select_template_by_persona(user_id)
            print(f"[OK] Auto-selected template: {template}")

        # 2. 템플릿 가져오기
        if template not in self.TEMPLATES:
            print(f"[WARN] Template '{template}' not found, using 'full_day'")
            template = "full_day"

        slot_configs = self.TEMPLATES[template].copy()

        # 3. 사용자 커스터마이징 적용
        if preferences:
            slot_configs = self._apply_preferences(slot_configs, preferences)

        # 4. 각 슬롯별 장소 추천
        slots: List[CourseSlot] = []
        previous_location: Optional[Tuple[float, float]] = None
        total_distance = 0.0
        used_places: List[str] = []  # 이미 사용된 장소 이름 추적

        for config in slot_configs:
            slot = self._recommend_for_slot(
                user_id=user_id,
                slot_config=config,
                previous_location=previous_location,
                exclude_places=used_places  # 중복 제외
            )

            if slot:
                slots.append(slot)
                used_places.append(slot.place_name)  # 사용된 장소 추가
                previous_location = (slot.latitude, slot.longitude)
                if slot.distance_from_previous:
                    total_distance += slot.distance_from_previous

        # 5. 코스 메타데이터 계산
        if not slots:
            raise ValueError("코스 생성 실패: 추천된 장소가 없습니다.")

        total_duration = sum(slot.duration for slot in slots)
        start_time = slots[0].start_time

        # 종료 시간 계산
        start_dt = datetime.strptime(start_time, "%H:%M")
        end_dt = start_dt + timedelta(minutes=total_duration)
        end_time = end_dt.strftime("%H:%M")

        course = DateCourse(
            date=date,
            template=template,
            slots=slots,
            total_distance=round(total_distance, 2),
            total_duration=total_duration,
            start_time=start_time,
            end_time=end_time
        )

        print(f"\n{'='*60}")
        print(f"[COURSE GENERATION COMPLETE]")
        print(f"   Template: {template}")
        print(f"   Slots: {len(slots)}")
        print(f"   Total Distance: {course.total_distance}km")
        print(f"   Total Duration: {course.total_duration}min ({start_time} - {end_time})")
        print(f"{'='*60}\n")

        return course

    def _select_template_by_persona(self, user_id: str) -> str:
        """
        페르소나 기반 템플릿 자동 선택

        Args:
            user_id: 사용자 ID

        Returns:
            str: 선택된 템플릿 이름
        """
        persona = self.suggest_service.get_user_persona(user_id)

        if not persona:
            print("[WARN] Persona not found, using default template")
            return "full_day"

        # 페르소나 분석 (20차원 벡터)
        # mainCategory (6): food_cafe, culture_art, activity_sports, nature_healing, craft_experience, shopping
        # atmosphere (6): quiet, romantic, trendy, private_vibe, artistic, energetic
        # experienceType (4): passive_enjoyment, active_participation, social_bonding, relaxation_focused
        # spaceCharacteristics (4): indoor_ratio, crowdedness_expected, photo_worthiness, scenic_view

        food_cafe = persona[0]
        culture_art = persona[1]
        activity_sports = persona[2]
        nature_healing = persona[3]

        romantic = persona[7]
        energetic = persona[11]

        active_participation = persona[13]
        relaxation_focused = persona[15]

        print(f"\n[PERSONA ANALYSIS FOR TEMPLATE SELECTION]")
        print(f"  food_cafe: {food_cafe:.2f}, culture_art: {culture_art:.2f}")
        print(f"  activity_sports: {activity_sports:.2f}, nature_healing: {nature_healing:.2f}")
        print(f"  romantic: {romantic:.2f}, energetic: {energetic:.2f}")
        print(f"  active_participation: {active_participation:.2f}, relaxation_focused: {relaxation_focused:.2f}")

        # 템플릿 선택 로직
        # 1. 활동적인 성향 (activity_sports 높음 + active_participation 높음)
        if activity_sports > 0.6 and active_participation > 0.6:
            return "active_date"

        # 2. 문화/예술 성향 (culture_art 높음)
        if culture_art > 0.6:
            return "culture_date"

        # 3. 힐링/로맨틱 성향 (nature_healing 높음 + romantic 높음 + relaxation_focused 높음)
        if nature_healing > 0.5 and romantic > 0.6 and relaxation_focused > 0.6:
            return "cafe_date"

        # 4. 에너지 낮음 (energetic 낮음) → 반나절 코스
        if energetic < 0.4:
            # 점심 vs 저녁 선호도
            if food_cafe > 0.7:
                return "half_day_lunch"
            else:
                return "half_day_dinner"

        # 5. 기본값: full_day
        return "full_day"

    def _apply_preferences(
        self,
        slot_configs: List[Dict],
        preferences: CoursePreferences
    ) -> List[Dict]:
        """
        사용자 설정을 템플릿에 적용

        Args:
            slot_configs: 원본 슬롯 설정
            preferences: 사용자 설정

        Returns:
            List[Dict]: 수정된 슬롯 설정
        """
        # 1. 제외할 슬롯 필터링
        if preferences.exclude:
            slot_configs = [
                s for s in slot_configs
                if s["slot_type"] not in preferences.exclude
            ]

        # 2. 필수 포함 슬롯 확인 (없으면 경고만)
        if preferences.must_include:
            existing_types = {s["slot_type"] for s in slot_configs}
            for must_type in preferences.must_include:
                if must_type not in existing_types:
                    print(f"[WARN] Required slot type '{must_type}' not in template")

        # 3. 시작 시간 조정
        if preferences.start_time:
            time_diff = self._calculate_time_diff(slot_configs[0]["start_time"], preferences.start_time)
            for config in slot_configs:
                config["start_time"] = self._adjust_time(config["start_time"], time_diff)

        # 4. 총 시간 제한 (duration 설정 시)
        if preferences.duration:
            total = 0
            filtered = []
            for config in slot_configs:
                if total + config["duration"] <= preferences.duration:
                    filtered.append(config)
                    total += config["duration"]
                else:
                    break
            slot_configs = filtered

        return slot_configs

    def _recommend_for_slot(
        self,
        user_id: str,
        slot_config: Dict,
        previous_location: Optional[Tuple[float, float]] = None,
        exclude_places: Optional[List[str]] = None,
        keyword: str = None
    ) -> Optional[CourseSlot]:
        """
        특정 슬롯에 대한 장소 추천

        Args:
            user_id: 사용자 ID
            slot_config: 슬롯 설정
            previous_location: 이전 장소 위치 (lat, lng)
            exclude_places: 제외할 장소 이름 리스트 (중복 방지)
            keyword: 유저가 원하는 특정한 장소
            
        Returns:
            CourseSlot: 추천된 슬롯 (장소 포함)
        """
        category = slot_config["category"]

        print(f"\n[SEARCH] [{slot_config['slot_type']}] Recommending for category: {category}")
        if exclude_places:
            print(f"   Excluding places: {exclude_places}")

        # suggest_service를 통해 장소 추천
        # 점진적으로 검색 개수를 늘려가며 시도
        try:
            places = None
            for k in [10, 20, 30, 50]:  # 점진적으로 증가
                places = self.suggest_service.get_recommendations(
                    user_id=user_id,
                    category=category,
                    specific_food=keyword,
                    last_recommend=exclude_places,  # 이미 사용된 장소 제외
                    k=k
                )

                if places:
                    print(f"   Found {len(places)} places with k={k}")
                    break
                else:
                    print(f"   No places with k={k}, trying larger search...")

            if not places:
                print(f"[ERROR] No places found for category: {category} (tried up to k=50)")
                return None

            place = places[0]

            # 이전 장소로부터 거리 계산
            distance = None
            if previous_location:
                distance = self._calculate_distance(
                    previous_location[0], previous_location[1],
                    place["latitude"], place["longitude"]
                )

            slot = CourseSlot(
                slot_type=slot_config["slot_type"],
                category=category,
                start_time=slot_config["start_time"],
                duration=slot_config["duration"],
                emoji=slot_config["emoji"],
                place_name=place["name"],
                place_address=place.get("address"),
                latitude=place["latitude"],
                longitude=place["longitude"],
                rating=place.get("rating"),
                price_range=place.get("price_range"),
                score=place["score"],
                distance_from_previous=distance
            )

            print(f"[OK] Recommended: {place['name']} (score: {place['score']:.2f})")
            if distance:
                print(f"   Distance from previous: {distance:.2f}km")

            return slot

        except Exception as e:
            print(f"[ERROR] Error recommending for slot: {e}")
            return None

    def _calculate_distance(self, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """
        Haversine 공식으로 두 지점 사이 거리 계산 (km)
        """
        R = 6371  # 지구 반지름 (km)

        lat1_rad = math.radians(lat1)
        lat2_rad = math.radians(lat2)
        delta_lat = math.radians(lat2 - lat1)
        delta_lon = math.radians(lon2 - lon1)

        a = math.sin(delta_lat / 2) ** 2 + \
            math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(delta_lon / 2) ** 2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

        distance = R * c
        return round(distance, 2)

    def _calculate_time_diff(self, time1: str, time2: str) -> int:
        """두 시간의 차이 계산 (분 단위)"""
        t1 = datetime.strptime(time1, "%H:%M")
        t2 = datetime.strptime(time2, "%H:%M")
        diff = (t2 - t1).total_seconds() / 60
        return int(diff)

    def _adjust_time(self, time_str: str, minutes: int) -> str:
        """시간에 분을 더함"""
        dt = datetime.strptime(time_str, "%H:%M")
        adjusted = dt + timedelta(minutes=minutes)
        return adjusted.strftime("%H:%M")

    def regenerate_course_slot(
        self,
        course: DateCourse,
        slot_index: int,
        user_id: str = None,
        category: str = None,
        keyword: str = None
    ) -> DateCourse:
        """
        코스의 특정 슬롯만 재생성

        Args:
            course: 기존 데이트 코스
            slot_index: 재생성할 슬롯 인덱스 (0부터 시작)
            user_id: 사용자 ID (페르소나 기반 추천용)
            keyword: 유저가 원하는 특정 장소
            
        Returns:
            DateCourse: 슬롯이 교체된 새로운 코스
        """
        
        if slot_index < 0 or slot_index >= len(course.slots):
            raise ValueError(f"Invalid slot_index: {slot_index}")

        print(f"\n{'='*60}")
        print(f"[REGENERATE] Slot #{slot_index} in {course.template} course")
        print(f"{'='*60}")

        # 기존 슬롯 정보
        old_slot = course.slots[slot_index]
        new_category = old_slot.category if old_slot.category == category else category
        # 슬롯 설정 재구성
        slot_config = {
            "slot_type": old_slot.slot_type,
            "category": new_category,  # 기존 슬롯의 category 사용
            "start_time": old_slot.start_time,
            "duration": old_slot.duration,
            "emoji": old_slot.emoji,
        }

        # 이미 사용된 장소들 (현재 슬롯 포함 - 같은 장소가 다시 나오지 않도록)
        exclude_places = [s.place_name for s in course.slots]
        print(f"   Excluding ALL current places: {exclude_places}")
        print(f"[slot change] {slot_config["category"]} >> {new_category}")
        # 이전 위치 (이전 슬롯이 있으면)
        previous_location = None
        if slot_index > 0:
            prev_slot = course.slots[slot_index - 1]
            previous_location = (prev_slot.latitude, prev_slot.longitude)

        # 새로운 장소 추천
        new_slot = self._recommend_for_slot(
            user_id=user_id,
            slot_config=slot_config,
            previous_location=previous_location,
            exclude_places=exclude_places,
            keyword=keyword
        )

        if not new_slot:
            raise RuntimeError(f"Failed to find alternative place for slot #{slot_index}")

        # 다음 슬롯 거리 재계산
        if slot_index < len(course.slots) - 1:
            next_slot = course.slots[slot_index + 1]
            new_distance = self._calculate_distance(
                new_slot.latitude, new_slot.longitude,
                next_slot.latitude, next_slot.longitude
            )
            # next_slot은 immutable이므로 새로 생성
            course.slots[slot_index + 1] = CourseSlot(
                slot_type=next_slot.slot_type,
                category=next_slot.category,
                emoji=next_slot.emoji,
                start_time=next_slot.start_time,
                duration=next_slot.duration,
                place_name=next_slot.place_name,
                place_address=next_slot.place_address,
                latitude=next_slot.latitude,
                longitude=next_slot.longitude,
                rating=next_slot.rating,
                score=next_slot.score,
                distance_from_previous=new_distance
            )

        # 슬롯 교체
        course.slots[slot_index] = new_slot

        # 총 거리 재계산
        course.total_distance = sum(
            s.distance_from_previous for s in course.slots
            if s.distance_from_previous is not None
        )

        print(f"\n✅ Slot #{slot_index} regenerated:")
        print(f"   Old: {old_slot.place_name}")
        print(f"   New: {new_slot.place_name} (score: {new_slot.score:.2f})")

        return course

    def _infer_category_from_slot_type(self, slot_type: str) -> str:
        """슬롯 타입으로부터 카테고리 추론"""
        mapping = {
            "lunch": "food_cafe",
            "dinner": "food_cafe",
            "cafe": "food_cafe",
            "dessert": "food_cafe",
            "activity": "activity_sports",
            "walk": "nature_healing",
            "night_view": "nature_healing",
            "exhibition": "culture_art",
        }
        return mapping.get(slot_type, "food_cafe")

    # ========== CRUD Methods ==========

    def create_course(self, user_id: str, course_data: dict) -> dict:
        """
        Create a new course in database

        Args:
            user_id: User ID (creator)
            course_data: Course data from CourseCreate schema

        Returns:
            Created course dict
        """
        import uuid
        course_id = str(uuid.uuid4())
        payload = {
            "course_id": course_id,
            "user_id": user_id,
            "couple_id": course_data.get("couple_id"),
            "date": course_data["date"],
            "template": course_data["template"],
            "slots": course_data["slots"],              # JSONB array
            "total_distance": course_data.get("total_distance", 0.0),
            "total_duration": course_data.get("total_duration", 0),
            "start_time": course_data["start_time"],
            "end_time": course_data["end_time"],
        }

        response = (
            self.supabase.table("courses")
            .insert(payload)
            .execute()
        )
        
        if not response.data:
            raise RuntimeError("Failed to create course in Supabase")

        return response.data[0]

    def get_course(self, course_id: str) -> Optional[dict]:
        """
        Get course by ID

        Args:
            course_id: Course ID

        Returns:
            Course object or None
        """
        response = (
            self.supabase.table("courses")
            .select("*")
            .eq("course_id", course_id)
            .execute()
        )
        
        if not response.data:
            raise RuntimeError("Failed to get course in Supabase")

        return response.data[0]
        

    def get_courses_by_user(self, user_id: str) -> List[dict]:
        """
        Get all courses by user ID

        Args:
            user_id: User ID

        Returns:
            List of Course objects
        """
        response = (
            self.supabase.table("courses")
            .select("*")
            .eq("user_id", user_id)
            .execute()
        )

        # Empty list is valid, not an error
        return response.data if response.data else []
    
    def get_courses_by_couple(self, couple_id: str) -> List[dict]:
        """
        Get all courses by couple ID

        Args:
            couple_id: Couple ID

        Returns:
            List of Course objects
        """
        response = (
            self.supabase.table("courses")
            .select("*")
            .eq("couple_id", couple_id)
            .execute()
        )
        
        if not response.data:
            raise RuntimeError("Failed to get course in Supabase")

        return response.data[0]
    
    def update_course(self, course_id: str, course_data: dict):
        """
        Update course in Supabase

        Args:
            course_id: Course ID
            course_data: dict with updated fields

        Returns:
            Updated course dict or None
        """
        # 1. update 실행
        response = (
            self.supabase.table("courses")
            .update(course_data)
            .eq("course_id", course_id)
            .execute()
        )

        # 2. 업데이트 결과 확인
        if not response.data:
            return None

        # 3. updated course 반환
        return response.data[0]
    
    def delete_course(self, course_id: str) -> bool:
        """
        Delete course from Supabase

        Args:
            course_id: Course ID

        Returns:
            True if deleted, False otherwise
        """
        response = (
            self.supabase.table("courses")
            .delete()
            .eq("course_id", course_id)
            .execute()
        )

        # 삭제된 row가 있으면 삭제 성공
        return bool(response.data)
