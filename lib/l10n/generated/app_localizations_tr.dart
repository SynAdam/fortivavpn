// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class STr extends S {
  STr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'FortivaVPN';

  @override
  String get statusDisconnected => 'Bağlantı kesildi';

  @override
  String get statusConnecting => 'Bağlanıyor';

  @override
  String get statusConnected => 'Bağlandı';

  @override
  String get statusDisconnecting => 'Bağlantı kesiliyor';

  @override
  String get statusError => 'Hata';

  @override
  String get statusVerifying => 'Doğrulanıyor...';

  @override
  String get disconnect => 'Bağlantıyı Kes';

  @override
  String get connectBtn => 'BAĞLAN';

  @override
  String get disconnectBtn => 'KES';

  @override
  String get pleaseWait => 'LÜTFEN BEKLEYİN';

  @override
  String get locationLabel => 'Konum:';

  @override
  String get selectServer => 'Sunucu Seç';

  @override
  String get serverLocation => 'Sunucu Konumu';

  @override
  String get searchServers => 'Sunucu ara';

  @override
  String get locationsTitle => 'Konumlar';

  @override
  String get sortLatency => 'Sıralama: Gecikme';

  @override
  String get sortAZ => 'Sıralama: A-Z';

  @override
  String get sortedByLatency => 'Gecikmeye göre sıralandı';

  @override
  String get sortedAZ => 'A–Z sıralandı';

  @override
  String get pingAll => 'Tümünü Pingle';

  @override
  String get pinging => 'Pingleniyor...';

  @override
  String get ping => 'Ping';

  @override
  String get stop => 'Durdur';

  @override
  String get fastestServer => 'EN HIZLI SUNUCU';

  @override
  String get timeout => 'zaman aşımı';

  @override
  String get tabCommunity => 'Topluluk';

  @override
  String get tabFree => 'Ücretsiz';

  @override
  String get tabPremium => 'Premium';

  @override
  String get noCommunityServers => 'Topluluk sunucusu yok';

  @override
  String get communityLoadFailed => 'Bu liste yüklenemedi';

  @override
  String get communityRetry => 'Yeniden dene';

  @override
  String get officialTabExplainer =>
      'Fortiva tarafından işletilir ve çevrimiçi tutulur. Uygulamayı kullanan herkesle paylaşılır. Buradan başlayın.';

  @override
  String get communityTabExplainer =>
      'Ek bağlantı seçenekleri. Hız ve erişilebilirlik değişebilir.';

  @override
  String get noFreeServers => 'Ücretsiz sunucu yok';

  @override
  String get noPremiumServers => 'Premium sunucu yok';

  @override
  String noResultsFor(String query) {
    return '\"$query\" için sonuç bulunamadı';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get freeBadge => 'ÜCRETSİZ';

  @override
  String get settings => 'Ayarlar';

  @override
  String get connection => 'Bağlantı';

  @override
  String get dnsConfiguration => 'DNS Yapılandırması';

  @override
  String get customDns => 'Özel DNS sunucuları';

  @override
  String get about => 'Hakkında';

  @override
  String get privacyPolicy => 'Gizlilik Politikası';

  @override
  String get contactUs => 'Bize Ulaşın';

  @override
  String get rateOnGooglePlay => 'Fortiva\'yı Google Play\'de değerlendirin';

  @override
  String get website => 'Web Sitesi';

  @override
  String get copyright => '© 2026 NimusAI';

  @override
  String get version => 'Sürüm';

  @override
  String get language => 'Dil';

  @override
  String get languageSubtitle => 'Uygulama dili';

  @override
  String get whatIsDns => 'DNS Nedir?';

  @override
  String get dnsExplanation =>
      'DNS (Alan Adı Sistemi) internetin telefon rehberidir. Web sitesi adlarını IP adreslerine çevirir.\n\nDNS\'inizi özelleştirmek:\n• Bağlantı hızını artırabilir ⚡\n• Gizliliği güçlendirebilir 🔒\n• Sansür engellerini aşabilir 🌍';

  @override
  String get configuration => 'Yapılandırma';

  @override
  String get primaryDns => 'Birincil DNS';

  @override
  String get primaryDnsHint => 'Varsayılan: 1.1.1.1';

  @override
  String get secondaryDns => 'İkincil DNS (Opsiyonel)';

  @override
  String get secondaryDnsHint => 'Varsayılan: 8.8.8.8';

  @override
  String get saveConfiguration => 'Yapılandırmayı Kaydet';

  @override
  String get dnsSaved => 'DNS Yapılandırması Kaydedildi';

  @override
  String get invalidPrimaryDns => 'Geçersiz Birincil DNS IP adresi';

  @override
  String get invalidSecondaryDns => 'Geçersiz İkincil DNS IP adresi';

  @override
  String get statistics => 'İstatistikler';

  @override
  String get overview => 'GENEL BAKIŞ';

  @override
  String get connectionsLabel => 'Bağlantılar';

  @override
  String get totalTime => 'Toplam Süre';

  @override
  String get dataUsage => 'VERİ KULLANIMI';

  @override
  String get uploaded => 'Yüklenen';

  @override
  String get downloaded => 'İndirilen';

  @override
  String get total => 'Toplam';

  @override
  String lastUpdated(String date) {
    return 'Son güncelleme: $date';
  }

  @override
  String today(String time) {
    return 'Bugün saat $time';
  }

  @override
  String get yesterday => 'Dün';

  @override
  String daysAgo(int count) {
    return '$count gün önce';
  }

  @override
  String get noDataYet => 'Henüz veri yok';

  @override
  String get connectToStart => 'İzlemeyi başlatmak için VPN\'e bağlanın';

  @override
  String get errorConnectionFailed => 'Bağlantı başarısız';

  @override
  String get errorServerNotWorking =>
      'Sunucu çalışmıyor — başka birini deneyin';

  @override
  String get errorServerNotForwarding => 'Sunucu trafiği iletmiyor';

  @override
  String get errorUnexpected => 'Beklenmeyen hata';

  @override
  String get errorDisconnectionFailed => 'Bağlantı kesme başarısız';

  @override
  String get errorFailedToRegister => 'Cihaz kaydı başarısız';

  @override
  String get ipInformation => 'IP Bilgisi';

  @override
  String get connectionAnalytics => 'Bağlantı Analitiği';

  @override
  String get recentSessions => 'Son Oturumlar';

  @override
  String get speedTest => 'Hız Testi';

  @override
  String get startTest => 'Testi Başlat';

  @override
  String get download => 'İndirme';

  @override
  String get upload => 'Yükleme';

  @override
  String get testingViaVpn => 'VPN üzerinden test';

  @override
  String get testingDirect => 'Doğrudan bağlantı testi';

  @override
  String get splitTunneling => 'Bölünmüş Tünel';

  @override
  String get splitTunnelingDescription =>
      'VPN tünelini atlayan uygulama kategorilerini seçin. Dışladığınız uygulamalar VPN yerine normal internet bağlantınızı kullanacaktır.';

  @override
  String get enableSplitTunneling => 'Bölünmüş Tüneli Etkinleştir';

  @override
  String get splitTunnelActive => 'Seçili uygulamalar VPN\'ı atlar';

  @override
  String get splitTunnelInactive => 'Tüm trafik VPN\'dan geçer';

  @override
  String get bypassVpnFor => 'VPN\'ı atla';

  @override
  String get tools => 'Araçlar';

  @override
  String get settingsGeneral => 'Genel';

  @override
  String get shareDiagnosticsTitle => 'Bağlantı tanılamalarını paylaş';

  @override
  String get shareDiagnosticsBody =>
      'Bağlantı raporları, operatörünüz ve ülkeniz, telefon modeli ve Android sürümü, VPN üzerinden girdiğiniz sitelerin adları ve günlük sayıları, ayrıca mesajlarımızı, Premium tekliflerimizi ve davet kartımızı görüp görmediğiniz ya da onlara dokunup dokunmadığınız gönderilir. Açtığınız sayfaları veya gönderdiklerinizi asla görmeyiz.';

  @override
  String get security => 'Güvenlik';

  @override
  String get privacyDashboard => 'Gizlilik Panosu';

  @override
  String get privacyDashboardSubtitle => 'IP bilgisi ve sızıntı koruması';

  @override
  String get connectionAnalyticsSubtitle => 'Oturum geçmişi ve grafikler';

  @override
  String get speedTestSubtitle => 'Bağlantı hızınızı test edin';

  @override
  String get splitTunnelingSubtitle => 'Uygulama VPN yönlendirmesi';

  @override
  String get splashTagline => 'Nerede olursanız olun, özel erişim';

  @override
  String get openSourceLicence => 'Açık kaynak lisansı';

  @override
  String get sourceOfferTitle => 'Açık kaynak lisansı';

  @override
  String get sourceOfferBody =>
      'Fortiva VPN, GNU General Public License v3 kapsamında özgür bir yazılımdır. Xray-core ve diğer açık kaynak projeleri üzerine kuruludur.\n\nYüklediğiniz sürümün eksiksiz kaynak koduna erişme hakkınız vardır. Talep etmek için uygulama sürümünüzü belirterek admin@fortivavpn.com adresine e-posta gönderin. Bu teklif, bu sürümü aldığınız tarihten itibaren üç yıl geçerlidir.';

  @override
  String get close => 'Kapat';

  @override
  String get account => 'Hesap';

  @override
  String get deleteAccount => 'Hesabı sil';

  @override
  String get deleteAccountSubtitle =>
      'Bu cihazı ve verilerinizi kalıcı olarak kaldırın';

  @override
  String get deleteAccountConfirmTitle => 'Hesabınız silinsin mi?';

  @override
  String get deleteAccountConfirmBody =>
      'Bu işlem cihaz kaydınızı, bağlı Google hesabınızı, sizin için oluşturulan kişisel sunucuları ve destek sohbetindeki mesajlarınızı kaldırır. Bu telefondaki bağlantı geçmişi de silinir.\n\nGeri alınamaz. Uygulamayı yeniden açarak istediğiniz zaman baştan başlayabilirsiniz.';

  @override
  String deleteAccountConfirmRetention(int days) {
    return 'Hesap kaydınız hemen silinir. Yedeklerdeki kopyalar ve anonim sunucu kayıtları $days gün içinde temizlenir.';
  }

  @override
  String get deleteAccountConfirmRetentionNoDays =>
      'Hesap kaydınız hemen silinir. Yedeklerdeki kopyalar ve anonim sunucu kayıtları daha sonra, gizlilik politikamızdaki sürelere göre temizlenir.';

  @override
  String get deleteAccountCancel => 'Hesabımı koru';

  @override
  String get deleteAccountConfirm => 'Sil';

  @override
  String get deleteAccountInProgress => 'Hesabınız siliniyor';

  @override
  String get deleteAccountDone => 'Hesabınız silindi.';

  @override
  String get deleteAccountFailed =>
      'Hesabınız silinemedi. Bağlantınızı kontrol edip tekrar deneyin.';

  @override
  String get homeTapToConnect => 'Bağlanmak için dokunun';

  @override
  String get homeChecking => 'Bağlantı kontrol ediliyor';

  @override
  String get homePreparing => 'Sunucunuz hazırlanıyor';

  @override
  String get homeDisconnecting => 'Bağlantı kesiliyor';

  @override
  String get homeFindingPath => 'Yol aranıyor';

  @override
  String get diagCheckingInternet => 'İnternetiniz kontrol ediliyor';

  @override
  String get diagInternationalCut => 'Bu ağda uluslararası internet kesik';

  @override
  String diagPathRow(String city, int n) {
    return '$city, yol $n';
  }

  @override
  String get diagOpen => 'açık';

  @override
  String get diagBlocked => 'engelli';

  @override
  String get diagSkipped => 'bugün atlandı';

  @override
  String diagConnectingThrough(String city) {
    return '$city üzerinden bağlanılıyor';
  }

  @override
  String get diagVerifying => 'Trafik doğrulanıyor';

  @override
  String get diagNoInternet => 'Telefonunuzda şu anda internet yok.';

  @override
  String get diagCutOff =>
      'Ağınız şu anda uluslararası internete erişemiyor. Yeniden denemek için dokunun.';

  @override
  String get diagNothingOpen =>
      'Şu anda tüm yollar engelli. Yeniden denemek için dokunun.';

  @override
  String get homeTryingAgain =>
      'Şu anda tüm yollar engelli. Birazdan yeniden denenecek.';

  @override
  String get homeCutOffTryingAgain =>
      'Ağınız şu anda uluslararası internete erişemiyor. Birazdan yeniden denenecek.';

  @override
  String get homeOfflineTryingAgain =>
      'Telefonunuzda şu anda internet yok. Birazdan yeniden denenecek.';

  @override
  String get diagPathFailed =>
      'Yol açıktı ama tünel kurulamadı. Yeniden denemek için dokunun.';

  @override
  String get openVpnSettings => 'VPN ayarlarını aç';

  @override
  String get yourServer => 'SUNUCUNUZ';

  @override
  String get yourServerCaption => 'Yalnızca size ait. Başka kimse bağlanmaz.';

  @override
  String get ourServer => 'SUNUCUMUZ';

  @override
  String get ourServerCaption =>
      'Fortiva tarafından işletilir ve herkesle paylaşılır. Kendi sunucunuz hazır olana kadar kullanılır.';

  @override
  String get communityServer => 'TOPLULUK SUNUCUSU';

  @override
  String get communityServerCaption =>
      'Ek bir bağlantı seçeneği. Her an çalışmayı bırakabilir.';

  @override
  String communityServerNumber(String n) {
    return 'Topluluk sunucusu $n';
  }

  @override
  String get myServersTitle => 'Sunucularınız';

  @override
  String get myServersExplainer =>
      'Her Fortiva cihazı, her konumda kendi sunucusunu alır ve kimlik bilgileri yalnızca bu kuruluma aittir. Hesap gerekmez.';

  @override
  String get myServersInUse => 'Kullanımda';

  @override
  String get myServersEmpty => 'Henüz sunucu atanmadı';

  @override
  String get myServersRetry => 'Yeniden dene';

  @override
  String get myServersBlockedTitle => 'Bugünkü verinizi kullandınız';

  @override
  String get myServersBlockedWait =>
      'Kotanız otomatik olarak yenilenir. Birazdan tekrar bakın.';

  @override
  String myServersMoved(String place) {
    return 'Şimdi $place kullanılıyor';
  }

  @override
  String get copyLink => 'Bağlantıyı kopyala';

  @override
  String get linkCopied => 'Bağlantı kopyalandı';

  @override
  String quotaUsedToday(String used, String limit) {
    return 'Bugün $limit içinden $used kullanıldı';
  }

  @override
  String get quotaUsedUp => 'Günlük veri tükendi';

  @override
  String get quotaUnlimited => 'Sınırsız veri';

  @override
  String get quotaDaily => 'Günlük veri';

  @override
  String get quotaLimitReached => 'Günlük sınıra ulaşıldı';

  @override
  String quotaLeftOf(String left, String limit) {
    return '$limit içinden $left kaldı';
  }

  @override
  String get quotaResetsShortly => 'Birazdan yenilenir';

  @override
  String quotaResetsInHours(int hours) {
    return '$hours saat sonra yenilenir';
  }

  @override
  String quotaResetsInMinutes(int minutes) {
    return '$minutes dakika sonra yenilenir';
  }

  @override
  String get myServersSubtitle => 'Bu cihaz için ayrılan sunucular';

  @override
  String get sharedServersTitle => 'Paylaşılan sunucular';

  @override
  String get sharedServersSubtitle =>
      'Yedek olarak kullanılan herkese açık konumlar';

  @override
  String get tabOfficial => 'Sunucularımız';

  @override
  String get noOfficialServers => 'Şu anda Fortiva sunucusu yok';

  @override
  String get inviteTitle => 'Arkadaşlarını davet et';

  @override
  String get inviteSubtitle => 'Her gün daha fazla veri kazan';

  @override
  String get inviteYourCode => 'Davet kodun';

  @override
  String get inviteShareAction => 'Daveti paylaş';

  @override
  String get inviteCopyAction => 'Kodu kopyala';

  @override
  String get inviteCodeCopied => 'Kod kopyalandı';

  @override
  String inviteShareMessage(String code, String url) {
    return 'Bende iyi çalışan ücretsiz bir VPN: Fortiva. Kayıt gerekmiyor.\nBu bağlantıdan kur:\n$url\nDavet kodum: $code';
  }

  @override
  String get inviteHowItWorks => 'Nasıl çalışır';

  @override
  String inviteHowItWorksBody(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days farklı gün',
      one: '$days gün',
    );
    return 'Kodunu paylaş. Biri uygulamayı kurup kodu girdiğinde ve VPN\'i $_temp0 kullandığında günlük verine $amount eklenir ve hesabında kalır.';
  }

  @override
  String inviteHowItWorksBodyNoAmount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days farklı gün',
      one: '$days gün',
    );
    return 'Kodunu paylaş. Biri uygulamayı kurup kodu girdiğinde ve VPN\'i $_temp0 kullandığında günlük verin artar ve bu artış hesabında kalır.';
  }

  @override
  String inviteHowItWorksBodyNoDays(String amount) {
    return 'Kodunu paylaş. Biri uygulamayı kurup kodu girdiğinde ve VPN\'i bir süre kullandığında günlük verine $amount eklenir ve hesabında kalır.';
  }

  @override
  String get inviteHowItWorksBodyNoAmountNoDays =>
      'Kodunu paylaş. Biri uygulamayı kurup kodu girdiğinde ve VPN\'i bir süre kullandığında günlük verin artar ve bu artış hesabında kalır.';

  @override
  String inviteHowItWorksCap(String max) {
    return 'Davetlerden günde en fazla $max kazanabilirsin.';
  }

  @override
  String get inviteStatInvited => 'Davet edilen';

  @override
  String get inviteStatEarning => 'Hak kazanan';

  @override
  String get inviteStatBonus => 'Bonus veri';

  @override
  String inviteBonusPerDay(String amount) {
    return 'Her gün +$amount';
  }

  @override
  String get inviteNoBonusYet => 'Henüz bonus yok';

  @override
  String invitePendingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count davet henüz hak kazanmadı',
      one: '1 davet henüz hak kazanmadı',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String inviteJoinedWith(String code) {
    return '$code koduyla katıldın';
  }

  @override
  String get inviteLoadFailed => 'Davet kodun yüklenemedi';

  @override
  String get inviteRetry => 'Tekrar dene';

  @override
  String get inviteHaveCodeTitle => 'Davet kodun var mı?';

  @override
  String inviteHaveCodeSubtitle(int hours) {
    return 'İlk $hours saat içinde gir';
  }

  @override
  String get inviteHaveCodeSubtitleNoHours => 'Kurulumdan kısa süre sonra gir';

  @override
  String get inviteEnterCodeHint => 'Davet kodu';

  @override
  String get inviteApplyAction => 'Uygula';

  @override
  String get inviteNotNowAction => 'Şimdi değil';

  @override
  String inviteClaimAccepted(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days farklı gün',
      one: '$days gün',
    );
    return 'Davet kabul edildi. VPN\'i $_temp0 kullandığında arkadaşın bonus veri kazanacak.';
  }

  @override
  String get inviteClaimAcceptedNoDays =>
      'Davet kabul edildi. VPN\'i bir süre kullandığında arkadaşın bonus veri kazanacak.';

  @override
  String get inviteClaimAlready => 'Bu cihaz zaten bir davet kodu kullandı';

  @override
  String get inviteClaimRejected =>
      'Bu kod işe yaramadı. Kontrol edip tekrar dene';

  @override
  String get inviteClaimNetwork => 'Sunucuya ulaşılamadı. Tekrar dene';

  @override
  String get inviteCardTitle =>
      'Fortiva senin için iyi çalışıyor mu? Arkadaşına gönder';

  @override
  String get inviteCardBody =>
      'Kurulum bağlantısını arkadaşına gönder, o da ücretsiz bağlansın.';

  @override
  String inviteCardReward(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Arkadaşın Fortiva\'yı kullanmaya başladığında $days günlük Premium alırsın.',
      one:
          'Arkadaşın Fortiva\'yı kullanmaya başladığında $days günlük Premium alırsın.',
    );
    return '$_temp0';
  }

  @override
  String get inviteCardRewardNoAmount =>
      'Arkadaşın Fortiva\'yı kullanmaya başladığında hediye olarak Premium alırsın.';

  @override
  String get inviteSendTelegram => 'Telegram';

  @override
  String get inviteSendWhatsApp => 'WhatsApp';

  @override
  String get inviteCopyLink => 'Bağlantıyı kopyala';

  @override
  String get inviteOtherApps => 'Diğer uygulamalar';

  @override
  String get inviteLinkCopied => 'Davet mesajı kopyalandı';

  @override
  String get invitePasteBody =>
      'Arkadaşının mesajındaki kodu kopyala ve buraya yapıştır.';

  @override
  String get invitePasteAction => 'Yapıştır';

  @override
  String get inviteErrorTooLate =>
      'Bu telefonda davet kodu girme süresi doldu.';

  @override
  String get inviteErrorUnknown =>
      'Bu kodu bulamadık. Arkadaşının mesajından tekrar kopyala.';

  @override
  String get inviteErrorOwnCode =>
      'Bu senin kendi kodun. Arkadaşının kodunu gir.';

  @override
  String get inviteErrorMutual =>
      'Sen ve arkadaşın birbirinizi davet edemezsiniz.';

  @override
  String inviteHowItWorksPremium(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Fortiva\'yı kullanmaya başlayan her arkadaşın sana ayrıca $days günlük Premium kazandırır.',
      one:
          'Fortiva\'yı kullanmaya başlayan her arkadaşın sana ayrıca $days günlük Premium kazandırır.',
    );
    return '$_temp0';
  }

  @override
  String inviteHowItWorksPremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Davetlerden en fazla $max günlük Premium kazanabilirsin.',
      one: 'Davetlerden en fazla $max günlük Premium kazanabilirsin.',
    );
    return '$_temp0';
  }

  @override
  String get premiumSourceInvite => 'Davetlerinizle kazanıldı';

  @override
  String quotaBonusIncluded(String amount) {
    return '$amount davet bonusu dahil';
  }

  @override
  String get updateTitle => 'Güncelleme mevcut';

  @override
  String get updateRequiredTitle => 'Güncelleme gerekli';

  @override
  String updateBody(String version) {
    return 'Fortiva $version yayınlandı. En yeni düzeltmeler için güncelleyin.';
  }

  @override
  String get updateRequiredBody =>
      'Bu sürüm artık desteklenmiyor. Fortiva\'yı kullanmaya devam etmek için güncelleyin.';

  @override
  String get updateNow => 'Güncelle';

  @override
  String get updateLater => 'Daha sonra';

  @override
  String get updateFromPlay => 'Google Play';

  @override
  String get updateFromTelegram => 'Telegram kanalı';

  @override
  String get updateConnect => 'Bağlan';

  @override
  String get updateConnectHint =>
      'Google Play veya Telegram açılmıyorsa önce Bağlan\'a dokunun.';

  @override
  String get updateConnected => 'Bağlandınız. Güncellemeyi şimdi indirin.';

  @override
  String get updateReconnect => 'Çalışmıyor mu? Yeniden bağlan';

  @override
  String get updateDisconnect => 'Bağlantıyı kes';

  @override
  String get updateDisconnectHint =>
      'Güncellemeyi normal internetinizle indirmek için Bağlantıyı kes\'e dokunun.';

  @override
  String get updateNotCarrying =>
      'Bağlısınız ama hiçbir şey açılmıyor. Yeniden bağlanmayı deneyin ya da normal internetinizi kullanmak için Bağlantıyı kes\'e dokunun.';

  @override
  String get diagVerdictNoInternet =>
      'Telefonunuzun internet bağlantısı yok. Bağlantı geri gelene kadar Fortiva bağlanamaz.';

  @override
  String get diagVerdictCutOff =>
      'Ağınız şu anda uluslararası internete erişemiyor. Birkaç dakika sonra yeniden deneyin.';

  @override
  String get diagVerdictNeedsPermission =>
      'Fortiva\'nın VPN çalıştırma izni yok ya da başka bir VPN uygulaması her zaman açık olarak ayarlanmış.';

  @override
  String get diagVerdictServerUnreachable =>
      'Bu sunucuya ağınızdan ulaşılamıyor. Ya burada engellenmiş ya da kapalı.';

  @override
  String get diagVerdictBlockedTls =>
      'Bu sunucuya bağlantı, kurulurken kesiliyor. Filtreleme tam olarak böyle görünür.';

  @override
  String get diagVerdictThrottled =>
      'Sunucu her kontrole yanıt verdi ama tünelden yine de hiçbir şey geçmedi. Bağlantı yavaşlatılıyor.';

  @override
  String get diagCheckInternet => 'İnternetinizi kontrol edin';

  @override
  String diagTryServer(String server) {
    return '$server ile yeni arama';
  }

  @override
  String get diagTryAnotherServer => 'Başka bir sunucu deneyin';

  @override
  String get diagDetails => 'Ayrıntılar';

  @override
  String get diagDetailsHide => 'Ayrıntıları gizle';

  @override
  String privateDnsWarning(String host) {
    return 'Özel DNS açık ($host), bu yüzden bazı siteler açılmayabilir. Telefonunuzun ayarlarından Özel DNS\'i kapatın.';
  }

  @override
  String get openNetworkSettings => 'Ağ ayarlarını aç';

  @override
  String testPointStatus(String time, int open, int total) {
    return 'Test noktası · son kontrol $time · $total yoldan $open açık';
  }

  @override
  String get messagesTooltip => 'Mesajlar';

  @override
  String get inboxTitle => 'Mesajlar';

  @override
  String get inboxEmpty => 'Şu anda mesaj yok.';

  @override
  String get messageClose => 'Kapat';

  @override
  String get supportTitle => 'Destek';

  @override
  String get supportTooltip => 'Destekle sohbet edin';

  @override
  String get supportAskAction => 'Desteğe sorun';

  @override
  String get supportContactSubtitle => 'Uygulama içinden bizimle yazışın';

  @override
  String get supportAutomaticNotice =>
      'Yanıtlar otomatik olarak yazılır ve yanlış olabilir.';

  @override
  String get supportStaffNotice =>
      'Otomatik yanıtlar şu anda kapalı. Mesajlarınız ekibimize gider.';

  @override
  String get supportInputHint => 'Sorunuzu yazın';

  @override
  String get supportInputHintTeam => 'Ekibimize yazın';

  @override
  String get supportSend => 'Gönder';

  @override
  String supportQuotaLeft(int remaining, int limit) {
    return 'Bugün $limit sorudan $remaining tanesi kaldı';
  }

  @override
  String supportWaitIn(String time) {
    return '$time sonra yeniden sorabilirsiniz.';
  }

  @override
  String supportDurationHours(int hours, int minutes) {
    return '$hours sa $minutes dk';
  }

  @override
  String supportDurationMinutes(int minutes) {
    return '$minutes dk';
  }

  @override
  String get supportNewConversation => 'Yeni sohbet';

  @override
  String get supportSending => 'Gönderiliyor';

  @override
  String get supportNotSent => 'Gönderilemedi. Yeniden denemek için dokunun.';

  @override
  String get supportRateUp => 'Faydalı';

  @override
  String get supportRateDown => 'Faydalı değil';

  @override
  String get supportRatedDown => 'Teşekkürler. Ekibimiz bu yanıtı inceleyecek.';

  @override
  String get supportTeamLabel => 'Fortiva ekibi';

  @override
  String get supportUnavailable => 'Sohbet şu anda kullanılamıyor.';

  @override
  String get supportOpenTelegram => 'Bize Telegram\'dan yazın';

  @override
  String get supportGenericError => 'Bir sorun oluştu. Lütfen yeniden deneyin.';

  @override
  String supportCodeTooLong(int max) {
    return 'Mesajınız çok uzun. Lütfen $max karakterin altında tutun.';
  }

  @override
  String get supportCodeEmpty => 'Mesajınız boş.';

  @override
  String get supportCodeWaitReply =>
      'Lütfen önceki sorunuzun yanıtını bekleyin.';

  @override
  String get supportCodeSlowDown =>
      'Çok hızlı mesaj gönderiyorsunuz. Lütfen biraz bekleyin.';

  @override
  String get supportCodeQuotaDay => 'Bugünkü tüm sorularınızı kullandınız.';

  @override
  String get supportCodePaused => 'Otomatik yanıtlar şimdilik durduruldu.';

  @override
  String get supportCodeBusy =>
      'Asistanımız şu anda meşgul. Birkaç dakika sonra yeniden deneyin.';

  @override
  String get supportCodeGreeting =>
      'Merhaba! Fortiva konusunda size nasıl yardımcı olabilirim?';

  @override
  String get supportCodeGibberish =>
      'Üzgünüm, anlayamadım. Lütfen sorunuzu yeniden yazın.';

  @override
  String get supportCodeRedacted =>
      'Mesajınızdaki kişisel bilgileri ve bağlantıları kaldırdık.';

  @override
  String get supportCodeRedactedEmpty =>
      'Mesajınızda yalnızca kişisel bilgiler veya bağlantılar vardı, bu yüzden gönderilmedi. Lütfen sorunu kelimelerle anlatın.';

  @override
  String get supportCodeOffTopic =>
      'Yalnızca Fortiva\'nın kullanımıyla ilgili sorularda yardımcı olabilirim.';

  @override
  String get supportCodeAbuse =>
      'Saygılı kalalım. Fortiva konusunda yardımcı olmak için buradayım.';

  @override
  String get supportCodeAiUnavailable =>
      'Asistan bu sefer yanıt veremedi. Biraz sonra yeniden deneyin.';

  @override
  String get supportCodeToStaff =>
      'Ekibimize gönderildi. Yanıtları burada görünecek.';

  @override
  String get supportCodeTicketOpened =>
      'Sorunuzu ekibimize ilettik. Yanıtları burada görünecek.';

  @override
  String get supportCodeNotSent =>
      'Bu mesaj gönderilemedi. Hâlâ yardıma ihtiyacınız varsa yeniden yazın.';

  @override
  String get supportAssistantSubtitle => 'Yapay zekâ asistanı';

  @override
  String get supportThinkingReading => 'Sorunuzu okuyorum';

  @override
  String get supportThinkingSearching => 'Cevabı arıyorum';

  @override
  String get supportThinkingWriting => 'Cevabı yazıyorum';

  @override
  String get supportThinkingStill =>
      'Hâlâ üzerinde çalışıyorum, beklediğiniz için teşekkürler';

  @override
  String get supportSuggestConnect => 'Bağlanamıyorum';

  @override
  String get supportSuggestData => 'Bugün ne kadar verim var?';

  @override
  String get supportSuggestSlow => 'Bağlantım yavaş';

  @override
  String get supportWithTeam => 'Bu konuşma artık ekibimizde.';

  @override
  String get supportTryAgainSoon => 'Birkaç dakika sonra yeniden deneyin.';

  @override
  String supportDurationWholeHours(int hours) {
    return '$hours sa';
  }

  @override
  String get supportUnreadReply => 'Yeni yanıt var';

  @override
  String get premiumTitle => 'Premium';

  @override
  String get premiumTileSubtitle => 'Sınırsız veri, günlük sınır yok';

  @override
  String get premiumTileActive => 'Premium açık';

  @override
  String get premiumGetUnlimited => 'Sınırsız alın';

  @override
  String get premiumHeadline => 'Sınırsız veri alın';

  @override
  String get premiumPitch =>
      'Premium günlük sınırı kaldırır; süresi bitene kadar istediğiniz kadar veri kullanabilirsiniz.';

  @override
  String get premiumActiveTitle => 'Premium açık';

  @override
  String premiumActiveUntil(String date) {
    return '$date tarihine kadar sınırsız veri';
  }

  @override
  String get premiumActiveNoDate => 'Sınırsız veri';

  @override
  String get premiumRenews => 'Google Play üzerinden otomatik olarak yenilenir';

  @override
  String get premiumSourceKey => 'Anahtarla etkinleştirildi';

  @override
  String get premiumSourceCrypto => 'Kriptoyla ödendi';

  @override
  String get premiumSourceStars => 'Telegram Yıldızlarıyla ödendi';

  @override
  String get premiumSourceGooglePlay => 'Google Play üzerinden ödendi';

  @override
  String get premiumSourceManual => 'Fortiva ekibinden bir hediye';

  @override
  String get premiumYourKey => 'Anahtarınız';

  @override
  String get premiumKeyHint =>
      'Bu anahtarı saklayın. Premium\'u başka bir telefona taşımak için anahtarı orada girin.';

  @override
  String premiumKeyMoves(int count, int days) {
    return 'Bir anahtar $days gün içinde en fazla $count kez başka bir telefona taşınabilir.';
  }

  @override
  String get premiumKeyMovesNoNumber =>
      'Bir anahtar başka bir telefona yalnızca sınırlı sayıda taşınabilir.';

  @override
  String get premiumCopy => 'Kopyala';

  @override
  String get premiumCopied => 'Kopyalandı';

  @override
  String get premiumChoosePlan => 'Bir plan seçin';

  @override
  String premiumPlanDays(int days) {
    return '$days gün sınırsız veri';
  }

  @override
  String get premiumPlanNoDays => 'Sınırsız veri';

  @override
  String get premiumBuy => 'Satın al';

  @override
  String get premiumPlayUnavailable =>
      'Google Play şu anda kullanılamıyor. Daha sonra tekrar deneyin.';

  @override
  String get premiumPlayPending =>
      'Ödemeniz Google Play\'de beklemede. Tamamlanır tamamlanmaz Premium başlar.';

  @override
  String get premiumPlayConfirming => 'Satın alma onaylanıyor...';

  @override
  String get premiumPlayRetrying =>
      'Ödeme yapıldı ama henüz onaylayamadık. Denemeye devam edeceğiz, tekrar ödemenize gerek yok.';

  @override
  String get premiumPlayRefused =>
      'Bu satın almayı onaylayamadık. Sizden ücret alındıysa destekle iletişime geçin.';

  @override
  String get premiumPlayNotAvailable =>
      'Premium şu anda bu telefonda kullanılamıyor. Sizden ücret alındıysa destekle iletişime geçin.';

  @override
  String get premiumNotAvailable =>
      'Premium şu anda bu telefonda kullanılamıyor.';

  @override
  String get premiumPlayFailed => 'Satın alma tamamlanmadı. Tekrar deneyin.';

  @override
  String get premiumNowOn => 'Premium açık. Sınırsız verinin keyfini çıkarın.';

  @override
  String get premiumRestore => 'Satın alımları geri yükle';

  @override
  String get premiumRestoreDone => 'Satın alımınız bu telefonda geri yüklendi.';

  @override
  String get premiumRestoreNone =>
      'Bu Google hesabında geri yüklenecek bir satın alım yok.';

  @override
  String get premiumRestoreFailed =>
      'Satın alım geri yüklenemedi. Daha sonra tekrar deneyin.';

  @override
  String premiumRenewsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Her $count günde bir ücretlendirilir. İptal edene kadar otomatik olarak yenilenir.',
      one:
          'Her gün ücretlendirilir. İptal edene kadar otomatik olarak yenilenir.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Her $count haftada bir ücretlendirilir. İptal edene kadar otomatik olarak yenilenir.',
      one:
          'Her hafta ücretlendirilir. İptal edene kadar otomatik olarak yenilenir.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Her $count ayda bir ücretlendirilir. İptal edene kadar otomatik olarak yenilenir.',
      one:
          'Her ay ücretlendirilir. İptal edene kadar otomatik olarak yenilenir.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Her $count yılda bir ücretlendirilir. İptal edene kadar otomatik olarak yenilenir.',
      one:
          'Her yıl ücretlendirilir. İptal edene kadar otomatik olarak yenilenir.',
    );
    return '$_temp0';
  }

  @override
  String get premiumRenewsNoPeriod =>
      'İptal edene kadar otomatik olarak yenilenir.';

  @override
  String get premiumPlayCancelNote =>
      'Google Play\'den istediğiniz zaman iptal edebilirsiniz. Premium, ödediğiniz sürenin sonuna kadar açık kalır.';

  @override
  String get premiumManageSubscription => 'Aboneliği yönet veya iptal et';

  @override
  String get premiumCurrentPlan => 'Mevcut plan';

  @override
  String get premiumPlaySubscribed =>
      'Zaten bir Google Play aboneliğiniz var. Google Play\'den yönetebilir veya iptal edebilirsiniz.';

  @override
  String get premiumEnterCode => 'Kod girin';

  @override
  String get premiumNeedsPlayVersion =>
      'Google Play üzerinden satın almak için Fortiva\'nın Google Play sürümü gerekir.';

  @override
  String get premiumOff => 'Premium şu anda satışta değil.';

  @override
  String get premiumLoadFailed =>
      'Premium yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.';

  @override
  String get premiumRetry => 'Tekrar deneyin';

  @override
  String premiumPriceUsdt(String price) {
    return '$price USDT';
  }

  @override
  String premiumPriceStars(String stars) {
    return '$stars Telegram Yıldızı';
  }

  @override
  String get premiumPayCrypto => 'Kriptoyla öde';

  @override
  String get premiumTelegramTitle => 'Telegram\'da ödeyin';

  @override
  String get premiumTelegramBody =>
      'Botumuzda Telegram Yıldızlarıyla ödeyin. Bir anahtar alırsınız ve Premium bu telefonda hemen başlar.';

  @override
  String get premiumTelegramButton => 'Telegram\'da satın al';

  @override
  String get premiumTelegramFailed => 'Telegram açılamadı. Tekrar deneyin.';

  @override
  String get checkoutTitle => 'Kriptoyla öde';

  @override
  String get checkoutChooseNetwork => 'Göndereceğiniz ağı seçin';

  @override
  String get checkoutContinue => 'Devam';

  @override
  String get checkoutSendExactly => 'Tam olarak bu tutarı gönderin';

  @override
  String get checkoutNetwork => 'Ağ';

  @override
  String get checkoutAddress => 'Bu adrese';

  @override
  String get checkoutMemo => 'Bu memo ile';

  @override
  String get checkoutMemoWarning =>
      'Bu memoyu transferinize mutlaka ekleyin, yoksa ödemeyi sizinle eşleştiremeyiz.';

  @override
  String get checkoutExactWarning =>
      'Tutarın aynısını ve yalnızca bu ağda gönderin. Farklı bir tutar ya da ağ bize ulaşmayabilir.';

  @override
  String checkoutTimeLeft(String time) {
    return 'Kalan süre: $time';
  }

  @override
  String get checkoutWaiting =>
      'Ödemeniz bekleniyor. Bu sayfa kendiliğinden güncellenir.';

  @override
  String get checkoutPaidTitle => 'Ödeme alındı';

  @override
  String get checkoutPaidKeyOnly =>
      'Anahtarınız hazır. Premium alması gereken telefona girin.';

  @override
  String get checkoutDone => 'Tamam';

  @override
  String get checkoutExpired =>
      'Bu siparişin süresi doldu. Zaten ödediyseniz destekle iletişime geçin.';

  @override
  String get checkoutUnderpaid =>
      'Tutarın tamamından daha azını aldık. Destekle iletişime geçin ve bu sipariş numarasını verin:';

  @override
  String get checkoutCanceled => 'Bu sipariş iptal edildi.';

  @override
  String get checkoutStartAgain => 'Yeniden başlat';

  @override
  String get checkoutUnavailable => 'Kriptoyla ödeme şu anda kullanılamıyor.';

  @override
  String get checkoutTooManyOpen =>
      'Ödenmemiş çok fazla siparişiniz var. Birini ödeyin ya da süreleri dolana kadar bekleyin.';

  @override
  String get checkoutUnknownPlan =>
      'Bu plan artık satışta değil. Geri dönüp başka bir plan seçin.';

  @override
  String get checkoutFailed =>
      'Ödeme başlatılamadı. Bağlantınızı kontrol edip tekrar deneyin.';

  @override
  String get redeemTitle => 'Kod girin';

  @override
  String get redeemSubtitle => 'Premium anahtarı ya da hediye kodu';

  @override
  String get redeemHint => 'Kod';

  @override
  String get redeemApply => 'Uygula';

  @override
  String get redeemCancel => 'İptal';

  @override
  String get redeemInvalid =>
      'Bu bir koda benzemiyor. Kontrol edip tekrar deneyin.';

  @override
  String get redeemUnknown =>
      'Bu kodu tanımıyoruz. Kontrol edip tekrar deneyin.';

  @override
  String get redeemExpired => 'Bu kodun süresi dolmuş.';

  @override
  String get redeemRevoked => 'Bu kod artık geçerli değil.';

  @override
  String get redeemMovedTooOften =>
      'Bu anahtar son zamanlarda telefonlar arasında çok sık taşındı. Daha sonra tekrar deneyin.';

  @override
  String get redeemExhausted => 'Bu kodun kullanım hakkı bitti.';

  @override
  String get redeemAlreadyUsed => 'Bu telefon bu kodu zaten kullandı.';

  @override
  String get redeemUnmetered =>
      'Bu telefonda zaten sınırsız veri var, bu koda gerek yok.';

  @override
  String get redeemRateLimited =>
      'Çok fazla deneme yapıldı. Biraz bekleyip tekrar deneyin.';

  @override
  String get redeemUnavailable =>
      'Bu özellik şu anda kullanılamıyor. Daha sonra tekrar deneyin.';

  @override
  String get redeemNetwork =>
      'Sunucuya ulaşılamadı. Bağlantınızı kontrol edip tekrar deneyin.';

  @override
  String get redeemFailed =>
      'Bu kod işe yaramadı. Kontrol edip tekrar deneyin.';

  @override
  String get redeemMoved => 'Premium bu telefona taşındı.';

  @override
  String redeemPromo(String amount) {
    return 'Kod kabul edildi. $amount ek veri eklendi.';
  }

  @override
  String get redeemPromoNoAmount => 'Kod kabul edildi. Ek veri eklendi.';

  @override
  String get tvScanTitle => 'Telefonunda aç';

  @override
  String get tvScanBody => 'Telefonunun kamerasını bu koda tut.';

  @override
  String get refresh => 'Yenile';

  @override
  String get premiumNotNow => 'Şimdi değil';

  @override
  String get premiumLimitSheetTitle => 'Bugünkü veriniz bitti';

  @override
  String get premiumLimitWait => 'Yenilenmesini bekleyin';

  @override
  String get premiumLimitInvite =>
      'Daha fazla veri için arkadaşlarınızı davet edin';

  @override
  String get premiumNoDailyLimit => 'Premium\'da günlük sınır yok.';

  @override
  String get premiumCalmTitle => 'Günlük sınırdan kurtulmak ister misiniz?';

  @override
  String get premiumCalmBody =>
      'Premium ile sınırsız veriniz olur. Ücretsiz planınız olduğu gibi kalır.';

  @override
  String get premiumNextStepTitle => 'Sıradaki adım Premium';

  @override
  String get premiumNextStepBody =>
      'Zaten en fazla ücretsiz veriye sahipsiniz. Premium\'da günlük sınır yok.';

  @override
  String get premiumLockedTag => 'Premium';

  @override
  String premiumLockedTitle(String place) {
    return '$place konumunun kilidini Premium ile açın';
  }

  @override
  String get premiumLockedBody =>
      'Bu konum Premium\'a özel. Ücretsiz sunucularınız aynı kalır.';

  @override
  String get premiumHeadlineLimit => 'Günlük sınır yok';

  @override
  String premiumHeadlineLocked(String place) {
    return '$place konumunun kilidini Premium ile açın';
  }

  @override
  String get premiumFreeStays =>
      'Ücretsiz plan Premium olmadan da çalışmaya devam eder.';

  @override
  String premiumEndsOn(String date) {
    return 'Premium $date tarihinde bitiyor';
  }

  @override
  String get premiumRenewBody =>
      'Sınırsız veriyi korumak için yenileyin. Yenileme, süreyi mevcut bitiş tarihinize ekler.';

  @override
  String premiumEndedOn(String date) {
    return 'Premium $date tarihinde bitti. Ücretsiz planınız geri döndü.';
  }

  @override
  String get premiumRenew => 'Yenile';

  @override
  String get noticeChannelName => 'Fortiva\'dan mesajlar';

  @override
  String get noticeChannelDescription =>
      'Fortiva ekibinden haberler ve mesajlar';

  @override
  String get noticesSettingTitle => 'Bildirimler';

  @override
  String get noticesSettingOn =>
      'Açık. Fortiva ekibinin mesajları uygulama kapalıyken de size ulaşabilir.';

  @override
  String get noticesSettingOff =>
      'Kapalı. Fortiva ekibinin mesajlarını uygulama kapalıyken de almak için açın.';

  @override
  String get noticesOffCard =>
      'Fortiva ekibinin mesajlarını uygulama kapalıyken de almak için bildirimleri açın.';

  @override
  String get noticesTurnOn => 'Aç';

  @override
  String get backgroundCard =>
      'Telefonunuz, uygulama kapalıyken Fortiva ekibinin mesajlarını bekletebilir. Mesajların size ulaşması için Fortiva\'nın arka planda çalışmasına izin verin.';

  @override
  String get backgroundHint =>
      'Sonraki ekranda Fortiva\'yı seçin (listede yoksa tüm uygulamaları gösterin). Ardından pil kullanımını Kısıtlanmamış yapın ya da otomatik başlamasına ve arka planda çalışmasına izin verin.';

  @override
  String get backgroundAllow => 'İzin ver';

  @override
  String get backgroundNotNow => 'Şimdi değil';

  @override
  String get backgroundSettingTitle => 'Uygulama kapalıyken mesajlar';

  @override
  String get backgroundSettingSubtitle =>
      'Uygulama kapalıyken de mesajların size ulaşması için Fortiva\'nın arka planda çalışmasına izin verin.';

  @override
  String get backgroundCardData =>
      'Telefonunuzdaki Veri Tasarrufu, uygulama kapalıyken Fortiva ekibinin mesajlarını engelleyebilir.';

  @override
  String get backgroundHintData =>
      'Sonraki ekranda Kısıtlanmamış veri kullanımını açın.';

  @override
  String get apnGuideTitle => 'Bu SIM\'de daha kararlı bağlantı';

  @override
  String get apnGuideBody =>
      'Telefonunuz bu SIM\'de IPv6 kullanmıyor. Açmanız, Fortiva\'nın bağlı kalmasına yardımcı olur.';

  @override
  String get apnGuideShowMe => 'Nasıl yapılacağını göster';

  @override
  String get apnGuideNotNow => 'Şimdi değil';

  @override
  String get apnGuideSheetTitle => 'Bu SIM için IPv6\'yı açın';

  @override
  String apnGuideStepOpen(String button) {
    return '\"$button\" seçeneğine dokunun (veya Ayarlar > Bağlantılar > Mobil ağlar > Erişim Noktası Adları\'na gidin).';
  }

  @override
  String apnGuideStepAccessPoint(String apn) {
    return 'Kullanılan erişim noktasına ($apn) dokunun.';
  }

  @override
  String get apnGuideStepAccessPointAny =>
      'Kullanılan erişim noktasına dokunun.';

  @override
  String get apnGuideStepProtocol =>
      '\"APN protokolü\" seçeneğine dokunun ve \"IPv4/IPv6\" seçin.';

  @override
  String get apnGuideStepSave =>
      'Kaydedin (Samsung\'da: üç nokta menüsü, ardından \"Kaydet\").';

  @override
  String get apnGuideStepRestart => 'Mobil veriyi kapatıp yeniden açın.';

  @override
  String get apnGuideUndo =>
      'Mobil veri çalışmayı bırakırsa APN protokolünü yeniden IPv4 yapın.';

  @override
  String get apnGuideOpenSettings => 'APN ayarlarını aç';

  @override
  String get homeStallSearching =>
      'Bağlantı çalışmayı bıraktı. Başka bir yol aranıyor.';

  @override
  String get homeStalled => 'Bağlı, ancak veri geçmiyor';

  @override
  String get peerShareTitle => 'Arkadaşının bağlanmasına yardım et';

  @override
  String get peerShareSubtitle =>
      'Fortiva\'nın ihtiyacı olanı arkadaşının telefonuna aktar';

  @override
  String get peerShareBody =>
      'Arkadaşınızın Fortiva\'sı bağlanamıyorsa, telefonu ihtiyacı olanı sizin telefonunuzdan alabilir. Bu, internet olmadan da çalışır.';

  @override
  String peerShareSteps(String action) {
    return 'Arkadaşınızın telefonunda Fortiva\'daki Ayarlar\'ı açın ve \"$action\" seçeneğine dokunun. Sonra bu kodları ona sırayla gösterin ya da bunu ona gönderin.';
  }

  @override
  String get peerShareLoading => 'En yeni kopya alınıyor';

  @override
  String get peerShareNothing =>
      'Bu telefonda aktarılacak yeni bir şey yok. Daha sonra tekrar deneyin.';

  @override
  String peerShareCodeOf(int current, int total) {
    return 'Kod $current / $total';
  }

  @override
  String get peerSharePrevious => 'Önceki';

  @override
  String get peerShareNext => 'Sonraki';

  @override
  String get peerShareCopy => 'Kopyala';

  @override
  String get peerShareSend => 'Gönder';

  @override
  String get peerShareCopied =>
      'Kopyalandı. Arkadaşınıza göndereceğiniz mesaja yapıştırın.';

  @override
  String get peerReceiveTitle => 'Arkadaşından yardım al';

  @override
  String get peerReceiveSubtitle => 'Başka yolla bağlanamadığında';

  @override
  String peerReceiveBody(String action) {
    return 'Fortiva\'sı bağlanan arkadaşınızdan Fortiva\'daki Ayarlar\'ı açıp \"$action\" seçeneğine dokunmasını isteyin. Sonra aşağıdaki yollardan biriyle bunu onun telefonundan alın.';
  }

  @override
  String get peerReceivePhotograph => 'Kodların fotoğrafını çek';

  @override
  String get peerReceivePhotographNext => 'Sonraki kodun fotoğrafını çek';

  @override
  String peerReceiveProgress(int have, int total) {
    return '$total koddan $have tanesi okundu';
  }

  @override
  String get peerReceiveFile => 'Gönderilen dosyayı aç';

  @override
  String get peerReceivePaste => 'Gönderileni yapıştır';

  @override
  String get peerReceiveNoCode =>
      'Bu fotoğrafta kod bulunamadı. Telefonu yaklaştırın ve kodun tamamının göründüğünden emin olun.';

  @override
  String get peerReceiveRefused =>
      'Fortiva bunu kullanamıyor. Arkadaşınızdan tekrar göndermesini isteyin.';

  @override
  String get peerReceiveNotNewer =>
      'Bu ya da daha yenisi sizde zaten var. Yeniden bağlanmayı deneyin ya da diğer arkadaşlarınızdan yardım isteyin.';

  @override
  String get peerReceiveTaken => 'Tamamlandı. Bağlanmak için düğmeye dokunun.';

  @override
  String get peerReceiveUnavailable =>
      'Bu telefon bunu yapamıyor. Başka bir yol deneyin.';

  @override
  String get peerReceiveNothingToPaste =>
      'Henüz bir şey kopyalanmadı. Arkadaşınızın gönderdiğini kopyalayın, sonra buraya tekrar dokunun.';

  @override
  String get peerOfferBody =>
      'Hâlâ bağlanamıyor musunuz? Fortiva\'sı çalışan arkadaşınız kendi telefonundan yardım edebilir.';

  @override
  String get peerReceiveAgain =>
      'Bu kod sizde zaten var. Arkadaşınızdan sonraki kodu göstermesini isteyin.';

  @override
  String get peerReceivePasteNotOurs =>
      'Kopyaladığınız şey Fortiva\'dan değil. Arkadaşınızın mesajının tamamını kopyalayın, sonra tekrar deneyin.';

  @override
  String peerReceiveNoPhoto(String action) {
    return 'Fotoğraf kameradan gelmedi. Fotoğrafı kamera uygulamasıyla çekin, sonra \"$action\" düğmesine dokunun.';
  }

  @override
  String get peerReceiveFileHint =>
      'Mesajlaşma uygulamasından gelen dosyayı önce İndirilenler klasörüne kaydetmeniz gerekebilir.';

  @override
  String get homeTryingBackup =>
      'Başka hiçbir şey bağlanmadı. Şimdi yedek bir ağ deneniyor.';

  @override
  String get homeConnectedBackup => 'Yedek bir ağ üzerinden bağlandı';

  @override
  String get backupNetwork => 'YEDEK AĞ';

  @override
  String get backupNetworkTitle => 'Yedek ağ';

  @override
  String get backupNetworkCaption =>
      'Başka hiçbir şey bağlanmadığında kullanılır. Sunucularımızdan daha yavaş olabilir.';

  @override
  String get backupNetworkPlace => 'Konum otomatik seçilir';

  @override
  String get speedTestStart => 'Testi başlat';

  @override
  String get speedTestAgain => 'Tekrar test et';

  @override
  String get speedTestRunning => 'Test ediliyor';

  @override
  String get speedTestIdle =>
      'Bağlantınızın şu anda ne kadar hızlı olduğunu görün.';

  @override
  String get speedTestPhasePing => 'Yanıt süresi kontrol ediliyor';

  @override
  String get speedTestPhaseDownload => 'İndirme hızı ölçülüyor';

  @override
  String get speedTestPhaseUpload => 'Yükleme hızı ölçülüyor';

  @override
  String get speedTestDone => 'Test tamamlandı';

  @override
  String get speedTestFailed =>
      'Test tamamlanamadı. İnternetinizi kontrol edip tekrar deneyin.';

  @override
  String get speedTestUnit => 'Mbps';

  @override
  String get ipAddressLabel => 'IP adresi';

  @override
  String get ipCopied => 'Adres kopyalandı';

  @override
  String get ipLocation => 'Konum';

  @override
  String get ipProvider => 'İnternet sağlayıcısı';

  @override
  String get ipOrganization => 'Kuruluş';

  @override
  String get ipTimeZone => 'Saat dilimi';

  @override
  String get ipCoordinates => 'Koordinatlar';

  @override
  String get ipCheckFailed => 'Adresiniz kontrol edilemedi';

  @override
  String get historyAverage => 'Ortalama';

  @override
  String get historyRecentDays => 'Son günler';

  @override
  String yesterdayAt(String time) {
    return 'Dün saat $time';
  }

  @override
  String dateAt(String date, String time) {
    return '$date saat $time';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds sn';
  }

  @override
  String get stageOwn => 'Fortiva sunucuları';

  @override
  String get stageCommunity => 'Topluluk sunucuları';

  @override
  String stageProgress(int n, int total) {
    return 'Aşama $n / $total';
  }

  @override
  String get stageTryingOwn => 'Fortiva sunucuları deneniyor';

  @override
  String get stageTryingCommunity => 'Topluluk sunucuları deneniyor';

  @override
  String get stageOwnFailedTryingCommunity =>
      'Fortiva sunucuları burada bağlanmadı. Şimdi topluluk sunucuları deneniyor.';

  @override
  String stageLastWorked(String server) {
    return 'En son çalışan sunucu: $server';
  }

  @override
  String stageTriedBlocked(int count) {
    return '$count yol denendi, burada engelli';
  }

  @override
  String stageTriedFailed(int count) {
    return '$count yol denendi, hiçbiri bağlanmadı';
  }

  @override
  String get stageNotConnected => 'Bağlanmadı';

  @override
  String get stageConnected => 'Burada bağlandı';

  @override
  String get stageSkipped => 'Bu sefer atlandı';

  @override
  String stageMoreToCheck(int count) {
    return '$count yol daha denenecek';
  }

  @override
  String stageNextTry(String stage, String time) {
    return 'Sonraki deneme $time sonra, $stage ile başlayacak';
  }

  @override
  String get searchSlowHint =>
      'Bu bir iki dakika sürebilir. Aramayı durdurmak için düğmeye dokunun.';

  @override
  String get searchStopped => 'Arama durduruldu';

  @override
  String get homeConnectedCommunity =>
      'Bir topluluk sunucusu üzerinden bağlandı';

  @override
  String get stageGettingServers => 'Sunucularınız alınıyor';

  @override
  String stageNextTryStarting(String stage) {
    return 'Sonraki deneme şimdi $stage ile başlıyor';
  }
}
