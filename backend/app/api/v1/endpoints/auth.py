"""
Authentication endpoints
"""
import bcrypt
from fastapi import APIRouter, Depends, HTTPException, status
from app.core.supabase_client import get_supabase
from app.core.security import verify_google_token, create_access_token
from app.schemas.auth import GoogleLoginRequest, TokenResponse, UserRegisterRequest, UserLoginRequest
from app.schemas.user import UserCreate, UserResponse
from app.services.user_service import UserService


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


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(
    user_data: UserRegisterRequest,
):
    """
    User registration endpoint with password (Phase 10.2.2)

    Create a new user account with email and password.

    Args:
        user_data: UserRegisterRequest with email, password, and optional profile info

    Returns:
        TokenResponse with access_token and user info

    Raises:
        HTTPException 400: If email already exists
        HTTPException 500: If database operation fails
    """
    try:
        user_service = UserService()

        # Check if email already exists
        existing_user = user_service.get_by_email(user_data.email)
        if existing_user:
            # Check if it's a Google OAuth account
            if existing_user.get("password_hash") is None:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Email already registered with Google login. Please sign in with Google."
                )
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered"
            )

        # Check if nickname already exists (if provided)
        if user_data.nickname:
            existing_nickname = user_service.get_by_nickname(user_data.nickname)
            if existing_nickname:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Nickname already taken"
                )

        # Generate user_id from email
        user_id = f"user_{user_data.email.replace('@', '_').replace('.', '_')}"

        # Hash password with bcrypt
        password_hash = bcrypt.hashpw(
            user_data.password.encode('utf-8'),
            bcrypt.gensalt()
        ).decode('utf-8')

        # Convert UserRegisterRequest to UserCreate for service layer
        user_create_data = UserCreate(
            email=user_data.email,
            name=user_data.name,
            nickname=user_data.nickname,
            birthday=user_data.birthday,
            gender=user_data.gender,
            picture=None
        )

        # Create user with password hash
        user = user_service.create_user(user_create_data, user_id, password_hash)

        # Generate JWT access token and store in database
        access_token = create_access_token(user["user_id"])
        supabase = get_supabase()
        response = (
            supabase.table("users")
            .update({"token": access_token})
            .eq("user_id", user["user_id"])
            .execute()
        )
        updated_user = response.data[0]

        return TokenResponse(
            access_token=access_token,
            token_type="bearer",
            user={
                "user_id": updated_user["user_id"],
                "email": updated_user["email"],
                "name": updated_user.get("name"),
                "nickname": updated_user.get("nickname"),
                "survey_done": updated_user.get("survey_done", False)
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Registration failed: {str(e)}"
        )


@router.post("/login", response_model=TokenResponse, status_code=status.HTTP_200_OK)
async def login(
    login_data: UserLoginRequest,
):
    """
    User login endpoint with password verification (Phase 10.2.2)

    Login with email and password, receive JWT token.

    Args:
        login_data: UserLoginRequest with email and password

    Returns:
        TokenResponse with access_token and user info

    Raises:
        HTTPException 404: If user not found
        HTTPException 401: If password is incorrect
        HTTPException 400: If account uses Google OAuth
        HTTPException 500: If database operation fails
    """
    try:
        user_service = UserService()

        # Find user by email
        user = user_service.get_by_email(login_data.email)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found. Please register first."
            )

        # Check if this is a Google OAuth account (no password)
        if user.get("password_hash") is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This account uses Google login. Please sign in with Google."
            )

        # Verify password
        if not bcrypt.checkpw(
            login_data.password.encode('utf-8'),
            user["password_hash"].encode('utf-8')
        ):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )

        # Generate JWT access token and store in database
        access_token = create_access_token(user["user_id"])
        supabase = get_supabase()
        response = (
            supabase.table("users")
            .update({"token": access_token})
            .eq("user_id", user["user_id"])
            .execute()
        )
        updated_user = response.data[0]

        # Return token and user info
        return TokenResponse(
            access_token=access_token,
            token_type="bearer",
            user={
                "user_id": updated_user["user_id"],
                "email": updated_user["email"],
                "name": updated_user.get("name"),
                "nickname": updated_user.get("nickname"),
                "survey_done": updated_user.get("survey_done", False)
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Login failed: {str(e)}"
        )
