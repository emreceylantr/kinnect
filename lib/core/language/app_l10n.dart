import 'language_manager.dart';

/// Uygulama çevirileri — TR / EN
/// Kullanım: AppL10n.home → 'Ana Akış' veya 'Home Feed'
class AppL10n {
  static bool get _en =>
      LanguageManager().localeNotifier.value.languageCode == 'en';

  static String get currentLanguageCode =>
      LanguageManager().localeNotifier.value.languageCode;

  // ── GENEL ──
  static String get ok => _en ? 'OK' : 'Tamam';
  static String get cancel => _en ? 'Cancel' : 'İptal';
  static String get save => _en ? 'Save' : 'Kaydet';
  static String get delete => _en ? 'Delete' : 'Sil';
  static String get confirm => _en ? 'Confirm' : 'Onayla';
  static String get yes => _en ? 'Yes' : 'Evet';
  static String get no => _en ? 'No' : 'Hayır';
  static String get loading => _en ? 'Loading...' : 'Yükleniyor...';
  static String get error => _en ? 'Error' : 'Hata';
  static String get retry => _en ? 'Retry' : 'Tekrar dene';
  static String get close => _en ? 'Close' : 'Kapat';
  static String get done => _en ? 'Done' : 'Bitti';
  static String get edit => _en ? 'Edit' : 'Düzenle';
  static String get share => _en ? 'Share' : 'Paylaş';
  static String get report => _en ? 'Report' : 'Şikayet Et';
  static String get block => _en ? 'Block' : 'Engelle';
  static String get unblock => _en ? 'Unblock' : 'Engeli Kaldır';
  static String get someone => _en ? 'Someone' : 'Birisi';
  static String get user => _en ? 'User' : 'Kullanıcı';
  static String get noResults => _en ? 'No results found' : 'Sonuç bulunamadı';
  static String get add => _en ? 'Add' : 'Ekle';
  static String get leave => _en ? 'Leave' : 'Ayrıl';
  static String get kick => _en ? 'Remove' : 'At';
  static String get show => _en ? 'Show' : 'Göster';
  static String get showAll => _en ? 'Show All' : 'Tümünü Göster';
  static String get hide => _en ? 'Hide' : 'Gizle';
  static String get updated => _en ? 'Updated!' : 'Güncellendi!';
  static String get uploading => _en ? 'Uploading cover...' : 'Kapak yükleniyor...';
  static String get continueLabel => _en ? 'Continue' : 'Devam et';

  // ── ANA SAYFA ──
  static String get homeFeed => _en ? 'Home Feed' : 'Ana Akış';
  static String get explore => _en ? 'Explore' : 'Keşfet';
  static String get aiAssistant => _en ? 'AI Assistant' : 'AI Asistan';
  static String get myProfile => _en ? 'My Profile' : 'Profilim';
  static String get messages => _en ? 'Messages' : 'Mesajlar';
  static String get feedEmpty => _en ? 'Feed is empty.' : 'Akış boş.';
  static String get incomingVideoCall => _en ? 'Video Call' : 'Görüntülü Arama';
  static String get incomingVoiceCall => _en ? 'Voice Call' : 'Sesli Arama';
  static String get wantsToJoinRoom => _en ? 'Wants to join the chat room' : 'Sohbet odasına katılmak istiyor';
  static String get decline => _en ? 'Decline' : 'Reddet';
  static String get join => _en ? 'Join' : 'Katıl';
  static String get notifFollowRequest => _en ? 'wants to follow you.' : 'seni takip etmek istiyor.';
  static String get notifLikedPost => _en ? 'liked your post.' : 'gönderini beğendi.';
  static String get notifCommentedPost => _en ? 'commented.' : 'yorum yaptı.';
  static String get notifSentMessage => _en ? 'sent you a message 💬' : 'sana bir mesaj gönderdi 💬';

  // ── BİLDİRİMLER ──
  static String get notifications => _en ? 'Notifications' : 'Bildirimler';
  static String get noNotifications =>
      _en ? 'No notifications yet' : 'Henüz bildirim yok';
  static String get noNotificationsSubtitle =>
      _en ? 'New interactions will appear here' : 'Yeni etkileşimler burada görünecek';
  static String get followRequests =>
      _en ? 'Follow Requests' : 'Takip İstekleri';
  static String get today => _en ? 'TODAY' : 'BUGÜN';
  static String get thisWeek => _en ? 'THIS WEEK' : 'BU HAFTA';
  static String get earlier => _en ? 'EARLIER' : 'DAHA ÖNCE';
  static String get justNow => _en ? 'just now' : 'az önce';
  static String get justNowCap => _en ? 'Just now' : 'Az önce';
  static String timeMinShort(int m) => _en ? '${m}m' : '${m}dk';
  static String timeHourShort(int h) => _en ? '${h}h' : '${h}sa';
  static String timeDayShort(int d) => _en ? '${d}d' : '${d}g';
  static String timeWeekShort(int w) => _en ? '${w}w' : '${w}hf';
  static String timeMonthShort(int mo) => _en ? '${mo}mo' : '${mo}ay';
  static String timeMinLong(int m) => _en ? '$m min ago' : '$m dk önce';
  static String timeHourLong(int h) => _en ? '$h hr ago' : '$h sa önce';
  static String timeDayLong(int d) => _en ? '$d days ago' : '$d gün önce';
  static String timeWeekLong(int w) => _en ? '$w weeks ago' : '$w hafta önce';
  static String timeMonthLong(int mo) => _en ? '$mo months ago' : '$mo ay önce';
  static String andNMorePeople(int n) => _en ? 'and $n more' : 've $n kişi daha';
  static String wantsToFollow(String username) =>
      _en ? '$username wants to follow you' : '$username seni takip etmek istiyor';
  static String get newNotification => _en ? 'New notification' : 'Yeni bildirim';
  static String andNOthers(int n) => _en ? '$n and $n others' : '$n ve $n kişi daha';

  // Bildirim aksiyonları
  static String notifLiked(int count) => count == 1
      ? (_en ? 'liked your post' : 'Gönderini beğendi')
      : (_en ? 'and ${count - 1} others liked' : 've ${count - 1} kişi daha beğendi');
  static String notifCommented(int count) => count == 1
      ? (_en ? 'commented on your post' : 'Gönderin üzerine yorum yaptı')
      : (_en ? 'and ${count - 1} others commented' : 've ${count - 1} kişi daha yorum yaptı');
  static String notifFueled(int count) => count == 1
      ? (_en ? 'fueled your post 🔥' : 'Gönderini harladı 🔥')
      : (_en ? 'and ${count - 1} others fueled 🔥' : 've ${count - 1} kişi daha harladı 🔥');
  static String get notifFollowed =>
      _en ? 'started following you' : 'Seni takip etmeye başladı';
  static String get notifMessaged =>
      _en ? 'sent you a message' : 'Sana mesaj gönderdi';
  static String notifCalled(int count) => count == 1
      ? (_en ? 'tried to call you' : 'Seni aramaya çalıştı')
      : (_en ? 'called you $count times' : 'Seni $count kez aramaya çalıştı');

