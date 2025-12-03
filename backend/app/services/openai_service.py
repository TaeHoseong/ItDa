from openai import AsyncOpenAI
from app.config import settings
from app.core.extra_features import get_extra_feature_service
import json
from datetime import datetime, timedelta
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)

def get_intent_system_prompt():
    """간결하고 효과적인 시스템 프롬프트"""
    today = datetime.now()
    tomorrow = today + timedelta(days=1)
    day_after = today + timedelta(days=2)

    return f"""당신은 친근한 한국어 일정 관리 AI 비서입니다.

오늘: {today.strftime('%Y-%m-%d (%A)')}
내일: {tomorrow.strftime('%Y-%m-%d (%A)')}
모레: {day_after.strftime('%Y-%m-%d (%A)')}

## 역할
사용자의 말을 이해하고 사용자가 어떠한 액션을 원하는지 알아내주세요. 오타나 구어체도 자연스럽게 이해하세요.

## 액션 종류
1. **general_chat**: 일반 대화 (인사, 감사 등)
2. **recommend_place**: 장소 추천 요청
3. **re_recommend_place**: 장소 재추천 요청
4. **select_place**: 추천된 장소 선택
5. **generate_course**: 하루 데이트 코스 추천 요청
6. **regenerate_course_slot**: 코스의 특정 슬롯 재생성 (예: "1번 슬롯 다른 장소로", "카페 다른 곳으로")
7. **view_schedule**: 일정 조회 요청
8. **update_info**: 정보 업데이트
## 응답 형식 (JSON)
{{
  "action": "액션명",
  "message": "사용자에게 보여줄 친근한 메시지",
}}

## 예시
"장소 추천해줘" → recommend_place (장소 추천)
"파스타 맛집 추천해줘" → recommend_place (장소 추천)
"데이트 장소 알려줘" → recommend_place (장소 추천)
"어디 갈까?" → recommend_place (장소 추천)
"내 일정 보여줘" → view_schedule
"오늘 일정 뭐있어?" → view_schedule
"이번 주 일정" → view_schedule
"1번 장소 맘에 들어" → select_place
"내일 데이트 코스 추천해줘" → generate_course
"1번 슬롯 다른 장소로" → regenerate_course_slot
"1번 슬롯 파스타맛집으로" -> regenerate_course_slot
"카페 다른 곳으로" → regenerate_course_slot
"카페 위주 반나절 코스" → generate_course
"하루 데이트 코스 짜줘" → generate_course
"오후 2시부터 4시간 코스" → generate_course
"내일 8시에 갈래" → update_info (select place 이후에만 가능)

유연하게 이해하고, 자연스러운 한국어로 응답하세요."""

