"""
JWT token generation and verification
"""
from datetime import datetime, timedelta
from typing import Optional
from jose import jwt, JWTError
from app.config import settings


def create_access_token(user_id: str, expires_delta: Optional[timedelta] = None) -> str:
    """
    Create JWT access token

    Args:
        user_id: User's unique identifier (Google ID)
        expires_delta: Token expiration time (default: 7 days from settings)

    Returns:
        Encoded JWT token string
    """
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    to_encode = {
        "sub": user_id,  # Subject (user identifier)
        "exp": expire     # Expiration time
    }

    encoded_jwt = jwt.encode(
        to_encode,
        settings.JWT_SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM
    )

    return encoded_jwt


def verify_token(token: str) -> str:
    """
    Verify JWT token and extract user_id

    Args:
        token: JWT token string

    Returns:
        user_id (str) extracted from token

    Raises:
        JWTError: If token is invalid or expired
    """
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM]
        )

        user_id: str = payload.get("sub")

        if user_id is None:
            raise JWTError("Token payload missing 'sub' claim")

        return user_id

    except JWTError as e:
        raise JWTError(f"Token verification failed: {str(e)}")
