import UIKit
import Flutter
import MediaPlayer // Müzik çalar erişimi için şart

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

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
}