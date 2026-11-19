enum ClassSessionType { weekly, makeup }

class ClassSession {
  final String id;
  String courseId;
  ClassSessionType type;
  int? weekday;
  DateTime? date;
  int startMinutes;
  int endMinutes;
  String? room;
  String? preparationNotes;
  DateTime? recurrenceEndDate;
  final Map<DateTime, String?> unavailableDates = {};

  ClassSession({
    required this.id,
    required this.courseId,
    required this.type,
    required this.startMinutes,
    required this.endMinutes,
    this.weekday,
    this.date,
    this.room,
    this.preparationNotes,
    this.recurrenceEndDate,
  });
}
