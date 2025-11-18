"""
User management endpoints
"""
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.core.supabase_client import get_supabase
from app.core.security import verify_token
from app.models.user import User
from app.schemas.user import UserPersonaUpdate, UserResponse
from jose import JWTError


router = APIRouter()
security = HTTPBearer()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> User:
    """
    Extract and verify JWT token from Authorization header

    Args:
        credentials: HTTP Bearer credentials from header
        supabse: Database session

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
        else:
            user = response.data

        return user

    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token verification failed: {str(e)}"
        )


@router.get("/me", response_model=UserResponse, status_code=status.HTTP_200_OK)
async def get_current_user_info(
    current_user = Depends(get_current_user)
):
    """
    Get current user information

    Args:
        current_user: Authenticated user from JWT

    Returns:
        UserResponse with user info
    """
    return UserResponse(
        user_id=current_user["user_id"],
        email=current_user["email"],
        name=current_user["name"],
        survey_done=current_user.get("survey_done", False)
    )


@router.put("/persona", response_model=UserResponse, status_code=status.HTTP_200_OK)
async def update_persona(
    persona: UserPersonaUpdate,
    current_user: User = Depends(get_current_user),
):
    """
    Update user persona (survey results)

    Args:
        persona: UserPersonaUpdate containing 20 dimension values
        current_user: Authenticated user from JWT

    Returns:
        UserResponse with updated user info

    Raises:
        HTTPException 500: If database operation fails
    """
    supabase = get_supabase()
    try:
        features_vector = [
            persona.food_cafe,
            persona.culture_art,
            persona.activity_sports,
            persona.nature_healing,
            persona.craft_experience,
            persona.shopping,

            persona.quiet,
            persona.romantic,
            persona.trendy,
            persona.private_vibe,
            persona.artistic,
            persona.energetic,

            persona.passive_enjoyment,
            persona.active_participation,
            persona.social_bonding,
            persona.relaxation_focused,

            persona.indoor_ratio,
            persona.crowdedness_expected,
            persona.photo_worthiness,
            persona.scenic_view,
        ]
        response = (
            supabase.table("users")
            .update({
                "features": features_vector,
                "survey_done": True
            })
            .eq("user_id", current_user["user_id"])
            .execute()
        )
        
        updated_user = response.data[0]

        return UserResponse(
            user_id=updated_user["user_id"],
            email=updated_user["email"],
            name=updated_user["name"],
            survey_done=updated_user["survey_done"]
        )

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update persona: {str(e)}"
        )
