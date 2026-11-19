import '../model/class_schedule.dart';
import '../model/class_session.dart';
import '../model/course.dart';

class ClassOccurrence {
  final String scheduleId;
  final String sessionId;
  final String courseId;
  final ClassSessionType type;
  final DateTime start;
  final DateTime end;
  final String? room;
  final String? preparationNotes;

  ClassOccurrence({
    required this.scheduleId,
    required this.sessionId,
    required this.courseId,
    required this.type,
    required this.start,
    required this.end,
    this.room,
    this.preparationNotes,
  });
}

class TimetableService {
  final List<ClassSchedule> schedules;
  final List<Course> courses;

  TimetableService({required this.schedules, required this.courses});

  ClassSchedule addSchedule({
    required String id,
    required String name,
    required DateTime startDate,
    DateTime? endDate,
    String? schoolName,
  }){
    for(final schedule in schedules){
      if(schedule.id == id){
        throw Exception('Timetable ID already exists.');
      }
    }
    final schedule = ClassSchedule(
      id: id,
      name: name.trim(),
      startDate: _date(startDate),
      endDate: endDate == null ? null : _date(endDate),
      schoolName: schoolName,
    );
    _validateSchedule(schedule);
    schedules.add(schedule);
    return schedule;
  }

  List<String> previewUpdateSchedule(
    String id, {
    required String name,
    required DateTime startDate,
    required DateTime from,
    required DateTime to,
    DateTime? endDate,
    String? schoolName,
  }){
    final current = _getSchedule(id);
    final proposed = ClassSchedule(
      id: id,
      name: name.trim(),
      startDate: _date(startDate),
      endDate: endDate == null ? null : _date(endDate),
      schoolName: schoolName,
    );
    _validateSchedule(proposed);
    _validateRange(from, to);
    final warnings = <String>[];
    final proposedOccurrences = <ClassOccurrence>[];
    for(final session in current.sessions){
      _validateSession(current, session, replacingId: session.id);
      proposedOccurrences.addAll(_occurrences(proposed, session, from, to));
      if(session.type == ClassSessionType.makeup &&
          !_insideSchedule(proposed, session.date!)){
        warnings.add(
          'Makeup ${session.id} will be outside the timetable dates.',
        );
      }
    }
    final existing = _allOccurrences(from, to);
    for(int i = 0; i < proposedOccurrences.length; i++){
      final occurrence = proposedOccurrences[i];
      for(final other in existing){
        if(other.scheduleId != id && _overlaps(occurrence, other)){
          warnings.add(
            'Session ${occurrence.sessionId} overlaps ${other.sessionId} at ${occurrence.start}.',
          );
        }
      }
      for(int j = i + 1; j < proposedOccurrences.length; j++){
        if(_overlaps(occurrence, proposedOccurrences[j])){
          warnings.add(
            'Sessions ${occurrence.sessionId} and ${proposedOccurrences[j].sessionId} overlap.',
          );
        }
      }
    }
    return warnings;
  }

  bool updateSchedule(
    String id, {
    required String name,
    required DateTime startDate,
    required DateTime from,
    required DateTime to,
    DateTime? endDate,
    String? schoolName,
    bool confirmed = true,
    bool saveAnyway = false,
  }){
    final warnings = previewUpdateSchedule(
      id,
      name: name,
      startDate: startDate,
      from: from,
      to: to,
      endDate: endDate,
      schoolName: schoolName,
    );
    if(!confirmed || (warnings.isNotEmpty && !saveAnyway)){
      return false;
    }
    final schedule = _getSchedule(id);
    schedule.name = name.trim();
    schedule.startDate = _date(startDate);
    schedule.endDate = endDate == null ? null : _date(endDate);
    schedule.schoolName = schoolName;
    return true;
  }

