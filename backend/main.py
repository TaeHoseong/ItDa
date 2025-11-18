from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel
from app.core.supabase_client import get_supabase

app = FastAPI()

# Pydantic 모델
class Place(BaseModel):
    place_id: str
    name: str
    category: str
    address: str
    latitude: float
    longitude: float
    rating: float
    price_range: str
    opening_hours: str
    reviews: str

def get_client():
    return get_supabase()


@app.get("/")
def read_root():
    return {"ItDa": "Useful"}

@app.get("/places/by_place_id/{place_id}")
def read_place(place_id: str, client = Depends(get_client)):
    response = (
        client.table("places")
        .select("*")
        .eq("place_id", place_id)
        .execute()
    )

    data = response.data
    if not data:
        raise HTTPException(status_code=404, detail="Item not found")

    return data[0]

@app.get("/places/by_id/{id}")
def read_place_index(id: int, client = Depends(get_client)):
    response = (
        client.table("places")
        .select("*")
        .eq("id", id)
        .execute()
    )

    data = response.data
    if not data:
        raise HTTPException(status_code=404, detail="Item not found")

    return data[0]

@app.put("/places/by_place_id/{place_id}")
def update_place(place_id: str, place: Place, client = Depends(get_client)):
    # 먼저 존재 여부 확인
    existing = (
        client.table("places")
        .select("*")
        .eq("place_id", place_id)
        .execute()
    )

    if not existing.data:
        raise HTTPException(status_code=404, detail="Item not found")

    # 업데이트 실행
    response = (
        client.table("places")
        .update({
            "name": place.name,
            "category": place.category,
            "address": place.address,
            "latitude": place.latitude,
            "longitude": place.longitude,
            "rating": place.rating,
            "price_range": place.price_range,
            "opening_hours": place.opening_hours,
            "reviews": place.reviews
        })
        .eq("place_id", place_id)
        .execute()
    )

    return response.data[0]

@app.post("/places/")
def create_place(place: Place, client = Depends(get_client)):
    response = (
        client.table("places")
        .insert({
            "place_id": place.place_id,
            "name": place.name,
            "category": place.category,
            "address": place.address,
            "latitude": place.latitude,
            "longitude": place.longitude,
            "rating": place.rating,
            "price_range": place.price_range,
            "opening_hours": place.opening_hours,
            "reviews": place.reviews
        })
        .execute()
    )
    
    return response.data[0]