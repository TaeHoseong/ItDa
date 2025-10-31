import numpy as np
import json

persona = [1,0,0,0,0,0,  0.9,0.7,0.5,0.8,0.8,0.3,  0.8,0.1,0.7,0.9,  0.95,0.3,0.8,0.4]

def extract_features(place: json):
    try:
        features = place["result"]["placeFeatures"]

        features_array = (
            list(features["mainCategory"].values()) +
            list(features["atmosphere"].values()) +
            list(features["experienceType"].values()) +
            list(features["spaceCharacteristics"].values())
        )
        # 현재는 임시로 '장소 내에서' 돌아다니는 거리로 계산 >> 추후에는 유저와의 거리로 바꿔야함
        distance = features["contextual"]["max_travel_distance"]  
        rating = features["contextual"]["average_rating"]
        # 현재 데이터엔 range 값으로 들어가 있어서 이걸 normalize해줘야함(지금은 임시로 0)
        price = 0 
        return np.array(features_array, dtype=float), distance, rating, price
    except KeyError as e:
        print(f"key error | {e} in place: {place.get('name', 'Unknown')}")
        return np.zeros(20), 0, 0, 0

def recommend_topk(persona, k=3, alpha=0.8, beta=0.7, gamma=0.2, delta=0.4):
    with open("extracted_features.json", 'r') as f:
        places = json.load(f)

    scores = []
    def cos_similarity(A, B):
        return np.dot(A, B)/(np.linalg.norm(A)*np.linalg.norm(B))
    for place in places:
        name = place["name"]
        features, distance, rating, price = extract_features(place)
        similarity = cos_similarity(features, persona)
        score = alpha*similarity + beta*distance + gamma*rating + delta*price
        scores.append((name, score))
        
    sorted_results = sorted(scores, key=lambda x: x[1], reverse=True)
    return sorted_results[:k]

if __name__ == '__main__':
    results = recommend_topk(persona, k=5)
    for place in results:
        print(f"당신에게 딱 맞는 장소는 {place[0]}이고, {place[1]:.2f}점의 점수로 추천되었습니다")