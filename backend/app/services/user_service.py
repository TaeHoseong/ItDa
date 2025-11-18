"""
User service for Phase 10.2
Handles user CRUD operations
"""
from sqlalchemy.orm import Session
from app.models.user import User
from app.schemas.user import UserCreate, SurveyUpdate
from typing import Optional
import uuid


class UserService:
    def __init__(self, db: Session):
        self.db = db

    def create_user(self, user_data: UserCreate, user_id: str) -> User:
        """
        Create a new user

        Args:
            user_data: UserCreate schema with user information
            user_id: Google ID (from OAuth)

        Returns:
            Created User object
        """
        user = User(
            user_id=user_id,
            email=user_data.email,
            name=user_data.name,
            picture=user_data.picture,
            nickname=user_data.nickname,
            birthday=user_data.birthday,
            gender=user_data.gender,
            survey_done=False,  # Survey not done yet
            couple_id=None
        )
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user

    def get_by_email(self, email: str) -> Optional[User]:
        """
        Get user by email

        Args:
            email: User's email address

        Returns:
            User object or None if not found
        """
        return self.db.query(User).filter(User.email == email).first()

    def get_by_id(self, user_id: str) -> Optional[User]:
        """
        Get user by user_id

        Args:
            user_id: User's unique identifier (Google ID)

        Returns:
            User object or None if not found
        """
        return self.db.query(User).filter(User.user_id == user_id).first()

    def get_by_nickname(self, nickname: str) -> Optional[User]:
        """
        Get user by nickname

        Args:
            nickname: User's nickname

        Returns:
            User object or None if not found
        """
        return self.db.query(User).filter(User.nickname == nickname).first()

    def update_persona(self, user_id: str, survey_data: SurveyUpdate) -> Optional[User]:
        """
        Update user's persona (20 dimensions) from survey

        Args:
            user_id: User's unique identifier
            survey_data: SurveyUpdate schema with 20-dim persona values

        Returns:
            Updated User object or None if not found
        """
        user = self.get_by_id(user_id)
        if not user:
            return None

        # Update all 20 persona dimensions
        # Main Category (6 dimensions)
        user.food_cafe = survey_data.food_cafe
        user.culture_art = survey_data.culture_art
        user.activity_sports = survey_data.activity_sports
        user.nature_healing = survey_data.nature_healing
        user.craft_experience = survey_data.craft_experience
        user.shopping = survey_data.shopping

        # Atmosphere (6 dimensions)
        user.quiet = survey_data.quiet
        user.romantic = survey_data.romantic
        user.trendy = survey_data.trendy
        user.private_vibe = survey_data.private_vibe
        user.artistic = survey_data.artistic
        user.energetic = survey_data.energetic

        # Experience Type (4 dimensions)
        user.passive_enjoyment = survey_data.passive_enjoyment
        user.active_participation = survey_data.active_participation
        user.social_bonding = survey_data.social_bonding
        user.relaxation_focused = survey_data.relaxation_focused

        # Space Characteristics (4 dimensions)
        user.indoor_ratio = survey_data.indoor_ratio
        user.crowdedness_expected = survey_data.crowdedness_expected
        user.photo_worthiness = survey_data.photo_worthiness
        user.scenic_view = survey_data.scenic_view

        # Mark survey as completed
        user.survey_done = True

        self.db.commit()
        self.db.refresh(user)
        return user

    def update_profile(
        self,
        user_id: str,
        nickname: Optional[str] = None,
        birthday: Optional[str] = None,
        gender: Optional[str] = None
    ) -> Optional[User]:
        """
        Update user profile information

        Args:
            user_id: User's unique identifier
            nickname: New nickname (optional)
            birthday: New birth date (optional)
            gender: New gender (optional)

        Returns:
            Updated User object or None if not found
        """
        user = self.get_by_id(user_id)
        if not user:
            return None

        if nickname is not None:
            user.nickname = nickname
        if birthday is not None:
            user.birthday = birthday
        if gender is not None:
            user.gender = gender

        self.db.commit()
        self.db.refresh(user)
        return user
