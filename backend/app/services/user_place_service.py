"""
개인 장소 (User Places) 서비스
"""
import hashlib
import copy
from typing import Optional, List, Dict
from app.core.supabase_client import get_supabase


# 카테고리별 기본 features (20차원 벡터 구조)
# extracted_features.json 형식과 동일
DEFAULT_FEATURES = {
    "food": {
        "placeFeatures": {
            "mainCategory": {
                "food": 1.0, "cafe": 0.2, "culture_art": 0.0,
                "activity_sports": 0.0, "nature_healing": 0.0,
                "craft_experience": 0.0, "shopping": 0.0
            },
            "atmosphere": {
                "quiet": 0.4, "romantic": 0.4, "trendy": 0.5,
                "private": 0.3, "artistic": 0.2, "energetic": 0.5
            },
            "experienceType": {
                "passive_enjoyment": 0.7, "active_participation": 0.2,
                "social_bonding": 0.7, "relaxation_focused": 0.5
            },
            "spaceCharacteristics": {
                "indoor_ratio": 0.9, "crowdedness_expected": 0.5,
                "photo_worthiness": 0.4, "scenic_view": 0.2
            },
            "contextual": {
                "average_rating": 0,
                "max_travel_distance": 0
            }
        }
    },
    "cafe": {
        "placeFeatures": {
            "mainCategory": {
                "food": 0.3, "cafe": 1.0, "culture_art": 0.1,
                "activity_sports": 0.0, "nature_healing": 0.1,
                "craft_experience": 0.0, "shopping": 0.0
            },
            "atmosphere": {
                "quiet": 0.6, "romantic": 0.5, "trendy": 0.6,
                "private": 0.4, "artistic": 0.4, "energetic": 0.3
            },
            "experienceType": {
                "passive_enjoyment": 0.8, "active_participation": 0.1,
                "social_bonding": 0.6, "relaxation_focused": 0.7
            },
            "spaceCharacteristics": {
                "indoor_ratio": 0.85, "crowdedness_expected": 0.4,
                "photo_worthiness": 0.6, "scenic_view": 0.3
            },
            "contextual": {
                "average_rating": 0,
                "max_travel_distance": 0
            }
        }
    },
    "activity": {
        "placeFeatures": {
            "mainCategory": {
                "food": 0.0, "cafe": 0.0, "culture_art": 0.2,
                "activity_sports": 1.0, "nature_healing": 0.3,
                "craft_experience": 0.2, "shopping": 0.0
            },
            "atmosphere": {
                "quiet": 0.2, "romantic": 0.3, "trendy": 0.5,
                "private": 0.2, "artistic": 0.2, "energetic": 0.9
            },
            "experienceType": {
                "passive_enjoyment": 0.2, "active_participation": 0.9,
                "social_bonding": 0.7, "relaxation_focused": 0.2
            },
            "spaceCharacteristics": {
                "indoor_ratio": 0.5, "crowdedness_expected": 0.6,
                "photo_worthiness": 0.5, "scenic_view": 0.4
            },
            "contextual": {
                "average_rating": 0,
                "max_travel_distance": 0
            }
        }
    },
    "culture": {
        "placeFeatures": {
            "mainCategory": {
                "food": 0.0, "cafe": 0.1, "culture_art": 1.0,
                "activity_sports": 0.1, "nature_healing": 0.2,
                "craft_experience": 0.3, "shopping": 0.1
            },
            "atmosphere": {
                "quiet": 0.7, "romantic": 0.5, "trendy": 0.5,
                "private": 0.4, "artistic": 0.9, "energetic": 0.3
            },
            "experienceType": {
                "passive_enjoyment": 0.8, "active_participation": 0.3,
                "social_bonding": 0.5, "relaxation_focused": 0.6
            },
            "spaceCharacteristics": {
                "indoor_ratio": 0.8, "crowdedness_expected": 0.5,
                "photo_worthiness": 0.7, "scenic_view": 0.4
            },
            "contextual": {
                "average_rating": 0,
                "max_travel_distance": 0
            }
        }
    },
    "nature": {
        "placeFeatures": {
            "mainCategory": {
                "food": 0.0, "cafe": 0.0, "culture_art": 0.1,
                "activity_sports": 0.3, "nature_healing": 1.0,
                "craft_experience": 0.0, "shopping": 0.0
            },
            "atmosphere": {
                "quiet": 0.8, "romantic": 0.7, "trendy": 0.3,
                "private": 0.5, "artistic": 0.4, "energetic": 0.3
            },
            "experienceType": {
                "passive_enjoyment": 0.6, "active_participation": 0.4,
                "social_bonding": 0.5, "relaxation_focused": 0.9
            },
            "spaceCharacteristics": {
                "indoor_ratio": 0.1, "crowdedness_expected": 0.3,
                "photo_worthiness": 0.8, "scenic_view": 0.9
            },
            "contextual": {
                "average_rating": 0,
                "max_travel_distance": 0
            }
        }
    }
}

