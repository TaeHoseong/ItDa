"""
JWT token generation and verification
Google OAuth idToken verification
"""
from datetime import datetime, timedelta
from typing import Optional, Dict
from jose import jwt, JWTError
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
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


async def verify_google_token(token: str) -> Dict[str, str]:
    """
    Verify Google OAuth idToken and extract user information

    Args:
        token: Google idToken string from client

    Returns:
        Dict containing user info with keys:
        - sub: Google user ID (unique identifier)
        - email: User's email address
        - name: User's display name
        - picture: User's profile picture URL

    Raises:
        ValueError: If token is invalid or verification fails
    """
    try:
        # Verify the token using Google's public keys
        idinfo = id_token.verify_oauth2_token(
            token,
            google_requests.Request(),
            settings.GOOGLE_CLIENT_ID
        )

        # Verify the token was issued by Google
        if idinfo['iss'] not in ['accounts.google.com', 'https://accounts.google.com']:
            raise ValueError('Wrong issuer')

        # Extract user information
        user_info = {
            'sub': idinfo['sub'],              # Google user ID
            'email': idinfo['email'],          # User email
            'name': idinfo.get('name', ''),    # Display name (optional)
            'picture': idinfo.get('picture', '')  # Profile picture URL (optional)
        }

        return user_info

    except ValueError as e:
        raise ValueError(f"Invalid Google token: {str(e)}")
