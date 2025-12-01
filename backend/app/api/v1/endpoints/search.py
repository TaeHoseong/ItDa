from fastapi import APIRouter, HTTPException
from typing import List, Any
from app.services.search_service import SearchService

router = APIRouter()

@router.get("/places", response_model=List[Any])
async def search_places(query: str):
    if not query:
        return []
    
    results = await SearchService.search_naver_local(query)
    return results
