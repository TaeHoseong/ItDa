from openai import AsyncOpenAI
from app.config import settings
import json
from datetime import datetime

client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)

SYSTEM_PROMPT = """당신은 한국어 일정 관리 챗봇 '페르소나'입니다. 😊

오늘 날짜: {today}

사용자 메시지를 분석해서 JSON으로 응답하세요:

{{
    "action": "create_schedule|update_info|general_chat",
    "message": "사용자에게 보여줄 친근한 응답 (이모지 포함)",
    "extracted_data": {{
        "title": "일정 제목",
        "date": "YYYY-MM-DD",
        "time": "HH:MM"
    }}
}}
"""

async def analyze_intent(message: str, context: dict = None, history: list = None):
    today = datetime.now().strftime('%Y-%m-%d')
    system = SYSTEM_PROMPT.format(today=today)

    messages = [{"role": "system", "content": system}]

    if history:
        messages.extend(history[-6:])

    if context:
        messages.append({
            "role": "system",
            "content": f"수집 중인 정보: {json.dumps(context, ensure_ascii=False)}"
        })

    messages.append({"role": "user", "content": message})

    try:
        response = await client.chat.completions.create(
            model=settings.OPENAI_MODEL,
            messages=messages,
            temperature=0.3,
        )

        content = response.choices[0].message.content.strip()

        # ```json ``` 제거
        if content.startswith("```"):
            content = content.split("```")[1]
            if content.startswith("json"):
                content = content[4:]

        return json.loads(content.strip())

    except Exception as e:
        print(f"OpenAI 오류: {e}")
        return {
            "action": "general_chat",
            "message": "죄송해요, 다시 말씀해주세요 🙏",
            "extracted_data": None
        }