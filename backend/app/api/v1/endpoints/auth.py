"""
Authentication endpoints
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import verify_google_token, create_access_token
from app.models.user import User
from app.schemas.auth import GoogleLoginRequest, TokenResponse


router = APIRouter()


@router.post("/google", response_model=TokenResponse, status_code=status.HTTP_200_OK)
async def google_login(
    request: GoogleLoginRequest,
    db: Session = Depends(get_db)
):
    """
    Google OAuth login endpoint

    1. Verify Google idToken
    2. Create or retrieve user from database
    3. Generate JWT access token
    4. Return token and user info

    Args:
        request: GoogleLoginRequest containing id_token
        db: Database session

    Returns:
        TokenResponse with access_token and user info

    Raises:
        HTTPException 401: If Google token is invalid
        HTTPException 500: If database operation fails
    """
    try:
        # 1. Verify Google idToken
        user_info = await verify_google_token(request.id_token)

    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid Google token: {str(e)}"
        )

    try:
        # 2. Check if user exists in database
        user = db.query(User).filter(User.user_id == user_info['sub']).first()

        if not user:
            # Create new user
            user = User(
                user_id=user_info['sub'],
                email=user_info['email'],
                name=user_info.get('name'),
                picture=user_info.get('picture')
            )
            db.add(user)
            db.commit()
            db.refresh(user)

        # 3. Generate JWT access token
        access_token = create_access_token(user.user_id)

        # 4. Return token and user info
        return TokenResponse(
            access_token=access_token,
            token_type="bearer",
            user={
                "user_id": user.user_id,
                "email": user.email,
                "name": user.name,
                "persona_completed": user.persona_completed
            }
        )

    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database operation failed: {str(e)}"
        )
