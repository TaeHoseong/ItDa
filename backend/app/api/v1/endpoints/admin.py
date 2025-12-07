"""
관리자 API 엔드포인트

내부 서버에서만 호출하는 엔드포인트입니다.
Swagger 문서에서 숨겨져 있으며, 인증 없이 호출 가능합니다.

사용 예시:
  curl -X POST "http://localhost:8000/api/v1/admin/run-pipeline?limit=10"
  curl -X GET "http://localhost:8000/api/v1/admin/pipeline-status"
"""
from fastapi import APIRouter, HTTPException, Query

from app.services.feature_pipeline import FeaturePipelineService

router = APIRouter()


@router.post("/run-pipeline", include_in_schema=False)
async def run_feature_pipeline(
    limit: int = Query(default=10, ge=1, le=100, description="처리할 최대 개수")
):
    """
    Feature 파이프라인 수동 실행 (내부 전용)

    - pending 상태의 승격 후보를 처리
    - Google Places API + OpenAI로 features 계산
    - 조건 충족 시 공식 장소로 승격
    """
    service = FeaturePipelineService()

    try:
        result = await service.run_pipeline(limit=limit)
        return {
            "status": "completed",
            "result": result
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/pipeline-status", include_in_schema=False)
async def get_pipeline_status():
    """
    파이프라인 상태 조회 (내부 전용)

    - 상태별 승격 후보 개수
    - 승격 대기 중인 장소 개수
    """
    service = FeaturePipelineService()

    try:
        status = service.get_pipeline_status()
        return status
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
