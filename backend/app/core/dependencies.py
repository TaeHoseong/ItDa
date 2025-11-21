"""
FastAPI dependencies for authentication
"""
from typing import Dict
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError
from app.core.security import verify_token
from app.core.supabase_client import get_supabase


security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> Dict[str, str]:
    """
    Dependency to extract and verify JWT token from Authorization header

    Returns lightweight user info (just user_id) for most endpoints

    Args:
        credentials: HTTP Bearer token from Authorization header

    Returns:
        Dict with user_id: {"user_id": "..."}

    Raises:
        HTTPException 401: If token is invalid or expired
    """
    try:
        token = credentials.credentials
        user_id = verify_token(token)
        return {"user_id": user_id}

    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Could not validate credentials: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )


def get_current_user_full(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    """
    Dependency to get full user data from database

    Use this when you need complete user information (email, name, etc.)
    For most endpoints, use get_current_user() instead

    Args:
        credentials: HTTP Bearer token from Authorization header

    Returns:
        Full user dict from Supabase with all fields

    Raises:
        HTTPException 401: If token is invalid or user not found
    """
    try:
        token = credentials.credentials
        user_id = verify_token(token)

        # Get user from database
        supabase = get_supabase()
        response = (
            supabase.table("users")
            .select("*")
            .eq("user_id", user_id)
            .single()
            .execute()
        )

        if not response.data:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found"
            )

        return response.data

    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Could not validate credentials: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )
