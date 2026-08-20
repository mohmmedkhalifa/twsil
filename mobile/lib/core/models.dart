import 'dart:convert';
import 'dart:math' as math;

class User {
  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final String role;
  final String locale;
  final bool isBanned;

  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.role,
    this.locale = 'ar',
    this.isBanned = false,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        role: json['role'] as String? ?? 'customer',
        locale: json['locale'] as String? ?? 'ar',
        isBanned: json['isBanned'] as bool? ?? false,
      );

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'role': role,
      };
}

class CaptainProfile {
  final String id;
  final String userId;
  final String transportType;
  final String? plateNumber;
  final String? nationalId;
  final String? city;
  final String verificationStatus;
  final String verificationNote;
  final String subscriptionStatus;
  final DateTime? subscriptionExpiresAt;
  final bool isAvailable;
  final double rating;
  final int ratingCount;
  final int totalDeliveries;
  final double totalEarnings;

  const CaptainProfile({
    required this.id,
    required this.userId,
    required this.transportType,
    this.plateNumber,
    this.nationalId,
    this.city,
    required this.verificationStatus,
    this.verificationNote = '',
    required this.subscriptionStatus,
    this.subscriptionExpiresAt,
    this.isAvailable = false,
    this.rating = 0,
    this.ratingCount = 0,
    this.totalDeliveries = 0,
    this.totalEarnings = 0,
  });

  factory CaptainProfile.fromJson(Map<String, dynamic> json) => CaptainProfile(
        id: json['id'] as String,
        userId: json['userId'] as String,
        transportType: json['transportType'] as String? ?? 'other',
        plateNumber: json['plateNumber'] as String?,
        nationalId: json['nationalId'] as String?,
        city: json['city'] as String?,
        verificationStatus: json['verificationStatus'] as String? ?? 'pending',
        verificationNote: json['verificationNote'] as String? ?? '',
        subscriptionStatus: json['subscriptionStatus'] as String? ?? 'inactive',
        subscriptionExpiresAt: json['subscriptionExpiresAt'] != null
            ? DateTime.tryParse(json['subscriptionExpiresAt'])
            : null,
        isAvailable: json['isAvailable'] as bool? ?? false,
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        ratingCount: json['ratingCount'] as int? ?? 0,
        totalDeliveries: json['totalDeliveries'] as int? ?? 0,
        totalEarnings: (json['totalEarnings'] as num?)?.toDouble() ?? 0,
      );
}

class Subscription {
  final String id;
  final double amount;
  final String paymentMethod;
  final String? receiptImageUrl;
  final String? transactionNumber;
  final String status;
  final String? adminNote;
  final DateTime? createdAt;

  const Subscription({
    required this.id,
    required this.amount,
    required this.paymentMethod,
    this.receiptImageUrl,
    this.transactionNumber,
    required this.status,
    this.adminNote,
    this.createdAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: json['id'] as String,
        amount: (json['amount'] as num?)?.toDouble() ?? 10,
        paymentMethod: json['paymentMethod'] as String? ?? 'jawwal_pay',
        receiptImageUrl: json['receiptImageUrl'] as String?,
        transactionNumber: json['transactionNumber'] as String?,
        status: json['status'] as String? ?? 'awaiting_payment',
        adminNote: json['adminNote'] as String?,
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      );
}

class Payment {
  final String id;
  final double amount;
  final String paymentMethod;
  final String? receiptImageUrl;
  final String? transactionNumber;
  final String status;
  final String? adminNote;
  final DateTime? createdAt;

