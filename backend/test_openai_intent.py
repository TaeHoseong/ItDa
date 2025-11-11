"""
openai_service.py 인텐트 분석 테스트
Phase 2 검증: recommend_place 액션 추가 확인 + 기존 기능 유지 확인
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

from app.services.openai_service import analyze_intent


async def test_openai_intent():
    """OpenAI 인텐트 분석 테스트"""
    print("\n" + "="*60)
    print("OpenAI Intent Analysis Test")
    print("="*60 + "\n")

    test_cases = [
        # 새로운 기능: 장소 추천
        ("장소 추천해줘", "recommend_place"),
        ("데이트 장소 알려줘", "recommend_place"),
        ("어디 갈까?", "recommend_place"),
        # 필터링
        ("파스타 맛집 추천해줘", "recommend_place")
        # 기존 기능: 일정 관리
        ("내일 3시 회의", "create_schedule"),
        ("일정 만들어줘", "update_info"),

        # 기존 기능: 일반 대화
        ("안녕", "general_chat"),
    ]

    results = []

    for idx, (message, expected_action) in enumerate(test_cases, 1):
        print(f"Test {idx}: '{message}'")
        print("-" * 60)

        try:
            result = await analyze_intent(message)
            action = result.get("action")
            response_message = result.get("message")

            # 결과 확인
            is_correct = action == expected_action
            status = "PASS" if is_correct else "FAIL"

            print(f"   Expected: {expected_action}")
            print(f"   Got:      {action}")
            print(f"   Message:  {response_message}")
            print(f"   Status:   {status}")

            results.append({
                "message": message,
                "expected": expected_action,
                "actual": action,
                "pass": is_correct
            })

        except Exception as e:
            print(f"   ERROR: {e}")
            results.append({
                "message": message,
                "expected": expected_action,
                "actual": "ERROR",
                "pass": False
            })

        print()

    # 전체 결과 요약
    print("="*60)
    print("Summary")
    print("="*60)

    total = len(results)
    passed = sum(1 for r in results if r["pass"])
    failed = total - passed

    print(f"Total:  {total}")
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")

    if failed > 0:
        print("\nFailed Tests:")
        for r in results:
            if not r["pass"]:
                print(f"  - '{r['message']}': expected {r['expected']}, got {r['actual']}")

    print("="*60 + "\n")

    return failed == 0


if __name__ == "__main__":
    success = asyncio.run(test_openai_intent())
    sys.exit(0 if success else 1)
