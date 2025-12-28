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
            else if call.method == "requestAppleMusicPermission" {
                MPMediaLibrary.requestAuthorization { status in
                    let isGranted = (status == .authorized)
                    result(isGranted)
                }
            }
            else {
                result(FlutterMethodNotImplemented)
            }
        })

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Şarkı bilgisini çeken fonksiyon
    private func getNowPlaying(result: FlutterResult) {
        // Önce izin durumunu kontrol et
        let authStatus = MPMediaLibrary.authorizationStatus()
        print("🍎 Apple Music Auth Status: \(authStatus.rawValue)")
        
        if authStatus != .authorized {
            print("❌ Apple Music izni yok!")
            result(nil)
            return
        }
        
        // systemMusicPlayer'dan şarkı bilgisi al
        let systemPlayer = MPMusicPlayerController.systemMusicPlayer
        let isPlaying = systemPlayer.playbackState == .playing
        
        print("🎵 systemMusicPlayer - isPlaying: \(isPlaying), item: \(systemPlayer.nowPlayingItem?.title ?? "NIL")")
        
        if let nowPlayingItem = systemPlayer.nowPlayingItem {
            let songName = nowPlayingItem.title ?? ""
            let artistName = nowPlayingItem.artist ?? ""
            let storeId = nowPlayingItem.playbackStoreID
            
            print("✅ Track found: \(songName) - \(artistName) (storeId: \(storeId))")

            let trackInfo: [String: Any] = [
                "name": songName,
                "artist": artistName,
                "storeId": storeId,
                "is_playing": isPlaying
            ]
            result(trackInfo)
            return
        }
        
        // systemMusicPlayer çalışmadıysa applicationMusicPlayer dene
        let appPlayer = MPMusicPlayerController.applicationMusicPlayer
        let appIsPlaying = appPlayer.playbackState == .playing
        
        print("🎵 applicationMusicPlayer - isPlaying: \(appIsPlaying), item: \(appPlayer.nowPlayingItem?.title ?? "NIL")")
        
        if let nowPlayingItem = appPlayer.nowPlayingItem {
            let songName = nowPlayingItem.title ?? ""
            let artistName = nowPlayingItem.artist ?? ""
            let storeId = nowPlayingItem.playbackStoreID
            
            print("✅ Track found from appPlayer: \(songName) - \(artistName)")

            let trackInfo: [String: Any] = [
                "name": songName,
                "artist": artistName,
                "storeId": storeId,
                "is_playing": appIsPlaying
            ]
            result(trackInfo)
            return
        }
        
        // Hala nil ise MPNowPlayingInfoCenter dene (diğer uygulamalar için)
        let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo
        print("🎵 MPNowPlayingInfoCenter: \(nowPlayingInfo ?? [:])")
        
        if let info = nowPlayingInfo,
           let title = info[MPMediaItemPropertyTitle] as? String {
            let artist = info[MPMediaItemPropertyArtist] as? String ?? ""
            
            print("✅ NowPlayingInfoCenter Track: \(title) - \(artist)")
            
            let trackInfo: [String: Any] = [
                "name": title,
                "artist": artist,
                "storeId": "0",
                "is_playing": true
            ]
            result(trackInfo)
            return
        }
        
        print("❌ No music found from any source")
        result(nil)
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