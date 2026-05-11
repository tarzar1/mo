import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocket, File, Directory;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'theme.dart';
import 'driver_api_service.dart';
import 'services/cache_service.dart';

// ─── API SERVICE SINGLETON ────────────────────────────────────────────

final driverApiProvider = Provider<DriverApiService>((ref) {
  return DriverApiService();
});

// ─── THEME PROVIDERS ──────────────────────────────────────────────────────────

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'theme_mode';

  ThemeModeNotifier() : super(ThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _storage.read(key: _key);
    if (saved != null) {
      state = saved == 'light' ? ThemeMode.light : ThemeMode.dark;
    }
  }

  Future<void> toggle() async {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await _storage.write(key: _key, value: state == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await _storage.write(key: _key, value: mode == ThemeMode.dark ? 'dark' : 'light');
  }

  bool get isDark => state == ThemeMode.dark;
}

final appThemeProvider =
    StateNotifierProvider<AppThemeNotifier, AppThemeVariant>(
  (ref) => AppThemeNotifier(),
);

class AppThemeNotifier extends StateNotifier<AppThemeVariant> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'app_theme';

  AppThemeNotifier() : super(AppThemeVariant.neon) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _storage.read(key: _key);
    if (saved != null) {
      final variant = AppThemeVariant.values.firstWhere(
        (v) => v.toString() == saved,
        orElse: () => AppThemeVariant.neon,
      );
      state = variant;
    }
  }

  Future<void> set(AppThemeVariant v) async {
    state = v;
    await _storage.write(key: _key, value: v.toString());
  }
}

// ─── USER ROLE ──────────────────────────────────────────────────────

enum UserRole { passenger, driver }

// ─── USER PROFILE ─────────────────────────────────────────────────────

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String avatar;
  final String avatarLocalPath;
  final String bio;
  final int tripsCompleted;
  final int tripsOffered;
  final double rating;
  final bool isVerified;
  final String lastName;
  final UserRole role;

  const UserProfile({
    this.id = '',
    required this.name,
    required this.email,
    required this.phone,
    required this.avatar,
    this.avatarLocalPath = '',
    required this.bio,
    required this.tripsCompleted,
    required this.tripsOffered,
    required this.rating,
    required this.isVerified,
    this.lastName = '',
    this.role = UserRole.passenger,
  });

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatar,
    String? avatarLocalPath,
    String? bio,
    int? tripsCompleted,
    int? tripsOffered,
    double? rating,
    bool? isVerified,
    UserRole? role,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      avatarLocalPath: avatarLocalPath ?? this.avatarLocalPath,
      bio: bio ?? this.bio,
      tripsCompleted: tripsCompleted ?? this.tripsCompleted,
      tripsOffered: tripsOffered ?? this.tripsOffered,
      rating: rating ?? this.rating,
      isVerified: isVerified ?? this.isVerified,
      role: role ?? this.role,
    );
  }

  String get roleLabel => role == UserRole.driver ? 'Conductor' : 'Pasajero';
  IconData get roleIcon => role == UserRole.driver ? Icons.drive_eta : Icons.person;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'avatar': avatar,
        'avatarLocalPath': avatarLocalPath,
        'bio': bio,
        'tripsCompleted': tripsCompleted,
        'tripsOffered': tripsOffered,
        'rating': rating,
        'isVerified': isVerified,
        'lastName': lastName,
        'role': role.name,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'] ?? '',
        avatar: json['avatar'] ?? '',
        avatarLocalPath: json['avatarLocalPath'] ?? '',
        bio: json['bio'] ?? '',
        tripsCompleted: json['tripsCompleted'] ?? 0,
        tripsOffered: json['tripsOffered'] ?? 0,
        rating: (json['rating'] ?? 5.0).toDouble(),
        isVerified: json['isVerified'] ?? false,
        lastName: json['lastName'] ?? '',
        role: json['role'] == 'driver' ? UserRole.driver : UserRole.passenger,
      );
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile>(
  (ref) => UserProfileNotifier(ref.read(driverApiProvider)),
);

class UserProfileNotifier extends StateNotifier<UserProfile> {
  final DriverApiService _api;

  UserProfileNotifier(this._api)
      : super(const UserProfile(
          name: '',
          email: '',
          phone: '',
          avatar: '',
          bio: '',
          tripsCompleted: 0,
          tripsOffered: 0,
          rating: 5.0,
          isVerified: false,
        ));

  void _cache() {
    CacheService().put('profile', 'my', state.toJson());
  }

  Future<void> loadProfile() async {
    final cached = CacheService().get('profile', 'my', ttl: CacheService.ttlProfile);
    if (cached != null) {
      state = UserProfile.fromJson(cached as Map<String, dynamic>);
    }
    try {
      final profile = await _api.getUserProfile().timeout(const Duration(seconds: 10));
      state = UserProfile(
        id: profile.id,
        name: '${profile.name} ${profile.lastName}'.trim(),
        email: profile.email,
        phone: profile.phone,
        avatar: profile.avatarUrl.isNotEmpty ? profile.avatarUrl : (profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'U'),
        bio: profile.bio,
        tripsCompleted: profile.tripsCompleted,
        tripsOffered: profile.tripsOffered,
        rating: profile.rating,
        isVerified: profile.isVerified,
        lastName: profile.lastName,
        role: profile.role == 'driver' ? UserRole.driver : UserRole.passenger,
      );
      _cache();
    } catch (e) {
      debugPrint('loadProfile error: $e');
    }
  }

  void update(UserProfile profile) {
    state = profile;
    _cache();
  }

  void updateName(String v) {
    state = state.copyWith(name: v);
    _cache();
  }

  void updateEmail(String v) {
    state = state.copyWith(email: v);
    _cache();
  }

  void updatePhone(String v) {
    state = state.copyWith(phone: v);
    _cache();
  }

