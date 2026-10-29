// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class SKo extends S {
  SKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'FortivaVPN';

  @override
  String get statusDisconnected => '연결 해제됨';

  @override
  String get statusConnecting => '연결 중';

  @override
  String get statusConnected => '연결됨';

  @override
  String get statusDisconnecting => '연결 해제 중';

  @override
  String get statusError => '오류';

  @override
  String get statusVerifying => '확인 중...';

  @override
  String get disconnect => '연결 해제';

  @override
  String get connectBtn => '연결';

  @override
  String get disconnectBtn => '연결 해제';

  @override
  String get pleaseWait => '잠시 기다려 주세요';

  @override
  String get locationLabel => '위치:';

  @override
  String get selectServer => '서버 선택';

  @override
  String get serverLocation => '서버 위치';

  @override
  String get searchServers => '서버 검색';

  @override
  String get locationsTitle => '위치';

  @override
  String get sortLatency => '정렬: 지연 시간';

  @override
  String get sortAZ => '정렬: A-Z';

  @override
  String get sortedByLatency => '지연 시간순 정렬';

  @override
  String get sortedAZ => 'A–Z 정렬';

  @override
  String get pingAll => '전체 핑';

  @override
  String get pinging => '핑 중...';

  @override
  String get ping => '핑';

  @override
  String get stop => '중지';

  @override
  String get fastestServer => '가장 빠른 서버';

  @override
  String get timeout => '시간 초과';

  @override
  String get tabCommunity => '커뮤니티';

  @override
  String get tabFree => '무료';

  @override
  String get tabPremium => '프리미엄';

  @override
  String get noCommunityServers => '커뮤니티 서버 없음';

  @override
  String get communityLoadFailed => '이 목록을 불러오지 못했습니다';

  @override
  String get communityRetry => '다시 시도';

  @override
  String get officialTabExplainer =>
      'Fortiva가 운영하고 유지하는 서버입니다. 앱을 쓰는 모든 사람이 함께 씁니다. 여기서 시작하세요.';

  @override
  String get communityTabExplainer => '추가 연결 옵션입니다. 속도와 이용 가능 여부는 달라질 수 있습니다.';

  @override
  String get noFreeServers => '무료 서버 없음';

  @override
  String get noPremiumServers => '프리미엄 서버 없음';

  @override
  String noResultsFor(String query) {
    return '\"$query\"에 대한 결과 없음';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get freeBadge => '무료';

  @override
  String get settings => '설정';

  @override
  String get connection => '연결';

  @override
  String get dnsConfiguration => 'DNS 설정';

  @override
  String get customDns => '사용자 정의 DNS 서버';

  @override
  String get about => '소개';

  @override
  String get privacyPolicy => '개인정보 처리방침';

  @override
  String get contactUs => '문의하기';

  @override
  String get rateOnGooglePlay => 'Google Play에서 Fortiva 평가하기';

  @override
  String get website => '웹사이트';

  @override
  String get copyright => '© 2026 NimusAI';

  @override
  String get version => '버전';

  @override
  String get language => '언어';

  @override
  String get languageSubtitle => '앱 표시 언어';

  @override
  String get whatIsDns => 'DNS란?';

  @override
  String get dnsExplanation =>
      'DNS(도메인 이름 시스템)는 인터넷의 전화번호부입니다. 웹사이트 이름을 IP 주소로 변환합니다.\n\nDNS를 사용자 정의하면:\n• 연결 속도 향상 ⚡\n• 개인정보 보호 강화 🔒\n• 검열 차단 우회 🌍';

  @override
  String get configuration => '설정';

  @override
  String get primaryDns => '기본 DNS';

  @override
  String get primaryDnsHint => '기본값: 1.1.1.1';

  @override
  String get secondaryDns => '보조 DNS (선택 사항)';

  @override
  String get secondaryDnsHint => '기본값: 8.8.8.8';

  @override
  String get saveConfiguration => '설정 저장';

  @override
  String get dnsSaved => 'DNS 설정이 저장되었습니다';

  @override
  String get invalidPrimaryDns => '잘못된 기본 DNS IP 주소';

  @override
  String get invalidSecondaryDns => '잘못된 보조 DNS IP 주소';

  @override
  String get statistics => '통계';

  @override
  String get overview => '개요';

  @override
  String get connectionsLabel => '연결 횟수';

  @override
  String get totalTime => '총 시간';

  @override
  String get dataUsage => '데이터 사용량';

  @override
  String get uploaded => '업로드';

  @override
  String get downloaded => '다운로드';

  @override
  String get total => '합계';

  @override
  String lastUpdated(String date) {
    return '마지막 업데이트: $date';
  }

  @override
  String today(String time) {
    return '오늘 $time';
  }

  @override
  String get yesterday => '어제';

  @override
  String daysAgo(int count) {
    return '$count일 전';
  }

  @override
  String get noDataYet => '아직 데이터 없음';

  @override
  String get connectToStart => 'VPN에 연결하여 추적 시작';

  @override
  String get errorConnectionFailed => '연결 실패';

  @override
  String get errorServerNotWorking => '서버가 작동하지 않음 — 다른 서버를 시도하세요';

  @override
  String get errorServerNotForwarding => '서버가 트래픽을 전달하지 않음';

  @override
  String get errorUnexpected => '예기치 않은 오류';

  @override
  String get errorDisconnectionFailed => '연결 해제 실패';

  @override
  String get errorFailedToRegister => '기기 등록 실패';

  @override
  String get ipInformation => 'IP 정보';

  @override
  String get connectionAnalytics => '연결 분석';

  @override
  String get recentSessions => '최근 세션';

  @override
  String get speedTest => '속도 테스트';

  @override
  String get startTest => '테스트 시작';

  @override
  String get download => '다운로드';

  @override
  String get upload => '업로드';

  @override
  String get testingViaVpn => 'VPN을 통해 테스트';

  @override
  String get testingDirect => '직접 연결 테스트';

  @override
  String get splitTunneling => '스플릿 터널링';

  @override
  String get splitTunnelingDescription => 'VPN 터널을 우회할 앱 카테고리를 선택하세요.';

  @override
  String get enableSplitTunneling => '스플릿 터널링 활성화';

  @override
  String get splitTunnelActive => '선택된 앱이 VPN을 우회합니다';

  @override
  String get splitTunnelInactive => '모든 트래픽이 VPN을 통과합니다';

  @override
  String get bypassVpnFor => 'VPN 우회 대상';

  @override
  String get tools => '도구';

  @override
  String get settingsGeneral => '일반';

  @override
  String get shareDiagnosticsTitle => '연결 진단 정보 공유';

  @override
  String get shareDiagnosticsBody =>
      '연결 보고서, 통신사와 국가, 휴대폰 모델과 Android 버전, 그리고 메시지, 프리미엄 안내, 초대 카드를 보거나 탭했는지 여부를 보냅니다. 회원님이 여는 페이지나 보내는 내용은 절대 보지 않습니다.';

  @override
  String get security => '보안';

  @override
  String get privacyDashboard => '개인정보 대시보드';

  @override
  String get privacyDashboardSubtitle => 'IP 정보 & 유출 방지';

  @override
  String get connectionAnalyticsSubtitle => '세션 기록 & 차트';

  @override
  String get speedTestSubtitle => '연결 속도 테스트';

  @override
  String get splitTunnelingSubtitle => '앱 VPN 라우팅 선택';

  @override
  String get splashTagline => '어디에 있든, 안전한 프라이빗 접속';

  @override
  String get openSourceLicence => '오픈소스 라이선스';

  @override
  String get sourceOfferTitle => '오픈소스 라이선스';

  @override
  String get sourceOfferBody =>
      'Fortiva VPN은 GNU General Public License v3에 따른 자유 소프트웨어입니다. Xray-core와 다른 오픈소스 프로젝트를 기반으로 만들어졌습니다.\n\n설치한 버전의 전체 소스 코드를 받을 권리가 있습니다. 요청하려면 앱 버전을 적어 admin@fortivavpn.com으로 이메일을 보내 주세요. 이 제안은 이 버전을 받은 날로부터 3년 동안 유효합니다.';

  @override
  String get close => '닫기';

  @override
  String get account => '계정';

  @override
  String get deleteAccount => '계정 삭제';

  @override
  String get deleteAccountSubtitle => '이 기기와 데이터를 영구히 삭제합니다';

  @override
  String get deleteAccountConfirmTitle => '계정을 삭제할까요?';

  @override
  String get deleteAccountConfirmBody =>
      '기기 등록, 회원님을 위해 만들어진 전용 서버, 지원팀과의 채팅 메시지가 삭제됩니다. 이 휴대폰의 연결 기록도 지워집니다.\n\n되돌릴 수 없습니다. 앱을 다시 열면 언제든 처음부터 시작할 수 있습니다.';

  @override
  String deleteAccountConfirmRetention(int days) {
    return '계정 기록은 즉시 삭제됩니다. 백업본과 익명 서버 로그는 $days일 이내에 지워집니다.';
  }

  @override
  String get deleteAccountConfirmRetentionNoDays =>
      '계정 기록은 즉시 삭제됩니다. 백업본과 익명 서버 로그는 개인정보 처리방침에서 정한 기간 안에 지워집니다.';

  @override
  String get deleteAccountCancel => '계정 유지';

  @override
  String get deleteAccountConfirm => '삭제';

  @override
  String get deleteAccountInProgress => '계정을 삭제하는 중';

  @override
  String get deleteAccountDone => '계정이 삭제되었습니다.';

  @override
  String get deleteAccountFailed => '계정을 삭제하지 못했습니다. 연결을 확인한 후 다시 시도해 주세요.';

  @override
  String get homeTapToConnect => '탭하여 연결';

  @override
  String get homeChecking => '연결 확인 중';

  @override
  String get homePreparing => '서버를 준비하는 중';

  @override
  String get homeDisconnecting => '연결을 끊는 중';

  @override
  String get homeFindingPath => '경로를 찾는 중';

  @override
  String get diagCheckingInternet => '인터넷 확인 중';

  @override
  String get diagInternationalCut => '이 네트워크에서 국제 인터넷이 끊겼습니다';

  @override
  String diagPathRow(String city, int n) {
    return '$city, 경로 $n';
  }

  @override
  String get diagOpen => '열림';

  @override
  String get diagBlocked => '차단됨';

  @override
  String get diagSkipped => '오늘 건너뜀';

  @override
  String diagConnectingThrough(String city) {
    return '$city을(를) 통해 연결 중';
  }

  @override
  String get diagVerifying => '트래픽 확인 중';

  @override
  String get diagNoInternet => '지금 휴대폰에 인터넷 연결이 없습니다.';

  @override
  String get diagCutOff => '지금 사용 중인 네트워크에서 국제 인터넷에 연결할 수 없습니다. 탭하여 다시 시도하세요.';

  @override
  String get diagNothingOpen => '지금은 모든 경로가 차단되어 있습니다. 탭하여 다시 시도하세요.';

  @override
  String get homeTryingAgain => '지금은 모든 경로가 차단되어 있습니다. 잠시 후 다시 시도합니다.';

  @override
  String get homeCutOffTryingAgain =>
      '지금 사용 중인 네트워크에서 국제 인터넷에 연결할 수 없습니다. 잠시 후 다시 시도합니다.';

  @override
  String get homeOfflineTryingAgain => '지금 휴대폰에 인터넷 연결이 없습니다. 잠시 후 다시 시도합니다.';

  @override
  String get diagPathFailed => '경로는 열려 있었지만 VPN 터널이 연결되지 않았습니다. 탭하여 다시 시도하세요.';

  @override
  String get openVpnSettings => 'VPN 설정 열기';

  @override
  String get yourServer => '내 서버';

  @override
  String get yourServerCaption => '나만의 서버입니다. 다른 사람은 연결하지 않습니다.';

  @override
  String get ourServer => '우리 서버';

  @override
  String get ourServerCaption =>
      'Fortiva가 운영하고 모두가 함께 씁니다. 내 서버가 준비될 때까지 사용합니다.';

  @override
  String get communityServer => '커뮤니티 서버';

  @override
  String get communityServerCaption => '추가 연결 옵션입니다. 언제든지 작동이 멈출 수 있습니다.';

  @override
  String communityServerNumber(String n) {
    return '커뮤니티 서버 $n';
  }

  @override
  String get myServersTitle => '내 서버';

  @override
  String get myServersExplainer =>
      'Fortiva는 기기마다 지역별 전용 서버를 제공하며, 인증 정보는 이 설치본에만 속합니다. 계정은 필요하지 않습니다.';

  @override
  String get myServersInUse => '사용 중';

  @override
  String get myServersEmpty => '아직 배정된 서버가 없습니다';

  @override
  String get myServersRetry => '다시 시도';

  @override
  String get myServersBlockedTitle => '오늘의 데이터를 모두 사용했습니다';

  @override
  String get myServersBlockedWait => '할당량은 자동으로 초기화됩니다. 잠시 후 확인해 주세요.';

  @override
  String myServersMoved(String place) {
    return '이제 $place을(를) 사용합니다';
  }

  @override
  String get copyLink => '링크 복사';

  @override
  String get linkCopied => '링크를 복사했습니다';

  @override
  String quotaUsedToday(String used, String limit) {
    return '오늘 $limit 중 $used 사용';
  }

  @override
  String get quotaUsedUp => '오늘의 데이터를 모두 사용함';

  @override
  String get quotaUnlimited => '무제한 데이터';

  @override
  String get quotaDaily => '일일 데이터';

  @override
  String get quotaLimitReached => '일일 한도에 도달함';

  @override
  String quotaLeftOf(String left, String limit) {
    return '$limit 중 $left 남음';
  }

  @override
  String get quotaResetsShortly => '곧 초기화됩니다';

  @override
  String quotaResetsInHours(int hours) {
    return '$hours시간 후 초기화';
  }

  @override
  String quotaResetsInMinutes(int minutes) {
    return '$minutes분 후 초기화';
  }

  @override
  String get myServersSubtitle => '이 기기에 배정된 서버';

  @override
  String get sharedServersTitle => '공용 서버';

  @override
  String get sharedServersSubtitle => '예비로 쓰는 공개 지역';

  @override
  String get tabOfficial => '우리 서버';

  @override
  String get noOfficialServers => '지금은 Fortiva 서버가 없습니다';

  @override
  String get inviteTitle => '친구 초대';

  @override
  String get inviteSubtitle => '매일 더 많은 데이터 받기';

  @override
  String get inviteYourCode => '내 초대 코드';

  @override
  String get inviteShareAction => '초대 공유';

  @override
  String get inviteCopyAction => '코드 복사';

  @override
  String get inviteCodeCopied => '코드가 복사됨';

  @override
  String inviteShareMessage(String code, String url) {
    return '제가 잘 쓰고 있는 무료 VPN, Fortiva예요. 가입 없이 쓸 수 있어요.\n이 링크로 설치하세요:\n$url\n초대 코드: $code';
  }

  @override
  String get inviteHowItWorks => '작동 방식';

  @override
  String inviteHowItWorksBody(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '서로 다른 $days일에',
      one: '$days일 동안',
    );
    return '코드를 공유하세요. 누군가 앱을 설치하고 코드를 입력한 뒤 $_temp0 VPN을 사용하면 하루 데이터가 $amount 늘어나고 계속 유지됩니다.';
  }

  @override
  String inviteHowItWorksBodyNoAmount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '서로 다른 $days일에',
      one: '$days일 동안',
    );
    return '코드를 공유하세요. 누군가 앱을 설치하고 코드를 입력한 뒤 $_temp0 VPN을 사용하면 하루 데이터가 늘어나고 계속 유지됩니다.';
  }

  @override
  String inviteHowItWorksBodyNoDays(String amount) {
    return '코드를 공유하세요. 누군가 앱을 설치하고 코드를 입력한 뒤 한동안 VPN을 사용하면 하루 데이터가 $amount 늘어나고 계속 유지됩니다.';
  }

  @override
  String get inviteHowItWorksBodyNoAmountNoDays =>
      '코드를 공유하세요. 누군가 앱을 설치하고 코드를 입력한 뒤 한동안 VPN을 사용하면 하루 데이터가 늘어나고 계속 유지됩니다.';

  @override
  String inviteHowItWorksCap(String max) {
    return '초대로 받을 수 있는 데이터는 하루 최대 $max까지입니다.';
  }

  @override
  String get inviteStatInvited => '초대함';

  @override
  String get inviteStatEarning => '조건 충족';

  @override
  String get inviteStatBonus => '보너스 데이터';

  @override
  String inviteBonusPerDay(String amount) {
    return '하루 +$amount';
  }

  @override
  String get inviteNoBonusYet => '아직 보너스 없음';

  @override
  String invitePendingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '초대 $count건이 아직 조건을 채우지 못했습니다',
      one: '초대 1건이 아직 조건을 채우지 못했습니다',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String inviteJoinedWith(String code) {
    return '코드 $code로 참여했습니다';
  }

  @override
  String get inviteLoadFailed => '초대 코드를 불러오지 못했습니다';

  @override
  String get inviteRetry => '다시 시도';

  @override
  String get inviteHaveCodeTitle => '초대 코드가 있나요?';

  @override
  String inviteHaveCodeSubtitle(int hours) {
    return '설치 후 $hours시간 안에 입력하세요';
  }

  @override
  String get inviteHaveCodeSubtitleNoHours => '설치하고 나서 되도록 빨리 입력하세요';

  @override
  String get inviteEnterCodeHint => '초대 코드';

  @override
  String get inviteApplyAction => '적용';

  @override
  String get inviteNotNowAction => '나중에';

  @override
  String inviteClaimAccepted(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '서로 다른 $days일에',
      one: '$days일 동안',
    );
    return '초대를 받았습니다. 오늘부터 $_temp0 VPN을 사용하면 초대가 계산됩니다.';
  }

  @override
  String get inviteClaimAcceptedNoDays =>
      '초대를 받았습니다. 오늘부터 한동안 VPN을 사용하면 초대가 계산됩니다.';

  @override
  String get inviteClaimAlready => '이 기기는 이미 초대 코드를 사용했습니다';

  @override
  String get inviteClaimRejected => '코드가 적용되지 않았습니다. 확인 후 다시 시도하세요';

  @override
  String get inviteClaimNetwork => '서버에 연결하지 못했습니다. 다시 시도하세요';

  @override
  String get inviteCardTitle => 'Fortiva 잘 쓰고 있나요? 친구에게도 보내 주세요';

  @override
  String get inviteCardBody => '설치 링크를 보내 주면 친구도 무료로 연결할 수 있어요.';

  @override
  String inviteCardReward(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '친구가 Fortiva를 쓰기 시작하면 프리미엄 $days일을 받아요.',
    );
    return '$_temp0';
  }

  @override
  String get inviteCardRewardNoAmount => '친구가 Fortiva를 쓰기 시작하면 프리미엄을 선물로 받아요.';

  @override
  String get inviteSendTelegram => 'Telegram';

  @override
  String get inviteSendWhatsApp => 'WhatsApp';

  @override
  String get inviteCopyLink => '링크 복사';

  @override
  String get inviteOtherApps => '다른 앱';

  @override
  String get inviteLinkCopied => '초대 메시지가 복사됨';

  @override
  String get invitePasteBody => '친구가 보낸 메시지에서 코드를 복사해 여기에 붙여넣으세요.';

  @override
  String get invitePasteAction => '붙여넣기';

  @override
  String get inviteErrorTooLate => '이 휴대폰에서 초대 코드를 입력할 수 있는 기간이 지났습니다.';

  @override
  String get inviteErrorUnknown => '이 코드를 찾을 수 없습니다. 친구의 메시지에서 다시 복사하세요.';

  @override
  String get inviteErrorOwnCode => '내 초대 코드입니다. 친구의 코드를 입력하세요.';

  @override
  String get inviteErrorMutual => '친구와 서로를 초대할 수는 없습니다.';

  @override
  String inviteHowItWorksPremium(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Fortiva를 쓰기 시작한 친구마다 프리미엄 $days일도 함께 받습니다.',
    );
    return '$_temp0';
  }

  @override
  String inviteHowItWorksPremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '초대로 받을 수 있는 프리미엄은 최대 $max일입니다.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeLive =>
      '보너스는 친구들이 Fortiva를 계속 사용하는 동안 이어집니다. 친구가 사용을 멈추면 보너스가 줄어들 수 있습니다.';

  @override
  String inviteTreeNext(String amount) {
    return '다음 친구는 조건 충족이 되고 활성이면 하루 $amount를 늘려 줍니다.';
  }

  @override
  String inviteTreeKept(String amount) {
    return '보너스는 하루 $amount 아래로 내려가지 않습니다. 이전 초대로 받던 보너스입니다. 이 양은 내 초대가 삭제될 때만 줄어들 수 있습니다.';
  }

  @override
  String get inviteTreeSlotsTitle => '내 자리';

  @override
  String get inviteTreeSlotActive => '활성';

  @override
  String get inviteTreeSlotNotActive => '지금 비활성';

  @override
  String get inviteTreeSlotEmpty => '빈 자리';

  @override
  String inviteTreePaysNow(String amount) {
    return '지금 하루 +$amount';
  }

  @override
  String inviteTreePairFull(String amount) {
    return '둘 다 활성이면 하루 +$amount';
  }

  @override
  String get inviteTreeNothingYet => '아직 없음';

  @override
  String get inviteTreeFriendsTitle => '내 자리를 통해';

  @override
  String get inviteTreeRowFriends => '내 자리에';

  @override
  String inviteTreeRowSteps(int steps) {
    String _temp0 = intl.Intl.pluralLogic(
      steps,
      locale: localeName,
      other: '$steps걸음 떨어진 곳',
    );
    return '$_temp0';
  }

  @override
  String inviteTreeRowPeople(int people, int active) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people명',
    );
    return '$_temp0, 활성 $active명';
  }

  @override
  String inviteTreeHowSlots(int slots) {
    String _temp0 = intl.Intl.pluralLogic(
      slots,
      locale: localeName,
      other: '코드를 공유하세요. 조건을 채운 처음 $slots명의 친구가 둘씩 짝을 지어 내 자리를 채웁니다.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeHowSlotsNoNumber =>
      '코드를 공유하세요. 먼저 조건을 채운 친구들이 둘씩 짝을 지어 내 자리를 채웁니다.';

  @override
  String get inviteTreeHowPair => '짝의 둘 다 활성이면 더 많이 받습니다.';

  @override
  String get inviteTreeHowFriendsSlots =>
      '내 자리가 다 차면, 그다음에 조건을 채운 내 친구는 나에게서 더 먼 다음 빈 자리에 들어갑니다. 그 친구들도 내 데이터를 늘려 주지만, 멀수록 조금씩 줄어듭니다.';

  @override
  String get inviteTreeHowOthers =>
      '내 첫 번째 짝에는 내가 초대하지 않은 사람이 들어올 수도 있습니다. 그 사람들도 똑같이 내 데이터를 늘려 줍니다.';

  @override
  String inviteTreeHowActive(int days, int window) {
    return '최근 $window일 중 $days일 이상 VPN을 사용한 친구는 활성으로 계산됩니다.';
  }

  @override
  String get inviteTreeHowActiveNoNumber => 'VPN을 계속 사용하는 친구는 활성으로 계산됩니다.';

  @override
  String inviteTreeHowCap(String max) {
    return '초대로 하루 최대 $max까지 늘릴 수 있습니다.';
  }

  @override
  String get inviteTreeHowCapNoAmount => '초대로 늘릴 수 있는 데이터에는 하루 한도가 있습니다.';

  @override
  String get inviteTreeIntroTitle => '친구가 데이터를 늘리는 방법';

  @override
  String get inviteTreeIntroOpen => '차근차근 보기';

  @override
  String inviteTreeIntroStep(int current, int total) {
    return '$current/$total';
  }

  @override
  String get inviteTreeIntroSkip => '건너뛰기';

  @override
  String get inviteTreeIntroNext => '다음';

  @override
  String get inviteTreeIntroBack => '이전';

  @override
  String get inviteTreeIntroDone => '완료';

  @override
  String get inviteTreeIntroYou => '나';

  @override
  String get inviteTreeIntroSlotsTitle => '친구들이 짝을 지어 내 자리를 채웁니다';

  @override
  String get inviteTreeIntroSlotsArt =>
      '나, 내 초대 코드, 짝을 이룬 내 자리. 자리마다 비어 있는지, 들어간 사람이 활성인지 지금 비활성인지 표시됩니다.';

  @override
  String get inviteTreeIntroPairTitle => '짝은 둘 다 활성일 때 가장 많이 늘려 줍니다';

  @override
  String inviteTreeIntroPairBoth(String full, String one) {
    return '첫 번째 짝의 친구가 둘 다 활성이면 하루 $full씩 늘어납니다. 한쪽만 활성이면 하루 $one씩 늘어납니다.';
  }

  @override
  String inviteTreeIntroPairBothOnly(String full) {
    return '첫 번째 짝의 친구가 둘 다 활성이면 하루 $full씩 늘어납니다. 한쪽만 활성이면 늘어나지 않습니다.';
  }

  @override
  String inviteTreeIntroPairNoOne(String full) {
    return '첫 번째 짝의 친구가 둘 다 활성이면 하루 $full씩 늘어납니다. 한쪽만 활성이면 덜 늘어납니다.';
  }

  @override
  String get inviteTreeIntroPairOthersLess => '다른 짝은 덜 늘려 줍니다.';

  @override
  String inviteTreeIntroAdds(String amount) {
    return '하루 +$amount';
  }

  @override
  String get inviteTreeIntroYourFriend => '내 친구';

  @override
  String get inviteTreeIntroTotalTitle => '친구에게서 받는 데이터';

  @override
  String get inviteTreeIntroTotalNow => '지금 친구에게서';

  @override
  String get inviteTreeIntroTotalMost => '초대로 늘릴 수 있는 최대치';

  @override
  String get inviteTreeIntroTotalKept => '이전 초대에서 이어진 양';

  @override
  String inviteTreeIntroTotalReach(String max) {
    return '무료 데이터와 친구에게서 받는 데이터를 합쳐 하루 최대 $max까지 늘어날 수 있습니다.';
  }

  @override
  String inviteTreeIntroPerDay(String amount) {
    return '하루 $amount';
  }

  @override
  String inviteTreeSheetNext(String amount) {
    return '다음 친구는 조건 충족이 되고 활성이면 하루 $amount를 늘려 줍니다. 오늘 데이터에는 더해지지 않습니다.';
  }

  @override
  String get inviteTreeHero => '친구가 매일 데이터를 늘려 줍니다';

  @override
  String inviteTreePremiumEach(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '내 코드로 조건을 충족한 친구마다 내 프리미엄도 $days일 늘어납니다.',
    );
    return '$_temp0';
  }

  @override
  String inviteTreePremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '초대로 받을 수 있는 프리미엄은 최대 $max일입니다.',
    );
    return '$_temp0';
  }

  @override
  String inviteTreeIntroSlotsBody(int slots) {
    String _temp0 = intl.Intl.pluralLogic(
      slots,
      locale: localeName,
      other:
          '내 코드로 가입한 친구는 내 하루 데이터를 늘려 줄 수 있습니다. 친구를 위한 자리가 $slots개 있습니다. 자리마다 친구가 들어가고, 자리는 짝을 이룹니다. 첫 번째 짝부터 채워집니다. 자리가 다 차도 친구는 계속 가입할 수 있습니다.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeIntroSlotsBodyNoNumber =>
      '내 코드로 가입한 친구는 내 하루 데이터를 늘려 줄 수 있습니다. 친구를 위한 자리가 있습니다. 자리마다 친구가 들어가고, 자리는 짝을 이룹니다. 첫 번째 짝부터 채워집니다. 자리가 다 차도 친구는 계속 가입할 수 있습니다.';

  @override
  String get inviteTreeIntroJoinTitle => '친구가 자리에 들어가는 방법';

  @override
  String inviteTreeIntroJoinCode(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '친구는 Fortiva를 설치하고 $hours시간 안에 자신의 초대 화면에서 내 코드를 입력해야 합니다.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeIntroJoinCodeNoNumber =>
      '친구는 Fortiva를 설치하고 얼마 지나지 않아 자신의 초대 화면에서 내 코드를 입력해야 합니다.';

  @override
  String inviteTreeIntroJoinQualify(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '그다음 서로 다른 $days일에 VPN을 사용해야 합니다. 그러면 조건 충족이 되고 다음 빈 자리에 들어갑니다.',
      one: '그다음 $days일 동안 VPN을 사용해야 합니다. 그러면 조건 충족이 되고 다음 빈 자리에 들어갑니다.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeIntroJoinQualifyNoNumber =>
      '그다음 한동안 VPN을 사용해야 합니다. 그러면 조건 충족이 되고 다음 빈 자리에 들어갑니다.';

  @override
  String get inviteTreeIntroJoinPlay =>
      '친구가 내 링크로 Google Play에서 설치하면 코드가 자동으로 입력됩니다.';

  @override
  String get inviteTreeIntroJoinWaiting =>
      '조건 충족이 되기 전까지 내 초대 화면에서는 \"초대함\"에 포함되지만, \"조건 충족\"에는 아직 포함되지 않습니다.';

  @override
  String get inviteTreeIntroJoinStepCode => '내 코드 입력';

  @override
  String get inviteTreeIntroJoinStepUse => 'VPN 사용';

  @override
  String get inviteTreeIntroJoinStepSlot => '자리에 들어감';

  @override
  String get inviteTreeIntroJoinArt =>
      '친구가 내 코드를 입력하고, 서로 다른 날에 VPN을 사용한 뒤, 다음 빈 자리에 들어갑니다.';

  @override
  String get inviteTreeIntroPairsBody =>
      '짝마다 내 데이터를 늘려 줄 수 있습니다. 짝의 둘 다 활성일 때 가장 많이 늘려 줍니다.';

  @override
  String get inviteTreeIntroPairsCaption => '짝마다 하루에 내 데이터에 더해 주는 양';

  @override
  String get inviteTreeIntroBothActive => '둘 다 활성';

  @override
  String get inviteTreeIntroOneActive => '한쪽만 활성';

  @override
  String inviteTreeIntroPlus(String amount) {
    return '+$amount';
  }

  @override
  String get inviteTreeIntroNothing => '없음';

  @override
  String get inviteTreeIntroPairNow => '강조된 양이 지금 내 짝들이 늘려 주는 양입니다.';

  @override
  String get inviteTreeIntroPairsArt =>
      '내 짝들과, 둘 다 활성일 때와 한쪽만 활성일 때 짝마다 하루에 늘려 주는 양.';

  @override
  String get inviteTreeIntroActiveTitle => '친구는 활성인 동안 데이터를 늘려 줍니다';

  @override
  String get inviteTreeIntroActiveStops =>
      '친구가 Fortiva 사용을 멈추면 그 짝이 늘려 주는 양이 줄고, 내 보너스도 줄어들 수 있습니다. 친구의 자리는 그대로입니다. 다시 Fortiva를 사용하면 그 짝이 다시 더 많이 늘려 줍니다.';

  @override
  String get inviteTreeIntroActiveFar =>
      '더 먼 곳에서 내 데이터를 늘려 주는 사람들도 활성인 동안에만 계산됩니다.';

  @override
  String get inviteTreeIntroActiveArt =>
      '친구가 Fortiva 사용을 멈춘 짝. 이제 이 짝은 덜 늘려 줍니다.';

  @override
  String get inviteTreeIntroFullTitle => '자리가 다 찼을 때';

  @override
  String get inviteTreeIntroFullBody =>
      '내 자리가 모두 차면, 다음 친구는 내 자리에 있는 사람의 첫 번째 짝에 들어갑니다. 순서는 내 첫 번째 자리부터입니다. 그 짝은 그 사람의 데이터를 늘려 주고, 내 데이터는 덜 늘려 줍니다.';

  @override
  String get inviteTreeIntroFullLess =>
      '자리가 멀수록 내 데이터를 덜 늘려 줍니다. 아주 먼 자리는 아무것도 더해 주지 않습니다.';

  @override
  String get inviteTreeIntroNextFriend => '다음 친구';

  @override
  String get inviteTreeIntroLaterFriend => '나중에 올 친구';

  @override
  String get inviteTreeIntroFullArt =>
      '나중에 올 친구가 내 자리에 있는 사람의 첫 번째 짝의 빈 자리에 들어갑니다. 그 짝은 그 사람의 데이터를 늘려 주고, 내 데이터는 덜 늘려 줍니다.';

  @override
  String get inviteTreeIntroOthersTitle => '첫 번째 짝에는 내가 초대하지 않은 사람이 들어올 수 있습니다';

  @override
  String get inviteTreeIntroOthersWhy =>
      '나는 친구의 코드로 가입했습니다. 그 친구의 자리가 다 차면, 그 친구의 다음 친구들이 내 첫 번째 짝의 빈 자리에 들어올 수 있습니다. 다른 사람의 친구들도 들어올 수 있습니다. 누가 들어오든 내 친구와 똑같이 내 데이터를 늘려 줍니다.';

  @override
  String get inviteTreeIntroOthersYours =>
      '내 친구들은 내 다른 빈 자리를 채우고, 그다음에는 더 먼 빈 자리에 들어갑니다.';

  @override
  String get inviteTreeIntroNotInvited => '내가 초대하지 않음';

  @override
  String get inviteTreeIntroOthersArt =>
      '내 첫 번째 짝의 예. 내가 초대한 친구와 내가 초대하지 않은 사람이 있습니다. 둘 다 활성인 동안 내 데이터를 늘려 줍니다.';

  @override
  String get inviteTreeIntroShareTitle => 'Fortiva를 사용할 친구를 초대하세요';

  @override
  String get inviteTreeIntroShareBody =>
      '친구는 활성인 동안에만 내 데이터를 늘려 줍니다. VPN이 필요한 친구에게 초대를 보내세요.';

  @override
  String get inviteTreeQaTitle => '질문과 답변';

  @override
  String get inviteTreeQaCountQ => '친구가 내 코드를 입력했습니다. 언제 자리에 들어가나요?';

  @override
  String get inviteTreeQaCountDay =>
      '그날 VPN으로 데이터를 조금이라도 사용한 날만 계산됩니다. 앱을 여는 것만으로는 부족합니다. 이 날짜에는 기한이 없습니다.';

  @override
  String get inviteTreeQaCountOther =>
      '이미 코드를 입력한 휴대폰은 다른 코드를 입력할 수 없습니다. 나와 친구가 서로의 코드를 입력할 수도 없습니다.';

  @override
  String get inviteTreeQaDownQ => '보너스가 왜 줄었나요?';

  @override
  String get inviteTreeQaDownA =>
      '내 데이터를 늘려 주던 사람이 지금 활성이 아닙니다. 내 자리에 있는 친구일 수도 있고 더 먼 곳의 사람일 수도 있습니다. 그 사람이 다시 Fortiva를 사용하면 다시 데이터를 늘려 줍니다.';

  @override
  String get inviteTreeQaDownLater =>
      '사용을 멈춘 친구도 한동안은 활성으로 계산됩니다. 그래서 보너스는 친구가 멈추고 얼마 뒤에 줄어들 수 있습니다.';

  @override
  String get inviteTreeQaDownRemoved =>
      '초대가 삭제될 때도 보너스가 줄어들 수 있습니다. 예를 들어 그 친구가 Fortiva 계정을 삭제할 때입니다.';

  @override
  String get inviteTreeQaFullQ => '내 자리가 다 차면 어떻게 되나요?';

  @override
  String get inviteTreeQaFullFurther =>
      '그 첫 번째 짝들도 다 차면, 다음 친구는 더 멀리, 그 짝들에 있는 사람의 첫 번째 짝에 들어갑니다. 그 짝은 그 사람의 데이터를 늘려 주고, 나와 그 사이에 있는 각 사람의 데이터는 더 적게 늘려 줍니다.';

  @override
  String get inviteTreeQaFriendsQ => '친구의 친구도 내 데이터를 늘려 주나요?';

  @override
  String get inviteTreeQaFriendsA =>
      '일부는 그렇습니다. 내 자리에 있는 각 사람의 첫 번째 짝은 그 사람의 데이터를 늘려 주고, 내 데이터는 더 적게 늘려 줍니다. 그 사람의 다른 짝들은 그 사람의 데이터만 늘려 줍니다. 더 먼 곳에서는 첫 번째 짝만 내 데이터를 늘려 주고, 멀수록 덜 늘려 주다가 결국 아무것도 더해 주지 않습니다.';

  @override
  String get inviteTreeQaOthersQ => '내 자리에 있는, 내가 초대하지 않은 사람은 누구인가요?';

  @override
  String get inviteTreeQaOthersA =>
      '자리가 다 찬 사람의 친구들입니다. 예를 들어 나를 초대한 사람의 친구들입니다. 그 사람들은 내 첫 번째 짝의 빈 자리에 들어왔고, 내가 고르거나 빼낼 수 없습니다. 내 친구와 똑같이 내 데이터를 늘려 줍니다.';

  @override
  String get inviteTreeQaSumQ => '보너스가 초대 화면의 양과 다른 이유는 무엇인가요?';

  @override
  String get inviteTreeQaSumA =>
      '\"내 자리를 통해\"의 각 줄은 그 줄의 사람들이 지금 늘려 주는 양을 보여 줍니다. 보너스는 그 합계이며, 상한이 있습니다.';

  @override
  String get inviteTreeQaSlotQ => '자리를 비우거나 누가 들어올지 고를 수 있나요?';

  @override
  String get inviteTreeQaSlotA =>
      '아니요. 친구는 Fortiva 사용을 멈춰도 자리를 유지합니다. 그 자리는 초대가 삭제될 때만 다시 비게 됩니다. 예를 들어 친구가 Fortiva 계정을 삭제할 때입니다. 빈 자리는 순서대로 채워지며, 누가 들어올지는 아무도 고를 수 없습니다.';

  @override
  String get inviteTreeQaPrivacyQ => '내가 Fortiva를 쓰는지 친구가 볼 수 있나요?';

  @override
  String get inviteTreeQaPrivacyA =>
      '친구의 코드로 가입했다면, 내가 들어가 있는 자리의 주인은 내가 활성인지 지금 비활성인지 볼 수 있습니다. 다른 사람들은 활성인 사람의 수만 볼 수 있고, 누구인지는 볼 수 없습니다. 초대 화면에는 누구의 이름, 휴대폰, 사용량도 표시되지 않습니다.';

  @override
  String get inviteTreeQaLimitQ => '상한이 있나요?';

  @override
  String get inviteTreeQaLimitMore =>
      '초대로 늘어난 양이 그만큼에 이르면, 친구가 더 있어도 데이터는 더 늘지 않습니다.';

  @override
  String get inviteTreeQaKeptQ => '지금 받고 있는 보너스는 어떻게 되나요?';

  @override
  String get inviteTreeQaKeptMore =>
      '이전 초대로 받던 보너스가 지금 친구들이 늘려 주는 양보다 많으면, 그 보너스를 대신 받습니다. 두 가지가 합쳐지지는 않습니다.';

  @override
  String get inviteTreeQaKeptRemoved =>
      '초대는 그 친구가 Fortiva 계정을 삭제하거나, 부정 사용 때문에 Fortiva가 취소할 때 삭제됩니다.';

  @override
  String get inviteTreeQaChangedQ => '초대에서 무엇이 바뀌었나요?';

  @override
  String get inviteTreeQaChangedA =>
      '예전에는 조건을 충족한 친구마다 정해진 양의 데이터가 늘었습니다. 이제는 친구가 활성인 동안 내 자리와 짝을 통해 데이터를 늘려 주며, 보너스는 줄어들 수 있습니다.';

  @override
  String get inviteTreeQaPremiumQ => '초대로 프리미엄 기간도 늘어나나요?';

  @override
  String get inviteTreeQaPremiumOwn =>
      '친구가 어느 자리에 들어가는지는 상관없습니다. 내가 초대하지 않은 사람으로는 프리미엄 기간이 늘지 않습니다.';

  @override
  String get inviteTreeQaGetsQ => '친구도 무언가를 받나요?';

  @override
  String get inviteTreeQaGetsA =>
      '내 코드를 입력한 것으로는 받지 않습니다. 누구나 그렇듯 친구에게도 자신의 코드와 자리가 있고, 그 코드로 가입한 친구들이 그 사람의 데이터를 늘려 줍니다. 조건 충족이 되면 그 사람의 첫 번째 짝에도 그 사람이 초대하지 않은 사람이 들어올 수 있고, 그 사람들도 데이터를 늘려 줍니다.';

  @override
  String get inviteTreeQaGetsSee =>
      '그 친구가 내 자리에 있으면, 활성인지 지금 비활성인지 볼 수 있습니다. 친구의 이름이나 사용량은 볼 수 없습니다.';

  @override
  String get inviteTreeKeptFloor =>
      '지금 보너스는 이전 초대로 남아 있는 양과 같습니다. 친구들이 함께 그보다 더 많이 늘려 주면 보너스가 올라갑니다.';

  @override
  String inviteTreeIntroTotalUpTo(String most, String total) {
    return '친구가 늘려 줄 수 있는 양은 하루 최대 $most입니다. 무료 데이터와 친구에게서 받는 데이터를 합치면 하루 최대 $total까지 됩니다.';
  }

  @override
  String get inviteTreeIntroPairsOrder =>
      '첫 번째 짝이 가장 많이 늘려 줍니다. 그다음 짝은 각각 덜 늘려 줍니다.';

  @override
  String get inviteTreeIntroInvitedYou => '나를 초대한 사람';

  @override
  String get inviteTreeIntroGuide => '차근차근 안내';

  @override
  String get inviteTreeQaCostQ => '나 때문에 친구의 데이터가 줄어드나요?';

  @override
  String get inviteTreeQaCostA =>
      '아니요. 친구가 나에게 늘려 주는 데이터는 친구 자신의 데이터에서 빠지지 않습니다. 친구의 하루 데이터는 나 때문에 바뀌지 않습니다.';

  @override
  String get inviteTreeQaStartQ => '친구가 늘려 주는 데이터는 언제부터 받나요?';

  @override
  String get inviteTreeQaStartA =>
      '친구가 자리에 들어가 활성이 된 때부터입니다. 보너스는 하루 동안 수시로 갱신되므로 그 직후, 같은 날에 올라갑니다. 친구가 조건을 충족하기 전에는 아무것도 늘려 주지 않습니다.';

  @override
  String get inviteTreeQaPhoneQ => '친구가 Fortiva를 다시 설치하거나 휴대폰을 바꾸면 어떻게 되나요?';

  @override
  String get inviteTreeQaPhoneA =>
      '같은 휴대폰에 다시 설치하면 Fortiva가 대개 그 휴대폰을 다시 알아보므로 달라지는 것이 없습니다. 새 휴대폰은 Fortiva에게 새 기기입니다. 자리는 여전히 이전 휴대폰의 것이며, 이전 휴대폰을 더 이상 쓰지 않으면 비활성으로 셉니다.';

  @override
  String get premiumSourceInvite => '친구 초대로 받음';

  @override
  String quotaBonusIncluded(String amount) {
    return '초대 보너스 $amount 포함';
  }

  @override
  String get updateTitle => '업데이트 있음';

  @override
  String get updateRequiredTitle => '업데이트 필요';

  @override
  String updateBody(String version) {
    return 'Fortiva $version이(가) 나왔습니다. 최신 수정 사항을 받으려면 업데이트하세요.';
  }

  @override
  String get updateRequiredBody =>
      '이 버전은 더 이상 지원되지 않습니다. Fortiva를 계속 사용하려면 업데이트하세요.';

  @override
  String get updateNow => '업데이트';

  @override
  String get updateLater => '나중에';

  @override
  String get updateFromPlay => 'Google Play';

  @override
  String get updateFromTelegram => 'Telegram 채널';

  @override
  String get updateConnect => '연결';

  @override
  String get updateConnectHint => 'Google Play나 Telegram이 열리지 않으면 먼저 연결을 누르세요.';

  @override
  String get updateConnected => '연결되었습니다. 지금 업데이트를 다운로드하세요.';

  @override
  String get updateReconnect => '안 되나요? 다시 연결';

  @override
  String get updateDisconnect => '연결 해제';

  @override
  String get updateDisconnectHint => '연결 해제를 누르고 평소 인터넷으로 업데이트를 다운로드하세요.';

  @override
  String get updateNotCarrying =>
      '연결되어 있지만 아무것도 열리지 않습니다. 다시 연결하거나, 연결 해제를 눌러 평소 인터넷을 사용하세요.';

  @override
  String get diagVerdictNoInternet =>
      '휴대폰에 인터넷 연결이 없습니다. 인터넷이 돌아올 때까지 Fortiva도 연결할 수 없습니다.';

  @override
  String get diagVerdictCutOff =>
      '지금 사용 중인 네트워크에서 국제 인터넷에 연결할 수 없습니다. 몇 분 후 다시 시도하세요.';

  @override
  String get diagVerdictNeedsPermission =>
      'Fortiva에 VPN 실행 권한이 없거나, 다른 VPN 앱이 항상 켜짐으로 설정되어 있습니다.';

  @override
  String get diagVerdictServerUnreachable =>
      '이 서버는 현재 네트워크에서 접근할 수 없습니다. 여기서 차단되었거나 서버가 꺼져 있습니다.';

  @override
  String get diagVerdictBlockedTls =>
      '이 서버와의 연결이 설정되는 도중에 끊기고 있습니다. 필터링이 있을 때 나타나는 모습입니다.';

  @override
  String get diagVerdictThrottled =>
      '서버가 모든 확인에 응답했지만 VPN 터널로는 아무것도 전달되지 않았습니다. 연결 속도가 제한되고 있습니다.';

  @override
  String get diagCheckInternet => '인터넷 확인하기';

  @override
  String diagTryServer(String server) {
    return '$server(으)로 새로 검색';
  }

  @override
  String get diagTryAnotherServer => '다른 서버 시도하기';

  @override
  String get diagDetails => '세부 정보';

  @override
  String get diagDetailsHide => '세부 정보 숨기기';

  @override
  String privateDnsWarning(String host) {
    return '개인 DNS가 켜져 있어($host) 일부 사이트가 열리지 않을 수 있습니다. 휴대폰 설정에서 개인 DNS를 끄세요.';
  }

  @override
  String get openNetworkSettings => '네트워크 설정 열기';

  @override
  String testPointStatus(String time, int open, int total) {
    return '테스트 지점 · 마지막 확인 $time · $total개 중 $open개 경로 열림';
  }

  @override
  String get messagesTooltip => '메시지';

  @override
  String get inboxTitle => '메시지';

  @override
  String get inboxEmpty => '지금은 메시지가 없습니다.';

  @override
  String get messageClose => '닫기';

  @override
  String get supportTitle => '고객 지원';

  @override
  String get supportTooltip => '지원팀과 채팅';

  @override
  String get supportAskAction => '지원팀에 문의';

  @override
  String get supportContactSubtitle => '앱에서 바로 채팅하세요';

  @override
  String get supportAutomaticNotice => '답변은 자동으로 작성되며 틀릴 수 있습니다.';

  @override
  String get supportStaffNotice => '지금은 자동 답변이 꺼져 있습니다. 메시지는 저희 팀에 전달됩니다.';

  @override
  String get supportInputHint => '질문을 입력하세요';

  @override
  String get supportInputHintTeam => '저희 팀에 보낼 메시지를 입력하세요';

  @override
  String get supportSend => '보내기';

  @override
  String supportQuotaLeft(int remaining, int limit) {
    return '오늘 남은 질문: $remaining/$limit개';
  }

  @override
  String supportWaitIn(String time) {
    return '$time 후에 다시 질문할 수 있습니다.';
  }

  @override
  String supportDurationHours(int hours, int minutes) {
    return '$hours시간 $minutes분';
  }

  @override
  String supportDurationMinutes(int minutes) {
    return '$minutes분';
  }

  @override
  String get supportNewConversation => '새 대화';

  @override
  String get supportSending => '보내는 중';

  @override
  String get supportNotSent => '보내지 못했습니다. 탭하여 다시 시도하세요.';

  @override
  String get supportRateUp => '도움이 됨';

  @override
  String get supportRateDown => '도움이 안 됨';

  @override
  String get supportRatedDown => '감사합니다. 저희 팀이 이 답변을 확인하겠습니다.';

  @override
  String get supportTeamLabel => 'Fortiva 팀';

  @override
  String get supportUnavailable => '지금은 채팅을 사용할 수 없습니다.';

  @override
  String get supportOpenTelegram => '텔레그램으로 메시지 보내기';

  @override
  String get supportGenericError => '문제가 발생했습니다. 다시 시도해 주세요.';

  @override
  String supportCodeTooLong(int max) {
    return '메시지가 너무 깁니다. $max자 미만으로 줄여 주세요.';
  }

  @override
  String get supportCodeEmpty => '메시지가 비어 있습니다.';

  @override
  String get supportCodeWaitReply => '이전 질문의 답변을 기다려 주세요.';

  @override
  String get supportCodeSlowDown => '메시지를 너무 빨리 보내고 있습니다. 잠시 기다려 주세요.';

  @override
  String get supportCodeQuotaDay => '오늘 질문을 모두 사용했습니다.';

  @override
  String get supportCodePaused => '자동 답변이 잠시 중지되었습니다.';

  @override
  String get supportCodeBusy => '지금은 도우미가 바쁩니다. 몇 분 후에 다시 시도해 주세요.';

  @override
  String get supportCodeGreeting => '안녕하세요! Fortiva 사용에 대해 무엇을 도와드릴까요?';

  @override
  String get supportCodeGibberish => '죄송합니다. 이해하지 못했습니다. 질문을 다시 써 주세요.';

  @override
  String get supportCodeRedacted => '메시지에서 개인 정보와 링크를 삭제했습니다.';

  @override
  String get supportCodeRedactedEmpty =>
      '메시지에 개인 정보나 링크만 있어서 보내지 않았습니다. 문제를 말로 설명해 주세요.';

  @override
  String get supportCodeOffTopic => 'Fortiva 사용에 관한 질문만 도와드릴 수 있습니다.';

  @override
  String get supportCodeAbuse => '서로 존중하며 대화해요. Fortiva 사용을 도와드리려고 여기 있습니다.';

  @override
  String get supportCodeAiUnavailable =>
      '이번에는 도우미가 답변하지 못했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get supportCodeToStaff => '저희 팀에 보냈습니다. 답변은 여기에 표시됩니다.';

  @override
  String get supportCodeTicketOpened => '질문을 저희 팀에 전달했습니다. 답변은 여기에 표시됩니다.';

  @override
  String get supportCodeNotSent => '이 메시지를 보내지 못했습니다. 아직 도움이 필요하면 다시 작성해 주세요.';

  @override
  String get supportAssistantSubtitle => 'AI 도우미';

  @override
  String get supportThinkingReading => '질문을 읽고 있어요';

  @override
  String get supportThinkingSearching => '답을 찾고 있어요';

  @override
  String get supportThinkingWriting => '답변을 쓰고 있어요';

  @override
  String get supportThinkingStill => '아직 작업 중이에요. 기다려 주셔서 고마워요';

  @override
  String get supportSuggestConnect => '연결이 안 돼요';

  @override
  String get supportSuggestData => '오늘 데이터가 얼마나 남았나요?';

  @override
  String get supportSuggestSlow => '연결이 느려요';

  @override
  String get supportWithTeam => '이 대화는 이제 저희 팀이 맡고 있어요.';

  @override
  String get supportTryAgainSoon => '몇 분 후에 다시 시도해 주세요.';

  @override
  String supportDurationWholeHours(int hours) {
    return '$hours시간';
  }

  @override
  String get supportUnreadReply => '새 답변이 있어요';

  @override
  String get premiumTitle => '프리미엄';

  @override
  String get premiumTileSubtitle => '무제한 데이터, 일일 한도 없음';

  @override
  String get premiumTileActive => '프리미엄 사용 중';

  @override
  String get premiumGetUnlimited => '무제한 받기';

  @override
  String get premiumHeadline => '데이터를 무제한으로';

  @override
  String get premiumPitch =>
      '프리미엄은 일일 한도를 없애 주므로, 기간이 끝날 때까지 원하는 만큼 데이터를 쓸 수 있습니다.';

  @override
  String get premiumActiveTitle => '프리미엄 사용 중';

  @override
  String premiumActiveUntil(String date) {
    return '$date까지 데이터 무제한';
  }

  @override
  String get premiumActiveNoDate => '데이터 무제한';

  @override
  String get premiumRenews => 'Google Play에서 자동으로 갱신됩니다';

  @override
  String get premiumSourceKey => '키로 활성화됨';

  @override
  String get premiumSourceCrypto => '암호화폐로 결제됨';

  @override
  String get premiumSourceStars => 'Telegram Stars로 결제됨';

  @override
  String get premiumSourceGooglePlay => 'Google Play로 결제됨';

  @override
  String get premiumSourceManual => 'Fortiva 팀의 선물';

  @override
  String get premiumYourKey => '내 키';

  @override
  String get premiumKeyHint =>
      '이 키를 잘 보관하세요. 다른 휴대폰에서 입력하면 프리미엄을 그쪽으로 옮길 수 있습니다.';

  @override
  String premiumKeyMoves(int count, int days) {
    return '키는 $days일 동안 최대 $count번 다른 휴대폰으로 옮길 수 있습니다.';
  }

  @override
  String get premiumKeyMovesNoNumber => '키를 다른 휴대폰으로 옮길 수 있는 횟수에는 제한이 있습니다.';

  @override
  String get premiumCopy => '복사';

  @override
  String get premiumCopied => '복사했습니다';

  @override
  String get premiumChoosePlan => '요금제 선택';

  @override
  String premiumPlanDays(int days) {
    return '$days일 데이터 무제한';
  }

  @override
  String get premiumPlanNoDays => '데이터 무제한';

  @override
  String get premiumBuy => '구매';

  @override
  String get premiumPlayUnavailable =>
      '지금은 Google Play를 사용할 수 없습니다. 나중에 다시 시도하세요.';

  @override
  String get premiumPlayPending =>
      'Google Play에서 결제가 대기 중입니다. 결제가 완료되는 즉시 프리미엄이 시작됩니다.';

  @override
  String get premiumPlayConfirming => '구매를 확인하는 중...';

  @override
  String get premiumPlayRetrying =>
      '결제는 완료되었지만 아직 확인하지 못했습니다. 계속 확인할 테니 다시 결제하지 않아도 됩니다.';

  @override
  String get premiumPlayRefused => '이 구매를 확인하지 못했습니다. 요금이 청구되었다면 고객 지원에 문의하세요.';

  @override
  String get premiumPlayNotAvailable =>
      '지금은 이 휴대폰에서 프리미엄을 사용할 수 없습니다. 요금이 청구되었다면 고객 지원에 문의하세요.';

  @override
  String get premiumNotAvailable => '지금은 이 휴대폰에서 프리미엄을 사용할 수 없습니다.';

  @override
  String get premiumPlayFailed => '구매가 완료되지 않았습니다. 다시 시도하세요.';

  @override
  String get premiumNowOn => '프리미엄이 켜졌습니다. 무제한 데이터를 즐기세요.';

  @override
  String get premiumRestore => '구매 복원';

  @override
  String get premiumRestoreDone => '이 휴대폰에서 구매를 복원했습니다.';

  @override
  String get premiumRestoreNone => 'Google Play에 복원할 구매가 없습니다.';

  @override
  String get premiumRestoreFailed => '구매를 복원하지 못했습니다. 나중에 다시 시도하세요.';

  @override
  String premiumRenewsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count일마다 결제됩니다. 해지할 때까지 자동으로 갱신됩니다.',
      one: '매일 결제됩니다. 해지할 때까지 자동으로 갱신됩니다.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count주마다 결제됩니다. 해지할 때까지 자동으로 갱신됩니다.',
      one: '매주 결제됩니다. 해지할 때까지 자동으로 갱신됩니다.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개월마다 결제됩니다. 해지할 때까지 자동으로 갱신됩니다.',
      one: '매월 결제됩니다. 해지할 때까지 자동으로 갱신됩니다.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count년마다 결제됩니다. 해지할 때까지 자동으로 갱신됩니다.',
      one: '매년 결제됩니다. 해지할 때까지 자동으로 갱신됩니다.',
    );
    return '$_temp0';
  }

  @override
  String get premiumRenewsNoPeriod => '해지할 때까지 자동으로 갱신됩니다.';

  @override
  String get premiumPlayCancelNote =>
      'Google Play에서 언제든지 해지할 수 있습니다. 결제한 기간이 끝날 때까지 프리미엄이 유지됩니다.';

  @override
  String get premiumManageSubscription => '구독 관리 또는 해지';

  @override
  String get premiumCurrentPlan => '현재 요금제';

  @override
  String get premiumPlaySubscribed =>
      '이미 Google Play 구독이 있습니다. Google Play에서 관리하거나 해지하세요.';

  @override
  String get premiumEnterCode => '코드 입력';

  @override
  String get premiumNeedsPlayVersion =>
      'Google Play로 구매하려면 Google Play 버전의 Fortiva가 필요합니다.';

  @override
  String get premiumOff => '지금은 프리미엄을 판매하지 않습니다.';

  @override
  String get premiumLoadFailed => '프리미엄 정보를 불러오지 못했습니다. 연결을 확인하고 다시 시도하세요.';

  @override
  String get premiumRetry => '다시 시도';

  @override
  String premiumPriceUsdt(String price) {
    return '$price USDT';
  }

  @override
  String premiumPriceStars(String stars) {
    return '$stars Telegram Stars';
  }

  @override
  String get premiumPayCrypto => '암호화폐로 결제';

  @override
  String get premiumTelegramTitle => 'Telegram에서 결제';

  @override
  String get premiumTelegramBody =>
      '저희 봇에서 Telegram Stars로 결제하세요. 키를 받게 되며, 이 휴대폰에서 바로 프리미엄이 시작됩니다.';

  @override
  String get premiumTelegramButton => 'Telegram에서 구매';

  @override
  String get premiumTelegramFailed => 'Telegram을 열지 못했습니다. 다시 시도하세요.';

  @override
  String get checkoutTitle => '암호화폐로 결제';

  @override
  String get checkoutChooseNetwork => '송금할 네트워크를 선택하세요';

  @override
  String get checkoutContinue => '계속';

  @override
  String get checkoutSendExactly => '정확히 이 금액을 보내세요';

  @override
  String get checkoutNetwork => '네트워크';

  @override
  String get checkoutAddress => '받는 주소';

  @override
  String get checkoutMemo => '메모';

  @override
  String get checkoutMemoWarning =>
      '송금할 때 이 메모를 꼭 넣으세요. 넣지 않으면 결제를 확인할 수 없습니다.';

  @override
  String get checkoutExactWarning =>
      '정확한 금액을 이 네트워크로만 보내세요. 다른 금액이나 네트워크로 보내면 도착하지 않을 수 있습니다.';

  @override
  String checkoutTimeLeft(String time) {
    return '남은 시간: $time';
  }

  @override
  String get checkoutWaiting => '결제를 기다리는 중입니다. 이 화면은 자동으로 업데이트됩니다.';

  @override
  String get checkoutPaidTitle => '결제 완료';

  @override
  String get checkoutPaidKeyOnly => '키가 준비되었습니다. 프리미엄을 쓸 휴대폰에서 입력하세요.';

  @override
  String get checkoutDone => '완료';

  @override
  String get checkoutExpired => '이 주문은 만료되었습니다. 이미 결제했다면 고객 지원에 문의하세요.';

  @override
  String get checkoutUnderpaid =>
      '받은 금액이 전체 금액보다 적습니다. 고객 지원에 문의하고 이 주문 번호를 알려 주세요:';

  @override
  String get checkoutCanceled => '이 주문은 취소되었습니다.';

  @override
  String get checkoutStartAgain => '다시 시작';

  @override
  String get checkoutUnavailable => '지금은 암호화폐 결제를 사용할 수 없습니다.';

  @override
  String get checkoutTooManyOpen =>
      '결제하지 않은 주문이 너무 많습니다. 그중 하나를 결제하거나 만료될 때까지 기다리세요.';

  @override
  String get checkoutUnknownPlan =>
      '이 요금제는 더 이상 판매하지 않습니다. 돌아가서 다른 요금제를 선택하세요.';

  @override
  String get checkoutFailed => '결제를 시작하지 못했습니다. 연결을 확인하고 다시 시도하세요.';

  @override
  String get redeemTitle => '코드 입력';

  @override
  String get redeemSubtitle => '프리미엄 키 또는 선물 코드';

  @override
  String get redeemHint => '코드';

  @override
  String get redeemApply => '적용';

  @override
  String get redeemCancel => '취소';

  @override
  String get redeemInvalid => '코드 형식이 아닌 것 같습니다. 확인 후 다시 시도하세요.';

  @override
  String get redeemUnknown => '알 수 없는 코드입니다. 확인 후 다시 시도하세요.';

  @override
  String get redeemExpired => '이 코드는 만료되었습니다.';

  @override
  String get redeemRevoked => '이 코드는 더 이상 유효하지 않습니다.';

  @override
  String get redeemMovedTooOften => '이 키는 최근 휴대폰 간 이동이 너무 많았습니다. 나중에 다시 시도하세요.';

  @override
  String get redeemExhausted => '이 코드는 모두 사용되었습니다.';

  @override
  String get redeemAlreadyUsed => '이 휴대폰은 이미 이 코드를 사용했습니다.';

  @override
  String get redeemUnmetered => '이 휴대폰은 이미 데이터 무제한이라 이 코드가 필요하지 않습니다.';

  @override
  String get redeemRateLimited => '시도가 너무 많습니다. 잠시 기다린 후 다시 시도하세요.';

  @override
  String get redeemUnavailable => '지금은 사용할 수 없습니다. 나중에 다시 시도하세요.';

  @override
  String get redeemNetwork => '서버에 연결하지 못했습니다. 연결을 확인하고 다시 시도하세요.';

  @override
  String get redeemFailed => '이 코드가 적용되지 않았습니다. 확인 후 다시 시도하세요.';

  @override
  String get redeemMoved => '프리미엄을 이 휴대폰으로 옮겼습니다.';

  @override
  String redeemPromo(String amount) {
    return '코드가 적용되었습니다. 추가 데이터 $amount을(를) 받았습니다.';
  }

  @override
  String get redeemPromoNoAmount => '코드가 적용되었습니다. 추가 데이터를 받았습니다.';

  @override
  String get tvScanTitle => '휴대폰에서 열기';

  @override
  String get tvScanBody => '휴대폰 카메라를 이 코드에 비추세요.';

  @override
  String get refresh => '새로고침';

  @override
  String get premiumNotNow => '나중에';

  @override
  String get premiumLimitSheetTitle => '오늘의 데이터를 모두 사용했습니다';

  @override
  String get premiumLimitWait => '초기화될 때까지 기다리기';

  @override
  String get premiumLimitInvite => '친구를 초대하고 데이터 더 받기';

  @override
  String premiumLimitInviteNext(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days일',
    );
    return '다음 친구가 서로 다른 $_temp0 동안 Fortiva를 쓰면 하루 $amount씩 늘어납니다. 오늘 데이터에는 더해지지 않습니다.';
  }

  @override
  String premiumLimitInviteNextNoDays(String amount) {
    return '다음 친구가 Fortiva를 한동안 쓰면 하루 $amount씩 늘어납니다. 오늘 데이터에는 더해지지 않습니다.';
  }

  @override
  String get premiumLimitInviteNoAmount =>
      '초대한 친구가 Fortiva를 쓰기 시작하면 매일 데이터가 늘어납니다. 오늘 데이터에는 더해지지 않습니다.';

  @override
  String get premiumLimitInvitesFull => '초대로 늘릴 수 있는 데이터를 이미 모두 받고 있습니다.';

  @override
  String get premiumLimitSeeInvites => '내 초대 보기';

  @override
  String get premiumLimitShareAgain => '다른 친구에게도 공유';

  @override
  String get premiumNoDailyLimit => '프리미엄은 일일 한도가 없습니다.';

  @override
  String get premiumCalmTitle => '일일 한도 없이 쓰고 싶으신가요?';

  @override
  String get premiumCalmBody => '프리미엄은 데이터가 무제한입니다. 무료 요금제는 그대로 유지됩니다.';

  @override
  String get premiumNextStepTitle => '다음 단계는 프리미엄입니다';

  @override
  String get premiumNextStepBody =>
      '이미 가장 많은 무료 데이터를 받고 있습니다. 프리미엄은 일일 한도가 없습니다.';

  @override
  String get premiumLockedTag => '프리미엄';

  @override
  String premiumLockedTitle(String place) {
    return '프리미엄으로 $place 잠금 해제';
  }

  @override
  String get premiumLockedBody => '이 위치는 프리미엄 전용입니다. 무료 서버는 그대로입니다.';

  @override
  String get premiumHeadlineLimit => '일일 한도 없음';

  @override
  String premiumHeadlineLocked(String place) {
    return '프리미엄으로 $place 잠금 해제';
  }

  @override
  String get premiumFreeStays => '프리미엄 없이도 무료 요금제는 계속 이용할 수 있습니다.';

  @override
  String premiumEndsOn(String date) {
    return '프리미엄이 $date에 종료됩니다';
  }

  @override
  String get premiumRenewBody =>
      '갱신하면 무제한 데이터를 계속 쓸 수 있습니다. 갱신한 기간은 현재 종료일에 더해집니다.';

  @override
  String premiumEndedOn(String date) {
    return '프리미엄이 $date에 종료되었습니다. 무료 요금제로 돌아왔습니다.';
  }

  @override
  String get premiumRenew => '갱신';

  @override
  String get noticeChannelName => 'Fortiva 메시지';

  @override
  String get noticeChannelDescription => 'Fortiva 팀의 소식과 메시지';

  @override
  String get noticesSettingTitle => '알림';

  @override
  String get noticesSettingOn => '켜짐. 앱이 닫혀 있어도 Fortiva 팀의 메시지를 받을 수 있습니다.';

  @override
  String get noticesSettingOff => '꺼짐. 켜면 앱이 닫혀 있어도 Fortiva 팀의 메시지를 받을 수 있습니다.';

  @override
  String get noticesOffCard => '알림을 켜면 앱이 닫혀 있어도 Fortiva 팀의 메시지를 받을 수 있습니다.';

  @override
  String get noticesTurnOn => '켜기';

  @override
  String get backgroundCard =>
      '앱이 닫혀 있는 동안 휴대폰이 Fortiva 팀의 메시지를 막을 수 있습니다. 메시지를 받으려면 Fortiva가 백그라운드에서 실행되도록 허용하세요.';

  @override
  String get backgroundHint =>
      '다음 화면에서 Fortiva를 선택하세요(목록에 없으면 모든 앱 보기). 그런 다음 배터리 사용을 제한 없음으로 설정하거나 자동 실행과 백그라운드 실행을 허용하세요.';

  @override
  String get backgroundAllow => '허용';

  @override
  String get backgroundNotNow => '나중에';

  @override
  String get backgroundSettingTitle => '앱이 닫혀 있을 때 메시지';

  @override
  String get backgroundSettingSubtitle =>
      'Fortiva가 백그라운드에서 실행되도록 허용하면 앱이 닫혀 있어도 메시지를 받을 수 있습니다.';

  @override
  String get backgroundCardData =>
      '앱이 닫혀 있는 동안 휴대폰의 데이터 절약 모드가 Fortiva 팀의 메시지를 막을 수 있습니다.';

  @override
  String get backgroundHintData => '다음 화면에서 데이터 무제한 사용을 켜세요.';

  @override
  String get apnGuideTitle => '이 SIM에서 더 안정적인 연결';

  @override
  String get apnGuideBody =>
      '휴대폰이 이 SIM에서 IPv6를 사용하지 않습니다. 켜면 Fortiva 연결이 더 잘 유지됩니다.';

  @override
  String get apnGuideShowMe => '방법 보기';

  @override
  String get apnGuideNotNow => '나중에';

  @override
  String get apnGuideSheetTitle => '이 SIM에서 IPv6 켜기';

  @override
  String apnGuideStepOpen(String button) {
    return '\"$button\"을(를) 탭하세요(또는 설정 > 연결 > 모바일 네트워크 > 액세스 포인트 이름으로 이동하세요).';
  }

  @override
  String apnGuideStepAccessPoint(String apn) {
    return '사용 중인 액세스 포인트($apn)를 탭하세요.';
  }

  @override
  String get apnGuideStepAccessPointAny => '사용 중인 액세스 포인트를 탭하세요.';

  @override
  String get apnGuideStepProtocol => '\"APN 프로토콜\"을 탭하고 \"IPv4/IPv6\"를 선택하세요.';

  @override
  String get apnGuideStepSave => '저장하세요(삼성: 점 세 개 메뉴에서 \"저장\").';

  @override
  String get apnGuideStepRestart => '모바일 데이터를 껐다가 다시 켜세요.';

  @override
  String get apnGuideUndo => '모바일 데이터가 작동하지 않으면 APN 프로토콜을 다시 IPv4로 바꾸세요.';

  @override
  String get apnGuideOpenSettings => 'APN 설정 열기';

  @override
  String get homeStallSearching => '연결이 작동하지 않습니다. 다른 경로를 찾는 중입니다.';

  @override
  String get homeStalled => '연결됨, 하지만 데이터가 오가지 않음';

  @override
  String get peerShareTitle => '친구 연결 돕기';

  @override
  String get peerShareSubtitle => '연결에 필요한 것을 친구 휴대폰에 전달하기';

  @override
  String get peerShareBody =>
      '친구의 Fortiva가 연결되지 않으면, 친구 휴대폰이 내 휴대폰에서 필요한 것을 받을 수 있습니다. 인터넷이 없어도 됩니다.';

  @override
  String peerShareSteps(String action) {
    return '친구 휴대폰의 Fortiva에서 설정을 열고 \"$action\" 항목을 누르세요. 그런 다음 이 코드를 차례로 보여 주거나 친구에게 보내세요.';
  }

  @override
  String get peerShareLoading => '최신 내용을 가져오는 중';

  @override
  String get peerShareNothing => '이 휴대폰에는 지금 전달할 새 내용이 없습니다. 나중에 다시 시도하세요.';

  @override
  String peerShareCodeOf(int current, int total) {
    return '코드 $current/$total';
  }

  @override
  String get peerSharePrevious => '이전';

  @override
  String get peerShareNext => '다음';

  @override
  String get peerShareCopy => '복사';

  @override
  String get peerShareSend => '보내기';

  @override
  String get peerShareCopied => '복사했습니다. 친구에게 보내는 메시지에 붙여 넣으세요.';

  @override
  String get peerReceiveTitle => '친구에게 도움 받기';

  @override
  String get peerReceiveSubtitle => '다른 방법으로 연결되지 않을 때';

  @override
  String peerReceiveBody(String action) {
    return 'Fortiva가 연결되는 친구에게 앱 안의 설정을 열고 \"$action\" 항목을 누르도록 부탁하세요. 그런 다음 아래 방법 중 하나로 친구 휴대폰에서 받으세요.';
  }

  @override
  String get peerReceivePhotograph => '친구의 코드 촬영';

  @override
  String get peerReceivePhotographNext => '다음 코드 촬영';

  @override
  String peerReceiveProgress(int have, int total) {
    return '코드 $total개 중 $have개 읽음';
  }

  @override
  String get peerReceiveFile => '친구가 보낸 파일 열기';

  @override
  String get peerReceivePaste => '친구가 보낸 내용 붙여넣기';

  @override
  String get peerReceiveNoCode =>
      '사진에서 코드를 찾지 못했습니다. 코드 전체가 보이도록 휴대폰을 더 가까이 대세요.';

  @override
  String get peerReceiveRefused =>
      '이 내용은 Fortiva에서 사용할 수 없습니다. 친구에게 다시 보내 달라고 부탁하세요.';

  @override
  String get peerReceiveNotNewer =>
      '이미 이 내용이나 더 새로운 내용이 있습니다. 다시 연결해 보거나 다른 친구에게 부탁하세요.';

  @override
  String get peerReceiveTaken => '완료되었습니다. 버튼을 눌러 연결하세요.';

  @override
  String get peerReceiveUnavailable => '이 휴대폰에서는 할 수 없습니다. 다른 방법을 시도하세요.';

  @override
  String get peerReceiveNothingToPaste =>
      '아직 복사한 내용이 없습니다. 친구가 보낸 내용을 복사한 뒤 여기를 다시 누르세요.';

  @override
  String get peerOfferBody =>
      '아직 연결되지 않나요? Fortiva가 잘 되는 친구가 자기 휴대폰으로 도와줄 수 있습니다.';

  @override
  String get peerReceiveAgain => '이미 읽은 코드입니다. 친구에게 다음 코드를 보여 달라고 하세요.';

  @override
  String get peerReceivePasteNotOurs =>
      '복사한 내용이 Fortiva에서 온 것이 아닙니다. 친구가 보낸 메시지 전체를 복사한 뒤 다시 시도하세요.';

  @override
  String peerReceiveNoPhoto(String action) {
    return '카메라에서 사진을 돌려받지 못했습니다. 카메라 앱으로 사진을 찍은 뒤 \"$action\" 버튼을 누르세요.';
  }

  @override
  String get peerReceiveFileHint => '메신저로 받은 파일은 먼저 다운로드 폴더에 저장해야 할 수도 있습니다.';

  @override
  String get homeTryingBackup => '다른 연결이 되지 않았습니다. 지금 예비 네트워크를 시도합니다.';

  @override
  String get homeConnectedBackup => '예비 네트워크로 연결됨';

  @override
  String get backupNetwork => '예비 네트워크';

  @override
  String get backupNetworkTitle => '예비 네트워크';

  @override
  String get backupNetworkCaption => '다른 연결이 되지 않을 때 사용됩니다. 우리 서버보다 느릴 수 있습니다.';

  @override
  String get backupNetworkPlace => '위치는 자동으로 선택됩니다';

  @override
  String get speedTestStart => '테스트 시작';

  @override
  String get speedTestAgain => '다시 테스트';

  @override
  String get speedTestRunning => '테스트 중';

  @override
  String get speedTestIdle => '지금 연결 속도가 얼마나 빠른지 확인해 보세요.';

  @override
  String get speedTestPhasePing => '응답 시간 확인 중';

  @override
  String get speedTestPhaseDownload => '다운로드 속도 측정 중';

  @override
  String get speedTestPhaseUpload => '업로드 속도 측정 중';

  @override
  String get speedTestDone => '테스트 완료';

  @override
  String get speedTestFailed => '테스트를 완료하지 못했습니다. 인터넷 연결을 확인하고 다시 시도하세요.';

  @override
  String get speedTestUnit => 'Mbps';

  @override
  String get ipAddressLabel => 'IP 주소';

  @override
  String get ipCopied => '주소를 복사했습니다';

  @override
  String get ipLocation => '위치';

  @override
  String get ipProvider => '인터넷 제공업체';

  @override
  String get ipOrganization => '조직';

  @override
  String get ipTimeZone => '시간대';

  @override
  String get ipCoordinates => '좌표';

  @override
  String get ipCheckFailed => '주소를 확인하지 못했습니다';

  @override
  String get historyAverage => '평균 연결 시간';

  @override
  String get historyRecentDays => '최근 활동';

  @override
  String yesterdayAt(String time) {
    return '어제 $time';
  }

  @override
  String dateAt(String date, String time) {
    return '$date $time';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds초';
  }

  @override
  String get stageOwn => 'Fortiva 서버';

  @override
  String get stageCommunity => '커뮤니티 서버';

  @override
  String stageProgress(int n, int total) {
    return '$total단계 중 $n단계';
  }

  @override
  String get stageTryingOwn => 'Fortiva 서버를 시도하는 중';

  @override
  String get stageTryingCommunity => '커뮤니티 서버를 시도하는 중';

  @override
  String get stageOwnFailedTryingCommunity =>
      '여기서는 Fortiva 서버에 연결되지 않았습니다. 지금 커뮤니티 서버를 시도합니다.';

  @override
  String stageLastWorked(String server) {
    return '마지막으로 연결된 서버: $server';
  }

  @override
  String stageTriedBlocked(int count) {
    return '경로 $count개 시도, 여기서 차단됨';
  }

  @override
  String stageTriedFailed(int count) {
    return '경로 $count개 시도, 연결된 경로 없음';
  }

  @override
  String get stageNotConnected => '연결되지 않음';

  @override
  String get stageConnected => '여기서 연결됨';

  @override
  String get stageSkipped => '이번에는 건너뜀';

  @override
  String stageMoreToCheck(int count) {
    return '확인할 경로 $count개 남음';
  }

  @override
  String stageNextTry(String stage, String time) {
    return '$time 후 $stage부터 다시 시도합니다';
  }

  @override
  String get searchSlowHint => '시간이 조금 걸릴 수 있습니다. 버튼을 탭하면 검색을 멈춥니다.';

  @override
  String get searchStopped => '검색을 멈췄습니다';

  @override
  String get homeConnectedCommunity => '커뮤니티 서버로 연결됨';

  @override
  String get stageGettingServers => '서버를 가져오는 중';

  @override
  String stageNextTryStarting(String stage) {
    return '지금 $stage부터 다시 시도합니다';
  }
}
