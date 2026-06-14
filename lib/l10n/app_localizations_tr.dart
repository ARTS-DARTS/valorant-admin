// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appSubtitle => 'Herkes için interaktif lineup\'lar';

  @override
  String get tabMaps => 'Haritalar';

  @override
  String get tabFavorites => 'Favoriler';

  @override
  String get tabCollections => 'Koleksiyonlar';

  @override
  String get tabProfile => 'Profil';

  @override
  String get cancel => 'İptal';

  @override
  String get ok => 'Tamam';

  @override
  String get or => 'veya';

  @override
  String get back => '← Geri';

  @override
  String get continueBtn => 'DEVAM ET';

  @override
  String get start => 'BAŞLA';

  @override
  String get comingSoon => 'Yakında';

  @override
  String get noInternet => 'İnternet bağlantısı yok';

  @override
  String get errorOccurred => 'Bir hata oluştu. Daha sonra tekrar deneyin';

  @override
  String get connectionError => 'Bağlantı hatası. İnternetini kontrol et.';

  @override
  String get welcome => 'Hoş geldiniz!';

  @override
  String get loginToAccount => 'Hesaba giriş yap';

  @override
  String get signIn => 'GİRİŞ YAP';

  @override
  String get register => 'KAYIT OL';

  @override
  String get nickname => 'Kullanıcı adı';

  @override
  String get password => 'Şifre';

  @override
  String get email => 'E-posta';

  @override
  String get signInWithGoogle => 'Google ile Giriş Yap';

  @override
  String get enterNickname => 'Kullanıcı adını gir';

  @override
  String get enterPassword => 'Şifreni gir';

  @override
  String get userNotFound => 'Bu kullanıcı adıyla kullanıcı bulunamadı';

  @override
  String get wrongPassword => 'Yanlış şifre';

  @override
  String get loginFailed => 'Giriş yapılamadı. Daha sonra tekrar deneyin';

  @override
  String get googleLoginFailed => 'Google ile giriş yapılamadı. Tekrar deneyin';

  @override
  String get chooseAppTheme => 'Uygulama teması seç';

  @override
  String get canChangeInProfile => 'Profilde daha sonra değiştirilebilir';

  @override
  String get createNicknameDesc =>
      'Başlamak için benzersiz bir kullanıcı adı oluştur';

  @override
  String get checkingNickname => 'Kullanıcı adı kontrol ediliyor...';

  @override
  String get nicknameFree => 'Kullanıcı adı müsait!';

  @override
  String get nicknameTaken => 'Kullanıcı adı alınmış';

  @override
  String get mustAcceptTerms => 'Kullanım Koşullarını kabul etmelisiniz';

  @override
  String get nameRules =>
      'Ad 2–20 karakter olmalıdır.\nSadece harf, rakam, _ ve -';

  @override
  String get nameTaken => 'Bu ad zaten alınmış. Başkasını dene!';

  @override
  String get nameCheckError => 'Ad kontrol hatası. Bağlantı yok mu?';

  @override
  String get nameHint =>
      '• 2-20 karakter\n• Harf, rakam, _ ve -\n• Benzersiz — kimse alamaz';

  @override
  String get iAgreePrefix => 'Okudum ve kabul ediyorum ';

  @override
  String get termsOfService => 'Kullanım Koşullarını';

  @override
  String get changeTheme => '← Temayı değiştir';

  @override
  String get createPassword => 'Şifre oluştur';

  @override
  String get passwordNeeded => 'Giriş yapmak için gerekli olacak';

  @override
  String get passwordHint => 'Şifre (minimum 6 karakter)';

  @override
  String get repeatPassword => 'Şifreyi tekrarla';

  @override
  String get passwordMinSix => 'Şifre en az 6 karakter olmalıdır';

  @override
  String get passwordsMismatch => 'Şifreler eşleşmiyor';

  @override
  String get accountCreationFailed =>
      'Hesap oluşturulamadı. Daha sonra tekrar deneyin';

  @override
  String get passwordTooSimple => 'Şifre çok basit. Minimum 6 karakter';

  @override
  String get emailAlreadyInUse => 'Bu e-posta zaten kullanılıyor';

  @override
  String get suggestLineup => 'Lineup öner';

  @override
  String get newsTooltip => 'Haberler';

  @override
  String get ratingMapPool => 'RATING MAP POOL';

  @override
  String get otherMaps => 'DİĞER HARİTALAR';

  @override
  String get categoryLineups => 'Lineup\'lar';

  @override
  String get categoryLineupsDesc => 'Düşmanı hazırlıksız yakala!';

  @override
  String get categoryCombo => 'Kombo';

  @override
  String get categoryComboDesc => 'Harika ajan komboları!';

  @override
  String get categorySmoky => 'Dumanlar';

  @override
  String get categorySmokyDesc => 'Ajanlarının en iyi dumanlarını öğren!';

  @override
  String get categoryDefense => 'Savunma';

  @override
  String get categoryDefenseDesc =>
      'Düşmanın siteye kolayca girmesine izin verme!';

  @override
  String get noLineupsYet => 'Henüz lineup yok, ama yakında eklenecek!';

  @override
  String lineupCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lineup',
      zero: 'Lineup yok',
    );
    return '$_temp0';
  }

  @override
  String get exclusiveAccessActive => 'Özel erişim 1 saat aktif';

  @override
  String patchLabel(String patch) {
    return 'Yama $patch';
  }

  @override
  String get accountDeleted => 'Hesap silindi';

  @override
  String get accountDeletedDesc =>
      'Tüm veriler silindi. Yeni bir hesap oluşturabilirsin.';

  @override
  String get mainMenu => 'ANA MENÜ';

  @override
  String get profileTitle => 'PROFİL';

  @override
  String get topAuthors => 'En iyi yazarlar';

  @override
  String get signOutDialogTitle => 'Çıkış yapılsın mı?';

  @override
  String get signOutDialogMessage =>
      'Tekrar giriş için kullanıcı adı ve şifre gerekecek.';

  @override
  String get signOutBtn => 'Çıkış yap';

  @override
  String get deleteAccountTitle => 'Hesap silinsin mi?';

  @override
  String get deleteAccountIrreversible => 'Bu işlem geri alınamaz!';

  @override
  String get deleteAccountContent =>
      'Silinecekler:\n• Kullanıcı adın\n• Seviye ve ilerleme\n• Tüm bekleyen lineup\'lar\n\nOnaylanan lineup\'lar kalacak.';

  @override
  String get deleteForever => 'Kalıcı olarak sil';

  @override
  String get linkEmailPassword => 'E-posta ve şifre bağla';

  @override
  String get linkEmailDesc =>
      'Google hesabına e-posta ve şifre bağla, böylece her iki yolla da giriş yapabilirsin.';

  @override
  String get newPassword => 'Yeni şifre';

  @override
  String get fillAllFields => 'Tüm alanları doldur';

  @override
  String get enterValidEmail => 'Geçerli bir e-posta gir';

  @override
  String get passwordMinSixSymbols => 'Şifre — minimum 6 karakter';

  @override
  String get emailPasswordLinked => 'E-posta ve şifre bağlandı ✅';

  @override
  String get emailAlreadyUsedByOther =>
      'Bu e-posta başka bir hesap tarafından kullanılıyor';

  @override
  String get emailAlreadyLinked => 'Bu e-posta başka bir hesaba bağlı';

  @override
  String get changePassword => 'Şifre değiştir';

  @override
  String get currentPassword => 'Mevcut şifre';

  @override
  String get repeatNewPassword => 'Yeni şifreyi tekrarla';

  @override
  String get newPasswordMinSix => 'Yeni şifre en az 6 karakter olmalıdır';

  @override
  String get passwordChanged => 'Şifre değiştirildi ✅';

  @override
  String get currentPasswordWrong => 'Mevcut şifre yanlış';

  @override
  String get appTheme => 'Uygulama teması';

  @override
  String approvedCount(int count) {
    return 'Onaylanan: $count';
  }

  @override
  String toNextLevel(String name, int count) {
    return '$name için: $count';
  }

  @override
  String get maximum => 'MAKSİMUM';

  @override
  String get levelPrivileges => 'Seviye ayrıcalıkları';

  @override
  String cooldownMinutes(int minutes) {
    return 'Bekleme süresi: $minutes dk';
  }

  @override
  String borderColor(String name) {
    return 'Çerçeve rengi: $name';
  }

  @override
  String get animatedProfile => 'Animasyonlu profil';

  @override
  String get topAuthorPosition => 'En iyi yazarlar listesindeki konum';

  @override
  String get allLevels => 'Tüm seviyeler';

  @override
  String get currentLevel => 'Mevcut';

  @override
  String levelRequirements(int lineups, int cd) {
    return '$lineups lineup • BC ${cd}dk';
  }

  @override
  String get aboutApp => 'Uygulama hakkında';

  @override
  String get aboutAppContent =>
      'Valorant için interaktif lineup\'lar içeren ücretsiz uygulama.\n\nRiot Games ile bağlantısı yoktur.';

  @override
  String get feedback => 'Geri bildirim';

  @override
  String get viewTutorial => 'Eğitimi görüntüle';

  @override
  String get signOutMenuTitle => 'Hesaptan çıkış yap';

  @override
  String get dangerZone => 'Tehlikeli bölge';

  @override
  String get dangerZoneDesc =>
      'Hesap silme geri alınamaz. Tüm ilerleme ve seviye kaybedilecek.';

  @override
  String get deleteMyAccount => 'HESABIMI SİL';

  @override
  String get notifications => 'Bildirimler';

  @override
  String get noNotifications => 'Bildirim yok';

  @override
  String nextLineupIn(int minutes) {
    return 'Sonraki lineup $minutes dk içinde.';
  }

  @override
  String get approvedStat => 'Onaylanan';

  @override
  String get totalStat => 'Toplam';

  @override
  String get cooldownStat => 'BC';

  @override
  String newCount(int count) {
    return '$count yeni';
  }

  @override
  String get link => 'Bağla';

  @override
  String get change => 'Değiştir';

  @override
  String get defaultPlayer => 'Oyuncu';

  @override
  String get favorites => 'Favoriler';

  @override
  String get addToCollection => 'Koleksiyona ekle';

  @override
  String get removeFromFavorites => 'Favorilerden kaldır';

  @override
  String get addToFavorites => 'Favorilere ekle';

  @override
  String get lineupFrom => 'Lineup yazan:';

  @override
  String get description => 'Açıklama';

  @override
  String get screenshots => 'Ekran görüntüleri';

  @override
  String get possiblyOutdated =>
      'Güncel olmayabilir — kullanıcılar güncelsizlik bildiriyor';

  @override
  String get isRelevant => 'Güncel mi?';

  @override
  String get needLevel2 => 'Seviye 2 gerekli';

  @override
  String get loginRequired => 'Hesaba giriş yap';

  @override
  String get votingFromLevel2 =>
      'Oylama seviye 2\'den itibaren kullanılabilir.\n\nAncak reklam izleyebilirsin — ve oyun geçerli sayılır!';

  @override
  String get howToGetLevel2 => 'Seviye 2 nasıl alınır? →';

  @override
  String get loginToVote => 'Oy vermek için giriş yapın.';

  @override
  String get watchAd => '📺 Reklam izle';

  @override
  String get yourVote => 'Oyunuz';

  @override
  String get isLineupRelevant => 'Lineup güncel mi?';

  @override
  String get outdated => 'Güncel değil';

  @override
  String get relevant => 'Güncel';

  @override
  String get authorProfileUnavailable => 'Yazar profili mevcut değil';

  @override
  String get alreadyVoted => 'Bu lineup için zaten oy kullandınız';

  @override
  String get adLoading => 'Reklam yükleniyor, bir saniye sonra dene...';

  @override
  String get voteAccepted => '✅ Oy sayıldı!';

  @override
  String get voteSaveError => 'Oy kaydedilirken hata';

  @override
  String get watchAdFull => 'Reklamı sonuna kadar izle';

  @override
  String get adUnavailable => 'Reklam mevcut değil, daha sonra dene';

  @override
  String get watchAdForAccess => 'Erişim için reklamı sonuna kadar izle';

  @override
  String get adLabel => '📺 reklam';

  @override
  String downloadingPercent(String percent) {
    return 'Yükleniyor $percent%...';
  }

  @override
  String get loadingAd => 'Reklam yükleniyor...';

  @override
  String get savingVideo => 'Video kaydediliyor...';

  @override
  String get savedOffline => 'Kaydedildi — çevrimdışı kullanılabilir';

  @override
  String get onlineOnly => 'Yalnızca çevrimiçi';

  @override
  String get saveOffline => 'Çevrimdışı kaydet';

  @override
  String get videoSaved => 'Video kaydedildi';

  @override
  String get videoLoadError => 'Video yüklenemedi';

  @override
  String get videoComingSoon => 'Video yakında gelecek';

  @override
  String get videoSavedSuccess =>
      '✅ Video kaydedildi — çevrimdışı kullanılabilir!';

  @override
  String get downloadError => 'İndirme hatası, tekrar dene';

  @override
  String get needExclusiveForLike => 'Beğenmek için özel erişim gerekli';

  @override
  String get exclusiveLineup => 'Özel lineup';

  @override
  String get watchAdForExclusive =>
      'Tüm özel lineup\'ları 1 saat açmak için reklam izle';

  @override
  String get watchAdAccessBtn => '▶ Reklam izle → 1 saatlik erişim';

  @override
  String get watchAdForSave =>
      'Videoyu kaydetmek için reklamı sonuna kadar izle';

  @override
  String get thanksForAd => 'Reklamı izlediğiniz için teşekkürler!';

  @override
  String get adHelpsUs => 'Bu uygulamayı geliştirmemize yardımcı oluyor 💪';

  @override
  String patchVersion(String version) {
    return 'Yama $version';
  }

  @override
  String get difficultyEasy => 'Kolay';

  @override
  String get difficultyMedium => 'Orta';

  @override
  String get difficultyHard => 'Zor';

  @override
  String screenshotN(int n) {
    return 'Ekran görüntüsü $n';
  }

  @override
  String get exclusiveTag => '⭐ ÖZEL';

  @override
  String get howToGetLevel2Title => 'Seviye 2 nasıl alınır?';

  @override
  String get xpDesc =>
      'Uygulamaya lineup\'lar yükle — her biri için XP kazanırsın. Yeterli XP topla ve seviye atla.';

  @override
  String get lineupRequirementsTitle => '📋 Lineup gereksinimleri';

  @override
  String get gotItWillPost => 'Anladım, yükleyeceğim!';

  @override
  String get tabMolly => 'Molly\'ler';

  @override
  String get tabReveal => 'Reveal';

  @override
  String get tabSmoky => 'Dumanlar';

  @override
  String get timingsSectionTitle => '⏱ Zamanlamalar';

  @override
  String get searchLineups => 'Lineup ara...';

  @override
  String get nothingFound => 'Hiçbir şey bulunamadı 🔍';

  @override
  String get language => 'Dil';

  @override
  String get languageTitle => 'Language / Язык';

  @override
  String get favoritesLoadError =>
      'Veriler yüklenemedi. İnternetini kontrol edip tekrar dene';

  @override
  String get favoritesEmpty => 'Henüz kaydedilmiş lineup yok';

  @override
  String get favoritesEmptyDesc =>
      'Kaydetmek için herhangi bir lineup\'taki yer imi simgesine dokun';

  @override
  String get feedbackTitle => 'GERİ BİLDİRİM';

  @override
  String get feedbackSendTab => 'Gönder';

  @override
  String get feedbackMyMessages => 'Mesajlarım';
}