  void updateBio(String v) {
    state = state.copyWith(bio: v);
    _cache();
  }

  void verify() {
    state = state.copyWith(isVerified: true);
    _cache();
  }

  Future<String?> updateAvatar(String filePath) async {
    try {
      final url = await _api.uploadAvatar(filePath);
      if (url.isNotEmpty) {
        state = state.copyWith(avatar: url, avatarLocalPath: '');
        _cache();
        return url;
      }
    } catch (_) {}
    try {
      final dir = Directory('${Directory.systemTemp.path}/avatars');
      if (!await dir.exists()) await dir.create(recursive: true);
      final ext = filePath.split('.').last;
      final localPath = '${dir.path}/${state.id}_avatar.$ext';
      await File(filePath).copy(localPath);
      state = state.copyWith(avatarLocalPath: localPath, avatar: '');
      _cache();
      return localPath;
    } catch (e) {
      debugPrint('updateAvatar local error: $e');
      return null;
    }
  }

  Future<void> removeAvatar() async {
    try {
      await _api.deleteAvatar();
    } catch (_) {}
    try {
      if (state.avatarLocalPath.isNotEmpty) {
        final f = File(state.avatarLocalPath);
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
    state = state.copyWith(avatar: '', avatarLocalPath: '');
    _cache();
  }
}

// ─── APP SETTINGS ─────────────────────────────────────────────────────

class AppSettings {
  final bool notifications;
  final bool emailAlerts;
  final bool locationAlways;
  final bool soundEffects;
  final String language;

  const AppSettings({
    this.notifications = true,
    this.emailAlerts = false,
    this.locationAlways = true,
    this.soundEffects = true,
    this.language = 'Español',
  });

  AppSettings copyWith({
    bool? notifications,
    bool? emailAlerts,
    bool? locationAlways,
    bool? soundEffects,
    String? language,
  }) {
    return AppSettings(
      notifications: notifications ?? this.notifications,
      emailAlerts: emailAlerts ?? this.emailAlerts,
      locationAlways: locationAlways ?? this.locationAlways,
      soundEffects: soundEffects ?? this.soundEffects,
      language: language ?? this.language,
    );
  }

  Map<String, dynamic> toJson() => {
        'notifications': notifications,
        'emailAlerts': emailAlerts,
        'locationAlways': locationAlways,
        'soundEffects': soundEffects,
        'language': language,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        notifications: json['notifications'] ?? true,
        emailAlerts: json['emailAlerts'] ?? false,
        locationAlways: json['locationAlways'] ?? true,
        soundEffects: json['soundEffects'] ?? true,
        language: json['language'] ?? 'Español',
      );
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);

class SettingsNotifier extends StateNotifier<AppSettings> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'app_settings';

  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _storage.read(key: _key);
    if (saved != null) {
      try {
        final Map<String, dynamic> json = {};
        saved.split(',').forEach((pair) {
          final parts = pair.split(':');
          if (parts.length == 2) {
            json[parts[0]] = parts[1] == 'true';
          }
        });
        state = AppSettings.fromJson(json);
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final json = state.toJson();
    final str = json.entries.map((e) => '${e.key}:${e.value}').join(',');
    await _storage.write(key: _key, value: str);
  }

  Future<void> toggle(String key) async {
    switch (key) {
      case 'notifications':
        state = state.copyWith(notifications: !state.notifications);
        break;
      case 'emailAlerts':
        state = state.copyWith(emailAlerts: !state.emailAlerts);
        break;
      case 'locationAlways':
        state = state.copyWith(locationAlways: !state.locationAlways);
        break;
      case 'soundEffects':
        state = state.copyWith(soundEffects: !state.soundEffects);
        break;
    }
    await _save();
  }

  Future<void> setLanguage(String v) async {
    state = state.copyWith(language: v);
    await _save();
  }
}

// ─── PAYMENT METHODS ───────────────────────────────────────────────────

enum PaymentType { card, paypal, cash, applePay }

class PaymentMethod {
  final String id;
  final PaymentType type;
  final String label;
  final String detail;
  final bool isDefault;

  const PaymentMethod({
    required this.id,
    required this.type,
    required this.label,
    required this.detail,
    this.isDefault = false,
  });

  PaymentMethod copyWith({bool? isDefault}) => PaymentMethod(
        id: id,
        type: type,
        label: label,
        detail: detail,
        isDefault: isDefault ?? this.isDefault,
      );
}

final paymentMethodsProvider =
    StateNotifierProvider<PaymentMethodsNotifier, List<PaymentMethod>>(
  (ref) => PaymentMethodsNotifier(ref.read(driverApiProvider)),
);

class PaymentMethodsNotifier extends StateNotifier<List<PaymentMethod>> {
  final DriverApiService _api;

  PaymentMethodsNotifier(this._api) : super([]);

  Future<void> loadPaymentMethods(String userId) async {
    try {
      final items = await _api.getPaymentMethods(userId);
      state = items.map((m) {
        PaymentType type;
        switch (m.type) {
          case 'paypal':
            type = PaymentType.paypal;
            break;
          case 'cash':
            type = PaymentType.cash;
            break;
          case 'applePay':
            type = PaymentType.applePay;
            break;
          default:
            type = PaymentType.card;
        }
        return PaymentMethod(
          id: m.id,
          type: type,
          label: m.label,
          detail: m.detail,
          isDefault: m.isDefault,
        );
      }).toList();
    } catch (e) {
      debugPrint('loadPaymentMethods error: $e');
    }
  }

  void setDefault(String id) {
    state = [
      for (final m in state) m.copyWith(isDefault: m.id == id),
    ];
  }

  void remove(String id) {
    state = state.where((m) => m.id != id).toList();
  }

  void add(PaymentMethod method) {
    state = [...state, method];
  }
}

// ─── NOTIFICATIONS ────────────────────────────────────────────────────

enum NotificationType { message, rideRequest, payment, system }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime time;
  final bool isRead;
  final IconData icon;
  final Color color;
  final NotificationType type;
  final String? targetId;
  final bool isLocal;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    required this.color,
    this.isRead = false,
    this.type = NotificationType.system,
    this.targetId,
    this.isLocal = false,
  });

  AppNotification copyWith({bool? isRead, bool? isLocal}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      time: time,
      icon: icon,
      color: color,
      type: type,
      targetId: targetId,
      isRead: isRead ?? this.isRead,
      isLocal: isLocal ?? this.isLocal,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'time': time.toIso8601String(),
        'isRead': isRead,
        'iconCodePoint': icon.codePoint,
        'colorValue': color.toARGB32(),
        'type': type.name,
        'targetId': targetId,
        'isLocal': isLocal,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        time: DateTime.parse(json['time']),
        icon: IconData(json['iconCodePoint'] ?? Icons.notifications_outlined.codePoint, fontFamily: 'MaterialIcons'),
        color: Color(json['colorValue'] ?? 0xFF0066FF),
        isRead: json['isRead'] ?? false,
        type: NotificationType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => NotificationType.system,
        ),
        targetId: json['targetId'],
        isLocal: json['isLocal'] ?? false,
      );
}