  const Payment({
    required this.id,
    required this.amount,
    required this.paymentMethod,
    this.receiptImageUrl,
    this.transactionNumber,
    required this.status,
    this.adminNote,
    this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id'] as String,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        paymentMethod: json['paymentMethod'] as String? ?? 'jawwal_pay',
        receiptImageUrl: json['receiptImageUrl'] as String?,
        transactionNumber: json['transactionNumber'] as String?,
        status: json['status'] as String? ?? 'awaiting_payment',
        adminNote: json['adminNote'] as String?,
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      );
}

class Order {
  final String id;
  final String orderNumber;
  final String customerId;
  final String? captainId;
  final String customerName;
  final String? captainName;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final double dropoffLat;
  final double dropoffLng;
  final String dropoffAddress;
  final String packageDescription;
  final String packageSize;
  final double distanceKm;
  final double deliveryFee;
  final double serviceFee;
  final String status;
  final String? cancellationReason;
  final double? currentLat;
  final double? currentLng;
  final String? pickupCode;
  final List<Payment> payments;
  final String? conversationId;
  final DateTime createdAt;
  final bool ratedByCustomer;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    this.captainId,
    required this.customerName,
    this.captainName,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.dropoffAddress,
    required this.packageDescription,
    required this.packageSize,
    required this.distanceKm,
    required this.deliveryFee,
    required this.serviceFee,
    required this.status,
    this.cancellationReason,
    this.currentLat,
    this.currentLng,
    this.pickupCode,
    this.payments = const [],
    this.conversationId,
    required this.createdAt,
    this.ratedByCustomer = false,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final captain = json['captain'] as Map<String, dynamic>?;
    final payments = (json['payments'] as List<dynamic>? ?? [])
        .map((p) => Payment.fromJson(p as Map<String, dynamic>))
        .toList();
    return Order(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      captainId: json['captainId']?.toString(),
      customerName: customer == null
          ? ''
          : '${customer['firstName'] ?? ''} ${customer['lastName'] ?? ''}'.trim(),
      captainName: captain == null
          ? null
          : '${captain['firstName'] ?? ''} ${captain['lastName'] ?? ''}'.trim(),
      pickupLat: (json['pickupLat'] as num?)?.toDouble() ?? 0.0,
      pickupLng: (json['pickupLng'] as num?)?.toDouble() ?? 0.0,
      pickupAddress: json['pickupAddress']?.toString() ?? '',
      dropoffLat: (json['dropoffLat'] as num?)?.toDouble() ?? 0.0,
      dropoffLng: (json['dropoffLng'] as num?)?.toDouble() ?? 0.0,
      dropoffAddress: json['dropoffAddress']?.toString() ?? '',
      packageDescription: json['packageDescription']?.toString() ?? '',
      packageSize: json['packageSize']?.toString() ?? 'medium',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ??
          (json['distance_km'] as num?)?.toDouble() ??
          double.tryParse(json['distanceKm']?.toString() ?? '') ??
          double.tryParse(json['distance_km']?.toString() ?? '') ??
          0.0,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ??
          (json['delivery_fee'] as num?)?.toDouble() ??
          0.0,
      serviceFee: ((json['serviceFee'] as num?)?.toDouble() ??
                  (json['service_fee'] as num?)?.toDouble() ??
                  0) > 0
          ? ((json['serviceFee'] as num?)?.toDouble() ??
              (json['service_fee'] as num?)?.toDouble() ??
              1.0)
          : 1.0,
      status: json['status']?.toString() ?? 'payment_pending',
      cancellationReason: json['cancellationReason']?.toString(),
      currentLat: (json['currentLat'] as num?)?.toDouble(),
      currentLng: (json['currentLng'] as num?)?.toDouble(),
      pickupCode: json['pickupCode']?.toString(),
      payments: payments,
      conversationId: json['conversationId']?.toString(),
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      ratedByCustomer: json['ratedByCustomer'] as bool? ?? false,
    );
  }

  Payment? get latestPayment => payments.isEmpty ? null : payments.last;