def get_action_prompt(action:str):
    today = datetime.now()
    tomorrow = today + timedelta(days=1)
    day_after = today + timedelta(days=2)
    prompt = ""
    if action == 'recommend_place':
        prompt = f"""
            당신은 장소 추천을 위한 파라미터 추출기입니다.
            사용자 입력에서 다음 세 가지 값을 JSON으로 추출하세요:
            메시지에 여러 키워드가 있어도 가장 명확한 하나만 할당한다.
            food와 category는 둘 다 추출할 수 있다.
            예: "파스타 맛집 추천해줘" → category: food, food: "파스타"
            
            1. specific_food  
            - 사용자가 특정 음식/메뉴를 언급했을 때만 값 설정  
            - 예: 파스타, 초밥, 라멘, 스테이크  
            - 없다면 null

            2. category  
            - 입력 문맥에서 주요 카테고리를 유추  
            - food / cafe / culture_art / activity_sports / nature_healing / craft_experience / shopping 중 하나  
            - 없다면 null
            
            3. {get_extra_feature_service().get_prompt_fragment()}

            출력 형식(중요!):
            {{
            "specific_food": "...",
            "category": "...",
            "extra_feature": "..."
            }}
        """
    if action == "select_place":
        prompt = """
        당신은 사용자의 선택 문장을 이해하고 아래 두 값을 JSON 형태로 추출하는 모델입니다.

        ## 해야 할 일
        사용자가 추천된 장소 중 어떤 것을 선택했는지 분석하여 다음 정보를 JSON으로 반환하세요:

        - place_index: 사용자가 말한 번호 (정수, 없으면 null)
        - place_name: 사용자가 직접 말한 장소 이름 (문자열, 없으면 null)

        ## 추출 규칙
        1. 사용자가 “1번”, “#2”, “3번 장소”, “2번 추천” 등 번호를 말하면 place_index에 정수를 넣으세요.
        2. 장소 이름을 직접 말하면 place_name에 넣으세요.
        3. 둘 다 말하면 둘 다 채웁니다.
        4. 둘 다 없으면 둘 다 null로 반환하세요.
        5. 번호는 한글/기호 모두 지원:
        - "1번", "1 번", "#1", "번호 1", "첫 번째" → 1
        - "두 번째", "세 번째" → 2, 3
        6. 장소 이름은 문장 속에서 자연어로 등장하는 부분을 그대로 추출합니다.

        ## 응답 형식(JSON)
        {
        "place_index": 1,
        "place_name": "스타벅스"
        }
            """
    if action == "update_info":
        prompt = f"""
        오늘: {today.strftime('%Y-%m-%d (%A)')}
        내일: {tomorrow.strftime('%Y-%m-%d (%A)')}
        모레: {day_after.strftime('%Y-%m-%d (%A)')}
        당신은 한국어 문장에서 날짜(date), 시간(time), 제목(title)을 추출하는 AI입니다.  
        사용자의 메세지에서 필요한 정보를 구조화된 JSON으로 반환하세요.

        ### 규칙
        1. 날짜(date)
        - YYYY-MM-DD 형식으로 변환
        - "오늘", "내일", "모레", "이번 주 금요일", "다음 주 화요일" 모두 처리
        - 숫자 날짜: "3월 5일", "12/28", "5일", "25일" 처리
        - 연도가 없으면 올해 혹은 다음 날짜로 자연스럽게 해석

        2. 시간(time)
        - HH:MM 형식으로 변환
        - "오전/오후", "AM/PM", "정오", "자정", "저녁 7시", "밤 10시 반", "3시 반" 모두 처리
        - 분이 생략된 경우 00분으로 설정
        - "30분", "반" → :30 로 해석

        3. 제목(title)
        문맥상 "무엇을 위한 일정인지" 추출
        예: 약속, 데이트, 점심, 저녁식사, 수업, 운동, 회의 등
        명확하지 않으면 null

        4. 비어 있는 경우 null로 출력

        ### 출력 형식(JSON)
        {{
            "title": string or null,
            "date": string or null,
            "time": string or null
        }}

        """
    return prompt

async def analyze_intent(message: str, context: dict = None, history: list = None):
    """의도 분석 - 개선된 버전"""

    system_prompt = get_intent_system_prompt()
    messages = [{"role": "system", "content": system_prompt}]

    # 🔥 대화 히스토리 더 많이 포함 (2턴 → 6턴)
    if history:
        messages.extend(history[-12:])  # 최근 6턴

    # context 정보
    if context and any(context.values()):
        context_info = []
        if context.get("title"):
            context_info.append(f"제목: {context['title']}")
        if context.get("date"):
            context_info.append(f"날짜: {context['date']}")
        if context.get("time"):
            context_info.append(f"시간: {context['time']}")

        if context_info:
            messages.append({
                "role": "system",
                "content": f"현재까지 수집된 정보: {', '.join(context_info)}"
            })

    messages.append({"role": "user", "content": message})

    logger.info(f"\n{'='*60}")
    logger.info(f"📤 입력: {message}")
    if context:
        logger.info(f"📋 Context: {context}")

    try:
        response = await client.chat.completions.create(
            model=settings.OPENAI_MODEL,
            messages=messages,
            temperature=0.3,  # 🔥 0.1 → 0.3 (더 창의적)
            max_tokens=500,   # 🔥 300 → 500 (더 긴 응답)
            response_format={"type": "json_object"}
        )

        content = response.choices[0].message.content.strip()
        logger.info(f"📥 응답: {content[:200]}...")

        result = json.loads(content)

        # 기본값 설정
        if "extracted_data" not in result:
            result["extracted_data"] = {}

        logger.info(f"✅ 액션: {result.get('action')}")
        logger.info(f"✅ 추출: {result.get('extracted_data')}")
        logger.info(f"{'='*60}\n")

        return result

    except Exception as e:
        logger.error(f"❌ OpenAI 오류: {e}")
        return fallback_response(message, context)

