"""
피드백 학습 서비스
일기 별점 기반으로 커플 페르소나(20차원)를 자동 조정

재계산 방식:
- 일기 저장/수정 시 user1, user2의 features로 원본 페르소나 재계산
- 원본에서 시작해 모든 일기 별점 누적 적용
- DB 스키마 변경 없이 구현
"""
from typing import List, Optional, Dict, Any
from app.core.supabase_client import get_supabase


# features 딕셔너리 → 20차원 리스트 변환을 위한 키 순서
FEATURES_ORDER = [
    # Main Category (6)
    "food_cafe", "culture_art", "activity_sports", "nature_healing", "craft_experience", "shopping",
    # Atmosphere (6)
    "quiet", "romantic", "trendy", "private_vibe", "artistic", "energetic",
    # Experience Type (4)
    "passive_enjoyment", "active_participation", "social_bonding", "relaxation_focused",
    # Space Characteristics (4)
    "indoor_ratio", "crowdedness_expected", "photo_worthiness", "scenic_view",
]


def features_dict_to_list(features: dict) -> List[float]:
    """딕셔너리 형태의 features를 20차원 리스트로 변환"""
    if not features or not isinstance(features, dict):
        return []
    return [features.get(key, 0.0) for key in FEATURES_ORDER]


def extract_place_features(place_features: Dict[str, Any]) -> Optional[List[float]]:
    """
    places 테이블의 features JSON에서 20차원 벡터 추출
    algorithm.py의 extract_features()와 동일한 로직

    Args:
        place_features: places.features JSON (placeFeatures 구조)

    Returns:
        20차원 float 리스트 또는 None
    """
    if not place_features:
        return None

    try:
        features = place_features.get("placeFeatures", place_features)

        main_category = features["mainCategory"]
        food_cafe = 1 if main_category.get("food_cafe", 0) else 0
        main_category_values = [
            food_cafe,
            main_category.get("culture_art", 0),
            main_category.get("activity_sports", 0),
            main_category.get("nature_healing", 0),
            main_category.get("craft_experience", 0),
            main_category.get("shopping", 0),
        ]

        atmosphere = features["atmosphere"]
        atmosphere_values = [
            atmosphere.get("quiet", 0),
            atmosphere.get("romantic", 0),
            atmosphere.get("trendy", 0),
            atmosphere.get("private", 0),
            atmosphere.get("artistic", 0),
            atmosphere.get("energetic", 0),
        ]

        experience_type = features["experienceType"]
        experience_values = [
            experience_type.get("passive_enjoyment", 0),
            experience_type.get("active_participation", 0),
            experience_type.get("social_bonding", 0),
            experience_type.get("relaxation_focused", 0),
        ]

        space_chars = features["spaceCharacteristics"]
        space_values = [
            space_chars.get("indoor_ratio", 0),
            space_chars.get("crowdedness_expected", 0),
            space_chars.get("photo_worthiness", 0),
            space_chars.get("scenic_view", 0),
        ]

        return main_category_values + atmosphere_values + experience_values + space_values

    except (KeyError, TypeError) as e:
        print(f"[FEEDBACK] Feature extraction error: {e}")
        return None


def apply_single_feedback(
    current_persona: List[float],
    place_feature: List[float],
    rating: float
) -> List[float]:
    """
    단일 별점 피드백을 페르소나에 적용

    공식:
    - adjustment_ratio = (rating - 2.5) * 0.04
    - 별점 5.0 → +10% (장소 feature 방향으로 이동)
    - 별점 2.5 → 0% (변화 없음)
    - 별점 1.0 → -6% (장소 feature 반대 방향으로 이동)

    Args:
        current_persona: 현재 페르소나 (20차원)
        place_feature: 장소 feature 벡터 (20차원)
        rating: 별점 (1-5)

    Returns:
        조정된 페르소나 (20차원)
    """
    # 별점 2.5는 변화 없음
    if rating == 2.5:
        return current_persona

    adjustment_ratio = (rating - 2.5) * 0.04

    new_persona = []
    for i in range(20):
        delta = (place_feature[i] - current_persona[i]) * adjustment_ratio
        new_value = current_persona[i] + delta
        # 0-1 범위로 클램핑
        new_value = max(0.0, min(1.0, new_value))
        new_persona.append(round(new_value, 4))

    return new_persona


