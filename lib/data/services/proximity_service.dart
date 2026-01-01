// Kinnect - Proximity Spark Service (Kıvılcım Modu)
// BLE ile yakındaki Kinnect kullanıcılarını algılama

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibration/vibration.dart';

/// Kıvılcım Modu - Yakındaki Kinnect kullanıcılarını BLE ile algılar
class ProximityService {
  static final ProximityService _instance = ProximityService._internal();
  factory ProximityService() => _instance;
  ProximityService._internal();

  // Supabase client
  final SupabaseClient _supabase = Supabase.instance.client;

  // Native BLE Advertiser channel (iOS)
  static const _bleChannel = MethodChannel('com.kinnect.ble_advertiser');

  // Kinnect UUID - Tüm Kinnect cihazları bu UUID'yi yayınlar
  static const String kinnectServiceUuid =
      "0000FE01-0000-1000-8000-00805F9B34FB";

  // State
  bool _isSparkModeEnabled = false;
  bool _isScanning = false;
  Timer? _scanTimer;
  Timer? _cleanupTimer;
  String? _myDeviceToken; // Bu cihazın unique token'ı

  // Algılanan kullanıcılar
  final Map<String, ProximityUser> _nearbyUsers = {};
  final _nearbyUsersController =
      StreamController<List<ProximityUser>>.broadcast();

  // Callbacks
  Stream<List<ProximityUser>> get nearbyUsersStream =>
      _nearbyUsersController.stream;
  List<ProximityUser> get nearbyUsers => _nearbyUsers.values.toList();
  bool get isSparkModeEnabled => _isSparkModeEnabled;
  String? get myDeviceToken => _myDeviceToken;

  /// Kıvılcım Modunu aç/kapat
  Future<void> toggleSparkMode() async {
    if (_isSparkModeEnabled) {
      await stopSparkMode();
    } else {
      await startSparkMode();
    }
  }

  /// Kıvılcım Modunu başlat
  Future<bool> startSparkMode() async {
    try {
      // Kullanıcı giriş yapmış mı?
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print("❌ Kullanıcı giriş yapmamış");
        return false;
      }

      // Bluetooth durumunu kontrol et
      if (await FlutterBluePlus.isSupported == false) {
        print("❌ Bluetooth desteklenmiyor");
        return false;
      }

      // Bluetooth açık mı kontrol et
      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        print("⚠️ Bluetooth kapalı, açılması gerekiyor");
        return false;
      }

      // Supabase'e cihazı kaydet ve token al
      _myDeviceToken = await _registerDevice(userId);
      if (_myDeviceToken == null) {
        print("❌ Device token alınamadı");
        return false;
      }

      _isSparkModeEnabled = true;

      // iOS'ta native advertising başlat
      if (Platform.isIOS) {
        await _startNativeAdvertising(_myDeviceToken!);
      }

      // Taramayı başlat
      await _startScanning();

