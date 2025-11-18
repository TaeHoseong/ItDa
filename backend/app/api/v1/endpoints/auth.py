"""
Authentication endpoints
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.supabase_client import get_supabase
from app.core.security import verify_google_token, create_access_token
from app.models.user import User
from app.schemas.auth import GoogleLoginRequest, TokenResponse


router = APIRouter()


@router.post("/google", response_model=TokenResponse, status_code=status.HTTP_200_OK)
async def google_login(request: GoogleLoginRequest):
    """
    Google OAuth login endpoint

    1. Verify Google idToken
    2. Create or retrieve user from database
    3. Generate JWT access token
    4. Return token and user info

    Args:
        request: GoogleLoginRequest containing id_token

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
        supabase = get_supabase()
        response = (
            supabase.table("users")
            .select("*")
            .eq("user_id", user_info['sub'])
            .execute()
        )
        
        if response.data:
            user_record = response.data[0]
        else:
            # Create new user
            response = (
                supabase.table("users").insert({
                    "user_id": user_info.get("sub"),
                    "email": user_info.get("email"),
                    "name": user_info.get("name"),
                    "picture": user_info.get("picture"),
                    "survey_done": False,
                })
                .execute()
            )
            user_record = response.data[0]
            
            if not response.data:
                raise HTTPException(
                    status_code=500,
                    detail="Supabase user creation failed"
                )
            user_record = response.data[0]


            
        # 3. Generate JWT access token
        access_token = create_access_token(user_record["user_id"])
        response = (
            supabase.table("users")
            .update({"token": access_token})
            .eq("user_id", user_record["user_id"])
            .execute()
        )
        
        updated_user = response.data[0]
        # 4. Return token and user info
        return TokenResponse(
            access_token=access_token,
            token_type="bearer",
            user={
                "user_id": updated_user["user_id"],
                "email": updated_user["email"],
                "name": updated_user["name"],
                "survey_done": updated_user["survey_done"]
            }
        )

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database operation failed: {str(e)}"
        )