  // ── MESAJLAR ──
  static String get newMessage => _en ? 'New Message' : 'Yeni Mesaj';
  static String get typeMessage =>
      _en ? 'Type a message...' : 'Mesaj yaz...';
  static String get typeEphemeralMessage =>
      _en ? '🔥 Ephemeral message...' : '🔥 Kül olan mesaj...';
  static String get online => _en ? 'Online' : 'Çevrimiçi';
  static String minsAgo(int m) => _en ? '${m}m ago' : '$m dk önce';
  static String hoursAgo(int h) => _en ? '${h}h ago' : '$h sa önce';
  static String daysAgo(int d) => _en ? '${d}d ago' : '$d gün önce';
  static String get noChatYet => _en ? 'No chats yet' : 'Henüz sohbet yok';
  static String get meetSomeone => _en ? 'Match and meet someone!' : 'Eşleşip biriyle tanış!';
  static String get searchChat => _en ? 'Search chats...' : 'Sohbet ara...';
  static String get noFollowees => _en ? 'You don\'t follow anyone' : 'Takip ettiğin kimse yok';
  static String get newGroup => _en ? 'New Group' : 'Yeni Grup';
  static String get groupNameHint => _en ? 'Group name...' : 'Grup adı...';
  static String get addPeople => _en ? 'Add People' : 'Kişi Ekle';
  static String get createGroup => _en ? 'Create Group' : 'Grup Oluştur';
  static String createGroupWithCount(int n) =>
      _en ? 'Create Group ($n people)' : 'Grup Oluştur ($n kişi)';
  static String get enterGroupName => _en ? 'Enter a group name' : 'Grup adı gir';
  static String get selectAtLeastOne => _en ? 'Select at least 1 person' : 'En az 1 kişi seç';
  static String get greetingHello => _en ? 'Hello' : 'Merhaba';
  static String get privacySettings => _en ? 'Privacy Settings' : 'Gizlilik Ayarları';
  static String get lastSeen => _en ? 'Last Seen' : 'Son Görülme';
  static String get lastSeenVisibleSubtitle =>
      _en ? 'Everyone can see' : 'Herkes görebilir';
  static String get lastSeenHiddenSubtitle =>
      _en ? 'No one can see' : 'Hiç kimse göremez';
  static String get readReceipts => _en ? 'Read Receipts' : 'Okundu Bilgisi';
  static String get readReceiptsSharedSubtitle =>
      _en ? 'Read receipts are shared' : 'Okundu bilgisi paylaşılır';
  static String get readReceiptsHiddenSubtitle =>
      _en ? 'Blue tick hidden (mutual)' : 'Mavi tik gizlenir (karşılıklı)';
  static String get chatStarted =>
      _en ? 'Chat started!' : 'sohbet başladı!';
  static String get sendFirstMessage => _en ? 'Send the first message 👋' : 'İlk mesajı gönder 👋';
  static String get reply => _en ? 'Reply' : 'Yanıtla';
  static String get photo => _en ? '📷 Photo' : '📷 Fotoğraf';
  static String get voiceMessage => _en ? '🎤 Voice message' : '🎤 Ses mesajı';
  static String get camera => _en ? 'Camera' : 'Kamera';
  static String get gallery => _en ? 'Gallery' : 'Galeri';
  static String get deleteMessage => _en ? 'Delete Message' : 'Mesajı Sil';
  static String get deleteMessageConfirm =>
      _en ? 'This message will be permanently deleted. Continue?' : 'Bu mesaj kalıcı olarak silinecek. Devam etmek istiyor musun?';
  static String get messageDeleted => _en ? 'Message deleted' : 'Mesaj silindi';
  static String get postNotFound => _en ? 'Post not found or deleted.' : 'Gönderi bulunamadı veya silinmiş.';
  static String get you => _en ? 'You' : 'Sen';

  // ── PROFİL ──
  static String get follow => _en ? 'Follow' : 'Takip Et';
  static String get following => _en ? 'Following' : 'Takip Ediliyor';
  static String get requested => _en ? 'Requested' : 'İstek Gönderildi';
  static String get sendMessage => _en ? 'Message' : 'Mesaj Gönder';
  static String get editProfile => _en ? 'Edit Profile' : 'Profili Düzenle';
  static String get posts => _en ? 'Posts' : 'Gönderi';
  static String get followers => _en ? 'Followers' : 'Takipçi';
  static String get followingCount => _en ? 'Following' : 'Takip';
  static String get logout => _en ? 'Sign Out' : 'Çıkış Yap';
  static String get logoutConfirm =>
      _en ? 'Are you sure you want to sign out?' : 'Hesabından çıkmak istediğinden emin misin?';
  static String get userBlocked => _en ? 'User Blocked' : 'Kullanıcı Engellendi';
  static String get youBlockedThisUser =>
      _en ? 'You have blocked this user.' : 'Bu kullanıcıyı engelledin.';
  static String get thisAccountIsPrivate =>
      _en ? 'This account is private.' : 'Bu hesap gizli.';
  static String get noPostsYet => _en ? 'No posts yet' : 'Henüz gönderi yok';
  static String get noSharesYet => _en ? 'No shares yet' : 'Henüz paylaşım yok';
  static String get shareFirstPost => _en ? 'Share your first post!' : 'İlk gönderini paylaş!';
  static String get userHasNoPostsYet =>
      _en ? 'This user hasn\'t shared anything yet.' : 'Bu kullanıcı henüz bir şey paylaşmadı.';
  static String get dataLoading => _en ? 'Data is loading...' : 'Veriler yükleniyor...';
  static String get followListPrivate =>
      _en ? 'You must follow to see the list.' : 'Listeyi görmek için takip etmelisin.';
  static String get followersList => _en ? 'Followers' : 'Takipçiler';
  static String get followingList => _en ? 'Following' : 'Takip Edilenler';
  static String get unnamed => _en ? 'Unnamed' : 'İsimsiz';
  static String get reportUser => _en ? 'Report User' : 'Kullanıcıyı Şikayet Et';
  static String get reported => _en ? 'Reported.' : 'Şikayet edildi.';
  static String get blockUser => _en ? 'Block' : 'Engelle';
  static String get blockConfirm =>
      _en ? 'Are you sure you want to block this user?' : 'Bu kullanıcıyı engellemek istediğine emin misin?';
  static String get unblockConfirm =>
      _en ? 'Do you want to unblock?' : 'Engeli kaldırmak istiyor musun?';
  static String get coverUploading => _en ? 'Uploading cover...' : 'Kapak yükleniyor...';
  static String get coverUpdated => _en ? 'Updated!' : 'Güncellendi!';
  static String get spotifySyncing =>
      _en ? 'Syncing music history...' : 'Müzik geçmişi senkronize ediliyor...';
  static String get spotifyConnected =>
      _en ? 'Spotify connected — Update matches' : 'Spotify bağlı — Eşleşmeleri güncelle';
  static String get spotifyConnect => _en ? 'Connect Spotify' : 'Spotify\'ı Bağla';
  static String get spotifySubtitle =>
      _en ? 'Find better matches based on your music taste' : 'Müzik zevkine göre daha iyi eşleşmeler bul';
  static String get spotifySyncSuccess =>
      _en ? 'Spotify music history added to matches!' : 'Spotify müzik geçmişin eşleşmelere eklendi!';
  static String get spotifySyncFail =>
      _en ? 'Spotify sync failed, try again.' : 'Spotify sync başarısız, tekrar dene.';
  static String get appleMusicSyncing =>
      _en ? 'Syncing Apple Music...' : 'Apple Music senkronize ediliyor...';
  static String get appleMusicConnectedLabel =>
      _en ? 'Apple Music — Update matches' : 'Apple Music — Eşleşmeleri güncelle';
  static String get appleMusicConnect => _en ? 'Connect Apple Music' : 'Apple Music\'i Bağla';
  static String get appleMusicSubtitle =>
      _en ? 'Find matches based on listening habits' : 'Dinleme alışkanlıklarına göre eşleşmeler bul';
  static String get appleMusicSyncSuccess =>
      _en ? 'Apple Music history added to matches!' : 'Apple Music geçmişin eşleşmelere eklendi!';
  static String get appleMusicSyncFail =>
      _en ? 'Apple Music permission required or library empty.' : 'Apple Music izni gerekli veya kütüphane boş.';

