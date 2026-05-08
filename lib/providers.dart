import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'theme.dart';
import 'driver_api_service.dart';

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

  Future<void> loadProfile() async {
    try {
      final profile = await _api.getUserProfile();
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
      } catch (e) {
        debugPrint('loadProfile error: $e');
      }
  }

  void update(UserProfile profile) => state = profile;
  void updateName(String v) => state = state.copyWith(name: v);
  void updateEmail(String v) => state = state.copyWith(email: v);
  void updatePhone(String v) => state = state.copyWith(phone: v);
  void updateBio(String v) => state = state.copyWith(bio: v);
  void verify() => state = state.copyWith(isVerified: true);
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

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime time;
  final bool isRead;
  final IconData icon;
  final Color color;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    required this.color,
    this.isRead = false,
  });

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      time: time,
      icon: icon,
      color: color,
      isRead: isRead ?? this.isRead,
    );
  }
}

class NotificationsNotifier extends StateNotifier<List<AppNotification>> {
  final DriverApiService _api;

  NotificationsNotifier(this._api) : super([]);

  Future<void> loadNotifications(String userId) async {
    try {
      final items = await _api.getNotifications(userId);
      state = items.map((n) {
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
        return AppNotification(
          id: n.id,
          title: n.title,
          body: n.body,
          time: DateTime.tryParse(n.createdAt) ?? DateTime.now(),
          icon: icon,
          color: color,
          isRead: n.isRead,
        );
      }).toList();
    } catch (e) {
      debugPrint('loadNotifications error: $e');
    }
  }

  void markRead(String id) {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];
  }

  void markAllRead() {
    state = [for (final n in state) n.copyWith(isRead: true)];
  }

  void addNotification(AppNotification notification) {
    state = [notification, ...state];
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
}

final tripsProvider = StateNotifierProvider<TripsNotifier, List<Trip>>(
  (ref) => TripsNotifier(ref.read(driverApiProvider)),
);

Trip _offerToTrip(Offer offer) {
  return Trip(
    id: offer.id,
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

  Future<void> loadTrips() async {
    try {
      final offers = await _api.getActiveOffers();
      state = offers.map(_offerToTrip).toList();
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
  }

  void leaveTrip(String id) {
    state = [
      for (final t in state)
        if (t.id == id)
          t.copyWith(isJoined: false, seatsAvailable: t.seatsAvailable + 1)
        else
          t
    ];
  }
}

// ─── CHAT ────────────────────────────────────────────────────────────

class ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final DateTime time;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.time,
    this.isRead = false,
  });
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

  const Conversation({
    required this.id,
    required this.name,
    required this.avatar,
    required this.lastMessage,
    required this.lastTime,
    required this.unread,
    required this.isOnline,
    required this.messages,
  });

  Conversation copyWith({
    List<ChatMessage>? messages,
    String? lastMessage,
    int? unread,
  }) {
    return Conversation(
      id: id,
      name: name,
      avatar: avatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastTime: lastTime,
      unread: unread ?? this.unread,
      isOnline: isOnline,
      messages: messages ?? this.messages,
    );
  }
}

final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, List<Conversation>>(
  (ref) => ConversationsNotifier(ref.read(driverApiProvider)),
);

class ConversationsNotifier extends StateNotifier<List<Conversation>> {
  final DriverApiService _api;

  ConversationsNotifier(this._api) : super([]);

  Future<void> loadConversations(String userId) async {
    try {
      final items = await _api.getConversations(userId);
      state = items.map((c) {
        final otherId = c.user1Id == userId ? c.user2Id : c.user1Id;
        return Conversation(
          id: c.id,
          name: otherId,
          avatar: otherId.isNotEmpty ? otherId[0].toUpperCase() : '?',
          lastMessage: c.lastMessage,
          lastTime: DateTime.tryParse(c.lastTime ?? '') ?? DateTime.now(),
          unread: 0,
          isOnline: false,
          messages: [],
        );
      }).toList();
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
              ...c.messages,
              ChatMessage(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                text: text,
                isMe: true,
                time: DateTime.now(),
              ),
            ],
            lastMessage: text,
            unread: 0,
          )
        else
          c,
    ];
  }

  void markAsRead(String id) {
    state = [
      for (final c in state)
        if (c.id == id) c.copyWith(unread: 0) else c,
    ];
  }
}

// ─── NAVIGATION ───────────────────────────────────────────────────────

final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

// ─── DERIVED PROVIDERS ────────────────────────────────────────────────

final unreadCountProvider = Provider<int>((ref) {
  final list = ref.watch(conversationsProvider);
  return list.fold(0, (sum, c) => sum + c.unread);
});