  List<String> previewAddSession(
    String scheduleId,
    ClassSession session, {
    required DateTime from,
    required DateTime to,
  }){
    final schedule = _getSchedule(scheduleId);
    _validateSession(schedule, session);
    return _preview(schedule, session, from, to);
  }

  bool addSession(
    String scheduleId,
    ClassSession session, {
    required DateTime from,
    required DateTime to,
    bool confirmed = true,
    bool saveAnyway = false,
  }){
    final warnings = previewAddSession(scheduleId, session, from: from, to: to);
    if(!confirmed || (warnings.isNotEmpty && !saveAnyway)){
      return false;
    }
    _getSchedule(scheduleId).sessions.add(_copy(session));
    return true;
  }

  bool addMakeup(
    String scheduleId,
    ClassSession session, {
    required DateTime from,
    required DateTime to,
    bool confirmed = true,
    bool saveAnyway = false,
  }){
    if(session.type != ClassSessionType.makeup){
      throw Exception('A makeup session is required.');
    }
    return addSession(
      scheduleId,
      session,
      from: from,
      to: to,
      confirmed: confirmed,
      saveAnyway: saveAnyway,
    );
  }

  List<String> previewUpdateSession(
    String scheduleId,
    ClassSession proposed, {
    required DateTime from,
    required DateTime to,
  }){
    final schedule = _getSchedule(scheduleId);
    final current = _getSession(schedule, proposed.id);
    if(current.type != proposed.type){
      throw Exception('Session type cannot change.');
    }
    final candidate = _copy(proposed);
    candidate.unavailableDates.clear();
    candidate.unavailableDates.addAll(current.unavailableDates);
    final mismatched = _mismatchedDates(candidate);
    for(final date in mismatched){
      candidate.unavailableDates.remove(date);
    }
    _validateSession(schedule, candidate, replacingId: current.id);
    final warnings = _preview(
      schedule,
      candidate,
      from,
      to,
      excludingId: current.id,
    );
    if(mismatched.isNotEmpty){
      warnings.add(
        'Unavailable dates no longer match the weekday. Explicit confirmation is required before clearing them.',
      );
    }
    return warnings;
  }

  bool updateWeeklySession(
    String scheduleId,
    ClassSession proposed, {
    required DateTime from,
    required DateTime to,
    bool clearUnavailableDates = false,
    bool confirmed = true,
    bool saveAnyway = false,
  }){
    if(proposed.type != ClassSessionType.weekly){
      throw Exception('A weekly session is required.');
    }
    return _updateSession(
      scheduleId,
      proposed,
      from,
      to,
      confirmed,
      saveAnyway,
      clearUnavailableDates,
    );
  }

  bool updateMakeup(
    String scheduleId,
    ClassSession proposed, {
    required DateTime from,
    required DateTime to,
    bool confirmed = true,
    bool saveAnyway = false,
  }){
    if(proposed.type != ClassSessionType.makeup){
      throw Exception('A makeup session is required.');
    }
    return _updateSession(
      scheduleId,
      proposed,
      from,
      to,
      confirmed,
      saveAnyway,
      false,
    );
  }

  bool _updateSession(
    String scheduleId,
    ClassSession proposed,
    DateTime from,
    DateTime to,
    bool confirmed,
    bool saveAnyway,
    bool clearUnavailableDates,
  ){
    final warnings = previewUpdateSession(
      scheduleId,
      proposed,
      from: from,
      to: to,
    );
    final current = _getSession(_getSchedule(scheduleId), proposed.id);
    final candidate = _copy(proposed);
    candidate.unavailableDates.clear();
    candidate.unavailableDates.addAll(current.unavailableDates);
    final mismatched = _mismatchedDates(candidate);
    if(!confirmed || (mismatched.isNotEmpty && !clearUnavailableDates)){
      return false;
    }
    for(final date in mismatched){
      candidate.unavailableDates.remove(date);
    }
    if(warnings.isNotEmpty && !saveAnyway){
      return false;
    }
    current.courseId = candidate.courseId;
    current.weekday = candidate.weekday;
    current.date = candidate.date == null ? null : _date(candidate.date!);
    current.startMinutes = candidate.startMinutes;
    current.endMinutes = candidate.endMinutes;
    current.room = candidate.room;
    current.preparationNotes = candidate.preparationNotes;
    current.recurrenceEndDate = candidate.recurrenceEndDate == null
        ? null
        : _date(candidate.recurrenceEndDate!);
    current.unavailableDates.clear();
    current.unavailableDates.addAll(candidate.unavailableDates);
    return true;
  }

