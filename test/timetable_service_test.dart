import 'package:flutter_test/flutter_test.dart';
import 'package:romlek/model/class_schedule.dart';
import 'package:romlek/model/class_session.dart';
import 'package:romlek/model/course.dart';
import 'package:romlek/service/timetable_service.dart';

void main() {
  late TimetableService service;
  late ClassSchedule first;
  late ClassSchedule second;
  final from = DateTime(2026, 11, 19);
  final to = DateTime(2026, 12, 1);

  setUp(() {
    first = ClassSchedule(
      id: 's1',
      name: 'Term 1',
      startDate: DateTime(2026, 11, 19),
      endDate: DateTime(2026, 12, 31),
    );
    second = ClassSchedule(
      id: 's2',
      name: 'Evening Classes',
      startDate: first.startDate,
      endDate: first.endDate,
    );
    first.courseIds.add('c1');
    second.courseIds.add('c2');
    service = TimetableService(
      schedules: [first, second],
      courses: [
        Course(id: 'c1', name: 'Mobile Development'),
        Course(id: 'c2', name: 'Database Systems'),
      ],
    );
  });

  ClassSession weekly(
    String id, {
    String courseId = 'c1',
    int weekday = DateTime.monday,
    int start = 480,
    int end = 600,
  }) {
    return ClassSession(
      id: id,
      courseId: courseId,
      type: ClassSessionType.weekly,
      weekday: weekday,
      startMinutes: start,
      endMinutes: end,
      room: 'Room A',
      preparationNotes: 'Review notes',
    );
  }

  ClassSession makeup(
    String id,
    DateTime date, {
    int start = 600,
    int end = 660,
  }) {
    return ClassSession(
      id: id,
      courseId: 'c1',
      type: ClassSessionType.makeup,
      date: date,
      startMinutes: start,
      endMinutes: end,
    );
  }

  bool add(
    ClassSession session, {
    String scheduleId = 's1',
    bool saveAnyway = false,
  }) {
    return service.addSession(
      scheduleId,
      session,
      from: from,
      to: to,
      saveAnyway: saveAnyway,
    );
  }

  group('TimetableService', () {
    test('extending an ended weekly class rechecks newly active conflicts', () {
      add(weekly('w1'));
      service.endWeeklySession('s1', 'w1', DateTime(2026, 11, 23));
      add(weekly('w2', courseId: 'c2'), scheduleId: 's2');
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
      first.endDate = DateTime(2026, 11, 20);
      service.addMakeup(
        's1',
        makeup('m1', DateTime(2026, 11, 23), start: 480, end: 600),
        from: from,
        to: to,
        saveAnyway: true,
      );
      add(weekly('w2', courseId: 'c2'), scheduleId: 's2');
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
      final proposed = weekly('w1');
      expect(
        service.previewAddSession('s1', proposed, from: from, to: to),
        isEmpty,
      );
      add(weekly('w2', courseId: 'c2'), scheduleId: 's2');
      expect(add(proposed), isFalse);
      expect(first.sessions, isEmpty);
      expect(add(proposed, saveAnyway: true), isTrue);
      expect(service.findConflicts(from, to).length, 2);
    });

    test('creates empty timetables and validates dates, names and IDs', () {
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
        final session = weekly('w1');
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
        expect(add(session), isTrue);
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
      for (final session in [
        weekly(''),
        weekly('x', courseId: 'missing'),
        weekly('x', courseId: 'c2'),
        weekly('x', weekday: 0),
        weekly('x', weekday: 8),
        weekly('x', start: -1),
        weekly('x', end: 1441),
        weekly('x', start: 600, end: 600),
        weekly('x', start: 600, end: 500),
      ]) {
        expect(() => add(session), throwsException);
      }
      final inconsistent = weekly('w1');
      inconsistent.date = from;
      expect(() => add(inconsistent), throwsException);
      final noWeekday = weekly('w1');
      noWeekday.weekday = null;
      expect(() => add(noWeekday), throwsException);
      expect(
        () => service.previewAddSession(
          'missing',
          weekly('w1'),
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
        add(weekly('w1'));
        expect(() => add(weekly('w1')), throwsException);
        expect(
          () => add(weekly('w1', courseId: 'c2'), scheduleId: 's2'),
          throwsException,
        );
        second.courseIds.add('c1');
        expect(() => add(weekly('w2')), throwsException);
        expect(first.sessions.length, 1);
        expect(second.sessions, isEmpty);
      },
    );

    test(
      'queries respect schedule dates, exact query boundaries and midnight end',
      () {
        first.endDate = DateTime(2026, 11, 23);
        add(weekly('w1', start: 0, end: 1440));
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
        add(weekly('w1'));
        expect(
          service.addMakeup(
            's1',
            makeup('m1', DateTime(2026, 11, 21)),
            from: from,
            to: to,
          ),
          isTrue,
        );
        expect(service.getClassOccurrences('s1', from, to).length, 3);
        final changed = makeup(
          'm1',
          DateTime(2026, 11, 22),
          start: 660,
          end: 720,
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
          () => service.addMakeup('s1', weekly('w2'), from: from, to: to),
          throwsException,
        );
        expect(
          () => service.updateMakeup('s1', weekly('m1'), from: from, to: to),
          throwsException,
        );
        final invalid = makeup('m1', from, start: 700, end: 600);
        expect(
          () => service.updateMakeup('s1', invalid, from: from, to: to),
          throwsException,
        );
        expect(first.sessions.last.date, DateTime(2026, 11, 22));
      },
    );

    test('invalid makeup fields do not add records', () {
      final missingDate = makeup('m1', from);
      missingDate.date = null;
      final withWeekday = makeup('m2', from);
      withWeekday.weekday = DateTime.monday;
      final withUnavailable = makeup('m3', from);
      withUnavailable.unavailableDates[from] = 'Unavailable';
      final withEnd = makeup('m4', from);
      withEnd.recurrenceEndDate = to;
      for (final session in [
        missingDate,
        withWeekday,
        withUnavailable,
        withEnd,
      ]) {
        expect(() => add(session), throwsException);
      }
      expect(first.sessions, isEmpty);
    });

    test('out-of-range makeup warns, requires acceptance and becomes active after range edit', () {
      first.endDate = DateTime(2026, 11, 20);
      final session = makeup('m1', DateTime(2026, 11, 21));
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
      add(weekly('w1'));
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
        add(weekly('w1'));
        final conflicting = weekly('w2', courseId: 'c2', start: 540, end: 660);
        expect(
          service.previewAddSession('s2', conflicting, from: from, to: to),
          isNotEmpty,
        );
        expect(add(conflicting, scheduleId: 's2'), isFalse);
        expect(second.sessions, isEmpty);
        expect(add(conflicting, scheduleId: 's2', saveAnyway: true), isTrue);
        final pairs = service.findConflicts(from, to);
        expect(pairs.length, 2);
        expect(pairs.first.map((item) => item.sessionId).toSet(), {'w1', 'w2'});
        expect(service.getClassOccurrences('s1', from, to).length, 2);
        expect(service.getClassOccurrences('s2', from, to).length, 2);
      },
    );

    test('touching classes are allowed and makeup conflicts are detected', () {
      add(weekly('w1'));
      expect(
        add(
          weekly('w2', courseId: 'c2', start: 600, end: 660),
          scheduleId: 's2',
        ),
        isTrue,
      );
      expect(service.findConflicts(from, to), isEmpty);
      final session = makeup(
        'm1',
        DateTime(2026, 11, 23),
        start: 570,
        end: 630,
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
        add(weekly('w1'));
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
        expect(add(other, scheduleId: 's2'), isTrue);
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
      add(weekly('w1'));
      final current = first.sessions.single;
      final day = DateTime(2026, 11, 23);
      service.markUnavailable('s1', 'w1', day, reason: 'Unavailable');
      final changed = weekly(
        'w1',
        weekday: DateTime.tuesday,
        start: 600,
        end: 660,
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
      add(weekly('w1'));
      add(
        weekly('w2', courseId: 'c2', weekday: DateTime.tuesday),
        scheduleId: 's2',
      );
      final changed = weekly('w1', weekday: DateTime.tuesday);
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
          weekly('w1', end: 400),
          from: from,
          to: to,
        ),
        throwsException,
      );
      expect(
        () => service.updateWeeklySession(
          's1',
          weekly('missing'),
          from: from,
          to: to,
        ),
        throwsException,
      );
      expect(
        () => service.updateWeeklySession(
          's1',
          makeup('w1', from),
          from: from,
          to: to,
        ),
        throwsException,
      );
      expect(
        () =>
            service.updateMakeup('s1', makeup('w1', from), from: from, to: to),
        throwsException,
      );
      expect(first.sessions.single.weekday, DateTime.tuesday);
    });

    test(
      'ending weekly recurrence is exclusive and preserves dated makeups',
      () {
        add(weekly('w1'));
        service.addMakeup(
          's1',
          makeup('m1', DateTime(2026, 11, 30)),
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
      add(weekly('w1'));
      service.addMakeup(
        's1',
        makeup('m1', DateTime(2026, 11, 21)),
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