  // Şikayet nedenleri
  static String get reportReasonSpam => _en ? 'Spam or Misleading' : 'Spam veya Yanıltıcı';
  static String get reportReasonImpersonation => _en ? 'Impersonation or Fake Account' : 'Taklit veya Sahte Hesap';
  static String get reportReasonHateSpeech => _en ? 'Hate Speech' : 'Nefret Söylemi';
  static String get reportReasonViolence => _en ? 'Violence or Dangerous' : 'Şiddet veya Tehlikeli';
  static String get reportReasonBullying => _en ? 'Bullying or Harassment' : 'Zorbalık veya Taciz';
  static String get reportReasonOther => _en ? 'Other' : 'Diğer';

  // ── PROFİL DÜZENLEME ──
  static String get editProfileTitle => _en ? 'Edit Profile' : 'Profili Düzenle';
  static String get fullName => _en ? 'Full Name' : 'Adın Soyadın';
  static String get username => _en ? 'Username' : 'Kullanıcı Adı';
  static String get bio => _en ? 'Bio' : 'Biyografi';
  static String get liveVideoAdded => _en ? 'Live Selected' : 'Live Seçildi';
  static String get addLiveVideo => _en ? 'Add Live Video' : 'Live Video Ekle';
  static String get addLivePhoto => _en ? 'Add Live Photo' : 'Live Fotoğraf Ekle';
  static String get livePhotoAdded => _en ? 'Live Photo Set ✓' : 'Live Fotoğraf Seçildi ✓';
  static String get pickLivePhoto => _en ? 'Live Photos' : 'Live Fotoğraflar';
  static String get noLivePhotos => _en ? 'No Live Photos in your gallery' : 'Galerinizde Live fotoğraf yok';
  static String get photoPermissionDenied => _en ? 'Photo library access is required.\nPlease allow it in Settings.' : 'Fotoğraf erişimi gerekli.\nLütfen Ayarlar\'dan izin verin.';
  static String get pickKeyFrame => _en ? 'Choose Key Frame' : 'Anahtar Kare Seç';
  static String get keyFrame => _en ? 'Key Frame' : 'Anahtar Kare';
  static String get keyFrameHint => _en ? 'Drag to pick the moment shown on your profile' : 'Profilinde görünecek anı seçmek için sürükle';
  static String get use => _en ? 'Use' : 'Kullan';
  static String get ringColor => _en ? 'Ring Color' : 'Halka Rengi';
  static String get profileRingColor => _en ? 'Profile Ring Color' : 'Profil Halka Rengi';
  static String get liveVideoSet =>
      _en ? 'Live Video and Cover Image Set! 🎬' : 'Live Video ve Kapak Resmi Ayarlandı! 🎬';
  static String get saveToHitCheckmark =>
      _en ? 'Tap ✓ to save' : 'Kaydetmek için ✓ bas';

  // ── GÖNDERI DETAY ──
  static String get postTitle => _en ? 'Post' : 'Gönderi';
  static String get explorePostTitle => _en ? 'Top of the Flame 🔥' : 'Ateşin Başı 🔥';
  static String get commentDeleted => _en ? 'Comment deleted.' : 'Yorum silindi.';
  static String get commentNotDeleted => _en ? 'Could not delete.' : 'Silinemedi.';
  static String get deleteComment => _en ? 'Delete Comment' : 'Yorumu Sil';
  static String get deleteCommentConfirm =>
      _en ? 'Are you sure you want to delete this comment?' : 'Bu yorumu silmek istediğine emin misin?';
  static String get editComment => _en ? 'Edit Comment' : 'Yorumu Düzenle';
  static String get commentHint => _en ? 'Write a comment...' : 'Yorum yaz...';
  static String get discard => _en ? 'Discard' : 'Vazgeç';
  static String get commentUpdated => _en ? 'Comment updated! ✏️' : 'Yorum güncellendi! ✏️';
  static String get commentFailed => _en ? 'Comment could not be sent ❌' : 'Yorum gönderilemedi ❌';
  static String get toxicComment =>
      _en ? '⛔ This comment contains inappropriate content!' : '⛔ Bu yorum uygunsuz içerik barındırıyor!';
  static String get reportReceived => _en ? 'Report received. Thank you! 🛡️' : 'Bildirimin alındı. Teşekkürler! 🛡️';
  static String get deletePost => _en ? 'Delete Post' : 'Gönderiyi Sil';
  static String get deletePostConfirm =>
      _en ? 'Are you sure you want to delete this post? This action cannot be undone.' : 'Bu gönderiyi silmek istediğine emin misin? Bu işlem geri alınamaz.';
  static String get postDeleted => _en ? 'Post deleted! 🗑️' : 'Gönderi silindi! 🗑️';
  static String get fuelExpired => _en ? 'This post\'s flame has expired! 🔥' : 'Bu gönderinin alev süresi doldu! 🔥';
  static String get reactionSent => _en ? 'Reaction sent! 📸' : 'Tepki gönderildi! 📸';
  static String get reactionDeleted => _en ? 'Reaction deleted! 🗑️' : 'Tepki silindi! 🗑️';
  static String get deleteReaction => _en ? 'Delete Reaction' : 'Tepkiyi Sil';
  static String get deleteReactionConfirm =>
      _en ? 'Are you sure you want to delete this reaction?' : 'Bu tepkiyi silmek istediğine emin misin?';
  static String get videoLoadFailed => _en ? 'Video could not be loaded' : 'Video yüklenemedi';
  static String get retryLabel => _en ? 'Try Again' : 'Tekrar Dene';
  static String get watchOnYoutube => _en ? 'Watch on YouTube' : 'YouTube\'da izle';
  static String get edited => _en ? '(edited)' : '(düzenlendi)';

