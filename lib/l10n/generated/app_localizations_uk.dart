// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class SUk extends S {
  SUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Fortiva';

  @override
  String get statusDisconnected => 'Не підключено';

  @override
  String get statusConnecting => 'Підключення';

  @override
  String get statusConnected => 'Підключено';

  @override
  String get statusDisconnecting => 'Завершення...';

  @override
  String get statusError => 'Помилка';

  @override
  String get statusVerifying => 'Перевірка...';

  @override
  String get disconnect => 'Завершити';

  @override
  String get connectBtn => 'Підключити';

  @override
  String get disconnectBtn => 'Відключити';

  @override
  String get pleaseWait => 'ЗАЧЕКАЙТЕ';

  @override
  String get locationLabel => 'Локація';

  @override
  String get selectServer => 'Виберіть локацію';

  @override
  String get serverLocation => 'Локація';

  @override
  String get searchServers => 'Пошук серверів';

  @override
  String get locationsTitle => 'Локації';

  @override
  String get sortLatency => 'Сортування: затримка';

  @override
  String get sortAZ => 'Сортування: А-Я';

  @override
  String get sortedByLatency => 'Відсортовано за затримкою';

  @override
  String get sortedAZ => 'Відсортовано від А до Я';

  @override
  String get pingAll => 'Перевірити всі';

  @override
  String get pinging => 'Перевіряємо...';

  @override
  String get ping => 'Пінг';

  @override
  String get stop => 'Зупинити';

  @override
  String get fastestServer => 'Найшвидший';

  @override
  String get timeout => 'тайм-аут';

  @override
  String get tabCommunity => 'Спільнота';

  @override
  String get tabFree => 'Безкоштовні';

  @override
  String get tabPremium => 'Преміум';

  @override
  String get noCommunityServers => 'Серверів спільноти поки немає';

  @override
  String get communityLoadFailed => 'Не вдалося завантажити цей список';

  @override
  String get communityRetry => 'Спробувати ще раз';

  @override
  String get officialTabExplainer =>
      'Ними керує Fortiva, і ми підтримуємо їх онлайн. Спільні для всіх, хто користується застосунком. Почніть звідси.';

  @override
  String get communityTabExplainer =>
      'Додаткові варіанти підключення. Швидкість і доступність можуть відрізнятися.';

  @override
  String get noFreeServers => 'Безкоштовних серверів поки немає';

  @override
  String get noPremiumServers => 'Преміум-серверів поки немає';

  @override
  String noResultsFor(String query) {
    return 'Нічого не знайдено за запитом «$query»';
  }

  @override
  String get proBadge => 'ПРЕМІУМ';

  @override
  String get freeBadge => 'БЕЗКОШТОВНО';

  @override
  String get settings => 'Налаштування';

  @override
  String get connection => 'Мережа';

  @override
  String get dnsConfiguration => 'DNS';

  @override
  String get customDns => 'Використовувати власні DNS-сервери';

  @override
  String get about => 'Про застосунок';

  @override
  String get privacyPolicy => 'Політика конфіденційності';

  @override
  String get contactUs => 'Зв\'язатися з нами';

  @override
  String get rateOnGooglePlay => 'Оцінити Fortiva в Google Play';

  @override
  String get website => 'Вебсайт';

  @override
  String get copyright => '© 2026 NimusAI';

  @override
  String get version => 'Версія';

  @override
  String get language => 'Мова';

  @override
  String get languageSubtitle => 'Мова інтерфейсу';

  @override
  String get whatIsDns => 'Що таке DNS?';

  @override
  String get dnsExplanation =>
      'DNS перетворює назви сайтів на адреси, до яких може звернутися ваш телефон. Інший DNS може пришвидшити завантаження сайтів і допомогти відкрити сайти, які блокує ваш провайдер.';

  @override
  String get configuration => 'Налаштування';

  @override
  String get primaryDns => 'Основний DNS';

  @override
  String get primaryDnsHint => 'За замовчуванням: 1.1.1.1';

  @override
  String get secondaryDns => 'Додатковий DNS (необов\'язково)';

  @override
  String get secondaryDnsHint => 'За замовчуванням: 8.8.8.8';

  @override
  String get saveConfiguration => 'Зберегти';

  @override
  String get dnsSaved => 'Налаштування DNS збережено';

  @override
  String get invalidPrimaryDns => 'Адреса основного DNS недійсна';

  @override
  String get invalidSecondaryDns => 'Адреса додаткового DNS недійсна';

  @override
  String get statistics => 'Історія';

  @override
  String get overview => 'ОГЛЯД';

  @override
  String get connectionsLabel => 'Сеанси';

  @override
  String get totalTime => 'Час підключення';

  @override
  String get dataUsage => 'Використано трафіку';

  @override
  String get uploaded => 'Вивантажено';

  @override
  String get downloaded => 'Завантажено';

  @override
  String get total => 'Усього';

  @override
  String lastUpdated(String date) {
    return 'Останнє оновлення: $date';
  }

  @override
  String today(String time) {
    return 'Сьогодні о $time';
  }

  @override
  String get yesterday => 'Вчора';

  @override
  String daysAgo(int count) {
    return '$count дн. тому';
  }

  @override
  String get noDataYet => 'Даних про сеанси немає';

  @override
  String get connectToStart => 'Підключіться, щоб почати відстеження';

  @override
  String get errorConnectionFailed => 'Не вдалося підключитися';

  @override
  String get errorServerNotWorking => 'Ця локація не працює. Спробуйте іншу.';

  @override
  String get errorServerNotForwarding =>
      'Ця локація не пропускає трафік. Спробуйте іншу.';

  @override
  String get errorUnexpected => 'Неочікувана помилка';

  @override
  String get errorDisconnectionFailed => 'Не вдалося відключитися';

  @override
  String get errorFailedToRegister => 'Не вдалося зареєструвати пристрій';

  @override
  String get ipInformation => 'Перевірити мою IP-адресу';

  @override
  String get connectionAnalytics => 'Історія';

  @override
  String get recentSessions => 'Останні підключення';

  @override
  String get speedTest => 'Тест швидкості';

  @override
  String get startTest => 'ЗАПУСТИТИ ДІАГНОСТИКУ';

  @override
  String get download => 'Завантаження';

  @override
  String get upload => 'Вивантаження';

  @override
  String get testingViaVpn => 'Перевірка через тунель';

  @override
  String get testingDirect => 'Перевірка прямого з\'єднання';

  @override
  String get splitTunneling => 'Налаштування маршрутів';

  @override
  String get splitTunnelingDescription =>
      'Виберіть, які категорії застосунків оминають тунель. Виключені застосунки використовують ваше пряме мережеве з\'єднання.';

  @override
  String get enableSplitTunneling => 'Увімкнути розділення маршрутів';

  @override
  String get splitTunnelActive => 'Вибрані застосунки оминають тунель';

  @override
  String get splitTunnelInactive => 'Увесь трафік іде через тунель';

  @override
  String get bypassVpnFor => 'Оминати тунель для';

  @override
  String get tools => 'Діагностика';

  @override
  String get settingsGeneral => 'Загальні';

  @override
  String get shareDiagnosticsTitle => 'Надсилати діагностику підключення';

  @override
  String get shareDiagnosticsBody =>
      'Надсилаються звіти про підключення, оператор і країна, модель телефону та версія Android, назви сайтів, які ви відкриваєте через VPN, із кількістю за день, а також те, чи бачили ви наші повідомлення, пропозиції Преміуму й картку запрошення та чи натискали на них. Ми ніколи не бачимо сторінок, які ви відкриваєте, і того, що ви надсилаєте.';

  @override
  String get security => 'Відповідність';

  @override
  String get privacyDashboard => 'Аналіз кінцевої точки';

  @override
  String get privacyDashboardSubtitle => 'Прозорість IP і контроль витоків';

  @override
  String get connectionAnalyticsSubtitle => 'Історія сеансів і звіти';

  @override
  String get speedTestSubtitle => 'Вимірювання пропускної здатності';

  @override
  String get splitTunnelingSubtitle => 'Налаштувати правила маршрутизації';

  @override
  String get splashTagline => 'Приватний доступ, де б ви не були';

  @override
  String get openSourceLicence => 'Ліцензія відкритого коду';

  @override
  String get sourceOfferTitle => 'Ліцензія відкритого коду';

  @override
  String get sourceOfferBody =>
      'Fortiva VPN є вільним програмним забезпеченням за ліцензією GNU General Public License v3. Застосунок побудовано на Xray-core та інших проєктах з відкритим кодом.\n\nВи маєте право отримати повний вихідний код встановленої у вас версії. Щоб запросити його, напишіть на admin@fortivavpn.com і вкажіть версію застосунку. Ця пропозиція діє три роки з дати, коли ви отримали цю версію.';

  @override
  String get close => 'Закрити';

  @override
  String get account => 'Обліковий запис';

  @override
  String get deleteAccount => 'Видалити обліковий запис';

  @override
  String get deleteAccountSubtitle =>
      'Назавжди видалити цей пристрій і ваші дані';

  @override
  String get deleteAccountConfirmTitle => 'Видалити ваш обліковий запис?';

  @override
  String get deleteAccountConfirmBody =>
      'Це видалить реєстрацію вашого пристрою, прив\'язаний обліковий запис Google, персональні сервери, створені для вас, і ваші повідомлення в чаті підтримки. Історію підключень на цьому телефоні теж буде стерто.\n\nЦю дію не можна скасувати. Ви можете почати заново в будь-який момент, просто знову відкривши застосунок.';

  @override
  String deleteAccountConfirmRetention(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня',
      many: '$days днів',
      few: '$days днів',
      one: '$days дня',
    );
    return 'Ваш обліковий запис видаляється одразу. Копії в резервних копіях і анонімних журналах серверів очищаються протягом $_temp0.';
  }

  @override
  String get deleteAccountConfirmRetentionNoDays =>
      'Ваш обліковий запис видаляється одразу. Копії в резервних копіях і анонімних журналах серверів очищаються пізніше, у строки, вказані в нашій політиці конфіденційності.';

  @override
  String get deleteAccountCancel => 'Залишити обліковий запис';

  @override
  String get deleteAccountConfirm => 'Видалити';

  @override
  String get deleteAccountInProgress => 'Видаляємо ваш обліковий запис';

  @override
  String get deleteAccountDone => 'Ваш обліковий запис видалено.';

  @override
  String get deleteAccountFailed =>
      'Не вдалося видалити обліковий запис. Перевірте з\'єднання і спробуйте ще раз.';

  @override
  String get homeTapToConnect => 'Натисніть, щоб підключитися';

  @override
  String get homeChecking => 'Перевірка з\'єднання';

  @override
  String get homePreparing => 'Налаштовуємо ваш сервер';

  @override
  String get homeDisconnecting => 'Відключення';

  @override
  String get homeFindingPath => 'Шукаємо шлях';

  @override
  String get diagCheckingInternet => 'Перевіряємо ваш інтернет';

  @override
  String get diagInternationalCut =>
      'Міжнародний інтернет у цій мережі відключено';

  @override
  String diagPathRow(String city, int n) {
    return '$city, шлях $n';
  }

  @override
  String get diagOpen => 'відкрито';

  @override
  String get diagBlocked => 'заблоковано';

  @override
  String get diagSkipped => 'сьогодні пропущено';

  @override
  String diagConnectingThrough(String city) {
    return 'Підключення через $city';
  }

  @override
  String get diagVerifying => 'Перевірка трафіку';

  @override
  String get diagNoInternet => 'Зараз на вашому телефоні немає інтернету.';

  @override
  String get diagCutOff =>
      'Ваша мережа зараз не має виходу в міжнародний інтернет. Натисніть, щоб спробувати ще раз.';

  @override
  String get diagNothingOpen =>
      'Зараз усі шляхи заблоковано. Натисніть, щоб спробувати ще раз.';

  @override
  String get homeTryingAgain =>
      'Зараз усі шляхи заблоковано. Незабаром спробуємо ще раз.';

  @override
  String get homeCutOffTryingAgain =>
      'Ваша мережа зараз не має виходу в міжнародний інтернет. Незабаром спробуємо ще раз.';

  @override
  String get homeOfflineTryingAgain =>
      'Зараз на вашому телефоні немає інтернету. Незабаром спробуємо ще раз.';

  @override
  String get diagPathFailed =>
      'Шлях був відкритий, але тунель не запустився. Натисніть, щоб спробувати ще раз.';

  @override
  String get openVpnSettings => 'Відкрити налаштування VPN';

  @override
  String get yourServer => 'ВАШ СЕРВЕР';

  @override
  String get yourServerCaption =>
      'Лише ваш. Ніхто інший через нього не підключається.';

  @override
  String get ourServer => 'НАШ СЕРВЕР';

  @override
  String get ourServerCaption =>
      'Ним керує Fortiva, і він спільний для всіх. Використовується, поки не буде готовий ваш власний сервер.';

  @override
  String get communityServer => 'СЕРВЕР СПІЛЬНОТИ';

  @override
  String get communityServerCaption =>
      'Додатковий варіант підключення. Може перестати працювати будь-якої миті.';

  @override
  String communityServerNumber(String n) {
    return 'Сервер спільноти $n';
  }

  @override
  String get myServersTitle => 'Ваші сервери';

  @override
  String get myServersExplainer =>
      'Кожен пристрій Fortiva отримує власний сервер у кожній локації з даними доступу, які належать лише цьому встановленню. Обліковий запис не потрібен.';

  @override
  String get myServersInUse => 'Використовується';

  @override
  String get myServersEmpty => 'Сервери ще не призначено';

  @override
  String get myServersRetry => 'Спробувати ще раз';

  @override
  String get myServersBlockedTitle => 'Ви використали денний трафік';

  @override
  String get myServersBlockedWait =>
      'Ваш денний ліміт оновлюється автоматично. Загляньте пізніше.';

  @override
  String myServersMoved(String place) {
    return 'Тепер використовується $place';
  }

  @override
  String get copyLink => 'Копіювати посилання';

  @override
  String get linkCopied => 'Посилання скопійовано';

  @override
  String quotaUsedToday(String used, String limit) {
    return 'Сьогодні використано $used з $limit';
  }

  @override
  String get quotaUsedUp => 'Денний трафік вичерпано';

  @override
  String get quotaUnlimited => 'Безлімітний трафік';

  @override
  String get quotaDaily => 'Денний трафік';

  @override
  String get quotaLimitReached => 'Денний ліміт досягнуто';

  @override
  String quotaLeftOf(String left, String limit) {
    return 'Залишилося $left з $limit';
  }

  @override
  String get quotaResetsShortly => 'Скоро оновиться';

  @override
  String quotaResetsInHours(int hours) {
    return 'Оновиться через $hours год';
  }

  @override
  String quotaResetsInMinutes(int minutes) {
    return 'Оновиться через $minutes хв';
  }

  @override
  String get myServersSubtitle => 'Сервери, виділені для цього пристрою';

  @override
  String get sharedServersTitle => 'Спільні сервери';

  @override
  String get sharedServersSubtitle => 'Публічні локації, запасний варіант';

  @override
  String get tabOfficial => 'Наші сервери';

  @override
  String get noOfficialServers => 'Зараз немає серверів Fortiva';

  @override
  String get inviteTitle => 'Запросити друзів';

  @override
  String get inviteSubtitle => 'Отримуйте додатковий денний трафік';

  @override
  String get inviteYourCode => 'Ваш код запрошення';

  @override
  String get inviteShareAction => 'Поділитися запрошенням';

  @override
  String get inviteCopyAction => 'Копіювати код';

  @override
  String get inviteCodeCopied => 'Код скопійовано';

  @override
  String inviteShareMessage(String code, String url) {
    return 'Безкоштовний VPN, який у мене добре працює: Fortiva. Без реєстрації.\nВстанови за цим посиланням:\n$url\nМій код запрошення: $code';
  }

  @override
  String get inviteHowItWorks => 'Як це працює';

  @override
  String inviteHowItWorksBody(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days різних дня',
      many: '$days різних днів',
      few: '$days різні дні',
      one: '$days день',
    );
    return 'Поділіться своїм кодом. Коли хтось установить застосунок, введе код і користуватиметься VPN у $_temp0, до вашого денного трафіку додасться $amount. Це залишається у вашому обліковому записі.';
  }

  @override
  String inviteHowItWorksBodyNoAmount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days різних дня',
      many: '$days різних днів',
      few: '$days різні дні',
      one: '$days день',
    );
    return 'Поділіться своїм кодом. Коли хтось установить застосунок, введе код і користуватиметься VPN у $_temp0, ви отримуватимете більше трафіку щодня. Це залишається у вашому обліковому записі.';
  }

  @override
  String inviteHowItWorksBodyNoDays(String amount) {
    return 'Поділіться своїм кодом. Коли хтось установить застосунок, введе код і деякий час користуватиметься VPN, до вашого денного трафіку додасться $amount. Це залишається у вашому обліковому записі.';
  }

  @override
  String get inviteHowItWorksBodyNoAmountNoDays =>
      'Поділіться своїм кодом. Коли хтось установить застосунок, введе код і деякий час користуватиметься VPN, ви отримуватимете більше трафіку щодня. Це залишається у вашому обліковому записі.';

  @override
  String inviteHowItWorksCap(String max) {
    return 'За запрошення можна отримати до $max на день.';
  }

  @override
  String get inviteStatInvited => 'Запрошено';

  @override
  String get inviteStatEarning => 'Зараховано';

  @override
  String get inviteStatBonus => 'Бонусний трафік';

  @override
  String inviteBonusPerDay(String amount) {
    return '+$amount щодня';
  }

  @override
  String get inviteNoBonusYet => 'Бонусу поки немає';

  @override
  String invitePendingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count запрошення ще не зараховано',
      many: '$count запрошень ще не зараховано',
      few: '$count запрошення ще не зараховано',
      one: '$count запрошення ще не зараховано',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String inviteJoinedWith(String code) {
    return 'Ви приєдналися за кодом $code';
  }

  @override
  String get inviteLoadFailed => 'Не вдалося завантажити ваш код запрошення';

  @override
  String get inviteRetry => 'Спробувати ще раз';

  @override
  String get inviteHaveCodeTitle => 'Є код запрошення?';

  @override
  String inviteHaveCodeSubtitle(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Введіть його протягом $hours години після встановлення',
      many: 'Введіть його протягом $hours годин після встановлення',
      few: 'Введіть його протягом $hours годин після встановлення',
      one: 'Введіть його протягом $hours години після встановлення',
    );
    return '$_temp0';
  }

  @override
  String get inviteHaveCodeSubtitleNoHours =>
      'Введіть його незабаром після встановлення';

  @override
  String get inviteEnterCodeHint => 'Код запрошення';

  @override
  String get inviteApplyAction => 'Застосувати';

  @override
  String get inviteNotNowAction => 'Не зараз';

  @override
  String inviteClaimAccepted(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days різних дня',
      many: '$days різних днів',
      few: '$days різні дні',
      one: '$days день',
    );
    return 'Запрошення прийнято. Ваш друг отримає бонусний трафік після того, як ви скористаєтеся VPN у $_temp0.';
  }

  @override
  String get inviteClaimAcceptedNoDays =>
      'Запрошення прийнято. Ваш друг отримає бонусний трафік після того, як ви деякий час користуватиметеся VPN.';

  @override
  String get inviteClaimAlready => 'Цей пристрій уже використав код запрошення';

  @override
  String get inviteClaimRejected =>
      'Цей код не спрацював. Перевірте його і спробуйте ще раз';

  @override
  String get inviteClaimNetwork =>
      'Не вдалося зв\'язатися з сервером. Спробуйте ще раз';

  @override
  String get inviteCardTitle => 'Fortiva добре у тебе працює? Надішли другові';

  @override
  String get inviteCardBody =>
      'Надішли другові посилання на встановлення, щоб і він міг безкоштовно підключатися.';

  @override
  String inviteCardReward(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Коли твій друг почне користуватися Fortiva, ти отримаєш $days дня Преміуму.',
      many:
          'Коли твій друг почне користуватися Fortiva, ти отримаєш $days днів Преміуму.',
      few:
          'Коли твій друг почне користуватися Fortiva, ти отримаєш $days дні Преміуму.',
      one:
          'Коли твій друг почне користуватися Fortiva, ти отримаєш $days день Преміуму.',
    );
    return '$_temp0';
  }

  @override
  String get inviteCardRewardNoAmount =>
      'Коли твій друг почне користуватися Fortiva, ти отримаєш Преміум у подарунок.';

  @override
  String get inviteSendTelegram => 'Telegram';

  @override
  String get inviteSendWhatsApp => 'WhatsApp';

  @override
  String get inviteCopyLink => 'Копіювати посилання';

  @override
  String get inviteOtherApps => 'Інші застосунки';

  @override
  String get inviteLinkCopied => 'Текст запрошення скопійовано';

  @override
  String get invitePasteBody =>
      'Скопіюйте код із повідомлення друга і вставте його сюди.';

  @override
  String get invitePasteAction => 'Вставити';

  @override
  String get inviteErrorTooLate =>
      'Час для введення коду запрошення на цьому телефоні минув.';

  @override
  String get inviteErrorUnknown =>
      'Ми не знайшли цей код. Скопіюйте його ще раз із повідомлення друга.';

  @override
  String get inviteErrorOwnCode => 'Це ваш власний код. Введіть код друга.';

  @override
  String get inviteErrorMutual =>
      'Ви з другом не можете запросити одне одного.';

  @override
  String inviteHowItWorksPremium(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Кожен друг, який почне користуватися Fortiva, також принесе вам $days дня Преміуму.',
      many:
          'Кожен друг, який почне користуватися Fortiva, також принесе вам $days днів Преміуму.',
      few:
          'Кожен друг, який почне користуватися Fortiva, також принесе вам $days дні Преміуму.',
      one:
          'Кожен друг, який почне користуватися Fortiva, також принесе вам $days день Преміуму.',
    );
    return '$_temp0';
  }

  @override
  String inviteHowItWorksPremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'За запрошення можна отримати до $max дня Преміуму.',
      many: 'За запрошення можна отримати до $max днів Преміуму.',
      few: 'За запрошення можна отримати до $max днів Преміуму.',
      one: 'За запрошення можна отримати до $max дня Преміуму.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeLive =>
      'Бонус діє, поки ваші друзі користуються Fortiva. Якщо друг перестане, бонус зменшиться.';

  @override
  String inviteTreeNext(String amount) {
    return 'Ваш наступний друг додасть $amount на день, коли почне користуватися Fortiva.';
  }

  @override
  String inviteTreeKept(String amount) {
    return 'Завдяки друзям, запрошеним раніше, ваш бонус не опуститься нижче $amount на день.';
  }

  @override
  String get inviteTreeSlotsTitle => 'Ваші місця';

  @override
  String get inviteTreeSlotActive => 'Активний';

  @override
  String get inviteTreeSlotNotActive => 'Зараз не активний';

  @override
  String get inviteTreeSlotEmpty => 'Вільне місце';

  @override
  String inviteTreePaysNow(String amount) {
    return '+$amount на день зараз';
  }

  @override
  String inviteTreePairFull(String amount) {
    return '+$amount на день, коли обидва активні';
  }

  @override
  String get inviteTreeNothingYet => 'Поки нічого';

  @override
  String get inviteTreeFriendsTitle => 'Через ваші місця';

  @override
  String get inviteTreeRowFriends => 'На ваших місцях';

  @override
  String get inviteTreeRowFriendsSlots => 'На їхніх місцях';

  @override
  String inviteTreeRowSteps(int steps) {
    String _temp0 = intl.Intl.pluralLogic(
      steps,
      locale: localeName,
      other: 'За $steps кроку від вас',
      many: 'За $steps кроків від вас',
      few: 'За $steps кроки від вас',
      one: 'За $steps крок від вас',
    );
    return '$_temp0';
  }

  @override
  String inviteTreeRowPeople(int people, int active) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people особи',
      many: '$people осіб',
      few: '$people особи',
      one: '$people особа',
    );
    return '$_temp0, активних: $active';
  }

  @override
  String inviteTreeHowSlots(int slots) {
    String _temp0 = intl.Intl.pluralLogic(
      slots,
      locale: localeName,
      other:
          'Поділіться своїм кодом. Ваші місця парами займуть перші $slots друга, чиї запрошення буде зараховано.',
      many:
          'Поділіться своїм кодом. Ваші місця парами займуть перші $slots друзів, чиї запрошення буде зараховано.',
      few:
          'Поділіться своїм кодом. Ваші місця парами займуть перші $slots друзі, чиї запрошення буде зараховано.',
      one:
          'Поділіться своїм кодом. Ваше місце займе перший друг, чиє запрошення буде зараховано.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeHowSlotsNoNumber =>
      'Поділіться своїм кодом. Ваші місця парами займуть перші друзі, чиї запрошення буде зараховано.';

  @override
  String get inviteTreeHowPair =>
      'Пара приносить більше, коли в ній обидва активні.';

  @override
  String get inviteTreeHowFriendsSlots =>
      'Коли ваші місця заповнені, ваші наступні друзі, чиї запрошення буде зараховано, займуть наступні вільні місця, далі від вас. Вони теж додають вам трафік, тим менше, чим далі вони від вас.';

  @override
  String get inviteTreeHowOthers =>
      'Вашу першу пару можуть зайняти й люди, яких ви не запрошували. Вони додають вам трафік так само.';

  @override
  String inviteTreeHowActive(int days, int window) {
    String _temp0 = intl.Intl.pluralLogic(
      window,
      locale: localeName,
      other: '$window дня',
      many: '$window днів',
      few: '$window дні',
      one: '$window день',
    );
    String _temp1 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня',
      many: '$days днів',
      few: '$days дні',
      one: '$days день',
    );
    return 'Друг вважається активним, якщо за останні $_temp0 він користувався Fortiva хоча б $_temp1.';
  }

  @override
  String get inviteTreeHowActiveNoNumber =>
      'Друг вважається активним, поки й далі користується Fortiva.';

  @override
  String inviteTreeHowCap(String max) {
    return 'Запрошення можуть додати до $max на день.';
  }

  @override
  String get inviteTreeHowCapNoAmount => 'Бонус за запрошення має денну межу.';

  @override
  String get premiumSourceInvite => 'За ваші запрошення';

  @override
  String quotaBonusIncluded(String amount) {
    return 'включно з бонусом $amount за запрошення';
  }

  @override
  String get updateTitle => 'Доступне оновлення';

  @override
  String get updateRequiredTitle => 'Потрібне оновлення';

  @override
  String updateBody(String version) {
    return 'Вийшла Fortiva $version. Оновіться, щоб отримати найновіші виправлення.';
  }

  @override
  String get updateRequiredBody =>
      'Ця версія більше не підтримується. Оновіться, щоб і далі користуватися Fortiva.';

  @override
  String get updateNow => 'Оновити';

  @override
  String get updateLater => 'Пізніше';

  @override
  String get updateFromPlay => 'Google Play';

  @override
  String get updateFromTelegram => 'Telegram-канал';

  @override
  String get updateConnect => 'Підключити';

  @override
  String get updateConnectHint =>
      'Якщо Google Play або Telegram не відкривається, спочатку натисніть «Підключити».';

  @override
  String get updateConnected => 'Ви підключені. Завантажте оновлення зараз.';

  @override
  String get updateReconnect => 'Не працює? Перепідключитися';

  @override
  String get updateDisconnect => 'Відключити';

  @override
  String get updateDisconnectHint =>
      'Натисніть «Відключити», щоб завантажити оновлення через звичайний інтернет.';

  @override
  String get updateNotCarrying =>
      'Ви підключені, але дані не проходять. Спробуйте перепідключитися або натисніть «Відключити», щоб користуватися звичайним інтернетом.';

  @override
  String get diagVerdictNoInternet =>
      'На вашому телефоні немає підключення до інтернету. Fortiva не зможе підключитися, поки воно не з\'явиться.';

  @override
  String get diagVerdictCutOff =>
      'Ваша мережа зараз не має виходу в міжнародний інтернет. Спробуйте ще раз за кілька хвилин.';

  @override
  String get diagVerdictNeedsPermission =>
      'Fortiva не має дозволу запускати VPN, або інший VPN-застосунок налаштовано як завжди ввімкнений.';

  @override
  String get diagVerdictServerUnreachable =>
      'Цей сервер недоступний з вашої мережі. Він або заблокований тут, або не працює.';

  @override
  String get diagVerdictBlockedTls =>
      'З\'єднання з цим сервером обривається під час установлення. Так виглядає фільтрація.';

  @override
  String get diagVerdictThrottled =>
      'Сервер відповів на всі перевірки, але тунель так нічого й не передав. З\'єднання сповільнюють.';

  @override
  String get diagCheckInternet => 'Перевірте інтернет';

  @override
  String diagTryServer(String server) {
    return 'Новий пошук: $server';
  }

  @override
  String get diagTryAnotherServer => 'Спробувати інший сервер';

  @override
  String get diagDetails => 'Подробиці';

  @override
  String get diagDetailsHide => 'Сховати подробиці';

  @override
  String privateDnsWarning(String host) {
    return 'Увімкнено приватний DNS ($host), тому деякі сайти можуть не відкриватися. Вимкніть приватний DNS у налаштуваннях телефона.';
  }

  @override
  String get openNetworkSettings => 'Відкрити налаштування мережі';

  @override
  String testPointStatus(String time, int open, int total) {
    return 'Тестова точка · остання перевірка $time · відкрито $open з $total';
  }

  @override
  String get messagesTooltip => 'Повідомлення';

  @override
  String get inboxTitle => 'Повідомлення';

  @override
  String get inboxEmpty => 'Зараз повідомлень немає.';

  @override
  String get messageClose => 'Закрити';

  @override
  String get supportTitle => 'Підтримка';

  @override
  String get supportTooltip => 'Чат з підтримкою';

  @override
  String get supportAskAction => 'Запитати підтримку';

  @override
  String get supportContactSubtitle => 'Напишіть нам у застосунку';

  @override
  String get supportAutomaticNotice =>
      'Відповіді пишуться автоматично і можуть бути помилковими.';

  @override
  String get supportStaffNotice =>
      'Автоматичні відповіді зараз вимкнено. Ваші повідомлення отримує наша команда.';

  @override
  String get supportInputHint => 'Напишіть своє запитання';

  @override
  String get supportInputHintTeam => 'Напишіть нашій команді';

  @override
  String get supportSend => 'Надіслати';

  @override
  String supportQuotaLeft(int remaining, int limit) {
    return 'Сьогодні залишилося запитань: $remaining з $limit';
  }

  @override
  String supportWaitIn(String time) {
    return 'Ви зможете запитати знову через $time.';
  }

  @override
  String supportDurationHours(int hours, int minutes) {
    return '$hours год $minutes хв';
  }

  @override
  String supportDurationMinutes(int minutes) {
    return '$minutes хв';
  }

  @override
  String get supportNewConversation => 'Нова розмова';

  @override
  String get supportSending => 'Надсилання';

  @override
  String get supportNotSent =>
      'Не надіслано. Натисніть, щоб спробувати ще раз.';

  @override
  String get supportRateUp => 'Корисно';

  @override
  String get supportRateDown => 'Не корисно';

  @override
  String get supportRatedDown =>
      'Дякуємо. Наша команда перегляне цю відповідь.';

  @override
  String get supportTeamLabel => 'Команда Fortiva';

  @override
  String get supportUnavailable => 'Чат зараз недоступний.';

  @override
  String get supportOpenTelegram => 'Напишіть нам у Telegram';

  @override
  String get supportGenericError => 'Щось пішло не так. Спробуйте ще раз.';

  @override
  String supportCodeTooLong(int max) {
    return 'Ваше повідомлення задовге. Вмістіть його в $max символів.';
  }

  @override
  String get supportCodeEmpty => 'Ваше повідомлення порожнє.';

  @override
  String get supportCodeWaitReply =>
      'Зачекайте на відповідь на ваше попереднє запитання.';

  @override
  String get supportCodeSlowDown =>
      'Ви надсилаєте повідомлення надто швидко. Зачекайте трохи.';

  @override
  String get supportCodeQuotaDay => 'Ви використали всі запитання на сьогодні.';

  @override
  String get supportCodePaused =>
      'Автоматичні відповіді тимчасово призупинено.';

  @override
  String get supportCodeBusy =>
      'Наш помічник зараз зайнятий. Спробуйте ще раз за кілька хвилин.';

  @override
  String get supportCodeGreeting => 'Вітаю! Чим можу допомогти з Fortiva?';

  @override
  String get supportCodeGibberish =>
      'Вибачте, я не зрозумів. Напишіть своє запитання ще раз.';

  @override
  String get supportCodeRedacted =>
      'Ми видалили з вашого повідомлення особисті дані та посилання.';

  @override
  String get supportCodeRedactedEmpty =>
      'У вашому повідомленні були лише особисті дані або посилання, тому його не надіслано. Опишіть проблему словами.';

  @override
  String get supportCodeOffTopic =>
      'Я можу допомогти лише з питаннями про користування Fortiva.';

  @override
  String get supportCodeAbuse =>
      'Будьмо ввічливими. Я тут, щоб допомогти вам із Fortiva.';

  @override
  String get supportCodeAiUnavailable =>
      'Цього разу помічник не зміг відповісти. Спробуйте трохи пізніше.';

  @override
  String get supportCodeToStaff =>
      'Надіслано нашій команді. Відповідь з\'явиться тут.';

  @override
  String get supportCodeTicketOpened =>
      'Ми передали ваше запитання нашій команді. Відповідь з\'явиться тут.';

  @override
  String get supportCodeNotSent =>
      'Це повідомлення не вдалося надіслати. Напишіть його ще раз, якщо вам усе ще потрібна допомога.';

  @override
  String get supportAssistantSubtitle => 'ШІ-помічник';

  @override
  String get supportThinkingReading => 'Читаю ваше запитання';

  @override
  String get supportThinkingSearching => 'Шукаю відповідь';

  @override
  String get supportThinkingWriting => 'Пишу відповідь';

  @override
  String get supportThinkingStill => 'Ще працюю, дякую за очікування';

  @override
  String get supportSuggestConnect => 'Не можу підключитися';

  @override
  String get supportSuggestData => 'Скільки трафіку в мене сьогодні?';

  @override
  String get supportSuggestSlow => 'У мене повільне з\'єднання';

  @override
  String get supportWithTeam => 'Цією розмовою тепер займається наша команда.';

  @override
  String get supportTryAgainSoon => 'Спробуйте ще раз за кілька хвилин.';

  @override
  String supportDurationWholeHours(int hours) {
    return '$hours год';
  }

  @override
  String get supportUnreadReply => 'Нова відповідь';

  @override
  String get premiumTitle => 'Преміум';

  @override
  String get premiumTileSubtitle => 'Безлімітний трафік без денного ліміту';

  @override
  String get premiumTileActive => 'Преміум увімкнено';

  @override
  String get premiumGetUnlimited => 'Отримати безліміт';

  @override
  String get premiumHeadline => 'Отримайте безлімітний трафік';

  @override
  String get premiumPitch =>
      'Преміум знімає денний ліміт, тож ви можете використовувати скільки завгодно трафіку, поки він діє.';

  @override
  String get premiumActiveTitle => 'Преміум увімкнено';

  @override
  String premiumActiveUntil(String date) {
    return 'Безлімітний трафік до $date';
  }

  @override
  String get premiumActiveNoDate => 'Безлімітний трафік';

  @override
  String get premiumRenews => 'Поновлюється автоматично через Google Play';

  @override
  String get premiumSourceKey => 'Активовано ключем';

  @override
  String get premiumSourceCrypto => 'Оплачено криптовалютою';

  @override
  String get premiumSourceStars => 'Оплачено через Telegram Stars';

  @override
  String get premiumSourceGooglePlay => 'Оплачено через Google Play';

  @override
  String get premiumSourceManual => 'Подарунок від команди Fortiva';

  @override
  String get premiumYourKey => 'Ваш ключ';

  @override
  String get premiumKeyHint =>
      'Збережіть цей ключ. Введіть його на іншому телефоні, щоб перенести туди Преміум.';

  @override
  String premiumKeyMoves(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'до $count разу',
      many: 'до $count разів',
      few: 'до $count разів',
      one: 'до $count разу',
    );
    String _temp1 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня',
      many: '$days днів',
      few: '$days днів',
      one: '$days дня',
    );
    return 'Ключ можна перенести на інший телефон $_temp0 протягом $_temp1.';
  }

  @override
  String get premiumKeyMovesNoNumber =>
      'Ключ можна перенести на інший телефон лише обмежену кількість разів.';

  @override
  String get premiumCopy => 'Копіювати';

  @override
  String get premiumCopied => 'Скопійовано';

  @override
  String get premiumChoosePlan => 'Виберіть план';

  @override
  String premiumPlanDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня безлімітного трафіку',
      many: '$days днів безлімітного трафіку',
      few: '$days дні безлімітного трафіку',
      one: '$days день безлімітного трафіку',
    );
    return '$_temp0';
  }

  @override
  String get premiumPlanNoDays => 'Безлімітний трафік';

  @override
  String get premiumBuy => 'Купити';

  @override
  String get premiumPlayUnavailable =>
      'Google Play зараз недоступний. Спробуйте пізніше.';

  @override
  String get premiumPlayPending =>
      'Ваш платіж очікує на обробку в Google Play. Преміум увімкнеться, щойно він пройде.';

  @override
  String get premiumPlayConfirming => 'Підтверджуємо покупку...';

  @override
  String get premiumPlayRetrying =>
      'Ваш платіж пройшов, але ми ще не змогли його підтвердити. Ми продовжимо спроби, тож платити знову не потрібно.';

  @override
  String get premiumPlayRefused =>
      'Нам не вдалося підтвердити цю покупку. Якщо з вас списали кошти, зверніться до підтримки.';

  @override
  String get premiumPlayNotAvailable =>
      'Преміум зараз недоступний на цьому телефоні. Якщо з вас списали кошти, зверніться до підтримки.';

  @override
  String get premiumNotAvailable =>
      'Преміум зараз недоступний на цьому телефоні.';

  @override
  String get premiumPlayFailed => 'Покупка не пройшла. Спробуйте ще раз.';

  @override
  String get premiumNowOn =>
      'Преміум увімкнено. Насолоджуйтеся безлімітним трафіком.';

  @override
  String get premiumRestore => 'Відновити покупки';

  @override
  String get premiumRestoreDone => 'Вашу покупку відновлено на цьому телефоні.';

  @override
  String get premiumRestoreNone =>
      'У цьому обліковому записі Google немає покупок для відновлення.';

  @override
  String get premiumRestoreFailed =>
      'Не вдалося відновити покупку. Спробуйте пізніше.';

  @override
  String premiumRenewsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Оплата списується раз на $count дня. Поновлюється автоматично, поки ви не скасуєте.',
      many:
          'Оплата списується раз на $count днів. Поновлюється автоматично, поки ви не скасуєте.',
      few:
          'Оплата списується раз на $count дні. Поновлюється автоматично, поки ви не скасуєте.',
      one:
          'Оплата списується щодня. Поновлюється автоматично, поки ви не скасуєте.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Оплата списується раз на $count тижня. Поновлюється автоматично, поки ви не скасуєте.',
      many:
          'Оплата списується раз на $count тижнів. Поновлюється автоматично, поки ви не скасуєте.',
      few:
          'Оплата списується раз на $count тижні. Поновлюється автоматично, поки ви не скасуєте.',
      one:
          'Оплата списується щотижня. Поновлюється автоматично, поки ви не скасуєте.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Оплата списується раз на $count місяця. Поновлюється автоматично, поки ви не скасуєте.',
      many:
          'Оплата списується раз на $count місяців. Поновлюється автоматично, поки ви не скасуєте.',
      few:
          'Оплата списується раз на $count місяці. Поновлюється автоматично, поки ви не скасуєте.',
      one:
          'Оплата списується щомісяця. Поновлюється автоматично, поки ви не скасуєте.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Оплата списується раз на $count року. Поновлюється автоматично, поки ви не скасуєте.',
      many:
          'Оплата списується раз на $count років. Поновлюється автоматично, поки ви не скасуєте.',
      few:
          'Оплата списується раз на $count роки. Поновлюється автоматично, поки ви не скасуєте.',
      one:
          'Оплата списується щороку. Поновлюється автоматично, поки ви не скасуєте.',
    );
    return '$_temp0';
  }

  @override
  String get premiumRenewsNoPeriod =>
      'Поновлюється автоматично, поки ви не скасуєте.';

  @override
  String get premiumPlayCancelNote =>
      'Скасувати можна будь-коли в Google Play. Преміум залишиться ввімкненим до кінця оплаченого періоду.';

  @override
  String get premiumManageSubscription => 'Керувати підпискою або скасувати її';

  @override
  String get premiumCurrentPlan => 'Поточний план';

  @override
  String get premiumPlaySubscribed =>
      'У вас уже є підписка Google Play. Керуйте нею або скасуйте її в Google Play.';

  @override
  String get premiumEnterCode => 'Ввести код';

  @override
  String get premiumNeedsPlayVersion =>
      'Щоб купити через Google Play, потрібна версія Fortiva з Google Play.';

  @override
  String get premiumOff => 'Преміум зараз не продається.';

  @override
  String get premiumLoadFailed =>
      'Не вдалося завантажити Преміум. Перевірте з\'єднання і спробуйте ще раз.';

  @override
  String get premiumRetry => 'Спробувати ще раз';

  @override
  String premiumPriceUsdt(String price) {
    return '$price USDT';
  }

  @override
  String premiumPriceStars(String stars) {
    return 'Telegram Stars: $stars';
  }

  @override
  String get premiumPayCrypto => 'Оплатити криптовалютою';

  @override
  String get premiumTelegramTitle => 'Оплата в Telegram';

  @override
  String get premiumTelegramBody =>
      'Оплатіть через Telegram Stars у нашому боті. Ви отримаєте ключ, і Преміум одразу ввімкнеться на цьому телефоні.';

  @override
  String get premiumTelegramButton => 'Купити в Telegram';

  @override
  String get premiumTelegramFailed =>
      'Не вдалося відкрити Telegram. Спробуйте ще раз.';

  @override
  String get checkoutTitle => 'Оплата криптовалютою';

  @override
  String get checkoutChooseNetwork =>
      'Виберіть мережу, з якої будете надсилати';

  @override
  String get checkoutContinue => 'Продовжити';

  @override
  String get checkoutSendExactly => 'Надішліть рівно';

  @override
  String get checkoutNetwork => 'Мережа';

  @override
  String get checkoutAddress => 'На цю адресу';

  @override
  String get checkoutMemo => 'З цим мемо';

  @override
  String get checkoutMemoWarning =>
      'Вкажіть це мемо в переказі, інакше ми не зможемо зіставити платіж з вами.';

  @override
  String get checkoutExactWarning =>
      'Надішліть точну суму і лише в цій мережі. Інша сума або мережа можуть до нас не дійти.';

  @override
  String checkoutTimeLeft(String time) {
    return 'Залишилося часу: $time';
  }

  @override
  String get checkoutWaiting =>
      'Очікуємо ваш платіж. Ця сторінка оновлюється сама.';

  @override
  String get checkoutPaidTitle => 'Платіж отримано';

  @override
  String get checkoutPaidKeyOnly =>
      'Ваш ключ готовий. Введіть його на телефоні, який має отримати Преміум.';

  @override
  String get checkoutDone => 'Готово';

  @override
  String get checkoutExpired =>
      'Термін цього замовлення минув. Якщо ви вже заплатили, зверніться до підтримки.';

  @override
  String get checkoutUnderpaid =>
      'Ми отримали менше за повну суму. Зверніться до підтримки і вкажіть цей номер замовлення:';

  @override
  String get checkoutCanceled => 'Це замовлення скасовано.';

  @override
  String get checkoutStartAgain => 'Почати заново';

  @override
  String get checkoutUnavailable => 'Оплата криптовалютою зараз недоступна.';

  @override
  String get checkoutTooManyOpen =>
      'У вас забагато неоплачених замовлень. Оплатіть одне з них або зачекайте, поки їхній термін мине.';

  @override
  String get checkoutUnknownPlan =>
      'Цей план більше не продається. Поверніться і виберіть інший.';

  @override
  String get checkoutFailed =>
      'Не вдалося почати оплату. Перевірте з\'єднання і спробуйте ще раз.';

  @override
  String get redeemTitle => 'Ввести код';

  @override
  String get redeemSubtitle => 'Ключ Преміум або подарунковий код';

  @override
  String get redeemHint => 'Код';

  @override
  String get redeemApply => 'Застосувати';

  @override
  String get redeemCancel => 'Скасувати';

  @override
  String get redeemInvalid =>
      'Це не схоже на код. Перевірте його і спробуйте ще раз.';

  @override
  String get redeemUnknown =>
      'Нам невідомий цей код. Перевірте його і спробуйте ще раз.';

  @override
  String get redeemExpired => 'Термін дії цього коду минув.';

  @override
  String get redeemRevoked => 'Цей код більше не дійсний.';

  @override
  String get redeemMovedTooOften =>
      'Цей ключ останнім часом надто часто переносили між телефонами. Спробуйте пізніше.';

  @override
  String get redeemExhausted => 'Цей код уже вичерпано.';

  @override
  String get redeemAlreadyUsed => 'Цей телефон уже використав цей код.';

  @override
  String get redeemUnmetered =>
      'На цьому телефоні вже безлімітний трафік, тож цей код йому не потрібен.';

  @override
  String get redeemRateLimited =>
      'Забагато спроб. Зачекайте трохи і спробуйте ще раз.';

  @override
  String get redeemUnavailable => 'Зараз це недоступно. Спробуйте пізніше.';

  @override
  String get redeemNetwork =>
      'Не вдалося зв\'язатися з сервером. Перевірте з\'єднання і спробуйте ще раз.';

  @override
  String get redeemFailed =>
      'Цей код не спрацював. Перевірте його і спробуйте ще раз.';

  @override
  String get redeemMoved => 'Преміум перенесено на цей телефон.';

  @override
  String redeemPromo(String amount) {
    return 'Код прийнято. Додано $amount додаткового трафіку.';
  }

  @override
  String get redeemPromoNoAmount => 'Код прийнято. Додатковий трафік додано.';

  @override
  String get tvScanTitle => 'Відкрийте на телефоні';

  @override
  String get tvScanBody => 'Наведіть камеру телефона на цей код.';

  @override
  String get refresh => 'Оновити';

  @override
  String get premiumNotNow => 'Не зараз';

  @override
  String get premiumLimitSheetTitle => 'Трафік на сьогодні вичерпано';

  @override
  String get premiumLimitWait => 'Зачекати на оновлення ліміту';

  @override
  String get premiumLimitInvite =>
      'Запросіть друзів, щоб отримати більше трафіку';

  @override
  String get premiumNoDailyLimit => 'Преміум не має денного ліміту.';

  @override
  String get premiumCalmTitle => 'Хочете без денного ліміту?';

  @override
  String get premiumCalmBody =>
      'Преміум дає безлімітний трафік. Ваш безкоштовний план залишається як є.';

  @override
  String get premiumNextStepTitle => 'Наступний крок: Преміум';

  @override
  String get premiumNextStepBody =>
      'У вас уже максимум безкоштовного трафіку. Преміум не має денного ліміту.';

  @override
  String get premiumLockedTag => 'Преміум';

  @override
  String premiumLockedTitle(String place) {
    return 'Відкрийте $place з Преміумом';
  }

  @override
  String get premiumLockedBody =>
      'Ця локація для Преміуму. Ваші безкоштовні сервери залишаються без змін.';

  @override
  String get premiumHeadlineLimit => 'Без денного ліміту';

  @override
  String premiumHeadlineLocked(String place) {
    return 'Відкрийте $place з Преміумом';
  }

  @override
  String get premiumFreeStays => 'Безкоштовний план працює і без Преміуму.';

  @override
  String premiumEndsOn(String date) {
    return 'Преміум закінчується $date';
  }

  @override
  String get premiumRenewBody =>
      'Поновіть, щоб зберегти безлімітний трафік. Поновлення додає час до поточної дати закінчення.';

  @override
  String premiumEndedOn(String date) {
    return 'Преміум закінчився $date. Ваш безкоштовний план знову діє.';
  }

  @override
  String get premiumRenew => 'Поновити';

  @override
  String get noticeChannelName => 'Повідомлення від Fortiva';

  @override
  String get noticeChannelDescription =>
      'Новини та повідомлення від команди Fortiva';

  @override
  String get noticesSettingTitle => 'Сповіщення';

  @override
  String get noticesSettingOn =>
      'Увімкнено. Повідомлення від команди Fortiva можуть надходити, навіть коли застосунок закрито.';

  @override
  String get noticesSettingOff =>
      'Вимкнено. Увімкніть їх, щоб отримувати повідомлення від команди Fortiva, навіть коли застосунок закрито.';

  @override
  String get noticesOffCard =>
      'Увімкніть сповіщення, щоб отримувати повідомлення від команди Fortiva, навіть коли застосунок закрито.';

  @override
  String get noticesTurnOn => 'Увімкнути';

  @override
  String get backgroundCard =>
      'Телефон може затримувати повідомлення від команди Fortiva, поки застосунок закрито. Дозвольте Fortiva працювати у фоні, щоб вони до вас доходили.';

  @override
  String get backgroundHint =>
      'На наступному екрані виберіть Fortiva (якщо його немає у списку, покажіть усі застосунки). Потім установіть для батареї режим Без обмежень або дозвольте автозапуск і роботу у фоні.';

  @override
  String get backgroundAllow => 'Дозволити';

  @override
  String get backgroundNotNow => 'Не зараз';

  @override
  String get backgroundSettingTitle => 'Повідомлення, коли застосунок закрито';

  @override
  String get backgroundSettingSubtitle =>
      'Дозвольте Fortiva працювати у фоні, щоб повідомлення надходили, навіть коли застосунок закрито.';

  @override
  String get backgroundCardData =>
      'Заощадження трафіку на телефоні може затримувати повідомлення від команди Fortiva, поки застосунок закрито.';

  @override
  String get backgroundHintData =>
      'На наступному екрані увімкніть Необмежений трафік.';

  @override
  String get apnGuideTitle => 'Стабільніше підключення на цій SIM';

  @override
  String get apnGuideBody =>
      'Ваш телефон не використовує IPv6 на цій SIM. Якщо його ввімкнути, Fortiva краще триматиме підключення.';

  @override
  String get apnGuideShowMe => 'Показати, як';

  @override
  String get apnGuideNotNow => 'Не зараз';

  @override
  String get apnGuideSheetTitle => 'Увімкніть IPv6 для цієї SIM';

  @override
  String apnGuideStepOpen(String button) {
    return 'Натисніть «$button» (або відкрийте Налаштування > Підключення > Мобільні мережі > Точки доступу).';
  }

  @override
  String apnGuideStepAccessPoint(String apn) {
    return 'Натисніть точку доступу, яка використовується ($apn).';
  }

  @override
  String get apnGuideStepAccessPointAny =>
      'Натисніть точку доступу, яка використовується.';

  @override
  String get apnGuideStepProtocol =>
      'Натисніть «Протокол APN» і виберіть «IPv4/IPv6».';

  @override
  String get apnGuideStepSave =>
      'Збережіть (на Samsung: меню з трьох крапок, потім «Зберегти»).';

  @override
  String get apnGuideStepRestart =>
      'Вимкніть мобільні дані й увімкніть їх знову.';

  @override
  String get apnGuideUndo =>
      'Якщо мобільний інтернет перестане працювати, поверніть протокол APN на IPv4.';

  @override
  String get apnGuideOpenSettings => 'Відкрити налаштування APN';

  @override
  String get homeStallSearching =>
      'З\'єднання перестало працювати. Шукаємо інший шлях.';

  @override
  String get homeStalled => 'Підключено, але дані не проходять';

  @override
  String get peerShareTitle => 'Допомогти другові підключитися';

  @override
  String get peerShareSubtitle =>
      'Передайте на телефон друга те, що потрібно Fortiva';

  @override
  String get peerShareBody =>
      'Якщо у друга не підключається Fortiva, його телефон може отримати все необхідне з вашого. Інтернет для цього не потрібен.';

  @override
  String peerShareSteps(String action) {
    return 'У Fortiva на його телефоні відкрийте «Налаштування» і натисніть «$action». Потім покажіть йому ці коди по черзі або надішліть йому все одразу.';
  }

  @override
  String get peerShareLoading => 'Отримуємо найсвіжішу копію';

  @override
  String get peerShareNothing =>
      'На цьому телефоні поки немає нічого свіжого, що можна передати. Спробуйте пізніше.';

  @override
  String peerShareCodeOf(int current, int total) {
    return 'Код $current з $total';
  }

  @override
  String get peerSharePrevious => 'Назад';

  @override
  String get peerShareNext => 'Далі';

  @override
  String get peerShareCopy => 'Копіювати';

  @override
  String get peerShareSend => 'Надіслати';

  @override
  String get peerShareCopied => 'Скопійовано. Вставте це в чат із другом.';

  @override
  String get peerReceiveTitle => 'Отримати допомогу друга';

  @override
  String get peerReceiveSubtitle => 'Якщо інакше підключитися не вдається';

  @override
  String peerReceiveBody(String action) {
    return 'Попросіть друга, у якого підключається Fortiva, відкрити «Налаштування» у Fortiva і натиснути «$action». Потім отримайте все з його телефону будь-яким із цих способів.';
  }

  @override
  String get peerReceivePhotograph => 'Сфотографувати коди друга';

  @override
  String get peerReceivePhotographNext => 'Сфотографувати наступний код';

  @override
  String peerReceiveProgress(int have, int total) {
    return 'Зчитано кодів: $have з $total';
  }

  @override
  String get peerReceiveFile => 'Відкрити файл від друга';

  @override
  String get peerReceivePaste => 'Вставити те, що надіслав друг';

  @override
  String get peerReceiveNoCode =>
      'На цьому фото код не знайдено. Піднесіть телефон ближче, щоб увесь код був у кадрі.';

  @override
  String get peerReceiveRefused =>
      'Fortiva не може це використати. Попросіть друга надіслати ще раз.';

  @override
  String get peerReceiveNotNewer =>
      'У вас уже є це або щось новіше. Спробуйте підключитися знову або попросіть про допомогу когось іще з друзів.';

  @override
  String get peerReceiveTaken => 'Готово. Натисніть кнопку, щоб підключитися.';

  @override
  String get peerReceiveUnavailable =>
      'На цьому телефоні це недоступно. Спробуйте інший спосіб.';

  @override
  String get peerReceiveNothingToPaste =>
      'Поки що нічого не скопійовано. Скопіюйте те, що надіслав друг, і натисніть тут ще раз.';

  @override
  String get peerOfferBody =>
      'Досі не вдається підключитися? Друг, у якого працює Fortiva, може допомогти зі свого телефону.';

  @override
  String get peerReceiveAgain =>
      'Цей код у вас уже є. Попросіть друга показати наступний.';

  @override
  String get peerReceivePasteNotOurs =>
      'Те, що ви скопіювали, не з Fortiva. Скопіюйте повідомлення друга повністю і спробуйте ще раз.';

  @override
  String peerReceiveNoPhoto(String action) {
    return 'Камера не передала фото. Зробіть знімок у застосунку камери, потім натисніть «$action».';
  }

  @override
  String get peerReceiveFileHint =>
      'Файл із месенджера, можливо, спершу треба зберегти в «Завантаження».';

  @override
  String get homeTryingBackup =>
      'Більше нічого не підключилося. Пробуємо резервну мережу.';

  @override
  String get homeConnectedBackup => 'Підключено через резервну мережу';

  @override
  String get backupNetwork => 'РЕЗЕРВНА МЕРЕЖА';

  @override
  String get backupNetworkTitle => 'Резервна мережа';

  @override
  String get backupNetworkCaption =>
      'Використовується, коли більше нічого не підключається. Може працювати повільніше за наші сервери.';

  @override
  String get backupNetworkPlace => 'Локація обирається автоматично';

  @override
  String get speedTestStart => 'Почати тест';

  @override
  String get speedTestAgain => 'Повторити тест';

  @override
  String get speedTestRunning => 'Триває тест';

  @override
  String get speedTestIdle =>
      'Дізнайтеся, наскільки швидке ваше підключення зараз.';

  @override
  String get speedTestPhasePing => 'Перевіряємо час відгуку';

  @override
  String get speedTestPhaseDownload => 'Вимірюємо швидкість завантаження';

  @override
  String get speedTestPhaseUpload => 'Вимірюємо швидкість вивантаження';

  @override
  String get speedTestDone => 'Тест завершено';

  @override
  String get speedTestFailed =>
      'Тест не вдалося завершити. Перевірте інтернет і спробуйте ще раз.';

  @override
  String get speedTestUnit => 'Мбіт/с';

  @override
  String get ipAddressLabel => 'IP-адреса';

  @override
  String get ipCopied => 'Адресу скопійовано';

  @override
  String get ipLocation => 'Розташування';

  @override
  String get ipProvider => 'Інтернет-провайдер';

  @override
  String get ipOrganization => 'Організація';

  @override
  String get ipTimeZone => 'Часовий пояс';

  @override
  String get ipCoordinates => 'Координати';

  @override
  String get ipCheckFailed => 'Не вдалося перевірити вашу адресу';

  @override
  String get historyAverage => 'У середньому';

  @override
  String get historyRecentDays => 'Останні дні';

  @override
  String yesterdayAt(String time) {
    return 'Вчора о $time';
  }

  @override
  String dateAt(String date, String time) {
    return '$date о $time';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds с';
  }

  @override
  String get stageOwn => 'Сервери Fortiva';

  @override
  String get stageCommunity => 'Сервери спільноти';

  @override
  String stageProgress(int n, int total) {
    return 'Етап $n з $total';
  }

  @override
  String get stageTryingOwn => 'Пробуємо сервери Fortiva';

  @override
  String get stageTryingCommunity => 'Пробуємо сервери спільноти';

  @override
  String get stageOwnFailedTryingCommunity =>
      'Сервери Fortiva тут не підключилися. Тепер пробуємо сервери спільноти.';

  @override
  String stageLastWorked(String server) {
    return 'Останній робочий сервер: $server';
  }

  @override
  String stageTriedBlocked(int count) {
    return 'Перевірено шляхів: $count, тут заблоковано';
  }

  @override
  String stageTriedFailed(int count) {
    return 'Перевірено шляхів: $count, жоден не підключився';
  }

  @override
  String get stageNotConnected => 'Не підключилося';

  @override
  String get stageConnected => 'Підключено тут';

  @override
  String get stageSkipped => 'Цього разу пропущено';

  @override
  String stageMoreToCheck(int count) {
    return 'Ще шляхів до перевірки: $count';
  }

  @override
  String stageNextTry(String stage, String time) {
    return 'Наступна спроба через $time. Почнемо з етапу «$stage».';
  }

  @override
  String get searchSlowHint =>
      'Це може тривати хвилину-дві. Натисніть кнопку, щоб зупинити пошук.';

  @override
  String get searchStopped => 'Пошук зупинено';

  @override
  String get homeConnectedCommunity => 'Підключено через сервер спільноти';

  @override
  String get stageGettingServers => 'Отримуємо ваші сервери';

  @override
  String stageNextTryStarting(String stage) {
    return 'Починаємо наступну спробу з етапу «$stage»';
  }
}
