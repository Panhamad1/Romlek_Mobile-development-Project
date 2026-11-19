import 'package:flutter_test/flutter_test.dart';
import 'package:romlek/model/assessment.dart';
import 'package:romlek/model/course.dart';
import 'package:romlek/service/assessment_service.dart';

void main() {
  late AssessmentService service;
  final now = DateTime(2026, 11, 19, 10);

  setUp(() {
    service = AssessmentService(
      courses: [
        Course(id: 'c1', name: 'Mobile Development'),
        Course(id: 'c2', name: 'Database Systems'),
      ],
      assessments: [],
    );
  });

  Assessment add(
    String id,
    DateTime date, {
    String courseId = 'c1',
    AssessmentType type = AssessmentType.quiz,
  }) {
    return service.addAssessment(
      id: id,
      courseId: courseId,
      title: 'Dart Quiz',
      type: type,
      dateTime: date,
    );
  }

  group('AssessmentService', () {
    test('adds quizzes and exams including past dates', () {
      final quiz = add('q1', now.subtract(const Duration(days: 1)));
      final exam = add('e1', now, type: AssessmentType.exam);
      expect(quiz.type, AssessmentType.quiz);
      expect(exam.type, AssessmentType.exam);
      expect(service.assessments, [quiz, exam]);
    });

    test('invalid additions and duplicate IDs leave data unchanged', () {
      expect(() => add('', now), throwsException);
      expect(() => add('q1', now, courseId: 'missing'), throwsException);
      expect(
        () => service.addAssessment(
          id: 'q1',
          courseId: 'c1',
          title: '',
          type: AssessmentType.quiz,
          dateTime: now,
        ),
        throwsException,
      );
      expect(service.assessments, isEmpty);
      final quiz = add('q1', now);
      expect(() => add('q1', now), throwsException);
      expect(service.assessments, [quiz]);
    });

    test(
      'edits preserve identity and move attached preparation with the date',
      () {
        final quiz = add('q1', now);
        final later = now.add(const Duration(days: 2));
        service.updateAssessment(
          'q1',
          courseId: 'c2',
          title: 'SQL Exam',
          type: AssessmentType.exam,
          dateTime: later,
          notes: 'Bring a pen',
          preparationNotes: 'Review joins',
        );
        expect(quiz.id, 'q1');
        expect(quiz.courseId, 'c2');
        expect(quiz.type, AssessmentType.exam);
        expect(quiz.title, 'SQL Exam');
        expect(quiz.dateTime, later);
        expect(quiz.preparationNotes, 'Review joins');
        expect(
          service.getAssessmentsInRange(
            later,
            later.add(const Duration(days: 1)),
          ),
          [quiz],
        );
        service.updateAssessment(
          'q1',
          courseId: 'c2',
          title: 'SQL Exam',
          type: AssessmentType.exam,
          dateTime: later,
        );
        expect(quiz.notes, isNull);
        expect(quiz.preparationNotes, isNull);
      },
    );

    test('invalid edits do not partially mutate an assessment', () {
      final quiz = add('q1', now);
      expect(
        () => service.updateAssessment(
          'q1',
          courseId: 'missing',
          title: 'Changed',
          type: AssessmentType.exam,
          dateTime: now.add(const Duration(days: 1)),
        ),
        throwsException,
      );
      expect(
        () => service.updateAssessment(
          'q1',
          courseId: 'c2',
          title: '',
          type: AssessmentType.exam,
          dateTime: now,
        ),
        throwsException,
      );
      expect(quiz.courseId, 'c1');
      expect(quiz.title, 'Dart Quiz');
      expect(quiz.type, AssessmentType.quiz);
      expect(quiz.dateTime, now);
    });

    test(
      'queries filter courses and use an inclusive start and exclusive end',
      () {
        final atStart = add('q1', now);
        final atEnd = add(
          'q2',
          now.add(const Duration(days: 1)),
          courseId: 'c2',
        );
        final middle = add('q3', now.add(const Duration(hours: 1)));
        expect(service.getAssessmentsByCourse('c1'), [atStart, middle]);
        expect(service.getAssessmentsInRange(now, atEnd.dateTime), [
          atStart,
          middle,
        ]);
        expect(service.getAssessmentsInRange(now, now), isEmpty);
        expect(
          () => service.getAssessmentsByCourse('missing'),
          throwsException,
        );
        expect(
          () => service.getAssessmentsInRange(atEnd.dateTime, now),
          throwsException,
        );
      },
    );

    test('deletion requires confirmation and preserves other assessments', () {
      final first = add('q1', now);
      final second = add('q2', now);
      first.preparationNotes = 'Review lists';
      expect(service.deleteAssessment('q1', confirmed: false), isFalse);
      expect(service.assessments, [first, second]);
      expect(service.deleteAssessment('q1', confirmed: true), isTrue);
      expect(service.assessments, [second]);
      expect(
        () => service.deleteAssessment('missing', confirmed: true),
        throwsException,
      );
      expect(
        () => service.updateAssessment(
          'missing',
          courseId: 'c1',
          title: 'Quiz',
          type: AssessmentType.quiz,
          dateTime: now,
        ),
        throwsException,
      );
      expect(service.assessments, [second]);
    });
  });
}
