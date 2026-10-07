import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// Local storage: works offline on Android, iOS, Windows and web.
class InspectionStore {
  static const _key = 'inspections_v1';

  Future<List<Inspection>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List)
        .map((e) => Inspection.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> saveAll(List<Inspection> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }
}
