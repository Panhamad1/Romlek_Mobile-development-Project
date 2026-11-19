enum AssignmentStatus { pending, completed }

class Assignment {
  final String id;
  String courseId;
  String title;
  String? description;
  DateTime? dueDateTime;
  AssignmentStatus status = AssignmentStatus.pending;
  DateTime? completedAt;

  Assignment({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    this.dueDateTime,
  });
}
