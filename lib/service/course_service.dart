import '../model/assessment.dart';
import '../model/assignment.dart';
import '../model/class_schedule.dart';
import '../model/course.dart';
import 'timetable_service.dart';

class CourseService {
  final List<ClassSchedule> schedules;
  final List<Course> courses;
  final List<Assignment> assignments;
  final List<Assessment> assessments;

  CourseService({
    required this.schedules,
    required this.courses,
    required this.assignments,
    required this.assessments,
  });

  Course addCourse({
    required String id,
    required String scheduleId,
    required String name,
  }){
    final schedule = _getSchedule(scheduleId);
    if(id.trim().isEmpty){
      throw Exception('Course ID must not be blank.');
    }
    for(final course in courses){
      if(course.id == id){
        throw Exception('Course ID already exists.');
      }
    }
    for(final timetable in schedules){
      if(timetable.courseIds.contains(id)){
        throw Exception('Course ID already belongs to a timetable.');
      }
    }
    _validateName(name);

    final course = Course(id: id, name: name);
    courses.add(course);
    schedule.courseIds.add(course.id);
    return course;
  }

  void renameCourse(String courseId, String newName){
    final course = _getCourse(courseId);
    _getOwner(courseId);
    _validateName(newName, excludingId: courseId);
    course.rename(newName);
  }

  List<Course> getCoursesForSchedule(String scheduleId){
    final schedule = _getSchedule(scheduleId);
    final result = <Course>[];
    for(final courseId in schedule.courseIds){
      final course = _getCourse(courseId);
      _getOwner(courseId);
      result.add(course);
    }
    return result;
  }

  bool deleteCourse(String courseId, {required bool confirmed}){
    final course = _getCourse(courseId);
    final owner = _getOwner(courseId);
    if(!confirmed){
      return false;
    }

    owner.sessions.removeWhere((session) => session.courseId == courseId);
    assignments.removeWhere((assignment) => assignment.courseId == courseId);
    assessments.removeWhere((assessment) => assessment.courseId == courseId);
    owner.courseIds.remove(courseId);
    courses.remove(course);
    return true;
  }

  List<String> previewMoveCourse(
    String courseId,
    String targetScheduleId, {
    required DateTime from,
    required DateTime to,
  }){
    _getCourse(courseId);
    _getOwner(courseId);
    _getSchedule(targetScheduleId);
    return TimetableService(
      schedules: schedules,
      courses: courses,
    ).previewCourseMove(courseId, targetScheduleId, from, to);
  }

  bool moveCourse(
    String courseId,
    String targetScheduleId, {
    required DateTime from,
    required DateTime to,
    bool confirmed = true,
    bool saveAnyway = false,
  }){
    final warnings = previewMoveCourse(
      courseId,
      targetScheduleId,
      from: from,
      to: to,
    );
    if(!confirmed || (warnings.isNotEmpty && !saveAnyway)){
      return false;
    }
    final owner = _getOwner(courseId);
    final target = _getSchedule(targetScheduleId);
    if(owner == target){
      return true;
    }
    final sessions = owner.sessions
        .where((session) => session.courseId == courseId)
        .toList();
    owner.sessions.removeWhere((session) => session.courseId == courseId);
    owner.courseIds.remove(courseId);
    target.courseIds.add(courseId);
    target.sessions.addAll(sessions);
    return true;
  }

  bool deleteSchedule(String scheduleId, {required bool confirmed}){
    final schedule = _getSchedule(scheduleId);
    for(final courseId in schedule.courseIds){
      _getCourse(courseId);
      _getOwner(courseId);
    }
    for(final session in schedule.sessions){
      if(!schedule.courseIds.contains(session.courseId)){
        throw Exception('Timetable contains a session without its Course.');
      }
    }
    if(!confirmed){
      return false;
    }
    final ids = List<String>.from(schedule.courseIds);
    assignments.removeWhere((assignment) => ids.contains(assignment.courseId));
    assessments.removeWhere((assessment) => ids.contains(assessment.courseId));
    courses.removeWhere((course) => ids.contains(course.id));
    schedule.sessions.clear();
    schedule.courseIds.clear();
    schedules.remove(schedule);
    return true;
  }

  ClassSchedule _getSchedule(String scheduleId){
    for(final schedule in schedules){
      if(schedule.id == scheduleId){
        return schedule;
      }
    }
    throw Exception('Timetable not found.');
  }

  Course _getCourse(String courseId){
    for(final course in courses){
      if(course.id == courseId){
        return course;
      }
    }
    throw Exception('Course not found.');
  }

  ClassSchedule _getOwner(String courseId){
    ClassSchedule? owner;
    int membershipCount = 0;
    for(final schedule in schedules){
      for(final id in schedule.courseIds){
        if(id == courseId){
          owner = schedule;
          membershipCount++;
        }
      }
    }
    if(membershipCount != 1 || owner == null){
      throw Exception('Course must belong to exactly one timetable.');
    }
    for(final schedule in schedules){
      for(final session in schedule.sessions){
        if(session.courseId == courseId && schedule != owner){
          throw Exception('Course session is in the wrong timetable.');
        }
      }
    }
    return owner;
  }

  void _validateName(String name, {String? excludingId}){
    final comparisonName = name.trim().toLowerCase();
    if(comparisonName.isEmpty){
      throw Exception('Course name must not be blank.');
    }
    for(final course in courses){
      if(course.id != excludingId &&
          course.name.trim().toLowerCase() == comparisonName){
        throw Exception('Course name already exists.');
      }
    }
  }
}

