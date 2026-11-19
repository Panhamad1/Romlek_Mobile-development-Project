import '../model/assignment.dart';
import '../model/course.dart';

enum DeadlineStatus { completed, noDeadline, overdue, dueToday, upcoming }

class AssignmentService {
  final List<Course> courses;
  final List<Assignment> assignments;

  AssignmentService({required this.courses, required this.assignments});

  Assignment addAssignment({
    required String id,
    required String courseId,
    required String title,
    String? description,
    DateTime? dueDateTime,
  }){
    if(id.trim().isEmpty){
      throw Exception('Assignment ID must not be blank.');
    }
    for(final assignment in assignments){
      if(assignment.id == id){
        throw Exception('Assignment ID already exists.');
      }
    }
    _validate(courseId, title);
    final assignment = Assignment(
      id: id,
      courseId: courseId,
      title: title.trim(),
      description: description,
      dueDateTime: dueDateTime,
    );
    assignments.add(assignment);
    return assignment;
  }

  void updateAssignment(
    String id, {
    required String courseId,
    required String title,
    String? description,
    DateTime? dueDateTime,
  }){
    final assignment = _getAssignment(id);
    _validate(courseId, title);
    assignment.courseId = courseId;
    assignment.title = title.trim();
    assignment.description = description;
    assignment.dueDateTime = dueDateTime;
  }

  void markCompleted(String id, DateTime now){
    final assignment = _getAssignment(id);
    if(assignment.status == AssignmentStatus.completed){
      return;
    }
    assignment.status = AssignmentStatus.completed;
    assignment.completedAt = now;
  }

  void reopenAssignment(String id){
    final assignment = _getAssignment(id);
    assignment.status = AssignmentStatus.pending;
    assignment.completedAt = null;
  }

  void deleteAssignment(String id){
    final assignment = _getAssignment(id);
    assignments.remove(assignment);
  }

  List<Assignment> getAssignmentsByCourse(String courseId){
    _validateCourse(courseId);
    final result = <Assignment>[];
    for(final assignment in assignments){
      if(assignment.courseId == courseId){
        result.add(assignment);
      }
    }
    return result;
  }

  DeadlineStatus getDeadlineStatus(String id, DateTime now){
    final assignment = _getAssignment(id);
    if(assignment.status == AssignmentStatus.completed){
      return DeadlineStatus.completed;
    }
    final due = assignment.dueDateTime;
    if(due == null){
      return DeadlineStatus.noDeadline;
    }
    if(now.isAfter(due)){
      return DeadlineStatus.overdue;
    }
    if(now.year == due.year && now.month == due.month && now.day == due.day){
      return DeadlineStatus.dueToday;
    }
    return DeadlineStatus.upcoming;
  }

  Assignment _getAssignment(String id){
    for(final assignment in assignments){
      if(assignment.id == id){
        return assignment;
      }
    }
    throw Exception('Assignment not found.');
  }

  void _validate(String courseId, String title){
    _validateCourse(courseId);
    if(title.trim().isEmpty){
      throw Exception('Assignment title must not be blank.');
    }
  }

  void _validateCourse(String courseId){
    for(final course in courses){
      if(course.id == courseId){
        return;
      }
    }
    throw Exception('Course not found.');
  }
}