      // Eski kullanıcıları temizleme timer'ı
      _cleanupTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        _cleanupStaleUsers();
      });

      print("🔥 Kıvılcım Modu aktif! Token: $_myDeviceToken");
      return true;
    } catch (e) {
      print("❌ Kıvılcım Modu başlatılamadı: $e");
      return false;
    }
  }

  /// Kıvılcım Modunu durdur
  Future<void> stopSparkMode() async {
    _isSparkModeEnabled = false;
    _scanTimer?.cancel();
    _cleanupTimer?.cancel();

    await FlutterBluePlus.stopScan();
    _isScanning = false;

    // iOS'ta native advertising durdur
    if (Platform.isIOS) {
      await _stopNativeAdvertising();
    }

    // Supabase'de deaktive et
    await _deactivateDevice();

    _nearbyUsers.clear();
    _nearbyUsersController.add([]);

    print("💤 Kıvılcım Modu kapatıldı");
  }

  /// iOS Native BLE Advertising başlat
  Future<void> _startNativeAdvertising(String token) async {
    try {
      await _bleChannel
          .invokeMethod('startAdvertising', {'deviceToken': token});
      print("📡 Native BLE advertising başlatıldı: $token");
    } catch (e) {
      print("⚠️ Native advertising hatası: $e");
    }
  }

  /// iOS Native BLE Advertising durdur
  Future<void> _stopNativeAdvertising() async {
    try {
      await _bleChannel.invokeMethod('stopAdvertising');
      print("🔇 Native BLE advertising durduruldu");
    } catch (e) {
      print("⚠️ Native advertising stop hatası: $e");
    }
  }

  /// Supabase'e cihazı kaydet ve token al
  Future<String?> _registerDevice(String userId) async {
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';

      final response = await _supabase.rpc(
        'register_spark_device',
        params: {
          'p_user_id': userId,
          'p_platform': platform,
        },
      );

      if (response != null) {
        print("✅ Device token alındı: $response");
        return response.toString();
      }
      return null;
    } catch (e) {
      print("❌ Device kayıt hatası: $e");

      // Fallback: Local token oluştur
      final localToken = _generateLocalToken();
      print("⚠️ Local token kullanılıyor: $localToken");
      return localToken;
    }
  }

  /// Local token oluştur (fallback)
  String _generateLocalToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Supabase'de cihazı deaktive et
  Future<void> _deactivateDevice() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase.rpc(
          'deactivate_spark_device',
          params: {'p_user_id': userId},
        );
        print("✅ Device deaktive edildi");
      }
    } catch (e) {
      print("⚠️ Device deaktif hatası: $e");
    }
  }

  /// BLE Tarama başlat - Çevredeki Kinnect cihazlarını ara
  Future<void> _startScanning() async {
    if (_isScanning) return;
    _isScanning = true;

    // Periyodik tarama (pil tasarrufu için 20 saniyede bir)
    _scanTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (_isSparkModeEnabled) {
        await _performScan();
      }
    });

    // İlk taramayı hemen yap
    await _performScan();
  }

  /// Tek bir tarama gerçekleştir
  Future<void> _performScan() async {
    if (!_isSparkModeEnabled) return;

    print("🔍 Çevrede Kinnect kullanıcıları aranıyor...");

    try {
      // Scan listener'ı kur
      final subscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          _processDevice(result);
        }
      });

      // 5 saniye boyunca tara
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 5),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      await Future.delayed(const Duration(seconds: 5));
      await subscription.cancel();
    } catch (e) {
      print("❌ Tarama hatası: $e");
    }
  }

  /// Bulunan cihazı işle
  void _processDevice(ScanResult result) {
    final deviceId = result.device.remoteId.str;
    final rssi = result.rssi;
    final distance = _calculateDistance(rssi);
    final localName = result.advertisementData.advName;

    // 🔥 SADECE Kinnect cihazlarını kabul et (KINNECT_ prefix'i olan)
    if (!localName.startsWith('KINNECT_')) {
      return; // Kinnect cihazı değilse atla
    }

    // Sadece yakın cihazları (15 metre içinde) dikkate al
    if (distance <= 15.0 && distance > 0) {
      // Token'ı local name'den çıkar
      final extractedToken = localName.substring(8); // "KINNECT_" sonrası

      final isNew = !_nearbyUsers.containsKey(deviceId);

      // Mevcut kullanıcı bilgilerini koru (Supabase'den geldiyse)
      final existingUser = _nearbyUsers[deviceId];
      final preservedUserId = existingUser?.userId;
      final preservedUsername = existingUser?.username;
      final preservedFullName = existingUser?.fullName;
      final preservedAvatarUrl = existingUser?.avatarUrl;

      _nearbyUsers[deviceId] = ProximityUser(
        deviceId: deviceId,
        deviceToken: extractedToken,
        rssi: rssi,
        distance: distance,
        lastSeen: DateTime.now(),
        // Eğer daha önce Supabase'den bilgi aldıysak onu koru
        userId: preservedUserId,
        username: preservedUsername ??
            "Spark #${extractedToken.substring(0, 4).toUpperCase()}",
        fullName: preservedFullName,
        avatarUrl: preservedAvatarUrl,
      );

      // Yeni bir Kinnect kullanıcı algılandıysa
      if (isNew) {
        print("🔥 KINNECT KULLANICI BULUNDU! Token: $extractedToken");
        _triggerSparkEffect();

        // Supabase'den kullanıcı bilgisi al
        _lookupUserByToken(deviceId, extractedToken);
      }

      _nearbyUsersController.add(nearbyUsers);
    }
  }

  /// Token'a göre kullanıcı bilgisi al
  Future<void> _lookupUserByToken(String deviceId, String token) async {
    try {
      print("🔍 Token için kullanıcı aranıyor: $token");

      // 1. Önce spark_devices'dan user_id al
      final deviceData = await _supabase
          .from('spark_devices')
          .select('user_id')
          .eq('device_token', token)
          .eq('is_active', true)
          .maybeSingle();

      if (deviceData == null || deviceData['user_id'] == null) {
        print("⚠️ Token için aktif cihaz bulunamadı: $token");
        return;
      }

      final userId = deviceData['user_id'] as String;
      print("✅ User ID bulundu: $userId");

      // 2. Sonra profiles'dan kullanıcı bilgisi al
      final profileData = await _supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      if (profileData != null && _nearbyUsers.containsKey(deviceId)) {
        final username = profileData['username'] as String?;
        final fullName = profileData['full_name'] as String?;
        final avatarUrl = profileData['avatar_url'] as String?;

        print("🎉 Profil bulundu: $username ($fullName)");

        _nearbyUsers[deviceId] = ProximityUser(
          deviceId: deviceId,
          deviceToken: token,
          rssi: _nearbyUsers[deviceId]!.rssi,
          distance: _nearbyUsers[deviceId]!.distance,
          lastSeen: DateTime.now(),
          userId: userId,
          username: username ??
              fullName ??
              "Spark #${token.substring(0, 4).toUpperCase()}",
          fullName: fullName,
          avatarUrl: avatarUrl,
        );

        _nearbyUsersController.add(nearbyUsers);
      } else {
        print("⚠️ Profil bulunamadı: $userId");
      }
    } catch (e) {
      print("⚠️ Kullanıcı lookup hatası: $e");
    }
  }

  /// RSSI değerinden mesafe hesapla (metre)
  double _calculateDistance(int rssi) {
    // Log-distance path loss modeli
    const int measuredPower = -59; // 1m'deki kalibrasyon değeri
    const double n = 2.5; // Çevresel faktör

    if (rssi == 0) return -1.0;

    final ratio = (measuredPower - rssi) / (10 * n);
    return pow(10, ratio).toDouble();
  }

  /// Odun çıtırtısı haptic efekti 🔥
  Future<void> _triggerSparkEffect() async {
    print("✨ KIVILCIM! Yakında biri var!");

    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != true) {
      // Vibration yoksa system haptic kullan
      for (int i = 0; i < 5; i++) {
        HapticFeedback.lightImpact();
        await Future.delayed(Duration(milliseconds: Random().nextInt(50) + 10));
      }
      return;
    }

    // Odun çıtırtısı efekti - rastgele aralıklı kısa titreşimler
    final random = Random();
    for (int i = 0; i < 6; i++) {
      final duration = random.nextInt(30) + 10; // 10-40ms
      final pause = random.nextInt(60) + 20; // 20-80ms

      Vibration.vibrate(
          duration: duration, amplitude: random.nextInt(128) + 127);
      await Future.delayed(Duration(milliseconds: pause));
    }
  }

  /// Eski kullanıcıları temizle (30 saniyeden fazla görülmeyenler)
  void _cleanupStaleUsers() {
    final now = DateTime.now();
    final staleCount = _nearbyUsers.values
        .where((u) => now.difference(u.lastSeen).inSeconds > 30)
        .length;

    if (staleCount > 0) {
      _nearbyUsers.removeWhere((key, user) {
        return now.difference(user.lastSeen).inSeconds > 30;
      });
      _nearbyUsersController.add(nearbyUsers);
      print("🧹 $staleCount eski cihaz temizlendi");
    }
  }

  /// Cleanup
  void dispose() {
    stopSparkMode();
    _nearbyUsersController.close();
  }
}

/// Yakındaki kullanıcı modeli
class ProximityUser {
  final String deviceId;
  final String? deviceToken;
  final int rssi;
  final double distance;
  final DateTime lastSeen;

  // Supabase'den çekilen bilgiler
  final String? userId;
  final String? username;
  final String? avatarUrl;
  final String? fullName;

  ProximityUser({
    required this.deviceId,
    this.deviceToken,
    required this.rssi,
    required this.distance,
    required this.lastSeen,
    this.userId,
    this.username,
    this.avatarUrl,
    this.fullName,
  });

  /// Supabase'den kullanıcı bilgisi alındı mı?
  bool get isKinnectUser => userId != null;

  /// Mesafe açıklaması
  String get distanceText {
    if (distance < 1) return "Çok yakın";
    if (distance < 3) return "Yakında";
    if (distance < 5) return "Orta mesafe";
    if (distance < 10) return "Uzakta";
    return "Çok uzakta";
  }

  @override
  String toString() =>
      'ProximityUser(device: $deviceId, token: $deviceToken, user: $username, distance: ${distance.toStringAsFixed(1)}m)';
}
