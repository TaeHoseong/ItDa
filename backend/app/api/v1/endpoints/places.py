from fastapi import APIRouter, Depends, HTTPException
from typing import List
from app.core.supabase_client import get_supabase
from app.schemas.place import PlaceResponse, PlaceUpdate

router = APIRouter()

# 🟦 의존성: Supabase 클라이언트 제공
def get_client():
    return get_supabase()

@router.get("/by_place_id/{place_id}", response_model=PlaceResponse)
def get_place_by_place_id(place_id: str, client = Depends(get_client)):

    response = (
        client.table("places")
        .select("*")
        .eq("place_id", place_id)
        .limit(1)
        .execute()
    )

    data = response.data
    if not data:
        raise HTTPException(status_code=404, detail="장소를 찾을 수 없습니다")

    return data[0]

@router.get("/by_id/{id}", response_model=PlaceResponse)
def get_place_by_id(id: int, client = Depends(get_client)):

    response = (
        client.table("places")
        .select("*")
        .eq("id", id)
        .limit(1)
        .execute()
    )

    data = response.data
    if not data:
        raise HTTPException(status_code=404, detail="장소를 찾을 수 없습니다")

    return data[0]

@router.get("/", response_model=List[PlaceResponse])
def list_places(skip: int = 0, limit: int = 100, client = Depends(get_client)):

    response = (
        client.table("places")
        .select("*")
        .range(skip, skip + limit - 1)
        .execute()
    )

    return response.data

@router.patch("/by_place_id/{place_id}", response_model=PlaceResponse)
def update_place(place_id: str, updates: PlaceUpdate, client = Depends(get_client)):

    # 먼저 존재하는지 확인
    existing = (
        client.table("places")
        .select("*")
        .eq("place_id", place_id)
        .limit(1)
        .execute()
    )

    if not existing.data:
        raise HTTPException(status_code=404, detail="장소를 찾을 수 없습니다")

    # 실제 업데이트
    update_data = updates.dict(exclude_unset=True)

    response = (
        client.table("places")
        .update(update_data)
        .eq("place_id", place_id)
        .execute()
    )

    return response.data[0]

@router.delete("/by_place_id/{place_id}")
def delete_place(place_id: str, client = Depends(get_client)):

    existing = (
        client.table("places")
        .select("id")
        .eq("place_id", place_id)
        .execute()
    )

    if not existing.data:
        raise HTTPException(status_code=404, detail="장소를 찾을 수 없습니다")

    client.table("places").delete().eq("place_id", place_id).execute()

    return {"message": "삭제되었습니다"}