"""
Match request endpoints (Code-based matching)
"""
import random
import string
import uuid
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from app.core.supabase_client import get_supabase
from app.core.dependencies import get_current_user
from app.schemas.match import MatchCodeResponse, MatchConnectRequest, MatchConnectResponse


router = APIRouter()


def generate_match_code() -> str:
    """6자리 랜덤 코드 생성 (대문자 + 숫자)"""
    characters = string.ascii_uppercase + string.digits
    return ''.join(random.choices(characters, k=6))


@router.post("/generate-code", response_model=MatchCodeResponse, status_code=status.HTTP_201_CREATED)
async def generate_code(
    current_user = Depends(get_current_user),
):
    """
    매칭 코드 생성

    - 6자리 랜덤 코드 생성 (유효기간 15분)
    - 이전에 생성한 pending 코드는 모두 expired로 변경
    - 이미 커플이면 에러
    """
    supabase = get_supabase()

    try:
        # 1. 이미 커플인지 확인
        if current_user.get("couple_id"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="이미 커플이 매칭되어 있습니다"
            )

        # 2. 이전 pending 코드들을 expired로 변경
        supabase.table("match_requests").update({
            "status": "expired"
        }).eq("user_id", current_user["user_id"]).eq("status", "pending").execute()

        # 3. 새로운 코드 생성
        match_code = generate_match_code()
        expires_at = datetime.utcnow() + timedelta(minutes=15)

        # 4. 코드가 이미 존재하는 경우 재생성 (극히 드물지만)
        max_attempts = 10
        for _ in range(max_attempts):
            existing = supabase.table("match_requests").select("match_code").eq("match_code", match_code).execute()
            if not existing.data:
                break
            match_code = generate_match_code()
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="코드 생성 실패. 다시 시도해주세요."
            )

        # 5. 매칭 코드 저장
        response = supabase.table("match_requests").insert({
            "user_id": current_user["user_id"],
            "match_code": match_code,
            "status": "pending",
            "expires_at": expires_at.isoformat()
        }).execute()

        if not response.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="코드 생성 실패"
            )

        return MatchCodeResponse(
            match_code=match_code,
            expires_at=expires_at
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"코드 생성 실패: {str(e)}"
        )


@router.post("/connect", response_model=MatchConnectResponse, status_code=status.HTTP_201_CREATED)
async def connect_with_code(
    request_data: MatchConnectRequest,
    current_user = Depends(get_current_user),
):
    """
    매칭 코드로 커플 연결

    - 코드 입력 → 검증 → 즉시 커플 생성
    - 커플 페르소나 계산 (남성*0.3 + 여성*0.7)
    """
    supabase = get_supabase()

    try:
        # 1. 이미 커플인지 확인
        if current_user.get("couple_id"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="이미 커플이 매칭되어 있습니다"
            )

        # 2. 코드 검증
        code_response = (
            supabase.table("match_requests")
            .select("*")
            .eq("match_code", request_data.match_code)
            .eq("status", "pending")
            .execute()
        )

        if not code_response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="유효하지 않은 코드입니다"
            )

        match_request = code_response.data[0]

        # 3. 만료 확인
        expires_at = datetime.fromisoformat(match_request["expires_at"].replace('Z', '+00:00'))
        if datetime.utcnow() > expires_at.replace(tzinfo=None):
            # 만료된 코드는 expired로 변경
            supabase.table("match_requests").update({
                "status": "expired"
            }).eq("request_id", match_request["request_id"]).execute()

            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="만료된 코드입니다 (유효기간: 15분)"
            )

        # 4. 자기 자신의 코드인지 확인
        if match_request["user_id"] == current_user["user_id"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="자신의 코드로는 매칭할 수 없습니다"
            )

        # 5. 코드 생성자 정보 가져오기
        partner_response = (
            supabase.table("users")
            .select("user_id, name, nickname, gender, features, couple_id")
            .eq("user_id", match_request["user_id"])
            .execute()
        )

        if not partner_response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="코드 생성자를 찾을 수 없습니다"
            )

        partner = partner_response.data[0]

        # 6. 파트너도 이미 커플인지 확인
        if partner.get("couple_id"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="상대방이 이미 다른 커플과 매칭되어 있습니다"
            )

        # 7. 커플 페르소나 계산 (남성*0.3 + 여성*0.7)
        user1_gender = current_user.get("gender")
        user2_gender = partner.get("gender")
        user1_features = current_user.get("features", [])
        user2_features = partner.get("features", [])

        couple_features = None
        if (user1_gender and user2_gender and
            user1_features and user2_features and
            len(user1_features) == 20 and len(user2_features) == 20):

            # 성별에 따라 가중치 적용
            if user1_gender == "M" and user2_gender == "F":
                couple_features = [
                    user1_features[i] * 0.3 + user2_features[i] * 0.7
                    for i in range(20)
                ]
            elif user1_gender == "F" and user2_gender == "M":
                couple_features = [
                    user1_features[i] * 0.7 + user2_features[i] * 0.3
                    for i in range(20)
                ]
            else:
                # 같은 성별이거나 성별 정보 없으면 평균
                couple_features = [
                    (user1_features[i] + user2_features[i]) / 2
                    for i in range(20)
                ]

        # 8. 커플 생성
        couple_id = str(uuid.uuid4())
        couple_response = (
            supabase.table("couples")
            .insert({
                "couple_id": couple_id,
                "user_id1": current_user["user_id"],
                "user_id2": partner["user_id"],
                "features": couple_features,
                "courses": [],  # courses 테이블의 course_id 배열
                "diary": [],
                "chat_history": []
            })
            .execute()
        )

        if not couple_response.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="커플 생성 실패"
            )

        # 9. 두 사용자의 couple_id 업데이트
        supabase.table("users").update({
            "couple_id": couple_id
        }).eq("user_id", current_user["user_id"]).execute()

        supabase.table("users").update({
            "couple_id": couple_id
        }).eq("user_id", partner["user_id"]).execute()

        # 10. 매칭 코드 상태를 'used'로 변경
        supabase.table("match_requests").update({
            "status": "used"
        }).eq("request_id", match_request["request_id"]).execute()

        # 11. 성공 응답
        return MatchConnectResponse(
            couple_id=couple_id,
            partner_user_id=partner["user_id"],
            partner_name=partner.get("name", ""),
            partner_nickname=partner.get("nickname", ""),
            created_at=datetime.utcnow()
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"매칭 실패: {str(e)}"
        )
