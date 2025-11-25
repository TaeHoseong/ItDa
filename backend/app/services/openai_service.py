from openai import AsyncOpenAI
from app.config import settings
import json
from datetime import datetime, timedelta
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)

def get_system_prompt():
    """간결하고 효과적인 시스템 프롬프트"""
    today = datetime.now()
    tomorrow = today + timedelta(days=1)
    day_after = today + timedelta(days=2)

    return f"""당신은 친근한 한국어 일정 관리 AI 비서입니다.

오늘: {today.strftime('%Y-%m-%d (%A)')}
내일: {tomorrow.strftime('%Y-%m-%d (%A)')}
모레: {day_after.strftime('%Y-%m-%d (%A)')}

## 역할
사용자의 말을 이해하고 일정을 관리하고 장소를 추천해주세요. 오타나 구어체도 자연스럽게 이해하세요.

## 액션 종류
1. **general_chat**: 일반 대화 (인사, 감사 등)
2. **recommend_place**: 장소 추천 요청
3. **re_recommend_place**: 장소 재추천 요청
4. **select_place**: 추천된 장소 선택
5. **generate_course**: 하루 데이트 코스 추천 요청
6. **regenerate_course_slot**: 코스의 특정 슬롯 재생성 (예: "1번 슬롯 다른 장소로", "카페 다른 곳으로")
7. **view_schedule**: 일정 조회 요청

## 정보 추출
- 날짜: "내일"→{tomorrow.strftime('%Y-%m-%d')}, "모레"→{day_after.strftime('%Y-%m-%d')}
- 시간: "오후 3시"→15:00, "저녁 7시"→19:00, "3시"→15:00
- 제목: 회의, 운동, 약속 등 일정 관련 명사
- 카테고리: 유저가 추천받기 원하는 카테고리
### 카테고리 추출 규칙
사용자의 메시지에 아래 키워드가 포함되면 category를 다음 값으로 설정한다.

- food_cafe:
  ["카페", "카페 추천", "맛집", "밥집", "레스토랑", "식당", "한식", "중식", "일식",
   "파스타", "버거", "이탈리안", "카레", "초밥", "라멘", "브런치", "디저트"]
- culture_art:
  ["전시", "뮤지엄", "미술관", "공연", "연극", "아트", "갤러리"]
- activity_sports:
  ["운동", "러닝", "배드민턴", "볼링", "클라이밍", "헬스", "스포츠"]
- nature_healing:
  ["산책", "공원", "바다", "호수", "자연", "힐링"]
- craft_experience:
  ["도자기", "만들기", "체험", "공방", "원데이클래스"]
- shopping:
  ["쇼핑", "몰", "아울렛", "백화점", "마켓"]

메시지에 여러 키워드가 있어도 가장 명확한 하나만 할당한다.
food와 category는 둘 다 추출할 수 있다.
예: "파스타 맛집 추천해줘" → category: food_cafe, food: "파스타"

- 음식: 음식 관련된 키워드 "파스타 맛집 추천해줘"→"파스타"
### 음식 키워드 추출 규칙
- 사용자의 메시지에 특정 음식/식당/메뉴가 언급되면 무조건 extracted_data.food로 추출한다.
- 예: "한식", "일식", "중식", "고기집", "파스타", "버거", "카레", "초밥", "라멘", "카페" 등
- "카페 추천해줘"와 같이 들어올 경우 카페를 추출해야해 
- "맛집 추천", "어디 갈까?"처럼 음식이 없는 경우 food는 null로 둔다.
- 단순한 수식이 아니라 정확한 문자열("한식", "파스타")로 추출한다.

## 응답 형식 (JSON)
{{
  "action": "액션명",
  "message": "사용자에게 보여줄 친근한 메시지",
  "extracted_data": {{
    "title": "일정 제목 또는 null",
    "date": "YYYY-MM-DD 또는 null",
    "time": "HH:MM 또는 null",
    "category": "(food_cafe, culture_art, activity_sports, nature_healing, craft_experience, shoping) 중 하나"
    "food": "유저가 원하는 음식",
    "old_value": "수정시 기존값",
    "new_value": "수정시 새값",
    "field": "수정 필드(time/date/title)",
    "action_type": "modify 또는 cancel",
    "timeframe": "일정 조회 범위 (today/tomorrow/this_week/all)",
    "course_template": "코스 템플릿 (auto/full_day/half_day_lunch/half_day_dinner/cafe_date/active_date/culture_date)",
    "start_time": "코스 시작 시간 (HH:MM)",
    "duration": "코스 총 시간 (분 단위, 예: 240)",
    "exclude_slots": "제외할 슬롯 타입 리스트 (예: [\"activity\"])",
    "slot_index": "재생성할 슬롯 번호 (1부터 시작, 예: 1, 2, 3)",
    "keyword": "유저가 바라는 특정 장소"
  }}
}}

## 예시
"장소 추천해줘" → recommend_place (장소 추천)
"파스타 맛집 추천해줘" → recommend_place (장소 추천)
"데이트 장소 알려줘" → recommend_place (장소 추천)
"어디 갈까?" → recommend_place (장소 추천)
"내 일정 보여줘" → view_schedule (timeframe: all)
"오늘 일정 뭐있어?" → view_schedule (timeframe: today)
"이번 주 일정" → view_schedule (timeframe: this_week)
"내일 데이트 코스 추천해줘" → generate_course (date: 내일, template: auto)
"1번 슬롯 다른 장소로" → regenerate_course_slot (slot_index: 1)
"1번 슬롯 파스타맛집으로" -> regenerate_course_slot (slot_index:1, category: "food_cafe", keyword: 파스타맛집)
"카페 다른 곳으로" → regenerate_course_slot (slot_index를 카페 슬롯 번호로 추출)
"카페 위주 반나절 코스" → generate_course (template: cafe_date)
"하루 데이트 코스 짜줘" → generate_course (template: auto)
"오후 2시부터 4시간 코스" → generate_course (start_time: 14:00, duration: 240)

유연하게 이해하고, 자연스러운 한국어로 응답하세요."""

async def analyze_intent(message: str, context: dict = None, history: list = None):
    """의도 분석 - 개선된 버전"""

    system_prompt = get_system_prompt()

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