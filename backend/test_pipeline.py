"""파이프라인 테스트용 pending 데이터 생성"""
from app.core.supabase_client import get_supabase

supabase = get_supabase()

# 테스트 데이터 - 실제 존재하는 장소로
test_candidates = [
    {
        "place_hash": "test_hash_001",
        "canonical_name": "스타벅스 송도센트럴파크점",
        "canonical_address": "인천광역시 연수구 센트럴로 194 A동 101호",
        "canonical_category": "카페",
        "latitude": 37.3925,
        "longitude": 126.6404,
        "user_count": 6,  # 승격 조건 충족
        "user_ids": ["user1", "user2", "user3", "user4", "user5", "user6"],
        "features_status": "pending",
        "is_promoted": False
    },
    {
        "place_hash": "test_hash_002",
        "canonical_name": "송도 센트럴파크",
        "canonical_address": "인천광역시 연수구 컨벤시아대로 160",
        "canonical_category": "공원",
        "latitude": 37.3917,
        "longitude": 126.6401,
        "user_count": 3,  # 승격 조건 미충족
        "user_ids": ["user1", "user2", "user3"],
        "features_status": "pending",
        "is_promoted": False
    }
]

print("테스트 데이터 삽입 중...")

for candidate in test_candidates:
    try:
        # 기존 데이터 삭제 (중복 방지)
        supabase.table("place_adoption_candidates") \
            .delete() \
            .eq("place_hash", candidate["place_hash"]) \
            .execute()

        # 새로 삽입
        result = supabase.table("place_adoption_candidates") \
            .insert(candidate) \
            .execute()
        print(f"✅ 삽입 완료: {candidate['canonical_name']}")
    except Exception as e:
        print(f"❌ 삽입 실패: {candidate['canonical_name']} - {e}")

# 상태 확인
print("\n현재 place_adoption_candidates 상태:")
result = supabase.table("place_adoption_candidates") \
    .select("canonical_name, features_status, user_count, is_promoted") \
    .execute()

for row in result.data:
    print(f"  - {row['canonical_name']}: status={row['features_status']}, count={row['user_count']}, promoted={row['is_promoted']}")