  void markUnavailable(
    String scheduleId,
    String sessionId,
    DateTime date, {
    String? reason,
  }){
    final schedule = _getSchedule(scheduleId);
    final session = _getSession(schedule, sessionId);
    _validateSession(schedule, session, replacingId: session.id);
    _validateWeeklyDate(schedule, session, date);
    session.unavailableDates[_date(date)] = reason;
  }

  List<String> previewRestoreUnavailable(
    String scheduleId,
    String sessionId,
    DateTime date,
  ){
    final schedule = _getSchedule(scheduleId);
    final current = _getSession(schedule, sessionId);
    _validateWeeklyDate(schedule, current, date);
    if(!_isUnavailable(current, date)){
      throw Exception('This class date is not unavailable.');
    }
    final candidate = _copy(current);
    candidate.unavailableDates.removeWhere(
      (key, reason) => _date(key) == _date(date),
    );
    _validateSession(schedule, candidate, replacingId: current.id);
    final day = _date(date);
    return _preview(
      schedule,
      candidate,
      day,
      DateTime(day.year, day.month, day.day + 1),
      excludingId: current.id,
    );
  }

  bool restoreUnavailable(
    String scheduleId,
    String sessionId,
    DateTime date, {
    bool confirmed = true,
    bool saveAnyway = false,
  }){
    final warnings = previewRestoreUnavailable(scheduleId, sessionId, date);
    if(!confirmed || (warnings.isNotEmpty && !saveAnyway)){
      return false;
    }
    final session = _getSession(_getSchedule(scheduleId), sessionId);
    session.unavailableDates.removeWhere(
      (key, reason) => _date(key) == _date(date),
    );
    return true;
  }

  Map<DateTime, String?> getUnavailableDates(
    String scheduleId,
    String sessionId,
    DateTime from,
    DateTime to,
  ){
    _validateRange(from, to);
    final schedule = _getSchedule(scheduleId);
    final session = _getSession(schedule, sessionId);
    _validateSession(schedule, session, replacingId: session.id);
    final result = <DateTime, String?>{};
    for(final entry in session.unavailableDates.entries){
      final date = _date(entry.key);
      if(!date.isBefore(from) && date.isBefore(to)){
        result[date] = entry.value;
      }
    }
    return result;
  }

  List<String> previewEndWeeklySession(
    String scheduleId,
    String sessionId,
    DateTime endDate,
  ){
    final schedule = _getSchedule(scheduleId);
    final session = _getSession(schedule, sessionId);
    if(session.type != ClassSessionType.weekly){
      throw Exception('Only a weekly session can be ended.');
    }
    final candidate = _copy(session);
    candidate.recurrenceEndDate = _date(endDate);
    _validateSession(schedule, candidate, replacingId: session.id);
    DateTime from = _date(endDate);
    if(session.recurrenceEndDate != null &&
        _date(session.recurrenceEndDate!).isBefore(from)){
      from = _date(session.recurrenceEndDate!);
    }
    return _preview(
      schedule,
      candidate,
      from,
      _date(endDate),
      excludingId: session.id,
    );
  }