# 중립 features (카테고리 매핑 실패 시)
NEUTRAL_FEATURES = {
    "placeFeatures": {
        "mainCategory": {
            "food": 0.5, "cafe": 0.5, "culture_art": 0.5,
            "activity_sports": 0.5, "nature_healing": 0.5,
            "craft_experience": 0.5, "shopping": 0.5
        },
        "atmosphere": {
            "quiet": 0.5, "romantic": 0.5, "trendy": 0.5,
            "private": 0.5, "artistic": 0.5, "energetic": 0.5
        },
        "experienceType": {
            "passive_enjoyment": 0.5, "active_participation": 0.5,
            "social_bonding": 0.5, "relaxation_focused": 0.5
        },
        "spaceCharacteristics": {
            "indoor_ratio": 0.5, "crowdedness_expected": 0.5,
            "photo_worthiness": 0.5, "scenic_view": 0.5
        },
        "contextual": {
            "average_rating": 0,
            "max_travel_distance": 0
        }
    }
}


class UserPlaceService:
    def __init__(self):
        self.supabase = get_supabase()

    @staticmethod
    def generate_place_hash(name: str, lat: float, lng: float) -> str:
        """장소 고유 해시 생성 (중복 검사용)"""
        # 소수점 5자리까지 정규화 (약 1m 정밀도)
        normalized = f"{name}:{lat:.5f}:{lng:.5f}"
        return hashlib.sha256(normalized.encode()).hexdigest()

    @staticmethod
    def get_default_features(category: Optional[str]) -> dict:
        """
        카테고리 기반 기본 features 반환

        네이버 Local Search API 카테고리 형식: "대분류>세부분류"
        예시:
        - "음식점>육류,고기요리"
        - "카페,디저트>카페"
        - "문화,예술>박물관"
        - "스포츠,레저>볼링장"
        - "여행,명소>궁궐"
        """
        if not category:
            return copy.deepcopy(NEUTRAL_FEATURES)

        # 대분류 추출 (첫 번째 ">" 앞부분)
        main_category = category.split(">")[0].lower()

        # 1단계: 대분류 기반 매핑 (확실한 매핑)
        # 네이버 API 대분류 목록 기반
        if '음식점' in main_category:
            return copy.deepcopy(DEFAULT_FEATURES["food"])
        if '카페' in main_category or '디저트' in main_category:
            return copy.deepcopy(DEFAULT_FEATURES["cafe"])
        if '스포츠' in main_category or '레저' in main_category:
            return copy.deepcopy(DEFAULT_FEATURES["activity"])
        if '관람' in main_category or '체험' in main_category:
            return copy.deepcopy(DEFAULT_FEATURES["activity"])
        if '문화' in main_category or '예술' in main_category:
            return copy.deepcopy(DEFAULT_FEATURES["culture"])
        if '여행' in main_category or '명소' in main_category:
            return copy.deepcopy(DEFAULT_FEATURES["nature"])

        # 2단계: 대분류 매핑 실패 시 NEUTRAL 반환
        # (세부분류 추측보다 안전한 기본값 사용)
        return copy.deepcopy(NEUTRAL_FEATURES)

    def add_user_place(self, user_id: str, data: dict) -> dict:
        """
        개인 장소 추가 + 승격 후보 카운트 증가

        - 정식 DB(places)에 있는 장소는 저장하지 않음
        - 개인 DB(user_places)에 이미 있으면 기존 데이터 반환
        """
        place_hash = self.generate_place_hash(
            data["name"], data["latitude"], data["longitude"]
        )

        # 1. 정식 DB(places)에 있는지 확인 (이름 + 좌표 근사 비교)
        # 0.0001도 ≈ 약 11m 오차 범위
        official = self.supabase.table("places") \
            .select("place_id") \
            .eq("name", data["name"]) \
            .gte("latitude", data["latitude"] - 0.0001) \
            .lte("latitude", data["latitude"] + 0.0001) \
            .gte("longitude", data["longitude"] - 0.0001) \
            .lte("longitude", data["longitude"] + 0.0001) \
            .execute()

        if official.data:
            # 정식 DB에 있으면 저장하지 않고 None 반환
            return None

        # 2. 이미 이 유저가 추가했는지 확인
        existing = self.supabase.table("user_places") \
            .select("*") \
            .eq("user_id", user_id) \
            .eq("place_hash", place_hash) \
            .execute()

        if existing.data:
            # 이미 있으면 기존 데이터 그대로 반환 (중복 추가 무시)
            return existing.data[0]

        # 3. 기본 features 할당
        default_features = self.get_default_features(data.get("category"))

        # 4. user_places에 추가
        new_place = {
            "place_hash": place_hash,
            "name": data["name"],
            "address": data.get("address"),
            "category": data.get("category"),
            "latitude": data["latitude"],
            "longitude": data["longitude"],
            "naver_data": data.get("naver_data"),
            "user_id": user_id,
            "features": default_features,
            "features_status": "default",
            "added_from": data["added_from"]
        }

        result = self.supabase.table("user_places") \
            .insert(new_place) \
            .select() \
            .execute()

        # 5. place_adoption_candidates 업데이트 (실패해도 진행)
        try:
            self._update_adoption_candidate(place_hash, user_id, data)
        except Exception as e:
            print(f"[WARNING] adoption_candidate 업데이트 실패: {e}")

        return result.data[0]

    def _update_adoption_candidate(self, place_hash: str, user_id: str, data: dict):
        """승격 후보 테이블 업데이트 (atomic operation via RPC)"""
        self.supabase.rpc("add_adoption_candidate", {
            "p_place_hash": place_hash,
            "p_user_id": user_id,
            "p_name": data["name"],
            "p_address": data.get("address"),
            "p_category": data.get("category"),
            "p_latitude": data["latitude"],
            "p_longitude": data["longitude"]
        }).execute()

    def get_user_places(
        self,
        user_id: str,
        has_features: Optional[bool] = None
    ) -> List[dict]:
        """유저의 개인 장소 목록 조회"""
        query = self.supabase.table("user_places") \
            .select("*") \
            .eq("user_id", user_id)

        if has_features is True:
            # features가 계산된 것만 (default 또는 completed)
            query = query.in_("features_status", ["default", "completed"])
        elif has_features is False:
            # features가 없는 것만
            query = query.in_("features_status", ["pending", "processing", "failed"])

        result = query.order("created_at", desc=True).execute()
        return result.data

    def get_user_place(self, user_id: str, user_place_id: str) -> Optional[dict]:
        """개인 장소 단건 조회"""
        result = self.supabase.table("user_places") \
            .select("*") \
            .eq("user_id", user_id) \
            .eq("user_place_id", user_place_id) \
            .execute()

        return result.data[0] if result.data else None

    def delete_user_place(self, user_id: str, user_place_id: str) -> bool:
        """개인 장소 삭제"""
        # 1. 삭제할 장소의 place_hash 먼저 조회
        place = self.get_user_place(user_id, user_place_id)
        if not place:
            return False

        place_hash = place["place_hash"]

        # 2. user_places에서 삭제
        result = self.supabase.table("user_places") \
            .delete() \
            .eq("user_id", user_id) \
            .eq("user_place_id", user_place_id) \
            .execute()

        if not result.data:
            return False

        # 3. adoption_candidate에서 user_id 제거 (실패해도 진행)
        try:
            self.supabase.rpc("remove_from_adoption_candidate", {
                "p_place_hash": place_hash,
                "p_user_id": user_id
            }).execute()
        except Exception as e:
            print(f"[WARNING] adoption_candidate에서 유저 제거 실패: {e}")

        return True
