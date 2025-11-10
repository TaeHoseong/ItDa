"""
User management endpoints
"""
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import verify_token
from app.models.user import User
from app.schemas.user import UserPersonaUpdate, UserResponse
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
        persona_completed=current_user.persona_completed
    )


@router.put("/persona", response_model=UserResponse, status_code=status.HTTP_200_OK)
async def update_persona(
    persona: UserPersonaUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update user persona (survey results)

    Args:
        persona: UserPersonaUpdate containing 20 dimension values
        current_user: Authenticated user from JWT
        db: Database session

    Returns:
        UserResponse with updated user info

    Raises:
        HTTPException 500: If database operation fails
    """
    try:
        # Update all persona fields
        current_user.food_cafe = persona.food_cafe
        current_user.culture_art = persona.culture_art
        current_user.activity_sports = persona.activity_sports
        current_user.nature_healing = persona.nature_healing
        current_user.craft_experience = persona.craft_experience
        current_user.shopping = persona.shopping

        current_user.quiet = persona.quiet
        current_user.romantic = persona.romantic
        current_user.trendy = persona.trendy
        current_user.private_vibe = persona.private_vibe
        current_user.artistic = persona.artistic
        current_user.energetic = persona.energetic

        current_user.passive_enjoyment = persona.passive_enjoyment
        current_user.active_participation = persona.active_participation
        current_user.social_bonding = persona.social_bonding
        current_user.relaxation_focused = persona.relaxation_focused

        current_user.indoor_ratio = persona.indoor_ratio
        current_user.crowdedness_expected = persona.crowdedness_expected
        current_user.photo_worthiness = persona.photo_worthiness
        current_user.scenic_view = persona.scenic_view

        # Mark persona as completed
        current_user.persona_completed = True

        db.commit()
        db.refresh(current_user)

        return UserResponse(
            user_id=current_user.user_id,
            email=current_user.email,
            name=current_user.name,
            persona_completed=current_user.persona_completed
        )

    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update persona: {str(e)}"
        )
