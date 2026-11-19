import 'package:flutter_test/flutter_test.dart';
import 'package:romlek/model/assessment.dart';
import 'package:romlek/model/assignment.dart';
import 'package:romlek/model/class_schedule.dart';
import 'package:romlek/model/class_session.dart';
import 'package:romlek/model/course.dart';
import 'package:romlek/service/course_service.dart';

void main() {
  late ClassSchedule first;
  late ClassSchedule second;
  late CourseService service;

  setUp(() {
    first = ClassSchedule(
      id: 'schedule-1',
      name: 'Term 1',
      startDate: DateTime(2026, 11, 1),
    );
    second = ClassSchedule(
      id: 'schedule-2',
      name: 'Term 2',
      startDate: DateTime(2027, 1, 1),
    );
    service = CourseService(
      schedules: [first, second],
      courses: [],
      assignments: [],
      assessments: [],
    );
  });

  Course addCourse(String id, String name, String scheduleId) {
    return service.addCourse(id: id, scheduleId: scheduleId, name: name);
  }

  group('CourseService', () {
    test('course move previews conflicts and requires Save Anyway', () {
      final course = addCourse('course-1', 'Mobile Development', first.id);
      final other = addCourse('course-2', 'Database Systems', second.id);
      first.endDate = DateTime(2026, 11, 20);
      second.startDate = first.startDate;
      final makeup = ClassSession(
        id: 'm1',
        courseId: course.id,
        type: ClassSessionType.makeup,
        date: DateTime(2026, 11, 23),
        startMinutes: 480,
        endMinutes: 600,
      );
      first.sessions.add(makeup);
      second.sessions.add(
        ClassSession(
          id: 'w1',
          courseId: other.id,
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 480,
          endMinutes: 600,
        ),
      );
      final from = DateTime(2026, 11, 19);
      final to = DateTime(2026, 12, 1);
      final warnings = service.previewMoveCourse(
        course.id,
        second.id,
        from: from,
        to: to,
      );
      expect(warnings.any((warning) => warning.contains('overlaps')), isTrue);
      expect(
        service.moveCourse(course.id, second.id, from: from, to: to),
        isFalse,
      );
      expect(first.sessions, [makeup]);
      expect(
        service.moveCourse(
          course.id,
          second.id,
          from: from,
          to: to,
          saveAnyway: true,
        ),
        isTrue,
      );
      expect(second.courseIds, [other.id, course.id]);
      expect(second.sessions.last, same(makeup));
    });

    test(
      'moves the Course and its sessions while preserving related records',
      () {
        final course = addCourse('course-1', 'Mobile Development', first.id);
        second.startDate = first.startDate;
        final weekly = ClassSession(
          id: 'w1',
          courseId: course.id,
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 480,
          endMinutes: 600,
          preparationNotes: 'Review lists',
        );
        final makeup = ClassSession(
          id: 'm1',
          courseId: course.id,
          type: ClassSessionType.makeup,
          date: DateTime(2026, 11, 21),
          startMinutes: 600,
          endMinutes: 660,
        );
        first.sessions.addAll([weekly, makeup]);
        final assignment = Assignment(
          id: 'a1',
          courseId: course.id,
          title: 'Flutter Homework',
        );
        final assessment = Assessment(
          id: 'q1',
          courseId: course.id,
          title: 'Dart Quiz',
          type: AssessmentType.quiz,
          dateTime: DateTime(2026, 11, 19, 10),
        );
        service.assignments.add(assignment);
        service.assessments.add(assessment);
        final from = DateTime(2026, 11, 19);
        final to = DateTime(2026, 12, 1);
        expect(
          service.previewMoveCourse(course.id, second.id, from: from, to: to),
          isEmpty,
        );
        expect(
          service.moveCourse(
            course.id,
            second.id,
            from: from,
            to: to,
            confirmed: false,
          ),
          isFalse,
        );
        expect(first.courseIds, [course.id]);
        expect(
          service.moveCourse(course.id, second.id, from: from, to: to),
          isTrue,
        );
        expect(first.courseIds, isEmpty);
        expect(first.sessions, isEmpty);
        expect(second.courseIds, [course.id]);
        expect(second.sessions, [weekly, makeup]);
        expect(second.sessions.first, same(weekly));
        expect(weekly.preparationNotes, 'Review lists');
        expect(service.assignments.single, same(assignment));
        expect(service.assessments.single, same(assessment));
        expect(service.courses.single, same(course));
        expect(
          service.moveCourse(course.id, second.id, from: from, to: to),
          isTrue,
        );
        expect(second.courseIds, [course.id]);
      },
    );

    test(
      'move warnings require acceptance and invalid moves leave data intact',
      () {
        final course = addCourse('course-1', 'Mobile Development', first.id);
        final session = ClassSession(
          id: 'm1',
          courseId: course.id,
          type: ClassSessionType.makeup,
          date: DateTime(2026, 11, 21),
          startMinutes: 600,
          endMinutes: 660,
        );
        first.sessions.add(session);
        final from = DateTime(2026, 11, 19);
        final to = DateTime(2027, 1, 10);
        expect(
          service.previewMoveCourse(course.id, second.id, from: from, to: to),
          isNotEmpty,
        );
        expect(
          service.moveCourse(course.id, second.id, from: from, to: to),
          isFalse,
        );
        expect(
          () => service.moveCourse(course.id, 'missing', from: from, to: to),
          throwsException,
        );
        expect(
          () => service.moveCourse('missing', second.id, from: from, to: to),
          throwsException,
        );
        expect(
          () => service.moveCourse(course.id, second.id, from: to, to: from),
          throwsException,
        );
        expect(first.sessions, [session]);
        expect(first.courseIds, [course.id]);
        expect(second.courseIds, isEmpty);
        expect(
          service.moveCourse(
            course.id,
            second.id,
            from: from,
            to: to,
            saveAnyway: true,
          ),
          isTrue,
        );
        expect(second.sessions, [session]);
        expect(second.sessions.single.date, DateTime(2026, 11, 21));
      },
    );

    test(
      'timetable deletion removes all dependents and keeps unrelated data',
      () {
        final course = addCourse('course-1', 'Mobile Development', first.id);
        final other = addCourse('course-2', 'Database Systems', second.id);
        first.sessions.add(
          ClassSession(
            id: 'w1',
            courseId: course.id,
            type: ClassSessionType.weekly,
            weekday: DateTime.monday,
            startMinutes: 480,
            endMinutes: 600,
          ),
        );
        service.assignments.addAll([
          Assignment(id: 'a1', courseId: course.id, title: 'Flutter Homework'),
          Assignment(id: 'a2', courseId: other.id, title: 'SQL Homework'),
        ]);
        service.assessments.addAll([
          Assessment(
            id: 'q1',
            courseId: course.id,
            title: 'Dart Quiz',
            type: AssessmentType.quiz,
            dateTime: DateTime(2026, 11, 19),
          ),
          Assessment(
            id: 'q2',
            courseId: other.id,
            title: 'SQL Quiz',
            type: AssessmentType.quiz,
            dateTime: DateTime(2027, 1, 19),
          ),
        ]);
        expect(service.deleteSchedule(first.id, confirmed: false), isFalse);
        expect(service.schedules, [first, second]);
        expect(service.deleteSchedule(first.id, confirmed: true), isTrue);
        expect(service.schedules, [second]);
        expect(service.courses, [other]);
        expect(service.assignments.single.id, 'a2');
        expect(service.assessments.single.id, 'q2');
        expect(first.sessions, isEmpty);
        expect(first.courseIds, isEmpty);
        expect(second.courseIds, [other.id]);
      },
    );

    test('timetable deletion validates everything before any removal', () {
      final course = addCourse('course-1', 'Mobile Development', first.id);
      first.courseIds.add('missing');
      expect(
        () => service.deleteSchedule(first.id, confirmed: true),
        throwsException,
      );
      expect(service.courses, [course]);
      expect(service.schedules, [first, second]);
      expect(first.courseIds, [course.id, 'missing']);
      expect(
        () => service.deleteSchedule('missing', confirmed: true),
        throwsException,
      );
      first.courseIds.remove('missing');
      first.sessions.add(
        ClassSession(
          id: 'bad',
          courseId: 'missing',
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 480,
          endMinutes: 600,
        ),
      );
      expect(
        () => service.deleteSchedule(first.id, confirmed: true),
        throwsException,
      );
      expect(first.sessions.length, 1);
      expect(service.courses, [course]);
    });

    test('adds a course to exactly one timetable', () {
      final course = addCourse('course-1', 'Mobile Development', first.id);

      expect(course.name, 'Mobile Development');
      expect(service.courses, [course]);
      expect(first.courseIds, [course.id]);
      expect(second.courseIds, isEmpty);
      expect(first.sessions, isEmpty);
    });

    test('invalid additions leave courses and membership unchanged', () {
      expect(
        () => addCourse('course-1', 'Mobile Development', 'missing'),
        throwsException,
      );
      expect(
        () => addCourse('', 'Mobile Development', first.id),
        throwsException,
      );
      expect(() => addCourse('course-1', '', first.id), throwsException);

      expect(service.courses, isEmpty);
      expect(first.courseIds, isEmpty);
      expect(second.courseIds, isEmpty);
    });

    test('rejects duplicate IDs and global names ignoring case', () {
      final course = addCourse('course-1', 'Mobile Development', first.id);

      expect(
        () => addCourse('course-1', 'Database Systems', second.id),
        throwsException,
      );
      expect(
        () => addCourse('course-2', 'mobile DEVELOPMENT', second.id),
        throwsException,
      );

      expect(service.courses, [course]);
      expect(first.courseIds, [course.id]);
      expect(second.courseIds, isEmpty);
    });

    test('rejects an ID already referenced by a timetable', () {
      second.courseIds.add('course-1');

      expect(
        () => addCourse('course-1', 'Mobile Development', first.id),
        throwsException,
      );
      expect(service.courses, isEmpty);
      expect(first.courseIds, isEmpty);
      expect(second.courseIds, ['course-1']);
    });

    test(
      'renames without changing identity or membership, including same name',
      () {
        final course = addCourse('course-1', 'Mobile Development', first.id);

        service.renameCourse(course.id, 'mobile DEVELOPMENT');
        expect(course.name, 'mobile DEVELOPMENT');
        service.renameCourse(course.id, 'Database Systems');

        expect(course.name, 'Database Systems');
        expect(course.id, 'course-1');
        expect(first.courseIds, [course.id]);
        expect(service.courses.single, same(course));
      },
    );

    test('invalid renames preserve the existing course', () {
      final course = addCourse('course-1', 'Mobile Development', first.id);
      addCourse('course-2', 'Database Systems', second.id);

      expect(() => service.renameCourse(course.id, ''), throwsException);

      expect(
        () => service.renameCourse(course.id, 'database SYSTEMS'),
        throwsException,
      );
      expect(
        () => service.renameCourse('missing', 'New Name'),
        throwsException,
      );
      expect(course.name, 'Mobile Development');
      expect(first.courseIds, [course.id]);
    });

    test(
      'lists only selected timetable courses and supports an empty timetable',
      () {
        expect(service.getCoursesForSchedule(first.id), isEmpty);
        final course = addCourse('course-1', 'Mobile Development', first.id);
        addCourse('course-2', 'Database Systems', second.id);

        final result = service.getCoursesForSchedule(first.id);
        expect(result, [course]);
        result.clear();
        expect(service.courses.length, 2);
        expect(first.courseIds, [course.id]);
        expect(() => service.getCoursesForSchedule('missing'), throwsException);
      },
    );

    test('listing rejects dangling or duplicate membership', () {
      first.courseIds.add('missing');
      expect(() => service.getCoursesForSchedule(first.id), throwsException);
      first.courseIds.clear();
      final course = addCourse('course-1', 'Mobile Development', first.id);
      first.courseIds.add(course.id);

      expect(() => service.getCoursesForSchedule(first.id), throwsException);
      expect(first.courseIds, [course.id, course.id]);
    });

    test(
      'confirmed deletion cascades related records and preserves other data',
      () {
        final course = addCourse('course-1', 'Mobile Development', first.id);
        final otherCourse = addCourse('course-2', 'Database Systems', first.id);
        final otherTimetableCourse = addCourse(
          'course-3',
          'Networks',
          second.id,
        );
        final weekly = ClassSession(
          id: 'session-1',
          courseId: course.id,
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 480,
          endMinutes: 600,
          preparationNotes: 'Review lists',
        );
        weekly.unavailableDates[DateTime(2026, 11, 23)] = 'Unavailable';
        final makeup = ClassSession(
          id: 'session-2',
          courseId: course.id,
          type: ClassSessionType.makeup,
          date: DateTime(2026, 11, 21),
          startMinutes: 480,
          endMinutes: 600,
        );
        final otherSession = ClassSession(
          id: 'session-3',
          courseId: otherCourse.id,
          type: ClassSessionType.weekly,
          weekday: DateTime.tuesday,
          startMinutes: 480,
          endMinutes: 600,
        );
        first.sessions.addAll([weekly, makeup, otherSession]);
        service.assignments.addAll([
          Assignment(
            id: 'assignment-1',
            courseId: course.id,
            title: 'Flutter Homework',
          ),
          Assignment(
            id: 'assignment-2',
            courseId: otherCourse.id,
            title: 'SQL Homework',
          ),
        ]);
        service.assessments.addAll([
          Assessment(
            id: 'assessment-1',
            courseId: course.id,
            title: 'Dart Quiz',
            type: AssessmentType.quiz,
            dateTime: DateTime(2026, 11, 19, 10),
          ),
          Assessment(
            id: 'assessment-2',
            courseId: otherTimetableCourse.id,
            title: 'Networks Exam',
            type: AssessmentType.exam,
            dateTime: DateTime(2027, 1, 19, 10),
          ),
        ]);

        expect(service.deleteCourse(course.id, confirmed: true), isTrue);

        expect(service.courses, [otherCourse, otherTimetableCourse]);
        expect(first.courseIds, [otherCourse.id]);
        expect(first.sessions, [otherSession]);
        expect(service.assignments.single.id, 'assignment-2');
        expect(service.assessments.single.id, 'assessment-2');
        expect(second.courseIds, [otherTimetableCourse.id]);
        expect(service.schedules, [first, second]);
      },
    );

    test('cancelled deletion preserves course and related records', () {
      final course = addCourse('course-1', 'Mobile Development', first.id);
      final assignment = Assignment(
        id: 'assignment-1',
        courseId: course.id,
        title: 'Flutter Homework',
      );
      service.assignments.add(assignment);

      expect(service.deleteCourse(course.id, confirmed: false), isFalse);
      expect(service.courses, [course]);
      expect(first.courseIds, [course.id]);
      expect(service.assignments, [assignment]);
    });

    test('missing course deletion throws without removing data', () {
      final course = addCourse('course-1', 'Mobile Development', first.id);

      expect(
        () => service.deleteCourse('missing', confirmed: true),
        throwsException,
      );
      expect(service.courses, [course]);
      expect(first.courseIds, [course.id]);
    });

    test(
      'inconsistent ownership blocks rename and deletion before changes',
      () {
        final course = addCourse('course-1', 'Mobile Development', first.id);
        second.courseIds.add(course.id);
        final assignment = Assignment(
          id: 'assignment-1',
          courseId: course.id,
          title: 'Flutter Homework',
        );
        service.assignments.add(assignment);

        expect(
          () => service.renameCourse(course.id, 'New Name'),
          throwsException,
        );
        expect(
          () => service.deleteCourse(course.id, confirmed: true),
          throwsException,
        );
        expect(course.name, 'Mobile Development');
        expect(service.courses, [course]);
        expect(first.courseIds, [course.id]);
        expect(second.courseIds, [course.id]);
        expect(service.assignments, [assignment]);
      },
    );

    test(
      'session in a wrong timetable blocks deletion without partial changes',
      () {
        final course = addCourse('course-1', 'Mobile Development', first.id);
        final session = ClassSession(
          id: 'session-1',
          courseId: course.id,
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 480,
          endMinutes: 600,
        );
        second.sessions.add(session);

        expect(
          () => service.deleteCourse(course.id, confirmed: true),
          throwsException,
        );
        expect(service.courses, [course]);
        expect(first.courseIds, [course.id]);
        expect(second.sessions, [session]);
      },
    );
  });
}
