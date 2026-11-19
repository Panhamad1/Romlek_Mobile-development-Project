import '../model/assessment.dart';
import '../model/course.dart';

class AssessmentService {
  final List<Course> courses;
  final List<Assessment> assessments;

  AssessmentService({required this.courses, required this.assessments});

  Assessment addAssessment({
    required String id,
    required String courseId,
    required String title,
    required AssessmentType type,
    required DateTime dateTime,
    String? notes,
    String? preparationNotes,
  }){
    if(id.trim().isEmpty){
      throw Exception('Assessment ID must not be blank.');
    }
    for(final assessment in assessments){
      if(assessment.id == id){
        throw Exception('Assessment ID already exists.');
      }
    }
    _validate(courseId, title);
    final assessment = Assessment(
      id: id,
      courseId: courseId,
      title: title.trim(),
      type: type,
      dateTime: dateTime,
      notes: notes,
      preparationNotes: preparationNotes,
    );
    assessments.add(assessment);
    return assessment;
  }

  void updateAssessment(
    String id, {
    required String courseId,
    required String title,
    required AssessmentType type,
    required DateTime dateTime,
    String? notes,
    String? preparationNotes,
  }){
    final assessment = _getAssessment(id);
    _validate(courseId, title);
    assessment.courseId = courseId;
    assessment.title = title.trim();
    assessment.type = type;
    assessment.dateTime = dateTime;
    assessment.notes = notes;
    assessment.preparationNotes = preparationNotes;
  }

  bool deleteAssessment(String id, {required bool confirmed}){
    final assessment = _getAssessment(id);
    if(!confirmed){
      return false;
    }
    assessments.remove(assessment);
    return true;
  }

  List<Assessment> getAssessmentsByCourse(String courseId){
    _validateCourse(courseId);
    final result = <Assessment>[];
    for(final assessment in assessments){
      if(assessment.courseId == courseId){
        result.add(assessment);
      }
    }
    return result;
  }

  List<Assessment> getAssessmentsInRange(DateTime from, DateTime to){
    if(to.isBefore(from)){
      throw Exception('Range end must not precede start.');
    }
    final result = <Assessment>[];
    for(final assessment in assessments){
      if(!assessment.dateTime.isBefore(from) &&
          assessment.dateTime.isBefore(to)){
        result.add(assessment);
      }
    }
    result.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return result;
  }

  Assessment _getAssessment(String id){
    for(final assessment in assessments){
      if(assessment.id == id){
        return assessment;
      }
    }
    throw Exception('Assessment not found.');
  }

  void _validate(String courseId, String title){
    _validateCourse(courseId);
    if(title.trim().isEmpty){
      throw Exception('Assessment title must not be blank.');
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

