from typing import Dict
from datetime import datetime, timedelta
from app.schemas.persona import ChatRequest, ChatResponse
from app.services.openai_service import analyze_intent
from app.services.schedule_service import ScheduleService
from app.services.suggest_service import SuggestService
from app.core.supabase_client import get_supabase
from app.services.course_service import CourseService
from app.schemas.course import CoursePreferences
from sqlalchemy.orm import Session

class PersonaService:
    def __init__(self, sessions: Dict):
        self.sessions = sessions
        self.supabase = get_supabase()
        self.suggest_service = SuggestService()
        self.course_service = CourseService()

    async def process_message(self, request: ChatRequest) -> ChatResponse:
        """사용자 메시지 처리"""

        # 1️⃣ 세션 초기화
        if request.session_id not in self.sessions:
            self.sessions[request.session_id] = {
                "history": [],
                "pending_data": {}
            }

        session = self.sessions[request.session_id]

        print(f"\n{'='*60}")
        print(f"[NEW MESSAGE] {request.message}")
        print(f"[SESSION ID] {request.session_id}")
        print(f"[PENDING DATA] {session['pending_data']}")
        print(f"{'='*60}\n")

        # 2️⃣ OpenAI에게 의도 분석 (기존 pending_data 전달)
        intent = await analyze_intent(
            message=request.message,
            context=session["pending_data"],  # 🔥 중요: 기존 정보 전달
            history=session["history"]
        )

        # 3️⃣ 히스토리 업데이트
        self._update_history(session, request.message, intent["message"])

        # 4️⃣ extracted_data를 pending_data에 병합 (핵심!)
        extracted = intent.get("extracted_data", {})
        if extracted:
            # 새로 추출된 정보를 pending_data에 병합
            for key, value in extracted.items():
                if value:  # None이나 빈 값이 아닌 경우만
                    session["pending_data"][key] = value

            print(f"[UPDATED] pending_data: {session['pending_data']}")

        # 5️⃣ 액션별 처리
        response_data = None
        action = intent["action"]

        if action == "general_chat":
            response_data = self._handle_general_chat(session)

        elif action == "update_info":
            response_data = self._handle_update_info(session, intent)

        elif action == "create_schedule":
            response_data = await self._handle_create_schedule(session, intent)

        elif action == "update_schedule":
            response_data = await self._handle_update_schedule(session, intent)

        elif action == "recommend_place":
            response_data = self._handle_recommend_place(session, intent, request.user_id)
        elif action == "re_recommend_place":
            response_data = self._handle_re_recommend_place(session, intent, request.user_id)
        elif action == "select_place":
            response_data = await self._handle_select_place(session, intent)
        elif action == "view_schedule":
            response_data = self._handle_view_schedule(session, intent, request.user_id)
        elif action == "generate_course":
            response_data = self._handle_generate_course(session, intent, request.user_id)
        elif action == "regenerate_course_slot":
            print(f"\n[ACTION] Calling _handle_regenerate_course_slot")
            response_data = self._handle_regenerate_course_slot(session, intent, request.user_id)
            print(f"[ACTION] Response data keys: {response_data.keys() if response_data else None}")

        # improved_message가 있으면 그걸 사용, 없으면 intent["message"] 사용
        final_message = intent["message"]
        if response_data and "improved_message" in response_data:
            final_message = response_data["improved_message"]
            print(f"[DEBUG] Using improved_message: {final_message[:50]}...")
        else:
            print(f"[DEBUG] Using intent message: {final_message[:50]}...")
            if response_data:
                print(f"[DEBUG] response_data keys: {response_data.keys()}")

        return ChatResponse(
            message=final_message,
            action=action,
            data=response_data
        )

    def _update_history(self, session: dict, user_msg: str, bot_msg: str):
        """대화 히스토리 업데이트"""
        session["history"].extend([
            {"role": "user", "content": user_msg},
            {"role": "assistant", "content": bot_msg}
        ])
        if len(session["history"]) > 10:
            session["history"] = session["history"][-10:]

    def _handle_general_chat(self, session: dict) -> dict:
        """일반 대화 - pending_data 초기화"""
        session["pending_data"] = {}
        print(f"[GENERAL CHAT] pending_data initialized")

        return {
            "action_taken": "general_chat"
        }

    def _handle_update_info(self, session: dict, intent: dict) -> dict:
        """정보 수집 중"""
        missing = self._check_missing_fields(session["pending_data"])

        print(f"[UPDATE INFO] Collecting information")
        print(f"   Current data: {session['pending_data']}")
        print(f"   Missing fields: {missing}")

        return {
            "action_taken": "update_info",
            "pending_data": session["pending_data"],
            "missing_fields": missing
        }

    async def _handle_create_schedule(self, session: dict, intent: dict) -> dict:
        """일정 생성 정보 수집 (실제 저장은 프론트엔드에서 처리)"""

        # pending_data 사용 (이미 병합됨)
        schedule_data = session["pending_data"].copy()

        print(f"\n[CREATE SCHEDULE] Collecting schedule information")
        print(f"   Data: {schedule_data}")

        # 필수 정보 체크
        is_complete = self._is_complete(schedule_data)

        if is_complete:
            # 정보 충분 → 프론트엔드에 전달 (DB 저장은 프론트가 처리)
            session["pending_data"] = {}  # 초기화

            print(f"[READY] Schedule data ready for frontend!")
            print(f"   Title: {schedule_data['title']}")
            print(f"   Date: {schedule_data['date']}")
            print(f"   Time: {schedule_data['time']}\n")

            # 메시지 개선
            improved_message = (
                f"일정을 추가할게요!\n\n"
                f"제목: {schedule_data['title']}\n"
                f"날짜: {schedule_data['date']}\n"
                f"시간: {schedule_data['time']}"
            )

            return {
                "action_taken": "schedule_ready",
                "schedule_data": schedule_data,  # 프론트엔드가 이 데이터로 API 호출
                "improved_message": improved_message
            }
        else:
            # 정보 부족
            missing = self._check_missing_fields(schedule_data)

            print(f"[INFO NEEDED] Missing information")
            print(f"   Missing fields: {missing}\n")

            return {
                "action_taken": "need_more_info",
                "pending_data": schedule_data,
                "missing_fields": missing
            }

    async def _handle_update_schedule(self, session: dict, intent: dict) -> dict:
        """일정 수정 처리 (deprecated - DB 기반으로 변경 필요)"""

        # TODO: 이 기능은 user_id 기반으로 리팩토링 필요
        # 현재는 deprecated 상태

        return {
            "action_taken": "update_failed",
            "message": "일정 수정 기능은 현재 업데이트 중입니다."
        }

    def _is_complete(self, data: dict) -> bool:
        """필수 정보 완전성 체크"""
        required = ["title", "date", "time"]
        result = all(data.get(field) for field in required)
        return result

    def _check_missing_fields(self, data: dict) -> list:
        """부족한 필드 목록"""
        required = ["title", "date", "time"]
        missing = [field for field in required if not data.get(field)]
        return missing

    def _handle_recommend_place(self, session: dict, intent: dict, user_id: str = None) -> dict:
        """장소 추천 처리"""
        specific_food = intent["extracted_data"]["food"]
        category = intent["extracted_data"]["category"]        # 유저가 원하는 특정한 음식이 있을 경우
        print(f"\n{'='*60}")
        print(f"[RECOMMENDATION START]")
        print(f"   User ID: {user_id}")
        print(f"{'='*60}\n")

        # suggest_service를 통해 추천 장소 가져오기 (user_id 전달)
        places = self.suggest_service.get_recommendations(
            user_id=user_id, category=category, specific_food=specific_food, k=5)

        # 세션에 추천된 장소 저장 (장소 선택 시 사용)
        session["recommended_places"] = places
        session["last_category"] = category
        session["last_food"] = specific_food

        # 터미널 로깅
        print(f"\n{'='*60}")
        print(f"[RECOMMENDATION RESULTS]")
        print(f"{'='*60}")
        for idx, place in enumerate(places, 1):
            print(f"{idx}. {place['name']:<40} | Score: {place['score']:.2f}")
        print(f"{'='*60}\n")

        return {
            "action_taken": "place_recommended",
            "places": places,
            "count": len(places)
        }

    def _handle_re_recommend_place(self, session, intent, user_id):
        """이전 추천을 기반으로 재추천"""

        # 이전 추천에서 제외할 장소 리스트
        prev_places = [p["name"] for p in session["recommended_places"]]

        # 새 추천 가져오기
        new_places = self.suggest_service.get_recommendations(
            user_id=user_id,
            last_recommend=prev_places,
            category=session["last_category"],
            specific_food=session["last_food"],
            k=5
        )
        print(f"{[p["name"] for p in new_places]}")
        # 세션 업데이트
        session["recommended_places"].extend(new_places)

        return {
            "action_taken": "place_rerecommended",
            "places": new_places,
            "count": len(new_places)
        }
        
    async def _handle_select_place(self, session: dict, intent: dict) -> dict:
        """장소 선택 및 일정에 추가"""

        extracted = intent.get("extracted_data", {})
        place_index = extracted.get("place_index")  # 1, 2, 3, 4, 5
        place_name = extracted.get("place_name")  # "스타벅스"

        recommended_places = session.get("recommended_places", [])

        if not recommended_places:
            return {
                "action_taken": "no_places_found",
                "improved_message": "먼저 장소 추천을 받아주세요!"
            }

        selected_place = None

        # 번호로 선택
        if place_index:
            try:
                idx = int(place_index) - 1
                if 0 <= idx < len(recommended_places):
                    selected_place = recommended_places[idx]
            except:
                pass

        # 이름으로 선택
        if not selected_place and place_name:
            for place in recommended_places:
                if place_name.lower() in place['name'].lower():
                    selected_place = place
                    break

        if not selected_place:
            return {
                "action_taken": "place_not_found",
                "improved_message": "해당 장소를 찾을 수 없어요. 추천 목록을 다시 확인해주세요!"
            }

        # pending_data에 장소 정보 추가
        session["pending_data"]["place_name"] = selected_place["name"]
        session["pending_data"]["latitude"] = selected_place["latitude"]
        session["pending_data"]["longitude"] = selected_place["longitude"]
        session["pending_data"]["address"] = selected_place.get("address", "")

        # 날짜/시간 정보도 추출되었다면 병합
        if extracted.get("title"):
            session["pending_data"]["title"] = extracted["title"]
        if extracted.get("date"):
            session["pending_data"]["date"] = extracted["date"]
        if extracted.get("time"):
            session["pending_data"]["time"] = extracted["time"]

        # title이 없으면 장소 이름을 title로 사용
        if not session["pending_data"].get("title"):
            session["pending_data"]["title"] = selected_place["name"]

        # 일정 생성 시도
        schedule_data = session["pending_data"].copy()
        is_complete = self._is_complete(schedule_data)

        if is_complete:
            # 정보 충분 → 프론트엔드에 전달 (DB 저장은 프론트가 처리)
            session["pending_data"] = {}
            session["recommended_places"] = []  # 초기화

            improved_message = (
                f"✅ 일정을 추가할게요!\n\n"
                f"장소: {selected_place['name']}\n"
                f"제목: {schedule_data['title']}\n"
                f"날짜: {schedule_data['date']}\n"
                f"시간: {schedule_data['time']}"
            )

            return {
                "action_taken": "schedule_ready",
                "schedule_data": schedule_data,  # 프론트엔드가 이 데이터로 API 호출
                "improved_message": improved_message
            }
        else:
            # 날짜/시간 정보 필요
            missing = self._check_missing_fields(schedule_data)

            improved_message = (
                f"'{selected_place['name']}'을(를) 선택하셨네요! 👍\n"
                f"언제 방문하실 건가요? (날짜와 시간을 알려주세요)"
            )

            return {
                "action_taken": "need_more_info",
                "pending_data": schedule_data,
                "missing_fields": missing,
                "improved_message": improved_message
            }

    def _handle_view_schedule(self, session: dict, intent: dict, user_id: str = None) -> dict:
        """일정 조회 처리"""

        # pending_data 초기화 (일정 조회는 독립적인 액션)
        session["pending_data"] = {}

        if not self.supabse:
            return {
                "action_taken": "error",
                "message": "데이터베이스 연결이 필요합니다."
            }

        if not user_id:
            return {
                "action_taken": "error",
                "message": "로그인이 필요합니다."
            }

        extracted = intent.get("extracted_data", {})
        timeframe = extracted.get("timeframe", "all")

        print(f"\n{'='*60}")
        print(f"[VIEW SCHEDULE]")
        print(f"   User ID: {user_id}")
        print(f"   Timeframe: {timeframe}")
        print(f"   Current datetime: {datetime.now()}")
        print(f"{'='*60}\n")

        # ScheduleService 인스턴스 생성 (DB session 전달)
        schedule_service = ScheduleService(self.supabase)

        # 시간 범위 계산
        now = datetime.now()
        schedules = []

        if timeframe == "today":
            schedules = schedule_service.get_by_date(user_id, now)
        elif timeframe == "tomorrow":
            tomorrow = now + timedelta(days=1)
            schedules = schedule_service.get_by_date(user_id, tomorrow)
        elif timeframe == "this_week":
            # 이번 주 모든 일정 (월요일부터 일요일)
            start_of_week = now - timedelta(days=now.weekday())
            end_of_week = start_of_week + timedelta(days=6)

            all_schedules = schedule_service.get_by_user(user_id)
            schedules = [
                s for s in all_schedules
                if start_of_week.date() <= s.date.date() <= end_of_week.date()
            ]
        else:  # "all"
            schedules = schedule_service.get_by_user(user_id)

        print(f"[FOUND] {len(schedules)} schedule(s)")

        # 일정 포맷팅
        formatted_message = None
        if schedules:
            schedule_lines = []
            for idx, schedule in enumerate(schedules, 1):
                date_str = schedule.date.strftime("%Y-%m-%d (%A)")
                time_str = schedule.time if schedule.time else "시간 미정"
                place_str = f" @ {schedule.place_name}" if schedule.place_name else ""

                schedule_lines.append(
                    f"{idx}. [{date_str} {time_str}] {schedule.title}{place_str}"
                )

            formatted_message = "\n".join(schedule_lines)

        # 응답 데이터 준비
        schedules_data = [
            {
                "id": s.id,
                "title": s.title,
                "date": s.date.isoformat(),
                "time": s.time,
                "place_name": s.place_name,
                "latitude": s.latitude,
                "longitude": s.longitude,
                "address": s.address
            }
            for s in schedules
        ]

        print(f"[RESPONSE]\n{formatted_message if formatted_message else 'No schedules'}\n")
        print(f"{'='*60}\n")

        result = {
            "action_taken": "schedules_retrieved",
            "schedules": schedules_data,
            "count": len(schedules),
            "timeframe": timeframe,
        }

        # 일정이 있을 때만 improved_message 설정 (OpenAI 메시지 유지)
        if formatted_message:
            result["formatted_message"] = formatted_message
            result["improved_message"] = formatted_message

        return result

    def _handle_generate_course(self, session: dict, intent: dict, user_id: str = None) -> dict:
        """데이트 코스 생성 처리"""

        # pending_data 초기화
        session["pending_data"] = {}

        if not user_id:
            return {
                "action_taken": "error",
                "message": "로그인이 필요합니다."
            }

        extracted = intent.get("extracted_data", {})

        # 날짜 추출 (기본값: 오늘)
        date_str = extracted.get("date")
        if not date_str:
            date_str = datetime.now().strftime("%Y-%m-%d")

        # 템플릿 추출 (기본값: auto - 페르소나 기반)
        template = extracted.get("course_template", "auto")

        # 사용자 커스터마이징 설정
        preferences = None
        start_time = extracted.get("start_time")
        duration = extracted.get("duration")
        exclude_slots = extracted.get("exclude_slots")

        if start_time or duration or exclude_slots:
            preferences = CoursePreferences(
                start_time=start_time,
                duration=int(duration) if duration else None,
                exclude=exclude_slots
            )

        print(f"\n{'='*60}")
        print(f"[GENERATE COURSE]")
        print(f"   User ID: {user_id}")
        print(f"   Date: {date_str}")
        print(f"   Template: {template}")
        print(f"   Preferences: {preferences}")
        print(f"{'='*60}\n")

        try:
            # CourseService를 통해 코스 생성
            course = self.course_service.generate_date_course(
                user_id=user_id,
                date=date_str,
                template=template,
                preferences=preferences
            )

            # 세션에 생성된 코스 저장
            session["generated_course"] = course

            # 코스 정보를 보기 좋게 포맷팅
            course_lines = []
            course_lines.append(f"📅 {date_str} ({course.start_time} - {course.end_time})")
            course_lines.append(f"🚶 총 이동 거리: {course.total_distance}km")
            course_lines.append(f"⏱️ 총 소요 시간: {course.total_duration}분\n")

            for idx, slot in enumerate(course.slots, 1):
                time_info = f"{slot.start_time} ({slot.duration}분)"
                course_lines.append(f"{idx}. {slot.emoji} [{time_info}] {slot.place_name}")
                if slot.distance_from_previous:
                    course_lines.append(f"   └ 이전 장소에서 {slot.distance_from_previous}km")

            formatted_message = "\n".join(course_lines)

            print(f"\n[COURSE GENERATED]")
            print(formatted_message)
            print(f"{'='*60}\n")

            # 응답 데이터 준비
            course_data = {
                "date": course.date,
                "template": course.template,
                "start_time": course.start_time,
                "end_time": course.end_time,
                "total_distance": course.total_distance,
                "total_duration": course.total_duration,
                "slots": [
                    {
                        "slot_type": s.slot_type,
                        "emoji": s.emoji,
                        "start_time": s.start_time,
                        "duration": s.duration,
                        "place_name": s.place_name,
                        "place_address": s.place_address,
                        "latitude": s.latitude,
                        "longitude": s.longitude,
                        "rating": s.rating,
                        "score": s.score,
                        "distance_from_previous": s.distance_from_previous
                    }
                    for s in course.slots
                ]
            }

            return {
                "action_taken": "course_generated",
                "course": course_data,
                "formatted_message": formatted_message,
                "improved_message": formatted_message
            }

        except Exception as e:
            print(f"[ERROR] Failed to generate course: {e}")
            import traceback
            traceback.print_exc()

            return {
                "action_taken": "error",
                "message": f"코스 생성 중 오류가 발생했습니다: {str(e)}"
            }

    def _handle_regenerate_course_slot(self, session: dict, intent: dict, user_id: str = None) -> dict:
        """코스의 특정 슬롯 재생성 처리"""

        # 세션에 저장된 코스 확인
        if "generated_course" not in session:
            return {
                "action_taken": "error",
                "message": "재생성할 코스가 없습니다. 먼저 코스를 생성해주세요."
            }

        if not user_id:
            return {
                "action_taken": "error",
                "message": "로그인이 필요합니다."
            }

        extracted = intent.get("extracted_data", {})
        slot_index = extracted.get("slot_index")

        if slot_index is None:
            return {
                "action_taken": "error",
                "message": "재생성할 슬롯 번호를 지정해주세요. (예: '1번 슬롯 다른 장소로')"
            }

        # slot_index는 1부터 시작하는 사용자 입력을 0-based로 변환
        slot_index = int(slot_index) - 1

        print(f"\n{'='*60}")
        print(f"[REGENERATE SLOT] #{slot_index}")
        print(f"{'='*60}\n")

        try:
            course = session["generated_course"]

            # CourseService를 통해 슬롯 재생성
            updated_course = self.course_service.regenerate_course_slot(
                course=course,
                slot_index=slot_index,
                user_id=user_id
            )

            # 세션에 업데이트된 코스 저장
            session["generated_course"] = updated_course

            # 변경된 슬롯 정보
            new_slot = updated_course.slots[slot_index]

            # 응답 메시지
            message = f"✅ {slot_index + 1}번 슬롯을 다른 장소로 변경했어요!\n\n"
            message += f"{new_slot.emoji} [{new_slot.start_time}] {new_slot.place_name}"
            if new_slot.place_address:
                message += f"\n📍 {new_slot.place_address}"
            if new_slot.rating:
                message += f"\n⭐ 평점: {new_slot.rating}"

            # 코스 전체 데이터도 함께 반환
            course_data = {
                "date": updated_course.date,
                "template": updated_course.template,
                "start_time": updated_course.start_time,
                "end_time": updated_course.end_time,
                "total_distance": updated_course.total_distance,
                "total_duration": updated_course.total_duration,
                "slots": [
                    {
                        "slot_type": s.slot_type,
                        "emoji": s.emoji,
                        "start_time": s.start_time,
                        "duration": s.duration,
                        "place_name": s.place_name,
                        "place_address": s.place_address,
                        "latitude": s.latitude,
                        "longitude": s.longitude,
                        "rating": s.rating,
                        "score": s.score,
                        "distance_from_previous": s.distance_from_previous
                    }
                    for s in updated_course.slots
                ]
            }

            print(f"\n[SUCCESS] Slot regenerated successfully")
            print(f"   Returning improved_message: {message[:80]}...")

            return {
                "action_taken": "slot_regenerated",
                "slot_index": slot_index,
                "improved_message": message,
                "course": course_data
            }

        except ValueError as e:
            print(f"[ERROR] ValueError in regenerate: {e}")
            return {
                "action_taken": "error",
                "message": f"잘못된 슬롯 번호입니다: {str(e)}"
            }
        except Exception as e:
            print(f"[ERROR] Failed to regenerate slot: {e}")
            import traceback
            traceback.print_exc()

            return {
                "action_taken": "error",
                "message": f"슬롯 재생성 중 오류가 발생했습니다: {str(e)}"
            }