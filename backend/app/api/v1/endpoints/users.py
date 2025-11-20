"""
User management endpoints
"""
from fastapi import APIRouter, Depends, HTTPException, status
from app.core.dependencies import get_current_user_full
from app.schemas.user import UserResponse, SurveyUpdate
from app.services.user_service import UserService


router = APIRouter()


@router.get("/me", response_model=UserResponse, status_code=status.HTTP_200_OK)
async def get_current_user_info(
    current_user = Depends(get_current_user_full)
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
        picture=current_user["picture"],
        nickname=current_user["nickname"],
        birthday=current_user["birthday"],
        gender=current_user["gender"],
        couple_id=current_user["couple_id"],
        survey_done=current_user.get("survey_done", False)
    )


@router.put("/survey", response_model=UserResponse, status_code=status.HTTP_200_OK)
async def submit_survey(
    survey_data: SurveyUpdate,
    current_user = Depends(get_current_user_full),
):
    """
    Submit or re-submit user survey (updates persona)

    This endpoint allows users to submit their survey results (20 persona dimensions)
    for the first time or re-submit to update their preferences.

    Args:
        survey_data: SurveyUpdate containing 20 dimension values
        current_user: Authenticated user from JWT

    Returns:
        UserResponse with updated user info

    Raises:
        HTTPException 404: If user not found
        HTTPException 500: If database operation fails
    """
    try:
        user_service = UserService()

        # Update persona using service layer
        updated_user = user_service.update_persona(current_user["user_id"], survey_data)

        if not updated_user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )

        return UserResponse(
            user_id=updated_user["user_id"],
            email=updated_user["email"],
            name=updated_user.get("name"),
            picture=updated_user.get("picture"),
            nickname=updated_user.get("nickname"),
            birthday=updated_user.get("birthday"),
            gender=updated_user.get("gender"),
            couple_id=updated_user.get("couple_id"),
            survey_done=updated_user.get("survey_done", False)
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update survey: {str(e)}"
        )
