import 'package:flutter_test/flutter_test.dart';
import 'package:romlek/model/class_schedule.dart';
import 'package:romlek/model/class_session.dart';
import 'package:romlek/model/course.dart';
import 'package:romlek/service/timetable_service.dart';

void main() {
  final from = DateTime(2026, 11, 19);
  final to = DateTime(2026, 12, 1);

  group('TimetableService', () {
    test('extending an ended weekly class rechecks newly active conflicts', () {
      final first = ClassSchedule(
        id: 's1',
        name: 'Term 1',
        startDate: DateTime(2026, 11, 19),
        endDate: DateTime(2026, 12, 31),
      );
      final second = ClassSchedule(
        id: 's2',
        name: 'Evening Classes',
        startDate: first.startDate,
        endDate: first.endDate,
      );
      first.courseIds.add('c1');
      second.courseIds.add('c2');
      final service = TimetableService(
        schedules: [first, second],
        courses: [
          Course(id: 'c1', name: 'Mobile Development'),
          Course(id: 'c2', name: 'Database Systems'),
        ],
      );

      service.addSession(
        's1',
        ClassSession(
          id: 'w1',
          courseId: 'c1',
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 480,
          endMinutes: 600,
          room: 'Room A',
          preparationNotes: 'Review notes',
        ),
        from: from,
        to: to,
      );
      service.endWeeklySession('s1', 'w1', DateTime(2026, 11, 23));
      service.addSession(
        's2',
        ClassSession(
          id: 'w2',
          courseId: 'c2',
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 480,
          endMinutes: 600,
          room: 'Room A',
          preparationNotes: 'Review notes',
        ),
        from: from,
        to: to,
      );
      expect(service.findConflicts(from, to), isEmpty);
      expect(
        service.previewEndWeeklySession('s1', 'w1', DateTime(2026, 11, 30)),
        isNotEmpty,
      );
      expect(
        service.endWeeklySession('s1', 'w1', DateTime(2026, 11, 30)),
        isFalse,
      );
      expect(first.sessions.single.recurrenceEndDate, DateTime(2026, 11, 23));
      expect(
        service.endWeeklySession(
          's1',
          'w1',
          DateTime(2026, 11, 30),
          saveAnyway: true,
        ),
        isTrue,
      );
      expect(service.findConflicts(from, to).length, 1);
    });

    test('changing dates rechecks conflicts when an out-of-range makeup becomes active', () {
      final first = ClassSchedule(
        id: 's1',
        name: 'Term 1',
        startDate: DateTime(2026, 11, 19),
        endDate: DateTime(2026, 12, 31),
      );
      final second = ClassSchedule(
        id: 's2',
        name: 'Evening Classes',
        startDate: first.startDate,
        endDate: first.endDate,
      );
      first.courseIds.add('c1');
      second.courseIds.add('c2');
      final service = TimetableService(
        schedules: [first, second],
        courses: [
          Course(id: 'c1', name: 'Mobile Development'),
          Course(id: 'c2', name: 'Database Systems'),
        ],
      );

      first.endDate = DateTime(2026, 11, 20);
      service.addMakeup(
        's1',
        ClassSession(
          id: 'm1',
          courseId: 'c1',
          type: ClassSessionType.makeup,
          date: DateTime(2026, 11, 23),
          startMinutes: 480,
          endMinutes: 600,
        ),
        from: from,
        to: to,
        saveAnyway: true,
      );
      service.addSession(
        's2',
        ClassSession(
          id: 'w2',
          courseId: 'c2',
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 480,
          endMinutes: 600,
          room: 'Room A',
          preparationNotes: 'Review notes',
        ),
        from: from,
        to: to,
      );
      expect(service.findConflicts(from, to), isEmpty);
      expect(
        service.previewUpdateSchedule(
          's1',
          name: 'Term 1',
          startDate: from,
          endDate: to,
          from: from,
          to: to,
        ),
        isNotEmpty,
      );
      expect(
        service.updateSchedule(
          's1',
          name: 'Term 1',
          startDate: from,
          endDate: to,
          from: from,
          to: to,
        ),
        isFalse,
      );
      expect(first.endDate, DateTime(2026, 11, 20));
      expect(
        service.updateSchedule(
          's1',
          name: 'Term 1',
          startDate: from,
          endDate: to,
          from: from,
          to: to,
          saveAnyway: true,
        ),
        isTrue,
      );
      expect(service.findConflicts(from, to).length, 1);
    });

    test('saving revalidates even after an earlier clean preview', () {
      final first = ClassSchedule(
        id: 's1',
        name: 'Term 1',
        startDate: DateTime(2026, 11, 19),
        endDate: DateTime(2026, 12, 31),
      );
      final second = ClassSchedule(
        id: 's2',
        name: 'Evening Classes',
        startDate: first.startDate,
        endDate: first.endDate,
      );
      first.courseIds.add('c1');
      second.courseIds.add('c2');
      final service = TimetableService(
        schedules: [first, second],
        courses: [
          Course(id: 'c1', name: 'Mobile Development'),
          Course(id: 'c2', name: 'Database Systems'),
        ],
      );

      final proposed = ClassSession(
        id: 'w1',
        courseId: 'c1',
        type: ClassSessionType.weekly,
        weekday: DateTime.monday,
        startMinutes: 480,
        endMinutes: 600,
        room: 'Room A',
        preparationNotes: 'Review notes',
      );
      expect(
        service.previewAddSession('s1', proposed, from: from, to: to),
        isEmpty,
      );
      service.addSession(
        's2',
        ClassSession(
          id: 'w2',
          courseId: 'c2',
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 480,
          endMinutes: 600,
          room: 'Room A',
          preparationNotes: 'Review notes',
        ),
        from: from,
        to: to,
      );
      expect(service.addSession('s1', proposed, from: from, to: to), isFalse);
      expect(first.sessions, isEmpty);
      expect(
        service.addSession(
          's1',
          proposed,
          from: from,
          to: to,
          saveAnyway: true,
        ),
        isTrue,
      );
      expect(service.findConflicts(from, to).length, 2);
    });

    test('creates empty timetables and validates dates, names and IDs', () {
      final first = ClassSchedule(
        id: 's1',
        name: 'Term 1',
        startDate: DateTime(2026, 11, 19),
        endDate: DateTime(2026, 12, 31),
      );
      final second = ClassSchedule(
        id: 's2',
        name: 'Evening Classes',
        startDate: first.startDate,
        endDate: first.endDate,
      );
      first.courseIds.add('c1');
      second.courseIds.add('c2');
      final service = TimetableService(
        schedules: [first, second],
        courses: [
          Course(id: 'c1', name: 'Mobile Development'),
          Course(id: 'c2', name: 'Database Systems'),
        ],
      );

      final schedule = service.addSchedule(
        id: 's3',
        name: 'Term 2',
        startDate: from,
        endDate: from,
      );
      expect(schedule.sessions, isEmpty);
      expect(schedule.courseIds, isEmpty);
      expect(schedule.endDate, from);
      expect(
        () => service.addSchedule(id: 's3', name: 'Term 2', startDate: from),
        throwsException,
      );
      expect(
        () => service.addSchedule(id: '', name: 'Term 2', startDate: from),
        throwsException,
      );
      expect(
        () => service.addSchedule(id: 's4', name: '', startDate: from),
        throwsException,
      );
      expect(
        () => service.addSchedule(
          id: 's4',
          name: 'Term 2',
          startDate: to,
          endDate: from,
        ),
        throwsException,
      );
      expect(service.schedules.length, 3);
    });

    test(
      'previews without mutation, supports cancel and generates weekly dates',
      () {
        final first = ClassSchedule(
          id: 's1',
          name: 'Term 1',
          startDate: DateTime(2026, 11, 19),
          endDate: DateTime(2026, 12, 31),
        );
        final second = ClassSchedule(
          id: 's2',
          name: 'Evening Classes',
          startDate: first.startDate,
          endDate: first.endDate,
        );
        first.courseIds.add('c1');
        second.courseIds.add('c2');
        final service = TimetableService(
          schedules: [first, second],
          courses: [
            Course(id: 'c1', name: 'Mobile Development'),
            Course(id: 'c2', name: 'Database Systems'),
          ],
        );

        final session = ClassSession(
          id: 'w1',
          courseId: 'c1',
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 480,
          endMinutes: 600,
          room: 'Room A',
          preparationNotes: 'Review notes',
        );
        expect(
          service.previewAddSession('s1', session, from: from, to: to),
          isEmpty,
        );
        expect(first.sessions, isEmpty);
        expect(
          service.addSession(
            's1',
            session,
            from: from,
            to: to,
            confirmed: false,
          ),
          isFalse,
        );
        expect(first.sessions, isEmpty);
        expect(service.addSession('s1', session, from: from, to: to), isTrue);
        final occurrences = service.getClassOccurrences('s1', from, to);
        expect(occurrences.map((item) => item.start), [
          DateTime(2026, 11, 23, 8),
          DateTime(2026, 11, 30, 8),
        ]);
        expect(occurrences.first.end, DateTime(2026, 11, 23, 10));
        expect(occurrences.first.preparationNotes, 'Review notes');
        session.weekday = DateTime.friday;
        expect(first.sessions.single.weekday, DateTime.monday);
      },
    );

    test('invalid sessions throw without adding anything', () {
      final first = ClassSchedule(
        id: 's1',
        name: 'Term 1',
        startDate: DateTime(2026, 11, 19),
        endDate: DateTime(2026, 12, 31),
      );
      final second = ClassSchedule(
        id: 's2',
        name: 'Evening Classes',
        startDate: first.startDate,
        endDate: first.endDate,
      );
      first.courseIds.add('c1');
      second.courseIds.add('c2');
      final service = TimetableService(
        schedules: [first, second],
        courses: [
          Course(id: 'c1', name: 'Mobile Development'),
          Course(id: 'c2', name: 'Database Systems'),
        ],
      );

      for (final session in [
        ClassSession(
          id: '',
          courseId: 'c1',
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 480,
          endMinutes: 600,
          room: 'Room A',
          preparationNotes: 'Review notes',
        ),
        ClassSession(
          id: 'x',
          courseId: 'missing',
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 480,
          endMinutes: 600,
          room: 'Room A',
          preparationNotes: 'Review notes',
        ),
        ClassSession(
          id: 'x',
          courseId: 'c2',
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 480,
          endMinutes: 600,
          room: 'Room A',
          preparationNotes: 'Review notes',
        ),
        ClassSession(
          id: 'x',
          courseId: 'c1',
          type: ClassSessionType.weekly,
          weekday: 0,
          startMinutes: 480,
          endMinutes: 600,
          room: 'Room A',
          preparationNotes: 'Review notes',
        ),
        ClassSession(
          id: 'x',
          courseId: 'c1',
          type: ClassSessionType.weekly,
          weekday: 8,
          startMinutes: 480,
          endMinutes: 600,
          room: 'Room A',
          preparationNotes: 'Review notes',
        ),
        ClassSession(
          id: 'x',
          courseId: 'c1',
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: -1,
          endMinutes: 600,
          room: 'Room A',
          preparationNotes: 'Review notes',
        ),
        ClassSession(
          id: 'x',
          courseId: 'c1',
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 480,
          endMinutes: 1441,
          room: 'Room A',
          preparationNotes: 'Review notes',
        ),
        ClassSession(
          id: 'x',
          courseId: 'c1',
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 600,
          endMinutes: 600,
          room: 'Room A',
          preparationNotes: 'Review notes',
        ),
        ClassSession(
          id: 'x',
          courseId: 'c1',
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 600,
          endMinutes: 500,
          room: 'Room A',
          preparationNotes: 'Review notes',
        ),
      ]) {
        expect(
          () => service.addSession('s1', session, from: from, to: to),
          throwsException,
        );
      }
      final inconsistent = ClassSession(
        id: 'w1',
        courseId: 'c1',
        type: ClassSessionType.weekly,
        weekday: DateTime.monday,
        startMinutes: 480,
        endMinutes: 600,
        room: 'Room A',
        preparationNotes: 'Review notes',
      );
      inconsistent.date = from;
      expect(
        () => service.addSession('s1', inconsistent, from: from, to: to),
        throwsException,
      );
      final noWeekday = ClassSession(
        id: 'w1',
        courseId: 'c1',
        type: ClassSessionType.weekly,
        weekday: DateTime.monday,
        startMinutes: 480,
        endMinutes: 600,
        room: 'Room A',
        preparationNotes: 'Review notes',
      );
      noWeekday.weekday = null;
      expect(
        () => service.addSession('s1', noWeekday, from: from, to: to),
        throwsException,
      );
      expect(
        () => service.previewAddSession(
          'missing',
          ClassSession(
            id: 'w1',
            courseId: 'c1',
            type: ClassSessionType.weekly,
            weekday: DateTime.monday,
            startMinutes: 480,
            endMinutes: 600,
            room: 'Room A',
            preparationNotes: 'Review notes',
          ),
          from: from,
          to: to,
        ),
        throwsException,
      );
      expect(first.sessions, isEmpty);
    });

    test(
      'duplicate session IDs and duplicate course ownership are rejected',
      () {
        final first = ClassSchedule(
          id: 's1',
          name: 'Term 1',
          startDate: DateTime(2026, 11, 19),
          endDate: DateTime(2026, 12, 31),
        );
        final second = ClassSchedule(
          id: 's2',
          name: 'Evening Classes',
          startDate: first.startDate,
          endDate: first.endDate,
        );
        first.courseIds.add('c1');
        second.courseIds.add('c2');
        final service = TimetableService(
          schedules: [first, second],
          courses: [
            Course(id: 'c1', name: 'Mobile Development'),
            Course(id: 'c2', name: 'Database Systems'),
          ],
        );

        service.addSession(
          's1',
          ClassSession(
            id: 'w1',
            courseId: 'c1',
            type: ClassSessionType.weekly,
            weekday: DateTime.monday,
            startMinutes: 480,
            endMinutes: 600,
            room: 'Room A',
            preparationNotes: 'Review notes',
          ),
          from: from,
          to: to,
        );
        expect(
          () => service.addSession(
            's1',
            ClassSession(
              id: 'w1',
              courseId: 'c1',
              type: ClassSessionType.weekly,
              weekday: DateTime.monday,
              startMinutes: 480,
              endMinutes: 600,
              room: 'Room A',
              preparationNotes: 'Review notes',
            ),
            from: from,
            to: to,
          ),
          throwsException,
        );
        expect(
          () => service.addSession(
            's2',
            ClassSession(
              id: 'w1',
              courseId: 'c2',
              type: ClassSessionType.weekly,
              weekday: DateTime.monday,
              startMinutes: 480,
              endMinutes: 600,
              room: 'Room A',
              preparationNotes: 'Review notes',
            ),
            from: from,
            to: to,
          ),
          throwsException,
        );
        second.courseIds.add('c1');
        expect(
          () => service.addSession(
            's1',
            ClassSession(
              id: 'w2',
              courseId: 'c1',
              type: ClassSessionType.weekly,
              weekday: DateTime.monday,
              startMinutes: 480,
              endMinutes: 600,
              room: 'Room A',
              preparationNotes: 'Review notes',
            ),
            from: from,
            to: to,
          ),
          throwsException,
        );
        expect(first.sessions.length, 1);
        expect(second.sessions, isEmpty);
      },
    );

    test(
      'queries respect schedule dates, exact query boundaries and midnight end',
      () {
        final first = ClassSchedule(
          id: 's1',
          name: 'Term 1',
          startDate: DateTime(2026, 11, 19),
          endDate: DateTime(2026, 12, 31),
        );
        final second = ClassSchedule(
          id: 's2',
          name: 'Evening Classes',
          startDate: first.startDate,
          endDate: first.endDate,
        );
        first.courseIds.add('c1');
        second.courseIds.add('c2');
        final service = TimetableService(
          schedules: [first, second],
          courses: [
            Course(id: 'c1', name: 'Mobile Development'),
            Course(id: 'c2', name: 'Database Systems'),
          ],
        );

        first.endDate = DateTime(2026, 11, 23);
        service.addSession(
          's1',
          ClassSession(
            id: 'w1',
            courseId: 'c1',
            type: ClassSessionType.weekly,
            weekday: DateTime.monday,
            startMinutes: 0,
            endMinutes: 1440,
            room: 'Room A',
            preparationNotes: 'Review notes',
          ),
          from: from,
          to: to,
        );
        expect(
          service.getClassOccurrences('s1', from, DateTime(2026, 11, 23)),
          isEmpty,
        );
        final result = service.getClassOccurrences(
          's1',
          DateTime(2026, 11, 23),
          to,
        );
        expect(result.length, 1);
        expect(result.single.end, DateTime(2026, 11, 24));
        expect(service.getClassOccurrences('s1', from, from), isEmpty);
        expect(
          () => service.getClassOccurrences('s1', to, from),
          throwsException,
        );
        expect(
          () => service.getClassOccurrences('missing', from, to),
          throwsException,
        );
        expect(() => service.findConflicts(to, from), throwsException);
      },
    );

    test(
      'makeup is extra and can be edited without changing the weekly class',
      () {
        final first = ClassSchedule(
          id: 's1',
          name: 'Term 1',
          startDate: DateTime(2026, 11, 19),
          endDate: DateTime(2026, 12, 31),
        );
        final second = ClassSchedule(
          id: 's2',
          name: 'Evening Classes',
          startDate: first.startDate,
          endDate: first.endDate,
        );
        first.courseIds.add('c1');
        second.courseIds.add('c2');
        final service = TimetableService(
          schedules: [first, second],
          courses: [
            Course(id: 'c1', name: 'Mobile Development'),
            Course(id: 'c2', name: 'Database Systems'),
          ],
        );

        service.addSession(
          's1',
          ClassSession(
            id: 'w1',
            courseId: 'c1',
            type: ClassSessionType.weekly,
            weekday: DateTime.monday,
            startMinutes: 480,
            endMinutes: 600,
            room: 'Room A',
            preparationNotes: 'Review notes',
          ),
          from: from,
          to: to,
        );
        expect(
          service.addMakeup(
            's1',
            ClassSession(
              id: 'm1',
              courseId: 'c1',
              type: ClassSessionType.makeup,
              date: DateTime(2026, 11, 21),
              startMinutes: 600,
              endMinutes: 660,
            ),
            from: from,
            to: to,
          ),
          isTrue,
        );
        expect(service.getClassOccurrences('s1', from, to).length, 3);
        final changed = ClassSession(
          id: 'm1',
          courseId: 'c1',
          type: ClassSessionType.makeup,
          date: DateTime(2026, 11, 22),
          startMinutes: 660,
          endMinutes: 720,
        );
        changed.preparationNotes = 'Practice widgets';
        expect(
          service.previewUpdateSession('s1', changed, from: from, to: to),
          isEmpty,
        );
        expect(
          service.updateMakeup(
            's1',
            changed,
            from: from,
            to: to,
            confirmed: false,
          ),
          isFalse,
        );
        expect(first.sessions.last.date, DateTime(2026, 11, 21));
        expect(service.updateMakeup('s1', changed, from: from, to: to), isTrue);
        expect(first.sessions.last.id, 'm1');
        expect(first.sessions.last.preparationNotes, 'Practice widgets');
        expect(first.sessions.last.date, DateTime(2026, 11, 22));
        expect(first.sessions.first.weekday, DateTime.monday);
        expect(
          () => service.addMakeup(
            's1',
            ClassSession(
              id: 'w2',
              courseId: 'c1',
              type: ClassSessionType.weekly,
              weekday: DateTime.monday,
              startMinutes: 480,
              endMinutes: 600,
              room: 'Room A',
              preparationNotes: 'Review notes',
            ),
            from: from,
            to: to,
          ),
          throwsException,
        );
        expect(
          () => service.updateMakeup(
            's1',
            ClassSession(
              id: 'm1',
              courseId: 'c1',
              type: ClassSessionType.weekly,
              weekday: DateTime.monday,
              startMinutes: 480,
              endMinutes: 600,
              room: 'Room A',
              preparationNotes: 'Review notes',
            ),
            from: from,
            to: to,
          ),
          throwsException,
        );
        final invalid = ClassSession(
          id: 'm1',
          courseId: 'c1',
          type: ClassSessionType.makeup,
          date: from,
          startMinutes: 700,
          endMinutes: 600,
        );
        expect(
          () => service.updateMakeup('s1', invalid, from: from, to: to),
          throwsException,
        );
        expect(first.sessions.last.date, DateTime(2026, 11, 22));
      },
    );

    test('invalid makeup fields do not add records', () {
      final first = ClassSchedule(
        id: 's1',
        name: 'Term 1',
        startDate: DateTime(2026, 11, 19),
        endDate: DateTime(2026, 12, 31),
      );
      final second = ClassSchedule(
        id: 's2',
        name: 'Evening Classes',
        startDate: first.startDate,
        endDate: first.endDate,
      );
      first.courseIds.add('c1');
      second.courseIds.add('c2');
      final service = TimetableService(
        schedules: [first, second],
        courses: [
          Course(id: 'c1', name: 'Mobile Development'),
          Course(id: 'c2', name: 'Database Systems'),
        ],
      );

      final missingDate = ClassSession(
        id: 'm1',
        courseId: 'c1',
        type: ClassSessionType.makeup,
        date: from,
        startMinutes: 600,
        endMinutes: 660,
      );
      missingDate.date = null;
      final withWeekday = ClassSession(
        id: 'm2',
        courseId: 'c1',
        type: ClassSessionType.makeup,
        date: from,
        startMinutes: 600,
        endMinutes: 660,
      );
      withWeekday.weekday = DateTime.monday;
      final withUnavailable = ClassSession(
        id: 'm3',
        courseId: 'c1',
        type: ClassSessionType.makeup,
        date: from,
        startMinutes: 600,
        endMinutes: 660,
      );
      withUnavailable.unavailableDates[from] = 'Unavailable';
      final withEnd = ClassSession(
        id: 'm4',
        courseId: 'c1',
        type: ClassSessionType.makeup,
        date: from,
        startMinutes: 600,
        endMinutes: 660,
      );
      withEnd.recurrenceEndDate = to;
      for (final session in [
        missingDate,
        withWeekday,
        withUnavailable,
        withEnd,
      ]) {
        expect(
          () => service.addSession('s1', session, from: from, to: to),
          throwsException,
        );
      }
      expect(first.sessions, isEmpty);
    });

    test('out-of-range makeup warns, requires acceptance and becomes active after range edit', () {
      final first = ClassSchedule(
        id: 's1',
        name: 'Term 1',
        startDate: DateTime(2026, 11, 19),
        endDate: DateTime(2026, 12, 31),
      );
      final second = ClassSchedule(
        id: 's2',
        name: 'Evening Classes',
        startDate: first.startDate,
        endDate: first.endDate,
      );
      first.courseIds.add('c1');
      second.courseIds.add('c2');
      final service = TimetableService(
        schedules: [first, second],
        courses: [
          Course(id: 'c1', name: 'Mobile Development'),
          Course(id: 'c2', name: 'Database Systems'),
        ],
      );

      first.endDate = DateTime(2026, 11, 20);
      final session = ClassSession(
        id: 'm1',
        courseId: 'c1',
        type: ClassSessionType.makeup,
        date: DateTime(2026, 11, 21),
        startMinutes: 600,
        endMinutes: 660,
      );
      expect(
        service.previewAddSession('s1', session, from: from, to: to),
        isNotEmpty,
      );
      expect(service.addMakeup('s1', session, from: from, to: to), isFalse);
      expect(first.sessions, isEmpty);
      expect(
        service.addMakeup('s1', session, from: from, to: to, saveAnyway: true),
        isTrue,
      );
      expect(service.getClassOccurrences('s1', from, to), isEmpty);
      expect(
        service.updateSchedule(
          's1',
          from: from,
          to: to,
          name: 'Term 1',
          startDate: from,
          endDate: to,
        ),
        isTrue,
      );
      expect(
        service.getClassOccurrences('s1', from, to).single.sessionId,
        'm1',
      );
      expect(
        service.previewUpdateSchedule(
          's1',
          from: from,
          to: to,
          name: 'Term 1',
          startDate: from,
          endDate: from,
        ),
        isNotEmpty,
      );
      expect(
        service.updateSchedule(
          's1',
          from: from,
          to: to,
          name: 'Term 1',
          startDate: from,
          endDate: from,
        ),
        isFalse,
      );
      expect(first.endDate, to);
      expect(
        service.updateSchedule(
          's1',
          from: from,
          to: to,
          name: 'Term 1',
          startDate: from,
          endDate: from,
          saveAnyway: true,
        ),
        isTrue,
      );
      expect(first.sessions.single.id, 'm1');
      expect(service.getClassOccurrences('s1', from, to), isEmpty);
    });

    test('unavailable dates retain reasons and notes, omit active class, and can restore', () {
      final first = ClassSchedule(
        id: 's1',
        name: 'Term 1',
        startDate: DateTime(2026, 11, 19),
        endDate: DateTime(2026, 12, 31),
      );
      final second = ClassSchedule(
        id: 's2',
        name: 'Evening Classes',
        startDate: first.startDate,
        endDate: first.endDate,
      );
      first.courseIds.add('c1');
      second.courseIds.add('c2');
      final service = TimetableService(
        schedules: [first, second],
        courses: [
          Course(id: 'c1', name: 'Mobile Development'),
          Course(id: 'c2', name: 'Database Systems'),
        ],
      );

      service.addSession(
        's1',
        ClassSession(
          id: 'w1',
          courseId: 'c1',
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 480,
          endMinutes: 600,
          room: 'Room A',
          preparationNotes: 'Review notes',
        ),
        from: from,
        to: to,
      );
      final day = DateTime(2026, 11, 23);
      service.markUnavailable('s1', 'w1', day, reason: 'Lecturer unavailable');
      expect(service.getClassOccurrences('s1', from, to).length, 1);
      expect(service.getUnavailableDates('s1', 'w1', from, to), {
        day: 'Lecturer unavailable',
      });
      expect(first.sessions.single.preparationNotes, 'Review notes');
      expect(
        service.restoreUnavailable('s1', 'w1', day, confirmed: false),
        isFalse,
      );
      expect(service.previewRestoreUnavailable('s1', 'w1', day), isEmpty);
      expect(service.restoreUnavailable('s1', 'w1', day), isTrue);
      expect(service.getClassOccurrences('s1', from, to).length, 2);
      expect(service.getUnavailableDates('s1', 'w1', from, to), isEmpty);
      expect(
        () => service.restoreUnavailable('s1', 'w1', day),
        throwsException,
      );
      expect(
        () => service.markUnavailable('s1', 'w1', DateTime(2026, 11, 24)),
        throwsException,
      );
      expect(
        () => service.markUnavailable('s1', 'w1', DateTime(2026, 11, 16)),
        throwsException,
      );
      expect(
        () => service.markUnavailable('s1', 'missing', day),
        throwsException,
      );
      expect(
        () => service.getUnavailableDates('s1', 'w1', to, from),
        throwsException,
      );
    });

    test(
      'cross-timetable conflicts warn and Save Anyway keeps both occurrences',
      () {
        final first = ClassSchedule(
          id: 's1',
          name: 'Term 1',
          startDate: DateTime(2026, 11, 19),
          endDate: DateTime(2026, 12, 31),
        );
        final second = ClassSchedule(
          id: 's2',
          name: 'Evening Classes',
          startDate: first.startDate,
          endDate: first.endDate,
        );
        first.courseIds.add('c1');
        second.courseIds.add('c2');
        final service = TimetableService(
          schedules: [first, second],
          courses: [
            Course(id: 'c1', name: 'Mobile Development'),
            Course(id: 'c2', name: 'Database Systems'),
          ],
        );

        service.addSession(
          's1',
          ClassSession(
            id: 'w1',
            courseId: 'c1',
            type: ClassSessionType.weekly,
            weekday: DateTime.monday,
            startMinutes: 480,
            endMinutes: 600,
            room: 'Room A',
            preparationNotes: 'Review notes',
          ),
          from: from,
          to: to,
        );
        final conflicting = ClassSession(
          id: 'w2',
          courseId: 'c2',
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 540,
          endMinutes: 660,
          room: 'Room A',
          preparationNotes: 'Review notes',
        );
        expect(
          service.previewAddSession('s2', conflicting, from: from, to: to),
          isNotEmpty,
        );
        expect(
          service.addSession('s2', conflicting, from: from, to: to),
          isFalse,
        );
        expect(second.sessions, isEmpty);
        expect(
          service.addSession(
            's2',
            conflicting,
            from: from,
            to: to,
            saveAnyway: true,
          ),
          isTrue,
        );
        final pairs = service.findConflicts(from, to);
        expect(pairs.length, 2);
        expect(pairs.first.map((item) => item.sessionId).toSet(), {'w1', 'w2'});
        expect(service.getClassOccurrences('s1', from, to).length, 2);
        expect(service.getClassOccurrences('s2', from, to).length, 2);
      },
    );

    test('touching classes are allowed and makeup conflicts are detected', () {
      final first = ClassSchedule(
        id: 's1',
        name: 'Term 1',
        startDate: DateTime(2026, 11, 19),
        endDate: DateTime(2026, 12, 31),
      );
      final second = ClassSchedule(
        id: 's2',
        name: 'Evening Classes',
        startDate: first.startDate,
        endDate: first.endDate,
      );
      first.courseIds.add('c1');
      second.courseIds.add('c2');
      final service = TimetableService(
        schedules: [first, second],
        courses: [
          Course(id: 'c1', name: 'Mobile Development'),
          Course(id: 'c2', name: 'Database Systems'),
        ],
      );

      service.addSession(
        's1',
        ClassSession(
          id: 'w1',
          courseId: 'c1',
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 480,
          endMinutes: 600,
          room: 'Room A',
          preparationNotes: 'Review notes',
        ),
        from: from,
        to: to,
      );
      expect(
        service.addSession(
          's2',
          ClassSession(
            id: 'w2',
            courseId: 'c2',
            type: ClassSessionType.weekly,
            weekday: DateTime.monday,
            startMinutes: 600,
            endMinutes: 660,
            room: 'Room A',
            preparationNotes: 'Review notes',
          ),
          from: from,
          to: to,
        ),
        isTrue,
      );
      expect(service.findConflicts(from, to), isEmpty);
      final session = ClassSession(
        id: 'm1',
        courseId: 'c1',
        type: ClassSessionType.makeup,
        date: DateTime(2026, 11, 23),
        startMinutes: 570,
        endMinutes: 630,
      );
      expect(service.addMakeup('s1', session, from: from, to: to), isFalse);
      expect(
        service.addMakeup('s1', session, from: from, to: to, saveAnyway: true),
        isTrue,
      );
      expect(service.findConflicts(from, to).length, 2);
    });

    test(
      'restoring an unavailable class rechecks conflicts before changing data',
      () {
        final first = ClassSchedule(
          id: 's1',
          name: 'Term 1',
          startDate: DateTime(2026, 11, 19),
          endDate: DateTime(2026, 12, 31),
        );
        final second = ClassSchedule(
          id: 's2',
          name: 'Evening Classes',
          startDate: first.startDate,
          endDate: first.endDate,
        );
        first.courseIds.add('c1');
        second.courseIds.add('c2');
        final service = TimetableService(
          schedules: [first, second],
          courses: [
            Course(id: 'c1', name: 'Mobile Development'),
            Course(id: 'c2', name: 'Database Systems'),
          ],
        );

        service.addSession(
          's1',
          ClassSession(
            id: 'w1',
            courseId: 'c1',
            type: ClassSessionType.weekly,
            weekday: DateTime.monday,
            startMinutes: 480,
            endMinutes: 600,
            room: 'Room A',
            preparationNotes: 'Review notes',
          ),
          from: from,
          to: to,
        );
        final day = DateTime(2026, 11, 23);
        service.markUnavailable('s1', 'w1', day);
        final other = ClassSession(
          id: 'm2',
          courseId: 'c2',
          type: ClassSessionType.makeup,
          date: day,
          startMinutes: 480,
          endMinutes: 600,
        );
        expect(service.addSession('s2', other, from: from, to: to), isTrue);
        expect(service.findConflicts(from, to), isEmpty);
        expect(service.previewRestoreUnavailable('s1', 'w1', day), isNotEmpty);
        expect(service.restoreUnavailable('s1', 'w1', day), isFalse);
        expect(first.sessions.single.unavailableDates.containsKey(day), isTrue);
        expect(
          service.restoreUnavailable('s1', 'w1', day, saveAnyway: true),
          isTrue,
        );
        expect(service.findConflicts(from, to).length, 1);
      },
    );

    test('weekly edits preserve identity and require explicit clearing of mismatched dates', () {
      final first = ClassSchedule(
        id: 's1',
        name: 'Term 1',
        startDate: DateTime(2026, 11, 19),
        endDate: DateTime(2026, 12, 31),
      );
      final second = ClassSchedule(
        id: 's2',
        name: 'Evening Classes',
        startDate: first.startDate,
        endDate: first.endDate,
      );
      first.courseIds.add('c1');
      second.courseIds.add('c2');
      final service = TimetableService(
        schedules: [first, second],
        courses: [
          Course(id: 'c1', name: 'Mobile Development'),
          Course(id: 'c2', name: 'Database Systems'),
        ],
      );

      service.addSession(
        's1',
        ClassSession(
          id: 'w1',
          courseId: 'c1',
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 480,
          endMinutes: 600,
          room: 'Room A',
          preparationNotes: 'Review notes',
        ),
        from: from,
        to: to,
      );
      final current = first.sessions.single;
      final day = DateTime(2026, 11, 23);
      service.markUnavailable('s1', 'w1', day, reason: 'Unavailable');
      final changed = ClassSession(
        id: 'w1',
        courseId: 'c1',
        type: ClassSessionType.weekly,
        weekday: DateTime.tuesday,
        startMinutes: 600,
        endMinutes: 660,
        room: 'Room A',
        preparationNotes: 'Review notes',
      );
      changed.room = 'Room B';
      expect(
        service.previewUpdateSession('s1', changed, from: from, to: to),
        isNotEmpty,
      );
      expect(
        service.updateWeeklySession(
          's1',
          changed,
          from: from,
          to: to,
          saveAnyway: true,
        ),
        isFalse,
      );
      expect(current.weekday, DateTime.monday);
      expect(current.unavailableDates.containsKey(day), isTrue);
      expect(
        service.updateWeeklySession(
          's1',
          changed,
          from: from,
          to: to,
          saveAnyway: true,
          clearUnavailableDates: true,
        ),
        isTrue,
      );
      expect(first.sessions.single, same(current));
      expect(current.id, 'w1');
      expect(current.room, 'Room B');
      expect(current.unavailableDates, isEmpty);
      expect(
        service.getClassOccurrences('s1', from, to).single.start,
        DateTime(2026, 11, 24, 10),
      );
    });

    test('weekly edit validates input and overlaps before applying fields', () {
      final first = ClassSchedule(
        id: 's1',
        name: 'Term 1',
        startDate: DateTime(2026, 11, 19),
        endDate: DateTime(2026, 12, 31),
      );
      final second = ClassSchedule(
        id: 's2',
        name: 'Evening Classes',
        startDate: first.startDate,
        endDate: first.endDate,
      );
      first.courseIds.add('c1');
      second.courseIds.add('c2');
      final service = TimetableService(
        schedules: [first, second],
        courses: [
          Course(id: 'c1', name: 'Mobile Development'),
          Course(id: 'c2', name: 'Database Systems'),
        ],
      );

      service.addSession(
        's1',
        ClassSession(
          id: 'w1',
          courseId: 'c1',
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 480,
          endMinutes: 600,
          room: 'Room A',
          preparationNotes: 'Review notes',
        ),
        from: from,
        to: to,
      );
      service.addSession(
        's2',
        ClassSession(
          id: 'w2',
          courseId: 'c2',
          type: ClassSessionType.weekly,
          weekday: DateTime.tuesday,
          startMinutes: 480,
          endMinutes: 600,
          room: 'Room A',
          preparationNotes: 'Review notes',
        ),
        from: from,
        to: to,
      );
      final changed = ClassSession(
        id: 'w1',
        courseId: 'c1',
        type: ClassSessionType.weekly,
        weekday: DateTime.tuesday,
        startMinutes: 480,
        endMinutes: 600,
        room: 'Room A',
        preparationNotes: 'Review notes',
      );
      expect(
        service.updateWeeklySession('s1', changed, from: from, to: to),
        isFalse,
      );
      expect(first.sessions.single.weekday, DateTime.monday);
      expect(
        service.updateWeeklySession(
          's1',
          changed,
          from: from,
          to: to,
          saveAnyway: true,
        ),
        isTrue,
      );
      expect(service.findConflicts(from, to), isNotEmpty);
      expect(
        () => service.updateWeeklySession(
          's1',
          ClassSession(
            id: 'w1',
            courseId: 'c1',
            type: ClassSessionType.weekly,
            weekday: DateTime.monday,
            startMinutes: 480,
            endMinutes: 400,
            room: 'Room A',
            preparationNotes: 'Review notes',
          ),
          from: from,
          to: to,
        ),
        throwsException,
      );
      expect(
        () => service.updateWeeklySession(
          's1',
          ClassSession(
            id: 'missing',
            courseId: 'c1',
            type: ClassSessionType.weekly,
            weekday: DateTime.monday,
            startMinutes: 480,
            endMinutes: 600,
            room: 'Room A',
            preparationNotes: 'Review notes',
          ),
          from: from,
          to: to,
        ),
        throwsException,
      );
      expect(
        () => service.updateWeeklySession(
          's1',
          ClassSession(
            id: 'w1',
            courseId: 'c1',
            type: ClassSessionType.makeup,
            date: from,
            startMinutes: 600,
            endMinutes: 660,
          ),
          from: from,
          to: to,
        ),
        throwsException,
      );
      expect(
        () => service.updateMakeup(
          's1',
          ClassSession(
            id: 'w1',
            courseId: 'c1',
            type: ClassSessionType.makeup,
            date: from,
            startMinutes: 600,
            endMinutes: 660,
          ),
          from: from,
          to: to,
        ),
        throwsException,
      );
      expect(first.sessions.single.weekday, DateTime.tuesday);
    });

    test(
      'ending weekly recurrence is exclusive and preserves dated makeups',
      () {
        final first = ClassSchedule(
          id: 's1',
          name: 'Term 1',
          startDate: DateTime(2026, 11, 19),
          endDate: DateTime(2026, 12, 31),
        );
        final second = ClassSchedule(
          id: 's2',
          name: 'Evening Classes',
          startDate: first.startDate,
          endDate: first.endDate,
        );
        first.courseIds.add('c1');
        second.courseIds.add('c2');
        final service = TimetableService(
          schedules: [first, second],
          courses: [
            Course(id: 'c1', name: 'Mobile Development'),
            Course(id: 'c2', name: 'Database Systems'),
          ],
        );

        service.addSession(
          's1',
          ClassSession(
            id: 'w1',
            courseId: 'c1',
            type: ClassSessionType.weekly,
            weekday: DateTime.monday,
            startMinutes: 480,
            endMinutes: 600,
            room: 'Room A',
            preparationNotes: 'Review notes',
          ),
          from: from,
          to: to,
        );
        service.addMakeup(
          's1',
          ClassSession(
            id: 'm1',
            courseId: 'c1',
            type: ClassSessionType.makeup,
            date: DateTime(2026, 11, 30),
            startMinutes: 600,
            endMinutes: 660,
          ),
          from: from,
          to: to,
        );
        expect(
          service.endWeeklySession(
            's1',
            'w1',
            DateTime(2026, 11, 30),
            confirmed: false,
          ),
          isFalse,
        );
        expect(first.sessions.first.recurrenceEndDate, isNull);
        expect(
          service.endWeeklySession('s1', 'w1', DateTime(2026, 11, 30)),
          isTrue,
        );
        final occurrences = service.getClassOccurrences('s1', from, to);
        expect(occurrences.map((item) => item.sessionId), ['w1', 'm1']);
        expect(() => service.endWeeklySession('s1', 'm1', to), throwsException);
        expect(
          () => service.endWeeklySession('s1', 'missing', to),
          throwsException,
        );
        expect(
          () => service.markUnavailable('s1', 'w1', DateTime(2026, 11, 30)),
          throwsException,
        );
      },
    );

    test('session deletion needs confirmation and preserves the course and other sessions', () {
      final first = ClassSchedule(
        id: 's1',
        name: 'Term 1',
        startDate: DateTime(2026, 11, 19),
        endDate: DateTime(2026, 12, 31),
      );
      final second = ClassSchedule(
        id: 's2',
        name: 'Evening Classes',
        startDate: first.startDate,
        endDate: first.endDate,
      );
      first.courseIds.add('c1');
      second.courseIds.add('c2');
      final service = TimetableService(
        schedules: [first, second],
        courses: [
          Course(id: 'c1', name: 'Mobile Development'),
          Course(id: 'c2', name: 'Database Systems'),
        ],
      );

      service.addSession(
        's1',
        ClassSession(
          id: 'w1',
          courseId: 'c1',
          type: ClassSessionType.weekly,
          weekday: DateTime.monday,
          startMinutes: 480,
          endMinutes: 600,
          room: 'Room A',
          preparationNotes: 'Review notes',
        ),
        from: from,
        to: to,
      );
      service.addMakeup(
        's1',
        ClassSession(
          id: 'm1',
          courseId: 'c1',
          type: ClassSessionType.makeup,
          date: DateTime(2026, 11, 21),
          startMinutes: 600,
          endMinutes: 660,
        ),
        from: from,
        to: to,
      );
      expect(service.deleteSession('s1', 'w1', confirmed: false), isFalse);
      expect(first.sessions.length, 2);
      expect(service.deleteSession('s1', 'w1', confirmed: true), isTrue);
      expect(first.sessions.single.id, 'm1');
      expect(first.courseIds, ['c1']);
      expect(service.courses.length, 2);
      expect(
        () => service.deleteSession('s1', 'missing', confirmed: true),
        throwsException,
      );
      expect(
        () => service.deleteSession('missing', 'm1', confirmed: true),
        throwsException,
      );
    });

    test('invalid timetable edits do not partially change data', () {
      final first = ClassSchedule(
        id: 's1',
        name: 'Term 1',
        startDate: DateTime(2026, 11, 19),
        endDate: DateTime(2026, 12, 31),
      );
      final second = ClassSchedule(
        id: 's2',
        name: 'Evening Classes',
        startDate: first.startDate,
        endDate: first.endDate,
      );
      first.courseIds.add('c1');
      second.courseIds.add('c2');
      final service = TimetableService(
        schedules: [first, second],
        courses: [
          Course(id: 'c1', name: 'Mobile Development'),
          Course(id: 'c2', name: 'Database Systems'),
        ],
      );

      expect(
        service.updateSchedule(
          's1',
          from: from,
          to: to,
          name: 'Changed',
          startDate: from,
          endDate: to,
          confirmed: false,
        ),
        isFalse,
      );
      expect(
        () => service.updateSchedule(
          's1',
          from: from,
          to: to,
          name: '',
          startDate: from,
        ),
        throwsException,
      );
      expect(
        () => service.updateSchedule(
          's1',
          from: from,
          to: to,
          name: 'Changed',
          startDate: to,
          endDate: from,
        ),
        throwsException,
      );
      expect(
        () => service.previewUpdateSchedule(
          'missing',
          from: from,
          to: to,
          name: 'Changed',
          startDate: from,
        ),
        throwsException,
      );
      expect(first.name, 'Term 1');
      expect(first.endDate, DateTime(2026, 12, 31));
    });
  });
}
