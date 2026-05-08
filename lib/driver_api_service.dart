import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ============================================================
//  MODELS
// ============================================================

class Offer {
  final String id;
  final String driverName;
  final String driverLastName;
  final String driverPhone;
  final double rating;
  final String job;
  final int trips;
  final double price;
  final String distance;
  final String time;
  final String hour;
  final String color;
  final String avatar;
  final double homeLat;
  final double homeLng;
  final double destinationLat;
  final double destinationLng;
  final String recogida;
  final String destino;
  final String colorText;
  final String modeloAuto;
  final String mapaTheme;
  final String placaAuto;
  final bool active;

  Offer({
    required this.id,
    required this.driverName,
    required this.driverLastName,
    required this.driverPhone,
    required this.rating,
    required this.job,
    required this.trips,
    required this.price,
    required this.distance,
    required this.time,
    required this.hour,
    required this.color,
    required this.avatar,
    required this.homeLat,
    required this.homeLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.recogida,
    required this.destino,
    required this.colorText,
    required this.modeloAuto,
    required this.mapaTheme,
    required this.placaAuto,
    required this.active,
  });

  factory Offer.fromJson(Map<String, dynamic> json) => Offer(
        id: json['id'] ?? '',
        driverName: json['driver_name'] ?? '',
        driverLastName: json['driver_last_name'] ?? '',
        driverPhone: json['driver_phone'] ?? '',
        rating: (json['rating'] ?? 0).toDouble(),
        job: json['job'] ?? '',
        trips: json['trips'] ?? 0,
        price: (json['price'] ?? 0).toDouble(),
        distance: (json['distance'] ?? '').toString(),
        time: json['time'] ?? '',
        hour: json['hour'] ?? '',
        color: json['color'] ?? '',
        avatar: json['avatar'] ?? '',
        homeLat: (json['home_lat'] ?? 0).toDouble(),
        homeLng: (json['home_lng'] ?? 0).toDouble(),
        destinationLat: (json['destination_lat'] ?? 0).toDouble(),
        destinationLng: (json['destination_lng'] ?? 0).toDouble(),
        recogida: json['recogida'] ?? '',
        destino: json['destino'] ?? '',
        colorText: json['color_text'] ?? '',
        modeloAuto: json['modelo_auto'] ?? '',
        mapaTheme: json['mapa_theme'] ?? '',
        placaAuto: json['placa_auto'] ?? '',
        active: json['active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'driver_name': driverName,
        'driver_last_name': driverLastName,
        'driver_phone': driverPhone,
        'rating': rating,
        'job': job,
        'trips': trips,
        'price': price,
        'distance': distance,
        'time': time,
        'hour': hour,
        'color': color,
        'avatar': avatar,
        'home_lat': homeLat,
        'home_lng': homeLng,
        'destination_lat': destinationLat,
        'destination_lng': destinationLng,
        'recogida': recogida,
        'destino': destino,
        'color_text': colorText,
        'modelo_auto': modeloAuto,
        'mapa_theme': mapaTheme,
        'placa_auto': placaAuto,
        'active': active,
      };
}

class OfferUpdate {
  final double? rating;
  final String? job;
  final int? trips;
  final double? price;
  final String? distance;
  final String? time;
  final String? hour;
  final String? avatar;
  final double? homeLat;
  final double? homeLng;
  final double? destinationLat;
  final double? destinationLng;
  final String? recogida;
  final String? destino;
  final String? modeloAuto;
  final String? mapaTheme;
  final String? placaAuto;
  final bool? active;

  OfferUpdate({
    this.rating,
    this.job,
    this.trips,
    this.price,
    this.distance,
    this.time,
    this.hour,
    this.avatar,
    this.homeLat,
    this.homeLng,
    this.destinationLat,
    this.destinationLng,
    this.recogida,
    this.destino,
    this.modeloAuto,
    this.mapaTheme,
    this.placaAuto,
    this.active,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (rating != null) map['rating'] = rating;
    if (job != null) map['job'] = job;
    if (trips != null) map['trips'] = trips;
    if (price != null) map['price'] = price;
    if (distance != null) map['distance'] = distance;
    if (time != null) map['time'] = time;
    if (hour != null) map['hour'] = hour;
    if (avatar != null) map['avatar'] = avatar;
    if (homeLat != null) map['home_lat'] = homeLat;
    if (homeLng != null) map['home_lng'] = homeLng;
    if (destinationLat != null) map['destination_lat'] = destinationLat;
    if (destinationLng != null) map['destination_lng'] = destinationLng;
    if (recogida != null) map['recogida'] = recogida;
    if (destino != null) map['destino'] = destino;
    if (modeloAuto != null) map['modelo_auto'] = modeloAuto;
    if (mapaTheme != null) map['mapa_theme'] = mapaTheme;
    if (placaAuto != null) map['placa_auto'] = placaAuto;
    if (active != null) map['active'] = active;
    return map;
  }
}

class Driver {
  final String id;
  final String name;
  final String lastName;
  final String email;
  final String password;
  final String phone;
  final List<Offer> offers;
  final bool active;

