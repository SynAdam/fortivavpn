// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class SUz extends S {
  SUz([String locale = 'uz']) : super(locale);

  @override
  String get appTitle => 'Fortiva';

  @override
  String get statusDisconnected => 'Ulanmagan';

  @override
  String get statusConnecting => 'Ulanmoqda';

  @override
  String get statusConnected => 'Ulandi';

  @override
  String get statusDisconnecting => 'Uzilmoqda...';

  @override
  String get statusError => 'Xato';

  @override
  String get statusVerifying => 'Tekshirilmoqda...';

  @override
  String get disconnect => 'Toʻxtatish';

  @override
  String get connectBtn => 'Ulanish';

  @override
  String get disconnectBtn => 'Uzish';

  @override
  String get pleaseWait => 'ILTIMOS, KUTING';

  @override
  String get locationLabel => 'Joylashuv';

  @override
  String get selectServer => 'Joylashuvni tanlang';

  @override
  String get serverLocation => 'Joylashuv';

  @override
  String get searchServers => 'Serverlarni qidirish';

  @override
  String get locationsTitle => 'Joylashuvlar';

  @override
  String get sortLatency => 'Saralash: kechikish';

  @override
  String get sortAZ => 'Saralash: A-Z';

  @override
  String get sortedByLatency => 'Kechikish boʻyicha saralandi';

  @override
  String get sortedAZ => 'A-Z boʻyicha saralandi';

  @override
  String get pingAll => 'Hammasini tekshirish';

  @override
  String get pinging => 'Ping yuborilmoqda...';

  @override
  String get ping => 'Ping';

  @override
  String get stop => 'Toʻxtatish';

  @override
  String get fastestServer => 'Eng tez';

  @override
  String get timeout => 'vaqt tugadi';

  @override
  String get tabCommunity => 'Hamjamiyat';

  @override
  String get tabFree => 'Bepul';

  @override
  String get tabPremium => 'Premium';

  @override
  String get noCommunityServers => 'Hamjamiyat serverlari hali yoʻq';

  @override
  String get communityLoadFailed => 'Bu roʻyxatni yuklab boʻlmadi';

  @override
  String get communityRetry => 'Qayta urinish';

  @override
  String get officialTabExplainer =>
      'Fortiva tomonidan boshqariladi va biz uni onlayn saqlab turamiz. Ilovadan foydalanadigan hamma bilan birgalikda ishlatiladi. Shu yerdan boshlang.';

  @override
  String get communityTabExplainer =>
      'Qoʻshimcha ulanish imkoniyatlari. Tezlik va mavjudlik har xil boʻlishi mumkin.';

  @override
  String get noFreeServers => 'Bepul serverlar hali yoʻq';

  @override
  String get noPremiumServers => 'Premium serverlar hali yoʻq';

  @override
  String noResultsFor(String query) {
    return '\"$query\" boʻyicha natija topilmadi';
  }

  @override
  String get proBadge => 'PREMIUM';

  @override
  String get freeBadge => 'BEPUL';

  @override
  String get settings => 'Sozlamalar';

  @override
  String get connection => 'Tarmoq';

  @override
  String get dnsConfiguration => 'DNS';

  @override
  String get customDns => 'Oʻz DNS serverlaringizdan foydalanish';

  @override
  String get about => 'Ilova haqida';

  @override
  String get privacyPolicy => 'Maxfiylik siyosati';

  @override
  String get contactUs => 'Biz bilan bogʻlanish';

  @override
  String get rateOnGooglePlay =>
      'Fortiva ilovasini Google Play orqali baholang';

  @override
  String get website => 'Veb-sayt';

  @override
  String get copyright => '© 2026 NimusAI';

  @override
  String get version => 'Versiya';

  @override
  String get language => 'Til';

  @override
  String get languageSubtitle => 'Interfeys tili';

  @override
  String get whatIsDns => 'DNS nima?';

  @override
  String get dnsExplanation =>
      'DNS sayt nomlarini telefoningiz ulana oladigan manzillarga aylantiradi. Boshqa DNS ishlatish saytlarni tezroq yuklashi va provayderingiz bloklagan saytlarga kirishga yordam berishi mumkin.';

  @override
  String get configuration => 'Sozlamalar';

  @override
  String get primaryDns => 'Asosiy DNS';

  @override
  String get primaryDnsHint => 'Standart: 1.1.1.1';

  @override
  String get secondaryDns => 'Qoʻshimcha DNS (ixtiyoriy)';

  @override
  String get secondaryDnsHint => 'Standart: 8.8.8.8';

  @override
  String get saveConfiguration => 'Saqlash';

  @override
  String get dnsSaved => 'DNS sozlamalari saqlandi';

  @override
  String get invalidPrimaryDns => 'Bu asosiy DNS manzili notoʻgʻri';

  @override
  String get invalidSecondaryDns => 'Bu qoʻshimcha DNS manzili notoʻgʻri';

  @override
  String get statistics => 'Tarix';

  @override
  String get overview => 'UMUMIY KOʻRINISH';

  @override
  String get connectionsLabel => 'Seanslar';

  @override
  String get totalTime => 'Ulanish vaqti';

  @override
  String get dataUsage => 'Sarflangan trafik';

  @override
  String get uploaded => 'Yuklangan';

  @override
  String get downloaded => 'Yuklab olingan';

  @override
  String get total => 'Jami';

  @override
  String lastUpdated(String date) {
    return 'Oxirgi yangilanish: $date';
  }

  @override
  String today(String time) {
    return 'Bugun soat $time';
  }

  @override
  String get yesterday => 'Kecha';

  @override
  String daysAgo(int count) {
    return '$count kun oldin';
  }

  @override
  String get noDataYet => 'Seans maʼlumotlari yoʻq';

  @override
  String get connectToStart => 'Kuzatishni boshlash uchun ulaning';

  @override
  String get errorConnectionFailed => 'Ulanib boʻlmadi';

  @override
  String get errorServerNotWorking =>
      'Bu joylashuv ishlamayapti. Boshqasini sinab koʻring.';

  @override
  String get errorServerNotForwarding =>
      'Bu joylashuv trafikni oʻtkazmayapti. Boshqasini sinab koʻring.';

  @override
  String get errorUnexpected => 'Kutilmagan xato';

  @override
  String get errorDisconnectionFailed => 'Uzib boʻlmadi';

  @override
  String get errorFailedToRegister => 'Qurilmani roʻyxatdan oʻtkazib boʻlmadi';

  @override
  String get ipInformation => 'IP manzilimni tekshirish';

  @override
  String get connectionAnalytics => 'Tarix';

  @override
  String get recentSessions => 'Soʻnggi ulanishlar';

  @override
  String get speedTest => 'Tezlik testi';

  @override
  String get startTest => 'DIAGNOSTIKANI BOSHLASH';

  @override
  String get download => 'Yuklab olish';

  @override
  String get upload => 'Yuklash';

  @override
  String get testingViaVpn => 'Tunel orqali tekshirilmoqda';

  @override
  String get testingDirect => 'Toʻgʻridan-toʻgʻri ulanish tekshirilmoqda';

  @override
  String get splitTunneling => 'Marshrut sozlamalari';

  @override
  String get splitTunnelingDescription =>
      'Qaysi ilova toifalari tunelni chetlab oʻtishini tanlang. Chiqarib tashlangan ilovalar toʻgʻridan-toʻgʻri tarmoq ulanishingizdan foydalanadi.';

  @override
  String get enableSplitTunneling => 'Marshrutni ajratishni yoqish';

  @override
  String get splitTunnelActive => 'Tanlangan ilovalar tunelni chetlab oʻtadi';

  @override
  String get splitTunnelInactive => 'Barcha trafik tunel orqali oʻtadi';

  @override
  String get bypassVpnFor => 'Tunelni chetlab oʻtish';

  @override
  String get tools => 'Diagnostika';

  @override
  String get settingsGeneral => 'Umumiy';

  @override
  String get shareDiagnosticsTitle => 'Ulanish diagnostikasini ulashish';

  @override
  String get shareDiagnosticsBody =>
      'Ulanish hisobotlari, operatoringiz va mamlakatingiz, telefon modeli va Android versiyasi, VPN orqali kiradigan saytlaringiz nomlari kunlik soni bilan, shuningdek, xabarlarimiz, Premium takliflarimiz va doʻstlarni taklif qilish kartasini koʻrgan yoki bosganingiz yuboriladi. Siz ochgan sahifalarni yoki yuborgan narsalaringizni biz hech qachon koʻrmaymiz.';

  @override
  String get security => 'Muvofiqlik';

  @override
  String get privacyDashboard => 'Ulanish nuqtasi tahlili';

  @override
  String get privacyDashboardSubtitle => 'IP shaffofligi va sizish nazorati';

  @override
  String get connectionAnalyticsSubtitle => 'Seanslar tarixi va hisobotlar';

  @override
  String get speedTestSubtitle => 'Oʻtkazish tezligini oʻlchash';

  @override
  String get splitTunnelingSubtitle => 'Marshrut qoidalarini sozlash';

  @override
  String get splashTagline => 'Qayerda boʻlsangiz ham, maxfiy ulanish';

  @override
  String get openSourceLicence => 'Ochiq kod litsenziyasi';

  @override
  String get sourceOfferTitle => 'Ochiq kod litsenziyasi';

  @override
  String get sourceOfferBody =>
      'Fortiva VPN GNU General Public License v3 asosidagi erkin dasturiy taʼminotdir. U Xray-core va boshqa ochiq kodli loyihalar asosida qurilgan.\n\nSiz oʻrnatgan versiyaning toʻliq manba kodini olish huquqiga egasiz. Soʻrash uchun ilova versiyangizni koʻrsatib admin@fortivavpn.com manziliga xat yuboring. Bu taklif siz ushbu versiyani olgan sanadan boshlab uch yil davomida amal qiladi.';

  @override
  String get close => 'Yopish';

  @override
  String get account => 'Hisob';

  @override
  String get deleteAccount => 'Hisobni oʻchirish';

  @override
  String get deleteAccountSubtitle =>
      'Bu qurilma va maʼlumotlaringizni butunlay oʻchirish';

  @override
  String get deleteAccountConfirmTitle => 'Hisobingiz oʻchirilsinmi?';

  @override
  String get deleteAccountConfirmBody =>
      'Bu qurilmaning roʻyxatdan oʻtish yozuvini, siz uchun yaratilgan shaxsiy serverlarni va qoʻllab-quvvatlash chatidagi xabarlaringizni oʻchiradi. Bu telefondagi ulanish tarixi ham oʻchiriladi.\n\nBuni bekor qilib boʻlmaydi. Ilovani qayta ochib, istalgan vaqtda qaytadan boshlashingiz mumkin.';

  @override
  String deleteAccountConfirmRetention(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days kun',
      one: '$days kun',
    );
    return 'Hisob yozuvingiz darhol oʻchiriladi. Zaxira nusxalar va anonim server jurnallaridagi nusxalar $_temp0 ichida tozalanadi.';
  }

  @override
  String get deleteAccountConfirmRetentionNoDays =>
      'Hisob yozuvingiz darhol oʻchiriladi. Zaxira nusxalar va anonim server jurnallaridagi nusxalar keyinroq, maxfiylik siyosatimizdagi jadval boʻyicha tozalanadi.';

  @override
  String get deleteAccountCancel => 'Hisobimni saqlab qolish';

  @override
  String get deleteAccountConfirm => 'Oʻchirish';

  @override
  String get deleteAccountInProgress => 'Hisobingiz oʻchirilmoqda';

  @override
  String get deleteAccountDone => 'Hisobingiz oʻchirildi.';

  @override
  String get deleteAccountFailed =>
      'Hisobingizni oʻchirib boʻlmadi. Ulanishni tekshirib, qayta urinib koʻring.';

  @override
  String get homeTapToConnect => 'Ulanish uchun bosing';

  @override
  String get homeChecking => 'Ulanish tekshirilmoqda';

  @override
  String get homePreparing => 'Serveringiz sozlanmoqda';

  @override
  String get homeDisconnecting => 'Uzilmoqda';

  @override
  String get homeFindingPath => 'Yoʻl qidirilmoqda';

  @override
  String get diagCheckingInternet => 'Internetingiz tekshirilmoqda';

  @override
  String get diagInternationalCut => 'Bu tarmoqda xalqaro internet uzilgan';

  @override
  String diagPathRow(String city, int n) {
    return '$city, $n-yoʻl';
  }

  @override
  String get diagOpen => 'ochiq';

  @override
  String get diagBlocked => 'bloklangan';

  @override
  String get diagSkipped => 'bugun oʻtkazib yuborildi';

  @override
  String diagConnectingThrough(String city) {
    return '$city orqali ulanmoqda';
  }

  @override
  String get diagVerifying => 'Trafik tekshirilmoqda';

  @override
  String get diagNoInternet => 'Telefoningizda hozir internet yoʻq.';

  @override
  String get diagCutOff =>
      'Tarmogʻingiz hozir xalqaro internetga chiqa olmayapti. Qayta urinish uchun bosing.';

  @override
  String get diagNothingOpen =>
      'Hozir barcha yoʻllar bloklangan. Qayta urinish uchun bosing.';

  @override
  String get homeTryingAgain =>
      'Hozir barcha yoʻllar bloklangan. Birozdan soʻng qayta urinib koʻramiz.';

  @override
  String get homeCutOffTryingAgain =>
      'Tarmogʻingiz hozir xalqaro internetga chiqa olmayapti. Birozdan soʻng qayta urinib koʻramiz.';

  @override
  String get homeOfflineTryingAgain =>
      'Telefoningizda hozir internet yoʻq. Birozdan soʻng qayta urinib koʻramiz.';

  @override
  String get diagPathFailed =>
      'Yoʻl ochiq edi, lekin tunel ishga tushmadi. Qayta urinish uchun bosing.';

  @override
  String get openVpnSettings => 'VPN sozlamalarini ochish';

  @override
  String get yourServer => 'SIZNING SERVERINGIZ';

  @override
  String get yourServerCaption =>
      'Faqat sizniki. Boshqa hech kim u orqali ulanmaydi.';

  @override
  String get ourServer => 'BIZNING SERVERIMIZ';

  @override
  String get ourServerCaption =>
      'Fortiva tomonidan boshqariladi va hamma bilan birgalikda ishlatiladi. Oʻz serveringiz tayyor boʻlguncha ishlatiladi.';

  @override
  String get communityServer => 'HAMJAMIYAT SERVERI';

  @override
  String get communityServerCaption =>
      'Qoʻshimcha ulanish imkoniyati. Istalgan vaqtda ishlamay qolishi mumkin.';

  @override
  String communityServerNumber(String n) {
    return 'Hamjamiyat serveri $n';
  }

  @override
  String get myServersTitle => 'Serverlaringiz';

  @override
  String get myServersExplainer =>
      'Har bir Fortiva qurilmasiga har bir joylashuvda oʻz serveri beriladi, uning kirish maʼlumotlari faqat shu oʻrnatishga tegishli. Hisob kerak emas.';

  @override
  String get myServersInUse => 'Ishlatilmoqda';

  @override
  String get myServersEmpty => 'Hali server biriktirilmagan';

  @override
  String get myServersRetry => 'Qayta urinish';

  @override
  String get myServersBlockedTitle => 'Bugungi trafikni sarfladingiz';

  @override
  String get myServersBlockedWait =>
      'Kunlik limitingiz avtomatik yangilanadi. Birozdan keyin qayta tekshiring.';

  @override
  String myServersMoved(String place) {
    return 'Endi $place ishlatilmoqda';
  }

  @override
  String get copyLink => 'Havolani nusxalash';

  @override
  String get linkCopied => 'Havola nusxalandi';

  @override
  String quotaUsedToday(String used, String limit) {
    return 'Bugun $limit dan $used sarflandi';
  }

  @override
  String get quotaUsedUp => 'Kunlik trafik tugadi';

  @override
  String get quotaUnlimited => 'Cheksiz trafik';

  @override
  String get quotaDaily => 'Kunlik trafik';

  @override
  String get quotaLimitReached => 'Kunlik limitga yetildi';

  @override
  String quotaLeftOf(String left, String limit) {
    return '$limit dan $left qoldi';
  }

  @override
  String get quotaResetsShortly => 'Tez orada yangilanadi';

  @override
  String quotaResetsInHours(int hours) {
    return '$hours soatdan soʻng yangilanadi';
  }

  @override
  String quotaResetsInMinutes(int minutes) {
    return '$minutes daqiqadan soʻng yangilanadi';
  }

  @override
  String get myServersSubtitle => 'Bu qurilma uchun ajratilgan serverlar';

  @override
  String get sharedServersTitle => 'Umumiy serverlar';

  @override
  String get sharedServersSubtitle =>
      'Zaxira sifatida ishlatiladigan ochiq joylashuvlar';

  @override
  String get tabOfficial => 'Serverlarimiz';

  @override
  String get noOfficialServers => 'Hozir Fortiva serverlari yoʻq';

  @override
  String get inviteTitle => 'Doʻstlarni taklif qiling';

  @override
  String get inviteSubtitle => 'Qoʻshimcha kunlik trafik oling';

  @override
  String get inviteYourCode => 'Taklif kodingiz';

  @override
  String get inviteShareAction => 'Taklifni ulashish';

  @override
  String get inviteCopyAction => 'Kodni nusxalash';

  @override
  String get inviteCodeCopied => 'Kod nusxalandi';

  @override
  String inviteShareMessage(String code, String url) {
    return 'Menda yaxshi ishlaydigan bepul VPN: Fortiva. Roʻyxatdan oʻtish shart emas.\nShu havola orqali oʻrnating:\n$url\nTaklif kodim: $code';
  }

  @override
  String get inviteHowItWorks => 'Bu qanday ishlaydi';

  @override
  String inviteHowItWorksBody(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days turli kunda',
      one: '$days kun',
    );
    return 'Kodingizni ulashing. Kimdir ilovani oʻrnatib, kodni kiritsa va VPNdan $_temp0 foydalansa, kunlik trafikingizga $amount qoʻshiladi. U hisobingizda saqlanib qoladi.';
  }

  @override
  String inviteHowItWorksBodyNoAmount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days turli kunda',
      one: '$days kun',
    );
    return 'Kodingizni ulashing. Kimdir ilovani oʻrnatib, kodni kiritsa va VPNdan $_temp0 foydalansa, har kuni koʻproq trafik olasiz. U hisobingizda saqlanib qoladi.';
  }

  @override
  String inviteHowItWorksBodyNoDays(String amount) {
    return 'Kodingizni ulashing. Kimdir ilovani oʻrnatib, kodni kiritsa va VPNdan bir muddat foydalansa, kunlik trafikingizga $amount qoʻshiladi. U hisobingizda saqlanib qoladi.';
  }

  @override
  String get inviteHowItWorksBodyNoAmountNoDays =>
      'Kodingizni ulashing. Kimdir ilovani oʻrnatib, kodni kiritsa va VPNdan bir muddat foydalansa, har kuni koʻproq trafik olasiz. U hisobingizda saqlanib qoladi.';

  @override
  String inviteHowItWorksCap(String max) {
    return 'Takliflardan kuniga koʻpi bilan $max olishingiz mumkin.';
  }

  @override
  String get inviteStatInvited => 'Taklif qilingan';

  @override
  String get inviteStatEarning => 'Tasdiqlangan';

  @override
  String get inviteStatBonus => 'Bonus trafik';

  @override
  String inviteBonusPerDay(String amount) {
    return 'Har kuni +$amount';
  }

  @override
  String get inviteNoBonusYet => 'Hali bonus yoʻq';

  @override
  String invitePendingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ta taklif hali tasdiqlanmagan',
      one: '1 ta taklif hali tasdiqlanmagan',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String inviteJoinedWith(String code) {
    return 'Siz $code kodi bilan qoʻshildingiz';
  }

  @override
  String get inviteLoadFailed => 'Taklif kodingizni yuklab boʻlmadi';

  @override
  String get inviteRetry => 'Qayta urinish';

  @override
  String get inviteHaveCodeTitle => 'Taklif kodingiz bormi?';

  @override
  String inviteHaveCodeSubtitle(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Uni dastlabki $hours soat ichida kiriting',
      one: 'Uni birinchi soat ichida kiriting',
    );
    return '$_temp0';
  }

  @override
  String get inviteHaveCodeSubtitleNoHours =>
      'Uni oʻrnatgandan keyin tez orada kiriting';

  @override
  String get inviteEnterCodeHint => 'Taklif kodi';

  @override
  String get inviteApplyAction => 'Qoʻllash';

  @override
  String get inviteNotNowAction => 'Hozir emas';

  @override
  String inviteClaimAccepted(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days turli kunda',
      one: '$days kun',
    );
    return 'Taklif qabul qilindi. Siz VPNdan $_temp0 foydalanganingizdan keyin doʻstingiz bonus trafik oladi.';
  }

  @override
  String get inviteClaimAcceptedNoDays =>
      'Taklif qabul qilindi. Siz VPNdan bir muddat foydalanganingizdan keyin doʻstingiz bonus trafik oladi.';

  @override
  String get inviteClaimAlready =>
      'Bu qurilma allaqachon taklif kodidan foydalangan';

  @override
  String get inviteClaimRejected =>
      'Bu kod ishlamadi. Tekshirib, qayta urinib koʻring';

  @override
  String get inviteClaimNetwork =>
      'Serverga ulanib boʻlmadi. Qayta urinib koʻring';

  @override
  String get inviteCardTitle =>
      'Fortiva sizda yaxshi ishlayaptimi? Doʻstlaringizga yuboring';

  @override
  String get inviteCardBody =>
      'Doʻstingizga oʻrnatish havolasini yuboring, shunda u ham bepul ulana oladi.';

  @override
  String inviteCardReward(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Doʻstingiz Fortiva ilovasidan foydalana boshlaganda, siz $days kunlik Premium olasiz.',
      one:
          'Doʻstingiz Fortiva ilovasidan foydalana boshlaganda, siz $days kunlik Premium olasiz.',
    );
    return '$_temp0';
  }

  @override
  String get inviteCardRewardNoAmount =>
      'Doʻstingiz Fortiva ilovasidan foydalana boshlaganda, siz sovgʻa sifatida Premium olasiz.';

  @override
  String get inviteSendTelegram => 'Telegram';

  @override
  String get inviteSendWhatsApp => 'WhatsApp';

  @override
  String get inviteCopyLink => 'Havolani nusxalash';

  @override
  String get inviteOtherApps => 'Boshqa ilovalar';

  @override
  String get inviteLinkCopied => 'Taklif xabari nusxalandi';

  @override
  String get invitePasteBody =>
      'Doʻstingiz xabaridagi kodni nusxalab, shu yerga joylang.';

  @override
  String get invitePasteAction => 'Joylash';

  @override
  String get inviteErrorTooLate =>
      'Bu telefonda taklif kodini kiritish vaqti oʻtib ketdi.';

  @override
  String get inviteErrorUnknown =>
      'Bu kodni topa olmadik. Uni doʻstingiz xabaridan qayta nusxalang.';

  @override
  String get inviteErrorOwnCode =>
      'Bu oʻzingizning kodingiz. Doʻstingizning kodini kiriting.';

  @override
  String get inviteErrorMutual =>
      'Siz va doʻstingiz bir-biringizni taklif qila olmaysiz.';

  @override
  String inviteHowItWorksPremium(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Fortiva ilovasidan foydalana boshlagan har bir doʻstingiz sizga yana $days kunlik Premium beradi.',
      one:
          'Fortiva ilovasidan foydalana boshlagan har bir doʻstingiz sizga yana $days kunlik Premium beradi.',
    );
    return '$_temp0';
  }

  @override
  String inviteHowItWorksPremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Takliflardan koʻpi bilan $max kunlik Premium olishingiz mumkin.',
      one: 'Takliflardan koʻpi bilan $max kunlik Premium olishingiz mumkin.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeLive =>
      'Bonusingiz doʻstlaringiz Fortiva ilovasidan foydalanib turgan paytda amal qiladi. Biror doʻst toʻxtasa, bonus kamayadi.';

  @override
  String inviteTreeNext(String amount) {
    return 'Keyingi doʻstingiz Fortiva ilovasidan foydalana boshlagach, kuniga $amount qoʻshadi.';
  }

  @override
  String inviteTreeKept(String amount) {
    return 'Avval taklif qilgan doʻstlaringiz tufayli bonusingiz hech qachon kuniga $amount dan kam boʻlmaydi.';
  }

  @override
  String get inviteTreeSlotsTitle => 'Oʻrinlaringiz';

  @override
  String get inviteTreeSlotActive => 'Faol';

  @override
  String get inviteTreeSlotNotActive => 'Hozir faol emas';

  @override
  String get inviteTreeSlotEmpty => 'Boʻsh oʻrin';

  @override
  String inviteTreePaysNow(String amount) {
    return 'Hozir kuniga +$amount';
  }

  @override
  String inviteTreePairFull(String amount) {
    return 'Ikkalasi ham faol boʻlsa, kuniga +$amount';
  }

  @override
  String get inviteTreeNothingYet => 'Hozircha hech narsa';

  @override
  String get inviteTreeFriendsTitle => 'Oʻrinlaringiz orqali';

  @override
  String get inviteTreeRowFriends => 'Oʻrinlaringizda';

  @override
  String get inviteTreeRowFriendsSlots => 'Ularning oʻrinlarida';

  @override
  String inviteTreeRowSteps(int steps) {
    String _temp0 = intl.Intl.pluralLogic(
      steps,
      locale: localeName,
      other: '$steps qadam uzoqda',
    );
    return '$_temp0';
  }

  @override
  String inviteTreeRowPeople(int people, int active) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people kishi',
    );
    return '$_temp0, $active faol';
  }

  @override
  String inviteTreeHowSlots(int slots) {
    String _temp0 = intl.Intl.pluralLogic(
      slots,
      locale: localeName,
      other:
          'Kodingizni ulashing. Taklifi tasdiqlangan dastlabki $slots doʻst oʻrinlaringizni juft-juft qilib toʻldiradi.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeHowSlotsNoNumber =>
      'Kodingizni ulashing. Taklifi tasdiqlangan dastlabki doʻstlar oʻrinlaringizni juft-juft qilib toʻldiradi.';

  @override
  String get inviteTreeHowPair =>
      'Juftlikdagi ikkala odam ham faol boʻlsa, u koʻproq beradi.';

  @override
  String get inviteTreeHowFriendsSlots =>
      'Oʻrinlaringiz toʻlgach, taklifi keyin tasdiqlangan doʻstlaringiz keyingi boʻsh oʻrinlarni egallaydi, ular sizdan uzoqroq. Ular ham sizga trafik qoʻshadi, qanchalik uzoq boʻlsa, shunchalik kamroq.';

  @override
  String get inviteTreeHowOthers =>
      'Birinchi juftligingizga siz taklif qilmagan odamlar ham joylashishi mumkin. Ular ham sizga xuddi shunday trafik qoʻshadi.';

  @override
  String inviteTreeHowActive(int days, int window) {
    return 'Doʻst oxirgi $window kun ichida kamida $days kun Fortiva ilovasidan foydalangan boʻlsa, faol hisoblanadi.';
  }

  @override
  String get inviteTreeHowActiveNoNumber =>
      'Doʻst Fortiva ilovasidan foydalanishda davom etsa, faol hisoblanadi.';

  @override
  String inviteTreeHowCap(String max) {
    return 'Takliflar kuniga koʻpi bilan $max qoʻshishi mumkin.';
  }

  @override
  String get inviteTreeHowCapNoAmount =>
      'Takliflar qoʻshadigan trafikning kunlik chegarasi bor.';

  @override
  String get premiumSourceInvite => 'Takliflaringiz uchun sovgʻa';

  @override
  String quotaBonusIncluded(String amount) {
    return 'shu jumladan $amount taklif bonusi';
  }

  @override
  String get updateTitle => 'Yangilanish mavjud';

  @override
  String get updateRequiredTitle => 'Yangilanish talab qilinadi';

  @override
  String updateBody(String version) {
    return 'Fortiva $version chiqdi. Eng soʻnggi tuzatishlar uchun yangilang.';
  }

  @override
  String get updateRequiredBody =>
      'Bu versiya endi qoʻllab-quvvatlanmaydi. Fortiva ilovasidan foydalanishni davom ettirish uchun yangilang.';

  @override
  String get updateNow => 'Yangilash';

  @override
  String get updateLater => 'Keyinroq';

  @override
  String get updateFromPlay => 'Google Play';

  @override
  String get updateFromTelegram => 'Telegram kanali';

  @override
  String get updateConnect => 'Ulanish';

  @override
  String get updateConnectHint =>
      'Agar Google Play yoki Telegram ochilmasa, avval Ulanish tugmasini bosing.';

  @override
  String get updateConnected =>
      'Siz ulangansiz. Yangilanishni hozir yuklab oling.';

  @override
  String get updateReconnect => 'Ishlamayaptimi? Qayta ulanish';

  @override
  String get updateDisconnect => 'Uzish';

  @override
  String get updateDisconnectHint =>
      'Yangilanishni oddiy internetingiz orqali yuklab olish uchun Uzish tugmasini bosing.';

  @override
  String get updateNotCarrying =>
      'Siz ulangansiz, lekin hech narsa oʻtmayapti. Qayta ulanishni sinab koʻring yoki oddiy internetingizdan foydalanish uchun Uzish tugmasini bosing.';

  @override
  String get diagVerdictNoInternet =>
      'Telefoningizda internet ulanishi yoʻq. U tiklanmaguncha Fortiva ulana olmaydi.';

  @override
  String get diagVerdictCutOff =>
      'Tarmogʻingiz hozir xalqaro internetga chiqa olmayapti. Bir necha daqiqadan soʻng qayta urinib koʻring.';

  @override
  String get diagVerdictNeedsPermission =>
      'Fortiva ilovasida VPN ishga tushirish uchun ruxsat yoʻq yoki boshqa VPN ilovasi doim yoniq qilib sozlangan.';

  @override
  String get diagVerdictServerUnreachable =>
      'Bu serverga tarmogʻingizdan ulanib boʻlmaydi. U bu yerda bloklangan yoki ishlamayapti.';

  @override
  String get diagVerdictBlockedTls =>
      'Bu serverga ulanish oʻrnatilayotgan paytda uzilmoqda. Filtrlash aynan shunday koʻrinadi.';

  @override
  String get diagVerdictThrottled =>
      'Server har bir tekshiruvga javob berdi, lekin tunel baribir hech narsa oʻtkazmadi. Ulanish sekinlashtirilmoqda.';

  @override
  String get diagCheckInternet => 'Internetingizni tekshiring';

  @override
  String diagTryServer(String server) {
    return '$server bilan yangi qidiruv';
  }

  @override
  String get diagTryAnotherServer => 'Boshqa serverni sinab koʻring';

  @override
  String get diagDetails => 'Tafsilotlar';

  @override
  String get diagDetailsHide => 'Tafsilotlarni yashirish';

  @override
  String privateDnsWarning(String host) {
    return 'Shaxsiy DNS yoniq ($host), shuning uchun baʼzi saytlar ochilmasligi mumkin. Telefon sozlamalarida Shaxsiy DNSni oʻchiring.';
  }

  @override
  String get openNetworkSettings => 'Tarmoq sozlamalarini ochish';

  @override
  String testPointStatus(String time, int open, int total) {
    return 'Sinov nuqtasi · oxirgi tekshiruv $time · $total eshikdan $open tasi ochiq';
  }

  @override
  String get messagesTooltip => 'Xabarlar';

  @override
  String get inboxTitle => 'Xabarlar';

  @override
  String get inboxEmpty => 'Hozircha xabarlar yoʻq.';

  @override
  String get messageClose => 'Yopish';

  @override
  String get supportTitle => 'Qoʻllab-quvvatlash';

  @override
  String get supportTooltip => 'Qoʻllab-quvvatlash bilan chat';

  @override
  String get supportAskAction => 'Qoʻllab-quvvatlashdan soʻrash';

  @override
  String get supportContactSubtitle => 'Ilova ichida biz bilan yozishing';

  @override
  String get supportAutomaticNotice =>
      'Javoblar avtomatik yoziladi va notoʻgʻri boʻlishi mumkin.';

  @override
  String get supportStaffNotice =>
      'Avtomatik javoblar hozircha oʻchirilgan. Xabarlaringiz jamoamizga boradi.';

  @override
  String get supportInputHint => 'Savolingizni yozing';

  @override
  String get supportInputHintTeam => 'Jamoamizga yozing';

  @override
  String get supportSend => 'Yuborish';

  @override
  String supportQuotaLeft(int remaining, int limit) {
    return 'Bugun $limit savoldan $remaining tasi qoldi';
  }

  @override
  String supportWaitIn(String time) {
    return '$time dan keyin yana soʻrashingiz mumkin.';
  }

  @override
  String supportDurationHours(int hours, int minutes) {
    return '$hours soat $minutes daq';
  }

  @override
  String supportDurationMinutes(int minutes) {
    return '$minutes daq';
  }

  @override
  String get supportNewConversation => 'Yangi suhbat';

  @override
  String get supportSending => 'Yuborilmoqda';

  @override
  String get supportNotSent => 'Yuborilmadi. Qayta urinish uchun bosing.';

  @override
  String get supportRateUp => 'Foydali';

  @override
  String get supportRateDown => 'Foydali emas';

  @override
  String get supportRatedDown => 'Rahmat. Jamoamiz bu javobni koʻrib chiqadi.';

  @override
  String get supportTeamLabel => 'Fortiva jamoasi';

  @override
  String get supportUnavailable => 'Chat hozir mavjud emas.';

  @override
  String get supportOpenTelegram => 'Bizga Telegram orqali yozing';

  @override
  String get supportGenericError =>
      'Nimadir xato ketdi. Iltimos, qayta urinib koʻring.';

  @override
  String supportCodeTooLong(int max) {
    return 'Xabaringiz juda uzun. Uni $max belgidan qisqa qiling.';
  }

  @override
  String get supportCodeEmpty => 'Xabaringiz boʻsh.';

  @override
  String get supportCodeWaitReply =>
      'Iltimos, oxirgi savolingizga javobni kuting.';

  @override
  String get supportCodeSlowDown =>
      'Xabarlarni juda tez yuboryapsiz. Iltimos, biroz kuting.';

  @override
  String get supportCodeQuotaDay =>
      'Bugungi barcha savollaringizni ishlatib boʻldingiz.';

  @override
  String get supportCodePaused => 'Avtomatik javoblar hozircha toʻxtatilgan.';

  @override
  String get supportCodeBusy =>
      'Yordamchimiz hozir band. Iltimos, bir necha daqiqadan keyin qayta urinib koʻring.';

  @override
  String get supportCodeGreeting =>
      'Salom! Fortiva boʻyicha sizga qanday yordam bera olaman?';

  @override
  String get supportCodeGibberish =>
      'Kechirasiz, tushunmadim. Iltimos, savolingizni qayta yozing.';

  @override
  String get supportCodeRedacted =>
      'Xabaringizdan shaxsiy maʼlumotlar va havolalarni olib tashladik.';

  @override
  String get supportCodeRedactedEmpty =>
      'Xabaringizda faqat shaxsiy maʼlumotlar yoki havolalar bor edi, shuning uchun u yuborilmadi. Iltimos, muammoni soʻz bilan tushuntiring.';

  @override
  String get supportCodeOffTopic =>
      'Men faqat Fortiva ilovasidan foydalanish boʻyicha savollarga yordam bera olaman.';

  @override
  String get supportCodeAbuse =>
      'Keling, hurmatni saqlaylik. Men sizga Fortiva boʻyicha yordam berish uchun shu yerdaman.';

  @override
  String get supportCodeAiUnavailable =>
      'Yordamchi bu safar javob bera olmadi. Iltimos, birozdan keyin qayta urinib koʻring.';

  @override
  String get supportCodeToStaff =>
      'Jamoamizga yuborildi. Ularning javobi shu yerda koʻrinadi.';

  @override
  String get supportCodeTicketOpened =>
      'Savolingizni jamoamizga yetkazdik. Ularning javobi shu yerda koʻrinadi.';

  @override
  String get supportCodeNotSent =>
      'Bu xabarni yuborib boʻlmadi. Agar hali ham yordam kerak boʻlsa, uni qayta yozing.';

  @override
  String get supportAssistantSubtitle => 'AI yordamchi';

  @override
  String get supportThinkingReading => 'Savolingiz oʻqilmoqda';

  @override
  String get supportThinkingSearching => 'Javob qidirilmoqda';

  @override
  String get supportThinkingWriting => 'Javob yozilmoqda';

  @override
  String get supportThinkingStill =>
      'Hali ishlayapman, kutganingiz uchun rahmat';

  @override
  String get supportSuggestConnect => 'Ulana olmayapman';

  @override
  String get supportSuggestData => 'Bugun qancha trafikim bor?';

  @override
  String get supportSuggestSlow => 'Ulanishim sekin';

  @override
  String get supportWithTeam => 'Bu suhbat endi jamoamizda.';

  @override
  String get supportTryAgainSoon =>
      'Bir necha daqiqadan keyin qayta urinib koʻring.';

  @override
  String supportDurationWholeHours(int hours) {
    return '$hours soat';
  }

  @override
  String get supportUnreadReply => 'Yangi javob';

  @override
  String get premiumTitle => 'Premium';

  @override
  String get premiumTileSubtitle => 'Kunlik limitsiz cheksiz trafik';

  @override
  String get premiumTileActive => 'Premium yoqilgan';

  @override
  String get premiumGetUnlimited => 'Cheksiz trafik oling';

  @override
  String get premiumHeadline => 'Cheksiz trafik oling';

  @override
  String get premiumPitch =>
      'Premium kunlik limitni olib tashlaydi, shuning uchun u tugaguncha xohlagancha trafik ishlatishingiz mumkin.';

  @override
  String get premiumActiveTitle => 'Premium yoqilgan';

  @override
  String premiumActiveUntil(String date) {
    return '$date gacha cheksiz trafik';
  }

  @override
  String get premiumActiveNoDate => 'Cheksiz trafik';

  @override
  String get premiumRenews => 'Google Play orqali avtomatik uzaytiriladi';

  @override
  String get premiumSourceKey => 'Kalit bilan faollashtirilgan';

  @override
  String get premiumSourceCrypto => 'Kripto bilan toʻlangan';

  @override
  String get premiumSourceStars => 'Telegram yulduzlari bilan toʻlangan';

  @override
  String get premiumSourceGooglePlay => 'Google Play orqali toʻlangan';

  @override
  String get premiumSourceManual => 'Fortiva jamoasidan sovgʻa';

  @override
  String get premiumYourKey => 'Kalitingiz';

  @override
  String get premiumKeyHint =>
      'Bu kalitni ehtiyot qilib saqlang. Premiumni boshqa telefonga koʻchirish uchun uni oʻsha telefonda kiriting.';

  @override
  String premiumKeyMoves(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days kun',
      one: '$days kun',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'koʻpi bilan $count marta',
      one: 'bir marta',
    );
    return 'Kalit $_temp0 ichida boshqa telefonga $_temp1 koʻchirilishi mumkin.';
  }

  @override
  String get premiumKeyMovesNoNumber =>
      'Kalit boshqa telefonga faqat cheklangan miqdorda koʻchirilishi mumkin.';

  @override
  String get premiumCopy => 'Nusxalash';

  @override
  String get premiumCopied => 'Nusxalandi';

  @override
  String get premiumChoosePlan => 'Tarif tanlang';

  @override
  String premiumPlanDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days kun cheksiz trafik',
      one: '$days kun cheksiz trafik',
    );
    return '$_temp0';
  }

  @override
  String get premiumPlanNoDays => 'Cheksiz trafik';

  @override
  String get premiumBuy => 'Sotib olish';

  @override
  String get premiumPlayUnavailable =>
      'Google Play hozir mavjud emas. Keyinroq qayta urinib koʻring.';

  @override
  String get premiumPlayPending =>
      'Toʻlovingiz Google Play tizimida kutilmoqda. U oʻtishi bilan Premium boshlanadi.';

  @override
  String get premiumPlayConfirming => 'Xaridingiz tasdiqlanmoqda...';

  @override
  String get premiumPlayRetrying =>
      'Toʻlovingiz oʻtdi, lekin biz uni hali tasdiqlay olmadik. Urinishda davom etamiz, shuning uchun qayta toʻlashingiz shart emas.';

  @override
  String get premiumPlayRefused =>
      'Bu xaridni tasdiqlay olmadik. Agar sizdan pul yechilgan boʻlsa, qoʻllab-quvvatlash xizmatiga murojaat qiling.';

  @override
  String get premiumPlayNotAvailable =>
      'Premium hozir bu telefonda mavjud emas. Agar sizdan pul yechilgan boʻlsa, qoʻllab-quvvatlash xizmatiga murojaat qiling.';

  @override
  String get premiumNotAvailable => 'Premium hozir bu telefonda mavjud emas.';

  @override
  String get premiumPlayFailed => 'Xarid amalga oshmadi. Qayta urinib koʻring.';

  @override
  String get premiumNowOn =>
      'Premium yoqildi. Cheksiz trafikdan bahramand boʻling.';

  @override
  String get premiumRestore => 'Xaridlarni tiklash';

  @override
  String get premiumRestoreDone => 'Xaridingiz bu telefonda tiklandi.';

  @override
  String get premiumRestoreNone =>
      'Google Play tizimida tiklanadigan xarid yoʻq.';

  @override
  String get premiumRestoreFailed =>
      'Xaridingizni tiklab boʻlmadi. Keyinroq qayta urinib koʻring.';

  @override
  String premiumRenewsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Har $count kunda toʻlov olinadi. Bekor qilmaguningizcha avtomatik uzaytiriladi.',
      one:
          'Har kuni toʻlov olinadi. Bekor qilmaguningizcha avtomatik uzaytiriladi.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Har $count haftada toʻlov olinadi. Bekor qilmaguningizcha avtomatik uzaytiriladi.',
      one:
          'Har hafta toʻlov olinadi. Bekor qilmaguningizcha avtomatik uzaytiriladi.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Har $count oyda toʻlov olinadi. Bekor qilmaguningizcha avtomatik uzaytiriladi.',
      one:
          'Har oy toʻlov olinadi. Bekor qilmaguningizcha avtomatik uzaytiriladi.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Har $count yilda toʻlov olinadi. Bekor qilmaguningizcha avtomatik uzaytiriladi.',
      one:
          'Har yili toʻlov olinadi. Bekor qilmaguningizcha avtomatik uzaytiriladi.',
    );
    return '$_temp0';
  }

  @override
  String get premiumRenewsNoPeriod =>
      'Bekor qilmaguningizcha avtomatik uzaytiriladi.';

  @override
  String get premiumPlayCancelNote =>
      'Google Play orqali istalgan vaqtda bekor qilishingiz mumkin. Premium siz toʻlagan muddat tugaguncha yoqiq qoladi.';

  @override
  String get premiumManageSubscription =>
      'Obunani boshqarish yoki bekor qilish';

  @override
  String get premiumCurrentPlan => 'Joriy tarif';

  @override
  String get premiumPlaySubscribed =>
      'Sizda allaqachon Google Play obunasi bor. Uni Google Play orqali boshqaring yoki bekor qiling.';

  @override
  String get premiumEnterCode => 'Kod kiritish';

  @override
  String get premiumNeedsPlayVersion =>
      'Google Play orqali sotib olish uchun Fortiva ilovasining Google Play versiyasi kerak.';

  @override
  String get premiumOff => 'Premium hozir sotuvda emas.';

  @override
  String get premiumLoadFailed =>
      'Premium yuklanmadi. Ulanishni tekshirib, qayta urinib koʻring.';

  @override
  String get premiumRetry => 'Qayta urinish';

  @override
  String premiumPriceUsdt(String price) {
    return '$price USDT';
  }

  @override
  String premiumPriceStars(String stars) {
    return '$stars Telegram yulduzi';
  }

  @override
  String get premiumPayCrypto => 'Kripto bilan toʻlash';

  @override
  String get premiumTelegramTitle => 'Telegram orqali toʻlash';

  @override
  String get premiumTelegramBody =>
      'Botimizda Telegram yulduzlari bilan toʻlang. Siz kalit olasiz va Premium bu telefonda darhol boshlanadi.';

  @override
  String get premiumTelegramButton => 'Telegram orqali sotib olish';

  @override
  String get premiumTelegramFailed =>
      'Telegram ochilmadi. Qayta urinib koʻring.';

  @override
  String get checkoutTitle => 'Kripto bilan toʻlash';

  @override
  String get checkoutChooseNetwork => 'Qaysi tarmoqdan yuborishingizni tanlang';

  @override
  String get checkoutContinue => 'Davom etish';

  @override
  String get checkoutSendExactly => 'Aynan shu summani yuboring';

  @override
  String get checkoutNetwork => 'Tarmoq';

  @override
  String get checkoutAddress => 'Bu manzilga';

  @override
  String get checkoutMemo => 'Bu memo bilan';

  @override
  String get checkoutMemoWarning =>
      'Bu memoni oʻtkazmangizga qoʻshing, aks holda toʻlovni sizga bogʻlay olmaymiz.';

  @override
  String get checkoutExactWarning =>
      'Aynan shu summani va faqat shu tarmoq orqali yuboring. Boshqa summa yoki tarmoq bizga yetib kelmasligi mumkin.';

  @override
  String checkoutTimeLeft(String time) {
    return 'Qolgan vaqt: $time';
  }

  @override
  String get checkoutWaiting =>
      'Toʻlovingiz kutilmoqda. Bu sahifa oʻzi yangilanadi.';

  @override
  String get checkoutPaidTitle => 'Toʻlov qabul qilindi';

  @override
  String get checkoutPaidKeyOnly =>
      'Kalitingiz tayyor. Uni Premium olishi kerak boʻlgan telefonda kiriting.';

  @override
  String get checkoutDone => 'Tayyor';

  @override
  String get checkoutExpired =>
      'Bu buyurtma muddati tugagan. Agar allaqachon toʻlagan boʻlsangiz, qoʻllab-quvvatlash xizmatiga murojaat qiling.';

  @override
  String get checkoutUnderpaid =>
      'Biz toʻliq summadan kamroq oldik. Qoʻllab-quvvatlash xizmatiga murojaat qiling va ularga bu buyurtma raqamini bering:';

  @override
  String get checkoutCanceled => 'Bu buyurtma bekor qilindi.';

  @override
  String get checkoutStartAgain => 'Qaytadan boshlash';

  @override
  String get checkoutUnavailable => 'Kripto toʻlovlari hozir mavjud emas.';

  @override
  String get checkoutTooManyOpen =>
      'Sizda toʻlanmagan buyurtmalar juda koʻp. Ulardan birini toʻlang yoki muddati tugashini kuting.';

  @override
  String get checkoutUnknownPlan =>
      'Bu tarif endi sotuvda emas. Orqaga qaytib, boshqasini tanlang.';

  @override
  String get checkoutFailed =>
      'Toʻlovni boshlab boʻlmadi. Ulanishni tekshirib, qayta urinib koʻring.';

  @override
  String get redeemTitle => 'Kod kiritish';

  @override
  String get redeemSubtitle => 'Premium kaliti yoki sovgʻa kodi';

  @override
  String get redeemHint => 'Kod';

  @override
  String get redeemApply => 'Qoʻllash';

  @override
  String get redeemCancel => 'Bekor qilish';

  @override
  String get redeemInvalid =>
      'Bu kodga oʻxshamaydi. Tekshirib, qayta urinib koʻring.';

  @override
  String get redeemUnknown =>
      'Bu kod bizga notanish. Tekshirib, qayta urinib koʻring.';

  @override
  String get redeemExpired => 'Bu kodning muddati tugagan.';

  @override
  String get redeemRevoked => 'Bu kod endi amal qilmaydi.';

  @override
  String get redeemMovedTooOften =>
      'Bu kalit soʻnggi paytda telefonlar orasida juda koʻp koʻchirilgan. Keyinroq qayta urinib koʻring.';

  @override
  String get redeemExhausted => 'Bu kod allaqachon toʻliq ishlatilgan.';

  @override
  String get redeemAlreadyUsed => 'Bu telefon bu kodni allaqachon ishlatgan.';

  @override
  String get redeemUnmetered =>
      'Bu telefonda allaqachon cheksiz trafik bor, shuning uchun unga bu kod kerak emas.';

  @override
  String get redeemRateLimited =>
      'Urinishlar juda koʻp. Biroz kutib, qayta urinib koʻring.';

  @override
  String get redeemUnavailable =>
      'Bu hozir mavjud emas. Keyinroq qayta urinib koʻring.';

  @override
  String get redeemNetwork =>
      'Serverga ulanib boʻlmadi. Ulanishni tekshirib, qayta urinib koʻring.';

  @override
  String get redeemFailed =>
      'Bu kod ishlamadi. Tekshirib, qayta urinib koʻring.';

  @override
  String get redeemMoved => 'Premium bu telefonga koʻchirildi.';

  @override
  String redeemPromo(String amount) {
    return 'Kod qabul qilindi. $amount qoʻshimcha trafik qoʻshildi.';
  }

  @override
  String get redeemPromoNoAmount =>
      'Kod qabul qilindi. Qoʻshimcha trafik qoʻshildi.';

  @override
  String get tvScanTitle => 'Telefoningizda oching';

  @override
  String get tvScanBody => 'Telefoningiz kamerasini bu kodga qarating.';

  @override
  String get refresh => 'Yangilash';

  @override
  String get premiumNotNow => 'Hozir emas';

  @override
  String get premiumLimitSheetTitle => 'Bugungi trafik tugadi';

  @override
  String get premiumLimitWait => 'Trafik yangilanishini kuting';

  @override
  String get premiumLimitInvite =>
      'Koʻproq trafik uchun doʻstlarni taklif qiling';

  @override
  String get premiumNoDailyLimit => 'Premiumda kunlik limit yoʻq.';

  @override
  String get premiumCalmTitle => 'Kunlik limitsiz foydalanmoqchimisiz?';

  @override
  String get premiumCalmBody =>
      'Premium sizga cheksiz trafik beradi. Bepul tarifingiz oʻzgarmaydi.';

  @override
  String get premiumNextStepTitle => 'Keyingi qadam: Premium';

  @override
  String get premiumNextStepBody =>
      'Sizda allaqachon eng koʻp bepul trafik bor. Premiumda kunlik limit yoʻq.';

  @override
  String get premiumLockedTag => 'Premium';

  @override
  String premiumLockedTitle(String place) {
    return '$place joylashuvini Premium bilan oching';
  }

  @override
  String get premiumLockedBody =>
      'Bu joylashuv Premium uchun. Bepul serverlaringiz oʻzgarmaydi.';

  @override
  String get premiumHeadlineLimit => 'Kunlik limit yoʻq';

  @override
  String premiumHeadlineLocked(String place) {
    return '$place joylashuvini Premium bilan oching';
  }

  @override
  String get premiumFreeStays => 'Bepul tarif Premiumsiz ham ishlayveradi.';

  @override
  String premiumEndsOn(String date) {
    return 'Premium $date kuni tugaydi';
  }

  @override
  String get premiumRenewBody =>
      'Cheksiz trafikni saqlab qolish uchun uzaytiring. Uzaytirish joriy tugash sanangizga vaqt qoʻshadi.';

  @override
  String premiumEndedOn(String date) {
    return 'Premium $date kuni tugadi. Bepul tarifingiz qaytdi.';
  }

  @override
  String get premiumRenew => 'Uzaytirish';

  @override
  String get noticeChannelName => 'Fortiva xabarlari';

  @override
  String get noticeChannelDescription =>
      'Fortiva jamoasidan yangiliklar va xabarlar';

  @override
  String get noticesSettingTitle => 'Bildirishnomalar';

  @override
  String get noticesSettingOn =>
      'Yoqilgan. Fortiva jamoasining xabarlari ilova yopiq boʻlsa ham kelishi mumkin.';

  @override
  String get noticesSettingOff =>
      'Oʻchirilgan. Fortiva jamoasining xabarlarini ilova yopiq boʻlsa ham olish uchun ularni yoqing.';

  @override
  String get noticesOffCard =>
      'Fortiva jamoasining xabarlarini ilova yopiq boʻlsa ham olish uchun bildirishnomalarni yoqing.';

  @override
  String get noticesTurnOn => 'Yoqish';

  @override
  String get backgroundCard =>
      'Ilova yopiq paytda telefoningiz Fortiva jamoasining xabarlarini ushlab qolishi mumkin. Xabarlar yetib kelishi uchun Fortiva fonda ishlashiga ruxsat bering.';

  @override
  String get backgroundHint =>
      'Keyingi ekranda Fortiva ilovasini tanlang (roʻyxatda boʻlmasa, barcha ilovalarni koʻrsating). Keyin batareya sarfini Cheklanmagan qilib qoʻying yoki avtomatik ishga tushish hamda fonda ishlashga ruxsat bering.';

  @override
  String get backgroundAllow => 'Ruxsat berish';

  @override
  String get backgroundNotNow => 'Hozir emas';

  @override
  String get backgroundSettingTitle => 'Ilova yopiqligida xabarlar';

  @override
  String get backgroundSettingSubtitle =>
      'Ilova yopiq boʻlsa ham xabarlar yetib kelishi uchun Fortiva fonda ishlashiga ruxsat bering.';

  @override
  String get backgroundCardData =>
      'Ilova yopiq paytda telefoningizdagi trafikni tejash rejimi Fortiva jamoasining xabarlarini toʻxtatib qolishi mumkin.';

  @override
  String get backgroundHintData =>
      'Keyingi ekranda cheklanmagan trafikni yoqing.';

  @override
  String get apnGuideTitle => 'Bu SIM kartada barqarorroq ulanish';

  @override
  String get apnGuideBody =>
      'Telefoningiz bu SIM kartada IPv6 dan foydalanmayapti. Uni yoqsangiz, Fortiva ulanishni yaxshiroq ushlab turadi.';

  @override
  String get apnGuideShowMe => 'Qanday qilishni koʻrsatish';

  @override
  String get apnGuideNotNow => 'Hozir emas';

  @override
  String get apnGuideSheetTitle => 'Bu SIM karta uchun IPv6 ni yoqing';

  @override
  String apnGuideStepOpen(String button) {
    return '\"$button\" tugmasini bosing (yoki Sozlamalar > Ulanishlar > Mobil tarmoqlar > Kirish nuqtasi nomlari boʻlimiga oʻting).';
  }

  @override
  String apnGuideStepAccessPoint(String apn) {
    return 'Ishlatilayotgan kirish nuqtasini ($apn) bosing.';
  }

  @override
  String get apnGuideStepAccessPointAny =>
      'Ishlatilayotgan kirish nuqtasini bosing.';

  @override
  String get apnGuideStepProtocol =>
      '\"APN protokoli\" bandini bosing va \"IPv4/IPv6\" ni tanlang.';

  @override
  String get apnGuideStepSave =>
      'Saqlang (Samsungda: uch nuqta menyusi, keyin \"Saqlash\").';

  @override
  String get apnGuideStepRestart => 'Mobil internetni oʻchirib, qayta yoqing.';

  @override
  String get apnGuideUndo =>
      'Agar mobil internet ishlamay qolsa, APN protokolini yana IPv4 ga qaytaring.';

  @override
  String get apnGuideOpenSettings => 'APN sozlamalarini ochish';

  @override
  String get homeStallSearching =>
      'Ulanish ishlamay qoldi. Boshqa yoʻl qidirilmoqda.';

  @override
  String get homeStalled => 'Ulangan, lekin maʼlumot oʻtmayapti';

  @override
  String get peerShareTitle => 'Doʻstga ulanishda yordam berish';

  @override
  String get peerShareSubtitle =>
      'Fortiva uchun keraklisini doʻstingiz telefoniga oʻtkazing';

  @override
  String get peerShareBody =>
      'Agar doʻstingizda Fortiva ulanmasa, uning telefoni keraklisini sizning telefoningizdan olishi mumkin. Bu internetsiz ishlaydi.';

  @override
  String peerShareSteps(String action) {
    return 'Uning telefonidagi Fortiva ilovasida Sozlamalar boʻlimini oching va \"$action\" tugmasini bosing. Soʻng unga bu kodlarni ketma-ket koʻrsating yoki hammasini yuboring.';
  }

  @override
  String get peerShareLoading => 'Eng yangi nusxa olinmoqda';

  @override
  String get peerShareNothing =>
      'Bu telefonda uzatadigan yangi narsa yoʻq. Keyinroq qayta urinib koʻring.';

  @override
  String peerShareCodeOf(int current, int total) {
    return '$total ta koddan $current-si';
  }

  @override
  String get peerSharePrevious => 'Orqaga';

  @override
  String get peerShareNext => 'Keyingi';

  @override
  String get peerShareCopy => 'Nusxalash';

  @override
  String get peerShareSend => 'Yuborish';

  @override
  String get peerShareCopied =>
      'Nusxalandi. Uni doʻstingiz bilan chatga joylang.';

  @override
  String get peerReceiveTitle => 'Doʻstdan yordam olish';

  @override
  String get peerReceiveSubtitle => 'Boshqa usulda ulanib boʻlmasa';

  @override
  String peerReceiveBody(String action) {
    return 'Fortiva ilovasi ulanadigan doʻstingizdan Fortiva ichidagi Sozlamalar boʻlimini ochib, \"$action\" tugmasini bosishni soʻrang. Soʻng keraklisini uning telefonidan quyidagi istalgan usul bilan oling.';
  }

  @override
  String get peerReceivePhotograph => 'Doʻstingiz kodlarini suratga olish';

  @override
  String get peerReceivePhotographNext => 'Keyingi kodni suratga olish';

  @override
  String peerReceiveProgress(int have, int total) {
    return '$total ta koddan $have tasi oʻqildi';
  }

  @override
  String get peerReceiveFile => 'Doʻstingiz yuborgan faylni ochish';

  @override
  String get peerReceivePaste => 'Doʻstingiz yuborganini joylash';

  @override
  String get peerReceiveNoCode =>
      'Bu suratda kod topilmadi. Telefonni yaqinroq tuting, kod toʻliq koʻrinib tursin.';

  @override
  String get peerReceiveRefused =>
      'Fortiva bundan foydalana olmaydi. Doʻstingizdan qayta yuborishini soʻrang.';

  @override
  String get peerReceiveNotNewer =>
      'Bu sizda allaqachon bor yoki undan yangirogʻi bor. Qayta ulanib koʻring yoki boshqa doʻstingizdan soʻrang.';

  @override
  String get peerReceiveTaken => 'Tayyor. Ulanish uchun tugmani bosing.';

  @override
  String get peerReceiveUnavailable =>
      'Bu telefon buni qila olmaydi. Boshqa usulni sinab koʻring.';

  @override
  String get peerReceiveNothingToPaste =>
      'Hali hech narsa nusxalanmagan. Doʻstingiz yuborganini nusxalang, soʻng bu yerni yana bosing.';

  @override
  String get peerOfferBody =>
      'Hali ham ulanib boʻlmayaptimi? Fortiva ilovasi ishlayotgan doʻstingiz oʻz telefonidan yordam bera oladi.';

  @override
  String get peerReceiveAgain =>
      'Bu kod sizda allaqachon bor. Doʻstingizdan keyingisini koʻrsatishini soʻrang.';

  @override
  String get peerReceivePasteNotOurs =>
      'Nusxalaganingiz Fortiva ilovasidan emas. Doʻstingiz xabarini toʻliq nusxalang, soʻng qayta urinib koʻring.';

  @override
  String peerReceiveNoPhoto(String action) {
    return 'Kamera suratni qaytarmadi. Suratni kamera ilovasida oling, soʻng \"$action\" tugmasini bosing.';
  }

  @override
  String get peerReceiveFileHint =>
      'Messenjerdan kelgan faylni avval Yuklanmalar jildiga saqlash kerak boʻlishi mumkin.';

  @override
  String get homeTryingBackup =>
      'Boshqa hech narsa ulanmadi. Endi zaxira tarmoqni sinab koʻramiz.';

  @override
  String get homeConnectedBackup => 'Zaxira tarmoq orqali ulandi';

  @override
  String get backupNetwork => 'ZAXIRA TARMOQ';

  @override
  String get backupNetworkTitle => 'Zaxira tarmoq';

  @override
  String get backupNetworkCaption =>
      'Boshqa hech narsa ulanmaganda ishlatiladi. Serverlarimizdan sekinroq boʻlishi mumkin.';

  @override
  String get backupNetworkPlace => 'Joylashuv avtomatik tanlanadi';

  @override
  String get speedTestStart => 'Testni boshlash';

  @override
  String get speedTestAgain => 'Qayta tekshirish';

  @override
  String get speedTestRunning => 'Tekshirilmoqda';

  @override
  String get speedTestIdle =>
      'Ulanishingiz hozir qanchalik tez ekanini bilib oling.';

  @override
  String get speedTestPhasePing => 'Javob vaqti tekshirilmoqda';

  @override
  String get speedTestPhaseDownload => 'Yuklab olish tezligi oʻlchanmoqda';

  @override
  String get speedTestPhaseUpload => 'Yuklash tezligi oʻlchanmoqda';

  @override
  String get speedTestDone => 'Test tugadi';

  @override
  String get speedTestFailed =>
      'Test yakunlanmadi. Internetingizni tekshirib, qayta urinib koʻring.';

  @override
  String get speedTestUnit => 'Mbit/s';

  @override
  String get ipAddressLabel => 'IP manzil';

  @override
  String get ipCopied => 'Manzil nusxalandi';

  @override
  String get ipLocation => 'Joylashuv';

  @override
  String get ipProvider => 'Internet provayderi';

  @override
  String get ipOrganization => 'Tashkilot';

  @override
  String get ipTimeZone => 'Vaqt mintaqasi';

  @override
  String get ipCoordinates => 'Koordinatalar';

  @override
  String get ipCheckFailed => 'Manzilingizni tekshirib boʻlmadi';

  @override
  String get historyAverage => 'Oʻrtacha';

  @override
  String get historyRecentDays => 'Soʻnggi kunlar';

  @override
  String yesterdayAt(String time) {
    return 'Kecha soat $time';
  }

  @override
  String dateAt(String date, String time) {
    return '$date, soat $time';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds soniya';
  }

  @override
  String get stageOwn => 'Fortiva serverlari';

  @override
  String get stageCommunity => 'Hamjamiyat serverlari';

  @override
  String stageProgress(int n, int total) {
    return '$total bosqichdan $n-bosqich';
  }

  @override
  String get stageTryingOwn => 'Fortiva serverlari sinab koʻrilmoqda';

  @override
  String get stageTryingCommunity => 'Hamjamiyat serverlari sinab koʻrilmoqda';

  @override
  String get stageOwnFailedTryingCommunity =>
      'Fortiva serverlari bu yerda ulanmadi. Endi hamjamiyat serverlarini sinab koʻramiz.';

  @override
  String stageLastWorked(String server) {
    return 'Oxirgi ishlagan server: $server';
  }

  @override
  String stageTriedBlocked(int count) {
    return '$count ta yoʻl sinaldi, bu yerda bloklangan';
  }

  @override
  String stageTriedFailed(int count) {
    return '$count ta yoʻl sinaldi, hech biri ulanmadi';
  }

  @override
  String get stageNotConnected => 'Ulanmadi';

  @override
  String get stageConnected => 'Shu yerda ulandi';

  @override
  String get stageSkipped => 'Bu safar oʻtkazib yuborildi';

  @override
  String stageMoreToCheck(int count) {
    return 'Yana $count ta yoʻl tekshiriladi';
  }

  @override
  String stageNextTry(String stage, String time) {
    return 'Keyingi urinish $time dan soʻng, $stage bilan boshlanadi';
  }

  @override
  String get searchSlowHint =>
      'Bu bir-ikki daqiqa olishi mumkin. Qidiruvni toʻxtatish uchun tugmani bosing.';

  @override
  String get searchStopped => 'Qidiruv toʻxtatildi';

  @override
  String get homeConnectedCommunity => 'Hamjamiyat serveri orqali ulandi';

  @override
  String get stageGettingServers => 'Serverlaringiz olinmoqda';

  @override
  String stageNextTryStarting(String stage) {
    return 'Keyingi urinish hozir $stage bilan boshlanmoqda';
  }
}
