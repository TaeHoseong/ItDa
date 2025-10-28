from fastapi import HTTPException, Request
from fastapi.responses import JSONResponse

async def custom_exception_handler(request: Request, exc: HTTPException):
    """통일된 에러 응답"""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "error": {
                "code": exc.status_code,
                "message": exc.detail
            }
        }
    )