  // ── AYARLAR ──
  static String get settings => _en ? 'Settings' : 'Ayarlar';
  static String get language => _en ? 'LANGUAGE' : 'DİL';
  static String get account => _en ? 'ACCOUNT' : 'HESAP';
  static String get privacy => _en ? 'PRIVACY' : 'GİZLİLİK';
  static String get support => _en ? 'SUPPORT' : 'DESTEK';
  static String get about => _en ? 'About' : 'Hakkında';
  static String get rateApp => _en ? 'Rate App' : 'Uygulamayı Değerlendir';
  static String get privacyPolicy => _en ? 'Privacy Policy' : 'Gizlilik Politikası';
  static String get notificationsSettings => _en ? 'Notifications' : 'Bildirimler';
  static String get changePassword => _en ? 'Change Password' : 'Şifreyi Değiştir';
  static String get signOut => _en ? 'Sign Out' : 'Çıkış Yap';
  static String get signOutConfirm => _en ? 'Are you sure you want to sign out?' : 'Hesabından çıkmak istediğinden emin misin?';
  static String get deleteAccount => _en ? 'Delete Account' : 'Hesabı Sil';
  static String get deleteAccountConfirm => _en ? 'Are you sure? This action is permanent and cannot be undone.' : 'Emin misin? Bu işlem kalıcıdır ve geri alınamaz.';
  // Privacy toggles
  static String get showLastSeen => _en ? 'Last Seen' : 'Son Görülme';
  static String get showLastSeenSubtitle => _en ? 'Show others when you were last active' : 'Diğerleri son aktifliğini görebilir';
  static String get readReceiptsSubtitle => _en ? 'Show when you\'ve read messages' : 'Mesajları okuduğundu bildirsin';
  // Notification toggles
  static String get pushNotifications => _en ? 'Push Notifications' : 'Anlık Bildirimler';
  static String get notifLikes => _en ? 'Likes & Reactions' : 'Beğeniler & Tepkiler';
  static String get notifComments => _en ? 'Comments' : 'Yorumlar';
  static String get notifFollowers => _en ? 'New Followers' : 'Yeni Takipçiler';
  static String get notifMessages => _en ? 'Messages' : 'Mesajlar';

  // ── GRUPLAR ──
  static String get group => _en ? 'Group' : 'Grup';
  static String members(int n) => _en ? '$n members' : '$n üye';
  static String get leaveGroup => _en ? 'Leave Group' : 'Gruptan Ayrıl';
  static String get deleteGroup => _en ? 'Delete Group' : 'Grubu Sil';
  static String get addMember => _en ? 'Add Member' : 'Üye Ekle';
  static String get groupSettings =>
      _en ? 'Group Settings' : 'Grup Ayarları';
  static String get groupMembers => _en ? 'Members' : 'Üyeler';
  static String get groupLeader => _en ? 'Leader' : 'Lider';
  static String get groupAdmin => _en ? 'Admin' : 'Admin';
  static String get groupNameHintField => _en ? 'Group name' : 'Grup adı';
  static String get kickMember => _en ? 'Remove from Group' : 'Gruptan At';
  static String get kickConfirm =>
      _en ? 'will be removed from the group. Continue?' : 'gruptan atılacak. Devam et?';
  static String get makeAdmin => _en ? 'Make Admin' : 'Admin Yap';
  static String get removeAdmin => _en ? 'Remove Admin' : 'Admin\'den Çıkar';
  static String get leaveGroupConfirm =>
      _en ? 'Are you sure you want to leave the group?' : 'Gruptan ayrılmak istediğine emin misin?';
  static String get deleteGroupConfirm =>
      _en ? 'This group and all messages will be permanently deleted. This cannot be undone!' : 'Bu grup ve tüm mesajları kalıcı olarak silinecek. Bu işlem geri alınamaz!';
  static String get yesDelete => _en ? 'Yes, Delete' : 'Evet, Sil';
  static String get noCommonFriends =>
      _en ? 'No common friends to add' : 'Eklenecek ortak arkadaş bulunamadı';
  static String get groupInfoUpdated => _en ? 'Group info updated' : 'Grup bilgileri güncellendi';
  static String get groupAvatarUpdated => _en ? 'Group photo updated' : 'Grup fotoğrafı güncellendi';
  static String get groupNameUpdated => _en ? 'Group name updated' : 'Grup adı güncellendi';
  static String get saveFailed => _en ? 'Could not save' : 'Kaydedilemedi';

  // ── SOHBET ──
  static String get deleteChat =>
      _en ? 'Delete Chat' : 'Sohbeti Sil';
  static String get deleteChatConfirm =>
      _en ? 'All messages will be deleted. Are you sure?' : 'Bu sohbetin tüm mesajları silinecek. Emin misin?';
  static String get tapToView =>
      _en ? 'Tap to view messages...' : 'Mesajları görüntülemek için dokun...';
  static String get tapTrashToDelete =>
      _en ? 'Tap the trash to delete' : 'Silmek için çöp kutusuna bas';
  static String get chatCleared => _en ? 'Chat cleared.' : 'Sohbet temizlendi.';
  static String get yesDeleteAction => _en ? 'Yes, Delete' : 'Evet, Sil';

  // ── SPARK MODU ──
  static String get sparkMode => _en ? 'Spark Mode' : 'Kıvılcım Modu';
  static String get bluetoothRadar => _en ? 'Bluetooth radar' : 'Bluetooth radar';
  static String get scanning => _en ? 'Scanning...' : 'Taranıyor...';
  static String get scanningSurroundings => _en ? 'Scanning surroundings...' : 'Çevren taranıyor...';
  static String nearbyCount(int n) => _en ? '$n people nearby' : '$n kişi yakında';
  static String get tapToStop => _en ? 'Tap to stop' : 'Durdurmak için dokun';
  static String get tapToStart => _en ? 'Tap to start' : 'Başlatmak için dokun';
  static String get bluetoothError => _en ? 'Make sure Bluetooth is on!' : 'Bluetooth\'u açtığından emin ol!';
  static String get anErrorOccurred => _en ? 'An error occurred' : 'Bir hata oluştu';
  static String get kinnectUser => _en ? 'Kinnect User' : 'Kinnect Kullanıcısı';
  static String signalLabel(int pct) => _en ? '$pct% signal' : '$pct% sinyal';
  static String get viewProfile => _en ? 'View Profile' : 'Profili Gör';

