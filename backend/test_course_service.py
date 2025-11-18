"""
CourseService 테스트 스크립트
"""
import sys
import os
from pathlib import Path

# UTF-8 인코딩 설정 (Windows 콘솔)
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

# 경로 설정
backend_path = Path(__file__).parent
sys.path.insert(0, str(backend_path))

from app.services.course_service import CourseService
from app.schemas.course import CoursePreferences


def test_auto_template():
    """페르소나 기반 자동 템플릿 선택 테스트"""
    print("\n" + "="*80)
    print("TEST 1: Auto Template Selection (Persona-based)")
    print("="*80)

    service = CourseService()

    # 실제 DB에 있는 사용자 ID 사용 (페르소나 완료된 사용자)
    user_id = "102928578341147999188"

    course = service.generate_date_course(
        user_id=user_id,
        date="2025-11-25",
        template="auto"
    )

    print("\n[RESULT]")
    print(f"Template: {course.template}")
    print(f"Time: {course.start_time} - {course.end_time}")
    print(f"Total Distance: {course.total_distance}km")
    print(f"Duration: {course.total_duration}min")
    print(f"Slots ({len(course.slots)}):")
    for i, slot in enumerate(course.slots, 1):
        print(f"  {i}. {slot.emoji} [{slot.start_time}] {slot.slot_type} - {slot.place_name}")
        if slot.distance_from_previous:
            print(f"     Distance: {slot.distance_from_previous}km")


def test_specific_template():
    """특정 템플릿 테스트"""
    print("\n" + "="*80)
    print("TEST 2: Specific Template (cafe_date)")
    print("="*80)

    service = CourseService()
    user_id = "102928578341147999188"

    course = service.generate_date_course(
        user_id=user_id,
        date="2025-11-26",
        template="cafe_date"
    )

    print("\n[RESULT]")
    print(f"Template: {course.template}")
    print(f"Time: {course.start_time} - {course.end_time}")
    print(f"Total Distance: {course.total_distance}km")
    print(f"Duration: {course.total_duration}min")
    print(f"Slots ({len(course.slots)}):")
    for i, slot in enumerate(course.slots, 1):
        print(f"  {i}. {slot.emoji} [{slot.start_time}] {slot.slot_type} - {slot.place_name}")
        if slot.distance_from_previous:
            print(f"     Distance: {slot.distance_from_previous}km")


def test_with_preferences():
    """사용자 커스터마이징 테스트"""
    print("\n" + "="*80)
    print("TEST 3: Custom Preferences (exclude activity, start at 14:00)")
    print("="*80)

    service = CourseService()
    user_id = "102928578341147999188"

    preferences = CoursePreferences(
        start_time="14:00",
        exclude=["activity"],
        duration=240  # 4시간
    )

    course = service.generate_date_course(
        user_id=user_id,
        date="2025-11-27",
        template="full_day",
        preferences=preferences
    )

    print("\n[RESULT]")
    print(f"Template: {course.template}")
    print(f"Time: {course.start_time} - {course.end_time}")
    print(f"Duration: {course.total_duration}min (requested: {preferences.duration}min)")
    print(f"Slots ({len(course.slots)}):")
    for i, slot in enumerate(course.slots, 1):
        print(f"  {i}. {slot.emoji} [{slot.start_time}] {slot.slot_type} - {slot.place_name}")
        assert slot.slot_type != "activity", "Activity should be excluded!"


def test_all_templates():
    """모든 템플릿 빠른 테스트"""
    print("\n" + "="*80)
    print("TEST 4: All Templates Quick Test")
    print("="*80)

    service = CourseService()
    user_id = "102928578341147999188"

    templates = ["full_day", "half_day_lunch", "half_day_dinner", "cafe_date", "active_date", "culture_date"]

    for template in templates:
        try:
            course = service.generate_date_course(
                user_id=user_id,
                date="2025-11-28",
                template=template
            )
            print(f"[OK] {template}: {len(course.slots)} slots, {course.total_distance}km, {course.total_duration}min")
            for i, slot in enumerate(course.slots, 1):
                print(f"  {i}. {slot.emoji} [{slot.start_time}] {slot.slot_type} - {slot.place_name}")
                if slot.distance_from_previous:
                    print(f"     Distance: {slot.distance_from_previous}km")

        except Exception as e:
            print(f"[ERROR] {template}: {e}")


if __name__ == "__main__":
    try:
        # 테스트 실행
        test_auto_template()
        test_specific_template()
        test_with_preferences()
        test_all_templates()

        print("\n" + "="*80)
        print("[SUCCESS] ALL TESTS PASSED!")
        print("="*80)

    except Exception as e:
        print(f"\n[FAILED] TEST FAILED: {e}")
        import traceback
        traceback.print_exc()
