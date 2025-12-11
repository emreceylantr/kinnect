import UIKit
import Flutter
import MediaPlayer // 🔥 Bu kütüphane şart!

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
          self.getCurrentMediaItem(result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Anlık çalan şarkıyı sistemden çeken fonksiyon
  private func getCurrentMediaItem(result: FlutterResult) {
      let musicPlayer = MPMusicPlayerController.systemMusicPlayer
      if let nowPlaying = musicPlayer.nowPlayingItem {
          // Şarkı bilgilerini al
          let title = nowPlaying.title ?? ""
          let artist = nowPlaying.artist ?? ""
          let album = nowPlaying.albumTitle ?? ""
          // Store ID (iTunes ID'si) varsa işimiz çok kolaylaşır
          let storeId = nowPlaying.playbackStoreID

          let songInfo: [String: Any] = [
              "name": title,
              "artist": artist,
              "album": album,
              "storeId": storeId
          ]
          result(songInfo)
      } else {
          result(nil) // Şarkı çalmıyor
      }
  }
}