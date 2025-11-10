"""
장소 추천 서비스
algorithm.py를 import하여 사용 (수정 없이 재사용)
"""
import sys
import sqlite3
from pathlib import Path
from typing import List, Dict, Optional

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

        # DB 경로 (backend 폴더 기준 상위 디렉토리의 test.db)
        self.db_path = str(backend_path / ".." / "test.db")

    def get_user_persona(self, user_id: str) -> Optional[List[float]]:
        """
        DB에서 사용자 페르소나를 가져옴

        Args:
            user_id: User's unique identifier (Google ID)

        Returns:
            20차원 페르소나 벡터 or None (페르소나가 완료되지 않은 경우)
        """
        conn = sqlite3.connect(self.db_path)
        cur = conn.cursor()

        # 사용자 페르소나 조회
        cur.execute("""
            SELECT food_cafe, culture_art, activity_sports, nature_healing, craft_experience, shopping,
                   quiet, romantic, trendy, private_vibe, artistic, energetic,
                   passive_enjoyment, active_participation, social_bonding, relaxation_focused,
                   indoor_ratio, crowdedness_expected, photo_worthiness, scenic_view,
                   persona_completed
            FROM users
            WHERE user_id = ?
        """, (user_id,))

        row = cur.fetchone()
        conn.close()

        if not row:
            return None

        # persona_completed가 False이면 None 반환
        if not row[20]:  # persona_completed column
            return None

        # 20차원 벡터로 변환
        persona = list(row[:20])
        return persona

    def get_recommendations(
        self,
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

        # algorithm.py의 recommend_topk() 호출 (수정 없이 사용)
        # 첫 번째 인자로 db 경로 전달
        results = algorithm.recommend_topk(
            db=self.db_path,
            persona=persona,
            k=k,
            alpha=alpha,
            beta=beta,
            gamma=gamma,
            delta=delta
        )

        # results는 [(name, score), ...] 형태
        # DB에서 상세 정보를 가져와서 병합
        formatted_results = []

        # DB 연결
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row  # 딕셔너리 형태로 결과 반환
        cur = conn.cursor()

        for name, score in results:
            # 장소 상세 정보 조회
            cur.execute("""
                SELECT name, category, address, latitude, longitude,
                       rating, price_range, opening_hours
                FROM places
                WHERE name = ?
            """, (name,))

            row = cur.fetchone()
            if row:
                place_info = {
                    "name": row["name"],
                    "score": round(float(score), 2),
                    "category": row["category"],
                    "address": row["address"],
                    "latitude": row["latitude"],
                    "longitude": row["longitude"],
                    "rating": row["rating"],
                    "price_range": row["price_range"],
                    "opening_hours": row["opening_hours"]
                }
                formatted_results.append(place_info)

        conn.close()
        return formatted_results