  Driver({
    required this.id,
    required this.name,
    required this.lastName,
    required this.email,
    required this.password,
    required this.phone,
    required this.offers,
    required this.active,
  });

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        lastName: json['last_name'] ?? '',
        email: json['email'] ?? '',
        password: json['password'] ?? '',
        phone: json['phone'] ?? '',
        active: json['active'] ?? true,
        offers: (json['offers'] as List<dynamic>? ?? [])
            .map((o) => Offer.fromJson(o as Map<String, dynamic>))
            .toList(),
      );
}

// ============================================================
//  API RESPONSE MODELS
// ============================================================

class UserProfileResponse {
  final String id;
  final String name;
  final String lastName;
  final String email;
  final String phone;
  final String bio;
  final String role;
  final bool isVerified;
  final int tripsCompleted;
  final int tripsOffered;
  final double rating;
  final String avatarUrl;
  final bool active;

  UserProfileResponse({
    required this.id,
    required this.name,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.bio,
    required this.role,
    required this.isVerified,
    required this.tripsCompleted,
    required this.tripsOffered,
    required this.rating,
    required this.avatarUrl,
    required this.active,
  });

  factory UserProfileResponse.fromJson(Map<String, dynamic> json) =>
      UserProfileResponse(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        lastName: json['last_name'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'] ?? '',
        bio: json['bio'] ?? '',
        role: json['role'] ?? 'passenger',
        isVerified: json['is_verified'] ?? false,
        tripsCompleted: json['trips_completed'] ?? 0,
        tripsOffered: json['trips_offered'] ?? 0,
        rating: (json['rating'] ?? 5.0).toDouble(),
        avatarUrl: json['avatar_url'] ?? '',
        active: json['active'] ?? true,
      );
}

class NotificationItem {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String icon;
  final String color;
  final bool isRead;
  final String createdAt;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'] ?? '',
        userId: json['user_id'] ?? '',
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        icon: json['icon'] ?? 'notifications',
        color: json['color'] ?? '#0066FF',
        isRead: json['is_read'] ?? false,
        createdAt: json['created_at'] ?? '',
      );
}

class ConversationItem {
  final String id;
  final String user1Id;
  final String user2Id;
  final String lastMessage;
  final String? lastTime;
  final String createdAt;

  ConversationItem({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.lastMessage,
    this.lastTime,
    required this.createdAt,
  });

  factory ConversationItem.fromJson(Map<String, dynamic> json) =>
      ConversationItem(
        id: json['id'] ?? '',
        user1Id: json['user1_id'] ?? '',
        user2Id: json['user2_id'] ?? '',
        lastMessage: json['last_message'] ?? '',
        lastTime: json['last_time'],
        createdAt: json['created_at'] ?? '',
      );
}

class MessageItem {
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final String createdAt;
  final bool isRead;

  MessageItem({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.isRead,
  });

  factory MessageItem.fromJson(Map<String, dynamic> json) => MessageItem(
        id: json['id'] ?? '',
        conversationId: json['conversation_id'] ?? '',
        senderId: json['sender_id'] ?? '',
        text: json['text'] ?? '',
        createdAt: json['created_at'] ?? '',
        isRead: json['is_read'] ?? false,
      );
}

class ReviewItem {
  final String id;
  final String reviewerId;
  final String revieweeId;
  final String? tripId;
  final int rating;
  final String comment;
  final String createdAt;

  ReviewItem({
    required this.id,
    required this.reviewerId,
    required this.revieweeId,
    this.tripId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> json) => ReviewItem(
        id: json['id'] ?? '',
        reviewerId: json['reviewer_id'] ?? '',
        revieweeId: json['reviewee_id'] ?? '',
        tripId: json['trip_id'],
        rating: json['rating'] ?? 5,
        comment: json['comment'] ?? '',
        createdAt: json['created_at'] ?? '',
      );
}

class PaymentMethodItem {
  final String id;
  final String userId;
  final String type;
  final String label;
  final String detail;
  final bool isDefault;
  final String createdAt;

  PaymentMethodItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.label,
    required this.detail,
    required this.isDefault,
    required this.createdAt,
  });

  factory PaymentMethodItem.fromJson(Map<String, dynamic> json) =>
      PaymentMethodItem(
        id: json['id'] ?? '',
        userId: json['user_id'] ?? '',
        type: json['type'] ?? '',
        label: json['label'] ?? '',
        detail: json['detail'] ?? '',
        isDefault: json['is_default'] ?? false,
        createdAt: json['created_at'] ?? '',
      );
}

