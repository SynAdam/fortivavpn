// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class SRu extends S {
  SRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'FortivaVPN';

  @override
  String get statusDisconnected => 'Отключено';

  @override
  String get statusConnecting => 'Подключение';

  @override
  String get statusConnected => 'Подключено';

  @override
  String get statusDisconnecting => 'Отключение';

  @override
  String get statusError => 'Ошибка';

  @override
  String get statusVerifying => 'Проверка...';

  @override
  String get disconnect => 'Отключить';

  @override
  String get connectBtn => 'ПОДКЛЮЧИТЬ';

  @override
  String get disconnectBtn => 'ОТКЛЮЧИТЬ';

  @override
  String get pleaseWait => 'ПОДОЖДИТЕ';

  @override
  String get locationLabel => 'Локация:';

  @override
  String get selectServer => 'Выбрать сервер';

  @override
  String get serverLocation => 'Расположение сервера';

  @override
  String get searchServers => 'Поиск серверов';

  @override
  String get locationsTitle => 'Локации';

  @override
  String get sortLatency => 'Сортировка: задержка';

  @override
  String get sortAZ => 'Сортировка: А-Я';

  @override
  String get sortedByLatency => 'Отсортировано по задержке';

  @override
  String get sortedAZ => 'Отсортировано А–Я';

  @override
  String get pingAll => 'Пинг всех';

  @override
  String get pinging => 'Пингуем...';

  @override
  String get ping => 'Пинг';

  @override
  String get stop => 'Стоп';

  @override
  String get fastestServer => 'САМЫЙ БЫСТРЫЙ СЕРВЕР';

  @override
  String get timeout => 'тайм-аут';

  @override
  String get tabCommunity => 'Сообщество';

  @override
  String get tabFree => 'Бесплатные';

  @override
  String get tabPremium => 'Премиум';

  @override
  String get noCommunityServers => 'Нет серверов сообщества';

  @override
  String get communityLoadFailed => 'Не удалось загрузить этот список';

  @override
  String get communityRetry => 'Повторить';

  @override
  String get officialTabExplainer =>
      'Работают под управлением Fortiva, мы поддерживаем их онлайн. Общие для всех пользователей приложения. Начните отсюда.';

  @override
  String get communityTabExplainer =>
      'Дополнительные варианты подключения. Скорость и доступность могут меняться.';

  @override
  String get noFreeServers => 'Нет бесплатных серверов';

  @override
  String get noPremiumServers => 'Нет премиум-серверов';

  @override
  String noResultsFor(String query) {
    return 'Нет результатов для «$query»';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get freeBadge => 'БЕСП.';

  @override
  String get settings => 'Настройки';

  @override
  String get connection => 'Соединение';

  @override
  String get dnsConfiguration => 'Настройка DNS';

  @override
  String get customDns => 'Пользовательские DNS-серверы';

  @override
  String get about => 'О приложении';

  @override
  String get privacyPolicy => 'Политика конфиденциальности';

  @override
  String get contactUs => 'Связаться с нами';

  @override
  String get rateOnGooglePlay => 'Оценить Fortiva в Google Play';

  @override
  String get website => 'Веб-сайт';

  @override
  String get copyright => '© 2026 NimusAI';

  @override
  String get version => 'Версия';

  @override
  String get language => 'Язык';

  @override
  String get languageSubtitle => 'Язык интерфейса';

  @override
  String get whatIsDns => 'Что такое DNS?';

  @override
  String get dnsExplanation =>
      'DNS (система доменных имён) — это телефонная книга интернета. Он преобразует имена сайтов в IP-адреса.\n\nНастройка DNS позволяет:\n• Повысить скорость соединения ⚡\n• Усилить конфиденциальность 🔒\n• Обойти блокировки цензуры 🌍';

  @override
  String get configuration => 'Конфигурация';

  @override
  String get primaryDns => 'Основной DNS';

  @override
  String get primaryDnsHint => 'По умолчанию: 1.1.1.1';

  @override
  String get secondaryDns => 'Дополнительный DNS (необязательно)';

  @override
  String get secondaryDnsHint => 'По умолчанию: 8.8.8.8';

  @override
  String get saveConfiguration => 'Сохранить настройки';

  @override
  String get dnsSaved => 'Настройки DNS сохранены';

  @override
  String get invalidPrimaryDns => 'Неверный IP-адрес основного DNS';

  @override
  String get invalidSecondaryDns => 'Неверный IP-адрес дополнительного DNS';

  @override
  String get statistics => 'Статистика';

  @override
  String get overview => 'ОБЗОР';

  @override
  String get connectionsLabel => 'Подключения';

  @override
  String get totalTime => 'Общее время';

  @override
  String get dataUsage => 'ИСПОЛЬЗОВАНИЕ ДАННЫХ';

  @override
  String get uploaded => 'Загружено';

  @override
  String get downloaded => 'Скачано';

  @override
  String get total => 'Всего';

  @override
  String lastUpdated(String date) {
    return 'Обновлено: $date';
  }

  @override
  String today(String time) {
    return 'Сегодня в $time';
  }

  @override
  String get yesterday => 'Вчера';

  @override
  String daysAgo(int count) {
    return '$count дн. назад';
  }

  @override
  String get noDataYet => 'Данных пока нет';

  @override
  String get connectToStart => 'Подключитесь к VPN для начала отслеживания';

  @override
  String get errorConnectionFailed => 'Ошибка подключения';

  @override
  String get errorServerNotWorking => 'Сервер не работает — попробуйте другой';

  @override
  String get errorServerNotForwarding => 'Сервер не пересылает трафик';

  @override
  String get errorUnexpected => 'Непредвиденная ошибка';

  @override
  String get errorDisconnectionFailed => 'Ошибка отключения';

  @override
  String get errorFailedToRegister => 'Ошибка регистрации устройства';

  @override
  String get ipInformation => 'Информация об IP';

  @override
  String get connectionAnalytics => 'Аналитика подключений';

  @override
  String get recentSessions => 'Недавние сеансы';

  @override
  String get speedTest => 'Тест скорости';

  @override
  String get startTest => 'Начать тест';

  @override
  String get download => 'Скачивание';

  @override
  String get upload => 'Загрузка';

  @override
  String get testingViaVpn => 'Тест через VPN';

  @override
  String get testingDirect => 'Тест прямого подключения';

  @override
  String get splitTunneling => 'Раздельное туннелирование';

  @override
  String get splitTunnelingDescription =>
      'Выберите категории приложений, которые будут обходить VPN-туннель.';

  @override
  String get enableSplitTunneling => 'Включить раздельное туннелирование';

  @override
  String get splitTunnelActive => 'Выбранные приложения обходят VPN';

  @override
  String get splitTunnelInactive => 'Весь трафик через VPN';

  @override
  String get bypassVpnFor => 'Обойти VPN для';

  @override
  String get tools => 'Инструменты';

  @override
  String get settingsGeneral => 'Общие';

  @override
  String get shareDiagnosticsTitle => 'Отправлять диагностику подключения';

  @override
  String get shareDiagnosticsBody =>
      'Отправляются отчёты о подключениях, оператор и страна, модель телефона и версия Android, названия сайтов, которые вы открываете через VPN, с числом посещений за день, а также то, видели ли вы наши сообщения, предложения Премиума и карточку приглашения и нажимали ли на них. Мы никогда не видим страницы, которые вы открываете, и то, что вы отправляете.';

  @override
  String get security => 'Безопасность';

  @override
  String get privacyDashboard => 'Панель конфиденциальности';

  @override
  String get privacyDashboardSubtitle => 'IP-информация и защита от утечек';

  @override
  String get connectionAnalyticsSubtitle => 'История сеансов и графики';

  @override
  String get speedTestSubtitle => 'Проверьте скорость подключения';

  @override
  String get splitTunnelingSubtitle => 'Маршрутизация VPN приложений';

  @override
  String get splashTagline => 'Приватный доступ, где бы вы ни были';

  @override
  String get openSourceLicence => 'Лицензия открытого исходного кода';

  @override
  String get sourceOfferTitle => 'Лицензия открытого исходного кода';

  @override
  String get sourceOfferBody =>
      'Fortiva VPN является свободным программным обеспечением под лицензией GNU General Public License v3. Приложение основано на Xray-core и других проектах с открытым исходным кодом.\n\nВы имеете право на полный исходный код установленной у вас версии. Чтобы запросить его, напишите на admin@fortivavpn.com и укажите версию приложения. Это предложение действует три года с даты получения этой версии.';

  @override
  String get close => 'Закрыть';

  @override
  String get account => 'Аккаунт';

  @override
  String get deleteAccount => 'Удалить аккаунт';

  @override
  String get deleteAccountSubtitle =>
      'Навсегда удалить это устройство и ваши данные';

  @override
  String get deleteAccountConfirmTitle => 'Удалить ваш аккаунт?';

  @override
  String get deleteAccountConfirmBody =>
      'Будут удалены регистрация устройства, персональные серверы, созданные для вас, и ваши сообщения в чате поддержки. История подключений на этом телефоне тоже будет стёрта.\n\nОтменить это нельзя. Вы можете начать заново в любой момент, просто снова открыв приложение.';

  @override
  String deleteAccountConfirmRetention(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня',
      many: '$days дней',
      few: '$days дней',
      one: '$days дня',
    );
    return 'Запись вашего аккаунта удаляется сразу. Копии в резервных копиях и анонимные логи серверов стираются в течение $_temp0.';
  }

  @override
  String get deleteAccountConfirmRetentionNoDays =>
      'Запись вашего аккаунта удаляется сразу. Копии в резервных копиях и анонимные логи серверов стираются позже, в сроки, указанные в нашей политике конфиденциальности.';

  @override
  String get deleteAccountCancel => 'Оставить аккаунт';

  @override
  String get deleteAccountConfirm => 'Удалить';

  @override
  String get deleteAccountInProgress => 'Удаляем ваш аккаунт';

  @override
  String get deleteAccountDone => 'Ваш аккаунт удалён.';

  @override
  String get deleteAccountFailed =>
      'Не удалось удалить аккаунт. Проверьте соединение и попробуйте снова.';

  @override
  String get homeTapToConnect => 'Нажмите, чтобы подключиться';

  @override
  String get homeChecking => 'Проверка соединения';

  @override
  String get homePreparing => 'Настраиваем ваш сервер';

  @override
  String get homeDisconnecting => 'Отключение';

  @override
  String get homeFindingPath => 'Ищем путь';

  @override
  String get diagCheckingInternet => 'Проверяем ваш интернет';

  @override
  String get diagInternationalCut =>
      'Международный интернет в этой сети отключён';

  @override
  String diagPathRow(String city, int n) {
    return '$city, путь $n';
  }

  @override
  String get diagOpen => 'открыт';

  @override
  String get diagBlocked => 'заблокирован';

  @override
  String get diagSkipped => 'пропущен сегодня';

  @override
  String diagConnectingThrough(String city) {
    return 'Подключаемся через $city';
  }

  @override
  String get diagVerifying => 'Проверяем трафик';

  @override
  String get diagNoInternet => 'У вашего телефона сейчас нет интернета.';

  @override
  String get diagCutOff =>
      'Ваша сеть сейчас не может выйти в международный интернет. Нажмите, чтобы попробовать снова.';

  @override
  String get diagNothingOpen =>
      'Сейчас все пути заблокированы. Нажмите, чтобы попробовать снова.';

  @override
  String get homeTryingAgain =>
      'Сейчас все пути заблокированы. Скоро попробуем снова.';

  @override
  String get homeCutOffTryingAgain =>
      'Ваша сеть сейчас не может выйти в международный интернет. Скоро попробуем снова.';

  @override
  String get homeOfflineTryingAgain =>
      'У вашего телефона сейчас нет интернета. Скоро попробуем снова.';

  @override
  String get diagPathFailed =>
      'Путь был открыт, но туннель так и не заработал. Нажмите, чтобы попробовать снова.';

  @override
  String get openVpnSettings => 'Открыть настройки VPN';

  @override
  String get yourServer => 'ВАШ СЕРВЕР';

  @override
  String get yourServerCaption =>
      'Только ваш. Через него больше никто не подключается.';

  @override
  String get ourServer => 'НАШ СЕРВЕР';

  @override
  String get ourServerCaption =>
      'Работает под управлением Fortiva, общий для всех. Используется, пока не готов ваш собственный сервер.';

  @override
  String get communityServer => 'СЕРВЕР СООБЩЕСТВА';

  @override
  String get communityServerCaption =>
      'Дополнительный вариант подключения. Может перестать работать в любой момент.';

  @override
  String communityServerNumber(String n) {
    return 'Сервер сообщества $n';
  }

  @override
  String get myServersTitle => 'Ваши серверы';

  @override
  String get myServersExplainer =>
      'Каждое устройство Fortiva получает собственный сервер в каждой локации, с данными доступа, которые принадлежат только этой установке. Аккаунт не нужен.';

  @override
  String get myServersInUse => 'Используется';

  @override
  String get myServersEmpty => 'Серверы ещё не назначены';

  @override
  String get myServersRetry => 'Повторить';

  @override
  String get myServersBlockedTitle => 'Дневной объём данных израсходован';

  @override
  String get myServersBlockedWait =>
      'Лимит обновляется автоматически. Загляните позже.';

  @override
  String myServersMoved(String place) {
    return 'Теперь используется $place';
  }

  @override
  String get copyLink => 'Скопировать ссылку';

  @override
  String get linkCopied => 'Ссылка скопирована';

  @override
  String quotaUsedToday(String used, String limit) {
    return '$used из $limit израсходовано сегодня';
  }

  @override
  String get quotaUsedUp => 'Дневной объём исчерпан';

  @override
  String get quotaUnlimited => 'Безлимитные данные';

  @override
  String get quotaDaily => 'Дневной объём';

  @override
  String get quotaLimitReached => 'Дневной лимит достигнут';

  @override
  String quotaLeftOf(String left, String limit) {
    return 'Осталось $left из $limit';
  }

  @override
  String get quotaResetsShortly => 'Скоро обновится';

  @override
  String quotaResetsInHours(int hours) {
    return 'Обновится через $hours ч';
  }

  @override
  String quotaResetsInMinutes(int minutes) {
    return 'Обновится через $minutes мин';
  }

  @override
  String get myServersSubtitle => 'Серверы, выделенные этому устройству';

  @override
  String get sharedServersTitle => 'Общие серверы';

  @override
  String get sharedServersSubtitle =>
      'Общедоступные локации, как запасной вариант';

  @override
  String get tabOfficial => 'Наши серверы';

  @override
  String get noOfficialServers => 'Сейчас нет серверов Fortiva';

  @override
  String get inviteTitle => 'Пригласить друзей';

  @override
  String get inviteSubtitle => 'Получайте больше трафика каждый день';

  @override
  String get inviteYourCode => 'Ваш код приглашения';

  @override
  String get inviteShareAction => 'Поделиться приглашением';

  @override
  String get inviteCopyAction => 'Скопировать код';

  @override
  String get inviteCodeCopied => 'Код скопирован';

  @override
  String inviteShareMessage(String code, String url) {
    return 'Бесплатный VPN, который у меня хорошо работает: Fortiva. Без регистрации.\nУстанови по этой ссылке:\n$url\nМой код приглашения: $code';
  }

  @override
  String get inviteHowItWorks => 'Как это работает';

  @override
  String inviteHowItWorksBody(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days разных дня',
      many: '$days разных дней',
      few: '$days разных дня',
      one: '$days день',
    );
    return 'Поделитесь кодом. Когда кто-то установит приложение, введёт код и будет пользоваться VPN в $_temp0, к вашему дневному трафику добавится $amount и останется навсегда.';
  }

  @override
  String inviteHowItWorksBodyNoAmount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days разных дня',
      many: '$days разных дней',
      few: '$days разных дня',
      one: '$days день',
    );
    return 'Поделитесь кодом. Когда кто-то установит приложение, введёт код и будет пользоваться VPN в $_temp0, ваш дневной трафик увеличится и останется таким навсегда.';
  }

  @override
  String inviteHowItWorksBodyNoDays(String amount) {
    return 'Поделитесь кодом. Когда кто-то установит приложение, введёт код и какое-то время попользуется VPN, к вашему дневному трафику добавится $amount и останется навсегда.';
  }

  @override
  String get inviteHowItWorksBodyNoAmountNoDays =>
      'Поделитесь кодом. Когда кто-то установит приложение, введёт код и какое-то время попользуется VPN, ваш дневной трафик увеличится и останется таким навсегда.';

  @override
  String inviteHowItWorksCap(String max) {
    return 'За приглашения можно получить до $max в день.';
  }

  @override
  String get inviteStatInvited => 'Приглашено';

  @override
  String get inviteStatEarning => 'Засчитано';

  @override
  String get inviteStatBonus => 'Бонусный трафик';

  @override
  String inviteBonusPerDay(String amount) {
    return '+$amount в день';
  }

  @override
  String get inviteNoBonusYet => 'Бонуса пока нет';

  @override
  String invitePendingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count приглашений ещё не засчитано',
      one: '1 приглашение ещё не засчитано',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String inviteJoinedWith(String code) {
    return 'Вы присоединились по коду $code';
  }

  @override
  String get inviteLoadFailed => 'Не удалось загрузить код приглашения';

  @override
  String get inviteRetry => 'Повторить';

  @override
  String get inviteHaveCodeTitle => 'Есть код приглашения?';

  @override
  String inviteHaveCodeSubtitle(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Введите его в течение $hours часа после установки',
      many: 'Введите его в течение $hours часов после установки',
      few: 'Введите его в течение $hours часов после установки',
      one: 'Введите его в течение $hours часа после установки',
    );
    return '$_temp0';
  }

  @override
  String get inviteHaveCodeSubtitleNoHours =>
      'Введите его вскоре после установки';

  @override
  String get inviteEnterCodeHint => 'Код приглашения';

  @override
  String get inviteApplyAction => 'Применить';

  @override
  String get inviteNotNowAction => 'Не сейчас';

  @override
  String inviteClaimAccepted(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days разных дня',
      many: '$days разных дней',
      few: '$days разных дня',
      one: '$days день',
    );
    return 'Приглашение принято. Оно засчитается, когда вы, начиная с сегодняшнего дня, воспользуетесь VPN в $_temp0.';
  }

  @override
  String get inviteClaimAcceptedNoDays =>
      'Приглашение принято. Оно засчитается, когда вы, начиная с сегодняшнего дня, какое-то время попользуетесь VPN.';

  @override
  String get inviteClaimAlready =>
      'Это устройство уже использовало код приглашения';

  @override
  String get inviteClaimRejected =>
      'Код не сработал. Проверьте его и попробуйте снова';

  @override
  String get inviteClaimNetwork =>
      'Не удалось связаться с сервером. Попробуйте снова';

  @override
  String get inviteCardTitle => 'Fortiva хорошо у тебя работает? Отправь другу';

  @override
  String get inviteCardBody =>
      'Отправь другу ссылку на установку, чтобы и он мог бесплатно подключаться.';

  @override
  String inviteCardReward(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Когда твой друг начнёт пользоваться Fortiva, ты получишь $days дня Премиума.',
      many:
          'Когда твой друг начнёт пользоваться Fortiva, ты получишь $days дней Премиума.',
      few:
          'Когда твой друг начнёт пользоваться Fortiva, ты получишь $days дня Премиума.',
      one:
          'Когда твой друг начнёт пользоваться Fortiva, ты получишь $days день Премиума.',
    );
    return '$_temp0';
  }

  @override
  String get inviteCardRewardNoAmount =>
      'Когда твой друг начнёт пользоваться Fortiva, ты получишь Премиум в подарок.';

  @override
  String get inviteSendTelegram => 'Telegram';

  @override
  String get inviteSendWhatsApp => 'WhatsApp';

  @override
  String get inviteCopyLink => 'Скопировать ссылку';

  @override
  String get inviteOtherApps => 'Другие приложения';

  @override
  String get inviteLinkCopied => 'Текст приглашения скопирован';

  @override
  String get invitePasteBody =>
      'Скопируйте код из сообщения друга и вставьте его сюда.';

  @override
  String get invitePasteAction => 'Вставить';

  @override
  String get inviteErrorTooLate =>
      'Время для ввода кода приглашения на этом телефоне истекло.';

  @override
  String get inviteErrorUnknown =>
      'Мы не нашли этот код. Скопируйте его ещё раз из сообщения друга.';

  @override
  String get inviteErrorOwnCode =>
      'Это ваш собственный код. Введите код друга.';

  @override
  String get inviteErrorMutual =>
      'Вы с другом не можете пригласить друг друга.';

  @override
  String inviteHowItWorksPremium(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Каждый друг, который начнёт пользоваться Fortiva, также принесёт вам $days дня Премиума.',
      many:
          'Каждый друг, который начнёт пользоваться Fortiva, также принесёт вам $days дней Премиума.',
      few:
          'Каждый друг, который начнёт пользоваться Fortiva, также принесёт вам $days дня Премиума.',
      one:
          'Каждый друг, который начнёт пользоваться Fortiva, также принесёт вам $days день Премиума.',
    );
    return '$_temp0';
  }

  @override
  String inviteHowItWorksPremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'За приглашения можно получить до $max дня Премиума.',
      many: 'За приглашения можно получить до $max дней Премиума.',
      few: 'За приглашения можно получить до $max дней Премиума.',
      one: 'За приглашения можно получить до $max дня Премиума.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeLive =>
      'Ваш бонус действует, пока друзья продолжают пользоваться Fortiva. Если друг перестанет, бонус может уменьшиться.';

  @override
  String inviteTreeNext(String amount) {
    return 'Ваш следующий друг добавит $amount в день, когда его приглашение засчитают и он будет активен.';
  }

  @override
  String inviteTreeKept(String amount) {
    return 'Ваш бонус не опускается ниже $amount в день, это бонус от ваших прежних приглашений. Эта сумма может уменьшиться, только если одно из ваших приглашений удалят.';
  }

  @override
  String get inviteTreeSlotsTitle => 'Ваши места';

  @override
  String get inviteTreeSlotActive => 'Активен';

  @override
  String get inviteTreeSlotNotActive => 'Сейчас не активен';

  @override
  String get inviteTreeSlotEmpty => 'Свободное место';

  @override
  String inviteTreePaysNow(String amount) {
    return '+$amount в день сейчас';
  }

  @override
  String inviteTreePairFull(String amount) {
    return '+$amount в день, когда оба активны';
  }

  @override
  String get inviteTreeNothingYet => 'Пока ничего';

  @override
  String get inviteTreeFriendsTitle => 'Через ваши места';

  @override
  String get inviteTreeRowFriends => 'На ваших местах';

  @override
  String inviteTreeRowSteps(int steps) {
    String _temp0 = intl.Intl.pluralLogic(
      steps,
      locale: localeName,
      other: 'В $steps шагах от вас',
      many: 'В $steps шагах от вас',
      few: 'В $steps шагах от вас',
      one: 'В $steps шаге от вас',
    );
    return '$_temp0';
  }

  @override
  String inviteTreeRowPeople(int people, int active) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people человека',
      many: '$people человек',
      few: '$people человека',
      one: '$people человек',
    );
    return '$_temp0, активных: $active';
  }

  @override
  String inviteTreeHowSlots(int slots) {
    String _temp0 = intl.Intl.pluralLogic(
      slots,
      locale: localeName,
      other:
          'Поделитесь кодом. Ваши места парами займут первые $slots друга, чьи приглашения будут засчитаны.',
      many:
          'Поделитесь кодом. Ваши места парами займут первые $slots друзей, чьи приглашения будут засчитаны.',
      few:
          'Поделитесь кодом. Ваши места парами займут первые $slots друга, чьи приглашения будут засчитаны.',
      one:
          'Поделитесь кодом. Ваше место займёт первый друг, чьё приглашение будет засчитано.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeHowSlotsNoNumber =>
      'Поделитесь кодом. Ваши места парами займут первые друзья, чьи приглашения будут засчитаны.';

  @override
  String get inviteTreeHowPair =>
      'Пара приносит больше, когда в ней оба активны.';

  @override
  String get inviteTreeHowFriendsSlots =>
      'Когда ваши места заполнены, ваши следующие друзья, чьи приглашения будут засчитаны, займут следующие свободные места, дальше от вас. Они тоже добавляют вам трафик, тем меньше, чем дальше они от вас.';

  @override
  String get inviteTreeHowOthers =>
      'Вашу первую пару могут занять и люди, которых вы не приглашали. Они добавляют вам трафик так же.';

  @override
  String inviteTreeHowActive(int days, int window) {
    String _temp0 = intl.Intl.pluralLogic(
      window,
      locale: localeName,
      other: '$window дня',
      many: '$window дней',
      few: '$window дня',
      one: '$window день',
    );
    String _temp1 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня',
      many: '$days дней',
      few: '$days дня',
      one: '$days день',
    );
    return 'Друг считается активным, если за последние $_temp0 он пользовался VPN хотя бы $_temp1.';
  }

  @override
  String get inviteTreeHowActiveNoNumber =>
      'Друг считается активным, пока продолжает пользоваться VPN.';

  @override
  String inviteTreeHowCap(String max) {
    return 'Приглашения могут добавить до $max в день.';
  }

  @override
  String get inviteTreeHowCapNoAmount =>
      'У бонуса за приглашения есть дневной предел.';

  @override
  String get inviteTreeIntroTitle => 'Как друзья добавляют трафик';

  @override
  String get inviteTreeIntroOpen => 'Показать по шагам';

  @override
  String inviteTreeIntroStep(int current, int total) {
    return 'Шаг $current из $total';
  }

  @override
  String get inviteTreeIntroSkip => 'Пропустить';

  @override
  String get inviteTreeIntroNext => 'Далее';

  @override
  String get inviteTreeIntroBack => 'Назад';

  @override
  String get inviteTreeIntroDone => 'Готово';

  @override
  String get inviteTreeIntroYou => 'Вы';

  @override
  String get inviteTreeIntroSlotsTitle => 'Друзья занимают ваши места парами';

  @override
  String get inviteTreeIntroSlotsArt =>
      'Вы, ваш код приглашения и ваши места парами. Каждое место показывает, свободно ли оно, или активен ли человек в нём сейчас.';

  @override
  String get inviteTreeIntroPairTitle =>
      'Пара добавляет больше всего, когда оба активны';

  @override
  String inviteTreeIntroPairBoth(String full, String one) {
    return 'Когда оба друга в вашей первой паре активны, она добавляет $full в день. Когда активен только один из них, она добавляет $one в день.';
  }

  @override
  String inviteTreeIntroPairBothOnly(String full) {
    return 'Когда оба друга в вашей первой паре активны, она добавляет $full в день. Когда активен только один из них, она ничего не добавляет.';
  }

  @override
  String inviteTreeIntroPairNoOne(String full) {
    return 'Когда оба друга в вашей первой паре активны, она добавляет $full в день. Когда активен только один из них, она добавляет меньше.';
  }

  @override
  String get inviteTreeIntroPairOthersLess =>
      'Ваши другие пары добавляют меньше.';

  @override
  String inviteTreeIntroAdds(String amount) {
    return '+$amount в день';
  }

  @override
  String get inviteTreeIntroYourFriend => 'Ваш друг';

  @override
  String get inviteTreeIntroTotalTitle => 'Ваш трафик от друзей';

  @override
  String get inviteTreeIntroTotalNow => 'От друзей сейчас';

  @override
  String get inviteTreeIntroTotalMost => 'Максимум от приглашений';

  @override
  String get inviteTreeIntroTotalKept => 'Сохранено от прежних приглашений';

  @override
  String inviteTreeIntroTotalReach(String max) {
    return 'Бесплатный трафик вместе с трафиком от друзей может достичь $max в день.';
  }

  @override
  String inviteTreeIntroPerDay(String amount) {
    return '$amount в день';
  }

  @override
  String inviteTreeSheetNext(String amount) {
    return 'Ваш следующий друг добавит $amount в день, когда его приглашение засчитают и он будет активен. К сегодняшнему трафику это не добавится.';
  }

  @override
  String get inviteTreeHero => 'Друзья увеличивают ваш дневной трафик';

  @override
  String inviteTreePremiumEach(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Каждый друг, чьё приглашение по вашему коду засчитано, также добавляет вам $days дня Премиума.',
      many:
          'Каждый друг, чьё приглашение по вашему коду засчитано, также добавляет вам $days дней Премиума.',
      few:
          'Каждый друг, чьё приглашение по вашему коду засчитано, также добавляет вам $days дня Премиума.',
      one:
          'Каждый друг, чьё приглашение по вашему коду засчитано, также добавляет вам $days день Премиума.',
    );
    return '$_temp0';
  }

  @override
  String inviteTreePremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Приглашения могут добавить до $max дня Премиума.',
      many: 'Приглашения могут добавить до $max дней Премиума.',
      few: 'Приглашения могут добавить до $max дней Премиума.',
      one: 'Приглашения могут добавить до $max дня Премиума.',
    );
    return '$_temp0';
  }

  @override
  String inviteTreeIntroSlotsBody(int slots) {
    String _temp0 = intl.Intl.pluralLogic(
      slots,
      locale: localeName,
      other: '$slots места',
      many: '$slots мест',
      few: '$slots места',
      one: '$slots место',
    );
    return 'Друзья, которые присоединяются по вашему коду, могут добавлять трафик к вашему дневному трафику. У вас $_temp0 для них. На каждом месте может быть друг, а места идут парами. Сначала заполняется ваша первая пара. Когда ваши места заполнены, друзья всё равно могут присоединяться.';
  }

  @override
  String get inviteTreeIntroSlotsBodyNoNumber =>
      'Друзья, которые присоединяются по вашему коду, могут добавлять трафик к вашему дневному трафику. У вас есть места для них. На каждом месте может быть друг, а места идут парами. Сначала заполняется ваша первая пара. Когда ваши места заполнены, друзья всё равно могут присоединяться.';

  @override
  String get inviteTreeIntroJoinTitle => 'Как друг занимает место';

  @override
  String inviteTreeIntroJoinCode(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours часа',
      many: '$hours часов',
      few: '$hours часов',
      one: '$hours часа',
    );
    return 'Ваш друг должен ввести ваш код на своём экране приглашений в течение $_temp0 после установки Fortiva.';
  }

  @override
  String get inviteTreeIntroJoinCodeNoNumber =>
      'Ваш друг должен ввести ваш код на своём экране приглашений вскоре после установки Fortiva.';

  @override
  String inviteTreeIntroJoinQualify(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'После этого он должен пользоваться VPN в $days разных дня. Тогда его приглашение засчитывается, и он занимает следующее свободное место.',
      many:
          'После этого он должен пользоваться VPN в $days разных дней. Тогда его приглашение засчитывается, и он занимает следующее свободное место.',
      few:
          'После этого он должен пользоваться VPN в $days разных дня. Тогда его приглашение засчитывается, и он занимает следующее свободное место.',
      one:
          'После этого он должен пользоваться VPN $days день. Тогда его приглашение засчитывается, и он занимает следующее свободное место.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeIntroJoinQualifyNoNumber =>
      'После этого он должен какое-то время пользоваться VPN. Тогда его приглашение засчитывается, и он занимает следующее свободное место.';

  @override
  String get inviteTreeIntroJoinPlay =>
      'Если он установит Fortiva из Google Play по вашей ссылке, код введётся за него.';

  @override
  String get inviteTreeIntroJoinWaiting =>
      'Пока его приглашение не засчитано, ваш экран приглашений учитывает его в графе «Приглашено», но ещё не в графе «Засчитано».';

  @override
  String get inviteTreeIntroJoinStepCode => 'Вводит ваш код';

  @override
  String get inviteTreeIntroJoinStepUse => 'Пользуется VPN';

  @override
  String get inviteTreeIntroJoinStepSlot => 'Занимает место';

  @override
  String get inviteTreeIntroJoinArt =>
      'Друг вводит ваш код, пользуется VPN в разные дни, а затем занимает следующее свободное место.';

  @override
  String get inviteTreeIntroPairsBody =>
      'Каждая пара может добавлять вам трафик. Больше всего она добавляет, когда оба человека в ней активны.';

  @override
  String get inviteTreeIntroPairsCaption =>
      'Сколько каждая пара добавляет к вашему трафику в день';

  @override
  String get inviteTreeIntroBothActive => 'Оба активны';

  @override
  String get inviteTreeIntroOneActive => 'Активен один';

  @override
  String inviteTreeIntroPlus(String amount) {
    return '+$amount';
  }

  @override
  String get inviteTreeIntroNothing => 'Ничего';

  @override
  String get inviteTreeIntroPairNow =>
      'Выделенные значения показывают, сколько ваши пары добавляют сейчас.';

  @override
  String get inviteTreeIntroPairsArt =>
      'Ваши пары и сколько каждая добавляет в день, когда активны оба человека в ней и когда активен один.';

  @override
  String get inviteTreeIntroActiveTitle =>
      'Друг добавляет трафик, пока он активен';

  @override
  String get inviteTreeIntroActiveStops =>
      'Если друг перестаёт пользоваться Fortiva, его пара добавляет меньше, и ваш бонус может уменьшиться. Его место остаётся за ним. Когда он снова начинает пользоваться Fortiva, его пара снова добавляет больше.';

  @override
  String get inviteTreeIntroActiveFar =>
      'Люди, которые находятся дальше и добавляют вам трафик, тоже учитываются, только пока они активны.';

  @override
  String get inviteTreeIntroActiveArt =>
      'Пара, в которой друг перестал пользоваться Fortiva. Теперь эта пара добавляет меньше.';

  @override
  String get inviteTreeIntroFullTitle => 'Когда ваши места заполнены';

  @override
  String get inviteTreeIntroFullBody =>
      'Когда все ваши места заняты, ваш следующий друг попадает в первую пару кого-то из тех, кто на ваших местах, по порядку начиная с вашего первого места. Эта пара добавляет трафик этому человеку, а вам меньше.';

  @override
  String get inviteTreeIntroFullLess =>
      'Чем дальше место, тем меньше оно добавляет вам. Очень далёкие места ничего не добавляют.';

  @override
  String get inviteTreeIntroNextFriend => 'Ваш следующий друг';

  @override
  String get inviteTreeIntroLaterFriend => 'Друг, который придёт позже';

  @override
  String get inviteTreeIntroFullArt =>
      'Друг, пришедший позже, занимает свободное место в первой паре кого-то из тех, кто на ваших местах. Эта пара добавляет трафик этому человеку, а вам меньше.';

  @override
  String get inviteTreeIntroOthersTitle =>
      'В вашей первой паре могут быть люди, которых вы не приглашали';

  @override
  String get inviteTreeIntroOthersWhy =>
      'Вы присоединились по коду друга. Когда его места заполнены, его следующие друзья могут занять свободное место в вашей первой паре. Друзья других людей тоже могут. Кто бы его ни занял, он добавляет вам трафик так же, как ваши собственные друзья.';

  @override
  String get inviteTreeIntroOthersYours =>
      'Ваши собственные друзья заполняют ваши остальные свободные места, а после этого свободные места дальше.';

  @override
  String get inviteTreeIntroNotInvited => 'Не приглашён вами';

  @override
  String get inviteTreeIntroOthersArt =>
      'Пример вашей первой пары: друг, которого вы пригласили, и человек, которого вы не приглашали. Оба добавляют вам трафик, пока активны.';

  @override
  String get inviteTreeIntroShareTitle =>
      'Приглашайте друзей, которые будут пользоваться Fortiva';

  @override
  String get inviteTreeIntroShareBody =>
      'Друг добавляет вам трафик, только пока он активен. Отправьте приглашение друзьям, которым нужен VPN.';

  @override
  String get inviteTreeQaTitle => 'Вопросы и ответы';

  @override
  String get inviteTreeQaCountQ =>
      'Мой друг ввёл мой код. Когда он займёт место?';

  @override
  String get inviteTreeQaCountDay =>
      'День засчитывается, только если в этот день он использует через VPN хоть немного трафика. Просто открыть приложение недостаточно. Срока для этих дней нет.';

  @override
  String get inviteTreeQaCountOther =>
      'Телефон, на котором уже ввели код, не может ввести другой. Вы и ваш друг не можете ввести коды друг друга.';

  @override
  String get inviteTreeQaDownQ => 'Почему мой бонус уменьшился?';

  @override
  String get inviteTreeQaDownA =>
      'Кто-то, кто добавляет вам трафик, сейчас не активен. Это может быть друг на ваших местах или кто-то дальше. Когда он снова начнёт пользоваться Fortiva, он снова будет добавлять трафик.';

  @override
  String get inviteTreeQaDownLater =>
      'Друг, который перестал пользоваться приложением, ещё какое-то время считается активным. Поэтому ваш бонус может уменьшиться не сразу, а через некоторое время.';

  @override
  String get inviteTreeQaDownRemoved =>
      'Ваш бонус может уменьшиться и тогда, когда приглашение удаляется, например когда этот друг удаляет свой аккаунт Fortiva.';

  @override
  String get inviteTreeQaFullQ => 'Что будет, когда мои места заполнятся?';

  @override
  String get inviteTreeQaFullFurther =>
      'Когда и эти первые пары заполнены, ваш следующий друг попадает дальше, в первую пару кого-то из тех, кто в этих парах. Эта пара добавляет трафик этому человеку, а вам и каждому, кто между вами, меньше.';

  @override
  String get inviteTreeQaFriendsQ => 'Друзья моих друзей добавляют мне трафик?';

  @override
  String get inviteTreeQaFriendsA =>
      'Некоторые да. Первая пара каждого, кто на ваших местах, добавляет трафик этому человеку, а вам меньше. Остальные их пары добавляют трафик только им. Дальше трафик вам добавляют только первые пары, и чем они дальше, тем меньше, пока не перестают добавлять совсем.';

  @override
  String get inviteTreeQaOthersQ =>
      'Кто эти люди на моих местах, которых я не приглашал?';

  @override
  String get inviteTreeQaOthersA =>
      'Это друзья кого-то, чьи места заполнены, например того, кто вас пригласил. Они заняли свободное место в вашей первой паре, и вы не можете выбрать или убрать их. Они добавляют вам трафик так же, как ваши собственные друзья.';

  @override
  String get inviteTreeQaSumQ =>
      'Почему мой бонус отличается от значений на экране приглашений?';

  @override
  String get inviteTreeQaSumA =>
      'Каждая строка в разделе «Через ваши места» показывает, сколько сейчас добавляют люди этой строки. Ваш бонус равен их сумме, но не больше лимита.';

  @override
  String get inviteTreeQaSlotQ =>
      'Можно освободить место или выбрать, кто его займёт?';

  @override
  String get inviteTreeQaSlotA =>
      'Нет. Друг сохраняет своё место, даже если перестаёт пользоваться Fortiva. Его место снова освобождается, только когда его приглашение удаляется, например когда он удаляет свой аккаунт Fortiva. Свободные места заполняются по порядку, и никто не может выбрать, кто их займёт.';

  @override
  String get inviteTreeQaPrivacyQ => 'Видят ли друзья, пользуюсь ли я Fortiva?';

  @override
  String get inviteTreeQaPrivacyA =>
      'Если вы присоединились по коду друга, тот, у кого вы занимаете место, видит, активны вы или сейчас не активны. Остальные видят только, сколько людей активны, но не кто именно. Экран приглашений никогда не показывает ничьё имя, телефон или расход трафика.';

  @override
  String get inviteTreeQaLimitQ => 'Есть ли лимит?';

  @override
  String get inviteTreeQaLimitMore =>
      'Когда ваши приглашения добавляют столько, новые друзья больше трафика не добавляют.';

  @override
  String get inviteTreeQaKeptQ =>
      'Что будет с бонусом, который у меня уже есть?';

  @override
  String get inviteTreeQaKeptMore =>
      'Если бонус от ваших прежних приглашений больше того, что сейчас добавляют друзья, вы получаете этот бонус, а не то, что добавляют друзья. Эти суммы не складываются.';

  @override
  String get inviteTreeQaKeptRemoved =>
      'Приглашение удаляется, когда этот друг удаляет свой аккаунт Fortiva или когда Fortiva отменяет его из-за злоупотребления.';

  @override
  String get inviteTreeQaChangedQ => 'Что изменилось в приглашениях?';

  @override
  String get inviteTreeQaChangedA =>
      'Раньше каждый засчитанный друг добавлял фиксированный объём трафика. Теперь друзья добавляют трафик, пока они активны, через ваши места и пары, и ваш бонус может уменьшаться.';

  @override
  String get inviteTreeQaPremiumQ => 'Добавляют ли приглашения дни Премиума?';

  @override
  String get inviteTreeQaPremiumOwn =>
      'Неважно, какое место займёт ваш друг. Люди, которых вы не приглашали, не добавляют дни Премиума.';

  @override
  String get inviteTreeQaGetsQ => 'Получает ли что-то мой друг?';

  @override
  String get inviteTreeQaGetsA =>
      'За ввод вашего кода нет. Как и у всех, у него есть свой код и свои места, и друзья, которые присоединяются по его коду, добавляют ему трафик. Когда его приглашение засчитано, в его первой паре тоже могут оказаться люди, которых он не приглашал, и они тоже добавляют ему трафик.';

  @override
  String get inviteTreeQaGetsSee =>
      'Если он на ваших местах, вы видите, активен он или сейчас не активен. Вы никогда не видите его имя или расход трафика.';

  @override
  String get inviteTreeKeptFloor =>
      'Сейчас ваш бонус равен сумме, сохранённой от ваших прежних приглашений. Он вырастет, когда друзья вместе будут добавлять больше этой суммы.';

  @override
  String inviteTreeIntroTotalUpTo(String most, String total) {
    return 'Друзья могут добавить до $most в день. Ваш бесплатный трафик вместе с трафиком от друзей может достичь $total в день.';
  }

  @override
  String get inviteTreeIntroPairsOrder =>
      'Больше всего добавляет ваша первая пара. Каждая следующая пара добавляет меньше.';

  @override
  String get inviteTreeIntroInvitedYou => 'Пригласил вас';

  @override
  String get inviteTreeIntroGuide => 'Объяснение по шагам';

  @override
  String get inviteTreeQaCostQ => 'Теряет ли мой друг трафик из-за меня?';

  @override
  String get inviteTreeQaCostA =>
      'Нет. То, что друг добавляет вам, не вычитается из его собственного трафика. Его дневной трафик из-за вас не меняется.';

  @override
  String get inviteTreeQaStartQ =>
      'Когда начинает добавляться трафик от друга?';

  @override
  String get inviteTreeQaStartA =>
      'Как только друг занял место и активен. Ваш бонус время от времени обновляется, поэтому он вырастет вскоре после этого, в тот же день. Пока приглашение друга не засчитано, он ничего не добавляет.';

  @override
  String get inviteTreeQaPhoneQ =>
      'Что если друг переустановит Fortiva или сменит телефон?';

  @override
  String get inviteTreeQaPhoneA =>
      'После переустановки на том же телефоне Fortiva обычно узнаёт телефон, и ничего не меняется. Новый телефон для Fortiva новый. Место по-прежнему принадлежит старому телефону и считается неактивным, когда старым телефоном перестают пользоваться.';

  @override
  String get premiumSourceInvite => 'За ваши приглашения';

  @override
  String quotaBonusIncluded(String amount) {
    return 'включая $amount бонуса за приглашение';
  }

  @override
  String get updateTitle => 'Доступно обновление';

  @override
  String get updateRequiredTitle => 'Требуется обновление';

  @override
  String updateBody(String version) {
    return 'Вышла версия Fortiva $version. Обновите, чтобы получить последние исправления.';
  }

  @override
  String get updateRequiredBody =>
      'Эта версия больше не поддерживается. Обновите, чтобы продолжить пользоваться Fortiva.';

  @override
  String get updateNow => 'Обновить';

  @override
  String get updateLater => 'Позже';

  @override
  String get updateFromPlay => 'Google Play';

  @override
  String get updateFromTelegram => 'Telegram-канал';

  @override
  String get updateConnect => 'Подключиться';

  @override
  String get updateConnectHint =>
      'Если Google Play или Telegram не открывается, сначала нажмите «Подключиться».';

  @override
  String get updateConnected => 'Вы подключены. Скачайте обновление сейчас.';

  @override
  String get updateReconnect => 'Не работает? Переподключиться';

  @override
  String get updateDisconnect => 'Отключиться';

  @override
  String get updateDisconnectHint =>
      'Нажмите «Отключиться», чтобы скачать обновление через обычный интернет.';

  @override
  String get updateNotCarrying =>
      'Вы подключены, но данные не проходят. Попробуйте переподключиться или нажмите «Отключиться», чтобы пользоваться обычным интернетом.';

  @override
  String get diagVerdictNoInternet =>
      'У вашего телефона нет подключения к интернету. Пока оно не вернётся, Fortiva не сможет подключиться.';

  @override
  String get diagVerdictCutOff =>
      'Ваша сеть сейчас не может выйти в международный интернет. Попробуйте снова через несколько минут.';

  @override
  String get diagVerdictNeedsPermission =>
      'У Fortiva нет разрешения запускать VPN, или для другого VPN-приложения включён режим «Всегда включено».';

  @override
  String get diagVerdictServerUnreachable =>
      'Этот сервер недоступен из вашей сети. Он либо заблокирован здесь, либо не работает.';

  @override
  String get diagVerdictBlockedTls =>
      'Соединение с этим сервером обрывается, пока оно устанавливается. Так выглядит фильтрация.';

  @override
  String get diagVerdictThrottled =>
      'Сервер ответил на все проверки, но туннель так ничего и не передал. Соединение замедляют.';

  @override
  String get diagCheckInternet => 'Проверьте интернет';

  @override
  String diagTryServer(String server) {
    return 'Новый поиск: $server';
  }

  @override
  String get diagTryAnotherServer => 'Попробовать другой сервер';

  @override
  String get diagDetails => 'Подробности';

  @override
  String get diagDetailsHide => 'Скрыть подробности';

  @override
  String privateDnsWarning(String host) {
    return 'Включён частный DNS ($host), поэтому некоторые сайты могут не открываться. Отключите частный DNS в настройках телефона.';
  }

  @override
  String get openNetworkSettings => 'Открыть настройки сети';

  @override
  String testPointStatus(String time, int open, int total) {
    return 'Тестовая точка · последняя проверка $time · открыто $open из $total';
  }

  @override
  String get messagesTooltip => 'Сообщения';

  @override
  String get inboxTitle => 'Сообщения';

  @override
  String get inboxEmpty => 'Сейчас сообщений нет.';

  @override
  String get messageClose => 'Закрыть';

  @override
  String get supportTitle => 'Поддержка';

  @override
  String get supportTooltip => 'Чат с поддержкой';

  @override
  String get supportAskAction => 'Спросить поддержку';

  @override
  String get supportContactSubtitle => 'Напишите нам прямо в приложении';

  @override
  String get supportAutomaticNotice =>
      'Ответы пишутся автоматически и могут быть неточными.';

  @override
  String get supportStaffNotice =>
      'Автоматические ответы сейчас выключены. Ваши сообщения получит наша команда.';

  @override
  String get supportInputHint => 'Напишите вопрос';

  @override
  String get supportInputHintTeam => 'Напишите нашей команде';

  @override
  String get supportSend => 'Отправить';

  @override
  String supportQuotaLeft(int remaining, int limit) {
    return 'Осталось вопросов сегодня: $remaining из $limit';
  }

  @override
  String supportWaitIn(String time) {
    return 'Вы сможете спросить снова через $time.';
  }

  @override
  String supportDurationHours(int hours, int minutes) {
    return '$hours ч $minutes мин';
  }

  @override
  String supportDurationMinutes(int minutes) {
    return '$minutes мин';
  }

  @override
  String get supportNewConversation => 'Новый разговор';

  @override
  String get supportSending => 'Отправка';

  @override
  String get supportNotSent => 'Не отправлено. Нажмите, чтобы повторить.';

  @override
  String get supportRateUp => 'Полезно';

  @override
  String get supportRateDown => 'Бесполезно';

  @override
  String get supportRatedDown => 'Спасибо. Наша команда посмотрит этот ответ.';

  @override
  String get supportTeamLabel => 'Команда Fortiva';

  @override
  String get supportUnavailable => 'Чат сейчас недоступен.';

  @override
  String get supportOpenTelegram => 'Напишите нам в Telegram';

  @override
  String get supportGenericError => 'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String supportCodeTooLong(int max) {
    return 'Сообщение слишком длинное. Уложитесь в $max символов.';
  }

  @override
  String get supportCodeEmpty => 'Сообщение пустое.';

  @override
  String get supportCodeWaitReply =>
      'Пожалуйста, дождитесь ответа на предыдущий вопрос.';

  @override
  String get supportCodeSlowDown =>
      'Вы отправляете сообщения слишком быстро. Подождите немного.';

  @override
  String get supportCodeQuotaDay => 'Вы задали все вопросы на сегодня.';

  @override
  String get supportCodePaused =>
      'Автоматические ответы временно приостановлены.';

  @override
  String get supportCodeBusy =>
      'Наш помощник сейчас занят. Попробуйте через несколько минут.';

  @override
  String get supportCodeGreeting => 'Здравствуйте! Чем могу помочь с Fortiva?';

  @override
  String get supportCodeGibberish =>
      'Извините, я не понял. Напишите вопрос ещё раз.';

  @override
  String get supportCodeRedacted =>
      'Мы удалили из сообщения личные данные и ссылки.';

  @override
  String get supportCodeRedactedEmpty =>
      'В сообщении были только личные данные или ссылки, поэтому оно не отправлено. Опишите проблему словами.';

  @override
  String get supportCodeOffTopic =>
      'Я могу помочь только с вопросами об использовании Fortiva.';

  @override
  String get supportCodeAbuse =>
      'Давайте общаться уважительно. Я здесь, чтобы помочь с Fortiva.';

  @override
  String get supportCodeAiUnavailable =>
      'Помощник не смог ответить в этот раз. Попробуйте чуть позже.';

  @override
  String get supportCodeToStaff =>
      'Отправлено нашей команде. Ответ появится здесь.';

  @override
  String get supportCodeTicketOpened =>
      'Мы передали ваш вопрос нашей команде. Ответ появится здесь.';

  @override
  String get supportCodeNotSent =>
      'Это сообщение не удалось отправить. Напишите его ещё раз, если вам всё ещё нужна помощь.';

  @override
  String get supportAssistantSubtitle => 'ИИ-помощник';

  @override
  String get supportThinkingReading => 'Читаю ваш вопрос';

  @override
  String get supportThinkingSearching => 'Ищу ответ';

  @override
  String get supportThinkingWriting => 'Пишу ответ';

  @override
  String get supportThinkingStill => 'Всё ещё работаю, спасибо, что ждёте';

  @override
  String get supportSuggestConnect => 'Не могу подключиться';

  @override
  String get supportSuggestData => 'Сколько трафика у меня сегодня?';

  @override
  String get supportSuggestSlow => 'У меня медленное соединение';

  @override
  String get supportWithTeam =>
      'Теперь этим разговором занимается наша команда.';

  @override
  String get supportTryAgainSoon => 'Попробуйте ещё раз через несколько минут.';

  @override
  String supportDurationWholeHours(int hours) {
    return '$hours ч';
  }

  @override
  String get supportUnreadReply => 'Новый ответ';

  @override
  String get premiumTitle => 'Премиум';

  @override
  String get premiumTileSubtitle => 'Безлимитный трафик без дневного лимита';

  @override
  String get premiumTileActive => 'Премиум активен';

  @override
  String get premiumGetUnlimited => 'Получить безлимит';

  @override
  String get premiumHeadline => 'Получите безлимит';

  @override
  String get premiumPitch =>
      'Премиум снимает дневной лимит: пользуйтесь трафиком сколько угодно, пока он действует.';

  @override
  String get premiumActiveTitle => 'Премиум активен';

  @override
  String premiumActiveUntil(String date) {
    return 'Безлимитный трафик до $date';
  }

  @override
  String get premiumActiveNoDate => 'Безлимитный трафик';

  @override
  String get premiumRenews => 'Продлевается автоматически через Google Play';

  @override
  String get premiumSourceKey => 'Активирован ключом';

  @override
  String get premiumSourceCrypto => 'Оплачен криптовалютой';

  @override
  String get premiumSourceStars => 'Оплачен звёздами Telegram';

  @override
  String get premiumSourceGooglePlay => 'Оплачен через Google Play';

  @override
  String get premiumSourceManual => 'Подарок от команды Fortiva';

  @override
  String get premiumYourKey => 'Ваш ключ';

  @override
  String get premiumKeyHint =>
      'Сохраните этот ключ. Введите его на другом телефоне, чтобы перенести туда Премиум.';

  @override
  String premiumKeyMoves(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count раза',
      many: '$count раз',
      few: '$count раз',
      one: '$count раза',
    );
    String _temp1 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня',
      many: '$days дней',
      few: '$days дня',
      one: '$days день',
    );
    return 'Ключ можно перенести на другой телефон не больше $_temp0 за $_temp1.';
  }

  @override
  String get premiumKeyMovesNoNumber =>
      'Ключ можно переносить на другой телефон лишь ограниченное число раз.';

  @override
  String get premiumCopy => 'Копировать';

  @override
  String get premiumCopied => 'Скопировано';

  @override
  String get premiumChoosePlan => 'Выберите тариф';

  @override
  String premiumPlanDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня безлимитного трафика',
      many: '$days дней безлимитного трафика',
      few: '$days дня безлимитного трафика',
      one: '$days день безлимитного трафика',
    );
    return '$_temp0';
  }

  @override
  String get premiumPlanNoDays => 'Безлимитный трафик';

  @override
  String get premiumBuy => 'Купить';

  @override
  String get premiumPlayUnavailable =>
      'Google Play сейчас недоступен. Попробуйте позже.';

  @override
  String get premiumPlayPending =>
      'Ваш платёж ожидает подтверждения в Google Play. Премиум заработает, как только он пройдёт.';

  @override
  String get premiumPlayConfirming => 'Подтверждаем покупку...';

  @override
  String get premiumPlayRetrying =>
      'Оплата прошла, но мы пока не смогли её подтвердить. Мы продолжим попытки, платить ещё раз не нужно.';

  @override
  String get premiumPlayRefused =>
      'Не удалось подтвердить эту покупку. Если с вас списали деньги, напишите в поддержку.';

  @override
  String get premiumPlayNotAvailable =>
      'Премиум сейчас недоступен на этом телефоне. Если с вас списали деньги, напишите в поддержку.';

  @override
  String get premiumNotAvailable =>
      'Премиум сейчас недоступен на этом телефоне.';

  @override
  String get premiumPlayFailed => 'Покупка не прошла. Попробуйте ещё раз.';

  @override
  String get premiumNowOn => 'Премиум активен. Пользуйтесь безлимитом.';

  @override
  String get premiumRestore => 'Восстановить покупки';

  @override
  String get premiumRestoreDone =>
      'Ваша покупка восстановлена на этом телефоне.';

  @override
  String get premiumRestoreNone =>
      'В Google Play нет покупок для восстановления.';

  @override
  String get premiumRestoreFailed =>
      'Не удалось восстановить покупку. Попробуйте позже.';

  @override
  String premiumRenewsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Оплата списывается каждые $count дня. Продлевается автоматически, пока вы не отмените подписку.',
      many:
          'Оплата списывается каждые $count дней. Продлевается автоматически, пока вы не отмените подписку.',
      few:
          'Оплата списывается каждые $count дня. Продлевается автоматически, пока вы не отмените подписку.',
      one:
          'Оплата списывается каждый день. Продлевается автоматически, пока вы не отмените подписку.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Оплата списывается каждые $count недели. Продлевается автоматически, пока вы не отмените подписку.',
      many:
          'Оплата списывается каждые $count недель. Продлевается автоматически, пока вы не отмените подписку.',
      few:
          'Оплата списывается каждые $count недели. Продлевается автоматически, пока вы не отмените подписку.',
      one:
          'Оплата списывается каждую неделю. Продлевается автоматически, пока вы не отмените подписку.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Оплата списывается каждые $count месяца. Продлевается автоматически, пока вы не отмените подписку.',
      many:
          'Оплата списывается каждые $count месяцев. Продлевается автоматически, пока вы не отмените подписку.',
      few:
          'Оплата списывается каждые $count месяца. Продлевается автоматически, пока вы не отмените подписку.',
      one:
          'Оплата списывается каждый месяц. Продлевается автоматически, пока вы не отмените подписку.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Оплата списывается каждые $count года. Продлевается автоматически, пока вы не отмените подписку.',
      many:
          'Оплата списывается каждые $count лет. Продлевается автоматически, пока вы не отмените подписку.',
      few:
          'Оплата списывается каждые $count года. Продлевается автоматически, пока вы не отмените подписку.',
      one:
          'Оплата списывается каждый год. Продлевается автоматически, пока вы не отмените подписку.',
    );
    return '$_temp0';
  }

  @override
  String get premiumRenewsNoPeriod =>
      'Продлевается автоматически, пока вы не отмените подписку.';

  @override
  String get premiumPlayCancelNote =>
      'Отменить подписку можно в любой момент в Google Play. Премиум останется до конца оплаченного срока.';

  @override
  String get premiumManageSubscription => 'Управлять подпиской или отменить';

  @override
  String get premiumCurrentPlan => 'Текущий тариф';

  @override
  String get premiumPlaySubscribed =>
      'У вас уже есть подписка Google Play. Управлять ею или отменить её можно в Google Play.';

  @override
  String get premiumEnterCode => 'Ввести код';

  @override
  String get premiumNeedsPlayVersion =>
      'Чтобы купить через Google Play, нужна версия Fortiva из Google Play.';

  @override
  String get premiumOff => 'Премиум сейчас не продаётся.';

  @override
  String get premiumLoadFailed =>
      'Не удалось загрузить Премиум. Проверьте подключение и попробуйте снова.';

  @override
  String get premiumRetry => 'Повторить';

  @override
  String premiumPriceUsdt(String price) {
    return '$price USDT';
  }

  @override
  String premiumPriceStars(String stars) {
    return 'Звёзды Telegram: $stars';
  }

  @override
  String get premiumPayCrypto => 'Оплатить криптовалютой';

  @override
  String get premiumTelegramTitle => 'Оплата в Telegram';

  @override
  String get premiumTelegramBody =>
      'Оплатите звёздами Telegram в нашем боте. Вы получите ключ, и Премиум сразу заработает на этом телефоне.';

  @override
  String get premiumTelegramButton => 'Купить в Telegram';

  @override
  String get premiumTelegramFailed =>
      'Не удалось открыть Telegram. Попробуйте ещё раз.';

  @override
  String get checkoutTitle => 'Оплата криптовалютой';

  @override
  String get checkoutChooseNetwork =>
      'Выберите сеть, из которой будете отправлять';

  @override
  String get checkoutContinue => 'Продолжить';

  @override
  String get checkoutSendExactly => 'Отправьте ровно эту сумму';

  @override
  String get checkoutNetwork => 'Сеть';

  @override
  String get checkoutAddress => 'На этот адрес';

  @override
  String get checkoutMemo => 'С этим мемо';

  @override
  String get checkoutMemoWarning =>
      'Обязательно укажите это мемо в переводе, иначе мы не сможем сопоставить платёж с вами.';

  @override
  String get checkoutExactWarning =>
      'Отправьте точную сумму и только в этой сети. Другая сумма или другая сеть могут до нас не дойти.';

  @override
  String checkoutTimeLeft(String time) {
    return 'Осталось времени: $time';
  }

  @override
  String get checkoutWaiting =>
      'Ждём ваш платёж. Эта страница обновляется сама.';

  @override
  String get checkoutPaidTitle => 'Платёж получен';

  @override
  String get checkoutPaidKeyOnly =>
      'Ваш ключ готов. Введите его на телефоне, который должен получить Премиум.';

  @override
  String get checkoutDone => 'Готово';

  @override
  String get checkoutExpired =>
      'Срок этого заказа истёк. Если вы уже заплатили, напишите в поддержку.';

  @override
  String get checkoutUnderpaid =>
      'Мы получили меньше полной суммы. Напишите в поддержку и укажите этот номер заказа:';

  @override
  String get checkoutCanceled => 'Этот заказ отменён.';

  @override
  String get checkoutStartAgain => 'Начать заново';

  @override
  String get checkoutUnavailable => 'Оплата криптовалютой сейчас недоступна.';

  @override
  String get checkoutTooManyOpen =>
      'У вас слишком много неоплаченных заказов. Оплатите какой-нибудь из них или подождите, пока они истекут.';

  @override
  String get checkoutUnknownPlan =>
      'Этот тариф больше не продаётся. Вернитесь и выберите другой.';

  @override
  String get checkoutFailed =>
      'Не удалось начать оплату. Проверьте подключение и попробуйте снова.';

  @override
  String get redeemTitle => 'Ввести код';

  @override
  String get redeemSubtitle => 'Ключ Премиум или подарочный код';

  @override
  String get redeemHint => 'Код';

  @override
  String get redeemApply => 'Применить';

  @override
  String get redeemCancel => 'Отмена';

  @override
  String get redeemInvalid =>
      'Это не похоже на код. Проверьте его и попробуйте снова.';

  @override
  String get redeemUnknown =>
      'Мы не знаем такого кода. Проверьте его и попробуйте снова.';

  @override
  String get redeemExpired => 'Срок действия этого кода истёк.';

  @override
  String get redeemRevoked => 'Этот код больше не действует.';

  @override
  String get redeemMovedTooOften =>
      'Этот ключ слишком часто переносили между телефонами. Попробуйте позже.';

  @override
  String get redeemExhausted => 'Этот код уже израсходован.';

  @override
  String get redeemAlreadyUsed => 'Этот телефон уже использовал этот код.';

  @override
  String get redeemUnmetered =>
      'У этого телефона уже безлимитный трафик, этот код ему не нужен.';

  @override
  String get redeemRateLimited =>
      'Слишком много попыток. Подождите немного и попробуйте снова.';

  @override
  String get redeemUnavailable => 'Сейчас это недоступно. Попробуйте позже.';

  @override
  String get redeemNetwork =>
      'Не удалось связаться с сервером. Проверьте подключение и попробуйте снова.';

  @override
  String get redeemFailed =>
      'Этот код не сработал. Проверьте его и попробуйте снова.';

  @override
  String get redeemMoved => 'Премиум перенесён на этот телефон.';

  @override
  String redeemPromo(String amount) {
    return 'Код принят. Добавлено $amount дополнительного трафика.';
  }

  @override
  String get redeemPromoNoAmount =>
      'Код принят. Дополнительный трафик добавлен.';

  @override
  String get tvScanTitle => 'Откройте на телефоне';

  @override
  String get tvScanBody => 'Наведите камеру телефона на этот код.';

  @override
  String get refresh => 'Обновить';

  @override
  String get premiumNotNow => 'Не сейчас';

  @override
  String get premiumLimitSheetTitle => 'Трафик на сегодня израсходован';

  @override
  String get premiumLimitWait => 'Подождать обновления';

  @override
  String get premiumLimitInvite =>
      'Пригласите друзей, чтобы получить больше трафика';

  @override
  String premiumLimitInviteNext(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня',
      many: '$days дней',
      few: '$days дня',
      one: '$days день',
    );
    return 'Ваш следующий друг добавит $amount в день, когда начнёт пользоваться Fortiva и наберёт $_temp0 использования. К сегодняшнему трафику это не добавится.';
  }

  @override
  String premiumLimitInviteNextNoDays(String amount) {
    return 'Ваш следующий друг добавит $amount в день, когда какое-то время попользуется Fortiva. К сегодняшнему трафику это не добавится.';
  }

  @override
  String get premiumLimitInviteNoAmount =>
      'Приглашённые друзья увеличивают ваш дневной трафик, когда начинают пользоваться Fortiva. К сегодняшнему трафику это не добавится.';

  @override
  String get premiumLimitInvitesFull =>
      'Ваши приглашения уже добавляют максимум трафика.';

  @override
  String get premiumLimitSeeInvites => 'Посмотреть приглашения';

  @override
  String get premiumLimitShareAgain => 'Поделиться ещё с одним другом';

  @override
  String get premiumNoDailyLimit => 'В Премиуме нет дневного лимита.';

  @override
  String get premiumCalmTitle => 'Хотите без дневного лимита?';

  @override
  String get premiumCalmBody =>
      'Премиум даёт безлимитный трафик. Бесплатный тариф остаётся как есть.';

  @override
  String get premiumNextStepTitle => 'Следующий шаг: Премиум';

  @override
  String get premiumNextStepBody =>
      'У вас уже максимум бесплатного трафика. В Премиуме нет дневного лимита.';

  @override
  String get premiumLockedTag => 'Премиум';

  @override
  String premiumLockedTitle(String place) {
    return 'Откройте $place с Премиумом';
  }

  @override
  String get premiumLockedBody =>
      'Это место только для Премиума. Ваши бесплатные серверы остаются прежними.';

  @override
  String get premiumHeadlineLimit => 'Без дневного лимита';

  @override
  String premiumHeadlineLocked(String place) {
    return 'Откройте $place с Премиумом';
  }

  @override
  String get premiumFreeStays => 'Бесплатный тариф работает и без Премиума.';

  @override
  String premiumEndsOn(String date) {
    return 'Премиум закончится $date';
  }

  @override
  String get premiumRenewBody =>
      'Продлите, чтобы сохранить безлимитный трафик. Продление добавляет время к текущей дате окончания.';

  @override
  String premiumEndedOn(String date) {
    return 'Премиум закончился $date. Снова действует бесплатный тариф.';
  }

  @override
  String get premiumRenew => 'Продлить';

  @override
  String get noticeChannelName => 'Сообщения от Fortiva';

  @override
  String get noticeChannelDescription =>
      'Новости и сообщения от команды Fortiva';

  @override
  String get noticesSettingTitle => 'Уведомления';

  @override
  String get noticesSettingOn =>
      'Включены. Сообщения от команды Fortiva могут приходить, даже когда приложение закрыто.';

  @override
  String get noticesSettingOff =>
      'Выключены. Включите их, чтобы получать сообщения от команды Fortiva, даже когда приложение закрыто.';

  @override
  String get noticesOffCard =>
      'Включите уведомления, чтобы получать сообщения от команды Fortiva, даже когда приложение закрыто.';

  @override
  String get noticesTurnOn => 'Включить';

  @override
  String get backgroundCard =>
      'Телефон может задерживать сообщения от команды Fortiva, пока приложение закрыто. Разрешите Fortiva работать в фоне, чтобы они до вас доходили.';

  @override
  String get backgroundHint =>
      'На следующем экране выберите Fortiva (если его нет в списке, покажите все приложения). Затем установите для батареи режим Без ограничений или разрешите автозапуск и работу в фоне.';

  @override
  String get backgroundAllow => 'Разрешить';

  @override
  String get backgroundNotNow => 'Не сейчас';

  @override
  String get backgroundSettingTitle => 'Сообщения при закрытом приложении';

  @override
  String get backgroundSettingSubtitle =>
      'Разрешите Fortiva работать в фоне, чтобы сообщения приходили, даже когда приложение закрыто.';

  @override
  String get backgroundCardData =>
      'Экономия трафика на телефоне может задерживать сообщения от команды Fortiva, пока приложение закрыто.';

  @override
  String get backgroundHintData =>
      'На следующем экране включите Неограниченный трафик.';

  @override
  String get apnGuideTitle => 'Более стабильное подключение на этой SIM';

  @override
  String get apnGuideBody =>
      'Ваш телефон не использует IPv6 на этой SIM. Если включить его, Fortiva будет лучше держать подключение.';

  @override
  String get apnGuideShowMe => 'Показать, как';

  @override
  String get apnGuideNotNow => 'Не сейчас';

  @override
  String get apnGuideSheetTitle => 'Включите IPv6 для этой SIM';

  @override
  String apnGuideStepOpen(String button) {
    return 'Нажмите «$button» (или откройте Настройки > Подключения > Мобильные сети > Точки доступа).';
  }

  @override
  String apnGuideStepAccessPoint(String apn) {
    return 'Нажмите на используемую точку доступа ($apn).';
  }

  @override
  String get apnGuideStepAccessPointAny =>
      'Нажмите на используемую точку доступа.';

  @override
  String get apnGuideStepProtocol =>
      'Нажмите «Протокол APN» и выберите «IPv4/IPv6».';

  @override
  String get apnGuideStepSave =>
      'Сохраните (на Samsung: меню из трёх точек, затем «Сохранить»).';

  @override
  String get apnGuideStepRestart =>
      'Выключите мобильные данные и включите их снова.';

  @override
  String get apnGuideUndo =>
      'Если мобильный интернет перестанет работать, верните протокол APN на IPv4.';

  @override
  String get apnGuideOpenSettings => 'Открыть настройки APN';

  @override
  String get homeStallSearching =>
      'Соединение перестало работать. Ищем другой путь.';

  @override
  String get homeStalled => 'Подключено, но данные не проходят';

  @override
  String get peerShareTitle => 'Помочь другу подключиться';

  @override
  String get peerShareSubtitle =>
      'Передайте на телефон друга то, что нужно Fortiva';

  @override
  String get peerShareBody =>
      'Если у друга не подключается Fortiva, его телефон может получить всё необходимое с вашего. Интернет для этого не нужен.';

  @override
  String peerShareSteps(String action) {
    return 'В Fortiva на его телефоне откройте «Настройки» и нажмите «$action». Затем покажите ему эти коды по очереди или отправьте ему всё сразу.';
  }

  @override
  String get peerShareLoading => 'Получаем самую свежую копию';

  @override
  String get peerShareNothing =>
      'На этом телефоне пока нет ничего свежего, что можно передать. Попробуйте позже.';

  @override
  String peerShareCodeOf(int current, int total) {
    return 'Код $current из $total';
  }

  @override
  String get peerSharePrevious => 'Назад';

  @override
  String get peerShareNext => 'Далее';

  @override
  String get peerShareCopy => 'Копировать';

  @override
  String get peerShareSend => 'Отправить';

  @override
  String get peerShareCopied => 'Скопировано. Вставьте это в чат с другом.';

  @override
  String get peerReceiveTitle => 'Получить помощь друга';

  @override
  String get peerReceiveSubtitle => 'Если по-другому подключиться не удаётся';

  @override
  String peerReceiveBody(String action) {
    return 'Попросите друга, у которого подключается Fortiva, открыть «Настройки» в Fortiva и нажать «$action». Затем получите всё с его телефона любым из этих способов.';
  }

  @override
  String get peerReceivePhotograph => 'Сфотографировать коды друга';

  @override
  String get peerReceivePhotographNext => 'Сфотографировать следующий код';

  @override
  String peerReceiveProgress(int have, int total) {
    return 'Считано кодов: $have из $total';
  }

  @override
  String get peerReceiveFile => 'Открыть файл от друга';

  @override
  String get peerReceivePaste => 'Вставить то, что прислал друг';

  @override
  String get peerReceiveNoCode =>
      'На этом фото код не найден. Поднесите телефон ближе, чтобы весь код был в кадре.';

  @override
  String get peerReceiveRefused =>
      'Fortiva не может это использовать. Попросите друга отправить ещё раз.';

  @override
  String get peerReceiveNotNewer =>
      'У вас уже есть это или что-то новее. Попробуйте подключиться снова или попросите помощи у кого-нибудь ещё из друзей.';

  @override
  String get peerReceiveTaken => 'Готово. Нажмите кнопку, чтобы подключиться.';

  @override
  String get peerReceiveUnavailable =>
      'На этом телефоне это недоступно. Попробуйте другой способ.';

  @override
  String get peerReceiveNothingToPaste =>
      'Пока ничего не скопировано. Скопируйте то, что прислал друг, и нажмите здесь снова.';

  @override
  String get peerOfferBody =>
      'Всё ещё не удаётся подключиться? Друг, у которого работает Fortiva, может помочь со своего телефона.';

  @override
  String get peerReceiveAgain =>
      'Этот код у вас уже есть. Попросите друга показать следующий.';

  @override
  String get peerReceivePasteNotOurs =>
      'То, что вы скопировали, не из Fortiva. Скопируйте сообщение друга целиком и попробуйте ещё раз.';

  @override
  String peerReceiveNoPhoto(String action) {
    return 'Камера не передала фото. Сделайте снимок в приложении камеры, затем нажмите «$action».';
  }

  @override
  String get peerReceiveFileHint =>
      'Файл из мессенджера, возможно, сначала нужно сохранить в «Загрузки».';

  @override
  String get homeTryingBackup =>
      'Больше ничего не подключилось. Пробуем резервную сеть.';

  @override
  String get homeConnectedBackup => 'Подключено через резервную сеть';

  @override
  String get backupNetwork => 'РЕЗЕРВНАЯ СЕТЬ';

  @override
  String get backupNetworkTitle => 'Резервная сеть';

  @override
  String get backupNetworkCaption =>
      'Используется, когда больше ничего не подключается. Может работать медленнее наших серверов.';

  @override
  String get backupNetworkPlace => 'Локация выбирается автоматически';

  @override
  String get speedTestStart => 'Начать тест';

  @override
  String get speedTestAgain => 'Повторить тест';

  @override
  String get speedTestRunning => 'Идёт тест';

  @override
  String get speedTestIdle =>
      'Узнайте, насколько быстрое у вас подключение сейчас.';

  @override
  String get speedTestPhasePing => 'Проверяем время отклика';

  @override
  String get speedTestPhaseDownload => 'Измеряем скорость скачивания';

  @override
  String get speedTestPhaseUpload => 'Измеряем скорость загрузки';

  @override
  String get speedTestDone => 'Тест завершён';

  @override
  String get speedTestFailed =>
      'Тест не удалось завершить. Проверьте подключение к интернету и попробуйте ещё раз.';

  @override
  String get speedTestUnit => 'Мбит/с';

  @override
  String get ipAddressLabel => 'IP-адрес';

  @override
  String get ipCopied => 'Адрес скопирован';

  @override
  String get ipLocation => 'Местоположение';

  @override
  String get ipProvider => 'Интернет-провайдер';

  @override
  String get ipOrganization => 'Организация';

  @override
  String get ipTimeZone => 'Часовой пояс';

  @override
  String get ipCoordinates => 'Координаты';

  @override
  String get ipCheckFailed => 'Не удалось проверить ваш адрес';

  @override
  String get historyAverage => 'В среднем';

  @override
  String get historyRecentDays => 'Последние дни';

  @override
  String yesterdayAt(String time) {
    return 'Вчера в $time';
  }

  @override
  String dateAt(String date, String time) {
    return '$date в $time';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds с';
  }

  @override
  String get stageOwn => 'Серверы Fortiva';

  @override
  String get stageCommunity => 'Серверы сообщества';

  @override
  String stageProgress(int n, int total) {
    return 'Этап $n из $total';
  }

  @override
  String get stageTryingOwn => 'Пробуем серверы Fortiva';

  @override
  String get stageTryingCommunity => 'Пробуем серверы сообщества';

  @override
  String get stageOwnFailedTryingCommunity =>
      'Серверы Fortiva здесь не подключились. Теперь пробуем серверы сообщества.';

  @override
  String stageLastWorked(String server) {
    return 'Последний рабочий сервер: $server';
  }

  @override
  String stageTriedBlocked(int count) {
    return 'Проверено путей: $count, здесь заблокированы';
  }

  @override
  String stageTriedFailed(int count) {
    return 'Проверено путей: $count, ни один не подключился';
  }

  @override
  String get stageNotConnected => 'Не подключилось';

  @override
  String get stageConnected => 'Подключено здесь';

  @override
  String get stageSkipped => 'В этот раз пропущено';

  @override
  String stageMoreToCheck(int count) {
    return 'Ещё путей к проверке: $count';
  }

  @override
  String stageNextTry(String stage, String time) {
    return 'Следующая попытка через $time. Начнём с этапа «$stage».';
  }

  @override
  String get searchSlowHint =>
      'Это может занять минуту-другую. Нажмите кнопку, чтобы остановить поиск.';

  @override
  String get searchStopped => 'Поиск остановлен';

  @override
  String get homeConnectedCommunity => 'Подключено через сервер сообщества';

  @override
  String get stageGettingServers => 'Получаем ваши серверы';

  @override
  String stageNextTryStarting(String stage) {
    return 'Начинаем следующую попытку с этапа «$stage»';
  }
}
