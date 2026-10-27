// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class SAr extends S {
  SAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'FortivaVPN';

  @override
  String get statusDisconnected => 'غير متصل';

  @override
  String get statusConnecting => 'جارٍ الاتصال';

  @override
  String get statusConnected => 'متصل';

  @override
  String get statusDisconnecting => 'جارٍ قطع الاتصال';

  @override
  String get statusError => 'خطأ';

  @override
  String get statusVerifying => 'جارٍ التحقق...';

  @override
  String get disconnect => 'قطع الاتصال';

  @override
  String get connectBtn => 'اتصال';

  @override
  String get disconnectBtn => 'قطع الاتصال';

  @override
  String get pleaseWait => 'يرجى الانتظار';

  @override
  String get locationLabel => 'الموقع:';

  @override
  String get selectServer => 'اختيار خادم';

  @override
  String get serverLocation => 'موقع الخادم';

  @override
  String get searchServers => 'البحث عن خادم';

  @override
  String get locationsTitle => 'المواقع';

  @override
  String get sortLatency => 'الترتيب: زمن الاستجابة';

  @override
  String get sortAZ => 'الترتيب: أ-ي';

  @override
  String get sortedByLatency => 'مرتب حسب زمن الاستجابة';

  @override
  String get sortedAZ => 'مرتب أبجدياً';

  @override
  String get pingAll => 'اختبار الكل';

  @override
  String get pinging => 'جارٍ الاختبار...';

  @override
  String get ping => 'بنج';

  @override
  String get stop => 'إيقاف';

  @override
  String get fastestServer => 'أسرع خادم';

  @override
  String get timeout => 'انتهى الوقت';

  @override
  String get tabCommunity => 'المجتمع';

  @override
  String get tabFree => 'مجاني';

  @override
  String get tabPremium => 'مميز';

  @override
  String get noCommunityServers => 'لا توجد خوادم مجتمعية';

  @override
  String get communityLoadFailed => 'تعذّر تحميل هذه القائمة';

  @override
  String get communityRetry => 'أعد المحاولة';

  @override
  String get officialTabExplainer =>
      'تديرها Fortiva وتبقيها متصلة. مشتركة بين جميع مستخدمي التطبيق. ابدأ من هنا.';

  @override
  String get communityTabExplainer =>
      'خيارات اتصال إضافية. تختلف السرعة ومدى التوفر.';

  @override
  String get noFreeServers => 'لا توجد خوادم مجانية';

  @override
  String get noPremiumServers => 'لا توجد خوادم مميزة';

  @override
  String noResultsFor(String query) {
    return 'لا توجد نتائج لـ \"$query\"';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get freeBadge => 'مجاني';

  @override
  String get settings => 'الإعدادات';

  @override
  String get connection => 'الاتصال';

  @override
  String get dnsConfiguration => 'إعدادات DNS';

  @override
  String get customDns => 'خوادم DNS مخصصة';

  @override
  String get about => 'حول';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get contactUs => 'اتصل بنا';

  @override
  String get rateOnGooglePlay => 'قيّم Fortiva على Google Play';

  @override
  String get website => 'الموقع الإلكتروني';

  @override
  String get copyright => '© 2026 NimusAI';

  @override
  String get version => 'الإصدار';

  @override
  String get language => 'اللغة';

  @override
  String get languageSubtitle => 'لغة عرض التطبيق';

  @override
  String get whatIsDns => 'ما هو DNS؟';

  @override
  String get dnsExplanation =>
      'DNS (نظام أسماء النطاقات) هو دليل الهاتف للإنترنت. يقوم بترجمة أسماء المواقع إلى عناوين IP.\n\nتخصيص DNS يمكن أن:\n• يحسن سرعة الاتصال ⚡\n• يعزز الخصوصية 🔒\n• يتجاوز حجب الرقابة 🌍';

  @override
  String get configuration => 'الإعدادات';

  @override
  String get primaryDns => 'DNS الأساسي';

  @override
  String get primaryDnsHint => 'الافتراضي: 1.1.1.1';

  @override
  String get secondaryDns => 'DNS الثانوي (اختياري)';

  @override
  String get secondaryDnsHint => 'الافتراضي: 8.8.8.8';

  @override
  String get saveConfiguration => 'حفظ الإعدادات';

  @override
  String get dnsSaved => 'تم حفظ إعدادات DNS';

  @override
  String get invalidPrimaryDns => 'عنوان IP لـ DNS الأساسي غير صالح';

  @override
  String get invalidSecondaryDns => 'عنوان IP لـ DNS الثانوي غير صالح';

  @override
  String get statistics => 'الإحصائيات';

  @override
  String get overview => 'نظرة عامة';

  @override
  String get connectionsLabel => 'الاتصالات';

  @override
  String get totalTime => 'الوقت الإجمالي';

  @override
  String get dataUsage => 'استخدام البيانات';

  @override
  String get uploaded => 'تم الرفع';

  @override
  String get downloaded => 'تم التنزيل';

  @override
  String get total => 'الإجمالي';

  @override
  String lastUpdated(String date) {
    return 'آخر تحديث: $date';
  }

  @override
  String today(String time) {
    return 'اليوم الساعة $time';
  }

  @override
  String get yesterday => 'أمس';

  @override
  String daysAgo(int count) {
    return 'منذ $count أيام';
  }

  @override
  String get noDataYet => 'لا توجد بيانات بعد';

  @override
  String get connectToStart => 'اتصل بـ VPN لبدء التتبع';

  @override
  String get errorConnectionFailed => 'فشل الاتصال';

  @override
  String get errorServerNotWorking => 'الخادم لا يعمل — جرّب خادماً آخر';

  @override
  String get errorServerNotForwarding => 'الخادم لا يقوم بتوجيه حركة المرور';

  @override
  String get errorUnexpected => 'خطأ غير متوقع';

  @override
  String get errorDisconnectionFailed => 'فشل قطع الاتصال';

  @override
  String get errorFailedToRegister => 'فشل تسجيل الجهاز';

  @override
  String get ipInformation => 'معلومات IP';

  @override
  String get connectionAnalytics => 'تحليلات الاتصال';

  @override
  String get recentSessions => 'الجلسات الأخيرة';

  @override
  String get speedTest => 'اختبار السرعة';

  @override
  String get startTest => 'بدء الاختبار';

  @override
  String get download => 'تنزيل';

  @override
  String get upload => 'رفع';

  @override
  String get testingViaVpn => 'اختبار عبر VPN';

  @override
  String get testingDirect => 'اختبار الاتصال المباشر';

  @override
  String get splitTunneling => 'النفق المقسم';

  @override
  String get splitTunnelingDescription =>
      'اختر فئات التطبيقات التي تتجاوز نفق VPN. التطبيقات المستثناة ستستخدم اتصال الإنترنت العادي.';

  @override
  String get enableSplitTunneling => 'تفعيل النفق المقسم';

  @override
  String get splitTunnelActive => 'التطبيقات المحددة تتجاوز VPN';

  @override
  String get splitTunnelInactive => 'كل حركة المرور تمر عبر VPN';

  @override
  String get bypassVpnFor => 'تجاوز VPN لـ';

  @override
  String get tools => 'أدوات';

  @override
  String get settingsGeneral => 'عام';

  @override
  String get shareDiagnosticsTitle => 'مشاركة تشخيصات الاتصال';

  @override
  String get shareDiagnosticsBody =>
      'تُرسَل تقارير الاتصال، وشركة الاتصالات والبلد، وطراز الهاتف وإصدار أندرويد، وأسماء المواقع التي تزورها عبر VPN مع عددها اليومي، وما إذا كنت قد رأيت رسائلنا وعروض بريميوم وبطاقة الدعوة أو نقرت عليها. لا نرى أبدًا الصفحات التي تفتحها ولا ما ترسله.';

  @override
  String get security => 'الأمان';

  @override
  String get privacyDashboard => 'لوحة الخصوصية';

  @override
  String get privacyDashboardSubtitle => 'معلومات IP وحماية التسرب';

  @override
  String get connectionAnalyticsSubtitle => 'سجل الجلسات والرسوم البيانية';

  @override
  String get speedTestSubtitle => 'اختبر سرعة اتصالك';

  @override
  String get splitTunnelingSubtitle => 'توجيه VPN للتطبيقات';

  @override
  String get splashTagline => 'وصول خاص، أينما كنت';

  @override
  String get openSourceLicence => 'رخصة المصدر المفتوح';

  @override
  String get sourceOfferTitle => 'رخصة المصدر المفتوح';

  @override
  String get sourceOfferBody =>
      'Fortiva VPN برنامج حر مرخّص بموجب GNU General Public License v3. وهو مبني على Xray-core ومشاريع مفتوحة المصدر أخرى.\n\nيحق لك الحصول على الشيفرة المصدرية الكاملة للإصدار الذي ثبّته. لطلبها، أرسل بريدًا إلكترونيًا إلى admin@fortivavpn.com مع ذكر إصدار التطبيق لديك. يسري هذا العرض لمدة ثلاث سنوات من تاريخ حصولك على هذا الإصدار.';

  @override
  String get close => 'إغلاق';

  @override
  String get account => 'الحساب';

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String get deleteAccountSubtitle => 'إزالة هذا الجهاز وبياناتك نهائيًا';

  @override
  String get deleteAccountConfirmTitle => 'هل تريد حذف حسابك؟';

  @override
  String get deleteAccountConfirmBody =>
      'سيؤدي هذا إلى إزالة تسجيل جهازك، وأي حساب Google مرتبط، والخوادم الخاصة التي أُنشئت لك، ورسائلك في دردشة الدعم. كما سيُمحى سجل الاتصال على هذا الهاتف.\n\nلا يمكن التراجع عن هذا الإجراء. يمكنك البدء من جديد في أي وقت بإعادة فتح التطبيق.';

  @override
  String deleteAccountConfirmRetention(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يوم',
      many: '$days يومًا',
      few: '$days أيام',
      two: 'يومين',
      one: 'يوم واحد',
    );
    return 'يُحذف سجل حسابك فورًا. أما النسخ الموجودة في النسخ الاحتياطية وسجلات الخادم المجهولة فتُمحى خلال $_temp0.';
  }

  @override
  String get deleteAccountConfirmRetentionNoDays =>
      'يُحذف سجل حسابك فورًا. أما النسخ الموجودة في النسخ الاحتياطية وسجلات الخادم المجهولة فتُمحى لاحقًا، ضمن المدة المذكورة في سياسة الخصوصية.';

  @override
  String get deleteAccountCancel => 'الاحتفاظ بحسابي';

  @override
  String get deleteAccountConfirm => 'حذف';

  @override
  String get deleteAccountInProgress => 'جارٍ حذف حسابك';

  @override
  String get deleteAccountDone => 'تم حذف حسابك.';

  @override
  String get deleteAccountFailed =>
      'تعذّر حذف حسابك. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get homeTapToConnect => 'اضغط للاتصال';

  @override
  String get homeChecking => 'جارٍ التحقق من الاتصال';

  @override
  String get homePreparing => 'جارٍ إعداد خادمك';

  @override
  String get homeDisconnecting => 'جارٍ قطع الاتصال';

  @override
  String get homeFindingPath => 'جارٍ البحث عن مسار';

  @override
  String get diagCheckingInternet => 'جارٍ التحقق من الإنترنت لديك';

  @override
  String get diagInternationalCut => 'الإنترنت الدولي مقطوع على هذه الشبكة';

  @override
  String diagPathRow(String city, int n) {
    return '$city، المسار $n';
  }

  @override
  String get diagOpen => 'مفتوح';

  @override
  String get diagBlocked => 'محجوب';

  @override
  String get diagSkipped => 'تم تخطيه اليوم';

  @override
  String diagConnectingThrough(String city) {
    return 'جارٍ الاتصال عبر $city';
  }

  @override
  String get diagVerifying => 'جارٍ التحقق من حركة المرور';

  @override
  String get diagNoInternet => 'هاتفك غير متصل بالإنترنت الآن.';

  @override
  String get diagCutOff =>
      'شبكتك لا تصل إلى الإنترنت الدولي الآن. اضغط لإعادة المحاولة.';

  @override
  String get diagNothingOpen =>
      'كل المسارات محجوبة الآن. اضغط لإعادة المحاولة.';

  @override
  String get homeTryingAgain =>
      'كل المسارات محجوبة الآن. سنحاول مرة أخرى بعد قليل.';

  @override
  String get homeCutOffTryingAgain =>
      'شبكتك لا تصل إلى الإنترنت الدولي الآن. سنحاول مرة أخرى بعد قليل.';

  @override
  String get homeOfflineTryingAgain =>
      'هاتفك غير متصل بالإنترنت الآن. سنحاول مرة أخرى بعد قليل.';

  @override
  String get diagPathFailed =>
      'كان المسار مفتوحًا لكن لم يتم إنشاء النفق. اضغط لإعادة المحاولة.';

  @override
  String get openVpnSettings => 'فتح إعدادات VPN';

  @override
  String get yourServer => 'خادمك';

  @override
  String get yourServerCaption => 'لك وحدك. لا أحد غيرك يتصل عبره.';

  @override
  String get ourServer => 'خادمنا';

  @override
  String get ourServerCaption =>
      'تديره Fortiva ومشترك مع الجميع. يُستخدم إلى أن يصبح خادمك جاهزًا.';

  @override
  String get communityServer => 'خادم المجتمع';

  @override
  String get communityServerCaption =>
      'خيار اتصال إضافي. قد يتوقف عن العمل في أي وقت.';

  @override
  String communityServerNumber(String n) {
    return 'خادم المجتمع $n';
  }

  @override
  String get myServersTitle => 'خوادمك';

  @override
  String get myServersExplainer =>
      'يحصل كل جهاز في Fortiva على خادم خاص به في كل موقع، ببيانات اعتماد تخص هذا التثبيت وحده. لا حاجة إلى حساب.';

  @override
  String get myServersInUse => 'قيد الاستخدام';

  @override
  String get myServersEmpty => 'لم يتم تخصيص خوادم بعد';

  @override
  String get myServersRetry => 'أعد المحاولة';

  @override
  String get myServersBlockedTitle => 'لقد استهلكت بيانات اليوم';

  @override
  String get myServersBlockedWait =>
      'تتجدد حصتك تلقائيًا. تحقق مرة أخرى قريبًا.';

  @override
  String myServersMoved(String place) {
    return 'يتم الآن استخدام $place';
  }

  @override
  String get copyLink => 'نسخ الرابط';

  @override
  String get linkCopied => 'تم نسخ الرابط';

  @override
  String quotaUsedToday(String used, String limit) {
    return '$used من $limit مستخدمة اليوم';
  }

  @override
  String get quotaUsedUp => 'استُهلكت بيانات اليوم';

  @override
  String get quotaUnlimited => 'بيانات غير محدودة';

  @override
  String get quotaDaily => 'بيانات اليوم';

  @override
  String get quotaLimitReached => 'تم بلوغ الحد اليومي';

  @override
  String quotaLeftOf(String left, String limit) {
    return 'تبقّى $left من $limit';
  }

  @override
  String get quotaResetsShortly => 'يتجدد قريبًا';

  @override
  String quotaResetsInHours(int hours) {
    return 'يتجدد خلال $hours س';
  }

  @override
  String quotaResetsInMinutes(int minutes) {
    return 'يتجدد خلال $minutes د';
  }

  @override
  String get myServersSubtitle => 'الخوادم المخصصة لهذا الجهاز';

  @override
  String get sharedServersTitle => 'الخوادم المشتركة';

  @override
  String get sharedServersSubtitle => 'مواقع عامة تُستخدم كخيار احتياطي';

  @override
  String get tabOfficial => 'خوادمنا';

  @override
  String get noOfficialServers => 'لا توجد خوادم Fortiva حاليًا';

  @override
  String get inviteTitle => 'دعوة الأصدقاء';

  @override
  String get inviteSubtitle => 'احصل على بيانات يومية إضافية';

  @override
  String get inviteYourCode => 'رمز الدعوة الخاص بك';

  @override
  String get inviteShareAction => 'مشاركة الدعوة';

  @override
  String get inviteCopyAction => 'نسخ الرمز';

  @override
  String get inviteCodeCopied => 'تم نسخ الرمز';

  @override
  String inviteShareMessage(String code, String url) {
    return 'تطبيق VPN مجاني يعمل جيدًا معي: Fortiva. بدون تسجيل.\nثبّته من هذا الرابط:\n$url\nرمز دعوتي: $code';
  }

  @override
  String get inviteHowItWorks => 'كيف يعمل';

  @override
  String inviteHowItWorksBody(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يوم مختلف',
      many: '$days يومًا مختلفًا',
      few: '$days أيام مختلفة',
      two: 'يومين مختلفين',
      one: 'يوم واحد',
    );
    return 'شارك رمزك. عندما يثبّت أحدهم التطبيق ويُدخل الرمز ويستخدم الشبكة في $_temp0، تُضاف $amount إلى بياناتك اليومية وتبقى في حسابك.';
  }

  @override
  String inviteHowItWorksBodyNoAmount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يوم مختلف',
      many: '$days يومًا مختلفًا',
      few: '$days أيام مختلفة',
      two: 'يومين مختلفين',
      one: 'يوم واحد',
    );
    return 'شارك رمزك. عندما يثبّت أحدهم التطبيق ويُدخل الرمز ويستخدم الشبكة في $_temp0، تزيد بياناتك اليومية وتبقى الزيادة في حسابك.';
  }

  @override
  String inviteHowItWorksBodyNoDays(String amount) {
    return 'شارك رمزك. عندما يثبّت أحدهم التطبيق ويُدخل الرمز ويستخدم الشبكة لفترة، تُضاف $amount إلى بياناتك اليومية وتبقى في حسابك.';
  }

  @override
  String get inviteHowItWorksBodyNoAmountNoDays =>
      'شارك رمزك. عندما يثبّت أحدهم التطبيق ويُدخل الرمز ويستخدم الشبكة لفترة، تزيد بياناتك اليومية وتبقى الزيادة في حسابك.';

  @override
  String inviteHowItWorksCap(String max) {
    return 'يمكنك الحصول على ما يصل إلى $max يوميًا من الدعوات.';
  }

  @override
  String get inviteStatInvited => 'المدعوون';

  @override
  String get inviteStatEarning => 'مؤهل';

  @override
  String get inviteStatBonus => 'بيانات إضافية';

  @override
  String inviteBonusPerDay(String amount) {
    return '+$amount كل يوم';
  }

  @override
  String get inviteNoBonusYet => 'لا توجد مكافأة بعد';

  @override
  String invitePendingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دعوات لم تتأهل بعد',
      one: 'دعوة واحدة لم تتأهل بعد',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String inviteJoinedWith(String code) {
    return 'انضممت باستخدام الرمز $code';
  }

  @override
  String get inviteLoadFailed => 'تعذّر تحميل رمز الدعوة';

  @override
  String get inviteRetry => 'أعد المحاولة';

  @override
  String get inviteHaveCodeTitle => 'هل لديك رمز دعوة؟';

  @override
  String inviteHaveCodeSubtitle(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'أدخله خلال أول $hours ساعة',
      many: 'أدخله خلال أول $hours ساعة',
      few: 'أدخله خلال أول $hours ساعات',
      two: 'أدخله خلال أول ساعتين',
      one: 'أدخله خلال الساعة الأولى',
    );
    return '$_temp0';
  }

  @override
  String get inviteHaveCodeSubtitleNoHours => 'أدخله بعد التثبيت بوقت قصير';

  @override
  String get inviteEnterCodeHint => 'رمز الدعوة';

  @override
  String get inviteApplyAction => 'تطبيق';

  @override
  String get inviteNotNowAction => 'ليس الآن';

  @override
  String inviteClaimAccepted(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يوم مختلف',
      many: '$days يومًا مختلفًا',
      few: '$days أيام مختلفة',
      two: 'يومين مختلفين',
      one: 'يوم واحد',
    );
    return 'تم قبول الدعوة. سيحصل صديقك على بيانات إضافية بعد أن تستخدم الشبكة في $_temp0.';
  }

  @override
  String get inviteClaimAcceptedNoDays =>
      'تم قبول الدعوة. سيحصل صديقك على بيانات إضافية بعد أن تستخدم الشبكة لفترة.';

  @override
  String get inviteClaimAlready => 'استخدم هذا الجهاز رمز دعوة من قبل';

  @override
  String get inviteClaimRejected => 'لم يعمل هذا الرمز. تحقق منه وأعد المحاولة';

  @override
  String get inviteClaimNetwork => 'تعذّر الوصول إلى الخادم. أعد المحاولة';

  @override
  String get inviteCardTitle => 'هل يعمل فورتيفا جيدًا معك؟ أرسله إلى أصدقائك';

  @override
  String get inviteCardBody =>
      'أرسل رابط التثبيت إلى صديقك ليتصل هو أيضًا مجانًا.';

  @override
  String inviteCardReward(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'عندما يبدأ صديقك باستخدام فورتيفا، تحصل على بريميوم لمدة $days يوم.',
      many:
          'عندما يبدأ صديقك باستخدام فورتيفا، تحصل على بريميوم لمدة $days يومًا.',
      few:
          'عندما يبدأ صديقك باستخدام فورتيفا، تحصل على بريميوم لمدة $days أيام.',
      two: 'عندما يبدأ صديقك باستخدام فورتيفا، تحصل على بريميوم لمدة يومين.',
      one: 'عندما يبدأ صديقك باستخدام فورتيفا، تحصل على بريميوم لمدة يوم واحد.',
    );
    return '$_temp0';
  }

  @override
  String get inviteCardRewardNoAmount =>
      'عندما يبدأ صديقك باستخدام فورتيفا، تحصل على بريميوم كهدية.';

  @override
  String get inviteSendTelegram => 'تيليجرام';

  @override
  String get inviteSendWhatsApp => 'واتساب';

  @override
  String get inviteCopyLink => 'نسخ الرابط';

  @override
  String get inviteOtherApps => 'تطبيقات أخرى';

  @override
  String get inviteLinkCopied => 'تم نسخ رسالة الدعوة';

  @override
  String get invitePasteBody => 'انسخ الرمز من رسالة صديقك والصقه هنا.';

  @override
  String get invitePasteAction => 'لصق';

  @override
  String get inviteErrorTooLate => 'انتهى وقت إدخال رمز الدعوة على هذا الهاتف.';

  @override
  String get inviteErrorUnknown =>
      'لم نعثر على هذا الرمز. انسخه مرة أخرى من رسالة صديقك.';

  @override
  String get inviteErrorOwnCode => 'هذا رمزك أنت. أدخل رمز صديقك.';

  @override
  String get inviteErrorMutual => 'لا يمكنك أنت وصديقك أن يدعو كل منكما الآخر.';

  @override
  String inviteHowItWorksPremium(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'كل صديق يبدأ باستخدام فورتيفا يمنحك أيضًا بريميوم لمدة $days يوم.',
      many:
          'كل صديق يبدأ باستخدام فورتيفا يمنحك أيضًا بريميوم لمدة $days يومًا.',
      few: 'كل صديق يبدأ باستخدام فورتيفا يمنحك أيضًا بريميوم لمدة $days أيام.',
      two: 'كل صديق يبدأ باستخدام فورتيفا يمنحك أيضًا بريميوم لمدة يومين.',
      one: 'كل صديق يبدأ باستخدام فورتيفا يمنحك أيضًا بريميوم لمدة يوم واحد.',
    );
    return '$_temp0';
  }

  @override
  String inviteHowItWorksPremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'يمكنك الحصول من الدعوات على بريميوم لمدة تصل إلى $max يوم.',
      many: 'يمكنك الحصول من الدعوات على بريميوم لمدة تصل إلى $max يومًا.',
      few: 'يمكنك الحصول من الدعوات على بريميوم لمدة تصل إلى $max أيام.',
      two: 'يمكنك الحصول من الدعوات على بريميوم لمدة تصل إلى يومين.',
      one: 'يمكنك الحصول من الدعوات على بريميوم لمدة تصل إلى يوم واحد.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeLive =>
      'تستمر مكافأتك ما دام أصدقاؤك يستخدمون فورتيفا. إذا توقف أحدهم، تنخفض المكافأة.';

  @override
  String inviteTreeNext(String amount) {
    return 'صديقك التالي يضيف $amount يوميًا عندما يبدأ باستخدام فورتيفا.';
  }

  @override
  String inviteTreeKept(String amount) {
    return 'لن تقل مكافأتك عن $amount يوميًا أبدًا، بفضل الأصدقاء الذين دعوتهم سابقًا.';
  }

  @override
  String get inviteTreeSlotsTitle => 'خاناتك';

  @override
  String get inviteTreeSlotActive => 'نشط';

  @override
  String get inviteTreeSlotNotActive => 'غير نشط الآن';

  @override
  String get inviteTreeSlotEmpty => 'خانة فارغة';

  @override
  String inviteTreePaysNow(String amount) {
    return '+$amount يوميًا الآن';
  }

  @override
  String inviteTreePairFull(String amount) {
    return '+$amount يوميًا عندما يكون كلاهما نشطًا';
  }

  @override
  String get inviteTreeNothingYet => 'لا شيء بعد';

  @override
  String get inviteTreeFriendsTitle => 'عبر خاناتك';

  @override
  String get inviteTreeRowFriends => 'في خاناتك';

  @override
  String get inviteTreeRowFriendsSlots => 'في خاناتهم';

  @override
  String inviteTreeRowSteps(int steps) {
    String _temp0 = intl.Intl.pluralLogic(
      steps,
      locale: localeName,
      other: 'على بعد $steps خطوة',
      many: 'على بعد $steps خطوة',
      few: 'على بعد $steps خطوات',
      two: 'على بعد خطوتين',
      one: 'على بعد خطوة واحدة',
    );
    return '$_temp0';
  }

  @override
  String inviteTreeRowPeople(int people, int active) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people شخص',
      many: '$people شخصًا',
      few: '$people أشخاص',
      two: 'شخصان',
      one: 'شخص واحد',
    );
    return '$_temp0، $active نشط';
  }

  @override
  String inviteTreeHowSlots(int slots) {
    String _temp0 = intl.Intl.pluralLogic(
      slots,
      locale: localeName,
      other:
          'شارك رمزك. أول $slots من الأصدقاء الذين يتأهلون يملؤون خاناتك على شكل ثنائيات.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeHowSlotsNoNumber =>
      'شارك رمزك. أول الأصدقاء الذين يتأهلون يملؤون خاناتك على شكل ثنائيات.';

  @override
  String get inviteTreeHowPair => 'يمنحك الثنائي أكثر عندما يكون كلاهما نشطًا.';

  @override
  String get inviteTreeHowFriendsSlots =>
      'عندما تمتلئ خاناتك، يشغل الأصدقاء الذين يتأهلون بعد ذلك الخانات الفارغة التالية، الأبعد عنك. وهم أيضًا يضيفون إلى بياناتك، بمقدار أقل كلما ابتعدوا.';

  @override
  String get inviteTreeHowOthers =>
      'قد يشغل ثنائيك الأول أشخاص لم تدعُهم. وهم يضيفون إلى بياناتك بالطريقة نفسها.';

  @override
  String inviteTreeHowActive(int days, int window) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يوم',
      many: '$days يومًا',
      few: '$days أيام',
      two: 'يومين',
      one: 'يوم واحد',
    );
    String _temp1 = intl.Intl.pluralLogic(
      window,
      locale: localeName,
      other: '$window يوم',
      many: '$window يومًا',
      few: '$window أيام',
      two: 'يومين',
      one: 'يوم',
    );
    return 'يُحتسب الصديق نشطًا إذا استخدم فورتيفا في $_temp0 على الأقل خلال آخر $_temp1.';
  }

  @override
  String get inviteTreeHowActiveNoNumber =>
      'يُحتسب الصديق نشطًا ما دام يواصل استخدام فورتيفا.';

  @override
  String inviteTreeHowCap(String max) {
    return 'يمكن أن تضيف الدعوات حتى $max يوميًا.';
  }

  @override
  String get inviteTreeHowCapNoAmount => 'لما تضيفه الدعوات حد يومي.';

  @override
  String get premiumSourceInvite => 'هدية من دعوة الأصدقاء';

  @override
  String quotaBonusIncluded(String amount) {
    return 'تشمل $amount مكافأة دعوة';
  }

  @override
  String get updateTitle => 'يتوفر تحديث';

  @override
  String get updateRequiredTitle => 'التحديث مطلوب';

  @override
  String updateBody(String version) {
    return 'صدر الإصدار $version من فورتيفا. حدّث للحصول على آخر الإصلاحات.';
  }

  @override
  String get updateRequiredBody =>
      'هذا الإصدار لم يعد مدعوماً. حدّث لمواصلة استخدام فورتيفا.';

  @override
  String get updateNow => 'تحديث';

  @override
  String get updateLater => 'لاحقاً';

  @override
  String get updateFromPlay => 'Google Play';

  @override
  String get updateFromTelegram => 'قناة تيليجرام';

  @override
  String get updateConnect => 'اتصال';

  @override
  String get updateConnectHint =>
      'إذا لم يفتح Google Play أو تيليجرام، اضغط على اتصال أولاً.';

  @override
  String get updateConnected => 'أنت متصل الآن. نزّل التحديث.';

  @override
  String get updateReconnect => 'لا يعمل؟ أعد الاتصال';

  @override
  String get updateDisconnect => 'قطع الاتصال';

  @override
  String get updateDisconnectHint =>
      'اضغط على قطع الاتصال لتنزيل التحديث عبر اتصالك العادي بالإنترنت.';

  @override
  String get updateNotCarrying =>
      'أنت متصل، لكن لا شيء يمر عبر الاتصال. جرّب إعادة الاتصال، أو اضغط على قطع الاتصال لاستخدام اتصالك العادي بالإنترنت.';

  @override
  String get diagVerdictNoInternet =>
      'هاتفك غير متصل بالإنترنت. لا يمكن لـ Fortiva الاتصال حتى يعود الإنترنت.';

  @override
  String get diagVerdictCutOff =>
      'شبكتك لا تصل إلى الإنترنت الدولي الآن. حاول مرة أخرى بعد بضع دقائق.';

  @override
  String get diagVerdictNeedsPermission =>
      'ليس لدى Fortiva إذن بتشغيل VPN، أو هناك تطبيق VPN آخر مضبوط على وضع دائم التشغيل.';

  @override
  String get diagVerdictServerUnreachable =>
      'لا يمكن الوصول إلى هذا الخادم من شبكتك. إما أنه محجوب هنا أو متوقف.';

  @override
  String get diagVerdictBlockedTls =>
      'يُقطع الاتصال بهذا الخادم أثناء إنشائه. هذا ما يبدو عليه الحجب.';

  @override
  String get diagVerdictThrottled =>
      'أجاب الخادم عن كل الفحوصات، ومع ذلك لم يمرر النفق شيئًا. يتم إبطاء الاتصال.';

  @override
  String get diagCheckInternet => 'تحقق من اتصالك بالإنترنت';

  @override
  String diagTryServer(String server) {
    return 'بحث جديد عبر $server';
  }

  @override
  String get diagTryAnotherServer => 'جرّب خادمًا آخر';

  @override
  String get diagDetails => 'التفاصيل';

  @override
  String get diagDetailsHide => 'إخفاء التفاصيل';

  @override
  String privateDnsWarning(String host) {
    return 'ميزة DNS الخاص مفعّلة ($host)، لذلك قد لا تفتح بعض المواقع. أوقف DNS الخاص من إعدادات هاتفك.';
  }

  @override
  String get openNetworkSettings => 'فتح إعدادات الشبكة';

  @override
  String testPointStatus(String time, int open, int total) {
    return 'نقطة اختبار · آخر فحص $time · $open من $total مسارات مفتوحة';
  }

  @override
  String get messagesTooltip => 'الرسائل';

  @override
  String get inboxTitle => 'الرسائل';

  @override
  String get inboxEmpty => 'لا توجد رسائل حاليًا.';

  @override
  String get messageClose => 'إغلاق';

  @override
  String get supportTitle => 'الدعم';

  @override
  String get supportTooltip => 'الدردشة مع الدعم';

  @override
  String get supportAskAction => 'اسأل الدعم';

  @override
  String get supportContactSubtitle => 'تحدّث معنا داخل التطبيق';

  @override
  String get supportAutomaticNotice =>
      'تُكتب الإجابات تلقائيًا وقد تكون خاطئة.';

  @override
  String get supportStaffNotice =>
      'الإجابات التلقائية متوقفة حاليًا. تصل رسائلك إلى فريقنا.';

  @override
  String get supportInputHint => 'اكتب سؤالك';

  @override
  String get supportInputHintTeam => 'اكتب إلى فريقنا';

  @override
  String get supportSend => 'إرسال';

  @override
  String supportQuotaLeft(int remaining, int limit) {
    return 'الأسئلة المتبقية اليوم: $remaining من $limit';
  }

  @override
  String supportWaitIn(String time) {
    return 'يمكنك السؤال مرة أخرى بعد $time.';
  }

  @override
  String supportDurationHours(int hours, int minutes) {
    return '$hours س $minutes د';
  }

  @override
  String supportDurationMinutes(int minutes) {
    return '$minutes د';
  }

  @override
  String get supportNewConversation => 'محادثة جديدة';

  @override
  String get supportSending => 'جارٍ الإرسال';

  @override
  String get supportNotSent => 'لم تُرسل. اضغط للمحاولة مرة أخرى.';

  @override
  String get supportRateUp => 'مفيد';

  @override
  String get supportRateDown => 'غير مفيد';

  @override
  String get supportRatedDown => 'شكرًا. سيراجع فريقنا هذه الإجابة.';

  @override
  String get supportTeamLabel => 'فريق Fortiva';

  @override
  String get supportUnavailable => 'الدردشة غير متاحة الآن.';

  @override
  String get supportOpenTelegram => 'راسلنا على تيليجرام';

  @override
  String get supportGenericError => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String supportCodeTooLong(int max) {
    return 'رسالتك طويلة جدًا. اجعلها أقل من $max حرف.';
  }

  @override
  String get supportCodeEmpty => 'رسالتك فارغة.';

  @override
  String get supportCodeWaitReply => 'يرجى انتظار الرد على سؤالك السابق.';

  @override
  String get supportCodeSlowDown =>
      'أنت ترسل الرسائل بسرعة كبيرة. انتظر قليلًا من فضلك.';

  @override
  String get supportCodeQuotaDay => 'لقد استخدمت كل أسئلة اليوم.';

  @override
  String get supportCodePaused => 'الإجابات التلقائية متوقفة مؤقتًا.';

  @override
  String get supportCodeBusy =>
      'مساعدنا مشغول الآن. حاول مرة أخرى بعد بضع دقائق.';

  @override
  String get supportCodeGreeting => 'مرحبًا! كيف يمكنني مساعدتك في Fortiva؟';

  @override
  String get supportCodeGibberish =>
      'عذرًا، لم أفهم ذلك. اكتب سؤالك مرة أخرى من فضلك.';

  @override
  String get supportCodeRedacted =>
      'أزلنا البيانات الشخصية والروابط من رسالتك.';

  @override
  String get supportCodeRedactedEmpty =>
      'احتوت رسالتك على بيانات شخصية أو روابط فقط، لذلك لم تُرسل. صف المشكلة بالكلمات من فضلك.';

  @override
  String get supportCodeOffTopic =>
      'يمكنني المساعدة فقط في الأسئلة المتعلقة باستخدام Fortiva.';

  @override
  String get supportCodeAbuse =>
      'لنحافظ على الاحترام. أنا هنا لمساعدتك في Fortiva.';

  @override
  String get supportCodeAiUnavailable =>
      'لم يتمكن المساعد من الرد هذه المرة. حاول مرة أخرى بعد قليل.';

  @override
  String get supportCodeToStaff => 'أُرسلت إلى فريقنا. سيظهر ردهم هنا.';

  @override
  String get supportCodeTicketOpened =>
      'أحلنا سؤالك إلى فريقنا. سيظهر ردهم هنا.';

  @override
  String get supportCodeNotSent =>
      'تعذّر إرسال هذه الرسالة. اكتبها مرة أخرى إذا كنت لا تزال بحاجة إلى المساعدة.';

  @override
  String get supportAssistantSubtitle => 'مساعد بالذكاء الاصطناعي';

  @override
  String get supportThinkingReading => 'أقرأ سؤالك';

  @override
  String get supportThinkingSearching => 'أبحث عن الإجابة';

  @override
  String get supportThinkingWriting => 'أكتب الإجابة';

  @override
  String get supportThinkingStill => 'ما زلت أعمل عليه، شكرًا لصبرك';

  @override
  String get supportSuggestConnect => 'لا أستطيع الاتصال';

  @override
  String get supportSuggestData => 'كم لديّ من البيانات اليوم؟';

  @override
  String get supportSuggestSlow => 'اتصالي بطيء';

  @override
  String get supportWithTeam => 'هذه المحادثة الآن مع فريقنا.';

  @override
  String get supportTryAgainSoon => 'حاول مرة أخرى بعد بضع دقائق.';

  @override
  String supportDurationWholeHours(int hours) {
    return '$hours س';
  }

  @override
  String get supportUnreadReply => 'لديك رد جديد';

  @override
  String get premiumTitle => 'بريميوم';

  @override
  String get premiumTileSubtitle => 'بيانات غير محدودة بلا حد يومي';

  @override
  String get premiumTileActive => 'بريميوم مفعّل';

  @override
  String get premiumGetUnlimited => 'احصل على غير محدود';

  @override
  String get premiumHeadline => 'احصل على بيانات غير محدودة';

  @override
  String get premiumPitch =>
      'يرفع بريميوم الحد اليومي، فتستخدم ما تشاء من البيانات حتى تنتهي مدته.';

  @override
  String get premiumActiveTitle => 'بريميوم مفعّل';

  @override
  String premiumActiveUntil(String date) {
    return 'بيانات غير محدودة حتى $date';
  }

  @override
  String get premiumActiveNoDate => 'بيانات غير محدودة';

  @override
  String get premiumRenews => 'يتجدد تلقائيًا عبر Google Play';

  @override
  String get premiumSourceKey => 'مفعّل بمفتاح';

  @override
  String get premiumSourceCrypto => 'مدفوع بالعملات الرقمية';

  @override
  String get premiumSourceStars => 'مدفوع بنجوم تيليجرام';

  @override
  String get premiumSourceGooglePlay => 'مدفوع عبر Google Play';

  @override
  String get premiumSourceManual => 'هدية من فريق Fortiva';

  @override
  String get premiumYourKey => 'مفتاحك';

  @override
  String get premiumKeyHint =>
      'احتفظ بهذا المفتاح في مكان آمن. أدخله على هاتف آخر لنقل بريميوم إليه.';

  @override
  String premiumKeyMoves(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يوم',
      many: '$days يومًا',
      few: '$days أيام',
      two: 'يومين',
      one: 'يوم',
    );
    return 'حد نقل المفتاح إلى هاتف آخر: $count مرات في كل $_temp0.';
  }

  @override
  String get premiumKeyMovesNoNumber =>
      'لا يمكن نقل المفتاح إلى هاتف آخر إلا لعدد محدود من المرات.';

  @override
  String get premiumCopy => 'نسخ';

  @override
  String get premiumCopied => 'تم النسخ';

  @override
  String get premiumChoosePlan => 'اختر خطة';

  @override
  String premiumPlanDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يوم من البيانات غير المحدودة',
      many: '$days يومًا من البيانات غير المحدودة',
      few: '$days أيام من البيانات غير المحدودة',
      two: 'يومان من البيانات غير المحدودة',
      one: 'يوم واحد من البيانات غير المحدودة',
    );
    return '$_temp0';
  }

  @override
  String get premiumPlanNoDays => 'بيانات غير محدودة';

  @override
  String get premiumBuy => 'شراء';

  @override
  String get premiumPlayUnavailable =>
      'Google Play غير متاح الآن. حاول مرة أخرى لاحقًا.';

  @override
  String get premiumPlayPending =>
      'دفعتك معلّقة في Google Play. يبدأ بريميوم فور اكتمالها.';

  @override
  String get premiumPlayConfirming => 'جارٍ تأكيد الشراء...';

  @override
  String get premiumPlayRetrying =>
      'تم الدفع، لكننا لم نتمكن من تأكيده بعد. سنواصل المحاولة، فلا داعي للدفع مرة أخرى.';

  @override
  String get premiumPlayRefused =>
      'لم نتمكن من تأكيد هذا الشراء. إذا خُصم منك مبلغ، فتواصل مع الدعم.';

  @override
  String get premiumPlayNotAvailable =>
      'بريميوم غير متاح على هذا الهاتف الآن. إذا خُصم منك مبلغ، فتواصل مع الدعم.';

  @override
  String get premiumNotAvailable => 'بريميوم غير متاح على هذا الهاتف الآن.';

  @override
  String get premiumPlayFailed => 'لم تكتمل عملية الشراء. حاول مرة أخرى.';

  @override
  String get premiumNowOn => 'بريميوم مفعّل الآن. استمتع ببيانات غير محدودة.';

  @override
  String get premiumRestore => 'استعادة المشتريات';

  @override
  String get premiumRestoreDone => 'تمت استعادة مشترياتك على هذا الهاتف.';

  @override
  String get premiumRestoreNone =>
      'لا توجد مشتريات لاستعادتها في حساب Google هذا.';

  @override
  String get premiumRestoreFailed =>
      'تعذّرت استعادة المشتريات. حاول مرة أخرى لاحقًا.';

  @override
  String premiumRenewsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يُدفع كل $count يوم. يتجدد تلقائيًا حتى تلغي الاشتراك.',
      many: 'يُدفع كل $count يومًا. يتجدد تلقائيًا حتى تلغي الاشتراك.',
      few: 'يُدفع كل $count أيام. يتجدد تلقائيًا حتى تلغي الاشتراك.',
      two: 'يُدفع كل يومين. يتجدد تلقائيًا حتى تلغي الاشتراك.',
      one: 'يُدفع كل يوم. يتجدد تلقائيًا حتى تلغي الاشتراك.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يُدفع كل $count أسبوع. يتجدد تلقائيًا حتى تلغي الاشتراك.',
      many: 'يُدفع كل $count أسبوعًا. يتجدد تلقائيًا حتى تلغي الاشتراك.',
      few: 'يُدفع كل $count أسابيع. يتجدد تلقائيًا حتى تلغي الاشتراك.',
      two: 'يُدفع كل أسبوعين. يتجدد تلقائيًا حتى تلغي الاشتراك.',
      one: 'يُدفع كل أسبوع. يتجدد تلقائيًا حتى تلغي الاشتراك.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يُدفع كل $count شهر. يتجدد تلقائيًا حتى تلغي الاشتراك.',
      many: 'يُدفع كل $count شهرًا. يتجدد تلقائيًا حتى تلغي الاشتراك.',
      few: 'يُدفع كل $count أشهر. يتجدد تلقائيًا حتى تلغي الاشتراك.',
      two: 'يُدفع كل شهرين. يتجدد تلقائيًا حتى تلغي الاشتراك.',
      one: 'يُدفع كل شهر. يتجدد تلقائيًا حتى تلغي الاشتراك.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يُدفع كل $count سنة. يتجدد تلقائيًا حتى تلغي الاشتراك.',
      many: 'يُدفع كل $count سنة. يتجدد تلقائيًا حتى تلغي الاشتراك.',
      few: 'يُدفع كل $count سنوات. يتجدد تلقائيًا حتى تلغي الاشتراك.',
      two: 'يُدفع كل سنتين. يتجدد تلقائيًا حتى تلغي الاشتراك.',
      one: 'يُدفع كل سنة. يتجدد تلقائيًا حتى تلغي الاشتراك.',
    );
    return '$_temp0';
  }

  @override
  String get premiumRenewsNoPeriod => 'يتجدد تلقائيًا حتى تلغي الاشتراك.';

  @override
  String get premiumPlayCancelNote =>
      'يمكنك الإلغاء في أي وقت من Google Play. يبقى بريميوم مفعّلًا حتى نهاية المدة التي دفعت عنها.';

  @override
  String get premiumManageSubscription => 'إدارة الاشتراك أو إلغاؤه';

  @override
  String get premiumCurrentPlan => 'الخطة الحالية';

  @override
  String get premiumPlaySubscribed =>
      'لديك اشتراك في Google Play بالفعل. يمكنك إدارته أو إلغاؤه من Google Play.';

  @override
  String get premiumEnterCode => 'إدخال رمز';

  @override
  String get premiumNeedsPlayVersion =>
      'للشراء عبر Google Play، تحتاج إلى نسخة Google Play من Fortiva.';

  @override
  String get premiumOff => 'بريميوم غير معروض للبيع الآن.';

  @override
  String get premiumLoadFailed =>
      'تعذّر تحميل بريميوم. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get premiumRetry => 'حاول مرة أخرى';

  @override
  String premiumPriceUsdt(String price) {
    return '$price USDT';
  }

  @override
  String premiumPriceStars(String stars) {
    return 'نجوم تيليجرام: $stars';
  }

  @override
  String get premiumPayCrypto => 'الدفع بالعملات الرقمية';

  @override
  String get premiumTelegramTitle => 'الدفع في تيليجرام';

  @override
  String get premiumTelegramBody =>
      'ادفع بنجوم تيليجرام في البوت الخاص بنا. تحصل على مفتاح، ويبدأ بريميوم على هذا الهاتف فورًا.';

  @override
  String get premiumTelegramButton => 'اشترِ في تيليجرام';

  @override
  String get premiumTelegramFailed => 'تعذّر فتح تيليجرام. حاول مرة أخرى.';

  @override
  String get checkoutTitle => 'الدفع بالعملات الرقمية';

  @override
  String get checkoutChooseNetwork => 'اختر الشبكة التي سترسل منها';

  @override
  String get checkoutContinue => 'متابعة';

  @override
  String get checkoutSendExactly => 'أرسل هذا المبلغ بالضبط';

  @override
  String get checkoutNetwork => 'الشبكة';

  @override
  String get checkoutAddress => 'إلى هذا العنوان';

  @override
  String get checkoutMemo => 'مع هذه المذكرة';

  @override
  String get checkoutMemoWarning =>
      'ضع هذه المذكرة في التحويل، وإلا فلن نتمكن من ربط الدفعة بك.';

  @override
  String get checkoutExactWarning =>
      'أرسل المبلغ بالضبط وعلى هذه الشبكة فقط. قد لا يصلنا مبلغ مختلف أو شبكة أخرى.';

  @override
  String checkoutTimeLeft(String time) {
    return 'الوقت المتبقي: $time';
  }

  @override
  String get checkoutWaiting => 'بانتظار دفعتك. تتحدث هذه الصفحة تلقائيًا.';

  @override
  String get checkoutPaidTitle => 'تم استلام الدفعة';

  @override
  String get checkoutPaidKeyOnly =>
      'مفتاحك جاهز. أدخله على الهاتف الذي تريد تفعيل بريميوم عليه.';

  @override
  String get checkoutDone => 'تم';

  @override
  String get checkoutExpired =>
      'انتهت صلاحية هذا الطلب. إذا كنت قد دفعت، فتواصل مع الدعم.';

  @override
  String get checkoutUnderpaid =>
      'استلمنا أقل من المبلغ الكامل. تواصل مع الدعم وأعطهم رقم الطلب هذا:';

  @override
  String get checkoutCanceled => 'أُلغي هذا الطلب.';

  @override
  String get checkoutStartAgain => 'البدء من جديد';

  @override
  String get checkoutUnavailable => 'الدفع بالعملات الرقمية غير متاح الآن.';

  @override
  String get checkoutTooManyOpen =>
      'لديك طلبات غير مدفوعة كثيرة. ادفع أحدها أو انتظر حتى تنتهي صلاحيتها.';

  @override
  String get checkoutUnknownPlan =>
      'لم تعد هذه الخطة معروضة للبيع. ارجع واختر خطة أخرى.';

  @override
  String get checkoutFailed =>
      'تعذّر بدء الدفع. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get redeemTitle => 'إدخال رمز';

  @override
  String get redeemSubtitle => 'مفتاح بريميوم أو رمز هدية';

  @override
  String get redeemHint => 'الرمز';

  @override
  String get redeemApply => 'تطبيق';

  @override
  String get redeemCancel => 'إلغاء';

  @override
  String get redeemInvalid => 'هذا لا يبدو رمزًا. تحقق منه وحاول مرة أخرى.';

  @override
  String get redeemUnknown => 'لا نعرف هذا الرمز. تحقق منه وحاول مرة أخرى.';

  @override
  String get redeemExpired => 'انتهت صلاحية هذا الرمز.';

  @override
  String get redeemRevoked => 'لم يعد هذا الرمز صالحًا.';

  @override
  String get redeemMovedTooOften =>
      'نُقل هذا المفتاح بين الهواتف كثيرًا مؤخرًا. حاول مرة أخرى لاحقًا.';

  @override
  String get redeemExhausted => 'نفدت استخدامات هذا الرمز.';

  @override
  String get redeemAlreadyUsed => 'استخدم هذا الهاتف هذا الرمز من قبل.';

  @override
  String get redeemUnmetered =>
      'لدى هذا الهاتف بيانات غير محدودة بالفعل، فلا حاجة لهذا الرمز.';

  @override
  String get redeemRateLimited => 'محاولات كثيرة. انتظر قليلًا وحاول مرة أخرى.';

  @override
  String get redeemUnavailable =>
      'هذه الخدمة غير متاحة الآن. حاول مرة أخرى لاحقًا.';

  @override
  String get redeemNetwork =>
      'تعذّر الوصول إلى الخادم. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get redeemFailed => 'لم ينجح هذا الرمز. تحقق منه وحاول مرة أخرى.';

  @override
  String get redeemMoved => 'نُقل بريميوم إلى هذا الهاتف.';

  @override
  String redeemPromo(String amount) {
    return 'تم قبول الرمز. أُضيف $amount من البيانات الإضافية.';
  }

  @override
  String get redeemPromoNoAmount => 'تم قبول الرمز. أُضيفت بيانات إضافية.';

  @override
  String get tvScanTitle => 'افتح على هاتفك';

  @override
  String get tvScanBody => 'وجّه كاميرا هاتفك إلى هذا الرمز.';

  @override
  String get refresh => 'تحديث';

  @override
  String get premiumNotNow => 'ليس الآن';

  @override
  String get premiumLimitSheetTitle => 'انتهت بيانات اليوم';

  @override
  String get premiumLimitWait => 'انتظر حتى تتجدد';

  @override
  String get premiumLimitInvite => 'ادعُ أصدقاءك لتحصل على بيانات أكثر';

  @override
  String get premiumNoDailyLimit => 'لا يوجد حد يومي في بريميوم.';

  @override
  String get premiumCalmTitle => 'هل تريد التخلص من الحد اليومي؟';

  @override
  String get premiumCalmBody =>
      'يمنحك بريميوم بيانات غير محدودة. تبقى خطتك المجانية كما هي.';

  @override
  String get premiumNextStepTitle => 'الخطوة التالية هي بريميوم';

  @override
  String get premiumNextStepBody =>
      'لديك بالفعل أكبر قدر من البيانات المجانية. لا يوجد حد يومي في بريميوم.';

  @override
  String get premiumLockedTag => 'بريميوم';

  @override
  String premiumLockedTitle(String place) {
    return 'افتح $place مع بريميوم';
  }

  @override
  String get premiumLockedBody =>
      'هذا الموقع مخصص لبريميوم. تبقى خوادمك المجانية كما هي.';

  @override
  String get premiumHeadlineLimit => 'بلا حد يومي';

  @override
  String premiumHeadlineLocked(String place) {
    return 'افتح $place مع بريميوم';
  }

  @override
  String get premiumFreeStays => 'تظل الخطة المجانية تعمل بدون بريميوم.';

  @override
  String premiumEndsOn(String date) {
    return 'ينتهي بريميوم في $date';
  }

  @override
  String get premiumRenewBody =>
      'جدّد لتحتفظ بالبيانات غير المحدودة. التجديد يضيف المدة إلى تاريخ الانتهاء الحالي.';

  @override
  String premiumEndedOn(String date) {
    return 'انتهى بريميوم في $date. عادت خطتك المجانية.';
  }

  @override
  String get premiumRenew => 'تجديد';

  @override
  String get noticeChannelName => 'رسائل من Fortiva';

  @override
  String get noticeChannelDescription => 'أخبار ورسائل من فريق Fortiva';

  @override
  String get noticesSettingTitle => 'الإشعارات';

  @override
  String get noticesSettingOn =>
      'مفعّلة. يمكن أن تصلك رسائل فريق Fortiva حتى عندما يكون التطبيق مغلقًا.';

  @override
  String get noticesSettingOff =>
      'متوقفة. فعّلها لتصلك رسائل فريق Fortiva حتى عندما يكون التطبيق مغلقًا.';

  @override
  String get noticesOffCard =>
      'فعّل الإشعارات لتصلك رسائل فريق Fortiva حتى عندما يكون التطبيق مغلقًا.';

  @override
  String get noticesTurnOn => 'تفعيل';

  @override
  String get backgroundCard =>
      'قد يؤخّر هاتفك رسائل فريق Fortiva عندما يكون التطبيق مغلقًا. اسمح لـ Fortiva بالعمل في الخلفية لتصلك الرسائل.';

  @override
  String get backgroundHint =>
      'في الشاشة التالية، اختر Fortiva (إن لم يظهر، اعرض كل التطبيقات). ثم اضبط استخدام البطارية على «غير مقيّد»، أو اسمح له بالتشغيل التلقائي والعمل في الخلفية.';

  @override
  String get backgroundAllow => 'السماح';

  @override
  String get backgroundNotNow => 'ليس الآن';

  @override
  String get backgroundSettingTitle => 'الرسائل عند إغلاق التطبيق';

  @override
  String get backgroundSettingSubtitle =>
      'اسمح لـ Fortiva بالعمل في الخلفية لتصلك الرسائل حتى عندما يكون التطبيق مغلقًا.';

  @override
  String get backgroundCardData =>
      'قد يمنع موفّر البيانات في هاتفك وصول رسائل فريق Fortiva عندما يكون التطبيق مغلقًا.';

  @override
  String get backgroundHintData =>
      'في الشاشة التالية، فعّل «بيانات غير مقيّدة».';

  @override
  String get apnGuideTitle => 'اتصال أكثر ثباتًا على هذه الشريحة';

  @override
  String get apnGuideBody =>
      'لا يستخدم هاتفك IPv6 على هذه الشريحة. تفعيله يساعد Fortiva على البقاء متصلًا.';

  @override
  String get apnGuideShowMe => 'أرني الطريقة';

  @override
  String get apnGuideNotNow => 'ليس الآن';

  @override
  String get apnGuideSheetTitle => 'فعّل IPv6 لهذه الشريحة';

  @override
  String apnGuideStepOpen(String button) {
    return 'اضغط على \"$button\" (أو انتقل إلى الإعدادات > الاتصالات > شبكات الجوال > أسماء نقاط الوصول).';
  }

  @override
  String apnGuideStepAccessPoint(String apn) {
    return 'اضغط على نقطة الوصول المستخدمة ($apn).';
  }

  @override
  String get apnGuideStepAccessPointAny => 'اضغط على نقطة الوصول المستخدمة.';

  @override
  String get apnGuideStepProtocol =>
      'اضغط على \"بروتوكول APN\" واختر \"IPv4/IPv6\".';

  @override
  String get apnGuideStepSave =>
      'احفظ (في سامسونج: قائمة النقاط الثلاث، ثم \"حفظ\").';

  @override
  String get apnGuideStepRestart => 'أوقف بيانات الجوال ثم شغّلها مرة أخرى.';

  @override
  String get apnGuideUndo =>
      'إذا توقفت بيانات الجوال عن العمل، فأعد بروتوكول APN إلى IPv4.';

  @override
  String get apnGuideOpenSettings => 'فتح إعدادات APN';

  @override
  String get homeStallSearching =>
      'توقف الاتصال عن العمل. جارٍ البحث عن مسار آخر.';

  @override
  String get homeStalled => 'متصل، لكن لا تمر أي بيانات';

  @override
  String get peerShareTitle => 'ساعد صديقك على الاتصال';

  @override
  String get peerShareSubtitle =>
      'انقل إلى هاتف صديقك كل ما يحتاج إليه تطبيق Fortiva';

  @override
  String get peerShareBody =>
      'إذا لم يستطع Fortiva الاتصال لدى صديقك، يمكن لهاتفه أن يأخذ ما يحتاجه من هاتفك. يعمل هذا بدون إنترنت.';

  @override
  String peerShareSteps(String action) {
    return 'على هاتف صديقك، افتح الإعدادات في Fortiva واضغط على \"$action\". ثم اعرض عليه هذه الرموز رمزًا تلو الآخر، أو أرسلها إليه.';
  }

  @override
  String get peerShareLoading => 'جارٍ جلب أحدث نسخة';

  @override
  String get peerShareNothing =>
      'لا يوجد على هذا الهاتف شيء حديث لنقله. حاول مرة أخرى لاحقًا.';

  @override
  String peerShareCodeOf(int current, int total) {
    return 'الرمز $current من $total';
  }

  @override
  String get peerSharePrevious => 'السابق';

  @override
  String get peerShareNext => 'التالي';

  @override
  String get peerShareCopy => 'نسخ';

  @override
  String get peerShareSend => 'إرسال';

  @override
  String get peerShareCopied => 'تم النسخ. الصقه في رسالة إلى صديقك.';

  @override
  String get peerReceiveTitle => 'اطلب المساعدة من صديق';

  @override
  String get peerReceiveSubtitle => 'حين لا ينجح الاتصال بأي طريقة أخرى';

  @override
  String peerReceiveBody(String action) {
    return 'اطلب من صديق يعمل لديه Fortiva أن يفتح الإعدادات في Fortiva ويضغط على \"$action\". ثم خذ ما يلزمك من هاتفه بأيٍّ من هذه الطرق.';
  }

  @override
  String get peerReceivePhotograph => 'صوّر رموز صديقك';

  @override
  String get peerReceivePhotographNext => 'صوّر الرمز التالي';

  @override
  String peerReceiveProgress(int have, int total) {
    return 'الرموز المقروءة: $have من $total';
  }

  @override
  String get peerReceiveFile => 'افتح ملفًا أرسله صديقك';

  @override
  String get peerReceivePaste => 'الصق ما أرسله صديقك';

  @override
  String get peerReceiveNoCode =>
      'لم يُعثر على رمز في هذه الصورة. قرّب الهاتف واجعل الرمز كله ظاهرًا.';

  @override
  String get peerReceiveRefused =>
      'لا يمكن لـ Fortiva استخدام هذا. اطلب من صديقك إرساله مرة أخرى.';

  @override
  String get peerReceiveNotNewer =>
      'لديك هذا بالفعل، أو ما هو أحدث منه. حاول الاتصال مرة أخرى، أو اطلب المساعدة من صديق آخر.';

  @override
  String get peerReceiveTaken => 'تم. اضغط على الزر للاتصال.';

  @override
  String get peerReceiveUnavailable =>
      'لا يستطيع هذا الهاتف فعل ذلك. جرّب طريقة أخرى.';

  @override
  String get peerReceiveNothingToPaste =>
      'لم يُنسخ شيء بعد. انسخ ما أرسله صديقك، ثم اضغط هنا مرة أخرى.';

  @override
  String get peerOfferBody =>
      'ما زال الاتصال متعذرًا؟ يمكن لصديق يعمل لديه Fortiva أن يساعدك من هاتفه.';

  @override
  String get peerReceiveAgain =>
      'هذا الرمز لديك بالفعل. اطلب من صديقك أن يعرض الرمز التالي.';

  @override
  String get peerReceivePasteNotOurs =>
      'ما نسخته ليس من Fortiva. انسخ رسالة صديقك كاملة، ثم حاول مرة أخرى.';

  @override
  String peerReceiveNoPhoto(String action) {
    return 'لم تصل الصورة من الكاميرا. التقط الصورة بتطبيق الكاميرا، ثم اضغط على \"$action\".';
  }

  @override
  String get peerReceiveFileHint =>
      'قد تحتاج إلى حفظ الملف الذي وصلك عبر تطبيق مراسلة في مجلد التنزيلات أولًا.';

  @override
  String get homeTryingBackup =>
      'لم يتصل أي مسار آخر. نجرّب الآن شبكة احتياطية.';

  @override
  String get homeConnectedBackup => 'متصل عبر شبكة احتياطية';

  @override
  String get backupNetwork => 'شبكة احتياطية';

  @override
  String get backupNetworkTitle => 'شبكة احتياطية';

  @override
  String get backupNetworkCaption =>
      'تُستخدم عندما لا يتصل أي خيار آخر. قد تكون أبطأ من خوادمنا.';

  @override
  String get backupNetworkPlace => 'يتم اختيار الموقع تلقائيًا';

  @override
  String get speedTestStart => 'بدء الاختبار';

  @override
  String get speedTestAgain => 'أعد الاختبار';

  @override
  String get speedTestRunning => 'جارٍ الاختبار';

  @override
  String get speedTestIdle => 'اعرف سرعة اتصالك الآن.';

  @override
  String get speedTestPhasePing => 'جارٍ قياس زمن الاستجابة';

  @override
  String get speedTestPhaseDownload => 'جارٍ قياس سرعة التنزيل';

  @override
  String get speedTestPhaseUpload => 'جارٍ قياس سرعة الرفع';

  @override
  String get speedTestDone => 'انتهى الاختبار';

  @override
  String get speedTestFailed =>
      'لم يكتمل الاختبار. تحقق من اتصالك بالإنترنت وحاول مرة أخرى.';

  @override
  String get speedTestUnit => 'ميغابت/ث';

  @override
  String get ipAddressLabel => 'عنوان IP';

  @override
  String get ipCopied => 'تم نسخ العنوان';

  @override
  String get ipLocation => 'الموقع';

  @override
  String get ipProvider => 'مزود الإنترنت';

  @override
  String get ipOrganization => 'المؤسسة';

  @override
  String get ipTimeZone => 'المنطقة الزمنية';

  @override
  String get ipCoordinates => 'الإحداثيات';

  @override
  String get ipCheckFailed => 'تعذر التحقق من عنوانك';

  @override
  String get historyAverage => 'متوسط الاتصال';

  @override
  String get historyRecentDays => 'الأيام الأخيرة';

  @override
  String yesterdayAt(String time) {
    return 'أمس الساعة $time';
  }

  @override
  String dateAt(String date, String time) {
    return '$date الساعة $time';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds ث';
  }

  @override
  String get stageOwn => 'خوادم Fortiva';

  @override
  String get stageCommunity => 'خوادم المجتمع';

  @override
  String stageProgress(int n, int total) {
    return 'المرحلة $n من $total';
  }

  @override
  String get stageTryingOwn => 'نجرّب خوادم Fortiva';

  @override
  String get stageTryingCommunity => 'نجرّب خوادم المجتمع';

  @override
  String get stageOwnFailedTryingCommunity =>
      'لم تتصل خوادم Fortiva من هنا. نجرّب الآن خوادم المجتمع.';

  @override
  String stageLastWorked(String server) {
    return 'آخر خادم نجح الاتصال به: $server';
  }

  @override
  String stageTriedBlocked(int count) {
    return 'المسارات المجرّبة: $count، وهي محجوبة هنا';
  }

  @override
  String stageTriedFailed(int count) {
    return 'المسارات المجرّبة: $count، ولم يتصل أي منها';
  }

  @override
  String get stageNotConnected => 'لم يتصل';

  @override
  String get stageConnected => 'تم الاتصال من هنا';

  @override
  String get stageSkipped => 'لم تُجرَّب هذه المرة';

  @override
  String stageMoreToCheck(int count) {
    return 'مسارات أخرى للفحص: $count';
  }

  @override
  String stageNextTry(String stage, String time) {
    return 'المحاولة التالية بعد $time، وتبدأ مع $stage';
  }

  @override
  String get searchSlowHint =>
      'قد يستغرق هذا دقيقة أو دقيقتين. اضغط الزر لإيقاف البحث.';

  @override
  String get searchStopped => 'توقف البحث';

  @override
  String get homeConnectedCommunity => 'متصل عبر خادم المجتمع';

  @override
  String get stageGettingServers => 'جارٍ جلب خوادمك';

  @override
  String stageNextTryStarting(String stage) {
    return 'تبدأ المحاولة التالية الآن مع $stage';
  }
}
