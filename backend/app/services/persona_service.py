from typing import Dict
from datetime import datetime, timedelta
from app.schemas.persona import ChatRequest, ChatResponse
from app.services.openai_service import analyze_intent
from app.services.schedule_service import ScheduleService
from app.services.suggest_service import SuggestService
from sqlalchemy.orm import Session

class PersonaService:
    def __init__(self, sessions: Dict, db: Session = None):
        self.sessions = sessions
        self.db = db
        self.suggest_service = SuggestService()

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
        elif action == "select_place":
            response_data = await self._handle_select_place(session, intent)
        elif action == "view_schedule":
            response_data = self._handle_view_schedule(intent, request.user_id)

        return ChatResponse(
            message=intent["message"],
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
        # 유저가 원하는 특정한 음식이 있을 경우

        print(f"\n{'='*60}")
        print(f"[RECOMMENDATION START]")
        print(f"   User ID: {user_id}")
        print(f"{'='*60}\n")

        # suggest_service를 통해 추천 장소 가져오기 (user_id 전달)
        places = self.suggest_service.get_recommendations(user_id=user_id, specific_food=specific_food, k=5)

        # 세션에 추천된 장소 저장 (장소 선택 시 사용)
        session["recommended_places"] = places

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

    def _handle_view_schedule(self, intent: dict, user_id: str = None) -> dict:
        """일정 조회 처리"""

        if not self.db:
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
        print(f"{'='*60}\n")

        # ScheduleService 인스턴스 생성 (DB session 전달)
        schedule_service = ScheduleService(self.db)

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
        if not schedules:
            formatted_message = "등록된 일정이 없습니다. 😊"
        else:
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

        print(f"[RESPONSE]\n{formatted_message}\n")
        print(f"{'='*60}\n")

        return {
            "action_taken": "schedules_retrieved",
            "schedules": schedules_data,
            "count": len(schedules),
            "timeframe": timeframe,
            "formatted_message": formatted_message
        }