from typing import List
from datetime import datetime
import uuid

# 간단한 메모리 DB
schedules_db: List[dict] = []

class ScheduleService:
    async def create(self, schedule_data: dict) -> dict:
        new_schedule = {
            "id": str(uuid.uuid4()),
            **schedule_data,
            "created_at": datetime.now().isoformat(),
        }
        schedules_db.append(new_schedule)
        return new_schedule

    async def get_all(self) -> List[dict]:
        return sorted(schedules_db, key=lambda x: (x.get("date", ""), x.get("time", "")))

    async def update(self, schedule_id: str, updates: dict) -> dict:
        for schedule in schedules_db:
            if schedule["id"] == schedule_id:
                schedule.update(updates)
                return schedule
        raise ValueError("일정을 찾을 수 없습니다")

    async def delete(self, schedule_id: str) -> bool:
        global schedules_db
        original_len = len(schedules_db)
        schedules_db = [s for s in schedules_db if s["id"] != schedule_id]
        return len(schedules_db) < original_len