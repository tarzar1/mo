import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class CacheService {
  static final CacheService _instance = CacheService._();
  factory CacheService() => _instance;
  CacheService._();

  static const Duration ttlProfile = Duration(hours: 24);
  static const Duration ttlConversations = Duration(minutes: 5);
  static const Duration ttlNotifications = Duration(minutes: 5);
  static const Duration ttlTrips = Duration(minutes: 5);
  static const Duration ttlMessages = Duration(minutes: 10);

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox('profile'),
      Hive.openBox('conversations'),
      Hive.openBox('notifications'),
      Hive.openBox('trips'),
      Hive.openBox('messages'),
    ]);
    _initialized = true;
  }

  Box _box(String name) => Hive.box(name);

  void put(String boxName, String key, dynamic data) {
    final entry = {
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _box(boxName).put(key, jsonEncode(entry));
  }

  dynamic get(String boxName, String key, {Duration? ttl}) {
    final raw = _box(boxName).get(key);
    if (raw == null) return null;
    try {
      final entry = jsonDecode(raw as String) as Map<String, dynamic>;
      if (ttl != null) {
        final stored = DateTime.parse(entry['timestamp'] as String);
        if (DateTime.now().difference(stored) > ttl) {
          _box(boxName).delete(key);
          return null;
        }
      }
      return entry['data'];
    } catch (_) {
      _box(boxName).delete(key);
      return null;
    }
  }

  List<dynamic> getAll(String boxName, {Duration? ttl}) {
    final box = _box(boxName);
    final result = <dynamic>[];
    for (final key in box.keys) {
      final data = get(boxName, key as String, ttl: ttl);
      if (data != null) result.add(data);
    }
    return result;
  }

  void clear(String boxName) {
    _box(boxName).clear();
  }

  void remove(String boxName, String key) {
    _box(boxName).delete(key);
  }
}