  // ── AI EŞLEŞTİRME ──
  static String get soulTwins => _en ? 'Soul Twins' : 'Ruh İkizlerin';
  static String aiFoundCommon(int n) =>
      _en ? 'AI found common ground with $n people' : 'Yapay zeka $n kişiyle ortak yönler buldu';
  static String get closestToYou => _en ? 'Closest to You' : 'Sana En Yakın Kişiler';
  static String get hiddenMatches => _en ? 'Hidden Matches' : 'Gizlenen Eşleşmeler';
  static String get noHiddenMatches => _en ? 'No hidden matches.' : 'Gizlenmiş eşleşme yok.';
  static String get commonPoints => _en ? 'Common Points' : 'Ortak Noktalarınız';
  static String get personalityMatch => _en ? 'Personality Match' : 'Kişilik Uyumu';
  static String get commonMusic => _en ? '🎵 Common Music' : '🎵 Ortak Müzik';
  static String get bothListening => _en ? 'Both of you listen to this' : 'İkiniz de dinliyor';
  static String get aiAnalysis => _en ? 'AI Analysis' : 'Yapay Zeka Analizi';
  static String get analyzing => _en ? 'Analyzing' : 'Analiz ediliyor';
  static String get greatMatch => _en ? 'A great match!' : 'Harika bir eşleşme!';
  static String get interests => _en ? '🎯 Interests' : '🎯 İlgi Alanları';
  static String get sendMessageAction => _en ? 'Send Message' : 'Mesaj At';
  static String get goToProfile => _en ? 'Go to Profile' : 'Profile Git';
  static String get compatibility => _en ? 'Compatibility' : 'Uyum';
  static String get noMatchesYet => _en ? 'No Matches Yet' : 'Henüz Eşleşme Yok';
  static String get noMatchesSubtitle =>
      _en ? 'As you share posts, AI will show people with similar interests here! 🤖'
          : 'Post paylaştıkça yapay zeka sana benzer ilgi alanlarına sahip kişileri burada gösterecek! 🤖';
  static String get aiSearching => _en ? 'AI is searching for your soul twins...' : 'Yapay zeka ruh ikizlerini arıyor...';
  static String get connectionError => _en ? 'Connection error' : 'Bağlantı hatası';
  static String get matchesFailedToLoad =>
      _en ? 'Matches could not be loaded. Try again.' : 'Eşleşmeler yüklenemedi. Tekrar deneyin.';
  static String get tryAgain => _en ? 'Try Again' : 'Tekrar Dene';
  static String get toFindSoulTwin => _en ? 'To Find Your Soul Twin...' : 'Ruh İkizini Bulmak İçin...';
  static String aiNeedsPostsDescription(int n) =>
      _en ? 'For AI to analyze you and find the most compatible people, you need to share at least $n posts.'
          : 'Yapay zekanın seni analiz edebilmesi ve en uyumlu kişileri bulabilmesi için en az $n gönderi paylaşman gerekiyor.';
  static String postsProgress(int current, int total) =>
      _en ? '$current / $total posts' : '$current / $total gönderi';
  static String moreNeeded(int n) =>
      _en ? '$n more' : '$n tane daha';
  static String get sharePost => _en ? 'Share a Post' : 'Gönderi Paylaş';

  // ── ARAMA / KEŞFET ──
  static String get searchUsers => _en ? 'Search users...' : 'Kullanıcı ara...';
  static String get searchHint => _en ? 'Search...' : 'Ara...';
  static String get startSearching => _en ? 'Start searching' : 'Aramaya başla';
  static String get noExploreContent => _en ? 'No content to explore yet' : 'Henüz keşfedilecek içerik yok';

  // ── ANA AKIŞ ──
  static String get noPostsInFeed => _en ? 'No posts yet' : 'Henüz paylaşım yok';
  static String get followFriendsPrompt => _en ? 'Follow your friends!' : 'Arkadaşlarını takip et!';

  // ── ETİKETLEME ──
  static String get tagPerson => _en ? 'Tag Person' : 'Kişi Etiketle';
  static String get tagPeople => _en ? 'Tag People' : 'Kişileri Etiketle';
  static String get tapPhotoToTag => _en ? 'Tap photo to tag people' : 'Fotoğrafa dokunarak kişileri etiketle';
  static String get taggedTapToRemove => _en ? 'Tagged (tap to remove):' : 'Etiketlenen (silmek için dokun):';
  static String alreadyTagged(String username) => _en ? '$username is already tagged!' : '$username zaten etiketli!';
  static String skipOrContinue(int n) => n == 0 ? (_en ? 'Skip' : 'Atla') : (_en ? 'Continue ($n)' : 'Devam ($n)');

  // ── VİDEO DÜZENLEME ──
  static String get videoEditTitle => _en ? 'Edit Video' : 'Video Düzenle';
  static String get videoProcessError => _en ? 'Could not process video' : 'Video işlenemedi';
  static String get trimSection => _en ? 'Trim' : 'Kırpma';
  static String maxSecondsSelect(int n) => _en ? 'Select max $n seconds' : 'Maks. $n saniye seç';
  static String get coverSelectTitle => _en ? 'Choose Cover' : 'Kapak Seç';
  static String get coverSelectSubtitle => _en ? 'Which frame should be the cover?' : 'Videonun hangi anı kapak olsun?';
  static String get coverFrame => _en ? 'Cover frame' : 'Kapak karesi';
  static String get slideToSelectFrame => _en ? 'slide → select frame' : 'kaydır → kare seç';
  static String get startTime => _en ? 'Start' : 'Başlangıç';
  static String get endTime => _en ? 'End' : 'Bitiş';
  static String get secSuffix => _en ? 's' : 'sn';

  // ── TAKİPÇİ LİSTESİ ──
  static String get areYouSure => _en ? 'Are you sure?' : 'Emin misin?';
  static String removingFollowerMsg(String username) =>
      _en ? 'You\'re about to remove @$username from your followers.'
          : '@$username adlı kişiyi takipçilerinden çıkarmak üzeresin.';
  static String get followerRemoved => _en ? 'Removed.' : 'Kişi çıkarıldı.';
  static String get unfollowed => _en ? 'Unfollowed.' : 'Takipten çıkıldı.';

  // ── BEĞENİLER ──
  static String get noOneLiked => _en ? 'No one has liked this yet' : 'Henüz kimse beğenmedi';
  static String get likers => _en ? 'Likes' : 'Beğenenler';

  // ── SOHBET WİDGETS ──
  static String get goToPost => _en ? 'Go to post' : 'Gönderiye git';
  static String get messageAshes => _en ? 'Message burned to ashes 🔥' : 'Mesaj küle döndü 🔥';
  static String get noChatContacts => _en ? 'No friends to share with.' : 'Paylaşılacak arkadaş bulunamadı.';
  static String get shareWithFriend => _en ? 'Share with a friend' : 'Arkadaşla Paylaş';
  static String get sent => _en ? 'Sent' : 'Gönderildi';

  // ── GÖNDERİ ŞİKAYET ──
  static String get reportPostTitle => _en ? 'Report Post' : 'Şikayet Et';
  static String get reportPostQuestion => _en ? 'Why are you reporting this post?' : 'Bu gönderiyi neden bildiriyorsun?';
  static String get reportReasonNudity => _en ? 'Nudity or Sexual Content' : 'Çıplaklık veya Cinsellik';
  static String get additionalNote => _en ? 'Additional Note' : 'Ek Açıklama';
  static String selectedReason(String r) => _en ? 'Selected: $r' : 'Seçilen: $r';
  static String get addDetailOptional => _en ? 'If you\'d like to add more detail, write below.' : 'Detay eklemek istersen aşağıya yazabilirsin.';
  static String get typeHere => _en ? 'Type here...' : 'Buraya yaz...';
  static String get send => _en ? 'Send' : 'Gönder';