class NotificationsNotifier extends StateNotifier<List<AppNotification>> {
  final DriverApiService _api;

  WebSocket? _ws;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final Set<String> _deletedIds = {};

  NotificationsNotifier(this._api) : super([]);

  void _cache() {
    CacheService().put('notifications', 'all', state.map((n) => n.toJson()).toList());
  }

  Future<void> loadNotifications(String userId) async {
    final cached = CacheService().get('notifications', 'all', ttl: CacheService.ttlNotifications);
    if (cached != null) {
      state = (cached as List<dynamic>).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
    }
    try {
      final items = await _api.getNotifications(userId).timeout(const Duration(seconds: 10));
      final serverNotifs = items.map((n) {
        IconData icon;
        switch (n.icon) {
          case 'chat':
            icon = Icons.chat_bubble_outline;
            break;
          case 'reservation':
            icon = Icons.event_seat_outlined;
            break;
          case 'check':
            icon = Icons.check_circle_outline;
            break;
          default:
            icon = Icons.notifications_outlined;
        }
        Color color;
        try {
          color = Color(int.parse(n.color.replaceFirst('#', '0xFF')));
        } catch (_) {
          color = const Color(0xFF0066FF);
        }
        NotificationType nType;
        switch (n.type) {
          case 'message':
            nType = NotificationType.message;
            break;
          case 'ride_request':
            nType = NotificationType.rideRequest;
            break;
          case 'payment':
            nType = NotificationType.payment;
            break;
          default:
            nType = NotificationType.system;
        }
        return AppNotification(
          id: n.id,
          title: n.title,
          body: n.body,
          time: DateTime.tryParse(n.createdAt) ?? DateTime.now(),
          icon: icon,
          color: color,
          isRead: n.isRead,
          type: nType,
          targetId: n.targetId,
          isLocal: false,
        );
      }).toList();

      // Merge: keep local notifs + server notifs not in deleted set
      final localNotifs = state.where((n) => n.isLocal).toList();
      try {
        state = [
          ...serverNotifs.where((n) => !_deletedIds.contains(n.id)),
          ...localNotifs,
        ];
        _cache();
      } catch (_) {
        // Provider disposed, ignore
      }
    } catch (e) {
      debugPrint('loadNotifications error: $e');
    }
  }

