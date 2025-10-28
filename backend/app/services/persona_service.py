from typing import Dict
from app.schemas.persona import ChatRequest, ChatResponse
from app.services.openai_service import analyze_intent
from app.services.schedule_service import ScheduleService

class PersonaService:
    def __init__(self, sessions: Dict):
        self.sessions = sessions
        self.schedule_service = ScheduleService()

    async def process_message(self, request: ChatRequest) -> ChatResponse:
        """사용자 메시지 처리"""

        # 1️⃣ 세션 초기화
        if request.session_id not in self.sessions:
            self.sessions[request.session_id] = {
                "history": [],
                "pending_data": {}
            }

        session = self.sessions[request.session_id]

        print(f"\n{'🔵'*30}")
        print(f"📨 새 메시지: {request.message}")
        print(f"📦 세션 ID: {request.session_id}")
        print(f"📋 기존 pending_data: {session['pending_data']}")
        print(f"{'🔵'*30}\n")

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
            # 🔥 새로 추출된 정보를 pending_data에 병합
            for key, value in extracted.items():
                if value:  # None이나 빈 값이 아닌 경우만
                    session["pending_data"][key] = value

            print(f"✅ pending_data 업데이트됨: {session['pending_data']}")

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
        print(f"💬 일반 대화 → pending_data 초기화")

        return {
            "action_taken": "general_chat"
        }

    def _handle_update_info(self, session: dict, intent: dict) -> dict:
        """정보 수집 중"""
        missing = self._check_missing_fields(session["pending_data"])

        print(f"📝 정보 수집 중")
        print(f"   현재 데이터: {session['pending_data']}")
        print(f"   부족한 필드: {missing}")

        return {
            "action_taken": "update_info",
            "pending_data": session["pending_data"],
            "missing_fields": missing
        }

    async def _handle_create_schedule(self, session: dict, intent: dict) -> dict:
        """일정 생성 시도"""

        # pending_data 사용 (이미 병합됨)
        schedule_data = session["pending_data"].copy()

        print(f"\n📅 일정 생성 시도")
        print(f"   데이터: {schedule_data}")

        # 필수 정보 체크
        is_complete = self._is_complete(schedule_data)

        if is_complete:
            # ✅ 정보 충분 → DB 저장
            schedule = await self.schedule_service.create(schedule_data)
            session["pending_data"] = {}  # 초기화

            print(f"✅ 일정 생성 완료!")
            print(f"   {schedule}\n")

            # 메시지 개선
            improved_message = (
                f"일정이 생성되었습니다! ✅\n\n"
                f"📌 {schedule['title']}\n"
                f"📅 {schedule['date']}\n"
                f"⏰ {schedule['time']}"
            )

            return {
                "action_taken": "schedule_created",
                "schedule": schedule,
                "improved_message": improved_message
            }
        else:
            # ❌ 정보 부족
            missing = self._check_missing_fields(schedule_data)

            print(f"❌ 정보 부족")
            print(f"   부족한 필드: {missing}\n")

            return {
                "action_taken": "need_more_info",
                "pending_data": schedule_data,
                "missing_fields": missing
            }

    async def _handle_update_schedule(self, session: dict, intent: dict) -> dict:
        """일정 수정 처리"""

        extracted = intent.get("extracted_data", {})
        action_type = extracted.get("action_type")

        print(f"\n🔄 일정 수정 시도")
        print(f"   타입: {action_type}")
        print(f"   데이터: {extracted}")

        # 수정할 일정 찾기
        schedules = await self.schedule_service.get_all()

        # 조건에 맞는 일정 찾기
        target_schedule = None

        # 날짜로 찾기
        if extracted.get("date"):
            for s in schedules:
                if s.get("date") == extracted["date"]:
                    target_schedule = s
                    break

        # 제목으로 찾기
        if not target_schedule and extracted.get("title"):
            for s in schedules:
                if extracted["title"] in s.get("title", ""):
                    target_schedule = s
                    break

        # 가장 최근 일정 (아무 조건 없으면)
        if not target_schedule and schedules:
            target_schedule = schedules[-1]

        if not target_schedule:
            return {
                "action_taken": "schedule_not_found",
                "message": "수정할 일정을 찾을 수 없어요. 어떤 일정을 수정하시겠어요? 🤔"
            }

        # 취소
        if action_type == "cancel":
            await self.schedule_service.delete(target_schedule["id"])
            print(f"❌ 일정 삭제됨: {target_schedule['title']}")

            return {
                "action_taken": "schedule_cancelled",
                "deleted_schedule": target_schedule,
                "message": f"{target_schedule['title']} 일정을 취소했어요!"
            }

        # 수정
        elif action_type == "modify":
            field = extracted.get("field")
            new_value = extracted.get("new_value")

            if field and new_value:
                updates = {field: new_value}
                updated = await self.schedule_service.update(target_schedule["id"], updates)

                print(f"✅ 일정 수정됨:")
                print(f"   {target_schedule[field]} → {new_value}")

                return {
                    "action_taken": "schedule_updated",
                    "old_schedule": target_schedule,
                    "updated_schedule": updated,
                    "message": f"일정을 수정했어요! ✅"
                }

        return {
            "action_taken": "update_failed",
            "message": "일정 수정에 실패했어요. 다시 시도해주세요."
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