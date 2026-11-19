enum AssessmentType { quiz, exam }

class Assessment {
  final String id;
  String courseId;
  String title;
  AssessmentType type;
  DateTime dateTime;
  String? notes;
  String? preparationNotes;

  Assessment({
    required this.id,
    required this.courseId,
    required this.title,
    required this.type,
    required this.dateTime,
    this.notes,
    this.preparationNotes,
  });
}
