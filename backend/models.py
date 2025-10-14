from sqlalchemy import Column, Integer, String, Float, JSON
from database import Base

class PlaceModel(Base):
    __tablename__ = "places"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)  # 내부 PK
    place_id = Column(String, unique=True, index=True)   # Google Places API에서 주는 id
    
    name = Column(String, index=True)                    # displayName.text
    category = Column(String, index=True)                # primaryTypeDisplayName.text
    address = Column(String)                             # shortFormattedAddress
    
    latitude = Column(Float)                             # location.latitude
    longitude = Column(Float)                            # location.longitude
    
    rating = Column(Float, nullable=True)                # 평점
    price_range = Column(String, nullable=True)          # 가격대
    
    opening_hours = Column(JSON, nullable=True)          # currentOpeningHours.weekdayDescriptions (리스트)
    # photos = Column(JSON, nullable=True)                 # photos (list of dict)
    # reviews = Column(JSON, nullable=True)                # reviews (리스트 저장)