"""
Course management endpoints (Phase 10.4)
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.core.database import get_db
from app.api.v1.endpoints.users import get_current_user
from app.models.user import User
from app.schemas.course import CourseCreate, CourseUpdate, CourseResponse
from app.services.course_service import CourseService


router = APIRouter()


@router.post("/", response_model=CourseResponse, status_code=status.HTTP_201_CREATED)
async def create_course(
    course_data: CourseCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Create a new course

    Args:
        course_data: Course creation data
        current_user: Authenticated user
        db: Database session

    Returns:
        Created course

    Raises:
        HTTPException 500: If database operation fails
    """
    try:
        course_service = CourseService(db)
        course = course_service.create_course(
            db,
            user_id=current_user.user_id,
            course_data=course_data.dict()
        )

        return CourseResponse.from_orm(course)

    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create course: {str(e)}"
        )


@router.get("/{course_id}", response_model=CourseResponse, status_code=status.HTTP_200_OK)
async def get_course(
    course_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get course by ID

    Args:
        course_id: Course ID
        current_user: Authenticated user
        db: Database session

    Returns:
        Course details

    Raises:
        HTTPException 404: If course not found
        HTTPException 403: If user doesn't have access
    """
    course_service = CourseService(db)
    course = course_service.get_course(db, course_id)

    if not course:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Course not found"
        )

    # Check access: user must be creator or same couple
    if course.user_id != current_user.user_id:
        if not course.couple_id or course.couple_id != current_user.couple_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied"
            )

    return CourseResponse.from_orm(course)


@router.get("/", response_model=List[CourseResponse], status_code=status.HTTP_200_OK)
async def get_my_courses(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all courses for current user

    Args:
        current_user: Authenticated user
        db: Database session

    Returns:
        List of courses
    """
    course_service = CourseService(db)
    courses = course_service.get_courses_by_user(db, current_user.user_id)

    return [CourseResponse.from_orm(course) for course in courses]


@router.put("/{course_id}", response_model=CourseResponse, status_code=status.HTTP_200_OK)
async def update_course(
    course_id: str,
    course_data: CourseUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update course

    Args:
        course_id: Course ID
        course_data: Updated course data
        current_user: Authenticated user
        db: Database session

    Returns:
        Updated course

    Raises:
        HTTPException 404: If course not found
        HTTPException 403: If user doesn't have access
        HTTPException 500: If database operation fails
    """
    try:
        course_service = CourseService(db)

        # Check course exists and user has access
        course = course_service.get_course(db, course_id)
        if not course:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Course not found"
            )

        # Only creator can update
        if course.user_id != current_user.user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only course creator can update"
            )

        # Update course
        updated_course = course_service.update_course(
            db,
            course_id,
            course_data.dict(exclude_unset=True)
        )

        return CourseResponse.from_orm(updated_course)

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update course: {str(e)}"
        )


@router.delete("/{course_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_course(
    course_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Delete course

    Args:
        course_id: Course ID
        current_user: Authenticated user
        db: Database session

    Raises:
        HTTPException 404: If course not found
        HTTPException 403: If user doesn't have access
    """
    course_service = CourseService(db)

    # Check course exists and user has access
    course = course_service.get_course(db, course_id)
    if not course:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Course not found"
        )

    # Only creator can delete
    if course.user_id != current_user.user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only course creator can delete"
        )

    # Delete course
    success = course_service.delete_course(db, course_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete course"
        )

    return None
