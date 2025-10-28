from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.core.database import get_db
from app.models.place import PlaceModel
from app.schemas.place import PlaceResponse, PlaceUpdate

router = APIRouter()

@router.get("/by_place_id/{place_id}", response_model=PlaceResponse)
def get_place_by_place_id(place_id: str, db: Session = Depends(get_db)):
    """Place ID로 장소 조회"""
    item = db.query(PlaceModel).filter(PlaceModel.place_id == place_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="장소를 찾을 수 없습니다")
    return item

@router.get("/by_id/{id}", response_model=PlaceResponse)
def get_place_by_id(id: int, db: Session = Depends(get_db)):
    """ID로 장소 조회"""
    item = db.query(PlaceModel).filter(PlaceModel.id == id).first()
    if not item:
        raise HTTPException(status_code=404, detail="장소를 찾을 수 없습니다")
    return item

@router.get("/", response_model=List[PlaceResponse])
def list_places(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """장소 목록 조회"""
    places = db.query(PlaceModel).offset(skip).limit(limit).all()
    return places

@router.patch("/by_place_id/{place_id}", response_model=PlaceResponse)
def update_place(place_id: str, updates: PlaceUpdate, db: Session = Depends(get_db)):
    """장소 정보 수정"""
    db_place = db.query(PlaceModel).filter(PlaceModel.place_id == place_id).first()
    if not db_place:
        raise HTTPException(status_code=404, detail="장소를 찾을 수 없습니다")

    update_data = updates.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_place, field, value)
    
    db.commit()
    db.refresh(db_place)
    return db_place

@router.delete("/by_place_id/{place_id}")
def delete_place(place_id: str, db: Session = Depends(get_db)):
    """장소 삭제"""
    db_place = db.query(PlaceModel).filter(PlaceModel.place_id == place_id).first()
    if not db_place:
        raise HTTPException(status_code=404, detail="장소를 찾을 수 없습니다")
    
    db.delete(db_place)
    db.commit()
    return {"message": "삭제되었습니다"}