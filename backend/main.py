from typing import Union
from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from database import SessionLocal, engine
import models

# DB 테이블 생성
models.Base.metadata.create_all(bind=engine)

app = FastAPI()

# Pydantic 모델
class Place(BaseModel):
    id: int
    place_id: str
    name: str
    category: str
    address: str
    lattitude: float
    longitude: float
    rating: float
    price_range: str
    opening_hours: str
    reviews: str

# DB 세션 의존성
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/")
def read_root():
    return {"ItDa": "Useful"}

@app.get("/places/by_place_id/{place_id}")
def read_place(place_id: str, db: Session = Depends(get_db)):
    item = db.query(models.PlaceModel).filter(models.PlaceModel.place_id == place_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item

@app.get("/places/by_id/{id}")
def read_place_index(id: int, db: Session = Depends(get_db)):
    item = db.query(models.PlaceModel).filter(models.PlaceModel.id == id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item

@app.put("/places/by_place_id/{place_id}")
def update_place(place_id: str, place: Place, db: Session = Depends(get_db)):
    db_place = db.query(models.PlaceModel).filter(models.PlaceModel.place_id == place_id).first()
    if not db_place:
        raise HTTPException(status_code=404, detail="Item not found")

    db_place.name = place.name
    db_place.category=place.category
    db_place.addres=place.address,
    db_place.lattitude=place.latitude,
    db_place.longitude=place.longitude,
    db_place.rating=place.rating,
    db_place.price_range=place.price_range
    db_place.reviews = place.reviews
    
    db.commit()
    db.refresh(db_place)
    return db_place

@app.post("/places/")
def create_place(place: Place, db: Session = Depends(get_db)):
    db_place = models.PlaceModel(
        place_id=place.place_id,
        name=place.name,
        category=place.category,
        addres=place.address,
        lattitude=place.latitude,
        longitude=place.longitude,
        rating=place.rating,
        price_range=place.price_range,
        opeining_hours=place.opening_hours,
        reviews =place.reviews
    )
    db.add(db_place)
    db.commit()
    db.refresh(db_place)
    return db_place
