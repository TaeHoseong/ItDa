"""파이프라인 실행 테스트"""
import asyncio
from app.services.feature_pipeline import FeaturePipelineService

async def main():
    service = FeaturePipelineService()

    print("=== 파이프라인 상태 ===")
    status = service.get_pipeline_status()
    for key, value in status.items():
        print(f"  {key}: {value}")

    print("\n=== 파이프라인 실행 ===")
    result = await service.run_pipeline(limit=5)

    print(f"\n결과:")
    print(f"  processed: {result['processed']}")
    print(f"  features_calculated: {result['features_calculated']}")
    print(f"  promoted: {result['promoted']}")
    print(f"  promotion_ready_processed: {result['promotion_ready_processed']}")

    if result['errors']:
        print(f"\n에러:")
        for err in result['errors']:
            print(f"  - {err['name']}: {err['error']}")

if __name__ == "__main__":
    asyncio.run(main())
