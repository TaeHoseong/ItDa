from typing import List, Optional
from datetime import datetime
from fastapi import HTTPException

from app.core.supabase_client import get_supabase


class ScheduleService:
    """일정 관리 서비스 (Supabase 기반)"""

    def __init__(self):
        self.supabase = get_supabase()      # Supabase Client
        self.table_name = "courses"       # Supabase 테이블 이름

    # ---------------- 내부 유틸 ----------------

    def _handle_response(self, response, not_found_ok: bool = False):
        """Supabase 공통 응답/에러 처리"""
        if getattr(response, "error", None):
            raise HTTPException(
                status_code=500,
                detail=f"Supabase Error: {response.error.message}"
            )

        data = getattr(response, "data", None)

        if not_found_ok:
            return

        if data is None:
            raise HTTPException(
                status_code=500,
                detail="Supabase 응답에 data가 없습니다."
            )
    
    def _to_json_value(self, value):
        """Supabase로 보낼 때 datetime은 isoformat 문자열로 변환"""
        if isinstance(value, datetime):
            return value.isoformat()
        return value

    # ---------------- CRUD ----------------

    def create(self, user_id: str, data: dict) -> dict:
        """일정 생성 - schedule 데이터를 course 형식으로 변환하여 저장"""
        import uuid

        # 날짜 처리
        raw_date = data["date"]
        if isinstance(raw_date, datetime):
            date_value = raw_date
        else:
            date_value = datetime.fromisoformat(raw_date)

        # 시간 처리
        time_str = data.get("time", "12:00")
        start_time = time_str

        # end_time 계산 (기본 1시간 후)
        try:
            hour, minute = map(int, time_str.split(":"))
            end_hour = hour + 1
            end_time = f"{end_hour:02d}:{minute:02d}"
        except:
            end_time = "13:00"

        # slots 생성 (schedule의 장소 정보를 slot으로 변환)
        slot = {
            "slot_type": "schedule",
            "category": "general",
            "start_time": start_time,
            "duration": 60,
            "emoji": "📍",
            "place_name": data.get("place_name", data["title"]),
            "place_address": data.get("address"),
            "latitude": data.get("latitude", 0.0),
            "longitude": data.get("longitude", 0.0),
            "score": 1.0
        }

        # courses 형식의 payload 생성
        payload = {
            "course_id": str(uuid.uuid4()),
            "user_id": user_id,
            "couple_id": None,
            "date": date_value.strftime("%Y-%m-%d"),
            "template": "single_schedule",  # schedule은 단일 슬롯 course
            "slots": [slot],
            "total_distance": 0.0,
            "total_duration": 60,
            "start_time": start_time,
            "end_time": end_time,
        }

        response = (
            self.supabase
            .table(self.table_name)
            .insert(payload)
            .execute()
        )
        self._handle_response(response)

        rows = response.data or []
        if not rows:
            raise HTTPException(
                status_code=500,
                detail="일정 생성 후 반환된 데이터가 없습니다."
            )

        # course 형식을 schedule 형식으로 변환하여 반환
        course = rows[0]
        schedule = {
            "id": course.get("course_id"),
            "user_id": course.get("user_id"),
            "title": slot["place_name"],
            "date": str(course.get("date", "")) if course.get("date") else "",
            "time": course.get("start_time"),
            "place_name": slot.get("place_name"),
            "latitude": slot.get("latitude"),
            "longitude": slot.get("longitude"),
            "address": slot.get("place_address"),
            "created_at": str(course.get("created_at", "")) if course.get("created_at") else "",
            "updated_at": str(course.get("updated_at")) if course.get("updated_at") else None,
        }

        return schedule

    def get_by_user(self, user_id: str) -> List[dict]:
        """사용자 전체 일정 조회 - course 형식에서 schedule 형식으로 변환"""

        response = (
            self.supabase
            .table(self.table_name)
            .select("*")
            .eq("user_id", user_id)
            .eq("template", "single_schedule")  # schedule만 필터링
            .order("date", desc=False)
            .execute()
        )
        self._handle_response(response)

        courses = response.data or []

        # course 형식을 schedule 형식으로 변환
        schedules = []
        for course in courses:
            slot = course.get("slots", [{}])[0] if course.get("slots") else {}

            schedule = {
                "id": course.get("course_id"),  # course_id를 그대로 사용
                "user_id": course.get("user_id"),
                "title": slot.get("place_name", ""),
                "date": str(course.get("date", "")) if course.get("date") else "",
                "time": course.get("start_time"),
                "place_name": slot.get("place_name"),
                "latitude": slot.get("latitude"),
                "longitude": slot.get("longitude"),
                "address": slot.get("place_address"),
                "created_at": str(course.get("created_at", "")) if course.get("created_at") else "",
                "updated_at": str(course.get("updated_at")) if course.get("updated_at") else None,
            }
            schedules.append(schedule)

        return schedules

    def get_by_id(self, schedule_id: str) -> Optional[dict]:
        """특정 일정 조회 - course_id로 조회하고 schedule 형식으로 변환"""

        response = (
            self.supabase
            .table(self.table_name)
            .select("*")
            .eq("course_id", schedule_id)
            .eq("template", "single_schedule")
            .limit(1)
            .execute()
        )
        self._handle_response(response, not_found_ok=True)

        courses = response.data or []
        if not courses:
            return None

        # course 형식을 schedule 형식으로 변환
        course = courses[0]
        slot = course.get("slots", [{}])[0] if course.get("slots") else {}

        schedule = {
            "id": course.get("course_id"),
            "user_id": course.get("user_id"),
            "title": slot.get("place_name", ""),
            "date": str(course.get("date", "")) if course.get("date") else "",
            "time": course.get("start_time"),
            "place_name": slot.get("place_name"),
            "latitude": slot.get("latitude"),
            "longitude": slot.get("longitude"),
            "address": slot.get("place_address"),
            "created_at": str(course.get("created_at", "")) if course.get("created_at") else "",
            "updated_at": str(course.get("updated_at")) if course.get("updated_at") else None,
        }

        return schedule

    def get_by_date(self, user_id: str, date: datetime) -> List[dict]:
        """특정 날짜 일정 조회"""
    
        start = date.replace(hour=0, minute=0, second=0, microsecond=0)
        end = date.replace(hour=23, minute=59, second=59, microsecond=999999)

        start_str = start.isoformat()
        end_str = end.isoformat()

        response = (
            self.supabase
            .table(self.table_name)
            .select("*")
            .eq("user_id", user_id)
            .gte("date", start_str)
            .lte("date", end_str)
            .order("date", desc=False)
            .execute()
        )
        self._handle_response(response)

        rows = response.data or []
        return rows

    def update(self, schedule_id: str, data: dict) -> dict:
        """일정 수정 - schedule 데이터를 course 형식으로 변환하여 업데이트"""

        # 기존 course 조회
        response = (
            self.supabase
            .table(self.table_name)
            .select("*")
            .eq("course_id", schedule_id)
            .eq("template", "single_schedule")
            .limit(1)
            .execute()
        )

        if not response.data:
            raise HTTPException(status_code=404, detail="일정을 찾을 수 없습니다")

        existing_course = response.data[0]
        existing_slot = existing_course.get("slots", [{}])[0]

        # update_data 생성 (course 형식)
        update_data = {}

        # date 처리
        if "date" in data and data["date"] is not None:
            if isinstance(data["date"], datetime):
                update_data["date"] = data["date"].strftime("%Y-%m-%d")
            else:
                update_data["date"] = datetime.fromisoformat(data["date"]).strftime("%Y-%m-%d")

        # time 처리
        if "time" in data and data["time"] is not None:
            time_str = data["time"]
            update_data["start_time"] = time_str
            try:
                hour, minute = map(int, time_str.split(":"))
                end_hour = hour + 1
                update_data["end_time"] = f"{end_hour:02d}:{minute:02d}"
            except:
                pass

        # slots 업데이트 (기존 slot 데이터 병합)
        updated_slot = existing_slot.copy()
        if "title" in data:
            updated_slot["place_name"] = data["title"]
        if "place_name" in data:
            updated_slot["place_name"] = data["place_name"]
        if "latitude" in data:
            updated_slot["latitude"] = data["latitude"]
        if "longitude" in data:
            updated_slot["longitude"] = data["longitude"]
        if "address" in data:
            updated_slot["place_address"] = data["address"]
        if "time" in data:
            updated_slot["start_time"] = data["time"]

        update_data["slots"] = [updated_slot]

        if not update_data:
            return self.get_by_id(schedule_id)

        # 업데이트 실행
        response = (
            self.supabase
            .table(self.table_name)
            .update(update_data)
            .eq("course_id", schedule_id)
            .execute()
        )
        self._handle_response(response)

        # 업데이트된 데이터 조회 및 schedule 형식으로 변환
        return self.get_by_id(schedule_id)

    def delete(self, schedule_id: str) -> bool:
        """일정 삭제 - course_id로 삭제"""

        response = (
            self.supabase
            .table(self.table_name)
            .delete()
            .eq("course_id", schedule_id)
            .eq("template", "single_schedule")
            .execute()
        )
        self._handle_response(response, not_found_ok=True)

        rows = response.data or []
        if not rows:
            # 삭제된 행이 없다면 404
            raise HTTPException(status_code=404, detail="일정을 찾을 수 없습니다")

        return True