  void connectNotificationWs(String token) {
    _disconnectWs();
    _reconnectTimer?.cancel();

    final wsUrl = _api.notificationWsUrl.replaceFirst('http', 'ws');
    WebSocket.connect('$wsUrl?token=$token')
        .then((ws) {
      _ws = ws;
      _reconnectAttempts = 0;

      _wsSub = ws.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final type = json['type'] as String?;

            if (type == 'new_notification') {
              final notif = json['notification'] as Map<String, dynamic>?;
              if (notif != null) {
                IconData icon;
                switch (notif['icon'] as String? ?? 'notifications') {
                  case 'chat':
                    icon = Icons.chat_bubble_outline;
                    break;
                  case 'reservation':
                    icon = Icons.event_seat_outlined;
                    break;
                  case 'check':
                    icon = Icons.check_circle_outline;
                    break;
                  default:
                    icon = Icons.notifications_outlined;
                }
                Color color;
                try {
                  color = Color(int.parse((notif['color'] as String? ?? '#0066FF').replaceFirst('#', '0xFF')));
                } catch (_) {
                  color = const Color(0xFF0066FF);
                }
                NotificationType nType;
                switch (notif['type'] as String? ?? '') {
                  case 'message':
                    nType = NotificationType.message;
                    break;
                  case 'ride_request':
                    nType = NotificationType.rideRequest;
                    break;
                  case 'payment':
                    nType = NotificationType.payment;
                    break;
                  default:
                    nType = NotificationType.system;
                }
                addNotification(AppNotification(
                  id: notif['id'] as String? ?? '',
                  title: notif['title'] as String? ?? '',
                  body: notif['body'] as String? ?? '',
                  time: DateTime.tryParse(notif['created_at'] as String? ?? '') ?? DateTime.now(),
                  icon: icon,
                  color: color,
                  isRead: notif['is_read'] as bool? ?? false,
                  type: nType,
                  targetId: notif['target_id'] as String?,
                ));
              }
            } else if (type == 'notification_deleted') {
              final id = json['notification_id'] as String?;
              if (id != null) {
                state = state.where((n) => n.id != id).toList();
              }
            } else if (type == 'notifications_read') {
              final ids = (json['notification_ids'] as List<dynamic>?)?.cast<String>();
              if (ids != null) {
                state = [
                  for (final n in state)
                    if (ids.contains(n.id)) n.copyWith(isRead: true) else n,
                ];
              }
            }
          } catch (e) {
            debugPrint('Notification WS parse error: $e');
          }
        },
        onError: (e) {
          debugPrint('Notification WS error: $e');
          _scheduleWsReconnect(token);
        },
        onDone: () {
          debugPrint('Notification WS closed');
          _scheduleWsReconnect(token);
        },
      );
    }).catchError((e) {
      debugPrint('Notification WS connect error: $e');
      _scheduleWsReconnect(token);
    });
  }

  void _scheduleWsReconnect(String token) {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delay = (1 << (_reconnectAttempts - 1)).clamp(1, 30);
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      connectNotificationWs(token);
    });
  }

  void _disconnectWs() {
    _wsSub?.cancel();
    _wsSub = null;
    _ws?.close();
    _ws = null;
  }

  void disconnectNotificationWs() {
    _reconnectTimer?.cancel();
    _disconnectWs();
  }

  Future<void> clearAll() async {
    final ids = state.map((n) => n.id).toList();
    for (final id in ids) {
      if (!state.any((n) => n.id == id && n.isLocal)) {
        try {
          await _api.deleteNotification(id).timeout(const Duration(seconds: 10));
        } catch (_) {}
      }
      _deletedIds.add(id);
    }
    state = [];
    _cache();
  }

  Future<void> removeNotification(String id) async {
    _deletedIds.add(id);
    state = state.where((n) => n.id != id).toList();
    _cache();
    try {
      await _api.deleteNotification(id).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  void addLocalNotification({
    required String title,
    required String body,
    required NotificationType type,
    String? targetId,
  }) {
    final notif = AppNotification(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      time: DateTime.now(),
      icon: type == NotificationType.message
          ? Icons.chat_bubble_outline
          : type == NotificationType.rideRequest
              ? Icons.event_seat_outlined
              : Icons.notifications_outlined,
      color: type == NotificationType.message
          ? const Color(0xFF0066FF)
          : type == NotificationType.rideRequest
              ? const Color(0xFFFF6B35)
              : const Color(0xFF4CAF50),
      type: type,
      targetId: targetId,
      isLocal: true,
    );
    state = [notif, ...state];
  }

  void markRead(String id) {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];
    _cache();
  }

  void markAllRead() {
    state = [for (final n in state) n.copyWith(isRead: true)];
    _cache();
  }

  void addNotification(AppNotification notification) {
    state = [notification, ...state];
    _cache();
  }

  int get unreadCount => state.where((n) => !n.isRead).length;
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<AppNotification>>(
  (ref) => NotificationsNotifier(ref.read(driverApiProvider)),
);

// ─── TRIPS ────────────────────────────────────────────────────────────

enum TripStatus { available, full, inProgress, completed }

class Trip {
  final String id;
  final String driverId;
  final String driverName;
  final String driverAvatar;
  final double driverRating;
  final String origin;
  final String destination;
  final String departureTime;
  final String arrivalTime;
  final int seats;
  final int seatsAvailable;
  final double price;
  final TripStatus status;
  final List<String> amenities;
  final bool isJoined;

  const Trip({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.driverAvatar,
    required this.driverRating,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.arrivalTime,
    required this.seats,
    required this.seatsAvailable,
    required this.price,
    required this.status,
    required this.amenities,
    this.isJoined = false,
  });

  Trip copyWith({
    bool? isJoined,
    int? seatsAvailable,
    TripStatus? status,
  }) {
    return Trip(
      id: id,
      driverId: driverId,
      driverName: driverName,
      driverAvatar: driverAvatar,
      driverRating: driverRating,
      origin: origin,
      destination: destination,
      departureTime: departureTime,
      arrivalTime: arrivalTime,
      seats: seats,
      seatsAvailable: seatsAvailable ?? this.seatsAvailable,
      price: price,
      status: status ?? this.status,
      amenities: amenities,
      isJoined: isJoined ?? this.isJoined,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'driverId': driverId,
        'driverName': driverName,
        'driverAvatar': driverAvatar,
        'driverRating': driverRating,
        'origin': origin,
        'destination': destination,
        'departureTime': departureTime,
        'arrivalTime': arrivalTime,
        'seats': seats,
        'seatsAvailable': seatsAvailable,
        'price': price,
        'status': status.name,
        'amenities': amenities,
        'isJoined': isJoined,
      };

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: json['id'] ?? '',
        driverId: json['driverId'] ?? '',
        driverName: json['driverName'] ?? '',
        driverAvatar: json['driverAvatar'] ?? '',
        driverRating: (json['driverRating'] ?? 5.0).toDouble(),
        origin: json['origin'] ?? '',
        destination: json['destination'] ?? '',
        departureTime: json['departureTime'] ?? '',
        arrivalTime: json['arrivalTime'] ?? '',
        seats: json['seats'] ?? 0,
        seatsAvailable: json['seatsAvailable'] ?? 0,
        price: (json['price'] ?? 0.0).toDouble(),
        status: TripStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => TripStatus.available,
        ),
        amenities: List<String>.from(json['amenities'] ?? []),
        isJoined: json['isJoined'] ?? false,
      );
}

final tripsProvider = StateNotifierProvider<TripsNotifier, List<Trip>>(
  (ref) => TripsNotifier(ref.read(driverApiProvider)),
);

