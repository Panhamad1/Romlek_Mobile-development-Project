import 'class_session.dart';

class ClassSchedule {
  final String id;
  String name;
  String? schoolName;
  DateTime startDate;
  DateTime? endDate;
  final List<String> courseIds = [];
  final List<ClassSession> sessions = [];

  ClassSchedule({
    required this.id,
    required this.name,
    required this.startDate,
    this.schoolName,
    this.endDate,
  });
}
