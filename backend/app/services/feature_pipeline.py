"""
Feature Pipeline 서비스

개인 장소(user_places)와 승격 후보(place_adoption_candidates)의
features를 Google Places API + OpenAI로 정밀 계산하고,
조건 충족 시 공식 장소(places)로 승격하는 배치 파이프라인
"""
import json
import httpx
from typing import Optional, List, Dict, Any
from datetime import datetime
from openai import AsyncOpenAI

from app.config import settings
from app.core.supabase_client import get_supabase


# OpenAI 클라이언트
openai_client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)

# 승격 조건
PROMOTION_THRESHOLD = 5  # 5명 이상이 추가해야 승격


class FeaturePipelineService:
    def __init__(self):
        self.supabase = get_supabase()

    async def run_pipeline(self, limit: int = 10) -> Dict[str, Any]:
        """
        파이프라인 실행

        1. pending 상태의 승격 후보 조회 및 features 계산
        2. completed 상태 + user_count >= 5인 승격 대기 장소 처리

        Returns:
            처리 결과 요약
        """
        results = {
            "processed": 0,
            "features_calculated": 0,
            "promoted": 0,
            "promotion_ready_processed": 0,
            "errors": []
        }

        # Phase 1: pending 상태의 승격 후보 처리 (features 계산)
        candidates = self._get_pending_candidates(limit)

        for candidate in candidates:
            try:
                # 상태를 processing으로 변경
                self._update_candidate_status(candidate["place_hash"], "processing")

                # Google Places API로 상세정보 조회
                place_details = await self._fetch_google_place_details(
                    candidate["canonical_name"],
                    candidate["latitude"],
                    candidate["longitude"]
                )
                print(f"[FeaturePipeline] Google API 결과: {candidate['canonical_name']} -> {place_details is not None}")
                if place_details:
                    print(f"  - rating: {place_details.get('rating')}")
                    print(f"  - reviews: {len(place_details.get('reviews', []))}개")

                # OpenAI로 features 계산
                features = await self._calculate_features(
                    name=candidate["canonical_name"],
                    category=candidate.get("canonical_category"),
                    place_details=place_details
                )

                if features:
                    # DB 업데이트 (place_details도 함께 저장)
                    self._update_features(candidate["place_hash"], features, place_details)
                    results["features_calculated"] += 1

                    # candidate에 google_place_details 추가 (승격 시 사용)
                    candidate["google_place_details"] = place_details

                    # 최신 user_count 다시 조회 (features 계산 중 증가했을 수 있음)
                    updated = self.supabase.table("place_adoption_candidates") \
                        .select("user_count") \
                        .eq("place_hash", candidate["place_hash"]) \
                        .single() \
                        .execute()

                    current_user_count = updated.data["user_count"] if updated.data else candidate["user_count"]

                    # 승격 조건 체크
                    if current_user_count >= PROMOTION_THRESHOLD:
                        promoted = self._promote_to_official(candidate, features)
                        if promoted:
                            results["promoted"] += 1
                else:
                    # features 계산 실패
                    self._update_candidate_status(candidate["place_hash"], "failed")

                results["processed"] += 1

            except Exception as e:
                results["errors"].append({
                    "place_hash": candidate["place_hash"],
                    "name": candidate["canonical_name"],
                    "error": str(e)
                })
                self._update_candidate_status(candidate["place_hash"], "failed")

        # Phase 2: 승격 대기 장소 처리 (completed 상태 + user_count >= 5)
        ready_for_promotion = self._get_ready_for_promotion()

        for candidate in ready_for_promotion:
            try:
                promoted = self._promote_to_official(candidate, candidate["features"])
                if promoted:
                    results["promoted"] += 1
                results["promotion_ready_processed"] += 1
            except Exception as e:
                results["errors"].append({
                    "place_hash": candidate["place_hash"],
                    "name": candidate["canonical_name"],
                    "error": str(e)
                })

        return results

    def _get_pending_candidates(self, limit: int) -> List[dict]:
        """pending 상태의 승격 후보 조회"""
        result = self.supabase.table("place_adoption_candidates") \
            .select("*") \
            .eq("features_status", "pending") \
            .eq("is_promoted", False) \
            .limit(limit) \
            .execute()
        return result.data

    def _get_ready_for_promotion(self) -> List[dict]:
        """승격 대기 장소 조회 (completed 상태 + user_count >= 5 + 미승격)"""
        result = self.supabase.table("place_adoption_candidates") \
            .select("*") \
            .eq("features_status", "completed") \
            .eq("is_promoted", False) \
            .gte("user_count", PROMOTION_THRESHOLD) \
            .execute()
        return result.data or []

    def _update_candidate_status(self, place_hash: str, status: str):
        """승격 후보 상태 업데이트"""
        self.supabase.table("place_adoption_candidates") \
            .update({"features_status": status}) \
            .eq("place_hash", place_hash) \
            .execute()

    async def _fetch_google_place_details(
        self,
        name: str,
        lat: float,
        lng: float
    ) -> Optional[dict]:
        """Google Places API (New)로 장소 상세정보 조회"""
        if not settings.GOOGLE_PLACES_API_KEY:
            print("[FeaturePipeline] Google API 키 없음")
            return None

        try:
            async with httpx.AsyncClient() as client:
                # Places API (New) - Text Search
                search_url = "https://places.googleapis.com/v1/places:searchText"
                search_headers = {
                    "Content-Type": "application/json",
                    "X-Goog-Api-Key": settings.GOOGLE_PLACES_API_KEY,
                    "X-Goog-FieldMask": "places.id,places.displayName,places.rating,places.reviews,places.priceLevel,places.priceRange,places.regularOpeningHours.periods,places.regularOpeningHours.weekdayDescriptions,places.formattedAddress"
                }
                search_body = {
                    "textQuery": name,
                    "locationBias": {
                        "circle": {
                            "center": {"latitude": lat, "longitude": lng},
                            "radius": 500.0
                        }
                    },
                    "languageCode": "ko"
                }

                search_response = await client.post(search_url, headers=search_headers, json=search_body)
                search_data = search_response.json()

                print(f"[FeaturePipeline] Text Search 결과: {len(search_data.get('places', []))}개 장소")

                if not search_data.get("places"):
                    print(f"[FeaturePipeline] Text Search 실패: 결과 없음")
                    return None

                place = search_data["places"][0]

                # 새 API 형식을 기존 형식으로 변환
                result = {
                    "place_id": place.get("id"),  # Google Place ID (ChIJ... 형식)
                    "name": place.get("displayName", {}).get("text"),
                    "rating": place.get("rating"),
                    "reviews": [],
                    "price_range": None,  # 원문 그대로 저장 (예: "₩20,000~30,000")
                    "opening_hours": {},
                    "formatted_address": place.get("formattedAddress")
                }

                # reviews 변환
                if place.get("reviews"):
                    result["reviews"] = [
                        {"text": r.get("text", {}).get("text", "")}
                        for r in place["reviews"][:5]
                    ]

                # price_range 원문 저장 (startPrice ~ endPrice 형식)
                if place.get("priceRange"):
                    price_range = place["priceRange"]
                    start = price_range.get("startPrice", {})
                    end = price_range.get("endPrice", {})
                    start_text = f"₩{int(float(start.get('units', 0))):,}" if start.get('units') else None
                    end_text = f"₩{int(float(end.get('units', 0))):,}" if end.get('units') else None

                    if start_text and end_text:
                        result["price_range"] = f"{start_text}~{end_text}"
                    elif start_text:
                        result["price_range"] = f"{start_text}~"
                    elif end_text:
                        result["price_range"] = f"~{end_text}"

                # opening_hours 변환 (기존 형식에 맞춤: {"월": [{"open": "09:30", "close": "21:30"}], ...})
                if place.get("regularOpeningHours") and place["regularOpeningHours"].get("periods"):
                    day_map = {0: "일", 1: "월", 2: "화", 3: "수", 4: "목", 5: "금", 6: "토"}
                    opening_hours_dict = {}

                    for period in place["regularOpeningHours"]["periods"]:
                        open_info = period.get("open", {})
                        close_info = period.get("close", {})

                        day_num = open_info.get("day")
                        if day_num is not None:
                            day_name = day_map.get(day_num, str(day_num))

                            open_hour = open_info.get("hour", 0)
                            open_minute = open_info.get("minute", 0)
                            close_hour = close_info.get("hour", 0)
                            close_minute = close_info.get("minute", 0)

                            time_entry = {
                                "open": f"{open_hour:02d}:{open_minute:02d}",
                                "close": f"{close_hour:02d}:{close_minute:02d}"
                            }

                            if day_name not in opening_hours_dict:
                                opening_hours_dict[day_name] = []
                            opening_hours_dict[day_name].append(time_entry)

                    result["opening_hours"] = opening_hours_dict if opening_hours_dict else None
                else:
                    result["opening_hours"] = None

                print(f"[FeaturePipeline] 장소 정보: place_id={result['place_id']}, rating={result['rating']}, reviews={len(result['reviews'])}개")
                return result

        except Exception as e:
            print(f"[FeaturePipeline] Google API 오류: {e}")
            import traceback
            traceback.print_exc()

        return None

    async def _calculate_features(
        self,
        name: str,
        category: Optional[str],
        place_details: Optional[dict]
    ) -> Optional[dict]:
        """OpenAI로 feature 계산 (원본 update_feats.py 스타일)"""

        # Google Places API에서 가져온 데이터 추출
        rating = None
        price_range = None
        opening_hours = None
        reviews = []

        if place_details:
            rating = place_details.get("rating")
            price_range = place_details.get("price_range")  # 원문 그대로 (예: "₩20,000~30,000")
            opening_hours = place_details.get("opening_hours")  # 변환된 형식
            # reviews 추출
            reviews = [r.get("text", "") for r in place_details.get("reviews", [])[:5]]

        # 템플릿 (algorithm.py와 호환되는 구조 - food, cafe 분리)
        base_template = {
            "placeFeatures": {
                "mainCategory": {
                    "food": 0,
                    "cafe": 0,
                    "culture_art": 0,
                    "activity_sports": 0,
                    "nature_healing": 0,
                    "craft_experience": 0,
                    "shopping": 0
                },
                "atmosphere": {
                    "quiet": 0.0,
                    "romantic": 0.0,
                    "trendy": 0.0,
                    "private": 0.0,
                    "artistic": 0.0,
                    "energetic": 0.0
                },
                "experienceType": {
                    "passive_enjoyment": 0.0,
                    "active_participation": 0.0,
                    "social_bonding": 0.0,
                    "relaxation_focused": 0.0
                },
                "spaceCharacteristics": {
                    "indoor_ratio": 0.0,
                    "crowdedness_expected": 0.0,
                    "photo_worthiness": 0.0,
                    "scenic_view": 0.0
                },
                "contextual": {
                    "average_rating": 0.0,
                    "max_travel_distance": 3.0
                }
            }
        }

        # 원본 스타일 프롬프트
        prompt = f"""
아래는 장소의 기본 정보입니다:
---
이름: {name}
카테고리: {category}
평점: {rating}
가격대: {price_range}
영업시간: {opening_hours}
리뷰: {reviews}
---
아래 JSON 템플릿을 참고해서, 각 항목을 0~1 사이 값으로 합리적으로 채워주세요.
JSON 형식을 유지하고, 불필요한 설명 없이 JSON만 반환하세요.

템플릿:
{json.dumps(base_template, ensure_ascii=False, indent=2)}
"""

        try:
            response = await openai_client.chat.completions.create(
                model=settings.OPENAI_MODEL,
                messages=[{"role": "user", "content": prompt}],
                temperature=0.1,
                max_tokens=1000
            )

            content = response.choices[0].message.content.strip()

            # JSON 파싱 (```json ... ``` 형식 처리)
            if content.startswith("```"):
                content = content.split("```")[1]
                if content.startswith("json"):
                    content = content[4:]
            content = content.strip()

            features = json.loads(content)

            # 평점 정규화 (Google API에서 가져온 실제 값 사용)
            if rating:
                features["placeFeatures"]["contextual"]["average_rating"] = rating / 5.0

            return features

        except Exception as e:
            print(f"[FeaturePipeline] OpenAI 오류: {e}")
            return None

    def _update_features(self, place_hash: str, features: dict, place_details: Optional[dict] = None):
        """features 업데이트 (candidates + user_places)"""
        # 1. place_adoption_candidates 업데이트 (place_details도 저장)
        update_data = {
            "features": features,
            "features_status": "completed"
        }
        if place_details:
            update_data["google_place_details"] = place_details

        self.supabase.table("place_adoption_candidates") \
            .update(update_data) \
            .eq("place_hash", place_hash) \
            .execute()

        # 2. 해당 place_hash를 가진 모든 user_places 업데이트
        self.supabase.table("user_places") \
            .update({
                "features": features,
                "features_status": "completed"
            }) \
            .eq("place_hash", place_hash) \
            .execute()

    def _promote_to_official(self, candidate: dict, features: dict) -> bool:
        """공식 장소로 승격"""
        try:
            # 1. places 테이블에 동일 장소가 있는지 확인 (이름 + 좌표 근접)
            lat = candidate["latitude"]
            lng = candidate["longitude"]
            existing = self.supabase.table("places") \
                .select("place_id") \
                .eq("name", candidate["canonical_name"]) \
                .gte("latitude", lat - 0.0001) \
                .lte("latitude", lat + 0.0001) \
                .gte("longitude", lng - 0.0001) \
                .lte("longitude", lng + 0.0001) \
                .execute()

            if existing.data:
                # 이미 존재하면 승격 처리만 하고 INSERT 스킵
                existing_place_id = existing.data[0]["place_id"]
                print(f"[FeaturePipeline] 이미 존재하는 장소: {candidate['canonical_name']} (place_id: {existing_place_id})")

                # place_adoption_candidates 업데이트
                self.supabase.table("place_adoption_candidates") \
                    .update({
                        "is_promoted": True,
                        "promoted_place_id": existing_place_id
                    }) \
                    .eq("place_hash", candidate["place_hash"]) \
                    .execute()

                # user_places 삭제
                self.supabase.table("user_places") \
                    .delete() \
                    .eq("place_hash", candidate["place_hash"]) \
                    .execute()

                return True

            # 2. places 테이블에 INSERT
            # Google Place Details에서 추가 정보 추출
            google_details = candidate.get("google_place_details") or {}
            google_place_id = google_details.get("place_id")  # Google Place ID (ChIJ... 형식)
            rating = google_details.get("rating")
            reviews = google_details.get("reviews", [])
            opening_hours = google_details.get("opening_hours")  # 이미 변환된 형식
            price_range = google_details.get("price_range")  # 원문 그대로 (예: "₩20,000~30,000")

            new_place = {
                "name": candidate["canonical_name"],
                "address": candidate.get("canonical_address") or google_details.get("formatted_address"),
                "category": candidate.get("canonical_category"),
                "latitude": candidate["latitude"],
                "longitude": candidate["longitude"],
                "rating": rating,
                "price_range": price_range,
                "opening_hours": opening_hours,
                "reviews": [r.get("text", "") for r in reviews[:5]] if reviews else None,
                "features": features,
                "source": "promotion",
                "promoted_from_hash": candidate["place_hash"],
                "promoted_at": datetime.now().isoformat()
            }

            # Google Place ID가 있으면 사용, 없으면 DB에서 자동 생성
            if google_place_id:
                new_place["place_id"] = google_place_id

            self.supabase.table("places") \
                .insert(new_place) \
                .execute()

            # 삽입된 place_id 확인
            new_place_id = google_place_id
            if not new_place_id:
                # Google Place ID가 없으면 DB에서 조회
                inserted = self.supabase.table("places") \
                    .select("place_id") \
                    .eq("promoted_from_hash", candidate["place_hash"]) \
                    .single() \
                    .execute()
                if not inserted.data:
                    return False
                new_place_id = inserted.data["place_id"]

            # 2. place_adoption_candidates 업데이트
            self.supabase.table("place_adoption_candidates") \
                .update({
                    "is_promoted": True,
                    "promoted_place_id": new_place_id
                }) \
                .eq("place_hash", candidate["place_hash"]) \
                .execute()

            # 3. 해당 place_hash의 모든 user_places 삭제
            self.supabase.table("user_places") \
                .delete() \
                .eq("place_hash", candidate["place_hash"]) \
                .execute()

            print(f"[FeaturePipeline] 승격 완료: {candidate['canonical_name']} -> {new_place_id}")
            return True

        except Exception as e:
            print(f"[FeaturePipeline] 승격 실패: {e}")
            return False

    def get_pipeline_status(self) -> Dict[str, Any]:
        """파이프라인 상태 조회"""
        # 상태별 카운트
        pending = self.supabase.table("place_adoption_candidates") \
            .select("*", count="exact") \
            .eq("features_status", "pending") \
            .execute()

        processing = self.supabase.table("place_adoption_candidates") \
            .select("*", count="exact") \
            .eq("features_status", "processing") \
            .execute()

        completed = self.supabase.table("place_adoption_candidates") \
            .select("*", count="exact") \
            .eq("features_status", "completed") \
            .execute()

        failed = self.supabase.table("place_adoption_candidates") \
            .select("*", count="exact") \
            .eq("features_status", "failed") \
            .execute()

        promoted = self.supabase.table("place_adoption_candidates") \
            .select("*", count="exact") \
            .eq("is_promoted", True) \
            .execute()

        # 승격 대기 (features 완료 & user_count >= 5 & 아직 미승격)
        ready_for_promotion = self.supabase.table("place_adoption_candidates") \
            .select("*", count="exact") \
            .eq("features_status", "completed") \
            .eq("is_promoted", False) \
            .gte("user_count", PROMOTION_THRESHOLD) \
            .execute()

        return {
            "pending": pending.count or 0,
            "processing": processing.count or 0,
            "completed": completed.count or 0,
            "failed": failed.count or 0,
            "promoted": promoted.count or 0,
            "ready_for_promotion": ready_for_promotion.count or 0
        }
