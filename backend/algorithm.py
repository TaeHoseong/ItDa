import numpy as np
import os
import json
from app.core.supabase_client import get_supabase
from dotenv import load_dotenv
import math

load_dotenv(".env")

persona = [1,0,0,0,0,0,  0.9,0.7,0.5,0.8,0.8,0.3,  0.8,0.1,0.7,0.9,  0.95,0.3,0.8,0.4]

personas = np.array([
    # 1. 조용한 카페 & 음식점 선호
    [1,0,0,0,0,0,  0.9,0.7,0.5,0.8,0.8,0.3,  0.8,0.1,0.7,0.9,  0.95,0.3,0.8,0.4],

    # 2. 활기찬 분위기의 고깃집/분식집 선호
    [1,0,0,0,0,0,  0.1,0.3,0.5,0.2,0.2,0.7,  0.2,0.9,0.3,0.1,  0.05,0.7,0.2,0.6],

    # 3. 트렌디한 맛집 탐방러
    [1,0,0,0,0,0,  0.3,0.5,0.9,0.4,0.3,0.8,  0.9,0.2,0.9,0.5,  0.9,0.7,0.7,0.3],
])
persona_position = [37.382556, 126.671083]

def extract_features(place: json, persona):
    try:
        features = place["placeFeatures"]

        features_array = (
            list(features["mainCategory"].values()) +
            list(features["atmosphere"].values()) +
            list(features["experienceType"].values()) +
            list(features["spaceCharacteristics"].values())
        )
        # None 처리: average_rating이 None이면 0으로 대체
        rating = features["contextual"].get("average_rating", 0)
        if rating is None:
            rating = 0
        # 현재 데이터엔 range 값으로 들어가 있어서 이걸 normalize해줘야함(지금은 임시로 0)
        price = 0
        return np.array(features_array, dtype=float), rating, price
    except KeyError as e:
        print(f"key error | {e} in place: {place.get('name', 'Unknown')}")
        return np.zeros(20), 0, 0  # 수정: 3개 값 반환 (4개 아님)

def recommend_topk(persona, last_recommend=None, candidate_names=None, category=None, k=3, alpha=0.8, beta=0.7, gamma=0.2, delta=0.4):
    supabase = get_supabase()
    response = supabase.table("places").select("*").execute()
    places = response.data

    scores_total = []
    def cos_similarity(A, B):
        return np.dot(A, B)/(np.linalg.norm(A)*np.linalg.norm(B))
    def haversine_distance(coord1, coord2):
            # coord = [latitude, longitude]
            R = 6371  # 지구 반경 (km)
            lat1, lon1 = math.radians(coord1[0]), math.radians(coord1[1])
            lat2, lon2 = math.radians(coord2[0]), math.radians(coord2[1])

            dlat = lat2 - lat1
            dlon = lon2 - lon1

            a = math.sin(dlat / 2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2)**2
            c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
            return R * c
    for place in places:
        name = place["name"]
        scores = place["features"]
        latitude, longitude = place["latitude"], place["longitude"]
        if last_recommend and name in last_recommend:
            print(f"skip {name} (negative react)")
            continue
        # 필터링
        if category:
            place_category = json.loads(scores)["placeFeatures"]["mainCategory"]
            if place_category[category] < 0.5: 
                # print(f"skip {name}, {category}: {place_category[category]}")
                continue
        
        if candidate_names and name not in candidate_names:
            # print(f"skip {name} (not in candidate names)")
            continue
        scores_json = json.loads(scores)
        features, rating, price  = extract_features(scores_json, persona)
        distance = haversine_distance(persona_position, [latitude, longitude])
        similarity_cos = cos_similarity(features, persona)
        similarity_euclid =1 / np.linalg.norm(features - persona)
        similarity_dot = np.dot(features, persona)
        # print(similarity_euclid, similarity_cos, similarity_dot)
        similarity = similarity_cos
        score = alpha*similarity - beta*distance + gamma*rating + delta*price
        scores_total.append((name, score))

        
    sorted_results = sorted(scores_total, key=lambda x: x[1], reverse=True)
    return sorted_results[:k]

if __name__ == '__main__':
    for i, persona in enumerate(personas):
        print(f"------persona {i+1}--------")
        results = recommend_topk(persona, k=10)
        for place in results:
            print(f"당신에게 딱 맞는 장소는 {place[0]}이고, {place[1]:.2f}점의 점수로 추천되었습니다")