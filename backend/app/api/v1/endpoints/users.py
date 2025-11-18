"""
User management endpoints
"""
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import verify_token
from app.models.user import User
from app.schemas.user import UserResponse, SurveyUpdate
from app.services.user_service import UserService
from jose import JWTError


router = APIRouter()
security = HTTPBearer()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> User:
    """
    Extract and verify JWT token from Authorization header

    Args:
        credentials: HTTP Bearer credentials from header
        db: Database session

    Returns:
        User object

    Raises:
        HTTPException 401: If token is invalid or user not found
    """
    try:
        token = credentials.credentials

        # Verify token and get user_id
        user_id = verify_token(token)

        # Get user from database
        user = db.query(User).filter(User.user_id == user_id).first()

        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found"
            )

        return user

    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token verification failed: {str(e)}"
        )


@router.get("/me", response_model=UserResponse, status_code=status.HTTP_200_OK)
async def get_current_user_info(
    current_user: User = Depends(get_current_user)
):
    """
    Get current user information

    Args:
        current_user: Authenticated user from JWT

    Returns:
        UserResponse with user info
    """
    return UserResponse(
        user_id=current_user.user_id,
        email=current_user.email,
        name=current_user.name,
        picture=current_user.picture,
        nickname=current_user.nickname,
        birth_date=current_user.birth_date,
        gender=current_user.gender,
        couple_id=current_user.couple_id,
        persona_completed=current_user.persona_completed
    )


@router.put("/survey", response_model=UserResponse, status_code=status.HTTP_200_OK)
async def submit_survey(
    survey_data: SurveyUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Submit or re-submit user survey (updates persona)

    This endpoint allows users to submit their survey results (20 persona dimensions)
    for the first time or re-submit to update their preferences.

    Args:
        survey_data: SurveyUpdate containing 20 dimension values
        current_user: Authenticated user from JWT
        db: Database session

    Returns:
        UserResponse with updated user info

    Raises:
        HTTPException 404: If user not found
        HTTPException 500: If database operation fails
    """
    try:
        user_service = UserService(db)

        # Update persona using service layer
        updated_user = user_service.update_persona(current_user.user_id, survey_data)

        if not updated_user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )

        return UserResponse(
            user_id=updated_user.user_id,
            email=updated_user.email,
            name=updated_user.name,
            picture=updated_user.picture,
            nickname=updated_user.nickname,
            birth_date=updated_user.birth_date,
            gender=updated_user.gender,
            couple_id=updated_user.couple_id,
            persona_completed=updated_user.persona_completed
        )

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update survey: {str(e)}"
        )
