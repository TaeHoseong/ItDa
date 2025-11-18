"""
Authentication endpoints
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import verify_google_token, create_access_token
from app.models.user import User
from app.schemas.auth import GoogleLoginRequest, TokenResponse
from app.schemas.user import UserCreate, UserResponse
from app.services.user_service import UserService


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
                "survey_done": user.survey_done
            }
        )

    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database operation failed: {str(e)}"
        )


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register(
    user_data: UserCreate,
    db: Session = Depends(get_db)
):
    """
    User registration endpoint (Phase 10.2)

    Create a new user account with profile information.
    Note: This endpoint expects the user to have already authenticated with Google OAuth,
    and the user_id should be the Google ID.

    Args:
        user_data: UserCreate schema with registration info
        db: Database session

    Returns:
        UserResponse with created user info

    Raises:
        HTTPException 400: If email or nickname already exists
        HTTPException 500: If database operation fails
    """
    try:
        user_service = UserService(db)

        # Check if email already exists
        existing_user = user_service.get_by_email(user_data.email)
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered"
            )

        # Check if nickname already exists
        existing_nickname = user_service.get_by_nickname(user_data.nickname)
        if existing_nickname:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Nickname already taken"
            )

        # Generate user_id (for now, use email as placeholder)
        # In production, this should come from Google OAuth
        user_id = f"user_{user_data.email.replace('@', '_').replace('.', '_')}"

        # Create user
        user = user_service.create_user(user_data, user_id)

        return UserResponse(
            user_id=user.user_id,
            email=user.email,
            name=user.name,
            picture=user.picture,
            nickname=user.nickname,
            birthday=user.birthday,
            gender=user.gender,
            couple_id=user.couple_id,
            survey_done=user.survey_done
        )

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Registration failed: {str(e)}"
        )


@router.post("/login", response_model=TokenResponse, status_code=status.HTTP_200_OK)
async def login(
    email: str,
    db: Session = Depends(get_db)
):
    """
    User login endpoint (Phase 10.2)

    Login with email and receive JWT token.
    Note: In production, this should be integrated with Google OAuth flow.

    Args:
        email: User's email address
        db: Database session

    Returns:
        TokenResponse with access_token and user info

    Raises:
        HTTPException 404: If user not found
        HTTPException 500: If database operation fails
    """
    try:
        user_service = UserService(db)

        # Find user by email
        user = user_service.get_by_email(email)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found. Please register first."
            )

        # Generate JWT access token
        access_token = create_access_token(user.user_id)

        # Return token and user info
        return TokenResponse(
            access_token=access_token,
            token_type="bearer",
            user={
                "user_id": user.user_id,
                "email": user.email,
                "name": user.name,
                "nickname": user.nickname,
                "survey_done": user.survey_done
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Login failed: {str(e)}"
        )