  // ── AUTH / GİRİŞ ──
  static String get aiPowered => _en ? 'AI POWERED' : 'YAPAY ZEKA DESTEKLİ';
  static String get joinTribe => _en ? 'Join the\nTribe' : 'Kabileye\nKatıl';
  static String get joinSubtitle => _en ? 'Join us now to build real connections.' : 'Gerçek bağlar kurmak için\nşimdi aramıza katıl.';
  static String get continueWithGoogle => _en ? 'Continue with Google' : 'Google ile Devam Et';
  static String get signUpWithEmail => _en ? 'Sign Up with Email' : 'E-posta ile Kayıt Ol';
  static String get alreadyHaveAccount => _en ? 'Already have an account? ' : 'Zaten hesabın var mı? ';
  static String get signIn => _en ? 'Sign In' : 'Giriş Yap';
  static String get signingIn => _en ? 'Signing in...' : 'Giriş yapılıyor...';

  // ── KARŞILAMA EKRANI ──
  static String get welcomeTitle => _en ? 'Welcome to\nKinnect' : 'Kinnect\'e\nHoş Geldin';
  static String get welcomeSubtitle => _en ? 'Share meaning, not just photos.' : 'Sadece fotoğraf değil, anlam paylaş.';
  static String get skipLabel => _en ? 'Skip' : 'Atla';
  static String get letsGo => _en ? 'Let\'s Go' : 'Başlayalım';
  static String get featureAI => _en ? 'AI' : 'Yapay Zeka';
  static String get featureInnovative => _en ? 'Innovative & Fun' : 'Yenilikçi ve Eğlenceli';
  static String get featureDeepAnalysis => _en ? 'Deep Analysis' : 'Derin Analiz';
  static String get featurePrivate => _en ? 'Private & Secure' : 'Gizli ve Güvenli';
  static String get badgeVisualAI => _en ? 'VISUAL AI' : 'GÖRSEL ZEKA';
  static String get badgeNLP => _en ? 'NLP' : 'DOĞAL DİL İŞLEME';
  static String get badgeAIMatching => _en ? 'AI MATCHING' : 'AI EŞLEŞTİRME';
  static String get photoAnalysisTitle => _en ? 'Analyzing Your\nPhotos' : 'Fotoğraflarını\nAnaliz Ediyoruz';
  static String get photoAnalysisSubtitle => _en ? 'We discover hidden hobbies, style, and interests in your shared photos using AI.' : 'Paylaştığın karelerdeki gizli hobileri, tarzını ve ilgi alanlarını AI ile keşfediyoruz.';
  static String get textAnalysisTitle => _en ? 'Decoding Your\nWritings' : 'Yazılarını\nDeşifre Ediyoruz';
  static String get textAnalysisSubtitle => _en ? 'We read the real \'you\' between the lines of your posts. Build deep connections, not shallow ones.' : 'Tweetlerin ve yazılarının satır aralarındaki \'seni\' okuyoruz. Yüzeysel değil, derin bağlar kur.';
  static String get matchAnalysisTitle => _en ? 'Find Your Tribe' : 'Kabileni Bul';
  static String get matchAnalysisSubtitle => _en ? 'Discover and connect with the most compatible people based on photo and text analysis.' : 'Fotoğraf ve yazı analizlerine göre sana\nen uygun insanları keşfet ve bağlan.';
  static List<String> get welcomeInputWords => _en
      ? ['Did you see Explore?', 'Hey!', 'Great photo!', 'What\'s up?', 'Where are you?', 'What\'s this song?', 'Shall we meet?', 'Awesome!']
      : ['Keşfeti gördün mü?', 'Selam!', 'Fotoğrafın harika', 'Naber?', 'Konum neresi?', 'Bu şarkı ne?', 'Tanışalım mı?', 'Harika!'];
  static List<String> get welcomeOutputWords => _en
      ? ['Bond', 'Friendship', 'Trust', 'Meaning', 'Tribe', 'Sincerity', 'Real', 'Feeling']
      : ['Bağ', 'Dostluk', 'Güven', 'Anlam', 'Kabile', 'Samimiyet', 'Gerçek', 'His'];

  // ── ARAMA - YOLDAŞ / TREND ──
  static String get chooseCompanion => _en ? 'Choose Your Companion' : 'Yoldaşını Seç';
  static String get companionSubtitle => _en ? 'Choose the character to accompany you on the Explore screen.' : 'Keşfet ekranında sana eşlik edecek karakteri seç.';
  static String trendingRank(int n) => _en ? 'TRENDING #$n' : 'GÜNDEM #$n';
  static String fuelsCount(int n) => _en ? '$n Fuels' : '$n Harlama';
  static String get statusHeating => _en ? 'HEATING' : 'ISINIYOR';
  static String get statusFlaming => _en ? 'FLAMING' : 'ALEVLİ';
  static String get statusHellfire => _en ? 'HELLFIRE' : 'CEHENNEM';
  static String get statusBurnedOut => _en ? 'BURNED OUT' : 'KÜL OLDU';
  static String get noFlameYet => _en ? 'No flames yet.' : 'Henüz ateş yok.';

  // ── MÜZİK KARTI ──
  static String get manageMusicAccounts => _en ? 'Manage Music Accounts' : 'Müzik Hesaplarını Yönet';
  static String get connectSpotify => _en ? 'Connect with Spotify' : 'Spotify ile Bağlan';
  static String get disconnectSpotify => _en ? 'Disconnect Spotify' : 'Spotify Bağlantısını Kes';
  static String get connectAppleMusic => _en ? 'Connect with Apple Music' : 'Apple Music ile Bağlan';
  static String get disconnectAppleMusic => _en ? 'Disconnect Apple Music' : 'Apple Music Bağlantısını Kes';
  static String get connectSpotifyOrAppleMusic => _en ? 'Connect Spotify or Apple Music' : 'Spotify veya Apple Music Bağla';
  static String get nowListening => _en ? 'Now Listening' : 'Şu an Dinleniyor';
  static String get lastListened => _en ? 'Last Listened' : 'Son Dinlenen';
  static String get previewPlaying => _en ? 'Preview Playing' : 'Önizleme Çalıyor';

  // ── YAPAY ZEKA EŞLEŞTİRME ──
  static String get analysisSource => _en ? 'Analysis Source' : 'Analiz Kaynağı';

