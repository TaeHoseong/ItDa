"""
Course management endpoints (Phase 10.4)
"""
from fastapi import APIRouter, Depends, HTTPException, status
from typing import List

from app.core.dependencies import get_current_user
from app.schemas.course import CourseCreate, CourseUpdate, CourseResponse
from app.services.course_service import CourseService


router = APIRouter()


@router.post("", response_model=CourseResponse, status_code=status.HTTP_201_CREATED)
async def create_course(
    course_data: CourseCreate,
    current_user = Depends(get_current_user),
):
    """
    Create a new course

    Args:
        course_data: Course creation data
        current_user: Authenticated user

    Returns:
        Created course

    Raises:
        HTTPException 500: If database operation fails
    """
    try:
        course_service = CourseService()
        course = course_service.create_course(
            user_id=current_user['user_id'],
            course_data=course_data.dict()
        )

        return CourseResponse.from_orm(course)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create course: {str(e)}"
        )


@router.get("/{course_id}", response_model=CourseResponse, status_code=status.HTTP_200_OK)
async def get_course(
    course_id: str,
    current_user = Depends(get_current_user),
):
    """
    Get course by ID

    Args:
        course_id: Course ID
        current_user: Authenticated user
        
    Returns:
        Course details

    Raises:
        HTTPException 404: If course not found
        HTTPException 403: If user doesn't have access
    """
    course_service = CourseService()
    course = course_service.get_course(course_id)

    if not course:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Course not found"
        )

    # Check access: user must be creator or same couple
    if course.user_id != current_user["user_id"]:
        if not course.couple_id or course.couple_id != current_user.get("couple_id"):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied"
            )

    return CourseResponse.from_orm(course)


@router.get("/", response_model=List[CourseResponse], status_code=status.HTTP_200_OK)
async def get_my_courses(
    current_user = Depends(get_current_user),
):
    """
    Get all courses for current user

    Args:
        current_user: Authenticated user

    Returns:
        List of courses
    """

    course_service = CourseService()
    courses = course_service.get_courses_by_user(current_user["user_id"])

    return [CourseResponse.from_orm(course) for course in courses]


@router.put("/{course_id}", response_model=CourseResponse, status_code=status.HTTP_200_OK)
async def update_course(
    course_id: str,
    course_data: CourseUpdate,
    current_user = Depends(get_current_user),
):
    """
    Update course

    Args:
        course_id: Course ID
        course_data: Updated course data
        current_user: Authenticated user

    Returns:
        Updated course

    Raises:
        HTTPException 404: If course not found
        HTTPException 403: If user doesn't have access
        HTTPException 500: If database operation fails
    """
    try:
        course_service = CourseService()

        # Check course exists and user has access
        course = course_service.get_course(course_id)
        if not course:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Course not found"
            )

        # Only creator can update
        if course.user_id != current_user["user_id"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only course creator can update"
            )

        # Update course
        updated_course = course_service.update_course(
            course_id,
            course_data.dict(exclude_unset=True)
        )

        return CourseResponse.from_orm(updated_course)

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update course: {str(e)}"
        )


@router.delete("/{course_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_course(
    course_id: str,
    current_user = Depends(get_current_user),
):
    """
    Delete course

    Args:
        course_id: Course ID
        current_user: Authenticated user
        
    Raises:
        HTTPException 404: If course not found
        HTTPException 403: If user doesn't have access
    """
    course_service = CourseService()

    # Check course exists and user has access
    course = course_service.get_course(course_id)
    if not course:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Course not found"
        )

    # Only creator can delete
    if course.user_id != current_user["user_id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only course creator can delete"
        )

    # Delete course
    success = course_service.delete_course(course_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete course"
        )

    return None