  bool endWeeklySession(
    String scheduleId,
    String sessionId,
    DateTime endDate, {
    bool confirmed = true,
    bool saveAnyway = false,
  }){
    final warnings = previewEndWeeklySession(scheduleId, sessionId, endDate);
    final schedule = _getSchedule(scheduleId);
    final session = _getSession(schedule, sessionId);
    if(session.type != ClassSessionType.weekly){
      throw Exception('Only a weekly session can be ended.');
    }
    final candidate = _copy(session);
    candidate.recurrenceEndDate = _date(endDate);
    _validateSession(schedule, candidate, replacingId: session.id);
    if(!confirmed || (warnings.isNotEmpty && !saveAnyway)){
      return false;
    }
    session.recurrenceEndDate = _date(endDate);
    return true;
  }

  bool deleteSession(
    String scheduleId,
    String sessionId, {
    required bool confirmed,
  }){
    final schedule = _getSchedule(scheduleId);
    final session = _getSession(schedule, sessionId);
    if(!confirmed){
      return false;
    }
    schedule.sessions.remove(session);
    return true;
  }

  List<ClassOccurrence> getClassOccurrences(
    String scheduleId,
    DateTime from,
    DateTime to,
  ){
    _validateRange(from, to);
    final schedule = _getSchedule(scheduleId);
    _validateSchedule(schedule);
    final result = <ClassOccurrence>[];
    for(final session in schedule.sessions){
      _validateSession(schedule, session, replacingId: session.id);
      result.addAll(_occurrences(schedule, session, from, to));
    }
    result.sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  List<List<ClassOccurrence>> findConflicts(DateTime from, DateTime to){
    final occurrences = _allOccurrences(from, to);
    final conflicts = <List<ClassOccurrence>>[];
    for(int i = 0; i < occurrences.length; i++){
      for(int j = i + 1; j < occurrences.length; j++){
        if(_overlaps(occurrences[i], occurrences[j])){
          conflicts.add([occurrences[i], occurrences[j]]);
        }
      }
    }
    return conflicts;
  }

  List<String> previewCourseMove(
    String courseId,
    String targetId,
    DateTime from,
    DateTime to,
  ){
    final target = _getSchedule(targetId);
    _validateSchedule(target);
    ClassSchedule? owner;
    int count = 0;
    for(final schedule in schedules){
      for(final id in schedule.courseIds){
        if(id == courseId){
          owner = schedule;
          count++;
        }
      }
    }
    if(count != 1 || owner == null){
      throw Exception('Course must belong to exactly one timetable.');
    }
    _validateRange(from, to);
    final warnings = <String>[];
    final existing = _allOccurrences(from, to);
    final movedOccurrences = <ClassOccurrence>[];
    for(final session in owner.sessions){
      if(session.courseId != courseId){
        continue;
      }
      if(owner != target &&
          (_date(owner.startDate) != _date(target.startDate) ||
              owner.endDate != target.endDate)){
        warnings.add(
          'Session ${session.id} will use the destination timetable dates.',
        );
      }
      if(session.type == ClassSessionType.makeup &&
          !_insideSchedule(target, session.date!)){
        warnings.add(
          'Makeup ${session.id} is outside the destination timetable dates.',
        );
      }
      for(final proposed in _occurrences(target, session, from, to)){
        movedOccurrences.add(proposed);
        for(final other in existing){
          if(other.courseId != courseId && _overlaps(proposed, other)){
            warnings.add(
              'Session ${session.id} overlaps ${other.sessionId} at ${proposed.start}.',
            );
          }
        }
      }
    }
    for(int i = 0; i < movedOccurrences.length; i++){
      for(int j = i + 1; j < movedOccurrences.length; j++){
        if(_overlaps(movedOccurrences[i], movedOccurrences[j])){
          warnings.add(
            'Moved sessions ${movedOccurrences[i].sessionId} and ${movedOccurrences[j].sessionId} overlap.',
          );
        }
      }
    }
    return warnings;
  }

  List<String> _preview(
    ClassSchedule schedule,
    ClassSession session,
    DateTime from,
    DateTime to, {
    String? excludingId,
  }){
    _validateRange(from, to);
    final warnings = <String>[];
    if(session.type == ClassSessionType.makeup &&
        !_insideSchedule(schedule, session.date!)){
      warnings.add(
        'Makeup is outside the timetable dates and will be excluded from upcoming occurrences.',
      );
    }
    final proposed = _occurrences(schedule, session, from, to);
    final existing = _allOccurrences(from, to);
    for(final occurrence in proposed){
      for(final other in existing){
        if(other.sessionId != excludingId && _overlaps(occurrence, other)){
          warnings.add(
            'Session overlaps ${other.sessionId} at ${occurrence.start}.',
          );
        }
      }
    }
    return warnings;
  }

  List<ClassOccurrence> _allOccurrences(DateTime from, DateTime to){
    _validateRange(from, to);
    final result = <ClassOccurrence>[];
    for(final schedule in schedules){
      result.addAll(getClassOccurrences(schedule.id, from, to));
    }
    return result;
  }

  List<ClassOccurrence> _occurrences(
    ClassSchedule schedule,
    ClassSession session,
    DateTime from,
    DateTime to,
  ){
    final result = <ClassOccurrence>[];
    if(!from.isBefore(to)){
      return result;
    }
    if(session.type == ClassSessionType.makeup){
      final date = _date(session.date!);
      if(_insideSchedule(schedule, date)){
        _addOccurrence(result, schedule, session, date, from, to);
      }
      return result;
    }
    DateTime day = _date(from);
    if(day.isBefore(_date(schedule.startDate))){
      day = _date(schedule.startDate);
    }
    while(day.isBefore(to)){
      if(schedule.endDate != null && day.isAfter(_date(schedule.endDate!))){
        break;
      }
      if(session.recurrenceEndDate != null &&
          !day.isBefore(_date(session.recurrenceEndDate!))){
        break;
      }
      if(day.weekday == session.weekday && !_isUnavailable(session, day)){
        _addOccurrence(result, schedule, session, day, from, to);
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return result;
  }

  void _addOccurrence(
    List<ClassOccurrence> result,
    ClassSchedule schedule,
    ClassSession session,
    DateTime day,
    DateTime from,
    DateTime to,
  ){
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      session.startMinutes ~/ 60,
      session.startMinutes % 60,
    );
    final end = DateTime(
      day.year,
      day.month,
      day.day,
      session.endMinutes ~/ 60,
      session.endMinutes % 60,
    );
    if(start.isBefore(to) && end.isAfter(from)){
      result.add(
        ClassOccurrence(
          scheduleId: schedule.id,
          sessionId: session.id,
          courseId: session.courseId,
          type: session.type,
          start: start,
          end: end,
          room: session.room,
          preparationNotes: session.preparationNotes,
        ),
      );
    }
  }

  void _validateSession(
    ClassSchedule schedule,
    ClassSession session, {
    String? replacingId,
  }){
    _validateSchedule(schedule);
    if(session.id.trim().isEmpty){
      throw Exception('Session ID must not be blank.');
    }
    int matches = 0;
    for(final timetable in schedules){
      for(final existing in timetable.sessions){
        if(existing.id == session.id){
          matches++;
          if(replacingId != session.id || timetable != schedule){
            throw Exception('Session ID already exists.');
          }
        }
      }
    }
    if(matches > 1){
      throw Exception('Session ID already exists.');
    }
    int membership = 0;
    for(final timetable in schedules){
      for(final id in timetable.courseIds){
        if(id == session.courseId){
          membership++;
        }
      }
    }
    if(membership != 1 || !schedule.courseIds.contains(session.courseId)){
      throw Exception('Course must belong to this timetable only.');
    }
    bool courseExists = false;
    for(final course in courses){
      if(course.id == session.courseId){
        courseExists = true;
      }
    }
    if(!courseExists){
      throw Exception('Course not found.');
    }
    if(session.startMinutes < 0 ||
        session.endMinutes > 1440 ||
        session.endMinutes <= session.startMinutes){
      throw Exception(
        'Class times must be within one day and end after start.',
      );
    }
    if(session.type == ClassSessionType.weekly){
      if(session.weekday == null ||
          session.weekday! < 1 ||
          session.weekday! > 7 ||
          session.date != null){
        throw Exception(
          'Weekly class requires a valid weekday and no makeup date.',
        );
      }
      if(_mismatchedDates(session).isNotEmpty){
        throw Exception('Unavailable dates must match the weekly weekday.');
      }
    } else {
      if(session.date == null ||
          session.weekday != null ||
          session.recurrenceEndDate != null ||
          session.unavailableDates.isNotEmpty){
        throw Exception(
          'Makeup requires one date, without weekly-only fields.',
        );
      }
    }
  }

  void _validateSchedule(ClassSchedule schedule){
    if(schedule.id.trim().isEmpty || schedule.name.trim().isEmpty){
      throw Exception('Timetable ID and name must not be blank.');
    }
    if(schedule.endDate != null &&
        _date(schedule.endDate!).isBefore(_date(schedule.startDate))){
      throw Exception('Timetable end must not precede start.');
    }
  }

  void _validateWeeklyDate(
    ClassSchedule schedule,
    ClassSession session,
    DateTime date,
  ){
    if(session.type != ClassSessionType.weekly ||
        session.weekday != date.weekday ||
        !_insideSchedule(schedule, date) ||
        (session.recurrenceEndDate != null &&
            !_date(date).isBefore(_date(session.recurrenceEndDate!)))){
      throw Exception('Date must be an existing weekly class occurrence.');
    }
  }

  void _validateRange(DateTime from, DateTime to){
    if(to.isBefore(from)){
      throw Exception('Range end must not precede start.');
    }
  }

  List<DateTime> _mismatchedDates(ClassSession session){
    final result = <DateTime>[];
    for(final date in session.unavailableDates.keys){
      if(session.type != ClassSessionType.weekly ||
          date.weekday != session.weekday){
        result.add(date);
      }
    }
    return result;
  }

  bool _insideSchedule(ClassSchedule schedule, DateTime date){
    return !_date(date).isBefore(_date(schedule.startDate)) &&
        (schedule.endDate == null ||
            !_date(date).isAfter(_date(schedule.endDate!)));
  }

  bool _isUnavailable(ClassSession session, DateTime date){
    for(final key in session.unavailableDates.keys){
      if(_date(key) == _date(date)){
        return true;
      }
    }
    return false;
  }

  bool _overlaps(ClassOccurrence first, ClassOccurrence second){
    return first.start.isBefore(second.end) && first.end.isAfter(second.start);
  }

  DateTime _date(DateTime value){
    return DateTime(value.year, value.month, value.day);
  }

  ClassSchedule _getSchedule(String id){
    for(final schedule in schedules){
      if(schedule.id == id){
        return schedule;
      }
    }
    throw Exception('Timetable not found.');
  }

  ClassSession _getSession(ClassSchedule schedule, String id){
    for(final session in schedule.sessions){
      if(session.id == id){
        return session;
      }
    }
    throw Exception('Session not found.');
  }

  ClassSession _copy(ClassSession session){
    final copy = ClassSession(
      id: session.id,
      courseId: session.courseId,
      type: session.type,
      weekday: session.weekday,
      date: session.date == null ? null : _date(session.date!),
      startMinutes: session.startMinutes,
      endMinutes: session.endMinutes,
      room: session.room,
      preparationNotes: session.preparationNotes,
      recurrenceEndDate: session.recurrenceEndDate == null
          ? null
          : _date(session.recurrenceEndDate!),
    );
    copy.unavailableDates.addAll(session.unavailableDates);
    return copy;
  }
}