  double get calculatedDistanceKm {
    if (distanceKm > 0) return distanceKm;
    if (pickupLat == 0 || dropoffLat == 0) return 0.0;
    const R = 6371;
    final dLat = (dropoffLat - pickupLat) * (math.pi / 180);
    final dLng = (dropoffLng - pickupLng) * (math.pi / 180);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(pickupLat * (math.pi / 180)) *
            math.cos(dropoffLat * (math.pi / 180)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * R * math.asin(math.sqrt(a));
  }

  String get formattedDistance => Order.formatDistance(calculatedDistanceKm);

  String get statusLabel {
    switch (status) {
      case 'payment_pending':
        return 'بانتظار دفع الرسوم';
      case 'awaiting_captain':
        return 'بانتظار قبول السائق';
      case 'accepted':
        return 'تم قبول الطلب من الكابتن';
      case 'in_transit':
        return 'جاري التوصيل';
      case 'delivered':
        return 'تم التوصيل بنجاح';
      case 'cancelled':
        return 'تم إلغاء الطلب';
      default:
        return status;
    }
  }

  String get packageSizeText {
    switch (packageSize) {
      case 'small':
        return 'صغير (مغلف/أوراق)';
      case 'medium':
        return 'متوسط (حقيبة/صندوق)';
      case 'large':
        return 'كبير (أثاث/كرتونة)';
      default:
        return packageSize;
    }
  }

  double get weightKg => 1.0;

  static String formatDistance(double km) {
    if (km <= 0) return '0 متر';
    if (km < 1.0) {
      final meters = (km * 1000).round();
      return '$meters متر';
    }
    return '${km.toStringAsFixed(1)} كم';
  }
}

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String type;
  final String body;
  final String? imageUrl;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    required this.body,
    this.imageUrl,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        conversationId: json['conversationId'] as String,
        senderId: json['senderId'] as String,
        type: json['type'] as String? ?? 'text',
        body: json['body'] as String? ?? '',
        imageUrl: json['imageUrl'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

class Conversation {
  final String id;
  final String orderId;
  final String orderNumber;
  final String? otherName;
  final String customerId;
  final String? captainId;
  final Message? lastMessage;
  final List<Message> messages;

  const Conversation({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    this.otherName,
    required this.customerId,
    this.captainId,
    this.lastMessage,
    this.messages = const [],
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final msgs = (json['messages'] as List<dynamic>? ?? [])
        .map((m) => Message.fromJson({
              ...(m as Map<String, dynamic>),
              'conversationId': json['id'],
            }))
        .toList();
    return Conversation(
      id: json['id'] as String,
      orderId: json['orderId'] as String,
      orderNumber: (json['order'] as Map<String, dynamic>?)?['orderNumber'] as String? ?? '',
      otherName: (json['otherUser'] as Map<String, dynamic>?)?['firstName'] as String?,
      customerId: json['customerId'] as String,
      captainId: json['captainId'] as String?,
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson({
              ...(json['lastMessage'] as Map<String, dynamic>),
              'conversationId': json['id'],
            })
          : null,
      messages: msgs,
    );
  }
}

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        isRead: json['isRead'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'body': body,
        'isRead': isRead,
        'createdAt': createdAt.toIso8601String(),
      };
}

User? userFromJson(String source) {
  try {
    return User.fromJson(jsonDecode(source) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

class CaptainOffer {
  final String id;
  final String orderId;
  final String captainId;
  final double price;
  final int estimatedTimeMinutes;
  final String? message;
  final String status;
  final bool isDirectRequest;
  final String? conversationId;
  final String? captainName;
  final String? captainAvatar;
  final double rating;
  final int totalDeliveries;
  final String transportType;
  final DateTime createdAt;

  const CaptainOffer({
    required this.id,
    required this.orderId,
    required this.captainId,
    required this.price,
    this.estimatedTimeMinutes = 30,
    this.message,
    required this.status,
    this.isDirectRequest = false,
    this.conversationId,
    this.captainName,
    this.captainAvatar,
    this.rating = 5.0,
    this.totalDeliveries = 0,
    this.transportType = 'car',
    required this.createdAt,
  });

  factory CaptainOffer.fromJson(Map<String, dynamic> json) {
    final captain = json['captain'] as Map<String, dynamic>?;
    return CaptainOffer(
      id: json['id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      captainId: json['captainId']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      estimatedTimeMinutes: (json['estimatedTimeMinutes'] as num?)?.toInt() ?? 30,
      message: json['message']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      isDirectRequest: json['isDirectRequest'] as bool? ?? false,
      conversationId: json['conversationId']?.toString(),
      captainName: captain != null
          ? '${captain['firstName'] ?? ''} ${captain['lastName'] ?? ''}'.trim()
          : null,
      captainAvatar: captain?['avatarUrl']?.toString(),
      rating: (captain?['rating'] as num?)?.toDouble() ?? 5.0,
      totalDeliveries: (captain?['totalDeliveries'] as num?)?.toInt() ?? 0,
      transportType: captain?['transportType']?.toString() ?? 'car',
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

class PublicCaptainProfile {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final double rating;
  final int totalDeliveries;
  final String transportType;
  final String? city;
  final String? bio;
  final bool isAvailable;
  final double? distanceKm;

  const PublicCaptainProfile({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.rating = 5.0,
    this.totalDeliveries = 0,
    this.transportType = 'car',
    this.city,
    this.bio,
    this.isAvailable = true,
    this.distanceKm,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory PublicCaptainProfile.fromJson(Map<String, dynamic> json) {
    return PublicCaptainProfile(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['id']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? 'كابتن',
      lastName: json['lastName']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      totalDeliveries: (json['totalDeliveries'] as num?)?.toInt() ?? 0,
      transportType: json['transportType']?.toString() ?? 'car',
      city: json['city']?.toString(),
      bio: json['bio']?.toString(),
      isAvailable: json['isAvailable'] as bool? ?? true,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
    );
  }
}