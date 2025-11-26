"""
Extra Feature 서비스
DB 기반으로 슬롯 재추천 시 분위기/가격/별점 등 추가 조건 관리
"""
from typing import List, Tuple, Optional, Dict
from app.core.supabase_client import get_supabase


class ExtraFeatureService:
    """Extra Feature DB 기반 서비스"""

    _instance = None
    _cache: Optional[Dict] = None

    def __new__(cls):
        """싱글톤 패턴"""
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        self.supabase = get_supabase()

    def get_all_features(self, force_refresh: bool = False) -> Dict:
        """
        DB에서 활성화된 extra feature 설정 로드 (캐시 사용)

        Args:
            force_refresh: True면 캐시 무시하고 DB에서 다시 로드

        Returns:
            {key: {type, index, weight_name, value, description, filter_field, filter_threshold}, ...}
        """
        if self._cache is None or force_refresh:
            response = (
                self.supabase.table("extra_features")
                .select("*")
                .eq("is_active", True)
                .execute()
            )
            self._cache = {
                row["key"]: {
                    "type": row["type"],
                    "index": row.get("index"),
                    "weight_name": row.get("weight_name"),
                    "value": row.get("value"),
                    "description": row["description"],
                    "filter_field": row.get("filter_field"),
                    "filter_threshold": row.get("filter_threshold"),
                }
                for row in response.data
            }
            print(f"[EXTRA_FEATURES] Loaded {len(self._cache)} features from DB")

        return self._cache

    def clear_cache(self):
        """캐시 무효화"""
        self._cache = None

    def get_filter_config(self, extra_feature: str) -> Optional[Dict]:
        """
        extra_feature가 filter 타입인 경우 필터 설정 반환

        Args:
            extra_feature: extra feature 키

        Returns:
            {"field": "atmosphere.romantic", "threshold": 0.6} 또는 None
        """
        features = self.get_all_features()

        if not extra_feature or extra_feature not in features:
            return None

        config = features[extra_feature]
        if config["type"] == "filter" and config.get("filter_field"):
            return {
                "field": config["filter_field"],
                "threshold": config.get("filter_threshold", 0.5)
            }

        return None

    def get_prompt_fragment(self) -> str:
        """
        OpenAI 프롬프트용 extra_feature 설명 동적 생성

        Returns:
            프롬프트에 삽입할 문자열
        """
        features = self.get_all_features()
        keys = "/".join(features.keys())
        return f'"extra_feature": "추가 조건 ({keys}) 중 하나 또는 null"'

    def get_prompt_examples(self) -> str:
        """
        OpenAI 프롬프트용 예시 문장 동적 생성

        Returns:
            예시 문장 문자열
        """
        features = self.get_all_features()
        examples = []
        for key, config in features.items():
            desc = config["description"]
            examples.append(f'"{desc} 곳으로" → regenerate_course_slot (extra_feature: {key})')

        return "\n".join(examples[:4])  # 너무 길면 4개만

    def apply(
        self,
        persona: List[float],
        alpha: float,
        beta: float,
        gamma: float,
        delta: float,
        extra_feature: Optional[str]
    ) -> Tuple[List[float], float, float, float, float]:
        """
        extra_feature에 따른 가중치 조정 (weight 타입만 처리)

        Args:
            persona: 20차원 페르소나 벡터
            alpha: similarity 가중치
            beta: distance 가중치
            gamma: rating 가중치
            delta: price 가중치
            extra_feature: 적용할 extra feature 키

        Returns:
            (persona, alpha, beta, gamma, delta) 튜플
        """
        features = self.get_all_features()

        if not extra_feature or extra_feature not in features:
            return list(persona), alpha, beta, gamma, delta

        config = features[extra_feature]

        # weight 타입만 처리 (filter 타입은 algorithm.py에서 필터링으로 처리)
        if config["type"] == "weight":
            weight_name = config["weight_name"]
            weight_value = config["value"]

            if weight_name == "gamma":
                gamma = weight_value
                print(f"[EXTRA_FEATURE] Applied {extra_feature}: gamma = {weight_value}")
            elif weight_name == "delta":
                delta = weight_value
                print(f"[EXTRA_FEATURE] Applied {extra_feature}: delta = {weight_value}")
            elif weight_name == "alpha":
                alpha = weight_value
                print(f"[EXTRA_FEATURE] Applied {extra_feature}: alpha = {weight_value}")
            elif weight_name == "beta":
                beta = weight_value
                print(f"[EXTRA_FEATURE] Applied {extra_feature}: beta = {weight_value}")

        return list(persona), alpha, beta, gamma, delta


# 모듈 레벨 싱글톤 인스턴스
_service = None


def get_extra_feature_service() -> ExtraFeatureService:
    """ExtraFeatureService 싱글톤 인스턴스 반환"""
    global _service
    if _service is None:
        _service = ExtraFeatureService()
    return _service
