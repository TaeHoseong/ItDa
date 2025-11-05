"""
전체 플로우 통합 테스트
Phase 3 검증: 챗봇 → OpenAI 인텐트 → 추천 서비스 → 터미널 출력
"""
import sys
import asyncio
from pathlib import Path
from dotenv import load_dotenv

# app 모듈을 import하기 위한 경로 설정
backend_path = Path(__file__).parent
sys.path.insert(0, str(backend_path))

# .env 파일 명시적 로드
env_path = backend_path / ".env"
load_dotenv(env_path)

from app.services.persona_service import PersonaService
from app.schemas.persona import ChatRequest


async def test_integration():
    """전체 플로우 통합 테스트"""
    print("\n" + "="*60)
    print("Integration Test: Full Recommendation Flow")
    print("="*60 + "\n")

    # PersonaService 초기화
    sessions = {}
    persona_service = PersonaService(sessions)

    test_cases = [
        # 장소 추천 요청
        {"session_id": "test1", "message": "장소 추천해줘"},

        # 기존 일정 관리 기능 (동작 확인)
        {"session_id": "test2", "message": "내일 3시 회의"},
    ]

    for idx, case in enumerate(test_cases, 1):
        print(f"\n{'='*60}")
        print(f"Test {idx}: {case['message']}")
        print("="*60)

        try:
            request = ChatRequest(**case)
            response = await persona_service.process_message(request)

            print(f"\n[Response]")
            print(f"  Action:  {response.action}")
            print(f"  Message: {response.message}")

            if response.data:
                print(f"  Data:")
                if response.action == "recommend_place":
                    places = response.data.get("places", [])
                    print(f"    - Count: {response.data.get('count')}")
                    print(f"    - Places:")
                    for i, place in enumerate(places[:3], 1):  # 처음 3개만 출력
                        print(f"      {i}. {place['name']} (Score: {place['score']})")
                else:
                    for key, value in response.data.items():
                        print(f"    - {key}: {value}")

            print(f"\n[PASS] Test {idx} PASSED")

        except Exception as e:
            print(f"\n[FAIL] Test {idx} FAILED: {e}")
            import traceback
            traceback.print_exc()
            return False

    print("\n" + "="*60)
    print("ALL INTEGRATION TESTS PASSED!")
    print("="*60 + "\n")

    return True


if __name__ == "__main__":
    success = asyncio.run(test_integration())
    sys.exit(0 if success else 1)
