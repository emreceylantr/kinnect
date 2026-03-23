import UIKit
import Flutter
import MediaPlayer // Müzik çalar erişimi için şart
import FirebaseCore
import FirebaseMessaging
import CoreBluetooth // BLE Spark Mode için

// MARK: - BLE Advertiser (Spark Mode)
class BLEAdvertiser: NSObject, CBPeripheralManagerDelegate {
    private var peripheralManager: CBPeripheralManager?
    private var deviceToken: String?
    var isAdvertising = false
    
    private let kinnectServiceUUID = CBUUID(string: "0000FE01-0000-1000-8000-00805F9B34FB")
    
    static let shared = BLEAdvertiser()
    
    private override init() {
        super.init()
    }
    
    func startAdvertising(deviceToken: String) {
        self.deviceToken = deviceToken
        if peripheralManager == nil {
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        } else {
            beginAdvertising()
        }
    }
    
    func stopAdvertising() {
        peripheralManager?.stopAdvertising()
        isAdvertising = false
        print("🔇 BLE Advertising stopped")
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            print("✅ Bluetooth powered on")
            beginAdvertising()
        } else {
            isAdvertising = false
        }
    }
    
    private func beginAdvertising() {
        guard let token = deviceToken, !isAdvertising else { return }
        guard peripheralManager?.state == .poweredOn else { return }
        
        let localName = "KINNECT_\(token)"
        let advertisementData: [String: Any] = [
            CBAdvertisementDataLocalNameKey: localName,
            CBAdvertisementDataServiceUUIDsKey: [kinnectServiceUUID]
        ]
        
        peripheralManager?.startAdvertising(advertisementData)
        isAdvertising = true
        print("📡 BLE Advertising started: \(localName)")
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("❌ Advertising error: \(error.localizedDescription)")
        } else {
            print("✅ Advertising started successfully")
        }
    }
}

// MARK: - BLE Advertiser Flutter Plugin
class BLEAdvertiserPlugin: NSObject {
    static let shared = BLEAdvertiserPlugin()
    private let channelName = "com.kinnect.ble_advertiser"
    
    private override init() {
        super.init()
    }
    
    func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] (call, result) in
            self?.handle(call, result: result)
        }
    }
    
    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startAdvertising":
            if let args = call.arguments as? [String: Any],
               let token = args["deviceToken"] as? String {
                BLEAdvertiser.shared.startAdvertising(deviceToken: token)
                result(true)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "deviceToken required", details: nil))
            }
        case "stopAdvertising":
            BLEAdvertiser.shared.stopAdvertising()
            result(true)
        case "isAdvertising":
            result(BLEAdvertiser.shared.isAdvertising)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - AppDelegate
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
            else if call.method == "getTopAppleMusicTracks" {
                self.getTopTracks(result: result)
            }
            else {
                result(FlutterMethodNotImplemented)
            }
        })
        
        // 🔥 BLE Advertiser Plugin kaydet (Spark Mode için)
        BLEAdvertiserPlugin.shared.register(with: controller.binaryMessenger)

        // 🎬 Video Trimmer Plugin kaydet
        VideoTrimmerPlugin.shared.register(with: controller.binaryMessenger)

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Şarkı bilgisini çeken fonksiyon
    private func getNowPlaying(result: FlutterResult) {
        let authStatus = MPMediaLibrary.authorizationStatus()
        
        if authStatus != .authorized {
            result(nil)
            return
        }
        
        let systemPlayer = MPMusicPlayerController.systemMusicPlayer
        let isPlaying = systemPlayer.playbackState == .playing
        
        if let nowPlayingItem = systemPlayer.nowPlayingItem {
            let trackInfo: [String: Any] = [
                "name": nowPlayingItem.title ?? "",
                "artist": nowPlayingItem.artist ?? "",
                "storeId": nowPlayingItem.playbackStoreID,
                "is_playing": isPlaying
            ]
            result(trackInfo)
            return
        }
        
        let appPlayer = MPMusicPlayerController.applicationMusicPlayer
        if let nowPlayingItem = appPlayer.nowPlayingItem {
            let trackInfo: [String: Any] = [
                "name": nowPlayingItem.title ?? "",
                "artist": nowPlayingItem.artist ?? "",
                "storeId": nowPlayingItem.playbackStoreID,
                "is_playing": appPlayer.playbackState == .playing
            ]
            result(trackInfo)
            return
        }
        
        if let info = MPNowPlayingInfoCenter.default().nowPlayingInfo,
           let title = info[MPMediaItemPropertyTitle] as? String {
            let trackInfo: [String: Any] = [
                "name": title,
                "artist": info[MPMediaItemPropertyArtist] as? String ?? "",
                "storeId": "0",
                "is_playing": true
            ]
            result(trackInfo)
            return
        }
        
        result(nil)
    }
    
    // En çok çalınan şarkıları döndür
    private func getTopTracks(result: FlutterResult) {
        let authStatus = MPMediaLibrary.authorizationStatus()
        guard authStatus == .authorized else {
            result([])
            return
        }

        var tracks: [[String: Any]] = []
        let seen = NSMutableSet()

        // 1. Şu an çalan / son çalınan (her zaman önce ekle)
        let players = [
            MPMusicPlayerController.systemMusicPlayer,
            MPMusicPlayerController.applicationMusicPlayer
        ]
        for player in players {
            if let item = player.nowPlayingItem,
               let title = item.title, !title.isEmpty,
               let artist = item.artist, !artist.isEmpty {
                let key = "\(artist)|\(title)"
                if !seen.contains(key) {
                    seen.add(key)
                    tracks.append(["track": title, "artist": artist, "playCount": 999])
                }
            }
        }

        // 2. Kütüphanedeki şarkılar (play count sıralı)
        let query = MPMediaQuery.songs()
        let items = (query.items ?? []).sorted { $0.playCount > $1.playCount }
        for item in items.prefix(50) {
            let title = item.title ?? ""
            let artist = item.artist ?? ""
            guard !title.isEmpty, !artist.isEmpty else { continue }
            let key = "\(artist)|\(title)"
            if !seen.contains(key) {
                seen.add(key)
                tracks.append(["track": title, "artist": artist, "playCount": item.playCount])
            }
        }

        // 3. NowPlayingInfo (Media Center üzerinden çalanlar — AirPlay vs)
        if let info = MPNowPlayingInfoCenter.default().nowPlayingInfo,
           let title = info[MPMediaItemPropertyTitle] as? String, !title.isEmpty,
           let artist = info[MPMediaItemPropertyArtist] as? String, !artist.isEmpty {
            let key = "\(artist)|\(title)"
            if !seen.contains(key) {
                seen.add(key)
                tracks.append(["track": title, "artist": artist, "playCount": 999])
            }
        }

        result(Array(tracks.prefix(30)))
    }

    // FCM Token alındığında
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM Token: \(fcmToken ?? "nil")")
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