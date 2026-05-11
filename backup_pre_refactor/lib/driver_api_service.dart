import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ============================================================
//  ENHANCED MODELS
// ============================================================

enum MessageStatus { sending, sent, delivered, read, failed }

enum MessageType { text, image, video, audio, document, location, sticker, system }

class MessageReaction {
  final String userId;
  final String emoji;
  final String timestamp;

  const MessageReaction({
    required this.userId,
    required this.emoji,
    required this.timestamp,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) => MessageReaction(
        userId: json['user_id'] ?? '',
        emoji: json['emoji'] ?? '',
        timestamp: json['timestamp'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'emoji': emoji,
        'timestamp': timestamp,
      };
}

class EnhancedMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String type;
  final String text;
  final String mediaUrl;
  final String mediaThumbnail;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final double? latitude;
  final double? longitude;
  final String status;
  final String? replyToId;
  final Map<String, dynamic>? replyPreview;
  final String? editedAt;
  final bool isDeletedForAll;
  final List<MessageReaction> reactions;
  final String senderName;
  final String senderAvatar;
  final String sentAt;
  final String? deliveredAt;
  final String? readAt;
  final String? expiresAt;
  final String createdAt;

  const EnhancedMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.type = 'text',
    this.text = '',
    this.mediaUrl = '',
    this.mediaThumbnail = '',
    this.fileName = '',
    this.fileSize = 0,
    this.mimeType = '',
    this.latitude,
    this.longitude,
    this.status = 'sent',
    this.replyToId,
    this.replyPreview,
    this.editedAt,
    this.isDeletedForAll = false,
    this.reactions = const [],
    this.senderName = '',
    this.senderAvatar = '',
    this.sentAt = '',
    this.deliveredAt,
    this.readAt,
    this.expiresAt,
    this.createdAt = '',
  });

  factory EnhancedMessage.fromJson(Map<String, dynamic> json) => EnhancedMessage(
        id: json['id'] ?? '',
        chatId: json['chat_id'] ?? '',
        senderId: json['sender_id'] ?? '',
        type: json['type'] ?? 'text',
        text: json['text'] ?? '',
        mediaUrl: json['media_url'] ?? '',
        mediaThumbnail: json['media_thumbnail'] ?? '',
        fileName: json['file_name'] ?? '',
        fileSize: json['file_size'] ?? 0,
        mimeType: json['mime_type'] ?? '',
        latitude: json['latitude']?.toDouble(),
        longitude: json['longitude']?.toDouble(),
        status: json['status'] ?? 'sent',
        replyToId: json['reply_to_id'],
        replyPreview: json['reply_preview'] as Map<String, dynamic>?,
        editedAt: json['edited_at'],
        isDeletedForAll: json['is_deleted_for_all'] ?? false,
        reactions: (json['reactions'] as List<dynamic>?)
                ?.map((r) => MessageReaction.fromJson(r as Map<String, dynamic>))
                .toList() ??
            [],
        senderName: json['sender_name'] ?? '',
        senderAvatar: json['sender_avatar'] ?? '',
        sentAt: json['sent_at'] ?? '',
        deliveredAt: json['delivered_at'],
        readAt: json['read_at'],
        expiresAt: json['expires_at'],
        createdAt: json['created_at'] ?? '',
      );

  MessageStatus get messageStatus {
    switch (status) {
      case 'sending':
        return MessageStatus.sending;
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sent;
    }
  }
}

class EnhancedChat {
  final String id;
  final String type;
  final String name;
  final String avatarUrl;
  final bool isPinned;
  final bool isArchived;
  final bool isMuted;
  final int disappearingMsgSeconds;
  final List<String> participants;
  final String? lastMessage;
  final String? lastMessageType;
  final String? lastMessageTime;
  final String? lastSenderId;
  final int unreadCount;
  final String createdAt;
  final String updatedAt;

