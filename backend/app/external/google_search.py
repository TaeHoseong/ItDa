import requests
import time
from app.config import settings

API_KEY = settings.GOOGLE_PLACES_API_KEY

def search_place_google_v1(text_query: str, page_token: str=None):
    url = "https://places.googleapis.com/v1/places:searchText"
    headers = {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": API_KEY,
        "X-Goog-FieldMask": (
            "nextPageToken,"
            "places.id,"                                # Place ID              
            "places.displayName.text,"                  # 식당 이름
            "places.shortFormattedAddress,"               # 도로명 주소
            "places.location,"                          # 좌표
            # "places.photos,"                            # 사진들 (list 형태로 반환)
            "places.primaryTypeDisplayName.text,"       # 카테고리
            "places.currentOpeningHours.weekdayDescriptions,"   # 영업시간
            "places.reviews,"                         # 리뷰들 (list 형태로 반환)
            "places.rating,"                            # 평점
            "places.priceRange"                         # 가격 범위
        )
    }
    data = {
        "textQuery": text_query,
        "languageCode": "ko",
        "pageSize": 20
    }
    if page_token:
        data["pageToken"] = page_token 
        
    response = requests.post(url, headers=headers, json=data)
    if response.status_code == 200:
        return response.json()
    else:
        print("Error:", response.status_code, response.text)
        return None

if __name__ == "__main__":
    keyword = "송도 맛집"
    all_places = []
    page_token = None
    result = search_place_google_v1(keyword, page_token)
    print(result["places"][0])
    # for _ in range(5):  # 최대 5페이지 (20 * 5 = 100개)
    #     result = search_place_google_v1(keyword, page_token)
    #     if not result or "places" not in result:
    #         break
    #     all_places.extend(result["places"])
    #     page_token = result.get("nextPageToken")
    #     print("총 개수:", len(all_places))
    #     if not page_token:
    #         break
        
    #     time.sleep(2)  # 구글 API 권장 딜레이

    
    for p in all_places:
        print(p["displayName"]["text"], "-", p.get("shortFormattedAddress"))