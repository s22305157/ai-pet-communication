String wireString(Map data, String key) => data[key] as String? ?? '';
int wireInt(Map data, String key) => (data[key] as num?)?.toInt() ?? 0;
Map<String, dynamic> wireMap(Object? value) =>
    Map<String, dynamic>.from(value as Map);
String wireId(Map data) {
  final id = data['id'];
  if (id is! String || id.isEmpty) {
    throw const FormatException('Missing record id');
  }
  return id;
}
