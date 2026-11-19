import 'package:flutter_test/flutter_test.dart';
import 'package:romlek/model/assignment.dart';
import 'package:romlek/model/course.dart';
import 'package:romlek/service/assignment_service.dart';

void main() {
  late AssignmentService service;
  final now = DateTime(2026, 11, 19, 10);

  setUp(() {
    service = AssignmentService(
      courses: [
        Course(id: 'c1', name: 'Mobile Development'),
        Course(id: 'c2', name: 'Database Systems'),
      ],
      assignments: [],
    );
  });

  Assignment add({DateTime? due}) {
    return service.addAssignment(
      id: 'a1',
      courseId: 'c1',
      title: 'Flutter Homework',
      dueDateTime: due,
    );
  }

  group('AssignmentService', () {
    test('adds pending assignments with optional or past deadlines', () {
      final assignment = add();
      expect(assignment.status, AssignmentStatus.pending);
      expect(assignment.completedAt, isNull);
      expect(service.getDeadlineStatus('a1', now), DeadlineStatus.noDeadline);
      service.addAssignment(
        id: 'a2',
        courseId: 'c1',
        title: 'Old Homework',
        dueDateTime: now.subtract(const Duration(days: 1)),
      );
      expect(service.getDeadlineStatus('a2', now), DeadlineStatus.overdue);
    });

    test('invalid additions do not change data', () {
      expect(
        () => service.addAssignment(id: '', courseId: 'c1', title: 'Homework'),
        throwsException,
      );
      expect(
        () => service.addAssignment(
          id: 'a1',
          courseId: 'missing',
          title: 'Homework',
        ),
        throwsException,
      );
      expect(
        () => service.addAssignment(id: 'a1', courseId: 'c1', title: ''),
        throwsException,
      );
      expect(service.assignments, isEmpty);
      final assignment = add();
      expect(() => add(), throwsException);
      expect(service.assignments, [assignment]);
    });

    test(
      'complete, repeat complete, reopen and complete again follow timestamps',
      () {
        final assignment = add(due: now.subtract(const Duration(hours: 1)));
        service.markCompleted('a1', now);
        service.markCompleted('a1', now.add(const Duration(minutes: 1)));
        expect(assignment.completedAt, now);
        expect(service.getDeadlineStatus('a1', now), DeadlineStatus.completed);
        service.reopenAssignment('a1');
        expect(assignment.status, AssignmentStatus.pending);
        expect(assignment.completedAt, isNull);
        expect(service.getDeadlineStatus('a1', now), DeadlineStatus.overdue);
        service.reopenAssignment('a1');
        final later = now.add(const Duration(hours: 1));
        service.markCompleted('a1', later);
        expect(assignment.completedAt, later);
      },
    );

    test('editing preserves completion and can clear optional fields', () {
      final assignment = add(due: now);
      service.markCompleted('a1', now);
      service.updateAssignment(
        'a1',
        courseId: 'c2',
        title: 'SQL Homework',
        description: 'Practice joins',
        dueDateTime: now.add(const Duration(days: 1)),
      );
      expect(assignment.courseId, 'c2');
      expect(assignment.title, 'SQL Homework');
      expect(assignment.description, 'Practice joins');
      expect(assignment.status, AssignmentStatus.completed);
      expect(assignment.completedAt, now);
      service.updateAssignment('a1', courseId: 'c2', title: 'SQL Homework');
      expect(assignment.dueDateTime, isNull);
      expect(assignment.description, isNull);
      expect(assignment.completedAt, now);
    });

    test('invalid edits preserve all original fields', () {
      final assignment = add(due: now);
      expect(
        () => service.updateAssignment(
          'a1',
          courseId: 'missing',
          title: 'Changed',
        ),
        throwsException,
      );
      expect(
        () => service.updateAssignment('a1', courseId: 'c2', title: ''),
        throwsException,
      );
      expect(assignment.courseId, 'c1');
      expect(assignment.title, 'Flutter Homework');
      expect(assignment.dueDateTime, now);
    });

    test('deadline classification handles exact instant, today and future', () {
      add(due: now);
      expect(service.getDeadlineStatus('a1', now), DeadlineStatus.dueToday);
      expect(
        service.getDeadlineStatus('a1', now.add(const Duration(seconds: 1))),
        DeadlineStatus.overdue,
      );
      service.updateAssignment(
        'a1',
        courseId: 'c1',
        title: 'Homework',
        dueDateTime: now.add(const Duration(hours: 1)),
      );
      expect(service.getDeadlineStatus('a1', now), DeadlineStatus.dueToday);
      service.updateAssignment(
        'a1',
        courseId: 'c1',
        title: 'Homework',
        dueDateTime: now.add(const Duration(days: 1)),
      );
      expect(service.getDeadlineStatus('a1', now), DeadlineStatus.upcoming);
    });

    test(
      'queries filter by course and deletion preserves unrelated assignments',
      () {
        final first = add();
        final second = service.addAssignment(
          id: 'a2',
          courseId: 'c2',
          title: 'SQL Homework',
        );
        expect(service.getAssignmentsByCourse('c1'), [first]);
        expect(
          () => service.getAssignmentsByCourse('missing'),
          throwsException,
        );
        service.deleteAssignment('a1');
        expect(service.assignments, [second]);
        expect(service.getAssignmentsByCourse('c1'), isEmpty);
      },
    );

    test('operations reject missing assignment IDs without changing data', () {
      final assignment = add();
      expect(
        () => service.updateAssignment(
          'missing',
          courseId: 'c1',
          title: 'Homework',
        ),
        throwsException,
      );
      expect(() => service.markCompleted('missing', now), throwsException);
      expect(() => service.reopenAssignment('missing'), throwsException);
      expect(() => service.deleteAssignment('missing'), throwsException);
      expect(() => service.getDeadlineStatus('missing', now), throwsException);
      expect(service.assignments, [assignment]);
      expect(assignment.status, AssignmentStatus.pending);
    });
  });
}
