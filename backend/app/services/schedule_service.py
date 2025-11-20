from typing import List, Optional
from datetime import datetime
from fastapi import HTTPException

from app.models.schedule import Schedule
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

    def create(self, user_id: str, data: dict) -> Schedule:
        """일정 생성"""

        raw_date = data["date"]
        if isinstance(raw_date, datetime):
            date_value = raw_date
        else:
            date_value = datetime.fromisoformat(raw_date)

        payload = {
            "user_id": user_id,
            "title": data["title"],
            "date": self._to_json_value(date_value),
            "time": data.get("time", None),
            "place_name": data.get("place_name"),
            "latitude": data.get("latitude"),
            "longitude": data.get("longitude"),
            "address": data.get("address"),
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

        return rows[0]

    def get_by_user(self, user_id: str) -> List[Schedule]:
        """사용자 전체 일정 조회"""

        response = (
            self.supabase
            .table(self.table_name)
            .select("*")
            .eq("user_id", user_id)
            .order("date", desc=False)
            .execute()
        )
        self._handle_response(response)

        rows = response.data or []
        return rows

    def get_by_id(self, schedule_id: int) -> Optional[Schedule]:
        """특정 일정 조회"""

        response = (
            self.supabase
            .table(self.table_name)
            .select("*")
            .eq("id", schedule_id)
            .limit(1)
            .execute()
        )
        self._handle_response(response, not_found_ok=True)

        rows = response.data or []
        if not rows:
            return None
        return rows[0]

    def get_by_date(self, user_id: str, date: datetime) -> List[Schedule]:
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

    def update(self, schedule_id: int, data: dict) -> Schedule:
        """일정 수정"""

        existing = self.get_by_id(schedule_id)
        if not existing:
            raise HTTPException(status_code=404, detail="일정을 찾을 수 없습니다")

        update_data = {}
        for key, value in data.items():
            if value is None:
                continue

            if key == "date":
                if isinstance(value, str):
                    value = datetime.fromisoformat(value)

            # ⬇️ datetime일 가능성이 있는 값은 전부 JSON용으로 변환
            update_data[key] = self._to_json_value(value)

        if not update_data:
            return existing

        response = (
            self.supabase
            .table(self.table_name)
            .update(update_data)
            .eq("id", schedule_id)
            .execute()
        )
        self._handle_response(response)

        rows = response.data or []
        if not rows:
            updated = self.get_by_id(schedule_id)
            if not updated:
                raise HTTPException(
                    status_code=500,
                    detail="일정 수정 후 데이터를 가져오지 못했습니다."
                )
            return updated

        return rows[0]

    def delete(self, schedule_id: int) -> bool:
        """일정 삭제"""

        response = (
            self.supabase
            .table(self.table_name)
            .delete()
            .eq("id", schedule_id)
            .execute()
        )
        self._handle_response(response, not_found_ok=True)

        rows = response.data or []
        if not rows:
            # 삭제된 행이 없다면 404
            raise HTTPException(status_code=404, detail="일정을 찾을 수 없습니다")

        return True
