import httpx
from app.config import settings

class SearchService:
    NAVER_SEARCH_URL = "https://openapi.naver.com/v1/search/local.json"
    
    # Naver Search API Coordinate System
    # mapx, mapy: WGS84 coordinates * 10,000,000 (Integer)
    # Example: 1269783882 -> 126.9783882 (Longitude)
    #          375666103  -> 37.5666103  (Latitude)

    @staticmethod
    async def search_naver_local(query: str, display: int = 5):
        headers = {
            "X-Naver-Client-Id": settings.NAVER_CLIENT_ID,
            "X-Naver-Client-Secret": settings.NAVER_CLIENT_SECRET,
        }
        params = {
            "query": query,
            "display": display,
            "sort": "random"
        }

        async with httpx.AsyncClient() as client:
            response = await client.get(
                SearchService.NAVER_SEARCH_URL,
                headers=headers,
                params=params
            )
            
            if response.status_code != 200:
                print(f"[SearchService] Naver API error: {response.status_code} - {response.text}")
                return []
            
            data = response.json()
            items = data.get("items", [])
            
            # 좌표 변환 및 필드 추가
            for item in items:
                try:
                    # 네이버 mapx, mapy는 정수형으로 옴 (예: 309946, 552085)
                    # 이를 그대로 투영하면 됨.
                    mapx = int(item['mapx'])
                    mapy = int(item['mapy'])
                    
                    # KATECH -> WGS84
                    # (예: 1269783882 -> 126.9783882)
                    
                    lon = mapx / 10000000.0
                    lat = mapy / 10000000.0
                    
                    item['mapx'] = str(lon)
                    item['mapy'] = str(lat)
                    item['latitude'] = lat
                    item['longitude'] = lon
                    
                except Exception as e:
                    print(f"Coordinate conversion error: {e}")
                    pass
            
            return items
