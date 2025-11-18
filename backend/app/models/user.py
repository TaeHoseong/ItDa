from sqlalchemy import Column, String, Float, Boolean, DateTime
from datetime import datetime
from app.core.database import Base


class User(Base):
    __tablename__ = "users"

    # Google OAuth info
    user_id = Column(String, primary_key=True, index=True)  # Google ID (sub claim)
    email = Column(String, unique=True, nullable=False, index=True)
    name = Column(String, nullable=True)
    picture = Column(String, nullable=True)  # Profile picture URL

    # Additional user info (Phase 10.2)
    nickname = Column(String, unique=True, nullable=True, index=True)  # 사용자 닉네임
    birth_date = Column(String, nullable=True)  # YYYY-MM-DD 형식
    gender = Column(String, nullable=True)  # "male" or "female"

    # Couple relationship (Phase 10.3)
    couple_id = Column(String, nullable=True, index=True)  # 매칭된 커플 ID

    # Main Category (6 dimensions)
    food_cafe = Column(Float, default=0.0, nullable=False)
    culture_art = Column(Float, default=0.0, nullable=False)
    activity_sports = Column(Float, default=0.0, nullable=False)
    nature_healing = Column(Float, default=0.0, nullable=False)
    craft_experience = Column(Float, default=0.0, nullable=False)
    shopping = Column(Float, default=0.0, nullable=False)

    # Atmosphere (6 dimensions)
    quiet = Column(Float, default=0.0, nullable=False)
    romantic = Column(Float, default=0.0, nullable=False)
    trendy = Column(Float, default=0.0, nullable=False)
    private_vibe = Column(Float, default=0.0, nullable=False)
    artistic = Column(Float, default=0.0, nullable=False)
    energetic = Column(Float, default=0.0, nullable=False)

    # Experience Type (4 dimensions)
    passive_enjoyment = Column(Float, default=0.0, nullable=False)
    active_participation = Column(Float, default=0.0, nullable=False)
    social_bonding = Column(Float, default=0.0, nullable=False)
    relaxation_focused = Column(Float, default=0.0, nullable=False)

    # Space Characteristics (4 dimensions)
    indoor_ratio = Column(Float, default=0.0, nullable=False)
    crowdedness_expected = Column(Float, default=0.0, nullable=False)
    photo_worthiness = Column(Float, default=0.0, nullable=False)
    scenic_view = Column(Float, default=0.0, nullable=False)

    # Metadata
    survey_done = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
