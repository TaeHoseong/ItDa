import json
import math
import time
import argparse 
from google_search import search_place_google_v1
from database import SessionLocal, engine
import models
from models import PlaceModel
from tqdm import tqdm

# DB 테이블 생성
models.Base.metadata.create_all(bind=engine)
def process_price(price_range):
    CURRENCY_SYMBOLS = {
        "KRW": "₩",
        "USD": "$",
        "EUR": "€",
        "JPY": "¥",
        "CNY": "¥",
        "GBP": "£",
        "AUD": "A$",
        "CAD": "C$",
        "INR": "₹",
    }
    if not price_range:
        return None

    start = price_range.get("startPrice", {})
    end = price_range.get("endPrice", {})
    code = start.get("currencyCode", "KRW")  # 기본값 KRW
    symbol = CURRENCY_SYMBOLS.get(code, code)

    start_value = start.get("units", "")
    end_value = end.get("units", "")

    if start_value and end_value:
        return f"{symbol}{start_value} ~ {symbol}{end_value}"
    elif start_value:
        return f"{symbol}{start_value}"
    return None
    
def save_places_google(place_query: str, max_places: int = 60):
    """Google Places API 결과를 DB에 저장"""
    db = SessionLocal()
    try:
        all_places = []
        page_token = None

        print(f"📍 '{place_query}' 검색 중...")

        for _ in range(5):  # 최대 5페이지 → 실제는 3페이지(60개)까지만 지원
            result = search_place_google_v1(place_query, page_token)
            if not result or "places" not in result:
                break

            all_places.extend(result["places"])
            page_token = result.get("nextPageToken")
            if not page_token or len(all_places) >= max_places:
                break
            time.sleep(2)  # Google 권장 대기시간

        print(f"✅ 총 {len(all_places)}개 장소 수집 완료")

        # DB에 저장
        for p in tqdm(all_places):
            # 필드 추출
            place_id = p.get("id")
            name = p["displayName"]["text"]
            category = p.get("primaryTypeDisplayName", {}).get("text")
            address = p.get("shortFormattedAddress")
            location = p.get("location", {})
            latitude = location.get("latitude")
            longitude = location.get("longitude")
            rating = p.get("rating")
            price_range = process_price(p.get("priceRange"))
            opening_hours = p.get("currentOpeningHours", {}).get("weekdayDescriptions")
            # photos = p.get("photos")
            # reviews = p.get("reviews")

            # 중복 검사 (place_id 기준)
            exists = db.query(PlaceModel).filter(PlaceModel.place_id == place_id).first()
            if exists:
                continue
            def safe_json(value):
                if isinstance(value, (dict, list)):
                    return json.dumps(value, ensure_ascii=False)
                return value
            
            db_place = PlaceModel(
                place_id=place_id,
                name=name,
                category=category,
                address=address,
                latitude=latitude,
                longitude=longitude,
                rating=rating,
                price_range=price_range,
                opening_hours=safe_json(opening_hours),
                # photos=safe_json(photos),
                # reviews=safe_json(reviews)
            )

            db.add(db_place)

        db.commit()
        print("💾 DB 저장 완료!")

    finally:
        db.close()
            
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    
    parser.add_argument(
        "--place",
        type=str,
        default="인천 송도 맛집"
    )
    
    parser.add_argument(
        "--num_places",
        type=int,
        default=60
    )
    
    args = parser.parse_args()
    
    save_places_google(args.place, args.num_places)