Trip _offerToTrip(Offer offer) {
  return Trip(
    id: offer.id,
    driverId: offer.driverId,
    driverName: '${offer.driverName} ${offer.driverLastName}'.trim(),
    driverAvatar: offer.avatar.isNotEmpty ? offer.avatar : (offer.driverName.isNotEmpty ? offer.driverName[0].toUpperCase() : '?'),
    driverRating: offer.rating,
    origin: offer.recogida,
    destination: offer.destino,
    departureTime: offer.hour,
    arrivalTime: offer.time,
    seats: offer.trips > 0 ? offer.trips : 4,
    seatsAvailable: offer.trips > 0 ? offer.trips : 4,
    price: offer.price,
    status: offer.active ? TripStatus.available : TripStatus.completed,
    amenities: [],
  );
}

class TripsNotifier extends StateNotifier<List<Trip>> {
  final DriverApiService _api;

  TripsNotifier(this._api) : super([]);

  void _cache() {
    CacheService().put('trips', 'all', state.map((t) => t.toJson()).toList());
  }

  Future<void> loadTrips() async {
    final cached = CacheService().get('trips', 'all', ttl: CacheService.ttlTrips);
    if (cached != null) {
      state = (cached as List<dynamic>).map((e) => Trip.fromJson(e as Map<String, dynamic>)).toList();
    }
    try {
      final offers = await _api.getActiveOffers().timeout(const Duration(seconds: 10));
      state = offers.map(_offerToTrip).toList();
      _cache();
    } catch (e) {
      debugPrint('loadTrips error: $e');
    }
  }

  void joinTrip(String id) {
    state = [
      for (final t in state)
        if (t.id == id && t.seatsAvailable > 0)
          t.copyWith(isJoined: true, seatsAvailable: t.seatsAvailable - 1)
        else
          t
    ];
    _cache();
  }

  void leaveTrip(String id) {
    state = [
      for (final t in state)
        if (t.id == id)
          t.copyWith(isJoined: false, seatsAvailable: t.seatsAvailable + 1)
        else
          t
    ];
    _cache();
  }
}

// ─── RIDE REQUESTS ──────────────────────────────────────────────────

final rideRequestsProvider = StateNotifierProvider<RideRequestsNotifier, List<RideRequest>>(
  (ref) => RideRequestsNotifier(ref.read(driverApiProvider), ref),
);

class RideRequestsNotifier extends StateNotifier<List<RideRequest>> {
  final DriverApiService _api;
  final Ref _ref;

  RideRequestsNotifier(this._api, this._ref) : super([]);

  Future<void> loadIncoming() async {
    try {
      debugPrint('RideRequestsNotifier: Loading incoming requests...');
      final items = await _api.getIncomingRequests();
      debugPrint('RideRequestsNotifier: Loaded ${items.length} incoming requests');
      state = items;
    } catch (e) {
      debugPrint('loadIncomingRequests error: $e');
    }
  }

  Future<void> loadMy() async {
    try {
      debugPrint('RideRequestsNotifier: Loading my requests...');
      final items = await _api.getMyRequests();
      debugPrint('RideRequestsNotifier: Loaded ${items.length} requests');
      state = items;
    } catch (e) {
      debugPrint('loadMyRequests error: $e');
    }
  }

  Future<void> loadByRole(UserRole role) async {
    if (role == UserRole.driver) {
      await loadIncoming();
    } else {
      await loadMy();
    }
  }

  Future<void> createRequest(String offerId) async {
    try {
      debugPrint('RideRequestsNotifier: Creating request for offer $offerId');
      
      // Verificar si ya tiene una solicitud activa
      final currentRequests = state;
      final hasActiveRequest = currentRequests.any((r) => r.status == 'pending' || r.status == 'accepted');
      if (hasActiveRequest) {
        throw ApiException(400, 'Solo puedes tener una solicitud activa a la vez. Cancela la actual primero.');
      }
      
      final request = await _api.createRideRequest(offerId);
      debugPrint('RideRequestsNotifier: Request created with id ${request.id}, status: ${request.status}');
      await loadMy();
      debugPrint('RideRequestsNotifier: My requests reloaded after create');
    } catch (e) {
      debugPrint('createRequest error: $e');
      rethrow;
    }
  }

  Future<void> acceptRequest(String requestId) async {
    try {
      debugPrint('RideRequestsNotifier: Accepting request $requestId');
      await _api.acceptRequest(requestId);
      debugPrint('RideRequestsNotifier: Request accepted, reloading incoming requests');
      await loadIncoming();
      await _ref.read(tripsProvider.notifier).loadTrips();
      await _ref.read(conversationsProvider.notifier).loadConversations(_ref.read(userProfileProvider).id);
      debugPrint('RideRequestsNotifier: All data reloaded after accept');
    } catch (e) {
      debugPrint('acceptRequest error: $e');
      rethrow;
    }
  }

  Future<void> rejectRequest(String requestId) async {
    try {
      debugPrint('RideRequestsNotifier: Rejecting request $requestId');
      await _api.rejectRequest(requestId);
      debugPrint('RideRequestsNotifier: Request rejected, reloading incoming requests');
      await loadIncoming();
      await _ref.read(tripsProvider.notifier).loadTrips();
      await _ref.read(conversationsProvider.notifier).loadConversations(_ref.read(userProfileProvider).id);
      debugPrint('RideRequestsNotifier: All data reloaded after reject');
    } catch (e) {
      debugPrint('rejectRequest error: $e');
      rethrow;
    }
  }

  Future<void> cancelRequest(String requestId) async {
    try {
      debugPrint('RideRequestsNotifier: Cancelling request $requestId');
      await _api.cancelRequest(requestId);
      debugPrint('RideRequestsNotifier: Request cancelled, reloading data');
      final user = _ref.read(userProfileProvider);
      if (user.role == UserRole.driver) {
        await loadIncoming();
      } else {
        await loadMy();
      }
      await _ref.read(tripsProvider.notifier).loadTrips();
      await _ref.read(conversationsProvider.notifier).loadConversations(_ref.read(userProfileProvider).id);
      debugPrint('RideRequestsNotifier: All data reloaded after cancel');
    } catch (e) {
      debugPrint('cancelRequest error: $e');
      rethrow;
    }
  }