async def extract_data(action:str, message: str):
    prompt = get_action_prompt(action)
    response = await client.chat.completions.create(
        model=settings.OPENAI_MODEL,
        messages=[
            {"role": "system", "content": prompt},   # 시스템 프롬프트
            {"role": "user", "content": message},    # 사용자의 실제 입력
        ],
        temperature=0.3,
        max_tokens=500,
        response_format={"type": "json_object"}
    )
    return json.loads(response.choices[0].message.content)

def fallback_response(message: str, context: dict = None) -> dict:
    """폴백 - 더 관대하게"""
    logger.warning(f"⚠️  폴백 모드")

    normalized = normalize_message(message)
    message_lower = normalized.lower().strip()
    extracted = extract_info_simple(normalized, context)

    # 인사
    if any(w in message_lower for w in ["안녕", "hi", "hello", "하이"]):
        return {
            "action": "general_chat",
            "message": "안녕하세요! 😊",
            "extracted_data": {}
        }

    # 감사
    if any(w in message_lower for w in ["고마", "감사", "thank"]):
        return {
            "action": "general_chat",
            "message": "천만에요! 😊",
            "extracted_data": {}
        }
        
    # 일정 조회 키워드
    view_keywords = ["일정 보여", "일정 알려", "일정 뭐", "일정 있어", "무슨 일정", "스케줄"]
    if any(kw in message_lower for kw in view_keywords):
        timeframe = "all"
        if "오늘" in message_lower:
            timeframe = "today"
        elif "내일" in message_lower:
            timeframe = "tomorrow"
        elif "이번 주" in message_lower or "이번주" in message_lower:
            timeframe = "this_week"

        return {
            "action": "view_schedule",
            "message": "일정을 확인해드릴게요! 📅",
            "extracted_data": {"timeframe": timeframe}
        }
        
    # 장소 추천 키워드
    recommend_keywords = ["추천", "장소", "어디", "데이트", "갈만한", "맛집", "카페"]
    if any(kw in message_lower for kw in recommend_keywords):
        return {
            "action": "recommend_place",
            "message": "좋은 장소를 추천해드릴게요! 😊",
            "extracted_data": {}
        }

    return {
        "action": "general_chat",
        "message": "무엇을 도와드릴까요? 😊",
        "extracted_data": {}
    }

def normalize_message(message: str) -> str:
    """오타 보정"""
    corrections = {
        "일졍": "일정", "만드러조": "만들어줘", "만들어조": "만들어줘",
        "추가해조": "추가해줘", "넣어조": "넣어줘"
    }
    result = message
    for typo, correct in corrections.items():
        result = result.replace(typo, correct)
    return result

def extract_info_simple(message: str, context: dict = None) -> dict:
    """패턴 매칭"""
    result = {**(context or {})}

    # 제목
    titles = ["회의", "미팅", "약속", "수업", "운동", "식사", "치과", "병원"]
    for title in titles:
        if title in message:
            result["title"] = title
            break

    if not result.get("title") and any(w in message for w in ["일정", "약속"]):
        result["title"] = "일정"

    # 날짜
    today = datetime.now()
    date_map = {"오늘": 0, "내일": 1, "모레": 2, "글피": 3}
    for word, days in date_map.items():
        if word in message:
            result["date"] = (today + timedelta(days=days)).strftime('%Y-%m-%d')
            break

    # 시간
    import re
    patterns = [
        (r'오전\s*(\d+)시', lambda h: f"{int(h):02d}:00"),
        (r'오후\s*(\d+)시', lambda h: f"{int(h)+12 if int(h)<12 else int(h):02d}:00"),
        (r'저녁\s*(\d+)시', lambda h: f"{int(h)+12 if int(h)<12 else int(h):02d}:00"),
        (r'(\d+)시', lambda h: f"{int(h):02d}:00" if int(h)<=9 else f"{int(h):02d}:00" if int(h)>=12 else f"{int(h)+12:02d}:00"),
    ]

    for pattern, converter in patterns:
        match = re.search(pattern, message)
        if match:
            result["time"] = converter(match.group(1))
            break

    return result