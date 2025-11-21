from app.core.supabase_client import get_supabase
from app.services.course_service import CourseService
from datetime import datetime

class ScheduleService:
    def __init__(self):
        self.supabase = get_supabase()
        self.table_name = "couples"
    
    def _get_course_ids(self, user_id):
        response = (
            self.supabase
            .table(self.table_name)
            .select("schedules")
            .or_(f"user_id1.eq.{user_id},user_id2.eq.{user_id}")
            .maybe_single()
            .execute()
        )
        
        if not response.data:
            return []
        else:
            course_ids = response.data.get("schedules", [])
        
        return course_ids
    
    def get_by_date(
        self,
        user_id: str,
        date: datetime,
    ):
        start = date.replace(hour=0, minute=0, second=0, microsecond=0)
        end = date.replace(hour=23, minute=59, second=59, microsecond=999999)

        start_str = start.isoformat()
        end_str = end.isoformat()
        
        course_ids = self._get_course_ids(user_id)
        course_service = CourseService()
        
        courses = [course_service.get_course(course_id) for course_id in course_ids]
        
        schedules_total = []
        for course in courses:
            course_date = course.get("date")
            if isinstance(course_date, str):
                try:
                    parsed = datetime.fromisoformat(course_date.replace("Z", "+00:00"))
                    course_datetime = parsed.replace(tzinfo=None)
                except Exception:
                    continue
            elif isinstance(course_date, datetime):
                # datetime이면 tz정보 있을 수 있으므로 제거
                course_datetime = course_date.replace(tzinfo=None)
            else:
                continue

            # 날짜 범위 비교
            if not (start <= course_datetime <= end):
                continue
            slots = course.get("slots", [{}]) if course.get("slots") else {}
            schedules = []
            for slot in slots:
                
                schedule = {
                    "id": slot.get("course_id"),  # course_id를 그대로 사용
                    "user_id": course.get("user_id"),
                    "title": slot.get("place_name", ""),
                    "date": str(course.get("date", "")) if course.get("date") else "",
                    "time": course.get("start_time"),
                    "duration": slot.get("duration", ""),
                    "place_name": slot.get("place_name"),
                    "latitude": slot.get("latitude"),
                    "longitude": slot.get("longitude"),
                    "address": slot.get("place_address"),
                    "created_at": str(course.get("created_at", "")) if course.get("created_at") else "",
                    "updated_at": str(course.get("updated_at")) if course.get("updated_at") else None,
                }
                schedules.append(schedule)
            schedules_total.append(schedules)

        return schedules_total
    
    def get_by_user(
        self,
        user_id: str
    ):
        course_ids = self._get_course_ids(user_id)
        course_service = CourseService()
        
        courses = [course_service.get_course(course_id) for course_id in course_ids]
        
        schedules_total = []
        for course in courses:
            schedules = []
            slots = course.get("slots", [{}]) if course.get("slots") else {}
            for slot in slots:
                schedule = {
                    "id": slot.get("course_id"),  # course_id를 그대로 사용
                    "user_id": course.get("user_id"),
                    "title": slot.get("place_name", ""),
                    "date": str(course.get("date", "")) if course.get("date") else "",
                    "time": course.get("start_time"),
                    "duration": slot.get("duration", ""),
                    "place_name": slot.get("place_name"),
                    "latitude": slot.get("latitude"),
                    "longitude": slot.get("longitude"),
                    "address": slot.get("place_address"),
                    "created_at": str(course.get("created_at", "")) if course.get("created_at") else "",
                    "updated_at": str(course.get("updated_at")) if course.get("updated_at") else None,
                }
                schedules.append(schedule)
            schedules_total.append(schedules)
        return schedules_total