  /// Envía solicitudes a múltiples ofertas en paralelo.
  /// No tiene el guard de "solo una solicitud activa".
  Future<List<String>> batchCreateRequests(List<String> offerIds) async {
    debugPrint('RideRequestsNotifier: Sending ${offerIds.length} requests in parallel');
    try {
      final results = await Future.wait(
        offerIds.map((id) => _api.createRideRequest(id)),
      );
      debugPrint('RideRequestsNotifier: All requests sent, reloading');
      await loadMy();
      return results.map((r) => r.id).toList();
    } catch (e) {
      debugPrint('batchCreateRequests error: $e');
      rethrow;
    }
  }

  /// Elimina solicitudes del estado local SIN llamar al API de cancelar.
  void dropRequests(List<String> ids) {
    state = state.where((r) => !ids.contains(r.id)).toList();
  }

  void dropRequest(String id) {
    state = state.where((r) => r.id != id).toList();
  }

  List<RideRequest> get active => state.where((r) => r.status == 'pending' || r.status == 'accepted').toList();
  List<RideRequest> get history => state.where((r) => r.status == 'rejected' || r.status == 'cancelled').toList();

  int get pendingCount => state.where((r) => r.status == 'pending').length;
}

// ─── CHAT ────────────────────────────────────────────────────────────


class MessageReaction {
  final String userId;
  final String emoji;
  final DateTime timestamp;

  const MessageReaction({
    required this.userId,
    required this.emoji,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'emoji': emoji,
        'timestamp': timestamp.toIso8601String(),
      };

  factory MessageReaction.fromJson(Map<String, dynamic> json) => MessageReaction(
        userId: json['userId'] ?? '',
        emoji: json['emoji'] ?? '',
        timestamp: DateTime.parse(json['timestamp']),
      );
}

class ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final DateTime time;
  final MessageStatus status;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String? editedAt;
  final String? replyToId;
  final String? replyText;
  final bool? replyIsMe;
  final List<MessageReaction> reactions;
  final bool isDeleted;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.time,
    this.status = MessageStatus.sent,
    this.deliveredAt,
    this.readAt,
    this.editedAt,
    this.replyToId,
    this.replyText,
    this.replyIsMe,
    this.reactions = const [],
    this.isDeleted = false,
  });

  ChatMessage copyWith({
    MessageStatus? status,
    DateTime? deliveredAt,
    DateTime? readAt,
    List<MessageReaction>? reactions,
    bool? isDeleted,
  }) {
    return ChatMessage(
      id: id,
      text: text,
      isMe: isMe,
      time: time,
      status: status ?? this.status,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      editedAt: editedAt,
      replyToId: replyToId,
      replyText: replyText,
      replyIsMe: replyIsMe,
      reactions: reactions ?? this.reactions,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  bool get isSent => status.index >= MessageStatus.sent.index;
  bool get isDelivered => status.index >= MessageStatus.delivered.index;
  bool get isRead => status == MessageStatus.read;
  bool get isSending => status == MessageStatus.sending;
  bool get isFailed => status == MessageStatus.failed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isMe': isMe,
        'time': time.toIso8601String(),
        'status': status.name,
        'deliveredAt': deliveredAt?.toIso8601String(),
        'readAt': readAt?.toIso8601String(),
        'editedAt': editedAt,
        'replyToId': replyToId,
        'replyText': replyText,
        'replyIsMe': replyIsMe,
        'reactions': reactions.map((r) => r.toJson()).toList(),
        'isDeleted': isDeleted,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] ?? '',
        text: json['text'] ?? '',
        isMe: json['isMe'] ?? false,
        time: DateTime.parse(json['time']),
        status: MessageStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => MessageStatus.sent,
        ),
        deliveredAt: json['deliveredAt'] != null ? DateTime.parse(json['deliveredAt']) : null,
        readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
        editedAt: json['editedAt'],
        replyToId: json['replyToId'],
        replyText: json['replyText'],
        replyIsMe: json['replyIsMe'],
        reactions: (json['reactions'] as List<dynamic>?)
                ?.map((r) => MessageReaction.fromJson(r as Map<String, dynamic>))
                .toList() ??
            [],
        isDeleted: json['isDeleted'] ?? false,
      );
}

class Conversation {
  final String id;
  final String name;
  final String avatar;
  final String lastMessage;
  final DateTime lastTime;
  final int unread;
  final bool isOnline;
  final List<ChatMessage> messages;
  final bool isPinned;
  final bool isArchived;
  final bool isMuted;
  final int disappearingMsgSeconds;

  const Conversation({
    required this.id,
    required this.name,
    required this.avatar,
    required this.lastMessage,
    required this.lastTime,
    required this.unread,
    required this.isOnline,
    required this.messages,
    this.isPinned = false,
    this.isArchived = false,
    this.isMuted = false,
    this.disappearingMsgSeconds = 0,
  });

  Conversation copyWith({
    List<ChatMessage>? messages,
    String? lastMessage,
    DateTime? lastTime,
    int? unread,
    bool? isPinned,
    bool? isArchived,
    bool? isMuted,
    int? disappearingMsgSeconds,
    bool? isOnline,
  }) {
    return Conversation(
      id: id,
      name: name,
      avatar: avatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastTime: lastTime ?? this.lastTime,
      unread: unread ?? this.unread,
      isOnline: isOnline ?? this.isOnline,
      messages: messages ?? this.messages,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
      disappearingMsgSeconds: disappearingMsgSeconds ?? this.disappearingMsgSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'lastMessage': lastMessage,
        'lastTime': lastTime.toIso8601String(),
        'unread': unread,
        'isOnline': isOnline,
        'isPinned': isPinned,
        'isArchived': isArchived,
        'isMuted': isMuted,
        'disappearingMsgSeconds': disappearingMsgSeconds,
      };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        avatar: json['avatar'] ?? '',
        lastMessage: json['lastMessage'] ?? '',
        lastTime: DateTime.parse(json['lastTime']),
        unread: json['unread'] ?? 0,
        isOnline: json['isOnline'] ?? false,
        messages: [],
        isPinned: json['isPinned'] ?? false,
        isArchived: json['isArchived'] ?? false,
        isMuted: json['isMuted'] ?? false,
        disappearingMsgSeconds: json['disappearingMsgSeconds'] ?? 0,
      );
}

