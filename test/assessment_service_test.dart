import 'package:flutter_test/flutter_test.dart';
import 'package:romlek/model/assessment.dart';
import 'package:romlek/model/course.dart';
import 'package:romlek/service/assessment_service.dart';

void main() {
  final now = DateTime(2026, 11, 19, 10);

  group('AssessmentService', () {
    test('adds quizzes and exams including past dates', () {
      final service = AssessmentService(
        courses: [
          Course(id: 'c1', name: 'Mobile Development'),
          Course(id: 'c2', name: 'Database Systems'),
        ],
        assessments: [],
      );

      final quiz = service.addAssessment(
        id: 'q1',
        courseId: 'c1',
        title: 'Dart Quiz',
        type: AssessmentType.quiz,
        dateTime: now.subtract(const Duration(days: 1)),
      );
      final exam = service.addAssessment(
        id: 'e1',
        courseId: 'c1',
        title: 'Dart Quiz',
        type: AssessmentType.exam,
        dateTime: now,
      );
      expect(quiz.type, AssessmentType.quiz);
      expect(exam.type, AssessmentType.exam);
      expect(service.assessments, [quiz, exam]);
    });

    test('invalid additions and duplicate IDs leave data unchanged', () {
      final service = AssessmentService(
        courses: [
          Course(id: 'c1', name: 'Mobile Development'),
          Course(id: 'c2', name: 'Database Systems'),
        ],
        assessments: [],
      );

      expect(
        () => service.addAssessment(
          id: '',
          courseId: 'c1',
          title: 'Dart Quiz',
          type: AssessmentType.quiz,
          dateTime: now,
        ),
        throwsException,
      );
      expect(
        () => service.addAssessment(
          id: 'q1',
          courseId: 'missing',
          title: 'Dart Quiz',
          type: AssessmentType.quiz,
          dateTime: now,
        ),
        throwsException,
      );
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
      final quiz = service.addAssessment(
        id: 'q1',
        courseId: 'c1',
        title: 'Dart Quiz',
        type: AssessmentType.quiz,
        dateTime: now,
      );
      expect(
        () => service.addAssessment(
          id: 'q1',
          courseId: 'c1',
          title: 'Dart Quiz',
          type: AssessmentType.quiz,
          dateTime: now,
        ),
        throwsException,
      );
      expect(service.assessments, [quiz]);
    });

    test(
      'edits preserve identity and move attached preparation with the date',
      () {
        final service = AssessmentService(
          courses: [
            Course(id: 'c1', name: 'Mobile Development'),
            Course(id: 'c2', name: 'Database Systems'),
          ],
          assessments: [],
        );

        final quiz = service.addAssessment(
          id: 'q1',
          courseId: 'c1',
          title: 'Dart Quiz',
          type: AssessmentType.quiz,
          dateTime: now,
        );
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
      final service = AssessmentService(
        courses: [
          Course(id: 'c1', name: 'Mobile Development'),
          Course(id: 'c2', name: 'Database Systems'),
        ],
        assessments: [],
      );

      final quiz = service.addAssessment(
        id: 'q1',
        courseId: 'c1',
        title: 'Dart Quiz',
        type: AssessmentType.quiz,
        dateTime: now,
      );
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
        final service = AssessmentService(
          courses: [
            Course(id: 'c1', name: 'Mobile Development'),
            Course(id: 'c2', name: 'Database Systems'),
          ],
          assessments: [],
        );

        final atStart = service.addAssessment(
          id: 'q1',
          courseId: 'c1',
          title: 'Dart Quiz',
          type: AssessmentType.quiz,
          dateTime: now,
        );
        final atEnd = service.addAssessment(
          id: 'q2',
          courseId: 'c2',
          title: 'Dart Quiz',
          type: AssessmentType.quiz,
          dateTime: now.add(const Duration(days: 1)),
        );
        final middle = service.addAssessment(
          id: 'q3',
          courseId: 'c1',
          title: 'Dart Quiz',
          type: AssessmentType.quiz,
          dateTime: now.add(const Duration(hours: 1)),
        );
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
      final service = AssessmentService(
        courses: [
          Course(id: 'c1', name: 'Mobile Development'),
          Course(id: 'c2', name: 'Database Systems'),
        ],
        assessments: [],
      );

      final first = service.addAssessment(
        id: 'q1',
        courseId: 'c1',
        title: 'Dart Quiz',
        type: AssessmentType.quiz,
        dateTime: now,
      );
      final second = service.addAssessment(
        id: 'q2',
        courseId: 'c1',
        title: 'Dart Quiz',
        type: AssessmentType.quiz,
        dateTime: now,
      );
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
