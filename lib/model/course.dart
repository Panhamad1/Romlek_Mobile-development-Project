class Course {
  final String id;
  String _name;

  Course({required this.id, required this._name}) {
    _name = _name.trim();
    if (id.trim() == '') {
      throw Exception('Course ID must not be empty.');
    }
    if (_name == '') {
      throw Exception('Course name must not be empty.');
    }
  }

  String get name {
    return _name;
  }

  void rename(String newName) {
    newName = newName.trim();
    if (newName.isEmpty) {
      throw Exception('Course name must not be empty.');
    }

    _name = newName;
  }
}