final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, List<Conversation>>(
  (ref) => ConversationsNotifier(ref.read(driverApiProvider)),
);

class ConversationsNotifier extends StateNotifier<List<Conversation>> {
  final DriverApiService _api;

  ConversationsNotifier(this._api) : super([]);

  void _cacheConversations() {
    CacheService().put('conversations', 'all', state.map((c) => c.toJson()).toList());
  }

  void _cacheMessages(String convId) {
    final conv = state.where((c) => c.id == convId).firstOrNull;
    if (conv != null) {
      CacheService().put('messages', convId, conv.messages.map((m) => m.toJson()).toList());
    }
  }

  Future<void> loadConversations(String userId) async {
    final cached = CacheService().get('conversations', 'all', ttl: CacheService.ttlConversations);
    if (cached != null) {
      state = (cached as List<dynamic>).map((e) => Conversation.fromJson(e as Map<String, dynamic>)).toList();
      // Restore messages per conversation from cache
      for (var i = 0; i < state.length; i++) {
        final msgs = CacheService().get('messages', state[i].id, ttl: CacheService.ttlMessages);
        if (msgs != null) {
          final messageList = (msgs as List<dynamic>).map((m) => ChatMessage.fromJson(m as Map<String, dynamic>)).toList();
          state[i] = state[i].copyWith(messages: messageList);
        }
      }
    }
    try {
      final items = await _api.getConversations(userId).timeout(const Duration(seconds: 10));
      final otherIds = items.map((c) => c.user1Id == userId ? c.user2Id : c.user1Id).toList();
      Map<String, Map<String, String>> userMap = {};
      if (otherIds.isNotEmpty) {
        try {
          userMap = await _api.getUsersBatch(otherIds);
        } catch (_) {}
      }
      state = items.map((c) {
        final otherId = c.user1Id == userId ? c.user2Id : c.user1Id;
        final userData = userMap[otherId];
        final displayName = userData != null
            ? '${userData['name']} ${userData['last_name']}'.trim()
            : otherId;
        final avatar = userData != null
            ? (userData['avatar'] ?? (otherId.isNotEmpty ? otherId[0].toUpperCase() : '?'))
            : (otherId.isNotEmpty ? otherId[0].toUpperCase() : '?');
        return Conversation(
          id: c.id,
          name: displayName.isNotEmpty ? displayName : otherId,
          avatar: avatar.isNotEmpty ? avatar[0].toUpperCase() : '?',
          lastMessage: c.lastMessage,
          lastTime: DateTime.tryParse(c.lastTime ?? '') ?? DateTime.now(),
          unread: 0,
          isOnline: false,
          messages: [],
        );
      }).toList();
      _cacheConversations();
    } catch (e) {
      debugPrint('loadConversations error: $e');
    }
  }

  Future<void> sendMessage(String convId, String text, String senderId) async {
    try {
      await _api.sendMessage(convId, senderId, text);
    } catch (e) {
      debugPrint('sendMessage error: $e');
    }
    state = [
      for (final c in state)
        if (c.id == convId)
          c.copyWith(
            messages: [
              ChatMessage(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                text: text,
                isMe: true,
                time: DateTime.now(),
                status: MessageStatus.sent,
              ),
              ...c.messages,
            ],
            lastMessage: text,
            unread: 0,
          )
        else
          c,
    ];
    _cacheConversations();
    _cacheMessages(convId);
  }

  Future<void> deleteMessage(String convId, String messageId) async {
    try {
      await _api.deleteMessage(convId, messageId);
      state = [
        for (final c in state)
          if (c.id == convId)
            c.copyWith(
              messages: c.messages.where((m) => m.id != messageId).toList(),
            )
          else
            c,
      ];
      _cacheConversations();
      _cacheMessages(convId);
    } catch (e) {
      debugPrint('deleteMessage error: $e');
    }
  }

  void markMessagesRead(String convId, List<String> messageIds) {
    final now = DateTime.now();
    state = [
      for (final c in state)
        if (c.id == convId)
          c.copyWith(
            messages: c.messages.map((m) =>
              messageIds.contains(m.id) ? m.copyWith(
                status: MessageStatus.read,
                readAt: now,
              ) : m
            ).toList(),
          )
        else
          c,
    ];
    _cacheMessages(convId);
  }

  void removeMessage(String convId, String messageId) {
    state = [
      for (final c in state)
        if (c.id == convId)
          c.copyWith(
            messages: c.messages.where((m) => m.id != messageId).toList(),
          )
        else
          c,
    ];
    _cacheConversations();
    _cacheMessages(convId);
  }

  void addRealtimeMessage({
    required String convId,
    required ChatMessage message,
  }) {
    state = [
      for (final c in state)
        if (c.id == convId)
          c.copyWith(
            messages: [message, ...c.messages],
            lastMessage: message.text,
          )
        else
          c,
    ];
    _cacheConversations();
    _cacheMessages(convId);
  }

