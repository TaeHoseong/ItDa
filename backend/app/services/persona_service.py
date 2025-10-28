from typing import Dict
from app.schemas.persona import ChatRequest, ChatResponse
from app.services.openai_service import analyze_intent
from app.services.schedule_service import ScheduleService

class PersonaService:
    def __init__(self, sessions: Dict):
        self.sessions = sessions
        self.schedule_service = ScheduleService()

    async def process_message(self, request: ChatRequest) -> ChatResponse:
        # 세션 초기화
        if request.session_id not in self.sessions:
            self.sessions[request.session_id] = {
                "history": [],
                "pending_data": {}
            }

        session = self.sessions[request.session_id]

        # AI 분석
        intent = await analyze_intent(
            message=request.message,
            context=session["pending_data"],
            history=session["history"]
        )

        # 히스토리 업데이트
        session["history"].extend([
            {"role": "user", "content": request.message},
            {"role": "assistant", "content": intent["message"]}
        ])
        if len(session["history"]) > 10:
            session["history"] = session["history"][-10:]

        response_data = None

        # 액션 처리
        if intent["action"] == "create_schedule":
            extracted = intent.get("extracted_data", {})
            schedule_data = {**session["pending_data"], **extracted}

            if self._is_complete(schedule_data):
                schedule = await self.schedule_service.create(schedule_data)
                response_data = {"schedule": schedule}
                session["pending_data"] = {}
                intent["message"] = f"일정 생성 완료! 📅\n{schedule['title']} - {schedule['date']} {schedule['time']}"
            else:
                session["pending_data"] = schedule_data
                intent["action"] = "update_info"

        elif intent["action"] == "update_info":
            extracted = intent.get("extracted_data", {})
            if extracted:
                session["pending_data"].update(extracted)
            response_data = {"pending_data": session["pending_data"]}

        return ChatResponse(
            message=intent["message"],
            action=intent["action"],
            data=response_data
        )

    def _is_complete(self, data: dict) -> bool:
        required = ["title", "date", "time"]
        return all(data.get(field) for field in required)