"""
FastAPI dependencies for authentication
"""
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError
from app.core.security import verify_token


security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> str:
    """
    Dependency to extract and verify JWT token from Authorization header

    Args:
        credentials: HTTP Bearer token from Authorization header

    Returns:
        user_id (str) extracted from valid JWT token

    Raises:
        HTTPException 401: If token is invalid or expired
    """
    try:
        token = credentials.credentials
        user_id = verify_token(token)
        return user_id

    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Could not validate credentials: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )
