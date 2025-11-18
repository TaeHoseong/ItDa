"""
챗봇 코스 생성 테스트
"""
import sys
import asyncio
from pathlib import Path

# UTF-8 인코딩 설정
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

# 경로 설정
backend_path = Path(__file__).parent
sys.path.insert(0, str(backend_path))

from app.services.persona_service import PersonaService
from app.schemas.persona import ChatRequest


async def test_course_generation():
    """코스 생성 챗봇 테스트"""

    # PersonaService 초기화
    sessions = {}
    service = PersonaService(sessions=sessions)

    # 테스트 사용자 ID (페르소나 완료된 사용자)
    user_id = "102928578341147999188"
    session_id = "test_session_course"

    test_cases = [
        "내일 데이트 코스 추천해줘",
        "하루 데이트 코스 짜줘",
        "카페 위주 반나절 코스",
        "오후 2시부터 4시간 코스",
    ]

    for idx, message in enumerate(test_cases, 1):
        print("\n" + "="*80)
        print(f"TEST {idx}: {message}")
        print("="*80)

        request = ChatRequest(
            session_id=session_id,
            message=message,
            user_id=user_id
        )

        try:
            response = await service.process_message(request)

            print("\n[CHATBOT RESPONSE]")
            print(f"Action: {response.action}")
            print(f"\nMessage:\n{response.message}")

            if response.data and "course" in response.data:
                course = response.data["course"]
                print(f"\n[COURSE DETAILS]")
                print(f"Template: {course['template']}")
                print(f"Date: {course['date']}")
                print(f"Time: {course['start_time']} - {course['end_time']}")
                print(f"Total Distance: {course['total_distance']}km")
                print(f"Total Duration: {course['total_duration']}min")
                print(f"\nSlots ({len(course['slots'])}):")
                for i, slot in enumerate(course['slots'], 1):
                    print(f"  {i}. {slot['emoji']} [{slot['start_time']}] {slot['slot_type']} - {slot['place_name']}")
                    if slot.get('distance_from_previous'):
                        print(f"     Distance: {slot['distance_from_previous']}km")

        except Exception as e:
            print(f"\n[ERROR] {e}")
            import traceback
            traceback.print_exc()

        # 다음 테스트를 위해 세션 초기화
        if session_id in sessions:
            sessions[session_id] = {"history": [], "pending_data": {}}


if __name__ == "__main__":
    print("\n" + "="*80)
    print("챗봇 코스 생성 테스트 시작")
    print("="*80)

    asyncio.run(test_course_generation())

    print("\n" + "="*80)
    print("[SUCCESS] ALL TESTS COMPLETED!")
    print("="*80)