  /// Translates a user interest string from Turkish to English when language is EN.
  static String translateInterest(String interest) {
    if (!_en) return interest;
    const map = <String, String>{
      // Müzik / Music
      'müzik': 'music',
      'keman': 'violin',
      'gitar': 'guitar',
      'piyano': 'piano',
      'davul': 'drums',
      'bas gitar': 'bass guitar',
      'şarkı': 'singing',
      'şarkı söyleme': 'singing',
      'rap': 'rap',
      'hip-hop': 'hip-hop',
      'caz': 'jazz',
      'klasik müzik': 'classical music',
      'rock': 'rock',
      'pop': 'pop',
      'elektronik müzik': 'electronic music',
      'konser': 'concerts',
      'festival': 'festivals',
      // Doğa / Nature
      'doğa': 'nature',
      'kamp': 'camping',
      'dağ': 'mountains',
      'orman': 'forest',
      'deniz': 'sea',
      'sahil': 'beach',
      'göl': 'lake',
      'plaj': 'beach',
      'ada': 'island',
      'yürüyüş': 'hiking',
      'trekking': 'trekking',
      'bisiklet': 'cycling',
      'sörf': 'surfing',
      'dalış': 'diving',
      'kayak': 'skiing',
      'snowboard': 'snowboarding',
      'dağ bisikleti': 'mountain biking',
      'paraşüt': 'skydiving',
      'rafting': 'rafting',
      // Spor / Sports
      'spor': 'sports',
      'futbol': 'football',
      'basketbol': 'basketball',
      'voleybol': 'volleyball',
      'tenis': 'tennis',
      'yüzme': 'swimming',
      'koşu': 'running',
      'yoga': 'yoga',
      'pilates': 'pilates',
      'dans': 'dance',
      'boks': 'boxing',
      'fitness': 'fitness',
      'gym': 'gym',
      'jimnastik': 'gymnastics',
      // Yemek / Food
      'kahve': 'coffee',
      'çay': 'tea',
      'yemek': 'cooking',
      'yemek pişirme': 'cooking',
      'kafe': 'cafés',
      'pasta': 'baking',
      'vegan': 'vegan',
      'vejetaryen': 'vegetarian',
      // Sanat / Art
      'sanat': 'art',
      'resim': 'painting',
      'fotoğrafçılık': 'photography',
      'fotoğraf': 'photography',
      'sinema': 'cinema',
      'film': 'films',
      'dizi': 'series',
      'anime': 'anime',
      'çizim': 'drawing',
      'heykel': 'sculpture',
      'grafik tasarım': 'graphic design',
      'tasarım': 'design',
      // Seyahat / Travel
      'seyahat': 'travel',
      'tatil': 'travel',
      'gezi': 'travel',
      'keşif': 'exploration',
      'backpacking': 'backpacking',
      // Okuma / Reading
      'okuma': 'reading',
      'kitap': 'books',
      'şiir': 'poetry',
      'yazarlık': 'writing',
      'blog': 'blogging',
      // Teknoloji / Tech
      'teknoloji': 'technology',
      'yazılım': 'software',
      'programlama': 'programming',
      'oyun': 'gaming',
      'gaming': 'gaming',
      'e-spor': 'esports',
      'yapay zeka': 'AI',
      // Sağlık / Wellness
      'meditasyon': 'meditation',
      'mindfulness': 'mindfulness',
      'psikoloji': 'psychology',
      'sağlık': 'health',
      'beslenme': 'nutrition',
      // Diğer / Other
      'astronomi': 'astronomy',
      'tarih': 'history',
      'felsefe': 'philosophy',
      'girişimcilik': 'entrepreneurship',
      'iş dünyası': 'business',
      'moda': 'fashion',
      'sürdürülebilirlik': 'sustainability',
      'çevre': 'environment',
      'hayvanlar': 'animals',
      'evcil hayvan': 'pets',
      'köpek': 'dogs',
      'kedi': 'cats',
    };
    final key = interest.toLowerCase().trim();
    return map[key] ?? interest;
  }
  static String get analysisSourceDescription => _en ? 'AI made this analysis based on the following posts.' : 'Yapay zeka bu analizi aşağıdaki paylaşımlara dayanarak yaptı.';
  static String get myPosts => _en ? 'Your posts' : 'Senin paylaşımların';
  static String otherUserPosts(String name) => _en ? '$name\'s posts' : '$name\'ın paylaşımları';
  static String compatibilityPercent(int n) => _en ? '$n% Match' : '%$n Uyum';

  // ── YORUMLAR ──
  static String get firstComment => _en ? 'Be the first to comment!' : 'İlk yorumu sen yap!';
  static String get exploreCommentHint => _en ? 'Add fuel to the fire...' : 'Ateşe odun at...';
  static String get emojiReaction => _en ? 'Send Emoji Reaction' : 'Emoji Tepki Gönder';
  static String replyToUserHint(String username) => _en ? '@$username reply...' : '@$username yanıtla...';
  static String get firstFuel => _en ? 'Be the first to add fuel! 🔥' : 'İlk odunu sen at 🔥';
  static String recordingHint(int sec) => _en ? 'Recording... ($sec)' : 'Kaydediliyor... ($sec)';
  static String replyingToUser(String username) => _en ? 'Replying to @$username' : '@$username yanıtlıyorsun';
  static String get replyLabel => _en ? 'Reply' : 'Yanıtla';
  static String get voiceComment => _en ? 'Voice Comment' : 'Sesli Yorum';
  static String get playing => _en ? 'Playing...' : 'Çalıyor...';
  static String get anonymous => _en ? 'Anonymous' : 'Anonim';

  // ── GİRİŞ EKRANI ──
  static String get welcomeBack => _en ? 'Welcome\nBack' : 'Tekrar\nHoş Geldin';
  static String get continueWhereLeftOff => _en ? 'Continue where you left off.' : 'Kaldığın yerden devam et.';
  static String get emailAddress => _en ? 'Email Address' : 'E-posta Adresi';
  static String get emailRequired => _en ? 'Email required' : 'E-posta gerekli';
  static String get password => _en ? 'Password' : 'Şifre';
  static String get passwordRequired => _en ? 'Password required' : 'Şifre gerekli';
  static String get forgotPassword => _en ? 'Forgot your password?' : 'Şifreni mi unuttun?';
  static String get securityVerification => _en ? 'Security Verification' : 'Güvenlik Doğrulaması';
  static String twoFAPrompt(String phone) => _en ? 'Your account has 2FA enabled. Enter the 6-digit code sent to ($phone).' : 'Hesabınızda 2FA aktif. ($phone) numarasına gelen 6 haneli kodu giriniz.';
  static String get verifyLabel => _en ? 'Verify' : 'Doğrula';
  static String get loginFailed => _en ? 'Login failed' : 'Giriş başarısız';
  static String get userInfoError => _en ? 'Logged in but could not retrieve user info.' : 'Giriş yapıldı ama kullanıcı bilgisi alınamadı.';
  static String get emailNotConfirmed => _en ? 'Please confirm your email address.' : 'Lütfen e-posta adresinizi onaylayın.';
  static String get unexpectedError => _en ? 'An unexpected error occurred.' : 'Beklenmedik bir hata oluştu.';

  // ── KAYIT EKRANI ──
  static String get newAccount => _en ? 'NEW ACCOUNT' : 'YENİ HESAP';
  static String get createAccountTitle => _en ? 'Create\nAccount' : 'Hesap\nOluştur';
  static String get signupSubtitle => _en ? 'Step into Kinnect and find your tribe.' : 'Kinnect dünyasına adım at ve kabileni bul.';
  static String get enterValidEmail => _en ? 'Enter a valid email' : 'Geçerli bir e-posta girin';
  static String get passwordTooShort => _en ? 'Must be at least 8 characters' : 'En az 8 karakter olmalı';
  static String get confirmPasswordLabel => _en ? 'Confirm Password' : 'Şifre Tekrar';
  static String get passwordsDontMatch => _en ? 'Passwords don\'t match' : 'Şifreler eşleşmiyor';
  static String get signUp => _en ? 'Sign Up' : 'Kayıt Ol';
  static String get registrationSuccess => _en ? 'Registration Successful! 🎉' : 'Kayıt Başarılı! 🎉';
  static String checkEmailConfirmation(String email) => _en
      ? 'We sent a confirmation link to ($email). Please check your email.'
      : 'E-posta adresine ($email) onay linki gönderdik. Lütfen kontrol et.';

