"""
장소 추천 서비스
algorithm.py를 import하여 사용 (수정 없이 재사용)
"""
import sys
from pathlib import Path
from typing import List, Dict, Optional
from app.core.supabase_client import get_supabase

# backend/algorithm.py를 import하기 위한 경로 설정
backend_path = Path(__file__).parent.parent.parent
sys.path.insert(0, str(backend_path))

# algorithm.py import (수정 없이 사용)
import algorithm

class SuggestService:
    """장소 추천 서비스"""

    def __init__(self):
        # 임시 하드코딩 페르소나 (20-dim vector)
        # 향후 DB에서 사용자별 페르소나를 가져올 예정
        self.default_persona = [
            1, 0, 0, 0, 0, 0,  # mainCategory (6)
            0.9, 0.7, 0.5, 0.8, 0.8, 0.3,  # atmosphere (6)
            0.8, 0.1, 0.7, 0.9,  # experienceType (4)
            0.95, 0.3, 0.8, 0.4  # spaceCharacteristics (4)
        ]

        self.supabase = get_supabase()

    def get_user_persona(self, user_id: str) -> Optional[List[float]]:
        """
        DB에서 사용자 페르소나를 가져옴

        Args:
            user_id: User's unique identifier (Google ID)

        Returns:
            20차원 페르소나 벡터 or None (페르소나가 완료되지 않은 경우)
        """
        user = (
            self.supabase.table("users")
            .select("*")
            .eq("user_id", user_id)
            .single()
            .execute()
        )

        if not user.data:
            return None
        
        data = user.data

        if not data.get("survey_done"):
            return None
        
        return [
            data["food_cafe"], data["culture_art"], data["activity_sports"],
            data["nature_healing"], data["craft_experience"], data["shopping"],
            data["quiet"], data["romantic"], data["trendy"], data["private_vibe"],
            data["artistic"], data["energetic"],
            data["passive_enjoyment"], data["active_participation"],
            data["social_bonding"], data["relaxation_focused"],
            data["indoor_ratio"], data["crowdedness_expected"],
            data["photo_worthiness"], data["scenic_view"]
        ]
        
    def get_candidate_places(self, specific_food):
        import time
        from app.external.google_search import search_place_google_v1
        all_places = []
        page_token = None
        place_query = f"송도 {specific_food} 맛집"
        print(f"🔍 '{place_query}' 검색 중...")

        for _ in range(5):
            result = search_place_google_v1(place_query, page_token)
            if not result or "places" not in result:
                break

            all_places.extend(result["places"])
            page_token = result.get("nextPageToken")
            if not page_token or len(all_places) >= 15:
                break
            time.sleep(2)

        print(f"✅ 총 {len(all_places)}개 장소 수집 완료")
        candidate_names = []
        for p in all_places:
            candidate_names.append(p["displayName"]["text"])
        return candidate_names
    def get_recommendations(
        self,
        last_recommend=None,
        category: str = None,
        specific_food: str = None,
        persona: Optional[List[float]] = None,
        user_id: Optional[str] = None,
        k: int = 5,
        alpha: float = 0.8,
        beta: float = 0.7,
        gamma: float = 0.2,
        delta: float = 0.4
    ) -> List[Dict]:
        """
        장소 추천 메인 함수
        algorithm.py의 recommend_topk()를 호출하여 추천 결과 반환

        Args:
            persona: 20차원 페르소나 벡터 (우선순위 1)
            user_id: User ID (우선순위 2, persona가 None일 때 DB에서 조회)
            k: 추천할 장소 개수
            alpha: similarity 가중치
            beta: distance 가중치
            gamma: rating 가중치
            delta: price 가중치

        Returns:
            [{"name": str, "score": float}, ...]
        """
        # 페르소나 우선순위: 직접 전달 > user_id로 조회 > default
        persona_source = "직접 전달"
        if persona is None:
            if user_id:
                persona = self.get_user_persona(user_id)
                if persona:
                    persona_source = f"DB 조회 (user_id: {user_id})"
            if persona is None:
                persona = self.default_persona
                persona_source = "기본값 (default)"

        # 페르소나 값 출력
        print(f"\n{'='*60}")
        print(f"[PERSONA USED] Source: {persona_source}")
        print(f"{'='*60}")
        print(f"Main Category (6):")
        print(f"  food_cafe: {persona[0]:.2f}, culture_art: {persona[1]:.2f}, activity_sports: {persona[2]:.2f}")
        print(f"  nature_healing: {persona[3]:.2f}, craft_experience: {persona[4]:.2f}, shopping: {persona[5]:.2f}")
        print(f"\nAtmosphere (6):")
        print(f"  quiet: {persona[6]:.2f}, romantic: {persona[7]:.2f}, trendy: {persona[8]:.2f}")
        print(f"  private_vibe: {persona[9]:.2f}, artistic: {persona[10]:.2f}, energetic: {persona[11]:.2f}")
        print(f"\nExperience Type (4):")
        print(f"  passive_enjoyment: {persona[12]:.2f}, active_participation: {persona[13]:.2f}")
        print(f"  social_bonding: {persona[14]:.2f}, relaxation_focused: {persona[15]:.2f}")
        print(f"\nSpace Characteristics (4):")
        print(f"  indoor_ratio: {persona[16]:.2f}, crowdedness_expected: {persona[17]:.2f}")
        print(f"  photo_worthiness: {persona[18]:.2f}, scenic_view: {persona[19]:.2f}")
        print(f"{'='*60}\n")
        candidates=None
        # 특정 음식이 있는 경우 검색 먼저
        if specific_food:
            print(f"search for food {specific_food}...")
            candidates = self.get_candidate_places(specific_food)

        # algorithm.py의 recommend_topk() 호출 (수정 없이 사용)
        try:
            results = algorithm.recommend_topk(
                persona=persona,
                last_recommend=last_recommend,
                category=category,
                candidate_names=candidates,
                k=k,
                alpha=alpha,
                beta=beta,
                gamma=gamma,
                delta=delta
            )
        except Exception as e:
            print(e)

        # results는 [(name, score), ...] 형태
        # DB에서 상세 정보를 가져와서 병합
        places = (
            self.supabase
            .table("places")
            .select("*")
            .execute()
        )
        places = places.data or []

        formatted_results = []

        for name, score in results:
            detail = next((p for p in places if p["name"] == name), None)
            if not detail:
                continue

            place_info = {
                "name": detail["name"],
                "score": round(float(score), 2),
                "category": detail.get("category"),
                "address": detail.get("address"),
                "latitude": detail.get("latitude"),
                "longitude": detail.get("longitude"),
                "rating": detail.get("rating"),
                "price_range": detail.get("price_range"),
                "opening_hours": detail.get("opening_hours"),
            }
            formatted_results.append(place_info)

        return formatted_results