  Future<void> loadMessages(String convId, String userId) async {
    final convIndex = state.indexWhere((c) => c.id == convId);
    if (convIndex >= 0) {
      final cached = CacheService().get('messages', convId, ttl: CacheService.ttlMessages);
      if (cached != null) {
        final messages = (cached as List<dynamic>).map((m) => ChatMessage.fromJson(m as Map<String, dynamic>)).toList();
        state[convIndex] = state[convIndex].copyWith(messages: messages);
        state = [...state];
      }
    }
    try {
      final items = await _api.getMessages(convId).timeout(const Duration(seconds: 10));
      state = [
        for (final c in state)
          if (c.id == convId)
            c.copyWith(
              messages: items.map((m) => ChatMessage(
                id: m.id,
                text: m.text,
                isMe: m.senderId == userId,
                time: DateTime.tryParse(m.createdAt) ?? DateTime.now(),
                status: m.isRead ? MessageStatus.read : MessageStatus.delivered,
              )).toList().reversed.toList(),
              lastMessage: items.isNotEmpty ? items.last.text : c.lastMessage,
            )
          else
            c,
      ];
      _cacheMessages(convId);
    } catch (e) {
      debugPrint('loadMessages error: $e');

      // Fallback a enhanced messages
      try {
        final enhanced = await _api.getEnhancedMessages(convId);
        state = [
          for (final c in state)
            if (c.id == convId)
              c.copyWith(
                messages: enhanced.map((e) => ChatMessage(
                  id: e.id,
                  text: e.text,
                  isMe: e.senderId == userId,
                  time: DateTime.tryParse(e.createdAt) ?? DateTime.now(),
                  status: e.messageStatus,
                  deliveredAt: e.deliveredAt != null ? DateTime.tryParse(e.deliveredAt!) : null,
                  readAt: e.readAt != null ? DateTime.tryParse(e.readAt!) : null,
                  editedAt: e.editedAt,
                )).toList(),
                lastMessage: enhanced.isNotEmpty ? enhanced.last.text : c.lastMessage,
              )
            else
              c,
        ];
        _cacheMessages(convId);
      } catch (_) {}
    }
  }

  void markAsRead(String id) {
    state = [
      for (final c in state)
        if (c.id == id) c.copyWith(unread: 0) else c,
    ];
    _cacheConversations();
  }

  void updateMessageStatus(String convId, List<String> messageIds, MessageStatus status) {
    final now = DateTime.now();
    state = [
      for (final c in state)
        if (c.id == convId)
          c.copyWith(
            messages: c.messages.map((m) =>
              messageIds.contains(m.id)
                ? m.copyWith(
                    status: status,
                    deliveredAt: status == MessageStatus.delivered ? (m.deliveredAt ?? now) : m.deliveredAt,
                    readAt: status == MessageStatus.read ? now : m.readAt,
                  )
                : m
            ).toList(),
          )
        else
          c,
    ];
    _cacheMessages(convId);
  }

  void addReaction(String convId, String messageId, String userId, String emoji) {
    state = [
      for (final c in state)
        if (c.id == convId)
          c.copyWith(
            messages: c.messages.map((m) =>
              m.id == messageId
                ? m.copyWith(
                    reactions: [
                      ...m.reactions.where((r) => r.userId != userId),
                      MessageReaction(userId: userId, emoji: emoji, timestamp: DateTime.now()),
                    ],
                  )
                : m
            ).toList(),
          )
        else
          c,
    ];
    _cacheMessages(convId);
  }

  void removeReaction(String convId, String messageId, String userId) {
    state = [
      for (final c in state)
        if (c.id == convId)
          c.copyWith(
            messages: c.messages.map((m) =>
              m.id == messageId
                ? m.copyWith(
                    reactions: m.reactions.where((r) => r.userId != userId).toList(),
                  )
                : m
            ).toList(),
          )
        else
          c,
    ];
    _cacheMessages(convId);
  }

  Future<void> deleteConversation(String id) async {
    try {
      await _api.deleteConversation(id);
    } catch (e) {
      debugPrint('deleteConversation error: $e');
    }
    state = state.where((c) => c.id != id).toList();
    CacheService().remove('messages', id);
    _cacheConversations();
  }

  void togglePin(String id) {
    state = [
      for (final c in state)
        if (c.id == id) c.copyWith(isPinned: !c.isPinned) else c,
    ];
    _cacheConversations();
  }

  void toggleArchive(String id) {
    state = [
      for (final c in state)
        if (c.id == id) c.copyWith(isArchived: !c.isArchived) else c,
    ];
    _cacheConversations();
  }

  void toggleMute(String id) {
    state = [
      for (final c in state)
        if (c.id == id) c.copyWith(isMuted: !c.isMuted) else c,
    ];
    _cacheConversations();
  }

  void updateConversationMeta(String id, {String? lastMessage, DateTime? lastTime, int? unread}) {
    state = [
      for (final c in state)
        if (c.id == id)
          c.copyWith(
            lastMessage: lastMessage,
            lastTime: lastTime,
            unread: unread,
          )
        else
          c,
    ];
    _cacheConversations();
  }
}

// ─── NAVIGATION ───────────────────────────────────────────────────────

final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

// ─── DERIVED PROVIDERS ────────────────────────────────────────────────

final unreadCountProvider = Provider<int>((ref) {
  final list = ref.watch(conversationsProvider);
  return list.fold(0, (sum, c) => sum + c.unread);
});

final currentConversationIdProvider = StateProvider<String?>((ref) => null);

// ─── SHARED UTILITIES ──────────────────────────────────────────────

String formatRelativeTime(DateTime t) {
  final local = t.isUtc ? t.toLocal() : t;
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.isNegative) return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  if (diff.inMinutes < 1) return 'ahora';
  if (now.day == local.day && now.month == local.month && now.year == local.year) {
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (local.day == yesterday.day && local.month == yesterday.month && local.year == yesterday.year) {
    return 'ayer';
  }
  if (diff.inDays < 7) return 'hace ${diff.inDays} d';
  return '${local.day}/${local.month}/${local.year}';
}