// ============================================================
//  EXCEPTION
// ============================================================

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

// ============================================================
//  SERVICE
// ============================================================

class DriverApiService {
  // Para Android emulator: 10.0.2.2 → host localhost
  // Para iOS simulator: usa localhost directamente
  static const String _baseUrl = 'http://10.0.2.2:8000';
  static const String _tokenKey = 'jwt_token';

  // ⚠️ MODO DESARROLLO: Cambia a false cuando tengas el servidor listo
  // En true: la app usa datos de prueba (no necesita servidor)
  // En false: la app se conecta a _baseUrl
  static const bool devMode = false;

  // 🔒 Keystore en Android / Keychain en iOS
  final _storage = const FlutterSecureStorage();

  String? _token; // copia en memoria → evita leer disco en cada llamada

  // ── helpers ────────────────────────────────────────

  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
      };

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  void _requireToken() {
    if (_token == null) {
      throw ApiException(401, 'No hay token. Haz login primero.');
    }
  }

  void _checkStatus(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String detail = res.body;
      try {
        detail = jsonDecode(res.body)['detail'] ?? res.body;
      } catch (_) {}
      throw ApiException(res.statusCode, detail);
    }
  }

  // ── TOKEN ──────────────────────────────────────────────────

  /// Llama esto en main() — recupera sesión guardada del disco
  Future<String?> loadToken() async {
    _token = await _storage.read(key: _tokenKey);
    return _token;
  }

  /// true si hay sesión activa
  bool get isLoggedIn => _token != null;

  // ── AUTH ───────────────────────────────────────────────────

  /// POST /login_jwt → guarda token encriptado en disco + memoria
  Future<String> loginJwt({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/login_jwt'),
      headers: _jsonHeaders,
      body: jsonEncode({'email': email, 'password': password}),
    );
    _checkStatus(res);

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    _token = data['access_token'] as String;

    // 🔒 guardar encriptado en disco
    await _storage.write(key: _tokenKey, value: _token);

    return _token!;
  }

  /// Borra token de disco y memoria
  Future<void> logout() async {
    _token = null;
    await _storage.delete(key: _tokenKey);
  }

  // ── DRIVER CREATION ────────────────────────────────────────

  /// POST /Create_driver/
  Future<void> createDriver({
    required String name,
    required String lastName,
    required String email,
    required String password,
    required String phone,
    required String role,
  }) async {
    final body = {
      'name': name,
      'last_name': lastName,
      'email': email,
      'password': password,
      'phone': phone,
      'role': role,
    };
    final res = await http.post(
      Uri.parse('$_baseUrl/Create_driver/'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    _checkStatus(res);
  }

  // ── OFFERS ─────────────────────────────────────────────────

  /// GET /offers_list → todas las ofertas (sin auth)
  Future<List<Offer>> getAllOffers() async {
    final res = await http.get(Uri.parse('$_baseUrl/offers_list'));
    _checkStatus(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => Offer.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /login/offers → ofertas del driver (legacy, sin JWT)
  Future<List<Offer>> getMyOffersLegacy({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/login/offers'),
      headers: _jsonHeaders,
      body: jsonEncode({'email': email, 'password': password}),
    );
    _checkStatus(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => Offer.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// PATCH /offers_list_jdwt → ofertas del driver con JWT
  Future<List<Offer>> getMyOffersJwt() async {
    _requireToken();

    final res = await http.patch(
      Uri.parse('$_baseUrl/offers_list_jdwt'),
      headers: _authHeaders,
    );
    _checkStatus(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => Offer.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// PATCH /offers_update → actualizar oferta (legacy, sin JWT)
  Future<List<Offer>> updateOfferLegacy({
    required String email,
    required String password,
    required OfferUpdate offerData,
  }) async {
    final uri = Uri.parse('$_baseUrl/offers_update/')
        .replace(queryParameters: {'email': email, 'password': password});
    final res = await http.patch(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode(offerData.toJson()),
    );
    _checkStatus(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => Offer.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// PATCH /offers_update_jwt → actualizar oferta con JWT
  Future<List<Offer>> updateOfferJwt(OfferUpdate offerData) async {
    _requireToken();

    final res = await http.patch(
      Uri.parse('$_baseUrl/offers_update_jwt'),
      headers: _authHeaders,
      body: jsonEncode(offerData.toJson()),
    );
    _checkStatus(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => Offer.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── DRIVERS ────────────────────────────────────────────────

  /// GET /all_drivers → todos los drivers (sin auth)
  Future<List<Driver>> getAllDrivers() async {
    final res = await http.get(Uri.parse('$_baseUrl/all_drivers'));
    _checkStatus(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => Driver.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// PATCH /login → login legacy
  Future<Driver> loginLegacy({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/login')
        .replace(queryParameters: {'email': email, 'password': password});
    final res = await http.patch(uri, headers: _jsonHeaders);
    _checkStatus(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return Driver.fromJson(list.first as Map<String, dynamic>);
  }

  // ── PASSWORD RESET ─────────────────────────────────────────

  /// PATCH /password_reset → sin auth (legacy)
  Future<String> resetPasswordLegacy({
    required String email,
    required String newPassword,
  }) async {
    final uri = Uri.parse('$_baseUrl/password_reset').replace(
      queryParameters: {'email': email, 'new_password': newPassword},
    );
    final res = await http.patch(uri, headers: _jsonHeaders);
    _checkStatus(res);
    return (jsonDecode(res.body) as Map<String, dynamic>)['message'] as String;
  }

  /// PATCH /password_reset_jwt → con JWT
  Future<String> resetPasswordJwt({
    required String email,
    required String id,
    required String newPassword,
  }) async {
    _requireToken();

    final res = await http.patch(
      Uri.parse('$_baseUrl/password_reset_jwt'),
      headers: _authHeaders,
      body: jsonEncode({'email': email, 'id': id, 'new_password': newPassword}),
    );
    _checkStatus(res);
    return (jsonDecode(res.body) as Map<String, dynamic>)['message'] as String;
  }

  // ── USER PROFILE ────────────────────────────────────────────

  Future<UserProfileResponse> getUserProfile() async {
    _requireToken();
    final uri = Uri.parse('$_baseUrl/users/me').replace(
      queryParameters: {'token': _token!},
    );
    final res = await http.get(uri, headers: _jsonHeaders);
    _checkStatus(res);
    return UserProfileResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ── CREATE / REPLACE MY OFFER ─────────────────────────────

  /// POST /offers/create — crea o reemplaza la oferta activa del conductor (1 sola)
  Future<Offer> createMyOffer({
    required String recogida,
    required String destino,
    required double price,
    required int trips,
    required String hour,
    required String time,
    required String modeloAuto,
    required String placaAuto,
    required String color,
    required String colorText,
  }) async {
    _requireToken();
    final uri = Uri.parse('$_baseUrl/offers/create').replace(
      queryParameters: {'token': _token!},
    );
    final res = await http.post(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode({
        'recogida': recogida,
        'destino': destino,
        'price': price,
        'trips': trips,
        'hour': hour,
        'time': time,
        'modelo_auto': modeloAuto,
        'placa_auto': placaAuto,
        'color': color,
        'color_text': colorText,
      }),
    );
    _checkStatus(res);
    return Offer.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ── ACTIVE OFFERS ──────────────────────────────────────────

  Future<List<Offer>> getActiveOffers() async {
    final res = await http.get(Uri.parse('$_baseUrl/offers'));
    _checkStatus(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => Offer.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── NOTIFICATIONS ──────────────────────────────────────────

  Future<List<NotificationItem>> getNotifications(String userId) async {
    final uri = Uri.parse('$_baseUrl/notifications').replace(
      queryParameters: {'user_id': userId},
    );
    final res = await http.get(uri, headers: _jsonHeaders);
    _checkStatus(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── CONVERSATIONS ──────────────────────────────────────────

  Future<List<ConversationItem>> getConversations(String userId) async {
    final uri = Uri.parse('$_baseUrl/conversations').replace(
      queryParameters: {'user_id': userId},
    );
    final res = await http.get(uri, headers: _jsonHeaders);
    _checkStatus(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => ConversationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<MessageItem>> getMessages(String conversationId) async {
    final res =
        await http.get(Uri.parse('$_baseUrl/conversations/$conversationId/messages'));
    _checkStatus(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => MessageItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── PAYMENT METHODS ────────────────────────────────────────

  Future<List<PaymentMethodItem>> getPaymentMethods(String userId) async {
    final uri = Uri.parse('$_baseUrl/payments/methods').replace(
      queryParameters: {'user_id': userId},
    );
    final res = await http.get(uri, headers: _jsonHeaders);
    _checkStatus(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => PaymentMethodItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendMessage(String conversationId, String senderId, String text) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/conversations/$conversationId/messages'),
      headers: _jsonHeaders,
      body: jsonEncode({'sender_id': senderId, 'text': text}),
    );
    _checkStatus(res);
  }

  // ── REVIEWS ────────────────────────────────────────────────

  Future<List<ReviewItem>> getMyReviews() async {
    _requireToken();
    final uri = Uri.parse('$_baseUrl/reviews/my').replace(
      queryParameters: {'token': _token!},
    );
    final res = await http.get(uri, headers: _jsonHeaders);
    _checkStatus(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => ReviewItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
