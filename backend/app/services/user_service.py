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

    def create_user(self, user_data: UserCreate, user_id: str):
        payload = {
            "user_id": user_id,
            "email": user_data.email,
            "name": user_data.name,
            "picture": user_data.picture,
            "nickname": user_data.nickname,
            "birthday": user_data.birthday,
            "gender": user_data.gender,
            "survey_done": False,
            "couple_id": None,
        }

        response = (
            self.supabase.table("users")
            .insert(payload)
            .execute()
        )

        if not response.data:
            raise RuntimeError("Supabase: failed to create user")

        return response.data[0]

    def get_by_email(self, email: str):
        response = (
            self.supabase.table("users")
            .select("*")
            .eq("email", email)
            .execute()
        )

        return response.data

    def get_by_id(self, user_id: str):
        response = (
            self.supabase.table("users")
            .select("*")
            .eq("user_id", user_id)
            .single()
            .execute()
        )
        return response.data

    def get_by_nickname(self, nickname: str):
        response = (
            self.supabase.table("users")
            .select("*")
            .eq("nickname", nickname)
            .single()
            .execute()
        )
        return response.data

    def update_persona(self, user_id: str, survey_data: SurveyUpdate):
        # 20차원 persona → 배열로 저장하는 방식 (추천)
        features_vector = [
            survey_data.food_cafe,
            survey_data.culture_art,
            survey_data.activity_sports,
            survey_data.nature_healing,
            survey_data.craft_experience,
            survey_data.shopping,

            survey_data.quiet,
            survey_data.romantic,
            survey_data.trendy,
            survey_data.private_vibe,
            survey_data.artistic,
            survey_data.energetic,

            survey_data.passive_enjoyment,
            survey_data.active_participation,
            survey_data.social_bonding,
            survey_data.relaxation_focused,

            survey_data.indoor_ratio,
            survey_data.crowdedness_expected,
            survey_data.photo_worthiness,
            survey_data.scenic_view,
        ]

        response = (
            self.supabase.table("users")
            .update({
                "features": features_vector,
                "survey_done": True
            })
            .eq("user_id", user_id)
            .execute()
        )

        if not response.data:
            return None
        
        return response.data[0]
    
    def update_profile(self, user_id: str, nickname=None, birthday=None, gender=None):
        update_data = {}

        if nickname is not None:
            update_data["nickname"] = nickname
        if birthday is not None:
            update_data["birthday"] = birthday
        if gender is not None:
            update_data["gender"] = gender

        if not update_data:
            return None

        response = (
            self.supabase.table("users")
            .update(update_data)
            .eq("user_id", user_id)
            .execute()
        )

        if not response.data:
            return None
        
        return response.data[0]
