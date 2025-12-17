import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🔔 Push Notification Service
/// Firebase Cloud Messaging ile push bildirim yönetimi
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  /// Firebase başlatma ve izin isteme
  Future<void> initialize() async {
    try {
      // İzin iste
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('🔔 Bildirim izni: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // FCM Token al
        await _getToken();

        // Token yenilendiğinde
        _messaging.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          _saveTokenToDatabase(newToken);
          debugPrint('🔄 FCM Token yenilendi: $newToken');
        });

        // Foreground mesajları dinle
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Background/Terminated mesajları dinle
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        // Uygulama kapalıyken gelen mesaj ile açıldıysa
        RemoteMessage? initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageOpenedApp(initialMessage);
        }
      }
    } catch (e) {
      debugPrint('❌ Notification initialize hatası: $e');
    }
  }

  /// FCM Token al
  Future<void> _getToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('🔑 FCM Token: $_fcmToken');

      if (_fcmToken != null) {
        await _saveTokenToDatabase(_fcmToken!);
      }
    } catch (e) {
      debugPrint('❌ Token alma hatası: $e');
    }
  }

  /// Token'ı veritabanına kaydet
  Future<void> _saveTokenToDatabase(String token) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Supabase'e token kaydet
      await Supabase.instance.client.from('profiles').update({
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      debugPrint('✅ FCM Token veritabanına kaydedildi');
    } catch (e) {
      debugPrint('❌ Token kaydetme hatası: $e');
    }
  }

  /// Uygulama açıkken gelen mesaj
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📩 Foreground mesaj alındı:');
    debugPrint('   Başlık: ${message.notification?.title}');
    debugPrint('   İçerik: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');

    // Burada in-app bildirim gösterebilirsin
    // Örn: SnackBar, overlay, vs.
  }

  /// Bildirime tıklanınca
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('🔔 Bildirime tıklandı:');
    debugPrint('   Data: ${message.data}');

    // Burada navigasyon yapabilirsin
    // Örn: Mesaj ekranına git, post detayına git vs.
    final type = message.data['type'];
    final targetId = message.data['target_id'];

    if (type == 'message') {
      // Mesaj ekranına yönlendir
      debugPrint('💬 Mesaj ekranına git: $targetId');
    } else if (type == 'like') {
      // Post detayına yönlendir
      debugPrint('❤️ Post detayına git: $targetId');
    } else if (type == 'follow') {
      // Profile yönlendir
      debugPrint('👤 Profile git: $targetId');
    }
  }

  /// Belirli bir kullanıcıya bildirim gönder (Supabase Edge Function ile)
  Future<void> sendNotificationToUser({
    required String targetUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Supabase Edge Function çağır
      await Supabase.instance.client.functions.invoke(
        'send-push-notification',
        body: {
          'target_user_id': targetUserId,
          'title': title,
          'body': body,
          'data': data ?? {},
        },
      );
      debugPrint('✅ Bildirim gönderildi: $targetUserId');
    } catch (e) {
      debugPrint('❌ Bildirim gönderme hatası: $e');
    }
  }

  /// Token'ı sil (logout için)
  Future<void> deleteToken() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client.from('profiles').update({
          'fcm_token': null,
        }).eq('id', userId);
      }
      await _messaging.deleteToken();
      _fcmToken = null;
      debugPrint('🗑️ FCM Token silindi');
    } catch (e) {
      debugPrint('❌ Token silme hatası: $e');
    }
  }
}