  // ── PROFİL OLUŞTURMA ──
  static String get createProfileBadge => _en ? 'CREATE PROFILE' : 'PROFİL OLUŞTUR';
  static String get displayName => _en ? 'Display Name' : 'Görünen İsim';
  static String get requiredField => _en ? 'Required field' : 'Gerekli alan';
  static String get getStarted => _en ? 'GET STARTED' : 'BAŞLAYALIM';

  // ── ŞİFRE SIFIRLAMA ──
  static String get resetPassword => _en ? 'Reset Your\nPassword' : 'Şifreni\nSıfırla';
  static String get resetPasswordSubtitle => _en ? 'Enter the email address linked to your account and we\'ll send you a reset link.' : 'Hesabına bağlı e-posta adresini gir,\nsana şifreni yenilemen için bir link gönderelim.';
  static String get sendLink => _en ? 'Send Link' : 'Link Gönder';
  static String get linkSent => _en ? 'Link Sent! 🚀' : 'Link Gönderildi! 🚀';
  static String resetLinkSentTo(String email) => _en
      ? 'We sent a password reset link to $email. Check your email.'
      : '$email adresine şifre sıfırlama linki gönderdik. E-postanı kontrol et.';
  static String get pleaseEnterEmail => _en ? 'Please enter your email address.' : 'Lütfen e-posta adresini gir.';

  // ── ŞİFRE DEĞİŞTİRME ──
  static String get setNewPassword => _en ? 'Set New Password' : 'Yeni Şifre Belirle';
  static String get setNewPasswordSubtitle => _en ? 'Create a new and strong password for your account.' : 'Lütfen hesabın için yeni ve güçlü bir şifre oluştur.';
  static String get newPassword => _en ? 'New Password' : 'Yeni Şifre';
  static String get passwordMinLength => _en ? 'Password must be at least 6 characters' : 'Şifre en az 6 karakter olmalı';
  static String get confirmPasswordReenter => _en ? 'Confirm Password' : 'Şifreyi Onayla';
  static String get reenterPassword => _en ? 'Please re-enter your password' : 'Lütfen şifreyi tekrar gir';
  static String get passwordsMismatch => _en ? 'Passwords don\'t match!' : 'Şifreler uyuşmuyor!';
  static String get updatePassword => _en ? 'Update Password' : 'Şifreyi Güncelle';

  // ── KULLANICI LİSTESİ ──
  static String get accept => _en ? 'Accept' : 'Kabul';
  static String get removeFromGroup => _en ? 'Remove' : 'Çıkar';
  static String get followLabel => _en ? 'Follow' : 'Takip Et';
  static String get requestSent => _en ? 'Request Sent' : 'İstek yollandı';
  static String get listEmpty => _en ? 'List is empty.' : 'Liste boş.';

  // ── KONUM SEÇİCİ ──
  static String get locationPermissionError => _en ? 'Could not get location. Please check permissions.' : 'Konum alınamadı. Lütfen izinleri kontrol edin.';
  static String get addLocation => _en ? 'Add Location' : 'Konum Ekle';
  static String get useCurrentLocation => _en ? 'Use my current location' : 'Şu anki konumumu kullan';
  static String get autoDetects => _en ? 'Automatically detects' : 'Otomatik olarak bulur';
  static String get enterManualLocation => _en ? 'Enter location manually' : 'Manuel konum gir';
  static String get enterLocation => _en ? 'Enter Location' : 'Konum Gir';
  static String get locationPlaceholder => _en ? 'E.g.: Beşiktaş, Istanbul' : 'Örn: Beşiktaş, İstanbul';
  static String get addLabel => _en ? 'Add' : 'Ekle';

  // ── ARAMA EKRANI ──
  static String get preparingCall => _en ? 'Preparing call...' : 'Arama hazırlanıyor...';
  static String get guest => _en ? 'Guest' : 'Misafir';

  // ── GÖNDERİ OLUŞTURMA / DÜZENLEME ──
  static String get passwordUpdated => _en ? 'Password updated successfully! 🎉' : 'Şifren başarıyla güncellendi! 🎉';
  static String get postExpired => _en ? 'This post\'s flame time has expired! 🔥' : 'Bu gönderinin alev süresi doldu! 🔥';
  static String get postShared => _en ? 'Shared! 🚀' : 'Gönderildi! 🚀';
  static String get mediaRequired => _en ? 'At least one image or text is required!' : 'En az bir görsel veya yazı olmalı!';
  static String get editsSaved => _en ? 'Changes saved! ✅' : 'Düzenlemeler kaydedildi! ✅';
  static String get writeHint => _en ? 'Write something...' : 'Bir şeyler yaz...';
  static String get music => _en ? 'Music' : 'Müzik';
  static String get addMusicOptional => _en ? 'Add Music (Optional)' : 'Müzik Ekle (Opsiyonel)';
  static String get tapToSelect => _en ? 'Tap to select...' : 'Dokunarak seç...';
  static String imagesCount(int n) => _en ? 'Images ($n)' : 'Görseller ($n)';
  static String taggedCount(int n) => _en ? 'Tagged People ($n)' : 'Etiketli Kişiler ($n)';
  static List<String> get postHints => _en ? [
    'What are you thinking?',
    'How are you today?',
    'What\'s on your mind?',
    'How are you feeling?',
    'How was your day?',
    'What should I share...',
    'Leaving myself a note.',
    'Wait, I\'m about to share something...',
    'Got a message for your followers?',
    'Write something inspiring...',
    'Something you want to share?',
    'I had something to say... forgot. Anyway, writing.',
    'Feels like I need to share some thoughts.',
    'Leaving a piece of my mind here.',
    'Looking a bit too good today, had to post 👀',
    'About to share something... someone will take it personally.',
  ] : [
    'Neler düşünüyorsun?',
    'Bugün nasılsın?',
    'Aklında ne var?',
    'Nasıl hissediyorsun?',
    'Günün nasıl geçti?',
    'Ne paylaşsam acaba…',
    'Kendime bir not bırakıyorum.',
    'Dur bak şimdi bir şey paylaşacağım…',
    'Takipçilerine bir mesajın var mı?',
    'İlham verici bir şeyler yaz...',
    'Paylaşmak istediğin bir şey mi var?',
    'Bir şey yazacaktım… unuttum. Neyse yazıyorum.',
    'Düşündüğüm bazı şeyleri paylaşmam gerekiyor sanki.',
    'Buraya düşüncelerimden bir parça bırakıyorum.',
    'Bugün biraz fazla iyi görünüyorum, paylaşayım dedim 👀',
    'Şimdi öyle bir şey paylaşacağım ki… biri üstüne alınacak.',
  ];
}
