"""
User service for Phase 10.2
Handles user CRUD operations using Supabase
"""
from app.core.supabase_client import get_supabase
from app.schemas.user import UserCreate, SurveyUpdate
from typing import Optional, Dict, Any


class UserService:
    def __init__(self):
        """Initialize UserService with Supabase client"""
        self.supabase = get_supabase()

    def create_user(self, user_data: UserCreate, user_id: str, password_hash: Optional[str] = None) -> Dict[str, Any]:
        """
        Create a new user

        Args:
            user_data: UserCreate schema with user information
            user_id: User ID (Google ID from OAuth or generated UUID)
            password_hash: Bcrypt password hash (None for Google OAuth users)

        Returns:
            Created user record as dictionary

        Raises:
            Exception: If user creation fails
        """
        response = (
            self.supabase.table("users")
            .insert({
                "user_id": user_id,
                "email": user_data.email,
                "name": user_data.name,
                "picture": user_data.picture,
                "nickname": user_data.nickname,
                "birthday": user_data.birthday,
                "gender": user_data.gender,
                "password_hash": password_hash,  # NULL for Google OAuth
                "survey_done": False,
                "couple_id": None
            })
            .execute()
        )

        if not response.data:
            raise Exception("Failed to create user")

        return response.data[0]

    def get_by_email(self, email: str) -> Optional[Dict[str, Any]]:
        """
        Get user by email

        Args:
            email: User's email address

        Returns:
            User record as dictionary or None if not found
        """
        response = (
            self.supabase.table("users")
            .select("*")
            .eq("email", email)
            .execute()
        )

        if response.data:
            return response.data[0]
        return None

    def get_by_id(self, user_id: str) -> Optional[Dict[str, Any]]:
        """
        Get user by user_id

        Args:
            user_id: User's unique identifier

        Returns:
            User record as dictionary or None if not found
        """
        response = (
            self.supabase.table("users")
            .select("*")
            .eq("user_id", user_id)
            .execute()
        )

        if response.data:
            return response.data[0]
        return None

    def get_by_nickname(self, nickname: str) -> Optional[Dict[str, Any]]:
        """
        Get user by nickname

        Args:
            nickname: User's nickname

        Returns:
            User record as dictionary or None if not found
        """
        response = (
            self.supabase.table("users")
            .select("*")
            .eq("nickname", nickname)
            .execute()
        )

        if response.data:
            return response.data[0]
        return None

    def update_persona(self, user_id: str, survey_data: SurveyUpdate) -> Optional[Dict[str, Any]]:
        """
        Update user's persona (20 dimensions) from survey

        Args:
            user_id: User's unique identifier
            survey_data: SurveyUpdate schema with 20-dim persona values

        Returns:
            Updated user record as dictionary or None if not found
        """
        # First check if user exists
        user = self.get_by_id(user_id)
        if not user:
            return None

        # Build features JSON object from survey data
        features = {
            # Main Category (6 dimensions)
            "food_cafe": survey_data.food_cafe,
            "culture_art": survey_data.culture_art,
            "activity_sports": survey_data.activity_sports,
            "nature_healing": survey_data.nature_healing,
            "craft_experience": survey_data.craft_experience,
            "shopping": survey_data.shopping,
            # Atmosphere (6 dimensions)
            "quiet": survey_data.quiet,
            "romantic": survey_data.romantic,
            "trendy": survey_data.trendy,
            "private_vibe": survey_data.private_vibe,
            "artistic": survey_data.artistic,
            "energetic": survey_data.energetic,
            # Experience Type (4 dimensions)
            "passive_enjoyment": survey_data.passive_enjoyment,
            "active_participation": survey_data.active_participation,
            "social_bonding": survey_data.social_bonding,
            "relaxation_focused": survey_data.relaxation_focused,
            # Space Characteristics (4 dimensions)
            "indoor_ratio": survey_data.indoor_ratio,
            "crowdedness_expected": survey_data.crowdedness_expected,
            "photo_worthiness": survey_data.photo_worthiness,
            "scenic_view": survey_data.scenic_view,
        }

        # Update features JSON and mark survey as completed
        response = (
            self.supabase.table("users")
            .update({
                "features": features,
                "survey_done": True
            })
            .eq("user_id", user_id)
            .execute()
        )

        if not response.data:
            return None

        return response.data[0]

    def update_profile(
        self,
        user_id: str,
        nickname: Optional[str] = None,
        birthday: Optional[str] = None,
        gender: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """
        Update user profile information

        Args:
            user_id: User's unique identifier
            nickname: New nickname (optional)
            birthday: New birth date (optional)
            gender: New gender (optional)

        Returns:
            Updated user record as dictionary or None if not found
        """
        # First check if user exists
        user = self.get_by_id(user_id)
        if not user:
            return None

        # Build update dictionary with only provided fields
        update_data = {}
        if nickname is not None:
            update_data["nickname"] = nickname
        if birthday is not None:
            update_data["birthday"] = birthday
        if gender is not None:
            update_data["gender"] = gender

        # If nothing to update, return current user
        if not update_data:
            return user

        response = (
            self.supabase.table("users")
            .update(update_data)
            .eq("user_id", user_id)
            .execute()
        )

        if not response.data:
            return None

        return response.data[0]