class FeedbackService:
    """피드백 학습 서비스"""

    def __init__(self):
        self.supabase = get_supabase()

    def _calculate_base_persona(self, couple_id: str) -> Optional[List[float]]:
        """
        user1, user2의 features로 원본 커플 페르소나 계산
        match.py의 로직과 동일 (남성*0.3 + 여성*0.7)

        Args:
            couple_id: 커플 ID

        Returns:
            20차원 원본 페르소나 또는 None
        """
        # 커플 정보에서 user_id1, user_id2 조회
        couple_response = (
            self.supabase.table("couples")
            .select("user_id1, user_id2")
            .eq("couple_id", couple_id)
            .single()
            .execute()
        )

        if not couple_response.data:
            print(f"[FEEDBACK] Couple not found: {couple_id}")
            return None

        user_id1 = couple_response.data.get("user_id1")
        user_id2 = couple_response.data.get("user_id2")

        # 두 사용자 정보 조회
        users_response = (
            self.supabase.table("users")
            .select("user_id, gender, features")
            .in_("user_id", [user_id1, user_id2])
            .execute()
        )

        if not users_response.data or len(users_response.data) < 2:
            print(f"[FEEDBACK] Users not found for couple: {couple_id}")
            return None

        # user1, user2 구분
        user1 = next((u for u in users_response.data if u["user_id"] == user_id1), None)
        user2 = next((u for u in users_response.data if u["user_id"] == user_id2), None)

        if not user1 or not user2:
            return None

        # features 변환 (딕셔너리 → 리스트)
        user1_features_raw = user1.get("features")
        user2_features_raw = user2.get("features")

        user1_features = features_dict_to_list(user1_features_raw) if isinstance(user1_features_raw, dict) else (user1_features_raw or [])
        user2_features = features_dict_to_list(user2_features_raw) if isinstance(user2_features_raw, dict) else (user2_features_raw or [])

        if len(user1_features) != 20 or len(user2_features) != 20:
            print(f"[FEEDBACK] Invalid user features length")
            return None

        # 성별에 따라 가중치 적용 (match.py와 동일 로직)
        user1_gender = user1.get("gender")
        user2_gender = user2.get("gender")

        if user1_gender == "M" and user2_gender == "F":
            base_persona = [
                user1_features[i] * 0.3 + user2_features[i] * 0.7
                for i in range(20)
            ]
        elif user1_gender == "F" and user2_gender == "M":
            base_persona = [
                user1_features[i] * 0.7 + user2_features[i] * 0.3
                for i in range(20)
            ]
        else:
            # 같은 성별이거나 성별 정보 없으면 평균
            base_persona = [
                (user1_features[i] + user2_features[i]) / 2
                for i in range(20)
            ]

        return base_persona

    def recalculate_couple_persona(self, couple_id: str) -> Dict[str, Any]:
        """
        커플의 모든 일기 별점을 기반으로 페르소나 재계산

        user1, user2의 features로 원본 계산 후 모든 일기 순회하며 누적 적용

        Args:
            couple_id: 커플 ID

        Returns:
            {
                "success": bool,
                "message": str,
                "diary_count": int,
                "feedback_count": int,
                "base_persona": List[float],
                "old_persona": List[float],
                "new_persona": List[float]
            }
        """
        result = {
            "success": False,
            "message": "",
            "diary_count": 0,
            "feedback_count": 0,
            "base_persona": None,
            "old_persona": None,
            "new_persona": None
        }

        # 1. 원본 페르소나 계산 (user1, user2 features 기반)
        base_persona = self._calculate_base_persona(couple_id)
        if not base_persona:
            result["message"] = f"Failed to calculate base persona for couple: {couple_id}"
            return result

        result["base_persona"] = base_persona

        # 2. 현재 페르소나 조회
        couple_response = (
            self.supabase.table("couples")
            .select("features")
            .eq("couple_id", couple_id)
            .single()
            .execute()
        )

        if couple_response.data:
            result["old_persona"] = couple_response.data.get("features")

        # 3. 해당 커플의 모든 일기 조회
        diary_response = (
            self.supabase.table("diary")
            .select("course_id, json")
            .eq("couple_id", couple_id)
            .execute()
        )

        diaries = diary_response.data or []
        result["diary_count"] = len(diaries)

        # 일기가 없으면 원본으로 복원
        if not diaries:
            self.supabase.table("couples").update({
                "features": base_persona
            }).eq("couple_id", couple_id).execute()

            result["success"] = True
            result["message"] = "No diaries - restored to base persona"
            result["new_persona"] = base_persona
            return result

        # 4. 모든 장소 feature 한번에 조회 (place_name을 키로 사용)
        places_response = self.supabase.table("places").select("name, features").execute()
        place_features_map = {}
        for p in places_response.data or []:
            if p.get("name") and p.get("features"):
                extracted = extract_place_features(p["features"])
                if extracted:
                    place_features_map[p["name"]] = extracted

        # 5. 원본에서 시작해 누적 계산
        current_persona = base_persona.copy()
        feedback_count = 0

        for diary in diaries:
            diary_json = diary.get("json", [])
            if not isinstance(diary_json, list):
                continue

            for slot in diary_json:
                place_name = slot.get("place_name")
                rating = slot.get("rating", 0)

                # place_name이나 rating이 없으면 스킵
                if not place_name or not rating or rating == 0:
                    continue

                # 장소 feature 찾기
                place_feature = place_features_map.get(place_name)
                if not place_feature:
                    continue

                # 피드백 적용
                current_persona = apply_single_feedback(current_persona, place_feature, rating)
                feedback_count += 1

        result["feedback_count"] = feedback_count

        # 6. 변화 확인 및 DB 업데이트
        if current_persona == result["old_persona"]:
            result["success"] = True
            result["message"] = "No change in persona"
            result["new_persona"] = current_persona
            return result

        update_response = (
            self.supabase.table("couples")
            .update({"features": current_persona})
            .eq("couple_id", couple_id)
            .execute()
        )

        if update_response.data:
            result["success"] = True
            result["message"] = f"Persona updated with {feedback_count} feedbacks from {len(diaries)} diaries"
            result["new_persona"] = current_persona

            # 변화량 로그
            print(f"[FEEDBACK] Couple {couple_id}: {feedback_count} feedbacks applied")
            changed_dims = []
            for i in range(20):
                diff = abs(current_persona[i] - base_persona[i])
                if diff > 0.001:
                    changed_dims.append(f"dim[{i}]: {base_persona[i]:.3f}→{current_persona[i]:.3f}")
            if changed_dims:
                print(f"[FEEDBACK] Changes: {', '.join(changed_dims[:5])}{'...' if len(changed_dims) > 5 else ''}")
        else:
            result["message"] = "Failed to update database"

        return result

    def get_persona_diff(self, couple_id: str) -> Dict[str, Any]:
        """
        원본 페르소나와 현재 features의 차이 조회 (디버깅용)

        Args:
            couple_id: 커플 ID

        Returns:
            {
                "base_persona": List[float],
                "current_features": List[float],
                "diff": List[float],
                "changed_dimensions": List[int]
            }
        """
        # 원본 계산
        base = self._calculate_base_persona(couple_id)
        if not base:
            return {"error": f"Failed to calculate base persona: {couple_id}"}

        # 현재 features 조회
        couple_response = (
            self.supabase.table("couples")
            .select("features")
            .eq("couple_id", couple_id)
            .single()
            .execute()
        )

        if not couple_response.data:
            return {"error": f"Couple not found: {couple_id}"}

        current = couple_response.data.get("features", [])

        if len(base) != 20 or len(current) != 20:
            return {"error": "Invalid persona dimensions"}

        diff = [round(current[i] - base[i], 4) for i in range(20)]
        changed = [i for i in range(20) if abs(diff[i]) > 0.001]

        return {
            "base_persona": base,
            "current_features": current,
            "diff": diff,
            "changed_dimensions": changed
        }
