import UIKit
import Flutter
import MediaPlayer // Müzik çalar erişimi için şart
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // Firebase başlat
        FirebaseApp.configure()
        
        // Push Notification ayarları
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        // Push izni iste
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            print("Push notification izni: \(granted)")
        }
        application.registerForRemoteNotifications()
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let musicChannel = FlutterMethodChannel(name: "com.kinnect.app/music",
                                                binaryMessenger: controller.binaryMessenger)

        musicChannel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in

            if call.method == "getAppleMusicTrack" {
                self.getNowPlaying(result: result)
            }
            // ▼▼▼▼ GÜNCELLEME BURADA: İZİN İSTEME FONKSİYONU EKLENDİ ▼▼▼▼
            else if call.method == "requestAppleMusicPermission" {
                // Bu kod çalıştığında ekrana o "İzin Ver" kutusu ZORLA çıkar
                MPMediaLibrary.requestAuthorization { status in
                    // Kullanıcı izin verdi mi? (authorized = true)
                    let isGranted = (status == .authorized)
                    result(isGranted)
                }
            }
            // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
            else {
                result(FlutterMethodNotImplemented)
            }
        })

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Şarkı bilgisini çeken fonksiyon
    private func getNowPlaying(result: FlutterResult) {
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer

        // Şarkı çalıyor mu?
        let isPlaying = musicPlayer.playbackState == .playing

        if let nowPlayingItem = musicPlayer.nowPlayingItem {
            let songName = nowPlayingItem.title ?? ""
            let artistName = nowPlayingItem.artist ?? ""
            let storeId = nowPlayingItem.playbackStoreID // iTunes Store ID'si

            let trackInfo: [String: Any] = [
                "name": songName,
                "artist": artistName,
                "storeId": storeId,
                "is_playing": isPlaying
            ]
            result(trackInfo)
        } else {
            // Hiçbir şey çalmıyorsa boş dönelim
            result(nil)
        }
    }
    
    // FCM Token alındığında
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM Token: \(fcmToken ?? "nil")")
        // Token'ı Flutter tarafına gönder
        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: dataDict
        )
    }
    
    // APNs token alındığında
    override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }
}