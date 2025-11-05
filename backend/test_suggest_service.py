"""
suggest_service.py 테스트 스크립트
Phase 1 검증용: algorithm.py import 및 추천 기능 동작 확인
"""
import sys
from pathlib import Path

# app 모듈을 import하기 위한 경로 설정
backend_path = Path(__file__).parent
sys.path.insert(0, str(backend_path))

from app.services.suggest_service import SuggestService


def test_suggest_service():
    """suggest_service basic functionality test"""
    print("\n" + "="*60)
    print("SuggestService Test Started")
    print("="*60 + "\n")

    try:
        # Create SuggestService instance
        print("Step 1: Creating SuggestService instance...")
        service = SuggestService()
        print("   SUCCESS\n")

        # Run recommendation
        print("Step 2: Running place recommendation (top 5)...")
        results = service.get_recommendations(k=5)
        print("   SUCCESS\n")

        # Print results
        print("Step 3: Recommendation Results:")
        print("-" * 60)
        for idx, place in enumerate(results, 1):
            print(f"   {idx}. {place['name']:<40} | Score: {place['score']:.2f}")
        print("-" * 60 + "\n")

        # Validation
        assert len(results) == 5, "Result count is not 5"
        assert all('name' in p and 'score' in p for p in results), "Result format is incorrect"

        print("="*60)
        print("ALL TESTS PASSED!")
        print("="*60 + "\n")

        return True

    except Exception as e:
        print(f"\nTEST FAILED: {e}\n")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    success = test_suggest_service()
    sys.exit(0 if success else 1)
