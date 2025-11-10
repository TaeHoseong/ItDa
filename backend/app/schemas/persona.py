from pydantic import BaseModel
from typing import Optional, Dict, Any

class ChatRequest(BaseModel):
    message: str
    session_id: str = "default"
    user_id: Optional[str] = None  # Google user ID for personalized recommendations

class ChatResponse(BaseModel):
    message: str
    action: str
    data: Optional[Dict[str, Any]] = None