  const EnhancedChat({
    required this.id,
    this.type = 'individual',
    this.name = '',
    this.avatarUrl = '',
    this.isPinned = false,
    this.isArchived = false,
    this.isMuted = false,
    this.disappearingMsgSeconds = 0,
    this.participants = const [],
    this.lastMessage,
    this.lastMessageType,
    this.lastMessageTime,
    this.lastSenderId,
    this.unreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EnhancedChat.fromJson(Map<String, dynamic> json) => EnhancedChat(
        id: json['id'] ?? '',
        type: json['type'] ?? 'individual',
        name: json['name'] ?? '',
        avatarUrl: json['avatar_url'] ?? '',
        isPinned: json['is_pinned'] ?? false,
        isArchived: json['is_archived'] ?? false,
        isMuted: json['is_muted'] ?? false,
        disappearingMsgSeconds: json['disappearing_msg_seconds'] ?? 0,
        participants: (json['participants'] as List<dynamic>?)?.cast<String>() ?? [],
        lastMessage: json['last_message'],
        lastMessageType: json['last_message_type'],
        lastMessageTime: json['last_message_time'],
        lastSenderId: json['last_sender_id'],
        unreadCount: json['unread_count'] ?? 0,
        createdAt: json['created_at'] ?? '',
        updatedAt: json['updated_at'] ?? '',
      );
}

// ============================================================
//  MODELS
// ============================================================

class Offer {
  final String id;
  final String driverId;
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
    required this.driverId,
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
        driverId: json['driver_id'] ?? '',
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
        'driver_id': driverId,
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

class UserSearchResult {
  final String id;
  final String name;
  final String lastName;
  final String email;
  final String phone;
  final String avatar;
  final String role;

  UserSearchResult({
    required this.id,
    required this.name,
    required this.lastName,
    required this.email,
    required this.phone,
    this.avatar = '',
    this.role = 'passenger',
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) =>
      UserSearchResult(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        lastName: json['last_name'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'] ?? '',
        avatar: json['avatar'] ?? '',
        role: json['role'] ?? 'passenger',
      );
}

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
  final String type;
  final String? targetId;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    required this.isRead,
    required this.createdAt,
    this.type = '',
    this.targetId,
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
        type: json['type'] ?? '',
        targetId: json['target_id'],
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

class RideRequest {
  final String id;
  final String offerId;
  final String passengerId;
  final String driverId;
  final String status;
  final String createdAt;
  final String passengerName;
  final String passengerAvatar;
  final String passengerPhone;
  final String recogida;
  final String destino;
  final double price;
  final String driverName;

  RideRequest({
    required this.id,
    required this.offerId,
    required this.passengerId,
    required this.driverId,
    required this.status,
    required this.createdAt,
    this.passengerName = '',
    this.passengerAvatar = '',
    this.passengerPhone = '',
    this.recogida = '',
    this.destino = '',
    this.price = 0,
    this.driverName = '',
  });

  factory RideRequest.fromJson(Map<String, dynamic> json) => RideRequest(
        id: json['id'] ?? '',
        offerId: json['offer_id'] ?? '',
        passengerId: json['passenger_id'] ?? '',
        driverId: json['driver_id'] ?? '',
        status: json['status'] ?? 'pending',
        createdAt: json['created_at'] ?? '',
        passengerName: json['passenger_name'] ?? '',
        passengerAvatar: json['passenger_avatar'] ?? '',
        passengerPhone: json['passenger_phone'] ?? '',
        recogida: json['recogida'] ?? '',
        destino: json['destino'] ?? '',
        price: (json['price'] ?? 0).toDouble(),
        driverName: json['driver_name'] ?? '',
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

class TransactionItem {
  final String id;
  final String tripId;
  final double amount;
  final String status;
  final String type;
  final String description;
  final String paymentMethodLabel;
  final String otherPartyName;
  final String otherPartyAvatar;
  final bool isIncome;
  final String createdAt;

  TransactionItem({
    required this.id,
    this.tripId = '',
    required this.amount,
    this.status = 'completed',
    this.type = 'payment',
    this.description = '',
    this.paymentMethodLabel = '',
    this.otherPartyName = '',
    this.otherPartyAvatar = '',
    this.isIncome = false,
    required this.createdAt,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) =>
      TransactionItem(
        id: json['id'] ?? '',
        tripId: json['trip_id'] ?? '',
        amount: (json['amount'] ?? 0).toDouble(),
        status: json['status'] ?? 'completed',
        type: json['type'] ?? 'payment',
        description: json['description'] ?? '',
        paymentMethodLabel: json['payment_method_label'] ?? '',
        otherPartyName: json['other_party_name'] ?? '',
        otherPartyAvatar: json['other_party_avatar'] ?? '',
        isIncome: json['is_income'] ?? false,
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
  static String get _baseUrl {
    if (kIsWeb) return 'http://192.168.4.23:8000';
    return 'http://192.168.4.23:8000';
  }
  static const String _tokenKey = 'jwt_token';

  // ⚠️ MODO DESARROLLO: Cambia a false cuando tengas el servidor listo
  // En true: la app usa datos de prueba (no necesita servidor)
  // En false: la app se conecta a _baseUrl
  static const bool devMode = false;

  // 🔒 Keystore en Android / Keychain en iOS
  final _storage = const FlutterSecureStorage();

  String? _token; // copia en memoria → evita leer disco en cada llamada

  String get wsBaseUrl => _baseUrl.replaceFirst('http', 'ws');
  String? get token => _token;

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
      
      // Imprime el error exacto (ej. Contraseña incorrecta) en la consola
      debugPrint('🚨 [API ERROR] HTTP ${res.statusCode} - $detail');
      
      throw ApiException(res.statusCode, detail);
    }
  }

  // ── TOKEN ──────────────────────────────────────────────────

  /// Llama esto en main() — recupera sesión guardada del disco
  Future<String?> loadToken() async {
    if (kIsWeb) return _token;
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

    if (!kIsWeb) {
      await _storage.write(key: _tokenKey, value: _token);
    }

    return _token!;
  }

  /// Borra token de disco y memoria
  Future<void> logout() async {
    _token = null;
    if (!kIsWeb) {
      await _storage.delete(key: _tokenKey);
    }
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

  // ── PUBLIC PROFILE ─────────────────────────────────────────

  Future<UserProfileResponse> getPublicProfile(String userId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/users/$userId'),
      headers: _jsonHeaders,
    );
    _checkStatus(res);
    return UserProfileResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
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

  /// POST /conversations/ensure — crea o devuelve conversacion existente
  Future<ConversationItem> ensureConversation(
      String user1Id, String user2Id) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/conversations/ensure'),
      headers: _jsonHeaders,
      body: jsonEncode({'user1_id': user1Id, 'user2_id': user2Id}),
    );
    _checkStatus(res);
    return ConversationItem.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

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

  Future<void> deleteMessage(String conversationId, String messageId) async {
    _requireToken();
    final uri = Uri.parse('$_baseUrl/conversations/$conversationId/messages/$messageId').replace(
      queryParameters: {'token': _token!},
    );
    final res = await http.delete(uri, headers: _jsonHeaders);
    _checkStatus(res);
  }

  Future<void> markConversationRead(String conversationId, String userId) async {
    final uri = Uri.parse('$_baseUrl/conversations/$conversationId/read').replace(
      queryParameters: {'user_id': userId},
    );
    final res = await http.patch(uri, headers: _jsonHeaders);
    _checkStatus(res);
  }

  /// DELETE /conversations/{id} — elimina conversación del lado del usuario
  Future<void> deleteConversation(String conversationId) async {
    _requireToken();
    final uri = Uri.parse('$_baseUrl/conversations/$conversationId').replace(
      queryParameters: {'token': _token!},
    );
    final res = await http.delete(uri, headers: _jsonHeaders);
    _checkStatus(res);
  }

  // ── RIDE REQUESTS ──────────────────────────────────────────

  /// POST /requests/create — pasajero solicita unirse a un viaje
  Future<RideRequest> createRideRequest(String offerId) async {
    _requireToken();
    final uri = Uri.parse('$_baseUrl/requests/create').replace(
      queryParameters: {'token': _token!},
    );
    final res = await http.post(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode({'offer_id': offerId}),
    );
    _checkStatus(res);
    return RideRequest.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// GET /requests/incoming — conductor ve solicitudes pendientes
  Future<List<RideRequest>> getIncomingRequests() async {
    _requireToken();
    final uri = Uri.parse('$_baseUrl/requests/incoming').replace(
      queryParameters: {'token': _token!},
    );
    final res = await http.get(uri, headers: _jsonHeaders);
    _checkStatus(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => RideRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /requests/my — pasajero ve sus solicitudes
  Future<List<RideRequest>> getMyRequests() async {
    _requireToken();
    final uri = Uri.parse('$_baseUrl/requests/my').replace(
      queryParameters: {'token': _token!},
    );
    final res = await http.get(uri, headers: _jsonHeaders);
    _checkStatus(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => RideRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// PATCH /requests/{id}/accept — conductor acepta
  Future<RideRequest> acceptRequest(String requestId) async {
    _requireToken();
    final uri = Uri.parse('$_baseUrl/requests/$requestId/accept').replace(
      queryParameters: {'token': _token!},
    );
    final res = await http.patch(uri, headers: _jsonHeaders);
    _checkStatus(res);
    return RideRequest.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// PATCH /requests/{id}/reject — conductor rechaza
  Future<RideRequest> rejectRequest(String requestId) async {
    _requireToken();
    final uri = Uri.parse('$_baseUrl/requests/$requestId/reject').replace(
      queryParameters: {'token': _token!},
    );
    final res = await http.patch(uri, headers: _jsonHeaders);
    _checkStatus(res);
    return RideRequest.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// PATCH /requests/{id}/cancel — pasajero cancela su solicitud
  Future<void> cancelRequest(String requestId) async {
    _requireToken();
    final uri = Uri.parse('$_baseUrl/requests/$requestId/cancel').replace(
      queryParameters: {'token': _token!},
    );
    final res = await http.patch(uri, headers: _jsonHeaders);
    _checkStatus(res);
  }

  // ── OFFERS ──────────────────────────────────────────────────

  /// DELETE /offers/{offer_id} — conductor elimina su oferta
  Future<void> deleteOffer(String offerId) async {
    _requireToken();
    final uri = Uri.parse('$_baseUrl/offers/$offerId').replace(
      queryParameters: {'token': _token!},
    );
    final res = await http.delete(uri, headers: _jsonHeaders);
    _checkStatus(res);
  }

  // ── USERS SEARCH ────────────────────────────────────────────

  /// GET /users/search?q=text → busca usuarios por nombre/email
  Future<List<UserSearchResult>> searchUsers(String query) async {
    final uri = Uri.parse('$_baseUrl/users/search').replace(
      queryParameters: {'q': query},
    );
    final res = await http.get(uri, headers: _jsonHeaders);
    _checkStatus(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => UserSearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── USERS BATCH ─────────────────────────────────────────────

  /// GET /users/batch?ids=id1,id2 → mapa id → {name, last_name, avatar}
  Future<Map<String, Map<String, String>>> getUsersBatch(List<String> ids) async {
    final uri = Uri.parse('$_baseUrl/users/batch').replace(
      queryParameters: {'ids': ids.join(',')},
    );
    final res = await http.get(uri, headers: _jsonHeaders);
    _checkStatus(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data.map((k, v) {
      final m = v as Map<String, dynamic>;
      return MapEntry(k, {
        'name': (m['name'] ?? '') as String,
        'last_name': (m['last_name'] ?? '') as String,
        'avatar': (m['avatar'] ?? '') as String,
      });
    });
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

  // ── ENHANCED CHAT ──────────────────────────────────────────

  Future<EnhancedChat> ensureEnhancedChat(String userId, String otherUserId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/chat/ensure'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'type': 'individual',
        'participant_ids': [userId, otherUserId],
      }),
    );
    _checkStatus(res);
    return EnhancedChat.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<EnhancedChat>> getEnhancedChatList(String userId) async {
    final uri = Uri.parse('$_baseUrl/chat/list').replace(
      queryParameters: {'user_id': userId},
    );
    final res = await http.get(uri, headers: _jsonHeaders);
    _checkStatus(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => EnhancedChat.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<EnhancedChat> updateChat(String chatId, {
    bool? isPinned, bool? isArchived, bool? isMuted,
    int? disappearingMsgSeconds, String? name,
  }) async {
    final body = <String, dynamic>{};
    if (isPinned != null) body['is_pinned'] = isPinned;
    if (isArchived != null) body['is_archived'] = isArchived;
    if (isMuted != null) body['is_muted'] = isMuted;
    if (disappearingMsgSeconds != null) body['disappearing_msg_seconds'] = disappearingMsgSeconds;
    if (name != null) body['name'] = name;
    final res = await http.patch(
      Uri.parse('$_baseUrl/chat/$chatId'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    _checkStatus(res);
    return EnhancedChat.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<EnhancedMessage> sendEnhancedMessage({
    required String chatId,
    required String senderId,
    required String text,
    String type = 'text',
    String? replyToId,
  }) async {
    final body = <String, dynamic>{
      'chat_id': chatId,
      'sender_id': senderId,
      'text': text,
      'type': type,
    };
    if (replyToId != null) body['reply_to_id'] = replyToId;
    final res = await http.post(
      Uri.parse('$_baseUrl/chat/messages'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    _checkStatus(res);
    return EnhancedMessage.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<EnhancedMessage>> getEnhancedMessages(String chatId, {String? before, int limit = 50}) async {
    final queryParams = <String, String>{'limit': limit.toString()};
    if (before != null) queryParams['before'] = before;
    final uri = Uri.parse('$_baseUrl/chat/$chatId/messages').replace(queryParameters: queryParams);
    final res = await http.get(uri, headers: _jsonHeaders);
    _checkStatus(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => EnhancedMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> markEnhancedMessagesRead(List<String> messageIds, String userId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/chat/messages/read'),
      headers: _jsonHeaders,
      body: jsonEncode({'message_ids': messageIds, 'user_id': userId}),
    );
    _checkStatus(res);
  }

  Future<void> addReaction(String messageId, String userId, String emoji) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/chat/messages/$messageId/reactions'),
      headers: _jsonHeaders,
      body: jsonEncode({'user_id': userId, 'emoji': emoji}),
    );
    _checkStatus(res);
  }

  Future<void> removeReaction(String messageId, String userId) async {
    final uri = Uri.parse('$_baseUrl/chat/messages/$messageId/reactions').replace(
      queryParameters: {'user_id': userId},
    );
    final res = await http.delete(uri, headers: _jsonHeaders);
    _checkStatus(res);
  }

  Future<void> editEnhancedMessage(String messageId, String text) async {
    final res = await http.patch(
      Uri.parse('$_baseUrl/chat/messages/$messageId'),
      headers: _jsonHeaders,
      body: jsonEncode({'text': text}),
    );
    _checkStatus(res);
  }

  Future<void> deleteEnhancedMessage(String messageId, {String mode = 'for_me', required String userId}) async {
    final uri = Uri.parse('$_baseUrl/chat/messages/$messageId').replace(
      queryParameters: {'mode': mode, 'user_id': userId},
    );
    final res = await http.delete(uri, headers: _jsonHeaders);
    _checkStatus(res);
  }

  Future<List<Map<String, dynamic>>> searchMessages(String query, String userId) async {
    final uri = Uri.parse('$_baseUrl/chat/search').replace(
      queryParameters: {'q': query, 'user_id': userId},
    );
    final res = await http.get(uri, headers: _jsonHeaders);
    _checkStatus(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<List<EnhancedMessage>> forwardMessages({
    required String fromChatId,
    required String toChatId,
    required List<String> messageIds,
    required String senderId,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/chat/forward'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'from_chat_id': fromChatId,
        'to_chat_id': toChatId,
        'message_ids': messageIds,
        'sender_id': senderId,
      }),
    );
    _checkStatus(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => EnhancedMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── WALLET / PAYMENTS ───────────────────────────────────────────

  Future<Map<String, dynamic>> getWallet(String userId) async {
    _requireToken();
    final uri = Uri.parse('$_baseUrl/payments/wallet').replace(
      queryParameters: {'user_id': userId, 'token': _token!},
    );
    final res = await http.get(uri, headers: _jsonHeaders);
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<TransactionItem>> getTransactions(String userId) async {
    final uri = Uri.parse('$_baseUrl/payments/transactions').replace(
      queryParameters: {'user_id': userId},
    );
    final res = await http.get(uri, headers: _jsonHeaders);
    _checkStatus(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => TransactionItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> processPayment({
    required String tripId,
    required double amount,
    required String paymentMethodId,
    String? description,
  }) async {
    _requireToken();
    final res = await http.post(
      Uri.parse('$_baseUrl/payments/process'),
      headers: _authHeaders,
      body: jsonEncode({
        'trip_id': tripId,
        'amount': amount,
        'payment_method_id': paymentMethodId,
        'description': description ?? '',
      }),
    );
    _checkStatus(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['success'] ?? false;
  }

  Future<bool> confirmPayment(String tripId) async {
    _requireToken();
    final uri = Uri.parse('$_baseUrl/payments/confirm/$tripId').replace(
      queryParameters: {'token': _token!},
    );
    final res = await http.patch(uri, headers: _jsonHeaders);
    _checkStatus(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['success'] ?? false;
  }

  String get notificationWsUrl => '${_baseUrl.replaceFirst('http', 'ws')}/ws/notifications';

  Future<void> deleteNotification(String notificationId) async {
    _requireToken();
    final uri = Uri.parse('$_baseUrl/notifications/$notificationId').replace(
      queryParameters: {'token': _token!},
    );
    final res = await http.delete(uri, headers: _authHeaders);
    _checkStatus(res);
  }

  String get enhancedWsBaseUrl => '${_baseUrl.replaceFirst('http', 'ws')}/ws/chat/v2';

  // ── AVATAR ────────────────────────────────────────────

  Future<String> uploadAvatar(String filePath) async {
    _requireToken();
    final uri = Uri.parse('$_baseUrl/users/me/avatar').replace(
      queryParameters: {'token': _token!},
    );
    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('avatar', filePath));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    _checkStatus(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['avatar_url'] as String? ?? '';
  }

  Future<void> deleteAvatar() async {
    _requireToken();
    final uri = Uri.parse('$_baseUrl/users/me/avatar').replace(
      queryParameters: {'token': _token!},
    );
    final res = await http.delete(uri, headers: _authHeaders);
    _checkStatus(res);
  }
}
