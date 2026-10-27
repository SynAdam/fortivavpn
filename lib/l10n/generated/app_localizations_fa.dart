// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class SFa extends S {
  SFa([String locale = 'fa']) : super(locale);

  @override
  String get appTitle => 'FortivaVPN';

  @override
  String get statusDisconnected => 'وصل نیست';

  @override
  String get statusConnecting => 'در حال اتصال';

  @override
  String get statusConnected => 'وصل شد';

  @override
  String get statusDisconnecting => 'در حال قطع';

  @override
  String get statusError => 'خطا';

  @override
  String get statusVerifying => 'در حال بررسی...';

  @override
  String get disconnect => 'قطع اتصال';

  @override
  String get connectBtn => 'اتصال';

  @override
  String get disconnectBtn => 'قطع اتصال';

  @override
  String get pleaseWait => 'لطفاً صبر کنید';

  @override
  String get locationLabel => 'موقعیت';

  @override
  String get selectServer => 'یک موقعیت انتخاب کنید';

  @override
  String get serverLocation => 'موقعیت';

  @override
  String get searchServers => 'جستجوی سرور';

  @override
  String get locationsTitle => 'موقعیت‌ها';

  @override
  String get sortLatency => 'مرتب‌سازی: تأخیر';

  @override
  String get sortAZ => 'مرتب‌سازی: الف-ی';

  @override
  String get sortedByLatency => 'بر اساس تأخیر مرتب شده';

  @override
  String get sortedAZ => 'مرتب شده الفبایی';

  @override
  String get pingAll => 'تست همه';

  @override
  String get pinging => 'در حال پینگ...';

  @override
  String get ping => 'پینگ';

  @override
  String get stop => 'توقف';

  @override
  String get fastestServer => 'سریع‌ترین';

  @override
  String get timeout => 'وقفه';

  @override
  String get tabCommunity => 'عمومی';

  @override
  String get tabFree => 'رایگان';

  @override
  String get tabPremium => 'ویژه';

  @override
  String get noCommunityServers => 'هنوز سرور عمومی وجود ندارد';

  @override
  String get communityLoadFailed => 'این فهرست بارگذاری نشد';

  @override
  String get communityRetry => 'دوباره تلاش کنید';

  @override
  String get officialTabExplainer =>
      'این سرورها را خود Fortiva اداره و نگهداری می‌کند و بین همه کاربران اپ مشترک است. از اینجا شروع کنید.';

  @override
  String get communityTabExplainer =>
      'گزینه‌های اتصال بیشتر. سرعت و در دسترس بودنشان متفاوت است.';

  @override
  String get noFreeServers => 'هنوز سرور رایگان وجود ندارد';

  @override
  String get noPremiumServers => 'هنوز سرور ویژه وجود ندارد';

  @override
  String noResultsFor(String query) {
    return 'نتیجه‌ای برای «$query» یافت نشد';
  }

  @override
  String get proBadge => 'ویژه';

  @override
  String get freeBadge => 'رایگان';

  @override
  String get settings => 'تنظیمات';

  @override
  String get connection => 'اتصال';

  @override
  String get dnsConfiguration => 'DNS';

  @override
  String get customDns => 'استفاده از DNS دلخواه';

  @override
  String get about => 'درباره';

  @override
  String get privacyPolicy => 'سیاست حفظ حریم خصوصی';

  @override
  String get contactUs => 'تماس با ما';

  @override
  String get rateOnGooglePlay => 'امتیاز به فورتیوا در گوگل پلی';

  @override
  String get website => 'وب‌سایت';

  @override
  String get copyright => '© ۲۰۲۶ NimusAI';

  @override
  String get version => 'نسخه';

  @override
  String get language => 'زبان';

  @override
  String get languageSubtitle => 'زبان نمایش برنامه';

  @override
  String get whatIsDns => 'DNS چیست؟';

  @override
  String get dnsExplanation =>
      'DNS نام سایت‌ها را به آدرسی تبدیل می‌کند که گوشی شما می‌تواند به آن وصل شود. انتخاب DNS دیگر می‌تواند باعث شود سایت‌ها سریع‌تر باز شوند و به باز شدن سایت‌های مسدود کمک کند.';

  @override
  String get configuration => 'تنظیمات';

  @override
  String get primaryDns => 'DNS اصلی';

  @override
  String get primaryDnsHint => 'پیش‌فرض: 1.1.1.1';

  @override
  String get secondaryDns => 'DNS دوم (اختیاری)';

  @override
  String get secondaryDnsHint => 'پیش‌فرض: 8.8.8.8';

  @override
  String get saveConfiguration => 'ذخیره';

  @override
  String get dnsSaved => 'تنظیمات DNS ذخیره شد';

  @override
  String get invalidPrimaryDns => 'آدرس DNS اصلی معتبر نیست';

  @override
  String get invalidSecondaryDns => 'آدرس DNS دوم معتبر نیست';

  @override
  String get statistics => 'تاریخچه';

  @override
  String get overview => 'نمای کلی';

  @override
  String get connectionsLabel => 'اتصال‌ها';

  @override
  String get totalTime => 'مدت اتصال';

  @override
  String get dataUsage => 'مصرف داده';

  @override
  String get uploaded => 'آپلود شده';

  @override
  String get downloaded => 'دانلود شده';

  @override
  String get total => 'مجموع';

  @override
  String lastUpdated(String date) {
    return 'آخرین به‌روزرسانی: $date';
  }

  @override
  String today(String time) {
    return 'امروز ساعت $time';
  }

  @override
  String get yesterday => 'دیروز';

  @override
  String daysAgo(int count) {
    return '$count روز پیش';
  }

  @override
  String get noDataYet => 'هنوز داده‌ای وجود ندارد';

  @override
  String get connectToStart => 'برای شروع ثبت، وصل شوید';

  @override
  String get errorConnectionFailed => 'اتصال برقرار نشد';

  @override
  String get errorServerNotWorking =>
      'این موقعیت کار نمی‌کند، یکی دیگر را امتحان کنید';

  @override
  String get errorServerNotForwarding =>
      'این موقعیت ترافیک را عبور نمی‌دهد، یکی دیگر را امتحان کنید';

  @override
  String get errorUnexpected => 'خطای غیرمنتظره';

  @override
  String get errorDisconnectionFailed => 'قطع اتصال انجام نشد';

  @override
  String get errorFailedToRegister => 'ثبت دستگاه ناموفق';

  @override
  String get ipInformation => 'بررسی آی‌پی من';

  @override
  String get connectionAnalytics => 'تاریخچه';

  @override
  String get recentSessions => 'اتصال‌های اخیر';

  @override
  String get speedTest => 'تست سرعت';

  @override
  String get startTest => 'شروع تست';

  @override
  String get download => 'دانلود';

  @override
  String get upload => 'آپلود';

  @override
  String get testingViaVpn => 'تست از طریق VPN';

  @override
  String get testingDirect => 'تست اتصال مستقیم';

  @override
  String get splitTunneling => 'تونل تقسیم';

  @override
  String get splitTunnelingDescription =>
      'دسته‌بندی‌های برنامه‌هایی که از تونل VPN عبور می‌کنند را انتخاب کنید.';

  @override
  String get enableSplitTunneling => 'فعال‌سازی تونل تقسیم';

  @override
  String get splitTunnelActive => 'برنامه‌های انتخاب شده VPN را دور می‌زنند';

  @override
  String get splitTunnelInactive => 'تمام ترافیک از VPN عبور می‌کند';

  @override
  String get bypassVpnFor => 'عبور از VPN برای';

  @override
  String get tools => 'ابزارها';

  @override
  String get settingsGeneral => 'عمومی';

  @override
  String get shareDiagnosticsTitle => 'اشتراک‌گذاری اطلاعات عیب‌یابی اتصال';

  @override
  String get shareDiagnosticsBody =>
      'گزارش اتصال‌ها، اپراتور و کشور شما، مدل گوشی و نسخه اندروید، نام سایت‌هایی که با وی‌پی‌ان باز می‌کنید همراه با تعداد روزانه، و اینکه پیام‌ها، پیشنهادهای پریمیوم و کارت دعوت ما را دیده‌اید یا روی آن‌ها زده‌اید فرستاده می‌شود. ما هرگز صفحه‌هایی را که باز می‌کنید یا چیزی را که می‌فرستید نمی‌بینیم.';

  @override
  String get security => 'امنیت';

  @override
  String get privacyDashboard => 'داشبورد حریم خصوصی';

  @override
  String get privacyDashboardSubtitle => 'اطلاعات IP و محافظت از نشت';

  @override
  String get connectionAnalyticsSubtitle => 'تاریخچه جلسات و نمودارها';

  @override
  String get speedTestSubtitle => 'سرعت اتصال خود را تست کنید';

  @override
  String get splitTunnelingSubtitle => 'مسیریابی VPN برنامه‌ها';

  @override
  String get splashTagline => 'دسترسی آزاد و امن، هر جا که هستید';

  @override
  String get openSourceLicence => 'مجوز متن‌باز';

  @override
  String get sourceOfferTitle => 'مجوز متن‌باز';

  @override
  String get sourceOfferBody =>
      'فورتیوا نرم‌افزار آزاد است و تحت مجوز GNU GPL نسخه ۳ منتشر می‌شود. این برنامه بر پایه Xray-core و چند پروژه متن‌باز دیگر ساخته شده است.\n\nشما حق دارید کد کامل همان نسخه‌ای را که نصب کرده‌اید دریافت کنید. برای درخواست، شماره نسخه برنامه را به admin@fortivavpn.com ایمیل کنید. این پیشنهاد تا سه سال از تاریخ دریافت این نسخه معتبر است.';

  @override
  String get close => 'بستن';

  @override
  String get account => 'حساب کاربری';

  @override
  String get deleteAccount => 'حذف حساب کاربری';

  @override
  String get deleteAccountSubtitle =>
      'این دستگاه و داده‌های شما برای همیشه پاک می‌شود';

  @override
  String get deleteAccountConfirmTitle => 'حساب کاربری خود را حذف می‌کنید؟';

  @override
  String get deleteAccountConfirmBody =>
      'با این کار ثبت دستگاه شما، حساب گوگل متصل‌شده، سرورهای اختصاصی‌ای که برایتان ساخته شده و پیام‌های گفتگوی شما با پشتیبانی حذف می‌شود. سابقه اتصال روی همین گوشی هم پاک می‌شود.\n\nاین کار برگشت‌پذیر نیست. هر وقت خواستید می‌توانید دوباره برنامه را باز کنید و از نو شروع کنید.';

  @override
  String deleteAccountConfirmRetention(int days) {
    return 'پرونده حساب شما بی‌درنگ حذف می‌شود. نسخه‌های موجود در پشتیبان‌گیری و گزارش‌های ناشناس سرور ظرف $days روز پاک می‌شوند.';
  }

  @override
  String get deleteAccountConfirmRetentionNoDays =>
      'پرونده حساب شما بی‌درنگ حذف می‌شود. نسخه‌های موجود در پشتیبان‌گیری و گزارش‌های ناشناس سرور بعداً، در مهلتی که سیاست حریم خصوصی ما تعیین کرده است، پاک می‌شوند.';

  @override
  String get deleteAccountCancel => 'حساب من بماند';

  @override
  String get deleteAccountConfirm => 'حذف';

  @override
  String get deleteAccountInProgress => 'در حال حذف حساب کاربری';

  @override
  String get deleteAccountDone => 'حساب کاربری شما حذف شد.';

  @override
  String get deleteAccountFailed =>
      'حذف حساب انجام نشد. اتصال خود را بررسی کنید و دوباره تلاش کنید.';

  @override
  String get homeTapToConnect => 'برای اتصال ضربه بزنید';

  @override
  String get homeChecking => 'در حال بررسی اتصال';

  @override
  String get homePreparing => 'در حال آماده‌سازی سرور شما';

  @override
  String get homeDisconnecting => 'در حال قطع اتصال';

  @override
  String get homeFindingPath => 'در حال یافتن مسیر';

  @override
  String get diagCheckingInternet => 'بررسی اینترنت گوشی';

  @override
  String get diagInternationalCut => 'اینترنت بین‌الملل روی این شبکه قطع است';

  @override
  String diagPathRow(String city, int n) {
    return '$city، مسیر $n';
  }

  @override
  String get diagOpen => 'باز';

  @override
  String get diagBlocked => 'مسدود';

  @override
  String get diagSkipped => 'امروز رد شد';

  @override
  String diagConnectingThrough(String city) {
    return 'اتصال از طریق $city';
  }

  @override
  String get diagVerifying => 'بررسی عبور ترافیک';

  @override
  String get diagNoInternet => 'گوشی شما الان به اینترنت وصل نیست.';

  @override
  String get diagCutOff =>
      'شبکه شما الان به اینترنت بین‌الملل دسترسی ندارد. برای تلاش دوباره ضربه بزنید.';

  @override
  String get diagNothingOpen =>
      'همه مسیرها الان مسدود هستند. برای تلاش دوباره ضربه بزنید.';

  @override
  String get homeTryingAgain =>
      'همه مسیرها الان مسدود هستند. کمی بعد دوباره تلاش می‌کنیم.';

  @override
  String get homeCutOffTryingAgain =>
      'شبکه شما الان به اینترنت بین‌الملل دسترسی ندارد. کمی بعد دوباره تلاش می‌کنیم.';

  @override
  String get homeOfflineTryingAgain =>
      'گوشی شما الان به اینترنت وصل نیست. کمی بعد دوباره تلاش می‌کنیم.';

  @override
  String get diagPathFailed =>
      'مسیر باز بود ولی تونل برقرار نشد. برای تلاش دوباره ضربه بزنید.';

  @override
  String get openVpnSettings => 'باز کردن تنظیمات VPN';

  @override
  String get yourServer => 'سرور شما';

  @override
  String get yourServerCaption =>
      'فقط برای شما. هیچ‌کس دیگری از آن استفاده نمی‌کند.';

  @override
  String get ourServer => 'سرور ما';

  @override
  String get ourServerCaption =>
      'توسط Fortiva اداره می‌شود و بین همه مشترک است. تا آماده شدن سرور خودتان استفاده می‌شود.';

  @override
  String get communityServer => 'سرور عمومی';

  @override
  String get communityServerCaption =>
      'یک گزینه اتصال بیشتر. ممکن است هر زمانی از کار بیفتد.';

  @override
  String communityServerNumber(String n) {
    return 'سرور عمومی $n';
  }

  @override
  String get myServersTitle => 'سرورهای شما';

  @override
  String get myServersExplainer =>
      'هر دستگاه Fortiva در هر موقعیت سرور مخصوص خودش را دارد، با اطلاعات ورودی که فقط به همین نصب تعلق دارد. نیازی به حساب کاربری نیست.';

  @override
  String get myServersInUse => 'در حال استفاده';

  @override
  String get myServersEmpty => 'هنوز سروری اختصاص داده نشده است';

  @override
  String get myServersRetry => 'دوباره تلاش کنید';

  @override
  String get myServersBlockedTitle => 'حجم امروز شما تمام شده است';

  @override
  String get myServersBlockedWait =>
      'سهمیه شما به‌طور خودکار ریست می‌شود. کمی بعد دوباره سر بزنید.';

  @override
  String myServersMoved(String place) {
    return 'اکنون از $place استفاده می‌شود';
  }

  @override
  String get copyLink => 'کپی لینک';

  @override
  String get linkCopied => 'لینک کپی شد';

  @override
  String quotaUsedToday(String used, String limit) {
    return '$used از $limit امروز مصرف شده';
  }

  @override
  String get quotaUsedUp => 'حجم روزانه تمام شد';

  @override
  String get quotaUnlimited => 'حجم نامحدود';

  @override
  String get quotaDaily => 'حجم روزانه';

  @override
  String get quotaLimitReached => 'به سقف روزانه رسیدید';

  @override
  String quotaLeftOf(String left, String limit) {
    return '$left از $limit باقی مانده';
  }

  @override
  String get quotaResetsShortly => 'به‌زودی ریست می‌شود';

  @override
  String quotaResetsInHours(int hours) {
    return 'تا $hours ساعت دیگر ریست می‌شود';
  }

  @override
  String quotaResetsInMinutes(int minutes) {
    return 'تا $minutes دقیقه دیگر ریست می‌شود';
  }

  @override
  String get myServersSubtitle => 'سرورهایی که برای این دستگاه تأمین شده‌اند';

  @override
  String get sharedServersTitle => 'سرورهای مشترک';

  @override
  String get sharedServersSubtitle =>
      'موقعیت‌های عمومی، به‌عنوان گزینه پشتیبان';

  @override
  String get tabOfficial => 'سرورهای ما';

  @override
  String get noOfficialServers => 'در حال حاضر سرور Fortiva موجود نیست';

  @override
  String get inviteTitle => 'دعوت از دوستان';

  @override
  String get inviteSubtitle => 'دیتای روزانه بیشتری بگیرید';

  @override
  String get inviteYourCode => 'کد دعوت شما';

  @override
  String get inviteShareAction => 'اشتراک‌گذاری دعوت';

  @override
  String get inviteCopyAction => 'کپی کد';

  @override
  String get inviteCodeCopied => 'کد کپی شد';

  @override
  String inviteShareMessage(String code, String url) {
    return 'یه فیلترشکن رایگان که برای من خوب کار می‌کنه: فورتیوا. ثبت‌نام نمی‌خواد.\nاز این لینک نصبش کن:\n$url\nکد دعوت من: $code';
  }

  @override
  String get inviteHowItWorks => 'چطور کار می‌کند';

  @override
  String inviteHowItWorksBody(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days روز مختلف',
      one: '$days روز',
    );
    return 'کدتان را به اشتراک بگذارید. وقتی کسی برنامه را نصب کند، کد را وارد کند و در $_temp0 از وی‌پی‌ان استفاده کند، $amount به دیتای روزانه شما اضافه می‌شود و همیشه باقی می‌ماند.';
  }

  @override
  String inviteHowItWorksBodyNoAmount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days روز مختلف',
      one: '$days روز',
    );
    return 'کدتان را به اشتراک بگذارید. وقتی کسی برنامه را نصب کند، کد را وارد کند و در $_temp0 از وی‌پی‌ان استفاده کند، دیتای روزانه شما بیشتر می‌شود و همیشه باقی می‌ماند.';
  }

  @override
  String inviteHowItWorksBodyNoDays(String amount) {
    return 'کدتان را به اشتراک بگذارید. وقتی کسی برنامه را نصب کند، کد را وارد کند و مدتی از وی‌پی‌ان استفاده کند، $amount به دیتای روزانه شما اضافه می‌شود و همیشه باقی می‌ماند.';
  }

  @override
  String get inviteHowItWorksBodyNoAmountNoDays =>
      'کدتان را به اشتراک بگذارید. وقتی کسی برنامه را نصب کند، کد را وارد کند و مدتی از وی‌پی‌ان استفاده کند، دیتای روزانه شما بیشتر می‌شود و همیشه باقی می‌ماند.';

  @override
  String inviteHowItWorksCap(String max) {
    return 'از دعوت دوستان حداکثر $max در روز می‌گیرید.';
  }

  @override
  String get inviteStatInvited => 'دعوت‌شده';

  @override
  String get inviteStatEarning => 'واجد شرایط';

  @override
  String get inviteStatBonus => 'دیتای پاداش';

  @override
  String inviteBonusPerDay(String amount) {
    return '+$amount هر روز';
  }

  @override
  String get inviteNoBonusYet => 'هنوز پاداشی ندارید';

  @override
  String invitePendingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دعوت هنوز واجد شرایط نشده‌اند',
      one: '۱ دعوت هنوز واجد شرایط نشده است',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String inviteJoinedWith(String code) {
    return 'شما با کد $code وارد شدید';
  }

  @override
  String get inviteLoadFailed => 'کد دعوت شما بارگذاری نشد';

  @override
  String get inviteRetry => 'تلاش دوباره';

  @override
  String get inviteHaveCodeTitle => 'کد دعوت دارید؟';

  @override
  String inviteHaveCodeSubtitle(int hours) {
    return 'آن را در $hours ساعت اول وارد کنید';
  }

  @override
  String get inviteHaveCodeSubtitleNoHours => 'آن را کمی پس از نصب وارد کنید';

  @override
  String get inviteEnterCodeHint => 'کد دعوت';

  @override
  String get inviteApplyAction => 'اعمال';

  @override
  String get inviteNotNowAction => 'الان نه';

  @override
  String inviteClaimAccepted(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days روز مختلف',
      one: '$days روز',
    );
    return 'دعوت پذیرفته شد. وقتی در $_temp0 از وی‌پی‌ان استفاده کنید، دوستتان دیتای پاداش می‌گیرد.';
  }

  @override
  String get inviteClaimAcceptedNoDays =>
      'دعوت پذیرفته شد. وقتی مدتی از وی‌پی‌ان استفاده کنید، دوستتان دیتای پاداش می‌گیرد.';

  @override
  String get inviteClaimAlready =>
      'این دستگاه قبلاً از یک کد دعوت استفاده کرده است';

  @override
  String get inviteClaimRejected =>
      'این کد کار نکرد. آن را بررسی و دوباره تلاش کنید';

  @override
  String get inviteClaimNetwork =>
      'ارتباط با سرور برقرار نشد. دوباره تلاش کنید';

  @override
  String get inviteCardTitle => 'فورتیوا برات خوب کار کرد؟ برای دوستت بفرست';

  @override
  String get inviteCardBody =>
      'لینک نصب رو برای دوستت بفرست تا اونم رایگان وصل بشه.';

  @override
  String inviteCardReward(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'وقتی دوستت از فورتیوا استفاده کنه، $days روز پریمیوم می‌گیری.',
    );
    return '$_temp0';
  }

  @override
  String get inviteCardRewardNoAmount =>
      'وقتی دوستت از فورتیوا استفاده کنه، پریمیوم هدیه می‌گیری.';

  @override
  String get inviteSendTelegram => 'تلگرام';

  @override
  String get inviteSendWhatsApp => 'واتس‌اپ';

  @override
  String get inviteCopyLink => 'کپی لینک';

  @override
  String get inviteOtherApps => 'برنامه‌های دیگه';

  @override
  String get inviteLinkCopied => 'پیام دعوت کپی شد';

  @override
  String get invitePasteBody => 'کد رو از پیام دوستت کپی کن و اینجا بچسبون.';

  @override
  String get invitePasteAction => 'چسباندن';

  @override
  String get inviteErrorTooLate =>
      'زمان وارد کردن کد دعوت برای این گوشی تموم شده.';

  @override
  String get inviteErrorUnknown =>
      'این کد پیدا نشد. دوباره از پیام دوستت کپی کن.';

  @override
  String get inviteErrorOwnCode => 'این کد خودته. کد دوستت رو وارد کن.';

  @override
  String get inviteErrorMutual => 'تو و دوستت نمی‌تونید همدیگه رو دعوت کنید.';

  @override
  String inviteHowItWorksPremium(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'هر دوستی که از فورتیوا استفاده کنه، $days روز پریمیوم هم بهت می‌ده.',
    );
    return '$_temp0';
  }

  @override
  String inviteHowItWorksPremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'از دعوت‌ها تا $max روز پریمیوم می‌تونی بگیری.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeLive =>
      'پاداش شما تا وقتی ادامه دارد که دوستانتان از فورتیوا استفاده کنند. اگر دوستی استفاده را کنار بگذارد، پاداش کم می‌شود.';

  @override
  String inviteTreeNext(String amount) {
    return 'دوست بعدی که دعوت کنید، وقتی استفاده از فورتیوا را شروع کند، $amount در روز به دیتای شما اضافه می‌کند.';
  }

  @override
  String inviteTreeKept(String amount) {
    return 'پاداش شما به‌خاطر دوستانی که قبلاً دعوت کرده‌اید، هیچ‌وقت از $amount در روز کمتر نمی‌شود.';
  }

  @override
  String get inviteTreeSlotsTitle => 'جایگاه‌های شما';

  @override
  String get inviteTreeSlotActive => 'فعال';

  @override
  String get inviteTreeSlotNotActive => 'فعلاً غیرفعال';

  @override
  String get inviteTreeSlotEmpty => 'جای خالی';

  @override
  String inviteTreePaysNow(String amount) {
    return '+$amount در روز، اکنون';
  }

  @override
  String inviteTreePairFull(String amount) {
    return '+$amount در روز، وقتی هر دو فعال باشند';
  }

  @override
  String get inviteTreeNothingYet => 'هنوز چیزی نیست';

  @override
  String get inviteTreeFriendsTitle => 'از طریق جایگاه‌هایتان';

  @override
  String get inviteTreeRowFriends => 'در جایگاه‌های شما';

  @override
  String get inviteTreeRowFriendsSlots => 'در جایگاه‌های آن‌ها';

  @override
  String inviteTreeRowSteps(int steps) {
    String _temp0 = intl.Intl.pluralLogic(
      steps,
      locale: localeName,
      other: 'با $steps قدم فاصله',
    );
    return '$_temp0';
  }

  @override
  String inviteTreeRowPeople(int people, int active) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people نفر',
    );
    return '$_temp0، $active نفر فعال';
  }

  @override
  String inviteTreeHowSlots(int slots) {
    String _temp0 = intl.Intl.pluralLogic(
      slots,
      locale: localeName,
      other:
          'کدتان را به اشتراک بگذارید. $slots دوست اولی که واجد شرایط شوند، جایگاه‌های شما را جفت‌جفت پر می‌کنند.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeHowSlotsNoNumber =>
      'کدتان را به اشتراک بگذارید. اولین دوستانی که واجد شرایط شوند، جایگاه‌های شما را جفت‌جفت پر می‌کنند.';

  @override
  String get inviteTreeHowPair =>
      'هر جفت وقتی هر دوی آن‌ها فعال باشند، پاداش بیشتری می‌دهد.';

  @override
  String get inviteTreeHowFriendsSlots =>
      'وقتی جایگاه‌های شما پر شود، دوستان بعدی‌تان که واجد شرایط شوند جایگاه‌های خالی بعدی را می‌گیرند که از شما دورترند. آن‌ها هم به دیتای شما اضافه می‌کنند، ولی هرچه دورتر باشند، کمتر.';

  @override
  String get inviteTreeHowOthers =>
      'جفت اول شما ممکن است با کسانی پر شود که دعوتشان نکرده‌اید. آن‌ها هم به همین شکل به دیتای شما اضافه می‌کنند.';

  @override
  String inviteTreeHowActive(int days, int window) {
    return 'هر دوست تا وقتی فعال حساب می‌شود که در $window روز گذشته، دست‌کم در $days روز از فورتیوا استفاده کرده باشد.';
  }

  @override
  String get inviteTreeHowActiveNoNumber =>
      'هر دوست تا وقتی فعال حساب می‌شود که به استفاده از فورتیوا ادامه دهد.';

  @override
  String inviteTreeHowCap(String max) {
    return 'دعوت‌ها می‌توانند تا $max در روز به دیتای شما اضافه کنند.';
  }

  @override
  String get inviteTreeHowCapNoAmount => 'پاداش دعوت در روز سقف مشخصی دارد.';

  @override
  String get premiumSourceInvite => 'هدیه دعوت از دوستان';

  @override
  String quotaBonusIncluded(String amount) {
    return 'شامل $amount پاداش دعوت';
  }

  @override
  String get updateTitle => 'نسخه جدید اومده';

  @override
  String get updateRequiredTitle => 'باید به‌روزرسانی کنی';

  @override
  String updateBody(String version) {
    return 'نسخه $version فورتیوا منتشر شد. برای آخرین اصلاح‌ها به‌روزرسانی کن.';
  }

  @override
  String get updateRequiredBody =>
      'این نسخه دیگه پشتیبانی نمی‌شه. برای ادامه استفاده، به‌روزرسانی کن.';

  @override
  String get updateNow => 'به‌روزرسانی';

  @override
  String get updateLater => 'بعداً';

  @override
  String get updateFromPlay => 'گوگل پلی';

  @override
  String get updateFromTelegram => 'کانال تلگرام';

  @override
  String get updateConnect => 'اتصال';

  @override
  String get updateConnectHint =>
      'اگه گوگل پلی یا تلگرام باز نمی‌شه، اول روی اتصال بزن.';

  @override
  String get updateConnected => 'وصل شدی. حالا به‌روزرسانی رو دانلود کن.';

  @override
  String get updateReconnect => 'کار نمی‌کنه؟ دوباره وصل شو';

  @override
  String get updateDisconnect => 'قطع اتصال';

  @override
  String get updateDisconnectHint =>
      'روی قطع اتصال بزن تا به‌روزرسانی رو با اینترنت معمولی‌ت دانلود کنی.';

  @override
  String get updateNotCarrying =>
      'وصلی، ولی چیزی باز نمی‌شه. دوباره وصل شو، یا روی قطع اتصال بزن تا با اینترنت معمولی‌ت ادامه بدی.';

  @override
  String get diagVerdictNoInternet =>
      'گوشی شما به اینترنت وصل نیست. تا وصل نشود، فورتیوا هم وصل نمی‌شود.';

  @override
  String get diagVerdictCutOff =>
      'شبکه شما الان به اینترنت بین‌الملل دسترسی ندارد. چند دقیقه دیگر دوباره امتحان کنید.';

  @override
  String get diagVerdictNeedsPermission =>
      'فورتیوا اجازه اجرای VPN را ندارد، یا یک برنامه VPN دیگر روی حالت همیشه روشن است.';

  @override
  String get diagVerdictServerUnreachable =>
      'این سرور از شبکه شما در دسترس نیست. یا اینجا مسدود است یا خودش خاموش است.';

  @override
  String get diagVerdictBlockedTls =>
      'ارتباط با این سرور وسط برقرار شدن قطع می‌شود. این نشانه فیلترینگ است.';

  @override
  String get diagVerdictThrottled =>
      'سرور به همه بررسی‌ها جواب داد ولی تونل چیزی رد نکرد. سرعت ارتباط پایین آورده شده است.';

  @override
  String get diagCheckInternet => 'اینترنت را بررسی کنید';

  @override
  String diagTryServer(String server) {
    return 'جستجوی تازه با $server';
  }

  @override
  String get diagTryAnotherServer => 'سرور دیگری را امتحان کنید';

  @override
  String get diagDetails => 'جزئیات';

  @override
  String get diagDetailsHide => 'بستن جزئیات';

  @override
  String privateDnsWarning(String host) {
    return 'DNS خصوصی گوشیت روشنه ($host) و برای همین بعضی سایت‌ها باز نمی‌شن. از تنظیمات گوشی DNS خصوصی رو خاموش کن.';
  }

  @override
  String get openNetworkSettings => 'باز کردن تنظیمات شبکه';

  @override
  String testPointStatus(String time, int open, int total) {
    return 'نقطه‌ی آزمایش · آخرین بررسی $time · $open از $total مسیر باز';
  }

  @override
  String get messagesTooltip => 'پیام‌ها';

  @override
  String get inboxTitle => 'پیام‌ها';

  @override
  String get inboxEmpty => 'فعلاً پیامی نیست.';

  @override
  String get messageClose => 'بستن';

  @override
  String get supportTitle => 'پشتیبانی';

  @override
  String get supportTooltip => 'گفتگو با پشتیبانی';

  @override
  String get supportAskAction => 'از پشتیبانی بپرس';

  @override
  String get supportContactSubtitle => 'همین‌جا توی برنامه با ما گفتگو کن';

  @override
  String get supportAutomaticNotice =>
      'جواب‌ها خودکار نوشته می‌شن و ممکنه اشتباه باشن.';

  @override
  String get supportStaffNotice =>
      'فعلاً جواب خودکار خاموشه. پیام‌هات به تیم ما می‌رسه.';

  @override
  String get supportInputHint => 'سؤالت رو بنویس';

  @override
  String get supportInputHintTeam => 'برای تیم ما بنویس';

  @override
  String get supportSend => 'ارسال';

  @override
  String supportQuotaLeft(int remaining, int limit) {
    return '$remaining از $limit سؤال امروز باقی مونده';
  }

  @override
  String supportWaitIn(String time) {
    return '$time دیگه می‌تونی دوباره بپرسی.';
  }

  @override
  String supportDurationHours(int hours, int minutes) {
    return '$hours ساعت و $minutes دقیقه';
  }

  @override
  String supportDurationMinutes(int minutes) {
    return '$minutes دقیقه';
  }

  @override
  String get supportNewConversation => 'گفتگوی تازه';

  @override
  String get supportSending => 'در حال ارسال';

  @override
  String get supportNotSent => 'ارسال نشد. برای تلاش دوباره بزن.';

  @override
  String get supportRateUp => 'مفید بود';

  @override
  String get supportRateDown => 'مفید نبود';

  @override
  String get supportRatedDown => 'ممنون. تیم ما این جواب رو بررسی می‌کنه.';

  @override
  String get supportTeamLabel => 'تیم Fortiva';

  @override
  String get supportUnavailable => 'گفتگو الان در دسترس نیست.';

  @override
  String get supportOpenTelegram => 'توی تلگرام بهمون پیام بده';

  @override
  String get supportGenericError => 'یه مشکلی پیش اومد. دوباره امتحان کن.';

  @override
  String supportCodeTooLong(int max) {
    return 'پیامت خیلی طولانیه. کمتر از $max حرف بنویس.';
  }

  @override
  String get supportCodeEmpty => 'پیامت خالیه.';

  @override
  String get supportCodeWaitReply => 'لطفاً صبر کن تا جواب سؤال قبلیت بیاد.';

  @override
  String get supportCodeSlowDown =>
      'پیام‌ها رو خیلی سریع می‌فرستی. یه کم صبر کن.';

  @override
  String get supportCodeQuotaDay => 'همه‌ی سؤال‌های امروزت رو پرسیدی.';

  @override
  String get supportCodePaused => 'فعلاً جواب خودکار متوقف شده.';

  @override
  String get supportCodeBusy =>
      'دستیار ما الان خیلی سرش شلوغه. چند دقیقه دیگه دوباره امتحان کن.';

  @override
  String get supportCodeGreeting =>
      'سلام! چطور می‌تونم توی استفاده از Fortiva کمکت کنم؟';

  @override
  String get supportCodeGibberish =>
      'ببخشید، متوجه نشدم. لطفاً سؤالت رو دوباره بنویس.';

  @override
  String get supportCodeRedacted =>
      'اطلاعات شخصی و لینک‌ها رو از پیامت حذف کردیم.';

  @override
  String get supportCodeRedactedEmpty =>
      'پیامت فقط اطلاعات شخصی یا لینک داشت، برای همین فرستاده نشد. لطفاً مشکل رو با کلمه‌ها توضیح بده.';

  @override
  String get supportCodeOffTopic =>
      'من فقط می‌تونم توی سؤال‌های مربوط به استفاده از Fortiva کمک کنم.';

  @override
  String get supportCodeAbuse =>
      'بیا محترمانه حرف بزنیم. من اینجام که توی Fortiva کمکت کنم.';

  @override
  String get supportCodeAiUnavailable =>
      'دستیار این بار نتونست جواب بده. کمی بعد دوباره امتحان کن.';

  @override
  String get supportCodeToStaff =>
      'برای تیم ما فرستاده شد. جوابشون همین‌جا میاد.';

  @override
  String get supportCodeTicketOpened =>
      'سؤالت رو به تیم ما سپردیم. جوابشون همین‌جا میاد.';

  @override
  String get supportCodeNotSent =>
      'این پیام فرستاده نشد. اگه هنوز کمک لازم داری، دوباره بنویسش.';

  @override
  String get supportAssistantSubtitle => 'دستیار هوشمند';

  @override
  String get supportThinkingReading => 'دارم سؤالت رو می‌خونم';

  @override
  String get supportThinkingSearching => 'دنبال جواب می‌گردم';

  @override
  String get supportThinkingWriting => 'دارم جواب رو می‌نویسم';

  @override
  String get supportThinkingStill =>
      'هنوز دارم روش کار می‌کنم، ممنون که صبر می‌کنی';

  @override
  String get supportSuggestConnect => 'نمی‌تونم وصل بشم';

  @override
  String get supportSuggestData => 'امروز چقدر حجم دارم؟';

  @override
  String get supportSuggestSlow => 'اتصالم کنده';

  @override
  String get supportWithTeam => 'این گفتگو الان دست تیم ماست.';

  @override
  String get supportTryAgainSoon => 'چند دقیقه دیگه دوباره امتحان کن.';

  @override
  String supportDurationWholeHours(int hours) {
    return '$hours ساعت';
  }

  @override
  String get supportUnreadReply => 'جواب تازه داری';

  @override
  String get premiumTitle => 'پریمیوم';

  @override
  String get premiumTileSubtitle => 'حجم نامحدود، بدون سقف روزانه';

  @override
  String get premiumTileActive => 'پریمیوم فعال است';

  @override
  String get premiumGetUnlimited => 'حجم نامحدود بگیرید';

  @override
  String get premiumHeadline => 'حجم نامحدود بگیرید';

  @override
  String get premiumPitch =>
      'پریمیوم سقف روزانه را برمی‌دارد و تا وقتی اعتبارش تمام نشده، هر چقدر بخواهید استفاده می‌کنید.';

  @override
  String get premiumActiveTitle => 'پریمیوم فعال است';

  @override
  String premiumActiveUntil(String date) {
    return 'حجم نامحدود تا $date';
  }

  @override
  String get premiumActiveNoDate => 'حجم نامحدود';

  @override
  String get premiumRenews => 'از طریق گوگل پلی خودکار تمدید می‌شود';

  @override
  String get premiumSourceKey => 'با کلید فعال شده';

  @override
  String get premiumSourceCrypto => 'پرداخت با ارز دیجیتال';

  @override
  String get premiumSourceStars => 'پرداخت با استارز تلگرام';

  @override
  String get premiumSourceGooglePlay => 'پرداخت از طریق گوگل پلی';

  @override
  String get premiumSourceManual => 'هدیه‌ای از طرف تیم فورتیوا';

  @override
  String get premiumYourKey => 'کلید شما';

  @override
  String get premiumKeyHint =>
      'این کلید را جای امنی نگه دارید. با وارد کردنش در گوشی دیگری، پریمیوم به آن گوشی منتقل می‌شود.';

  @override
  String premiumKeyMoves(int count, int days) {
    return 'هر کلید را می‌شود در هر $days روز، تا $count بار به گوشی دیگری منتقل کرد.';
  }

  @override
  String get premiumKeyMovesNoNumber =>
      'هر کلید را فقط به تعداد محدودی می‌شود به گوشی دیگری منتقل کرد.';

  @override
  String get premiumCopy => 'کپی';

  @override
  String get premiumCopied => 'کپی شد';

  @override
  String get premiumChoosePlan => 'طرح مورد نظرتان را انتخاب کنید';

  @override
  String premiumPlanDays(int days) {
    return '$days روز حجم نامحدود';
  }

  @override
  String get premiumPlanNoDays => 'حجم نامحدود';

  @override
  String get premiumBuy => 'خرید';

  @override
  String get premiumPlayUnavailable =>
      'گوگل پلی الان در دسترس نیست. کمی بعد دوباره امتحان کنید.';

  @override
  String get premiumPlayPending =>
      'پرداخت شما در گوگل پلی در انتظار است. به محض انجام شدن، پریمیوم فعال می‌شود.';

  @override
  String get premiumPlayConfirming => 'در حال تأیید خرید شما...';

  @override
  String get premiumPlayRetrying =>
      'پرداخت انجام شد، اما هنوز نتوانستیم تأییدش کنیم. خودمان دوباره تلاش می‌کنیم و لازم نیست دوباره پرداخت کنید.';

  @override
  String get premiumPlayRefused =>
      'نتوانستیم این خرید را تأیید کنیم. اگر از حسابتان پولی کم شده، با پشتیبانی تماس بگیرید.';

  @override
  String get premiumPlayNotAvailable =>
      'پریمیوم فعلاً برای این گوشی در دسترس نیست. اگر از حسابتان پولی کم شده، با پشتیبانی تماس بگیرید.';

  @override
  String get premiumNotAvailable =>
      'پریمیوم فعلاً برای این گوشی در دسترس نیست.';

  @override
  String get premiumPlayFailed => 'خرید انجام نشد. دوباره امتحان کنید.';

  @override
  String get premiumNowOn => 'پریمیوم فعال شد. از حجم نامحدود لذت ببرید.';

  @override
  String get premiumRestore => 'بازیابی خریدها';

  @override
  String get premiumRestoreDone => 'خرید شما روی این گوشی بازیابی شد.';

  @override
  String get premiumRestoreNone => 'این حساب گوگل خریدی برای بازیابی ندارد.';

  @override
  String get premiumRestoreFailed =>
      'بازیابی خرید انجام نشد. کمی بعد دوباره امتحان کنید.';

  @override
  String premiumRenewsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'هر $count روز یک بار پرداخت می‌شود. تا وقتی لغو نکنید، خودکار تمدید می‌شود.',
      one: 'هر روز پرداخت می‌شود. تا وقتی لغو نکنید، خودکار تمدید می‌شود.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'هر $count هفته یک بار پرداخت می‌شود. تا وقتی لغو نکنید، خودکار تمدید می‌شود.',
      one: 'هر هفته پرداخت می‌شود. تا وقتی لغو نکنید، خودکار تمدید می‌شود.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'هر $count ماه یک بار پرداخت می‌شود. تا وقتی لغو نکنید، خودکار تمدید می‌شود.',
      one: 'هر ماه پرداخت می‌شود. تا وقتی لغو نکنید، خودکار تمدید می‌شود.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'هر $count سال یک بار پرداخت می‌شود. تا وقتی لغو نکنید، خودکار تمدید می‌شود.',
      one: 'هر سال پرداخت می‌شود. تا وقتی لغو نکنید، خودکار تمدید می‌شود.',
    );
    return '$_temp0';
  }

  @override
  String get premiumRenewsNoPeriod => 'تا وقتی لغو نکنید، خودکار تمدید می‌شود.';

  @override
  String get premiumPlayCancelNote =>
      'هر وقت بخواهید می‌توانید اشتراک را در گوگل پلی لغو کنید. پریمیوم تا پایان مدتی که پولش را داده‌اید فعال می‌ماند.';

  @override
  String get premiumManageSubscription => 'مدیریت یا لغو اشتراک';

  @override
  String get premiumCurrentPlan => 'طرح فعلی';

  @override
  String get premiumPlaySubscribed =>
      'شما از قبل یک اشتراک گوگل پلی دارید. می‌توانید آن را در گوگل پلی مدیریت یا لغو کنید.';

  @override
  String get premiumEnterCode => 'وارد کردن کد';

  @override
  String get premiumNeedsPlayVersion =>
      'برای خرید از طریق گوگل پلی به نسخه گوگل پلی فورتیوا نیاز دارید.';

  @override
  String get premiumOff => 'پریمیوم فعلاً فروخته نمی‌شود.';

  @override
  String get premiumLoadFailed =>
      'اطلاعات پریمیوم بارگذاری نشد. اتصالتان را بررسی کنید و دوباره امتحان کنید.';

  @override
  String get premiumRetry => 'دوباره امتحان کنید';

  @override
  String premiumPriceUsdt(String price) {
    return '$price تتر';
  }

  @override
  String premiumPriceStars(String stars) {
    return '$stars استارز تلگرام';
  }

  @override
  String get premiumPayCrypto => 'پرداخت با ارز دیجیتال';

  @override
  String get premiumTelegramTitle => 'پرداخت در تلگرام';

  @override
  String get premiumTelegramBody =>
      'در ربات ما با استارز تلگرام پرداخت کنید. کلید پریمیوم را می‌گیرید و پریمیوم همان لحظه روی این گوشی فعال می‌شود.';

  @override
  String get premiumTelegramButton => 'خرید در تلگرام';

  @override
  String get premiumTelegramFailed => 'تلگرام باز نشد. دوباره امتحان کنید.';

  @override
  String get checkoutTitle => 'پرداخت با ارز دیجیتال';

  @override
  String get checkoutChooseNetwork =>
      'شبکه‌ای را که از آن واریز می‌کنید انتخاب کنید';

  @override
  String get checkoutContinue => 'ادامه';

  @override
  String get checkoutSendExactly => 'دقیقاً این مبلغ را بفرستید';

  @override
  String get checkoutNetwork => 'شبکه';

  @override
  String get checkoutAddress => 'به این آدرس';

  @override
  String get checkoutMemo => 'با این ممو';

  @override
  String get checkoutMemoWarning =>
      'حتماً این ممو را در انتقال وارد کنید، وگرنه نمی‌توانیم پرداخت را به شما نسبت بدهیم.';

  @override
  String get checkoutExactWarning =>
      'دقیقاً همین مبلغ را و فقط روی همین شبکه بفرستید. مبلغ یا شبکه‌ی دیگر ممکن است به دست ما نرسد.';

  @override
  String checkoutTimeLeft(String time) {
    return 'زمان باقی‌مانده: $time';
  }

  @override
  String get checkoutWaiting =>
      'منتظر پرداخت شما هستیم. این صفحه خودش به‌روز می‌شود.';

  @override
  String get checkoutPaidTitle => 'پرداخت دریافت شد';

  @override
  String get checkoutPaidKeyOnly =>
      'کلید شما آماده است. آن را در گوشی‌ای وارد کنید که قرار است پریمیوم بگیرد.';

  @override
  String get checkoutDone => 'تمام';

  @override
  String get checkoutExpired =>
      'مهلت این سفارش تمام شده است. اگر پرداخت کرده‌اید، با پشتیبانی تماس بگیرید.';

  @override
  String get checkoutUnderpaid =>
      'مبلغی که رسید کمتر از مبلغ کامل است. با پشتیبانی تماس بگیرید و این شماره سفارش را به آن‌ها بدهید:';

  @override
  String get checkoutCanceled => 'این سفارش لغو شد.';

  @override
  String get checkoutStartAgain => 'شروع دوباره';

  @override
  String get checkoutUnavailable => 'پرداخت با ارز دیجیتال الان در دسترس نیست.';

  @override
  String get checkoutTooManyOpen =>
      'سفارش‌های پرداخت‌نشده‌ی زیادی دارید. یکی از آن‌ها را پرداخت کنید یا صبر کنید تا مهلتشان تمام شود.';

  @override
  String get checkoutUnknownPlan =>
      'این طرح دیگر فروخته نمی‌شود. برگردید و طرح دیگری انتخاب کنید.';

  @override
  String get checkoutFailed =>
      'پرداخت شروع نشد. اتصالتان را بررسی کنید و دوباره امتحان کنید.';

  @override
  String get redeemTitle => 'وارد کردن کد';

  @override
  String get redeemSubtitle => 'کلید پریمیوم یا کد هدیه';

  @override
  String get redeemHint => 'کد';

  @override
  String get redeemApply => 'اعمال';

  @override
  String get redeemCancel => 'انصراف';

  @override
  String get redeemInvalid =>
      'این شبیه کد نیست. آن را بررسی کنید و دوباره امتحان کنید.';

  @override
  String get redeemUnknown =>
      'این کد را نمی‌شناسیم. آن را بررسی کنید و دوباره امتحان کنید.';

  @override
  String get redeemExpired => 'اعتبار این کد تمام شده است.';

  @override
  String get redeemRevoked => 'این کد دیگر معتبر نیست.';

  @override
  String get redeemMovedTooOften =>
      'این کلید اخیراً بیش از حد بین گوشی‌ها جابه‌جا شده است. کمی بعد دوباره امتحان کنید.';

  @override
  String get redeemExhausted => 'ظرفیت استفاده از این کد تمام شده است.';

  @override
  String get redeemAlreadyUsed => 'این گوشی قبلاً از این کد استفاده کرده است.';

  @override
  String get redeemUnmetered =>
      'این گوشی همین حالا حجم نامحدود دارد و به این کد نیازی ندارد.';

  @override
  String get redeemRateLimited =>
      'تعداد تلاش‌ها زیاد بود. کمی صبر کنید و دوباره امتحان کنید.';

  @override
  String get redeemUnavailable =>
      'این امکان الان در دسترس نیست. کمی بعد دوباره امتحان کنید.';

  @override
  String get redeemNetwork =>
      'ارتباط با سرور برقرار نشد. اتصالتان را بررسی کنید و دوباره امتحان کنید.';

  @override
  String get redeemFailed =>
      'این کد کار نکرد. آن را بررسی کنید و دوباره امتحان کنید.';

  @override
  String get redeemMoved => 'پریمیوم به این گوشی منتقل شد.';

  @override
  String redeemPromo(String amount) {
    return 'کد پذیرفته شد. $amount حجم اضافه به شما داده شد.';
  }

  @override
  String get redeemPromoNoAmount => 'کد پذیرفته شد. حجم اضافه به شما داده شد.';

  @override
  String get tvScanTitle => 'با گوشی باز کنید';

  @override
  String get tvScanBody => 'دوربین گوشی‌تان را روی این کد بگیرید.';

  @override
  String get refresh => 'تازه‌سازی';

  @override
  String get premiumNotNow => 'الان نه';

  @override
  String get premiumLimitSheetTitle => 'حجم امروزتان تمام شد';

  @override
  String get premiumLimitWait => 'صبر کنید تا ریست شود';

  @override
  String get premiumLimitInvite => 'دوستانتان را دعوت کنید و حجم بیشتری بگیرید';

  @override
  String get premiumNoDailyLimit => 'پریمیوم سقف روزانه ندارد.';

  @override
  String get premiumCalmTitle => 'می‌خواهید سقف روزانه نداشته باشید؟';

  @override
  String get premiumCalmBody =>
      'با پریمیوم حجم شما نامحدود می‌شود. طرح رایگانتان همان‌طور که هست می‌ماند.';

  @override
  String get premiumNextStepTitle => 'قدم بعدی: پریمیوم';

  @override
  String get premiumNextStepBody =>
      'شما همین حالا بیشترین حجم رایگان را دارید. پریمیوم سقف روزانه ندارد.';

  @override
  String get premiumLockedTag => 'پریمیوم';

  @override
  String premiumLockedTitle(String place) {
    return '$place را با پریمیوم باز کنید';
  }

  @override
  String get premiumLockedBody =>
      'این موقعیت مخصوص پریمیوم است. سرورهای رایگان شما تغییری نمی‌کنند.';

  @override
  String get premiumHeadlineLimit => 'بدون سقف روزانه';

  @override
  String premiumHeadlineLocked(String place) {
    return '$place را با پریمیوم باز کنید';
  }

  @override
  String get premiumFreeStays => 'طرح رایگان بدون پریمیوم هم کار می‌کند.';

  @override
  String premiumEndsOn(String date) {
    return 'پریمیوم شما $date تمام می‌شود';
  }

  @override
  String get premiumRenewBody =>
      'برای اینکه حجم نامحدود ادامه داشته باشد، تمدید کنید. مدت تمدید به تاریخ پایان فعلی اضافه می‌شود.';

  @override
  String premiumEndedOn(String date) {
    return 'پریمیوم شما $date تمام شد. طرح رایگانتان برگشت.';
  }

  @override
  String get premiumRenew => 'تمدید';

  @override
  String get noticeChannelName => 'پیام‌های Fortiva';

  @override
  String get noticeChannelDescription => 'خبرها و پیام‌های تیم Fortiva';

  @override
  String get noticesSettingTitle => 'اعلان‌ها';

  @override
  String get noticesSettingOn =>
      'روشن. پیام‌های تیم Fortiva حتی وقتی برنامه بسته است می‌تواند به شما برسد.';

  @override
  String get noticesSettingOff =>
      'خاموش. روشنش کنید تا پیام‌های تیم Fortiva حتی وقتی برنامه بسته است به شما برسد.';

  @override
  String get noticesOffCard =>
      'اعلان‌ها را روشن کنید تا پیام‌های تیم Fortiva حتی وقتی برنامه بسته است به شما برسد.';

  @override
  String get noticesTurnOn => 'روشن کردن';

  @override
  String get backgroundCard =>
      'ممکن است وقتی برنامه بسته است، گوشی شما جلوی رسیدن پیام‌های تیم Fortiva را بگیرد. اجازه دهید Fortiva در پس‌زمینه کار کند تا پیام‌ها به شما برسد.';

  @override
  String get backgroundHint =>
      'در صفحه بعد، Fortiva را انتخاب کنید (اگر در فهرست نیست، همه برنامه‌ها را نشان دهید). سپس مصرف باتری آن را روی «نامحدود» بگذارید یا اجازه دهید خودکار اجرا شود و در پس‌زمینه کار کند.';

  @override
  String get backgroundAllow => 'اجازه دادن';

  @override
  String get backgroundNotNow => 'الان نه';

  @override
  String get backgroundSettingTitle => 'پیام‌ها وقتی برنامه بسته است';

  @override
  String get backgroundSettingSubtitle =>
      'اجازه دهید Fortiva در پس‌زمینه کار کند تا پیام‌ها وقتی برنامه بسته است هم به شما برسد.';

  @override
  String get backgroundCardData =>
      'ممکن است «صرفه‌جویی داده» در گوشی شما وقتی برنامه بسته است جلوی رسیدن پیام‌های تیم Fortiva را بگیرد.';

  @override
  String get backgroundHintData => 'در صفحه بعد، «داده نامحدود» را روشن کنید.';

  @override
  String get apnGuideTitle => 'اتصال پایدارتر با این سیم‌کارت';

  @override
  String get apnGuideBody =>
      'گوشی شما روی این سیم‌کارت از IPv6 استفاده نمی‌کند. اگر روشنش کنید، فورتیوا بهتر وصل می‌ماند.';

  @override
  String get apnGuideShowMe => 'روشش را نشانم بده';

  @override
  String get apnGuideNotNow => 'الان نه';

  @override
  String get apnGuideSheetTitle => 'روشن کردن IPv6 برای این سیم‌کارت';

  @override
  String apnGuideStepOpen(String button) {
    return 'روی «$button» بزنید (یا بروید به تنظیمات > اتصالات > شبکه‌های تلفن همراه > نام‌های نقطه دسترسی).';
  }

  @override
  String apnGuideStepAccessPoint(String apn) {
    return 'روی نقطه دسترسی فعال ($apn) بزنید.';
  }

  @override
  String get apnGuideStepAccessPointAny => 'روی نقطه دسترسی فعال بزنید.';

  @override
  String get apnGuideStepProtocol =>
      'روی «پروتکل APN» بزنید و «IPv4/IPv6» را انتخاب کنید.';

  @override
  String get apnGuideStepSave =>
      'ذخیره کنید (در سامسونگ: منوی سه‌نقطه و بعد «ذخیره»).';

  @override
  String get apnGuideStepRestart =>
      'داده تلفن همراه را خاموش و دوباره روشن کنید.';

  @override
  String get apnGuideUndo =>
      'اگر داده تلفن همراه کار نکرد، «پروتکل APN» را به IPv4 برگردانید.';

  @override
  String get apnGuideOpenSettings => 'باز کردن تنظیمات APN';

  @override
  String get homeStallSearching =>
      'اتصال دیگر کار نمی‌کرد. در حال یافتن مسیر دیگری.';

  @override
  String get homeStalled => 'وصل است، اما داده‌ای رد و بدل نمی‌شود';

  @override
  String get peerShareTitle => 'کمک به اتصال دوست';

  @override
  String get peerShareSubtitle =>
      'چیزی را که Fortiva لازم دارد به گوشی دوستتان برسانید';

  @override
  String get peerShareBody =>
      'اگر Fortiva دوستتان وصل نمی‌شود، گوشی او می‌تواند چیزی را که لازم دارد از گوشی شما بگیرد. این کار بدون اینترنت هم انجام می‌شود.';

  @override
  String peerShareSteps(String action) {
    return 'روی گوشی دوستتان، «تنظیمات» را در خود Fortiva باز کنید و روی «$action» بزنید. بعد این کدها را یکی‌یکی به او نشان دهید یا برایش بفرستید.';
  }

  @override
  String get peerShareLoading => 'در حال دریافت تازه‌ترین نسخه';

  @override
  String get peerShareNothing =>
      'این گوشی فعلاً چیز تازه‌ای برای دادن به دوستتان ندارد. کمی بعد دوباره امتحان کنید.';

  @override
  String peerShareCodeOf(int current, int total) {
    return 'کد $current از $total';
  }

  @override
  String get peerSharePrevious => 'قبلی';

  @override
  String get peerShareNext => 'بعدی';

  @override
  String get peerShareCopy => 'کپی';

  @override
  String get peerShareSend => 'ارسال';

  @override
  String get peerShareCopied =>
      'کپی شد. آن را در پیامی برای دوستتان جای‌گذاری کنید.';

  @override
  String get peerReceiveTitle => 'کمک گرفتن از دوست';

  @override
  String get peerReceiveSubtitle => 'وقتی هیچ راه دیگری وصل نمی‌شود';

  @override
  String peerReceiveBody(String action) {
    return 'از دوستی که Fortiva روی گوشی‌اش وصل می‌شود بخواهید «تنظیمات» را در خود Fortiva باز کند و روی «$action» بزند. بعد با یکی از این روش‌ها آن را از گوشی او بگیرید.';
  }

  @override
  String get peerReceivePhotograph => 'عکس گرفتن از کدهای دوستتان';

  @override
  String get peerReceivePhotographNext => 'عکس گرفتن از کد بعدی';

  @override
  String peerReceiveProgress(int have, int total) {
    return 'تا الان $have از $total کد خوانده شده است';
  }

  @override
  String get peerReceiveFile => 'باز کردن فایلی که دوستتان فرستاده';

  @override
  String get peerReceivePaste => 'جای‌گذاری متنی که دوستتان فرستاده';

  @override
  String get peerReceiveNoCode =>
      'در این عکس کدی پیدا نشد. گوشی را نزدیک‌تر بگیرید تا کل کد در کادر باشد.';

  @override
  String get peerReceiveRefused =>
      'این برای Fortiva قابل استفاده نیست. از دوستتان بخواهید دوباره آن را بفرستد.';

  @override
  String get peerReceiveNotNewer =>
      'این را از قبل دارید، یا نسخه جدیدتری از آن را. دوباره برای اتصال تلاش کنید، یا از دوست دیگری کمک بگیرید.';

  @override
  String get peerReceiveTaken => 'انجام شد. برای اتصال روی دکمه ضربه بزنید.';

  @override
  String get peerReceiveUnavailable =>
      'این کار روی این گوشی ممکن نیست. راه دیگری را امتحان کنید.';

  @override
  String get peerReceiveNothingToPaste =>
      'هنوز چیزی کپی نشده است. متنی را که دوستتان فرستاده کپی کنید، بعد دوباره اینجا ضربه بزنید.';

  @override
  String get peerOfferBody =>
      'هنوز وصل نمی‌شوید؟ دوستی که Fortiva روی گوشی‌اش کار می‌کند می‌تواند از گوشی خودش کمکتان کند.';

  @override
  String get peerReceiveAgain =>
      'این کد قبلاً خوانده شده است. از دوستتان بخواهید کد بعدی را نشانتان دهد.';

  @override
  String get peerReceivePasteNotOurs =>
      'متنی که کپی کرده‌اید از Fortiva نیست. کل پیام دوستتان را کپی کنید، بعد دوباره امتحان کنید.';

  @override
  String peerReceiveNoPhoto(String action) {
    return 'عکس از دوربین به Fortiva نرسید. با برنامه دوربین گوشی از کد عکس بگیرید، بعد روی «$action» بزنید.';
  }

  @override
  String get peerReceiveFileHint =>
      'اگر فایل را در پیام‌رسان گرفته‌اید، شاید لازم باشد اول آن را در پوشه دانلودها ذخیره کنید.';

  @override
  String get homeTryingBackup =>
      'هیچ مسیر دیگری وصل نشد. حالا یک شبکه جایگزین را امتحان می‌کنیم.';

  @override
  String get homeConnectedBackup => 'از طریق شبکه جایگزین وصل شد';

  @override
  String get backupNetwork => 'شبکه جایگزین';

  @override
  String get backupNetworkTitle => 'شبکه جایگزین';

  @override
  String get backupNetworkCaption =>
      'وقتی هیچ گزینه دیگری وصل نشود از این شبکه استفاده می‌شود. ممکن است از سرورهای ما کندتر باشد.';

  @override
  String get backupNetworkPlace => 'موقعیت به‌صورت خودکار انتخاب می‌شود';

  @override
  String get speedTestStart => 'شروع تست';

  @override
  String get speedTestAgain => 'تست دوباره';

  @override
  String get speedTestRunning => 'در حال تست';

  @override
  String get speedTestIdle => 'ببینید سرعت اتصالتان همین حالا چقدر است.';

  @override
  String get speedTestPhasePing => 'در حال بررسی زمان پاسخ';

  @override
  String get speedTestPhaseDownload => 'در حال اندازه‌گیری سرعت دانلود';

  @override
  String get speedTestPhaseUpload => 'در حال اندازه‌گیری سرعت آپلود';

  @override
  String get speedTestDone => 'تست تمام شد';

  @override
  String get speedTestFailed =>
      'تست کامل نشد. اینترنت گوشی را بررسی کنید و دوباره امتحان کنید.';

  @override
  String get speedTestUnit => 'مگابیت بر ثانیه';

  @override
  String get ipAddressLabel => 'آدرس آی‌پی';

  @override
  String get ipCopied => 'آدرس کپی شد';

  @override
  String get ipLocation => 'موقعیت';

  @override
  String get ipProvider => 'سرویس‌دهنده اینترنت';

  @override
  String get ipOrganization => 'سازمان';

  @override
  String get ipTimeZone => 'منطقه زمانی';

  @override
  String get ipCoordinates => 'مختصات';

  @override
  String get ipCheckFailed => 'بررسی آدرس شما انجام نشد';

  @override
  String get historyAverage => 'میانگین هر اتصال';

  @override
  String get historyRecentDays => 'روزهای اخیر';

  @override
  String yesterdayAt(String time) {
    return 'دیروز ساعت $time';
  }

  @override
  String dateAt(String date, String time) {
    return '$date ساعت $time';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds ثانیه';
  }

  @override
  String get stageOwn => 'سرورهای فورتیوا';

  @override
  String get stageCommunity => 'سرورهای عمومی';

  @override
  String stageProgress(int n, int total) {
    return 'مرحله $n از $total';
  }

  @override
  String get stageTryingOwn => 'در حال امتحان سرورهای فورتیوا';

  @override
  String get stageTryingCommunity => 'در حال امتحان سرورهای عمومی';

  @override
  String get stageOwnFailedTryingCommunity =>
      'سرورهای فورتیوا اینجا وصل نشدند. حالا سرورهای عمومی را امتحان می‌کنیم.';

  @override
  String stageLastWorked(String server) {
    return 'آخرین سروری که کار کرد: $server';
  }

  @override
  String stageTriedBlocked(int count) {
    return '$count مسیر امتحان شد، اینجا مسدود است';
  }

  @override
  String stageTriedFailed(int count) {
    return '$count مسیر امتحان شد، هیچ‌کدام وصل نشد';
  }

  @override
  String get stageNotConnected => 'وصل نشد';

  @override
  String get stageConnected => 'اینجا وصل شد';

  @override
  String get stageSkipped => 'این بار امتحان نشد';

  @override
  String stageMoreToCheck(int count) {
    return '$count مسیر دیگر در نوبت بررسی';
  }

  @override
  String stageNextTry(String stage, String time) {
    return 'تلاش بعدی $time دیگر با $stage شروع می‌شود';
  }

  @override
  String get searchSlowHint =>
      'این کار ممکن است یکی دو دقیقه طول بکشد. برای توقف جستجو، دکمه را بزنید.';

  @override
  String get searchStopped => 'جستجو متوقف شد';

  @override
  String get homeConnectedCommunity => 'از طریق سرور عمومی وصل شد';

  @override
  String get stageGettingServers => 'در حال گرفتن سرورهای شما';

  @override
  String stageNextTryStarting(String stage) {
    return 'تلاش بعدی همین حالا با $stage شروع می‌شود';
  }
}
