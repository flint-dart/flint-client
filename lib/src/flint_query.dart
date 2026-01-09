class FlintQuery {
  final Map<String, dynamic> _params = {};

  FlintQuery add(String key, dynamic value) {
    if (value == null) return this;
    _params[key] = value;
    return this;
  }

  FlintQuery addAll(Map<String, dynamic>? values) {
    if (values == null) return this;
    values.forEach(add);
    return this;
  }

  Map<String, String> toQueryParameters() {
    return _params.map((key, value) {
      if (value is List) {
        return MapEntry(key, value.join(','));
      }
      return MapEntry(key, value.toString());
    });
  }

  bool get isEmpty => _params.isEmpty;
}
