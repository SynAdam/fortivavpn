// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class SUr extends S {
  SUr([String locale = 'ur']) : super(locale);

  @override
  String get appTitle => 'FortivaVPN';

  @override
  String get statusDisconnected => 'منقطع';

  @override
  String get statusConnecting => 'رابطہ ہو رہا ہے';

  @override
  String get statusConnected => 'متصل';

  @override
  String get statusDisconnecting => 'منقطع ہو رہا ہے';

  @override
  String get statusError => 'خرابی';

  @override
  String get statusVerifying => 'تصدیق ہو رہی ہے...';

  @override
  String get disconnect => 'منقطع کریں';

  @override
  String get connectBtn => 'رابطہ کریں';

  @override
  String get disconnectBtn => 'منقطع کریں';

  @override
  String get pleaseWait => 'براہ کرم انتظار کریں';

  @override
  String get locationLabel => 'مقام:';

  @override
  String get selectServer => 'سرور منتخب کریں';

  @override
  String get serverLocation => 'سرور کا مقام';

  @override
  String get searchServers => 'سرور تلاش کریں';

  @override
  String get locationsTitle => 'مقامات';

  @override
  String get sortLatency => 'ترتیب: تاخیر';

  @override
  String get sortAZ => 'ترتیب: الف-ی';

  @override
  String get sortedByLatency => 'تاخیر کے مطابق ترتیب';

  @override
  String get sortedAZ => 'حروف تہجی میں ترتیب';

  @override
  String get pingAll => 'سب کو پنگ کریں';

  @override
  String get pinging => 'پنگ ہو رہا ہے...';

  @override
  String get ping => 'پنگ';

  @override
  String get stop => 'رکیں';

  @override
  String get fastestServer => 'تیز ترین سرور';

  @override
  String get timeout => 'وقت ختم';

  @override
  String get tabCommunity => 'کمیونٹی';

  @override
  String get tabFree => 'مفت';

  @override
  String get tabPremium => 'پریمیم';

  @override
  String get noCommunityServers => 'کوئی کمیونٹی سرور نہیں';

  @override
  String get communityLoadFailed => 'یہ فہرست لوڈ نہیں ہو سکی';

  @override
  String get communityRetry => 'دوبارہ کوشش کریں';

  @override
  String get officialTabExplainer =>
      'Fortiva انہیں چلاتا ہے اور ہم انہیں آن لائن رکھتے ہیں۔ ایپ استعمال کرنے والے سب کے درمیان مشترک۔ یہاں سے شروع کریں۔';

  @override
  String get communityTabExplainer =>
      'اضافی کنکشن آپشنز۔ رفتار اور دستیابی بدلتی رہتی ہے۔';

  @override
  String get noFreeServers => 'کوئی مفت سرور نہیں';

  @override
  String get noPremiumServers => 'کوئی پریمیم سرور نہیں';

  @override
  String noResultsFor(String query) {
    return '\"$query\" کے لیے کوئی نتیجہ نہیں';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get freeBadge => 'مفت';

  @override
  String get settings => 'ترتیبات';

  @override
  String get connection => 'رابطہ';

  @override
  String get dnsConfiguration => 'DNS ترتیبات';

  @override
  String get customDns => 'حسب ضرورت DNS سرورز';

  @override
  String get about => 'کے بارے میں';

  @override
  String get privacyPolicy => 'رازداری کی پالیسی';

  @override
  String get contactUs => 'ہم سے رابطہ کریں';

  @override
  String get rateOnGooglePlay => 'Google Play پر Fortiva کو ریٹ کریں';

  @override
  String get website => 'ویب سائٹ';

  @override
  String get copyright => '© 2026 NimusAI';

  @override
  String get version => 'ورژن';

  @override
  String get language => 'زبان';

  @override
  String get languageSubtitle => 'ایپ ڈسپلے زبان';

  @override
  String get whatIsDns => 'DNS کیا ہے؟';

  @override
  String get dnsExplanation =>
      'DNS (ڈومین نام سسٹم) انٹرنیٹ کی فون بک ہے۔ یہ ویب سائٹ کے ناموں کو IP پتوں میں تبدیل کرتا ہے۔\n\nاپنا DNS حسب ضرورت بنانا:\n• رابطے کی رفتار بہتر کر سکتا ہے ⚡\n• رازداری بڑھا سکتا ہے 🔒\n• سنسرشپ بلاکس کو بائی پاس کر سکتا ہے 🌍';

  @override
  String get configuration => 'ترتیبات';

  @override
  String get primaryDns => 'بنیادی DNS';

  @override
  String get primaryDnsHint => 'پہلے سے طے شدہ: 1.1.1.1';

  @override
  String get secondaryDns => 'ثانوی DNS (اختیاری)';

  @override
  String get secondaryDnsHint => 'پہلے سے طے شدہ: 8.8.8.8';

  @override
  String get saveConfiguration => 'ترتیبات محفوظ کریں';

  @override
  String get dnsSaved => 'DNS ترتیبات محفوظ ہو گئیں';

  @override
  String get invalidPrimaryDns => 'بنیادی DNS IP پتہ غلط ہے';

  @override
  String get invalidSecondaryDns => 'ثانوی DNS IP پتہ غلط ہے';

  @override
  String get statistics => 'اعدادوشمار';

  @override
  String get overview => 'جائزہ';

  @override
  String get connectionsLabel => 'رابطے';

  @override
  String get totalTime => 'کل وقت';

  @override
  String get dataUsage => 'ڈیٹا استعمال';

  @override
  String get uploaded => 'اپ لوڈ';

  @override
  String get downloaded => 'ڈاؤن لوڈ';

  @override
  String get total => 'کل';

  @override
  String lastUpdated(String date) {
    return 'آخری تازہ کاری: $date';
  }

  @override
  String today(String time) {
    return 'آج $time بجے';
  }

  @override
  String get yesterday => 'کل';

  @override
  String daysAgo(int count) {
    return '$count دن پہلے';
  }

  @override
  String get noDataYet => 'ابھی تک کوئی ڈیٹا نہیں';

  @override
  String get connectToStart => 'ٹریکنگ شروع کرنے کے لیے VPN سے رابطہ کریں';

  @override
  String get errorConnectionFailed => 'رابطہ ناکام';

  @override
  String get errorServerNotWorking => 'سرور کام نہیں کر رہا — دوسرا آزمائیں';

  @override
  String get errorServerNotForwarding => 'سرور ٹریفک فارورڈ نہیں کر رہا';

  @override
  String get errorUnexpected => 'غیر متوقع خرابی';

  @override
  String get errorDisconnectionFailed => 'منقطع ہونا ناکام';

  @override
  String get errorFailedToRegister => 'ڈیوائس رجسٹریشن ناکام';

  @override
  String get ipInformation => 'IP معلومات';

  @override
  String get connectionAnalytics => 'کنکشن تجزیات';

  @override
  String get recentSessions => 'حالیہ سیشنز';

  @override
  String get speedTest => 'رفتار ٹیسٹ';

  @override
  String get startTest => 'ٹیسٹ شروع کریں';

  @override
  String get download => 'ڈاؤن لوڈ';

  @override
  String get upload => 'اپ لوڈ';

  @override
  String get testingViaVpn => 'VPN کے ذریعے ٹیسٹ';

  @override
  String get testingDirect => 'براہ راست کنکشن ٹیسٹ';

  @override
  String get splitTunneling => 'اسپلٹ ٹنلنگ';

  @override
  String get splitTunnelingDescription =>
      'VPN ٹنل کو نظرانداز کرنے والی ایپ زمرہ جات منتخب کریں۔';

  @override
  String get enableSplitTunneling => 'اسپلٹ ٹنلنگ فعال کریں';

  @override
  String get splitTunnelActive => 'منتخب ایپس VPN کو نظرانداز کرتی ہیں';

  @override
  String get splitTunnelInactive => 'تمام ٹریفک VPN سے گزرتی ہے';

  @override
  String get bypassVpnFor => 'VPN نظرانداز کریں';

  @override
  String get tools => 'ٹولز';

  @override
  String get settingsGeneral => 'عمومی';

  @override
  String get shareDiagnosticsTitle => 'کنکشن کی تشخیصی معلومات شیئر کریں';

  @override
  String get shareDiagnosticsBody =>
      'کنکشن رپورٹس، آپ کا آپریٹر اور ملک، فون کا ماڈل اور اینڈرائیڈ ورژن، اور یہ کہ آپ نے ہمارے پیغامات، پریمیم آفرز اور دعوتی کارڈ دیکھے یا ان پر ٹیپ کیا، بھیجے جاتے ہیں۔ آپ جو صفحات کھولتے ہیں یا جو کچھ بھیجتے ہیں، وہ ہم کبھی نہیں دیکھتے۔';

  @override
  String get security => 'سیکیورٹی';

  @override
  String get privacyDashboard => 'پرائیویسی ڈیش بورڈ';

  @override
  String get privacyDashboardSubtitle => 'IP معلومات اور لیک تحفظ';

  @override
  String get connectionAnalyticsSubtitle => 'سیشن تاریخ اور چارٹس';

  @override
  String get speedTestSubtitle => 'اپنی کنکشن رفتار ٹیسٹ کریں';

  @override
  String get splitTunnelingSubtitle => 'ایپ VPN روٹنگ منتخب کریں';

  @override
  String get splashTagline => 'نجی رسائی، آپ جہاں بھی ہوں';

  @override
  String get openSourceLicence => 'اوپن سورس لائسنس';

  @override
  String get sourceOfferTitle => 'اوپن سورس لائسنس';

  @override
  String get sourceOfferBody =>
      'Fortiva VPN ایک آزاد سافٹ ویئر ہے جو GNU General Public License v3 کے تحت جاری کیا گیا ہے۔ یہ Xray-core اور دیگر اوپن سورس منصوبوں پر مبنی ہے۔\n\nآپ کو اس ورژن کا مکمل سورس کوڈ حاصل کرنے کا حق ہے جو آپ نے انسٹال کیا ہے۔ درخواست کے لیے اپنی ایپ کا ورژن لکھ کر admin@fortivavpn.com پر ای میل کریں۔ یہ پیشکش اس ورژن کے ملنے کی تاریخ سے تین سال تک لاگو رہے گی۔';

  @override
  String get close => 'بند کریں';

  @override
  String get account => 'اکاؤنٹ';

  @override
  String get deleteAccount => 'اکاؤنٹ حذف کریں';

  @override
  String get deleteAccountSubtitle =>
      'یہ ڈیوائس اور آپ کا ڈیٹا ہمیشہ کے لیے ہٹا دیں';

  @override
  String get deleteAccountConfirmTitle =>
      'کیا آپ اپنا اکاؤنٹ حذف کرنا چاہتے ہیں؟';

  @override
  String get deleteAccountConfirmBody =>
      'اس سے آپ کی ڈیوائس کی رجسٹریشن، آپ کے لیے بنائے گئے ذاتی سرور اور سپورٹ چیٹ میں آپ کے پیغامات ہٹا دیے جائیں گے۔ اس فون پر کنکشن کی تاریخ بھی مٹ جائے گی۔\n\nیہ واپس نہیں ہو سکتا۔ آپ کسی بھی وقت ایپ دوبارہ کھول کر نئے سرے سے شروع کر سکتے ہیں۔';

  @override
  String deleteAccountConfirmRetention(int days) {
    return 'آپ کا اکاؤنٹ ریکارڈ فوراً ہٹا دیا جاتا ہے۔ بیک اپ میں موجود نقول اور گمنام سرور لاگز $days دن کے اندر مٹا دیے جاتے ہیں۔';
  }

  @override
  String get deleteAccountConfirmRetentionNoDays =>
      'آپ کا اکاؤنٹ ریکارڈ فوراً ہٹا دیا جاتا ہے۔ بیک اپ میں موجود نقول اور گمنام سرور لاگز بعد میں، ہماری پرائیویسی پالیسی میں بتائی گئی مدت کے اندر، مٹا دیے جاتے ہیں۔';

  @override
  String get deleteAccountCancel => 'میرا اکاؤنٹ رہنے دیں';

  @override
  String get deleteAccountConfirm => 'حذف کریں';

  @override
  String get deleteAccountInProgress => 'آپ کا اکاؤنٹ حذف کیا جا رہا ہے';

  @override
  String get deleteAccountDone => 'آپ کا اکاؤنٹ حذف کر دیا گیا ہے۔';

  @override
  String get deleteAccountFailed =>
      'اکاؤنٹ حذف نہیں ہو سکا۔ اپنا کنکشن جانچیں اور دوبارہ کوشش کریں۔';

  @override
  String get homeTapToConnect => 'کنیکٹ کرنے کے لیے ٹیپ کریں';

  @override
  String get homeChecking => 'کنکشن چیک کیا جا رہا ہے';

  @override
  String get homePreparing => 'آپ کا سرور تیار کیا جا رہا ہے';

  @override
  String get homeDisconnecting => 'منقطع کیا جا رہا ہے';

  @override
  String get homeFindingPath => 'راستہ تلاش کیا جا رہا ہے';

  @override
  String get diagCheckingInternet => 'آپ کا انٹرنیٹ چیک کیا جا رہا ہے';

  @override
  String get diagInternationalCut =>
      'اس نیٹ ورک پر بین الاقوامی انٹرنیٹ بند ہے';

  @override
  String diagPathRow(String city, int n) {
    return '$city، راستہ $n';
  }

  @override
  String get diagOpen => 'کھلا';

  @override
  String get diagBlocked => 'بلاک';

  @override
  String get diagSkipped => 'آج چھوڑ دیا گیا';

  @override
  String diagConnectingThrough(String city) {
    return '$city کے ذریعے کنیکٹ ہو رہا ہے';
  }

  @override
  String get diagVerifying => 'ٹریفک کی تصدیق ہو رہی ہے';

  @override
  String get diagNoInternet => 'آپ کے فون پر ابھی انٹرنیٹ نہیں ہے۔';

  @override
  String get diagCutOff =>
      'آپ کا نیٹ ورک ابھی بین الاقوامی انٹرنیٹ تک نہیں پہنچ پا رہا۔ دوبارہ کوشش کے لیے ٹیپ کریں۔';

  @override
  String get diagNothingOpen =>
      'ابھی ہر راستہ بلاک ہے۔ دوبارہ کوشش کے لیے ٹیپ کریں۔';

  @override
  String get homeTryingAgain =>
      'ابھی ہر راستہ بلاک ہے۔ تھوڑی دیر میں دوبارہ کوشش کریں گے۔';

  @override
  String get homeCutOffTryingAgain =>
      'آپ کا نیٹ ورک ابھی بین الاقوامی انٹرنیٹ تک نہیں پہنچ پا رہا۔ تھوڑی دیر میں دوبارہ کوشش کریں گے۔';

  @override
  String get homeOfflineTryingAgain =>
      'آپ کے فون پر ابھی انٹرنیٹ نہیں ہے۔ تھوڑی دیر میں دوبارہ کوشش کریں گے۔';

  @override
  String get diagPathFailed =>
      'راستہ کھلا تھا لیکن VPN ٹنل قائم نہیں ہو سکی۔ دوبارہ کوشش کے لیے ٹیپ کریں۔';

  @override
  String get openVpnSettings => 'VPN سیٹنگز کھولیں';

  @override
  String get yourServer => 'آپ کا سرور';

  @override
  String get yourServerCaption => 'صرف آپ کا۔ اس سے کوئی اور کنیکٹ نہیں ہوتا۔';

  @override
  String get ourServer => 'ہمارا سرور';

  @override
  String get ourServerCaption =>
      'Fortiva اسے چلاتا ہے اور سب کے ساتھ مشترک ہے۔ آپ کا اپنا سرور تیار ہونے تک استعمال ہوتا ہے۔';

  @override
  String get communityServer => 'کمیونٹی سرور';

  @override
  String get communityServerCaption =>
      'ایک اضافی کنکشن آپشن۔ یہ کسی بھی وقت بند ہو سکتا ہے۔';

  @override
  String communityServerNumber(String n) {
    return 'کمیونٹی سرور $n';
  }

  @override
  String get myServersTitle => 'آپ کے سرورز';

  @override
  String get myServersExplainer =>
      'ہر Fortiva ڈیوائس کو ہر مقام پر اپنا سرور ملتا ہے، جس کی اسناد صرف اسی انسٹال کی ہوتی ہیں۔ کسی اکاؤنٹ کی ضرورت نہیں۔';

  @override
  String get myServersInUse => 'زیرِ استعمال';

  @override
  String get myServersEmpty => 'ابھی تک کوئی سرور تفویض نہیں ہوا';

  @override
  String get myServersRetry => 'دوبارہ کوشش کریں';

  @override
  String get myServersBlockedTitle => 'آپ آج کا ڈیٹا استعمال کر چکے ہیں';

  @override
  String get myServersBlockedWait =>
      'آپ کا کوٹا خودبخود ری سیٹ ہو جاتا ہے۔ کچھ دیر بعد دوبارہ دیکھیں۔';

  @override
  String myServersMoved(String place) {
    return 'اب $place استعمال ہو رہا ہے';
  }

  @override
  String get copyLink => 'لنک کاپی کریں';

  @override
  String get linkCopied => 'لنک کاپی ہو گیا';

  @override
  String quotaUsedToday(String used, String limit) {
    return 'آج $limit میں سے $used استعمال ہوا';
  }

  @override
  String get quotaUsedUp => 'روزانہ کا ڈیٹا ختم';

  @override
  String get quotaUnlimited => 'لامحدود ڈیٹا';

  @override
  String get quotaDaily => 'روزانہ ڈیٹا';

  @override
  String get quotaLimitReached => 'روزانہ حد پوری';

  @override
  String quotaLeftOf(String left, String limit) {
    return '$limit میں سے $left باقی';
  }

  @override
  String get quotaResetsShortly => 'جلد ری سیٹ ہو جائے گا';

  @override
  String quotaResetsInHours(int hours) {
    return '$hours گھنٹے میں ری سیٹ ہوگا';
  }

  @override
  String quotaResetsInMinutes(int minutes) {
    return '$minutes منٹ میں ری سیٹ ہوگا';
  }

  @override
  String get myServersSubtitle => 'اس ڈیوائس کے لیے مختص سرورز';

  @override
  String get sharedServersTitle => 'مشترکہ سرورز';

  @override
  String get sharedServersSubtitle => 'عوامی مقامات، متبادل کے طور پر';

  @override
  String get tabOfficial => 'ہمارے سرور';

  @override
  String get noOfficialServers => 'ابھی کوئی Fortiva سرور نہیں';

  @override
  String get inviteTitle => 'دوستوں کو مدعو کریں';

  @override
  String get inviteSubtitle => 'روزانہ مزید ڈیٹا حاصل کریں';

  @override
  String get inviteYourCode => 'آپ کا دعوتی کوڈ';

  @override
  String get inviteShareAction => 'دعوت شیئر کریں';

  @override
  String get inviteCopyAction => 'کوڈ کاپی کریں';

  @override
  String get inviteCodeCopied => 'کوڈ کاپی ہو گیا';

  @override
  String inviteShareMessage(String code, String url) {
    return 'ایک مفت VPN جو میرے لیے اچھا چلتا ہے: Fortiva۔ سائن اپ کی ضرورت نہیں۔\nاس لنک سے انسٹال کریں:\n$url\nمیرا دعوتی کوڈ: $code';
  }

  @override
  String get inviteHowItWorks => 'یہ کیسے کام کرتا ہے';

  @override
  String inviteHowItWorksBody(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days مختلف دنوں میں',
      one: '$days دن',
    );
    return 'اپنا کوڈ شیئر کریں۔ جب کوئی ایپ انسٹال کرے، کوڈ درج کرے اور $_temp0 وی پی این استعمال کرے، تو آپ کے روزانہ ڈیٹا میں $amount شامل ہو جائے گا اور برقرار رہے گا۔';
  }

  @override
  String inviteHowItWorksBodyNoAmount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days مختلف دنوں میں',
      one: '$days دن',
    );
    return 'اپنا کوڈ شیئر کریں۔ جب کوئی ایپ انسٹال کرے، کوڈ درج کرے اور $_temp0 وی پی این استعمال کرے، تو آپ کا روزانہ ڈیٹا بڑھ جائے گا اور یہ اضافہ برقرار رہے گا۔';
  }

  @override
  String inviteHowItWorksBodyNoDays(String amount) {
    return 'اپنا کوڈ شیئر کریں۔ جب کوئی ایپ انسٹال کرے، کوڈ درج کرے اور کچھ عرصہ وی پی این استعمال کرے، تو آپ کے روزانہ ڈیٹا میں $amount شامل ہو جائے گا اور برقرار رہے گا۔';
  }

  @override
  String get inviteHowItWorksBodyNoAmountNoDays =>
      'اپنا کوڈ شیئر کریں۔ جب کوئی ایپ انسٹال کرے، کوڈ درج کرے اور کچھ عرصہ وی پی این استعمال کرے، تو آپ کا روزانہ ڈیٹا بڑھ جائے گا اور یہ اضافہ برقرار رہے گا۔';

  @override
  String inviteHowItWorksCap(String max) {
    return 'دعوتوں سے آپ روزانہ زیادہ سے زیادہ $max حاصل کر سکتے ہیں۔';
  }

  @override
  String get inviteStatInvited => 'مدعو کیے گئے';

  @override
  String get inviteStatEarning => 'اہل';

  @override
  String get inviteStatBonus => 'اضافی ڈیٹا';

  @override
  String inviteBonusPerDay(String amount) {
    return '+$amount روزانہ';
  }

  @override
  String get inviteNoBonusYet => 'ابھی کوئی بونس نہیں';

  @override
  String invitePendingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دعوتیں ابھی اہل نہیں ہوئیں',
      one: 'ایک دعوت ابھی اہل نہیں ہوئی',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String inviteJoinedWith(String code) {
    return 'آپ نے کوڈ $code کے ساتھ شمولیت اختیار کی';
  }

  @override
  String get inviteLoadFailed => 'آپ کا دعوتی کوڈ لوڈ نہیں ہو سکا';

  @override
  String get inviteRetry => 'دوبارہ کوشش کریں';

  @override
  String get inviteHaveCodeTitle => 'کیا آپ کے پاس دعوتی کوڈ ہے؟';

  @override
  String inviteHaveCodeSubtitle(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'اسے پہلے $hours گھنٹوں میں درج کریں',
      one: 'اسے پہلے گھنٹے میں درج کریں',
    );
    return '$_temp0';
  }

  @override
  String get inviteHaveCodeSubtitleNoHours =>
      'اسے انسٹال کرنے کے کچھ ہی دیر بعد درج کریں';

  @override
  String get inviteEnterCodeHint => 'دعوتی کوڈ';

  @override
  String get inviteApplyAction => 'لاگو کریں';

  @override
  String get inviteNotNowAction => 'ابھی نہیں';

  @override
  String inviteClaimAccepted(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days مختلف دنوں میں',
      one: '$days دن',
    );
    return 'دعوت قبول کر لی گئی۔ آج سے جب آپ $_temp0 وی پی این استعمال کریں گے تو یہ گنی جائے گی۔';
  }

  @override
  String get inviteClaimAcceptedNoDays =>
      'دعوت قبول کر لی گئی۔ آج سے جب آپ کچھ عرصہ وی پی این استعمال کریں گے تو یہ گنی جائے گی۔';

  @override
  String get inviteClaimAlready =>
      'اس ڈیوائس نے پہلے ہی ایک دعوتی کوڈ استعمال کیا ہے';

  @override
  String get inviteClaimRejected =>
      'یہ کوڈ کام نہیں کیا۔ اسے چیک کر کے دوبارہ کوشش کریں';

  @override
  String get inviteClaimNetwork =>
      'سرور تک رسائی نہیں ہو سکی۔ دوبارہ کوشش کریں';

  @override
  String get inviteCardTitle =>
      'کیا Fortiva آپ کے لیے اچھا چل رہا ہے؟ اسے اپنے دوستوں کو بھیجیں';

  @override
  String get inviteCardBody =>
      'اپنے دوست کو انسٹال کا لنک بھیجیں تاکہ وہ بھی مفت کنیکٹ ہو سکیں۔';

  @override
  String inviteCardReward(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'جب آپ کا دوست Fortiva استعمال کرنا شروع کرے گا تو آپ کو $days دن کا پریمیم ملے گا۔',
      one:
          'جب آپ کا دوست Fortiva استعمال کرنا شروع کرے گا تو آپ کو $days دن کا پریمیم ملے گا۔',
    );
    return '$_temp0';
  }

  @override
  String get inviteCardRewardNoAmount =>
      'جب آپ کا دوست Fortiva استعمال کرنا شروع کرے گا تو آپ کو تحفے میں پریمیم ملے گا۔';

  @override
  String get inviteSendTelegram => 'ٹیلیگرام';

  @override
  String get inviteSendWhatsApp => 'واٹس ایپ';

  @override
  String get inviteCopyLink => 'لنک کاپی کریں';

  @override
  String get inviteOtherApps => 'دوسری ایپس';

  @override
  String get inviteLinkCopied => 'دعوتی پیغام کاپی ہو گیا';

  @override
  String get invitePasteBody =>
      'اپنے دوست کے پیغام سے کوڈ کاپی کریں اور یہاں پیسٹ کریں۔';

  @override
  String get invitePasteAction => 'پیسٹ کریں';

  @override
  String get inviteErrorTooLate =>
      'اس فون پر دعوتی کوڈ درج کرنے کا وقت گزر چکا ہے۔';

  @override
  String get inviteErrorUnknown =>
      'ہمیں یہ کوڈ نہیں ملا۔ اسے اپنے دوست کے پیغام سے دوبارہ کاپی کریں۔';

  @override
  String get inviteErrorOwnCode =>
      'یہ آپ کا اپنا کوڈ ہے۔ اپنے دوست کا کوڈ درج کریں۔';

  @override
  String get inviteErrorMutual =>
      'آپ اور آپ کا دوست ایک دوسرے کو مدعو نہیں کر سکتے۔';

  @override
  String inviteHowItWorksPremium(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'ہر وہ دوست جو Fortiva استعمال کرنا شروع کرے، آپ کو $days دن کا پریمیم بھی دلاتا ہے۔',
      one:
          'ہر وہ دوست جو Fortiva استعمال کرنا شروع کرے، آپ کو $days دن کا پریمیم بھی دلاتا ہے۔',
    );
    return '$_temp0';
  }

  @override
  String inviteHowItWorksPremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'دعوتوں سے آپ زیادہ سے زیادہ $max دن کا پریمیم حاصل کر سکتے ہیں۔',
      one: 'دعوتوں سے آپ زیادہ سے زیادہ $max دن کا پریمیم حاصل کر سکتے ہیں۔',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeLive =>
      'آپ کا بونس تب تک چلتا ہے جب تک آپ کے دوست Fortiva استعمال کرتے رہیں۔ اگر کوئی دوست چھوڑ دے تو یہ گھٹ سکتا ہے۔';

  @override
  String inviteTreeNext(String amount) {
    return 'آپ کا اگلا دوست اہل اور فعال ہونے پر روزانہ $amount شامل کرتا ہے۔';
  }

  @override
  String inviteTreeKept(String amount) {
    return 'آپ کا بونس روزانہ $amount سے کم نہیں ہوتا، یہ وہ بونس ہے جو آپ کو پچھلی دعوتوں سے ملا تھا۔ یہ مقدار تبھی گھٹ سکتی ہے جب آپ کی کوئی دعوت ہٹائی جائے۔';
  }

  @override
  String get inviteTreeSlotsTitle => 'آپ کی جگہیں';

  @override
  String get inviteTreeSlotActive => 'فعال';

  @override
  String get inviteTreeSlotNotActive => 'ابھی فعال نہیں';

  @override
  String get inviteTreeSlotEmpty => 'خالی جگہ';

  @override
  String inviteTreePaysNow(String amount) {
    return '+$amount روزانہ، ابھی';
  }

  @override
  String inviteTreePairFull(String amount) {
    return '+$amount روزانہ، جب دونوں فعال ہوں';
  }

  @override
  String get inviteTreeNothingYet => 'ابھی کچھ نہیں';

  @override
  String get inviteTreeFriendsTitle => 'آپ کی جگہوں کے ذریعے';

  @override
  String get inviteTreeRowFriends => 'آپ کی جگہوں میں';

  @override
  String inviteTreeRowSteps(int steps) {
    String _temp0 = intl.Intl.pluralLogic(
      steps,
      locale: localeName,
      other: '$steps قدم دور',
    );
    return '$_temp0';
  }

  @override
  String inviteTreeRowPeople(int people, int active) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people افراد',
      one: '$people شخص',
    );
    return '$_temp0، $active فعال';
  }

  @override
  String inviteTreeHowSlots(int slots) {
    String _temp0 = intl.Intl.pluralLogic(
      slots,
      locale: localeName,
      other:
          'اپنا کوڈ شیئر کریں۔ اہل ہونے والے پہلے $slots دوست آپ کی جگہیں جوڑیوں میں بھرتے ہیں۔',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeHowSlotsNoNumber =>
      'اپنا کوڈ شیئر کریں۔ اہل ہونے والے پہلے دوست آپ کی جگہیں جوڑیوں میں بھرتے ہیں۔';

  @override
  String get inviteTreeHowPair =>
      'جب کسی جوڑی کے دونوں لوگ فعال ہوں تو وہ زیادہ دیتی ہے۔';

  @override
  String get inviteTreeHowFriendsSlots =>
      'جب آپ کی جگہیں بھر جائیں تو اس کے بعد اہل ہونے والے آپ کے دوست اگلی خالی جگہیں لیتے ہیں، جو آپ سے مزید دور ہوتی ہیں۔ وہ بھی آپ کے ڈیٹا میں اضافہ کرتے ہیں، جتنا دور، اتنا کم۔';

  @override
  String get inviteTreeHowOthers =>
      'آپ کی پہلی جوڑی میں ایسے لوگ بھی آ سکتے ہیں جنہیں آپ نے مدعو نہیں کیا۔ وہ بھی اسی طرح آپ کے ڈیٹا میں اضافہ کرتے ہیں۔';

  @override
  String inviteTreeHowActive(int days, int window) {
    return 'کوئی دوست تب تک فعال گنا جاتا ہے جب تک اس نے پچھلے $window دنوں میں کم از کم $days دن وی پی این استعمال کیا ہو۔';
  }

  @override
  String get inviteTreeHowActiveNoNumber =>
      'کوئی دوست تب تک فعال گنا جاتا ہے جب تک وہ وی پی این استعمال کرتا رہے۔';

  @override
  String inviteTreeHowCap(String max) {
    return 'دعوتیں روزانہ زیادہ سے زیادہ $max کا اضافہ کر سکتی ہیں۔';
  }

  @override
  String get inviteTreeHowCapNoAmount =>
      'دعوتوں سے ملنے والے اضافے کی ایک روزانہ حد ہے۔';

  @override
  String get inviteTreeIntroTitle => 'دوست ڈیٹا کیسے بڑھاتے ہیں';

  @override
  String get inviteTreeIntroOpen => 'قدم بہ قدم دیکھیں';

  @override
  String inviteTreeIntroStep(int current, int total) {
    return 'قدم $current، کل $total';
  }

  @override
  String get inviteTreeIntroSkip => 'چھوڑیں';

  @override
  String get inviteTreeIntroNext => 'آگے';

  @override
  String get inviteTreeIntroBack => 'پیچھے';

  @override
  String get inviteTreeIntroDone => 'ہو گیا';

  @override
  String get inviteTreeIntroYou => 'آپ';

  @override
  String get inviteTreeIntroSlotsTitle =>
      'دوست آپ کی جگہیں جوڑیوں میں بھرتے ہیں';

  @override
  String get inviteTreeIntroSlotsArt =>
      'آپ، آپ کا دعوتی کوڈ، اور جوڑیوں میں آپ کی جگہیں۔ ہر جگہ دکھاتی ہے کہ وہ خالی ہے، یا اس میں موجود شخص فعال ہے یا ابھی فعال نہیں۔';

  @override
  String get inviteTreeIntroPairTitle =>
      'جب دونوں فعال ہوں تو جوڑی سب سے زیادہ اضافہ کرتی ہے';

  @override
  String inviteTreeIntroPairBoth(String full, String one) {
    return 'جب آپ کی پہلی جوڑی کے دونوں دوست فعال ہوں تو یہ روزانہ $full کا اضافہ کرتی ہے۔ جب ان میں سے صرف ایک فعال ہو تو یہ روزانہ $one کا اضافہ کرتی ہے۔';
  }

  @override
  String inviteTreeIntroPairBothOnly(String full) {
    return 'جب آپ کی پہلی جوڑی کے دونوں دوست فعال ہوں تو یہ روزانہ $full کا اضافہ کرتی ہے۔ جب ان میں سے صرف ایک فعال ہو تو یہ کوئی اضافہ نہیں کرتی۔';
  }

  @override
  String inviteTreeIntroPairNoOne(String full) {
    return 'جب آپ کی پہلی جوڑی کے دونوں دوست فعال ہوں تو یہ روزانہ $full کا اضافہ کرتی ہے۔ جب ان میں سے صرف ایک فعال ہو تو یہ کم اضافہ کرتی ہے۔';
  }

  @override
  String get inviteTreeIntroPairOthersLess =>
      'آپ کی باقی جوڑیاں کم اضافہ کرتی ہیں۔';

  @override
  String inviteTreeIntroAdds(String amount) {
    return '+$amount روزانہ';
  }

  @override
  String get inviteTreeIntroYourFriend => 'آپ کا دوست';

  @override
  String get inviteTreeIntroTotalTitle => 'دوستوں سے آپ کا ڈیٹا';

  @override
  String get inviteTreeIntroTotalNow => 'ابھی دوستوں سے';

  @override
  String get inviteTreeIntroTotalMost =>
      'دعوتیں زیادہ سے زیادہ اتنا بڑھا سکتی ہیں';

  @override
  String get inviteTreeIntroTotalKept => 'پچھلی دعوتوں سے محفوظ';

  @override
  String inviteTreeIntroTotalReach(String max) {
    return 'مفت ڈیٹا اور دوستوں کا ڈیٹا مل کر روزانہ $max تک پہنچ سکتا ہے۔';
  }

  @override
  String inviteTreeIntroPerDay(String amount) {
    return '$amount روزانہ';
  }

  @override
  String inviteTreeSheetNext(String amount) {
    return 'آپ کا اگلا دوست اہل اور فعال ہونے پر روزانہ $amount شامل کرتا ہے۔ یہ آج کے ڈیٹا میں شامل نہیں ہوتا۔';
  }

  @override
  String get inviteTreeHero => 'دوست آپ کا روزانہ ڈیٹا بڑھاتے ہیں';

  @override
  String inviteTreePremiumEach(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'آپ کے کوڈ سے اہل ہونے والا ہر دوست آپ کے لیے $days دن کا پریمیم بھی شامل کرتا ہے۔',
      one:
          'آپ کے کوڈ سے اہل ہونے والا ہر دوست آپ کے لیے $days دن کا پریمیم بھی شامل کرتا ہے۔',
    );
    return '$_temp0';
  }

  @override
  String inviteTreePremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'دعوتیں زیادہ سے زیادہ $max دن کا پریمیم دے سکتی ہیں۔',
      one: 'دعوتیں زیادہ سے زیادہ $max دن کا پریمیم دے سکتی ہیں۔',
    );
    return '$_temp0';
  }

  @override
  String inviteTreeIntroSlotsBody(int slots) {
    String _temp0 = intl.Intl.pluralLogic(
      slots,
      locale: localeName,
      other:
          'جو دوست آپ کے کوڈ سے شامل ہوتے ہیں، وہ آپ کے روزانہ ڈیٹا میں اضافہ کر سکتے ہیں۔ ان کے لیے آپ کے پاس $slots جگہیں ہیں۔ ہر جگہ میں ایک دوست آتا ہے، اور جگہیں جوڑیوں میں ہوتی ہیں۔ سب سے پہلے آپ کی پہلی جوڑی بھر جاتی ہے۔ آپ کی جگہیں بھر جانے کے بعد بھی مزید دوست شامل ہو سکتے ہیں۔',
      one:
          'جو دوست آپ کے کوڈ سے شامل ہوتے ہیں، وہ آپ کے روزانہ ڈیٹا میں اضافہ کر سکتے ہیں۔ ان کے لیے آپ کے پاس $slots جگہ ہے۔ ہر جگہ میں ایک دوست آتا ہے، اور جگہیں جوڑیوں میں ہوتی ہیں۔ سب سے پہلے آپ کی پہلی جوڑی بھر جاتی ہے۔ آپ کی جگہیں بھر جانے کے بعد بھی مزید دوست شامل ہو سکتے ہیں۔',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeIntroSlotsBodyNoNumber =>
      'جو دوست آپ کے کوڈ سے شامل ہوتے ہیں، وہ آپ کے روزانہ ڈیٹا میں اضافہ کر سکتے ہیں۔ ان کے لیے آپ کے پاس جگہیں ہیں۔ ہر جگہ میں ایک دوست آتا ہے، اور جگہیں جوڑیوں میں ہوتی ہیں۔ سب سے پہلے آپ کی پہلی جوڑی بھر جاتی ہے۔ آپ کی جگہیں بھر جانے کے بعد بھی مزید دوست شامل ہو سکتے ہیں۔';

  @override
  String get inviteTreeIntroJoinTitle => 'دوست کو جگہ کیسے ملتی ہے';

  @override
  String inviteTreeIntroJoinCode(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other:
          'آپ کے دوست کو Fortiva انسٹال کرنے کے $hours گھنٹوں کے اندر اپنی دعوت والی اسکرین پر آپ کا کوڈ درج کرنا ہوگا۔',
      one:
          'آپ کے دوست کو Fortiva انسٹال کرنے کے $hours گھنٹے کے اندر اپنی دعوت والی اسکرین پر آپ کا کوڈ درج کرنا ہوگا۔',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeIntroJoinCodeNoNumber =>
      'آپ کے دوست کو Fortiva انسٹال کرنے کے جلد بعد اپنی دعوت والی اسکرین پر آپ کا کوڈ درج کرنا ہوگا۔';

  @override
  String inviteTreeIntroJoinQualify(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'اس کے بعد اسے $days مختلف دنوں میں وی پی این استعمال کرنا ہوگا۔ تب وہ اہل ہو جاتا ہے اور اگلی خالی جگہ لے لیتا ہے۔',
      one:
          'اس کے بعد اسے $days دن وی پی این استعمال کرنا ہوگا۔ تب وہ اہل ہو جاتا ہے اور اگلی خالی جگہ لے لیتا ہے۔',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeIntroJoinQualifyNoNumber =>
      'اس کے بعد اسے کچھ عرصہ وی پی این استعمال کرنا ہوگا۔ تب وہ اہل ہو جاتا ہے اور اگلی خالی جگہ لے لیتا ہے۔';

  @override
  String get inviteTreeIntroJoinPlay =>
      'اگر وہ آپ کے لنک سے Google Play سے انسٹال کرے تو کوڈ اس کے لیے خود درج ہو جاتا ہے۔';

  @override
  String get inviteTreeIntroJoinWaiting =>
      'جب تک وہ اہل نہیں ہوتا، آپ کی دعوت والی اسکرین اسے \"مدعو کیے گئے\" میں گنتی ہے، لیکن ابھی \"اہل\" میں نہیں۔';

  @override
  String get inviteTreeIntroJoinStepCode => 'آپ کا کوڈ درج کرتا ہے';

  @override
  String get inviteTreeIntroJoinStepUse => 'وی پی این استعمال کرتا ہے';

  @override
  String get inviteTreeIntroJoinStepSlot => 'جگہ لیتا ہے';

  @override
  String get inviteTreeIntroJoinArt =>
      'ایک دوست آپ کا کوڈ درج کرتا ہے، مختلف دنوں میں وی پی این استعمال کرتا ہے، اور پھر اگلی خالی جگہ لے لیتا ہے۔';

  @override
  String get inviteTreeIntroPairsBody =>
      'ہر جوڑی آپ کے لیے ڈیٹا شامل کر سکتی ہے۔ جب اس کے دونوں لوگ فعال ہوں تو یہ سب سے زیادہ شامل کرتی ہے۔';

  @override
  String get inviteTreeIntroPairsCaption =>
      'ہر جوڑی روزانہ آپ کے ڈیٹا میں کتنا شامل کرتی ہے';

  @override
  String get inviteTreeIntroBothActive => 'دونوں فعال';

  @override
  String get inviteTreeIntroOneActive => 'ایک فعال';

  @override
  String inviteTreeIntroPlus(String amount) {
    return '+$amount';
  }

  @override
  String get inviteTreeIntroNothing => 'کچھ نہیں';

  @override
  String get inviteTreeIntroPairNow =>
      'نمایاں مقداریں وہ ہیں جو آپ کی جوڑیاں ابھی شامل کر رہی ہیں۔';

  @override
  String get inviteTreeIntroPairsArt =>
      'آپ کی جوڑیاں، اور ہر جوڑی روزانہ کتنا شامل کرتی ہے جب اس کے دونوں لوگ فعال ہوں، اور جب ایک ہو۔';

  @override
  String get inviteTreeIntroActiveTitle =>
      'دوست جب تک فعال ہے، ڈیٹا شامل کرتا ہے';

  @override
  String get inviteTreeIntroActiveStops =>
      'اگر کوئی دوست Fortiva استعمال کرنا چھوڑ دے تو اس کی جوڑی کم شامل کرتی ہے اور آپ کا بونس گھٹ سکتا ہے۔ اس کی جگہ اسی کے پاس رہتی ہے۔ جب وہ پھر سے Fortiva استعمال کرے تو اس کی جوڑی پھر سے زیادہ شامل کرتی ہے۔';

  @override
  String get inviteTreeIntroActiveFar =>
      'مزید دور کے لوگ جو آپ کے لیے ڈیٹا شامل کرتے ہیں، وہ بھی تبھی تک گنے جاتے ہیں جب تک وہ فعال ہوں۔';

  @override
  String get inviteTreeIntroActiveArt =>
      'ایک جوڑی جس میں ایک دوست نے Fortiva استعمال کرنا چھوڑ دیا ہے۔ اب یہ جوڑی کم شامل کرتی ہے۔';

  @override
  String get inviteTreeIntroFullTitle => 'جب آپ کی جگہیں بھر جائیں';

  @override
  String get inviteTreeIntroFullBody =>
      'جب آپ کی سب جگہیں بھر جاتی ہیں تو آپ کا اگلا دوست آپ کی جگہوں میں موجود کسی شخص کی پہلی جوڑی میں جاتا ہے، آپ کی پہلی جگہ سے ترتیب وار۔ وہ جوڑی اس شخص کے لیے ڈیٹا شامل کرتی ہے، اور آپ کے لیے کم۔';

  @override
  String get inviteTreeIntroFullLess =>
      'کوئی جگہ جتنی دور ہو، آپ کے لیے اتنا کم شامل کرتی ہے۔ بہت دور کی جگہیں کچھ شامل نہیں کرتیں۔';

  @override
  String get inviteTreeIntroNextFriend => 'آپ کا اگلا دوست';

  @override
  String get inviteTreeIntroLaterFriend => 'بعد کا کوئی دوست';

  @override
  String get inviteTreeIntroFullArt =>
      'بعد کا کوئی دوست آپ کی جگہوں میں موجود کسی شخص کی پہلی جوڑی میں خالی جگہ لیتا ہے۔ وہ جوڑی اس شخص کے لیے ڈیٹا شامل کرتی ہے، اور آپ کے لیے کم۔';

  @override
  String get inviteTreeIntroOthersTitle =>
      'آپ کی پہلی جوڑی میں ایسے لوگ ہو سکتے ہیں جنہیں آپ نے مدعو نہیں کیا';

  @override
  String get inviteTreeIntroOthersWhy =>
      'آپ کسی دوست کے کوڈ سے شامل ہوئے ہیں۔ جب اس کی جگہیں بھر جاتی ہیں تو اس کے اگلے دوست آپ کی پہلی جوڑی میں خالی جگہ لے سکتے ہیں۔ دوسرے لوگوں کے دوست بھی لے سکتے ہیں۔ جو بھی اسے لے، وہ آپ کے اپنے دوستوں کی طرح آپ کے لیے ڈیٹا شامل کرتا ہے۔';

  @override
  String get inviteTreeIntroOthersYours =>
      'آپ کے اپنے دوست آپ کی باقی خالی جگہیں بھرتے ہیں، اور اس کے بعد مزید دور کی خالی جگہیں۔';

  @override
  String get inviteTreeIntroNotInvited => 'آپ نے مدعو نہیں کیا';

  @override
  String get inviteTreeIntroOthersArt =>
      'آپ کی پہلی جوڑی کی ایک مثال، جس میں ایک دوست ہے جسے آپ نے مدعو کیا اور ایک شخص جسے آپ نے مدعو نہیں کیا۔ دونوں جب تک فعال ہیں، آپ کے لیے ڈیٹا شامل کرتے ہیں۔';

  @override
  String get inviteTreeIntroShareTitle =>
      'ان دوستوں کو مدعو کریں جو Fortiva استعمال کریں گے';

  @override
  String get inviteTreeIntroShareBody =>
      'کوئی دوست آپ کے لیے ڈیٹا تبھی تک شامل کرتا ہے جب تک وہ فعال ہو۔ اپنی دعوت ان دوستوں کو بھیجیں جنہیں وی پی این کی ضرورت ہے۔';

  @override
  String get inviteTreeQaTitle => 'سوالات اور جوابات';

  @override
  String get inviteTreeQaCountQ =>
      'میرے دوست نے میرا کوڈ درج کیا۔ اسے جگہ کب ملے گی؟';

  @override
  String get inviteTreeQaCountDay =>
      'کوئی دن تبھی گنا جاتا ہے جب اس دن وہ وی پی این کے ذریعے کچھ ڈیٹا استعمال کرے۔ صرف ایپ کھولنا کافی نہیں۔ ان دنوں کی کوئی آخری تاریخ نہیں ہے۔';

  @override
  String get inviteTreeQaCountOther =>
      'جس فون پر پہلے ہی کوڈ درج ہو چکا ہو، اس پر دوسرا کوڈ درج نہیں ہو سکتا۔ آپ اور آپ کا دوست ایک دوسرے کا کوڈ درج نہیں کر سکتے۔';

  @override
  String get inviteTreeQaDownQ => 'میرا بونس کیوں گھٹ گیا؟';

  @override
  String get inviteTreeQaDownA =>
      'آپ کے لیے ڈیٹا شامل کرنے والا کوئی شخص ابھی فعال نہیں ہے۔ یہ آپ کی جگہوں میں کوئی دوست ہو سکتا ہے یا مزید دور کا کوئی شخص۔ جب وہ پھر سے Fortiva استعمال کرے گا تو پھر سے ڈیٹا شامل کرے گا۔';

  @override
  String get inviteTreeQaDownLater =>
      'استعمال چھوڑنے والا دوست کچھ عرصہ تک فعال گنا جاتا رہتا ہے۔ اس لیے آپ کا بونس اس کے چھوڑنے کے کچھ عرصہ بعد گھٹ سکتا ہے۔';

  @override
  String get inviteTreeQaDownRemoved =>
      'کوئی دعوت ہٹائے جانے پر بھی آپ کا بونس گھٹ سکتا ہے، مثلاً جب وہ دوست اپنا Fortiva اکاؤنٹ حذف کر دے۔';

  @override
  String get inviteTreeQaFullQ => 'جب میری جگہیں بھر جائیں تو کیا ہوتا ہے؟';

  @override
  String get inviteTreeQaFullFurther =>
      'جب وہ پہلی جوڑیاں بھی بھر جاتی ہیں تو آپ کا اگلا دوست مزید دور جاتا ہے، ان جوڑیوں میں موجود کسی شخص کی پہلی جوڑی میں۔ وہ جوڑی اس شخص کے لیے ڈیٹا شامل کرتی ہے، اور آپ کے لیے اور بیچ کے ہر شخص کے لیے کم مقدار۔';

  @override
  String get inviteTreeQaFriendsQ =>
      'کیا میرے دوستوں کے دوست بھی میرے لیے ڈیٹا شامل کرتے ہیں؟';

  @override
  String get inviteTreeQaFriendsA =>
      'ان میں سے بعض ہاں۔ آپ کی جگہوں میں موجود ہر شخص کی پہلی جوڑی اس شخص کے لیے ڈیٹا شامل کرتی ہے، اور آپ کے لیے کم مقدار۔ ان کی باقی جوڑیاں صرف ان کے لیے ڈیٹا شامل کرتی ہیں۔ مزید دور، صرف پہلی جوڑیاں آپ کے لیے ڈیٹا شامل کرتی ہیں، اور وہ جتنی دور ہوں اتنا کم شامل کرتی ہیں، یہاں تک کہ کچھ بھی شامل نہ کریں۔';

  @override
  String get inviteTreeQaOthersQ =>
      'میری جگہوں میں وہ لوگ کون ہیں جنہیں میں نے مدعو نہیں کیا؟';

  @override
  String get inviteTreeQaOthersA =>
      'وہ کسی ایسے شخص کے دوست ہیں جس کی جگہیں بھری ہوئی ہیں، مثلاً وہ شخص جس نے آپ کو مدعو کیا۔ انہوں نے آپ کی پہلی جوڑی میں خالی جگہ لی ہے، اور آپ انہیں نہ چن سکتے ہیں نہ ہٹا سکتے ہیں۔ وہ آپ کے اپنے دوستوں کی طرح آپ کے لیے ڈیٹا شامل کرتے ہیں۔';

  @override
  String get inviteTreeQaSumQ =>
      'میرا بونس دعوت والی اسکرین کی مقداروں سے مختلف کیوں ہے؟';

  @override
  String get inviteTreeQaSumA =>
      '\"آپ کی جگہوں کے ذریعے\" کی ہر قطار دکھاتی ہے کہ اس قطار کے لوگ ابھی کتنا شامل کر رہے ہیں۔ آپ کا بونس ان کا مجموعہ ہے، زیادہ سے زیادہ حد تک۔';

  @override
  String get inviteTreeQaSlotQ =>
      'کیا میں کوئی جگہ خالی کر سکتا ہوں یا چن سکتا ہوں کہ اسے کون لے؟';

  @override
  String get inviteTreeQaSlotA =>
      'نہیں۔ کوئی دوست Fortiva استعمال کرنا چھوڑ دے تب بھی اس کی جگہ اسی کے پاس رہتی ہے۔ اس کی جگہ تبھی دوبارہ خالی ہوتی ہے جب اس کی دعوت ہٹائی جائے، مثلاً جب وہ اپنا Fortiva اکاؤنٹ حذف کر دے۔ خالی جگہیں ترتیب سے بھر جاتی ہیں، اور کوئی نہیں چن سکتا کہ انہیں کون لے۔';

  @override
  String get inviteTreeQaPrivacyQ =>
      'کیا میرے دوست دیکھ سکتے ہیں کہ میں Fortiva استعمال کرتا ہوں؟';

  @override
  String get inviteTreeQaPrivacyA =>
      'اگر آپ کسی دوست کے کوڈ سے شامل ہوئے ہیں تو جس شخص کی جگہوں میں آپ ہیں، وہ دیکھ سکتا ہے کہ آپ فعال ہیں یا ابھی فعال نہیں۔ باقی لوگ صرف یہ دیکھتے ہیں کہ کتنے لوگ فعال ہیں، یہ نہیں کہ کون۔ دعوت والی اسکرین کبھی کسی کا نام، فون یا استعمال کی مقدار نہیں دکھاتی۔';

  @override
  String get inviteTreeQaLimitQ => 'کیا کوئی حد ہے؟';

  @override
  String get inviteTreeQaLimitMore =>
      'جب آپ کی دعوتیں اتنا شامل کرنے لگیں تو مزید دوست مزید ڈیٹا شامل نہیں کرتے۔';

  @override
  String get inviteTreeQaKeptQ =>
      'میرے پاس پہلے سے جو بونس ہے، اس کا کیا ہوگا؟';

  @override
  String get inviteTreeQaKeptMore =>
      'جب آپ کی پچھلی دعوتوں کا بونس اس سے زیادہ ہو جو آپ کے دوست ابھی شامل کر رہے ہیں، تو آپ کو وہی بونس ملتا ہے۔ دونوں کو جمع نہیں کیا جاتا۔';

  @override
  String get inviteTreeQaKeptRemoved =>
      'کوئی دعوت تب ہٹتی ہے جب وہ دوست اپنا Fortiva اکاؤنٹ حذف کر دے، یا جب Fortiva اسے غلط استعمال کی وجہ سے منسوخ کر دے۔';

  @override
  String get inviteTreeQaChangedQ => 'دعوتوں میں کیا بدلا ہے؟';

  @override
  String get inviteTreeQaChangedA =>
      'پہلے، اہل ہونے والا ہر دوست ڈیٹا کی ایک مقررہ مقدار شامل کرتا تھا۔ اب دوست جب تک فعال ہیں، آپ کی جگہوں اور جوڑیوں کے ذریعے ڈیٹا شامل کرتے ہیں، اور آپ کا بونس گھٹ سکتا ہے۔';

  @override
  String get inviteTreeQaPremiumQ =>
      'کیا دعوتیں پریمیم کے دن بھی شامل کرتی ہیں؟';

  @override
  String get inviteTreeQaPremiumOwn =>
      'اس سے فرق نہیں پڑتا کہ آپ کا دوست کون سی جگہ لیتا ہے۔ جن لوگوں کو آپ نے مدعو نہیں کیا، وہ پریمیم کے دن شامل نہیں کرتے۔';

  @override
  String get inviteTreeQaGetsQ => 'کیا میرے دوست کو کچھ ملتا ہے؟';

  @override
  String get inviteTreeQaGetsA =>
      'آپ کا کوڈ درج کرنے پر نہیں۔ سب کی طرح اس کا بھی اپنا کوڈ اور جگہیں ہیں، اور جو دوست اس کے کوڈ سے شامل ہوتے ہیں، وہ اس کے لیے ڈیٹا شامل کرتے ہیں۔ اہل ہونے کے بعد اس کی پہلی جوڑی میں بھی ایسے لوگ ہو سکتے ہیں جنہیں اس نے مدعو نہیں کیا، اور وہ بھی اس کے لیے ڈیٹا شامل کرتے ہیں۔';

  @override
  String get inviteTreeQaGetsSee =>
      'اگر وہ آپ کی جگہوں میں ہے تو آپ دیکھ سکتے ہیں کہ وہ فعال ہے یا ابھی فعال نہیں۔ آپ کبھی اس کا نام یا اس کے استعمال کی مقدار نہیں دیکھتے۔';

  @override
  String get inviteTreeKeptFloor =>
      'آپ کا بونس ابھی وہی مقدار ہے جو آپ کی پچھلی دعوتوں سے محفوظ ہے۔ جب آپ کے دوست مل کر اس سے زیادہ شامل کریں گے تو یہ بڑھ جائے گا۔';

  @override
  String inviteTreeIntroTotalUpTo(String most, String total) {
    return 'دوست روزانہ زیادہ سے زیادہ $most شامل کر سکتے ہیں۔ آپ کا مفت ڈیٹا اور دوستوں کا ڈیٹا مل کر روزانہ $total تک پہنچ سکتا ہے۔';
  }

  @override
  String get inviteTreeIntroPairsOrder =>
      'آپ کی پہلی جوڑی سب سے زیادہ شامل کرتی ہے۔ اس کے بعد کی ہر جوڑی کم شامل کرتی ہے۔';

  @override
  String get inviteTreeIntroInvitedYou => 'جس نے آپ کو مدعو کیا';

  @override
  String get inviteTreeIntroGuide => 'قدم بہ قدم رہنمائی';

  @override
  String get inviteTreeQaCostQ =>
      'کیا میری وجہ سے میرے دوست کا کوئی ڈیٹا کم ہوتا ہے؟';

  @override
  String get inviteTreeQaCostA =>
      'نہیں۔ جو ڈیٹا آپ کا دوست آپ کے لیے شامل کرتا ہے وہ اس کے اپنے ڈیٹا سے نہیں کٹتا۔ آپ کی وجہ سے اس کا روزانہ ڈیٹا نہیں بدلتا۔';

  @override
  String get inviteTreeQaStartQ =>
      'کسی دوست کا ڈیٹا کب سے شامل ہونا شروع ہوتا ہے؟';

  @override
  String get inviteTreeQaStartA =>
      'جیسے ہی آپ کا دوست کسی جگہ میں آ جائے اور فعال ہو۔ آپ کا بونس دن بھر اپ ڈیٹ ہوتا رہتا ہے، اس لیے اسی دن کچھ ہی دیر بعد بڑھ جاتا ہے۔ جب تک آپ کا دوست اہل نہیں ہوتا، وہ کچھ شامل نہیں کرتا۔';

  @override
  String get inviteTreeQaPhoneQ =>
      'اگر میرا دوست Fortiva دوبارہ انسٹال کرے یا فون بدل لے تو کیا ہوگا؟';

  @override
  String get inviteTreeQaPhoneA =>
      'اسی فون پر دوبارہ انسٹال کرنے کے بعد Fortiva عام طور پر فون کو پہچان لیتا ہے، اور کچھ نہیں بدلتا۔ نیا فون Fortiva کے لیے نیا ہوتا ہے۔ جگہ پرانے فون ہی کی رہتی ہے، اور جب پرانا فون استعمال نہ ہو تو وہ غیر فعال گنی جاتی ہے۔';

  @override
  String get premiumSourceInvite => 'آپ کی دعوتوں سے';

  @override
  String quotaBonusIncluded(String amount) {
    return '$amount دعوتی بونس شامل ہے';
  }

  @override
  String get updateTitle => 'اپ ڈیٹ دستیاب ہے';

  @override
  String get updateRequiredTitle => 'اپ ڈیٹ ضروری ہے';

  @override
  String updateBody(String version) {
    return 'Fortiva $version آ گیا ہے۔ تازہ ترین بہتری کے لیے اپ ڈیٹ کریں۔';
  }

  @override
  String get updateRequiredBody =>
      'یہ ورژن اب سپورٹ نہیں کیا جاتا۔ Fortiva استعمال جاری رکھنے کے لیے اپ ڈیٹ کریں۔';

  @override
  String get updateNow => 'اپ ڈیٹ کریں';

  @override
  String get updateLater => 'بعد میں';

  @override
  String get updateFromPlay => 'Google Play';

  @override
  String get updateFromTelegram => 'Telegram چینل';

  @override
  String get updateConnect => 'کنیکٹ کریں';

  @override
  String get updateConnectHint =>
      'اگر Google Play یا Telegram نہ کھلے تو پہلے کنیکٹ کریں پر ٹیپ کریں۔';

  @override
  String get updateConnected => 'آپ کنیکٹ ہیں۔ اب اپ ڈیٹ ڈاؤن لوڈ کریں۔';

  @override
  String get updateReconnect => 'کام نہیں کر رہا؟ دوبارہ کنیکٹ کریں';

  @override
  String get updateDisconnect => 'منقطع کریں';

  @override
  String get updateDisconnectHint =>
      'اپنے عام انٹرنیٹ سے اپ ڈیٹ ڈاؤن لوڈ کرنے کے لیے منقطع کریں پر ٹیپ کریں۔';

  @override
  String get updateNotCarrying =>
      'آپ کنیکٹ ہیں، لیکن کچھ نہیں کھل رہا۔ دوبارہ کنیکٹ کر کے دیکھیں، یا اپنا عام انٹرنیٹ استعمال کرنے کے لیے منقطع کریں پر ٹیپ کریں۔';

  @override
  String get diagVerdictNoInternet =>
      'آپ کے فون پر انٹرنیٹ کنکشن نہیں ہے۔ جب تک یہ واپس نہ آئے، Fortiva کنیکٹ نہیں ہو سکتا۔';

  @override
  String get diagVerdictCutOff =>
      'آپ کا نیٹ ورک ابھی بین الاقوامی انٹرنیٹ تک نہیں پہنچ پا رہا۔ چند منٹ بعد دوبارہ کوشش کریں۔';

  @override
  String get diagVerdictNeedsPermission =>
      'Fortiva کو VPN چلانے کی اجازت نہیں ہے، یا کوئی دوسری VPN ایپ ہمیشہ آن پر سیٹ ہے۔';

  @override
  String get diagVerdictServerUnreachable =>
      'آپ کے نیٹ ورک سے اس سرور تک رسائی نہیں ہو سکتی۔ یا تو یہ یہاں بلاک ہے یا بند ہے۔';

  @override
  String get diagVerdictBlockedTls =>
      'اس سرور سے کنکشن قائم ہوتے ہوتے کٹ جاتا ہے۔ فلٹرنگ ایسی ہی دکھائی دیتی ہے۔';

  @override
  String get diagVerdictThrottled =>
      'سرور نے ہر جانچ کا جواب دیا، پھر بھی VPN ٹنل سے کچھ نہیں گزرا۔ کنکشن کو سست کیا جا رہا ہے۔';

  @override
  String get diagCheckInternet => 'اپنا انٹرنیٹ چیک کریں';

  @override
  String diagTryServer(String server) {
    return '$server کے ساتھ نئی تلاش';
  }

  @override
  String get diagTryAnotherServer => 'دوسرا سرور آزمائیں';

  @override
  String get diagDetails => 'تفصیلات';

  @override
  String get diagDetailsHide => 'تفصیلات چھپائیں';

  @override
  String privateDnsWarning(String host) {
    return 'پرائیویٹ DNS آن ہے ($host)، اس لیے کچھ سائٹس نہیں کھل سکتیں۔ اپنے فون کی ترتیبات میں پرائیویٹ DNS بند کریں۔';
  }

  @override
  String get openNetworkSettings => 'نیٹ ورک کی ترتیبات کھولیں';

  @override
  String testPointStatus(String time, int open, int total) {
    return 'ٹیسٹ پوائنٹ · آخری جانچ $time · $total میں سے $open راستے کھلے';
  }

  @override
  String get messagesTooltip => 'پیغامات';

  @override
  String get inboxTitle => 'پیغامات';

  @override
  String get inboxEmpty => 'فی الحال کوئی پیغام نہیں ہے۔';

  @override
  String get messageClose => 'بند کریں';

  @override
  String get supportTitle => 'سپورٹ';

  @override
  String get supportTooltip => 'سپورٹ سے بات کریں';

  @override
  String get supportAskAction => 'سپورٹ سے پوچھیں';

  @override
  String get supportContactSubtitle => 'ایپ میں ہی ہم سے بات کریں';

  @override
  String get supportAutomaticNotice =>
      'جوابات خودکار طور پر لکھے جاتے ہیں اور غلط ہو سکتے ہیں۔';

  @override
  String get supportStaffNotice =>
      'خودکار جوابات فی الحال بند ہیں۔ آپ کے پیغامات ہماری ٹیم کو جاتے ہیں۔';

  @override
  String get supportInputHint => 'اپنا سوال لکھیں';

  @override
  String get supportInputHintTeam => 'ہماری ٹیم کو لکھیں';

  @override
  String get supportSend => 'بھیجیں';

  @override
  String supportQuotaLeft(int remaining, int limit) {
    return 'آج کے $limit میں سے $remaining سوال باقی ہیں';
  }

  @override
  String supportWaitIn(String time) {
    return 'آپ $time بعد دوبارہ پوچھ سکتے ہیں۔';
  }

  @override
  String supportDurationHours(int hours, int minutes) {
    return '$hours گھنٹے $minutes منٹ';
  }

  @override
  String supportDurationMinutes(int minutes) {
    return '$minutes منٹ';
  }

  @override
  String get supportNewConversation => 'نئی گفتگو';

  @override
  String get supportSending => 'بھیجا جا رہا ہے';

  @override
  String get supportNotSent =>
      'نہیں بھیجا جا سکا۔ دوبارہ کوشش کے لیے ٹیپ کریں۔';

  @override
  String get supportRateUp => 'مفید';

  @override
  String get supportRateDown => 'مفید نہیں';

  @override
  String get supportRatedDown => 'شکریہ۔ ہماری ٹیم اس جواب کو دیکھے گی۔';

  @override
  String get supportTeamLabel => 'Fortiva ٹیم';

  @override
  String get supportUnavailable => 'چیٹ ابھی دستیاب نہیں ہے۔';

  @override
  String get supportOpenTelegram => 'ٹیلیگرام پر ہمیں پیغام بھیجیں';

  @override
  String get supportGenericError => 'کچھ غلط ہو گیا۔ دوبارہ کوشش کریں۔';

  @override
  String supportCodeTooLong(int max) {
    return 'آپ کا پیغام بہت لمبا ہے۔ اسے $max حروف سے کم رکھیں۔';
  }

  @override
  String get supportCodeEmpty => 'آپ کا پیغام خالی ہے۔';

  @override
  String get supportCodeWaitReply =>
      'براہ کرم اپنے پچھلے سوال کے جواب کا انتظار کریں۔';

  @override
  String get supportCodeSlowDown =>
      'آپ بہت تیزی سے پیغامات بھیج رہے ہیں۔ تھوڑا انتظار کریں۔';

  @override
  String get supportCodeQuotaDay => 'آپ آج کے تمام سوالات استعمال کر چکے ہیں۔';

  @override
  String get supportCodePaused => 'خودکار جوابات فی الحال روکے گئے ہیں۔';

  @override
  String get supportCodeBusy =>
      'ہمارا اسسٹنٹ ابھی مصروف ہے۔ چند منٹ بعد دوبارہ کوشش کریں۔';

  @override
  String get supportCodeGreeting =>
      'سلام! Fortiva کے بارے میں میں آپ کی کیا مدد کر سکتا ہوں؟';

  @override
  String get supportCodeGibberish =>
      'معذرت، میں سمجھ نہیں سکا۔ براہ کرم اپنا سوال دوبارہ لکھیں۔';

  @override
  String get supportCodeRedacted =>
      'ہم نے آپ کے پیغام سے ذاتی معلومات اور لنکس ہٹا دیے ہیں۔';

  @override
  String get supportCodeRedactedEmpty =>
      'آپ کے پیغام میں صرف ذاتی معلومات یا لنکس تھے، اس لیے یہ نہیں بھیجا گیا۔ براہ کرم مسئلہ الفاظ میں بیان کریں۔';

  @override
  String get supportCodeOffTopic =>
      'میں صرف Fortiva کے استعمال سے متعلق سوالات میں مدد کر سکتا ہوں۔';

  @override
  String get supportCodeAbuse =>
      'آئیں احترام سے بات کریں۔ میں Fortiva میں آپ کی مدد کے لیے حاضر ہوں۔';

  @override
  String get supportCodeAiUnavailable =>
      'اسسٹنٹ اس بار جواب نہیں دے سکا۔ تھوڑی دیر بعد دوبارہ کوشش کریں۔';

  @override
  String get supportCodeToStaff =>
      'ہماری ٹیم کو بھیج دیا گیا۔ ان کا جواب یہیں آئے گا۔';

  @override
  String get supportCodeTicketOpened =>
      'ہم نے آپ کا سوال اپنی ٹیم کو دے دیا ہے۔ ان کا جواب یہیں آئے گا۔';

  @override
  String get supportCodeNotSent =>
      'یہ پیغام نہیں بھیجا جا سکا۔ اگر آپ کو اب بھی مدد چاہیے تو اسے دوبارہ لکھیں۔';

  @override
  String get supportAssistantSubtitle => 'اے آئی اسسٹنٹ';

  @override
  String get supportThinkingReading => 'آپ کا سوال پڑھ رہا ہوں';

  @override
  String get supportThinkingSearching => 'جواب تلاش کر رہا ہوں';

  @override
  String get supportThinkingWriting => 'جواب لکھ رہا ہوں';

  @override
  String get supportThinkingStill =>
      'ابھی اسی پر کام کر رہا ہوں، انتظار کا شکریہ';

  @override
  String get supportSuggestConnect => 'میں کنیکٹ نہیں ہو پا رہا';

  @override
  String get supportSuggestData => 'آج میرے پاس کتنا ڈیٹا ہے؟';

  @override
  String get supportSuggestSlow => 'میرا کنکشن سست ہے';

  @override
  String get supportWithTeam => 'یہ گفتگو اب ہماری ٹیم کے پاس ہے۔';

  @override
  String get supportTryAgainSoon => 'چند منٹ بعد دوبارہ کوشش کریں۔';

  @override
  String supportDurationWholeHours(int hours) {
    return '$hours گھنٹے';
  }

  @override
  String get supportUnreadReply => 'آپ کے لیے نیا جواب ہے';

  @override
  String get premiumTitle => 'پریمیم';

  @override
  String get premiumTileSubtitle => 'لامحدود ڈیٹا، کوئی روزانہ حد نہیں';

  @override
  String get premiumTileActive => 'پریمیم فعال ہے';

  @override
  String get premiumGetUnlimited => 'لامحدود لیں';

  @override
  String get premiumHeadline => 'لامحدود ڈیٹا لیں';

  @override
  String get premiumPitch =>
      'پریمیم روزانہ حد ختم کر دیتا ہے، اس لیے جب تک یہ چلے آپ جتنا چاہیں ڈیٹا استعمال کریں۔';

  @override
  String get premiumActiveTitle => 'پریمیم فعال ہے';

  @override
  String premiumActiveUntil(String date) {
    return '$date تک لامحدود ڈیٹا';
  }

  @override
  String get premiumActiveNoDate => 'لامحدود ڈیٹا';

  @override
  String get premiumRenews => 'Google Play کے ذریعے خود بخود تجدید ہوتا ہے';

  @override
  String get premiumSourceKey => 'کلید سے فعال کیا گیا';

  @override
  String get premiumSourceCrypto => 'کرپٹو سے ادائیگی';

  @override
  String get premiumSourceStars => 'ٹیلیگرام اسٹارز سے ادائیگی';

  @override
  String get premiumSourceGooglePlay => 'Google Play کے ذریعے ادائیگی';

  @override
  String get premiumSourceManual => 'Fortiva ٹیم کی طرف سے تحفہ';

  @override
  String get premiumYourKey => 'آپ کی کلید';

  @override
  String get premiumKeyHint =>
      'اس کلید کو سنبھال کر رکھیں۔ کسی دوسرے فون پر درج کریں تو پریمیم وہاں منتقل ہو جائے گا۔';

  @override
  String premiumKeyMoves(int count, int days) {
    return 'کلید $days دن میں زیادہ سے زیادہ $count بار دوسرے فون پر منتقل ہو سکتی ہے۔';
  }

  @override
  String get premiumKeyMovesNoNumber =>
      'کلید صرف محدود بار دوسرے فون پر منتقل ہو سکتی ہے۔';

  @override
  String get premiumCopy => 'کاپی';

  @override
  String get premiumCopied => 'کاپی ہو گیا';

  @override
  String get premiumChoosePlan => 'پلان چنیں';

  @override
  String premiumPlanDays(int days) {
    return '$days دن کا لامحدود ڈیٹا';
  }

  @override
  String get premiumPlanNoDays => 'لامحدود ڈیٹا';

  @override
  String get premiumBuy => 'خریدیں';

  @override
  String get premiumPlayUnavailable =>
      'Google Play ابھی دستیاب نہیں ہے۔ بعد میں دوبارہ کوشش کریں۔';

  @override
  String get premiumPlayPending =>
      'آپ کی ادائیگی Google Play میں زیر التوا ہے۔ مکمل ہوتے ہی پریمیم شروع ہو جائے گا۔';

  @override
  String get premiumPlayConfirming => 'آپ کی خریداری کی تصدیق ہو رہی ہے...';

  @override
  String get premiumPlayRetrying =>
      'ادائیگی ہو گئی، لیکن ہم ابھی اس کی تصدیق نہیں کر سکے۔ ہم کوشش جاری رکھیں گے، دوبارہ ادائیگی کی ضرورت نہیں۔';

  @override
  String get premiumPlayRefused =>
      'ہم اس خریداری کی تصدیق نہیں کر سکے۔ اگر آپ سے رقم کٹ گئی ہے تو سپورٹ سے رابطہ کریں۔';

  @override
  String get premiumPlayNotAvailable =>
      'پریمیم ابھی اس فون پر دستیاب نہیں۔ اگر آپ سے رقم کٹ گئی ہے تو سپورٹ سے رابطہ کریں۔';

  @override
  String get premiumNotAvailable => 'پریمیم ابھی اس فون پر دستیاب نہیں۔';

  @override
  String get premiumPlayFailed => 'خریداری مکمل نہیں ہوئی۔ دوبارہ کوشش کریں۔';

  @override
  String get premiumNowOn => 'پریمیم فعال ہو گیا۔ لامحدود ڈیٹا کا لطف اٹھائیں۔';

  @override
  String get premiumRestore => 'خریداریاں بحال کریں';

  @override
  String get premiumRestoreDone => 'آپ کی خریداری اس فون پر بحال ہو گئی۔';

  @override
  String get premiumRestoreNone =>
      'Google Play میں بحال کرنے کے لیے کوئی خریداری نہیں۔';

  @override
  String get premiumRestoreFailed =>
      'خریداری بحال نہیں ہو سکی۔ بعد میں دوبارہ کوشش کریں۔';

  @override
  String premiumRenewsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'ہر $count دن بعد ادائیگی ہوتی ہے۔ منسوخ کرنے تک خود بخود تجدید ہوتا ہے۔',
      one: 'ہر دن ادائیگی ہوتی ہے۔ منسوخ کرنے تک خود بخود تجدید ہوتا ہے۔',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'ہر $count ہفتے بعد ادائیگی ہوتی ہے۔ منسوخ کرنے تک خود بخود تجدید ہوتا ہے۔',
      one: 'ہر ہفتے ادائیگی ہوتی ہے۔ منسوخ کرنے تک خود بخود تجدید ہوتا ہے۔',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'ہر $count مہینے بعد ادائیگی ہوتی ہے۔ منسوخ کرنے تک خود بخود تجدید ہوتا ہے۔',
      one: 'ہر مہینے ادائیگی ہوتی ہے۔ منسوخ کرنے تک خود بخود تجدید ہوتا ہے۔',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'ہر $count سال بعد ادائیگی ہوتی ہے۔ منسوخ کرنے تک خود بخود تجدید ہوتا ہے۔',
      one: 'ہر سال ادائیگی ہوتی ہے۔ منسوخ کرنے تک خود بخود تجدید ہوتا ہے۔',
    );
    return '$_temp0';
  }

  @override
  String get premiumRenewsNoPeriod => 'منسوخ کرنے تک خود بخود تجدید ہوتا ہے۔';

  @override
  String get premiumPlayCancelNote =>
      'آپ جب چاہیں Google Play میں منسوخ کر سکتے ہیں۔ پریمیم ادا کیے گئے وقت کے آخر تک چلتا رہتا ہے۔';

  @override
  String get premiumManageSubscription =>
      'سبسکرپشن کا انتظام کریں یا منسوخ کریں';

  @override
  String get premiumCurrentPlan => 'موجودہ پلان';

  @override
  String get premiumPlaySubscribed =>
      'آپ کے پاس پہلے سے Google Play سبسکرپشن ہے۔ اسے Google Play میں سنبھالیں یا منسوخ کریں۔';

  @override
  String get premiumEnterCode => 'کوڈ درج کریں';

  @override
  String get premiumNeedsPlayVersion =>
      'Google Play کے ذریعے خریدنے کے لیے آپ کو Fortiva کا Google Play ورژن چاہیے۔';

  @override
  String get premiumOff => 'پریمیم ابھی فروخت کے لیے دستیاب نہیں۔';

  @override
  String get premiumLoadFailed =>
      'پریمیم لوڈ نہیں ہو سکا۔ اپنا کنکشن چیک کریں اور دوبارہ کوشش کریں۔';

  @override
  String get premiumRetry => 'دوبارہ کوشش کریں';

  @override
  String premiumPriceUsdt(String price) {
    return '$price USDT';
  }

  @override
  String premiumPriceStars(String stars) {
    return '$stars ٹیلیگرام اسٹارز';
  }

  @override
  String get premiumPayCrypto => 'کرپٹو سے ادائیگی کریں';

  @override
  String get premiumTelegramTitle => 'ٹیلیگرام میں ادائیگی';

  @override
  String get premiumTelegramBody =>
      'ہمارے بوٹ میں ٹیلیگرام اسٹارز سے ادائیگی کریں۔ آپ کو کلید ملے گی اور پریمیم اسی وقت اس فون پر شروع ہو جائے گا۔';

  @override
  String get premiumTelegramButton => 'ٹیلیگرام میں خریدیں';

  @override
  String get premiumTelegramFailed =>
      'ٹیلیگرام نہیں کھل سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get checkoutTitle => 'کرپٹو سے ادائیگی';

  @override
  String get checkoutChooseNetwork => 'وہ نیٹ ورک چنیں جس سے آپ بھیجیں گے';

  @override
  String get checkoutContinue => 'جاری رکھیں';

  @override
  String get checkoutSendExactly => 'بالکل یہی رقم بھیجیں';

  @override
  String get checkoutNetwork => 'نیٹ ورک';

  @override
  String get checkoutAddress => 'اس پتے پر';

  @override
  String get checkoutMemo => 'اس میمو کے ساتھ';

  @override
  String get checkoutMemoWarning =>
      'یہ میمو اپنی ٹرانسفر میں ضرور شامل کریں، ورنہ ہم ادائیگی کو آپ سے نہیں جوڑ سکیں گے۔';

  @override
  String get checkoutExactWarning =>
      'بالکل یہی رقم اور صرف اسی نیٹ ورک پر بھیجیں۔ مختلف رقم یا نیٹ ورک ہم تک نہیں پہنچ سکتا۔';

  @override
  String checkoutTimeLeft(String time) {
    return 'باقی وقت: $time';
  }

  @override
  String get checkoutWaiting =>
      'آپ کی ادائیگی کا انتظار ہے۔ یہ صفحہ خود اپ ڈیٹ ہوتا ہے۔';

  @override
  String get checkoutPaidTitle => 'ادائیگی موصول ہو گئی';

  @override
  String get checkoutPaidKeyOnly =>
      'آپ کی کلید تیار ہے۔ اسے اس فون پر درج کریں جسے پریمیم ملنا چاہیے۔';

  @override
  String get checkoutDone => 'ہو گیا';

  @override
  String get checkoutExpired =>
      'اس آرڈر کی مدت ختم ہو گئی۔ اگر آپ ادائیگی کر چکے ہیں تو سپورٹ سے رابطہ کریں۔';

  @override
  String get checkoutUnderpaid =>
      'ہمیں پوری رقم سے کم ملا۔ سپورٹ سے رابطہ کریں اور انہیں یہ آرڈر نمبر دیں:';

  @override
  String get checkoutCanceled => 'یہ آرڈر منسوخ ہو گیا۔';

  @override
  String get checkoutStartAgain => 'دوبارہ شروع کریں';

  @override
  String get checkoutUnavailable => 'کرپٹو ادائیگی ابھی دستیاب نہیں۔';

  @override
  String get checkoutTooManyOpen =>
      'آپ کے بہت سے آرڈر بغیر ادائیگی کے ہیں۔ ان میں سے کسی کی ادائیگی کریں یا ان کے ختم ہونے کا انتظار کریں۔';

  @override
  String get checkoutUnknownPlan =>
      'یہ پلان اب فروخت میں نہیں۔ واپس جائیں اور کوئی اور پلان چنیں۔';

  @override
  String get checkoutFailed =>
      'ادائیگی شروع نہیں ہو سکی۔ اپنا کنکشن چیک کریں اور دوبارہ کوشش کریں۔';

  @override
  String get redeemTitle => 'کوڈ درج کریں';

  @override
  String get redeemSubtitle => 'پریمیم کلید یا گفٹ کوڈ';

  @override
  String get redeemHint => 'کوڈ';

  @override
  String get redeemApply => 'لاگو کریں';

  @override
  String get redeemCancel => 'منسوخ';

  @override
  String get redeemInvalid =>
      'یہ کوڈ جیسا نہیں لگتا۔ اسے چیک کریں اور دوبارہ کوشش کریں۔';

  @override
  String get redeemUnknown =>
      'ہم اس کوڈ کو نہیں جانتے۔ اسے چیک کریں اور دوبارہ کوشش کریں۔';

  @override
  String get redeemExpired => 'اس کوڈ کی مدت ختم ہو چکی ہے۔';

  @override
  String get redeemRevoked => 'یہ کوڈ اب درست نہیں۔';

  @override
  String get redeemMovedTooOften =>
      'یہ کلید حال ہی میں بہت بار فون بدل چکی ہے۔ بعد میں دوبارہ کوشش کریں۔';

  @override
  String get redeemExhausted => 'یہ کوڈ پورا استعمال ہو چکا ہے۔';

  @override
  String get redeemAlreadyUsed => 'یہ فون پہلے ہی یہ کوڈ استعمال کر چکا ہے۔';

  @override
  String get redeemUnmetered =>
      'اس فون کے پاس پہلے سے لامحدود ڈیٹا ہے، اسے اس کوڈ کی ضرورت نہیں۔';

  @override
  String get redeemRateLimited =>
      'بہت زیادہ کوششیں۔ تھوڑا انتظار کریں اور دوبارہ کوشش کریں۔';

  @override
  String get redeemUnavailable =>
      'یہ ابھی دستیاب نہیں۔ بعد میں دوبارہ کوشش کریں۔';

  @override
  String get redeemNetwork =>
      'سرور تک رسائی نہیں ہو سکی۔ اپنا کنکشن چیک کریں اور دوبارہ کوشش کریں۔';

  @override
  String get redeemFailed =>
      'یہ کوڈ کام نہیں آیا۔ اسے چیک کریں اور دوبارہ کوشش کریں۔';

  @override
  String get redeemMoved => 'پریمیم اس فون پر منتقل ہو گیا۔';

  @override
  String redeemPromo(String amount) {
    return 'کوڈ قبول ہو گیا۔ $amount اضافی ڈیٹا شامل ہو گیا۔';
  }

  @override
  String get redeemPromoNoAmount => 'کوڈ قبول ہو گیا۔ اضافی ڈیٹا شامل ہو گیا۔';

  @override
  String get tvScanTitle => 'اپنے فون پر کھولیں';

  @override
  String get tvScanBody => 'اپنے فون کا کیمرہ اس کوڈ کی طرف کریں۔';

  @override
  String get refresh => 'ریفریش کریں';

  @override
  String get premiumNotNow => 'ابھی نہیں';

  @override
  String get premiumLimitSheetTitle => 'آج کا ڈیٹا ختم ہو گیا';

  @override
  String get premiumLimitWait => 'ری سیٹ ہونے کا انتظار کریں';

  @override
  String get premiumLimitInvite => 'مزید ڈیٹا کے لیے دوستوں کو مدعو کریں';

  @override
  String premiumLimitInviteNext(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days مختلف دنوں میں',
      one: '$days دن',
    );
    return 'آپ کا اگلا دوست $_temp0 Fortiva استعمال کر لے تو روزانہ $amount کا اضافہ کرے گا۔ یہ آج کے ڈیٹا میں شامل نہیں ہوتا۔';
  }

  @override
  String premiumLimitInviteNextNoDays(String amount) {
    return 'آپ کا اگلا دوست کچھ عرصہ Fortiva استعمال کر لے تو روزانہ $amount کا اضافہ کرے گا۔ یہ آج کے ڈیٹا میں شامل نہیں ہوتا۔';
  }

  @override
  String get premiumLimitInviteNoAmount =>
      'آپ کے مدعو کیے گئے دوست Fortiva استعمال کرنا شروع کرتے ہی آپ کا روزانہ ڈیٹا بڑھاتے ہیں۔ یہ آج کے ڈیٹا میں شامل نہیں ہوتا۔';

  @override
  String get premiumLimitInvitesFull =>
      'آپ کی دعوتیں پہلے ہی زیادہ سے زیادہ ڈیٹا بڑھا رہی ہیں۔';

  @override
  String get premiumLimitSeeInvites => 'اپنی دعوتیں دیکھیں';

  @override
  String get premiumLimitShareAgain => 'کسی اور دوست کو بھیجیں';

  @override
  String get premiumNoDailyLimit => 'پریمیم میں روزانہ کی کوئی حد نہیں۔';

  @override
  String get premiumCalmTitle => 'روزانہ کی حد سے چھٹکارا چاہیے؟';

  @override
  String get premiumCalmBody =>
      'پریمیم آپ کو لامحدود ڈیٹا دیتا ہے۔ آپ کا مفت پلان ویسا ہی رہے گا۔';

  @override
  String get premiumNextStepTitle => 'اگلا قدم پریمیم ہے';

  @override
  String get premiumNextStepBody =>
      'آپ کے پاس پہلے ہی سب سے زیادہ مفت ڈیٹا ہے۔ پریمیم میں روزانہ کی کوئی حد نہیں۔';

  @override
  String get premiumLockedTag => 'پریمیم';

  @override
  String premiumLockedTitle(String place) {
    return 'پریمیم کے ساتھ $place ان لاک کریں';
  }

  @override
  String get premiumLockedBody =>
      'یہ مقام پریمیم کے لیے ہے۔ آپ کے مفت سرور ویسے ہی رہیں گے۔';

  @override
  String get premiumHeadlineLimit => 'روزانہ کی کوئی حد نہیں';

  @override
  String premiumHeadlineLocked(String place) {
    return 'پریمیم کے ساتھ $place ان لاک کریں';
  }

  @override
  String get premiumFreeStays => 'مفت پلان پریمیم کے بغیر بھی چلتا رہتا ہے۔';

  @override
  String premiumEndsOn(String date) {
    return 'پریمیم $date کو ختم ہوگا';
  }

  @override
  String get premiumRenewBody =>
      'لامحدود ڈیٹا جاری رکھنے کے لیے تجدید کریں۔ تجدید کرنے سے وقت آپ کی موجودہ اختتامی تاریخ میں شامل ہو جاتا ہے۔';

  @override
  String premiumEndedOn(String date) {
    return 'پریمیم $date کو ختم ہو گیا۔ آپ کا مفت پلان واپس آ گیا ہے۔';
  }

  @override
  String get premiumRenew => 'تجدید کریں';

  @override
  String get noticeChannelName => 'Fortiva کے پیغامات';

  @override
  String get noticeChannelDescription => 'Fortiva ٹیم کی خبریں اور پیغامات';

  @override
  String get noticesSettingTitle => 'اطلاعات';

  @override
  String get noticesSettingOn =>
      'آن۔ ایپ بند ہونے پر بھی Fortiva ٹیم کے پیغامات آپ تک پہنچ سکتے ہیں۔';

  @override
  String get noticesSettingOff =>
      'آف۔ ایپ بند ہونے پر بھی Fortiva ٹیم کے پیغامات پانے کے لیے انہیں آن کریں۔';

  @override
  String get noticesOffCard =>
      'ایپ بند ہونے پر بھی Fortiva ٹیم کے پیغامات پانے کے لیے اطلاعات آن کریں۔';

  @override
  String get noticesTurnOn => 'آن کریں';

  @override
  String get backgroundCard =>
      'ایپ بند ہونے پر آپ کا فون Fortiva ٹیم کے پیغامات روک سکتا ہے۔ پیغامات پانے کے لیے Fortiva کو بیک گراؤنڈ میں چلنے دیں۔';

  @override
  String get backgroundHint =>
      'اگلی اسکرین پر Fortiva منتخب کریں (اگر فہرست میں نہ ہو تو تمام ایپس دکھائیں)۔ پھر بیٹری کے استعمال کو غیر محدود پر رکھیں، یا اسے خود بخود شروع ہونے اور بیک گراؤنڈ میں چلنے کی اجازت دیں۔';

  @override
  String get backgroundAllow => 'اجازت دیں';

  @override
  String get backgroundNotNow => 'ابھی نہیں';

  @override
  String get backgroundSettingTitle => 'ایپ بند ہونے پر پیغامات';

  @override
  String get backgroundSettingSubtitle =>
      'Fortiva کو بیک گراؤنڈ میں چلنے دیں تاکہ ایپ بند ہونے پر بھی پیغامات آپ تک پہنچیں۔';

  @override
  String get backgroundCardData =>
      'ایپ بند ہونے پر آپ کے فون کا ڈیٹا سیور Fortiva ٹیم کے پیغامات روک سکتا ہے۔';

  @override
  String get backgroundHintData => 'اگلی اسکرین پر غیر محدود ڈیٹا آن کریں۔';

  @override
  String get apnGuideTitle => 'اس سم پر زیادہ مستحکم کنکشن';

  @override
  String get apnGuideBody =>
      'آپ کا فون اس سم پر IPv6 استعمال نہیں کر رہا۔ اسے آن کرنے سے Fortiva کو جڑے رہنے میں مدد ملتی ہے۔';

  @override
  String get apnGuideShowMe => 'طریقہ دکھائیں';

  @override
  String get apnGuideNotNow => 'ابھی نہیں';

  @override
  String get apnGuideSheetTitle => 'اس سم کے لیے IPv6 آن کریں';

  @override
  String apnGuideStepOpen(String button) {
    return '\"$button\" پر ٹیپ کریں (یا ترتیبات > کنکشنز > موبائل نیٹ ورکس > رسائی پوائنٹ کے نام پر جائیں)۔';
  }

  @override
  String apnGuideStepAccessPoint(String apn) {
    return 'استعمال ہونے والے رسائی پوائنٹ ($apn) پر ٹیپ کریں۔';
  }

  @override
  String get apnGuideStepAccessPointAny =>
      'استعمال ہونے والے رسائی پوائنٹ پر ٹیپ کریں۔';

  @override
  String get apnGuideStepProtocol =>
      '\"APN پروٹوکول\" پر ٹیپ کریں اور \"IPv4/IPv6\" منتخب کریں۔';

  @override
  String get apnGuideStepSave =>
      'محفوظ کریں (Samsung پر: تین نقطوں والا مینو، پھر \"محفوظ کریں\")۔';

  @override
  String get apnGuideStepRestart => 'موبائل ڈیٹا بند کر کے دوبارہ آن کریں۔';

  @override
  String get apnGuideUndo =>
      'اگر موبائل ڈیٹا کام کرنا بند کر دے تو APN پروٹوکول کو واپس IPv4 پر کر دیں۔';

  @override
  String get apnGuideOpenSettings => 'APN کی ترتیبات کھولیں';

  @override
  String get homeStallSearching =>
      'کنکشن نے کام کرنا بند کر دیا۔ دوسرا راستہ تلاش کیا جا رہا ہے۔';

  @override
  String get homeStalled => 'متصل ہے، لیکن کوئی ڈیٹا نہیں گزر رہا';

  @override
  String get peerShareTitle => 'دوست کی کنیکٹ ہونے میں مدد کریں';

  @override
  String get peerShareSubtitle =>
      'اپنے دوست کے فون کو وہ سب دیں جس کی Fortiva کو ضرورت ہے';

  @override
  String get peerShareBody =>
      'اگر کسی دوست کا Fortiva کنیکٹ نہیں ہو پا رہا، تو ان کا فون آپ کے فون سے وہ لے سکتا ہے جو اسے چاہیے۔ یہ انٹرنیٹ کے بغیر کام کرتا ہے۔';

  @override
  String peerShareSteps(String action) {
    return 'ان کے فون پر Fortiva میں ترتیبات کھولیں اور \"$action\" پر ٹیپ کریں۔ پھر انہیں یہ کوڈ باری باری دکھائیں، یا یہ انہیں بھیج دیں۔';
  }

  @override
  String get peerShareLoading => 'تازہ ترین کاپی لی جا رہی ہے';

  @override
  String get peerShareNothing =>
      'اس فون کے پاس ابھی دینے کے لیے کوئی تازہ چیز نہیں ہے۔ کچھ دیر بعد دوبارہ کوشش کریں۔';

  @override
  String peerShareCodeOf(int current, int total) {
    return 'کوڈ: $total میں سے $current';
  }

  @override
  String get peerSharePrevious => 'پچھلا';

  @override
  String get peerShareNext => 'اگلا';

  @override
  String get peerShareCopy => 'کاپی';

  @override
  String get peerShareSend => 'بھیجیں';

  @override
  String get peerShareCopied =>
      'کاپی ہو گیا۔ اسے اپنے دوست کو پیغام میں پیسٹ کریں۔';

  @override
  String get peerReceiveTitle => 'دوست سے مدد لیں';

  @override
  String get peerReceiveSubtitle => 'جب کسی اور طرح کنیکٹ نہ ہو';

  @override
  String peerReceiveBody(String action) {
    return 'کسی ایسے دوست سے کہیں جس کا Fortiva کنیکٹ ہوتا ہو کہ وہ Fortiva میں ترتیبات کھولیں اور \"$action\" پر ٹیپ کریں۔ پھر ان میں سے کسی بھی طریقے سے ان کے فون سے لے لیں۔';
  }

  @override
  String get peerReceivePhotograph => 'دوست کے کوڈز کی تصویر لیں';

  @override
  String get peerReceivePhotographNext => 'اگلے کوڈ کی تصویر لیں';

  @override
  String peerReceiveProgress(int have, int total) {
    return 'پڑھے گئے کوڈ: $total میں سے $have';
  }

  @override
  String get peerReceiveFile => 'دوست کی بھیجی ہوئی فائل کھولیں';

  @override
  String get peerReceivePaste => 'جو دوست نے بھیجا وہ پیسٹ کریں';

  @override
  String get peerReceiveNoCode =>
      'اس تصویر میں کوئی کوڈ نہیں ملا۔ فون قریب لائیں اور دھیان رکھیں کہ پورا کوڈ نظر آئے۔';

  @override
  String get peerReceiveRefused =>
      'اسے Fortiva استعمال نہیں کر سکتا۔ اپنے دوست سے کہیں کہ دوبارہ بھیجیں۔';

  @override
  String get peerReceiveNotNewer =>
      'یہ آپ کے پاس پہلے سے ہے، یا اس سے نیا۔ دوبارہ کنیکٹ کرنے کی کوشش کریں، یا کسی اور دوست سے مدد لیں۔';

  @override
  String get peerReceiveTaken => 'ہو گیا۔ کنیکٹ کرنے کے لیے بٹن پر ٹیپ کریں۔';

  @override
  String get peerReceiveUnavailable =>
      'یہ فون ایسا نہیں کر سکتا۔ کوئی اور طریقہ آزمائیں۔';

  @override
  String get peerReceiveNothingToPaste =>
      'ابھی کچھ کاپی نہیں ہوا۔ دوست کا بھیجا ہوا کاپی کریں، پھر یہاں دوبارہ ٹیپ کریں۔';

  @override
  String get peerOfferBody =>
      'اب بھی کنیکٹ نہیں ہو رہا؟ جس دوست کا Fortiva چل رہا ہو، وہ اپنے فون سے مدد کر سکتے ہیں۔';

  @override
  String get peerReceiveAgain =>
      'یہ کوڈ آپ کے پاس پہلے سے ہے۔ اپنے دوست سے کہیں کہ اگلا کوڈ دکھائیں۔';

  @override
  String get peerReceivePasteNotOurs =>
      'آپ نے جو کاپی کیا وہ Fortiva کا نہیں ہے۔ اپنے دوست کا پورا پیغام کاپی کریں، پھر دوبارہ کوشش کریں۔';

  @override
  String peerReceiveNoPhoto(String action) {
    return 'کیمرے سے تصویر واپس نہیں ملی۔ کیمرہ ایپ سے تصویر لیں، پھر \"$action\" پر ٹیپ کریں۔';
  }

  @override
  String get peerReceiveFileHint =>
      'میسجنگ ایپ سے آئی فائل کو شاید پہلے ڈاؤن لوڈز میں محفوظ کرنا پڑے۔';

  @override
  String get homeTryingBackup =>
      'کوئی اور راستہ متصل نہیں ہوا۔ اب ایک بیک اپ نیٹ ورک آزما رہے ہیں۔';

  @override
  String get homeConnectedBackup => 'بیک اپ نیٹ ورک کے ذریعے متصل';

  @override
  String get backupNetwork => 'بیک اپ نیٹ ورک';

  @override
  String get backupNetworkTitle => 'بیک اپ نیٹ ورک';

  @override
  String get backupNetworkCaption =>
      'جب کچھ اور متصل نہ ہو تو یہ استعمال ہوتا ہے۔ یہ ہمارے سرورز سے سست ہو سکتا ہے۔';

  @override
  String get backupNetworkPlace => 'مقام خود بخود چنا جاتا ہے';

  @override
  String get speedTestStart => 'ٹیسٹ شروع کریں';

  @override
  String get speedTestAgain => 'دوبارہ ٹیسٹ کریں';

  @override
  String get speedTestRunning => 'ٹیسٹ جاری ہے';

  @override
  String get speedTestIdle => 'دیکھیں کہ آپ کا کنکشن ابھی کتنا تیز ہے۔';

  @override
  String get speedTestPhasePing => 'جواب کا وقت دیکھا جا رہا ہے';

  @override
  String get speedTestPhaseDownload => 'ڈاؤن لوڈ کی رفتار ناپی جا رہی ہے';

  @override
  String get speedTestPhaseUpload => 'اپ لوڈ کی رفتار ناپی جا رہی ہے';

  @override
  String get speedTestDone => 'ٹیسٹ مکمل ہو گیا';

  @override
  String get speedTestFailed =>
      'ٹیسٹ مکمل نہیں ہو سکا۔ اپنا انٹرنیٹ چیک کریں اور دوبارہ کوشش کریں۔';

  @override
  String get speedTestUnit => 'Mbps';

  @override
  String get ipAddressLabel => 'IP ایڈریس';

  @override
  String get ipCopied => 'ایڈریس کاپی ہو گیا';

  @override
  String get ipLocation => 'مقام';

  @override
  String get ipProvider => 'انٹرنیٹ فراہم کنندہ';

  @override
  String get ipOrganization => 'ادارہ';

  @override
  String get ipTimeZone => 'ٹائم زون';

  @override
  String get ipCoordinates => 'کوآرڈینیٹس';

  @override
  String get ipCheckFailed => 'آپ کا ایڈریس چیک نہیں ہو سکا';

  @override
  String get historyAverage => 'اوسط کنکشن';

  @override
  String get historyRecentDays => 'حالیہ دن';

  @override
  String yesterdayAt(String time) {
    return 'کل $time بجے';
  }

  @override
  String dateAt(String date, String time) {
    return '$date، $time بجے';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds سیکنڈ';
  }

  @override
  String get stageOwn => 'Fortiva سرور';

  @override
  String get stageCommunity => 'کمیونٹی سرور';

  @override
  String stageProgress(int n, int total) {
    return '$total میں سے مرحلہ $n';
  }

  @override
  String get stageTryingOwn => 'Fortiva سرور آزما رہے ہیں';

  @override
  String get stageTryingCommunity => 'کمیونٹی سرور آزما رہے ہیں';

  @override
  String get stageOwnFailedTryingCommunity =>
      'Fortiva سرور یہاں متصل نہیں ہوئے۔ اب کمیونٹی سرور آزما رہے ہیں۔';

  @override
  String stageLastWorked(String server) {
    return 'آخری بار چلنے والا سرور: $server';
  }

  @override
  String stageTriedBlocked(int count) {
    return 'آزمائے گئے راستے: $count، یہاں بلاک ہیں';
  }

  @override
  String stageTriedFailed(int count) {
    return 'آزمائے گئے راستے: $count، کوئی متصل نہیں ہوا';
  }

  @override
  String get stageNotConnected => 'متصل نہیں ہوا';

  @override
  String get stageConnected => 'یہاں سے متصل';

  @override
  String get stageSkipped => 'اس بار چھوڑ دیا گیا';

  @override
  String stageMoreToCheck(int count) {
    return 'جانچ کے لیے باقی راستے: $count';
  }

  @override
  String stageNextTry(String stage, String time) {
    return 'اگلی کوشش $time میں، $stage سے شروع ہوگی';
  }

  @override
  String get searchSlowHint =>
      'اس میں ایک دو منٹ لگ سکتے ہیں۔ تلاش روکنے کے لیے بٹن پر ٹیپ کریں۔';

  @override
  String get searchStopped => 'تلاش روک دی گئی';

  @override
  String get homeConnectedCommunity => 'کمیونٹی سرور کے ذریعے متصل';

  @override
  String get stageGettingServers => 'آپ کے سرور حاصل کیے جا رہے ہیں';

  @override
  String stageNextTryStarting(String stage) {
    return 'اگلی کوشش اب $stage سے شروع ہو رہی ہے';
  }
}
