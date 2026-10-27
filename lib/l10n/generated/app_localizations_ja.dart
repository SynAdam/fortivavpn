// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class SJa extends S {
  SJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'FortivaVPN';

  @override
  String get statusDisconnected => '切断済み';

  @override
  String get statusConnecting => '接続中';

  @override
  String get statusConnected => '接続済み';

  @override
  String get statusDisconnecting => '切断中';

  @override
  String get statusError => 'エラー';

  @override
  String get statusVerifying => '確認中...';

  @override
  String get disconnect => '切断';

  @override
  String get connectBtn => '接続';

  @override
  String get disconnectBtn => '切断';

  @override
  String get pleaseWait => 'お待ちください';

  @override
  String get locationLabel => '場所:';

  @override
  String get selectServer => 'サーバーを選択';

  @override
  String get serverLocation => 'サーバーの場所';

  @override
  String get searchServers => 'サーバーを検索';

  @override
  String get locationsTitle => '接続先';

  @override
  String get sortLatency => '並べ替え: 遅延';

  @override
  String get sortAZ => '並べ替え: A-Z';

  @override
  String get sortedByLatency => '遅延順で並べ替え';

  @override
  String get sortedAZ => 'A–Z順で並べ替え';

  @override
  String get pingAll => 'すべてPing';

  @override
  String get pinging => 'Ping中...';

  @override
  String get ping => 'ピング';

  @override
  String get stop => '停止';

  @override
  String get fastestServer => '最速サーバー';

  @override
  String get timeout => 'タイムアウト';

  @override
  String get tabCommunity => 'コミュニティ';

  @override
  String get tabFree => '無料';

  @override
  String get tabPremium => 'プレミアム';

  @override
  String get noCommunityServers => 'コミュニティサーバーなし';

  @override
  String get communityLoadFailed => 'このリストを読み込めませんでした';

  @override
  String get communityRetry => '再試行';

  @override
  String get officialTabExplainer =>
      'Fortiva が運営し、オンラインを維持しているサーバーです。アプリを使う全員で共有します。まずはここから。';

  @override
  String get communityTabExplainer => '追加の接続オプションです。速度と利用可否は変わることがあります。';

  @override
  String get noFreeServers => '無料サーバーなし';

  @override
  String get noPremiumServers => 'プレミアムサーバーなし';

  @override
  String noResultsFor(String query) {
    return '「$query」の検索結果なし';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get freeBadge => '無料';

  @override
  String get settings => '設定';

  @override
  String get connection => '接続';

  @override
  String get dnsConfiguration => 'DNS設定';

  @override
  String get customDns => 'カスタムDNSサーバー';

  @override
  String get about => 'アプリについて';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get contactUs => 'お問い合わせ';

  @override
  String get rateOnGooglePlay => 'Google PlayでFortivaを評価';

  @override
  String get website => 'ウェブサイト';

  @override
  String get copyright => '© 2026 NimusAI';

  @override
  String get version => 'バージョン';

  @override
  String get language => '言語';

  @override
  String get languageSubtitle => 'アプリの表示言語';

  @override
  String get whatIsDns => 'DNSとは？';

  @override
  String get dnsExplanation =>
      'DNS（ドメインネームシステム）はインターネットの電話帳です。ウェブサイト名をIPアドレスに変換します。\n\nDNSをカスタマイズすることで：\n• 接続速度を向上 ⚡\n• プライバシーを強化 🔒\n• 検閲ブロックを回避 🌍';

  @override
  String get configuration => '設定';

  @override
  String get primaryDns => 'プライマリDNS';

  @override
  String get primaryDnsHint => 'デフォルト: 1.1.1.1';

  @override
  String get secondaryDns => 'セカンダリDNS（オプション）';

  @override
  String get secondaryDnsHint => 'デフォルト: 8.8.8.8';

  @override
  String get saveConfiguration => '設定を保存';

  @override
  String get dnsSaved => 'DNS設定を保存しました';

  @override
  String get invalidPrimaryDns => '無効なプライマリDNS IPアドレス';

  @override
  String get invalidSecondaryDns => '無効なセカンダリDNS IPアドレス';

  @override
  String get statistics => '統計';

  @override
  String get overview => '概要';

  @override
  String get connectionsLabel => '接続回数';

  @override
  String get totalTime => '合計時間';

  @override
  String get dataUsage => 'データ使用量';

  @override
  String get uploaded => 'アップロード';

  @override
  String get downloaded => 'ダウンロード';

  @override
  String get total => '合計';

  @override
  String lastUpdated(String date) {
    return '最終更新: $date';
  }

  @override
  String today(String time) {
    return '今日 $time';
  }

  @override
  String get yesterday => '昨日';

  @override
  String daysAgo(int count) {
    return '$count日前';
  }

  @override
  String get noDataYet => 'まだデータがありません';

  @override
  String get connectToStart => 'VPNに接続してトラッキングを開始';

  @override
  String get errorConnectionFailed => '接続に失敗しました';

  @override
  String get errorServerNotWorking => 'サーバーが動作していません — 別のサーバーをお試しください';

  @override
  String get errorServerNotForwarding => 'サーバーがトラフィックを転送していません';

  @override
  String get errorUnexpected => '予期しないエラー';

  @override
  String get errorDisconnectionFailed => '切断に失敗しました';

  @override
  String get errorFailedToRegister => 'デバイスの登録に失敗しました';

  @override
  String get ipInformation => 'IP情報';

  @override
  String get connectionAnalytics => '接続分析';

  @override
  String get recentSessions => '最近のセッション';

  @override
  String get speedTest => 'スピードテスト';

  @override
  String get startTest => 'テスト開始';

  @override
  String get download => 'ダウンロード';

  @override
  String get upload => 'アップロード';

  @override
  String get testingViaVpn => 'VPN経由でテスト中';

  @override
  String get testingDirect => '直接接続テスト';

  @override
  String get splitTunneling => 'スプリットトンネリング';

  @override
  String get splitTunnelingDescription => 'VPNトンネルをバイパスするアプリカテゴリを選択してください。';

  @override
  String get enableSplitTunneling => 'スプリットトンネリングを有効化';

  @override
  String get splitTunnelActive => '選択したアプリはVPNをバイパスします';

  @override
  String get splitTunnelInactive => 'すべてのトラフィックがVPN経由';

  @override
  String get bypassVpnFor => 'VPNをバイパス';

  @override
  String get tools => 'ツール';

  @override
  String get settingsGeneral => '一般';

  @override
  String get shareDiagnosticsTitle => '接続の診断情報を共有';

  @override
  String get shareDiagnosticsBody =>
      '接続レポート、通信事業者と国、スマートフォンの機種と Android のバージョン、VPN 経由でアクセスしたサイトの名前と日ごとの回数、そしてメッセージ、プレミアムのご案内、招待カードを見たか、タップしたかを送信します。開いたページや送信した内容を私たちが見ることはありません。';

  @override
  String get security => 'セキュリティ';

  @override
  String get privacyDashboard => 'プライバシーダッシュボード';

  @override
  String get privacyDashboardSubtitle => 'IP情報 & リーク保護';

  @override
  String get connectionAnalyticsSubtitle => 'セッション履歴 & チャート';

  @override
  String get speedTestSubtitle => '接続速度をテスト';

  @override
  String get splitTunnelingSubtitle => 'アプリVPNルーティング';

  @override
  String get splashTagline => 'どこにいても、プライベートなアクセスを';

  @override
  String get openSourceLicence => 'オープンソースライセンス';

  @override
  String get sourceOfferTitle => 'オープンソースライセンス';

  @override
  String get sourceOfferBody =>
      'Fortiva VPN は GNU General Public License v3 のもとで提供される自由ソフトウェアです。Xray-core やその他のオープンソースプロジェクトをもとに作られています。\n\nインストールされているバージョンの完全なソースコードを受け取る権利があります。ご希望の場合は、アプリのバージョンを添えて admin@fortivavpn.com までメールでお知らせください。この申し出は、このバージョンを受け取った日から 3年間にわたって有効です。';

  @override
  String get close => '閉じる';

  @override
  String get account => 'アカウント';

  @override
  String get deleteAccount => 'アカウントを削除';

  @override
  String get deleteAccountSubtitle => 'この端末とデータを完全に削除します';

  @override
  String get deleteAccountConfirmTitle => 'アカウントを削除しますか？';

  @override
  String get deleteAccountConfirmBody =>
      '端末の登録、お客様のために作成された専用サーバー、サポートチャットのメッセージが削除されます。この端末の接続履歴も消去されます。\n\nこの操作は取り消せません。アプリを開き直せば、いつでも最初から始められます。';

  @override
  String deleteAccountConfirmRetention(int days) {
    return 'アカウントの記録はただちに削除されます。バックアップ内の複製と匿名のサーバーログは $days 日以内に消去されます。';
  }

  @override
  String get deleteAccountConfirmRetentionNoDays =>
      'アカウントの記録はただちに削除されます。バックアップ内の複製と匿名のサーバーログは、プライバシーポリシーに定める期間内に消去されます。';

  @override
  String get deleteAccountCancel => 'アカウントを残す';

  @override
  String get deleteAccountConfirm => '削除';

  @override
  String get deleteAccountInProgress => 'アカウントを削除しています';

  @override
  String get deleteAccountDone => 'アカウントを削除しました。';

  @override
  String get deleteAccountFailed => 'アカウントを削除できませんでした。接続を確認してもう一度お試しください。';

  @override
  String get homeTapToConnect => 'タップして接続';

  @override
  String get homeChecking => '接続を確認しています';

  @override
  String get homePreparing => 'サーバーを準備しています';

  @override
  String get homeDisconnecting => '切断しています';

  @override
  String get homeFindingPath => '経路を探しています';

  @override
  String get diagCheckingInternet => 'インターネット接続を確認しています';

  @override
  String get diagInternationalCut => 'このネットワークでは国際インターネットが遮断されています';

  @override
  String diagPathRow(String city, int n) {
    return '$city、経路 $n';
  }

  @override
  String get diagOpen => '開通';

  @override
  String get diagBlocked => 'ブロック済み';

  @override
  String get diagSkipped => '今日はスキップ';

  @override
  String diagConnectingThrough(String city) {
    return '$city 経由で接続しています';
  }

  @override
  String get diagVerifying => 'トラフィックを確認しています';

  @override
  String get diagNoInternet => 'お使いのスマホは現在インターネットに接続されていません。';

  @override
  String get diagCutOff => '現在、お使いのネットワークから国際インターネットに接続できません。タップして再試行してください。';

  @override
  String get diagNothingOpen => '現在すべての経路がブロックされています。タップして再試行してください。';

  @override
  String get homeTryingAgain => '現在すべての経路がブロックされています。まもなく再試行します。';

  @override
  String get homeCutOffTryingAgain =>
      '現在、お使いのネットワークから国際インターネットに接続できません。まもなく再試行します。';

  @override
  String get homeOfflineTryingAgain =>
      'お使いのスマホは現在インターネットに接続されていません。まもなく再試行します。';

  @override
  String get diagPathFailed => '経路は開通していましたが、トンネルを確立できませんでした。タップして再試行してください。';

  @override
  String get openVpnSettings => 'VPN設定を開く';

  @override
  String get yourServer => 'あなたのサーバー';

  @override
  String get yourServerCaption => 'あなた専用です。ほかの誰も接続しません。';

  @override
  String get ourServer => '当社のサーバー';

  @override
  String get ourServerCaption => 'Fortiva が運営し、全員で共有しています。自分のサーバーが準備できるまで使います。';

  @override
  String get communityServer => 'コミュニティサーバー';

  @override
  String get communityServerCaption => '追加の接続オプションです。いつでも使えなくなることがあります。';

  @override
  String communityServerNumber(String n) {
    return 'コミュニティサーバー $n';
  }

  @override
  String get myServersTitle => 'あなたのサーバー';

  @override
  String get myServersExplainer =>
      'Fortiva では、端末ごとに各地域の専用サーバーが用意され、その認証情報はこのインストールだけのものです。アカウントは不要です。';

  @override
  String get myServersInUse => '使用中';

  @override
  String get myServersEmpty => 'まだサーバーが割り当てられていません';

  @override
  String get myServersRetry => '再試行';

  @override
  String get myServersBlockedTitle => '本日のデータを使い切りました';

  @override
  String get myServersBlockedWait => '割り当ては自動的にリセットされます。しばらくしてからご確認ください。';

  @override
  String myServersMoved(String place) {
    return '$place を使用しています';
  }

  @override
  String get copyLink => 'リンクをコピー';

  @override
  String get linkCopied => 'リンクをコピーしました';

  @override
  String quotaUsedToday(String used, String limit) {
    return '本日 $limit 中 $used 使用';
  }

  @override
  String get quotaUsedUp => '本日のデータを使い切りました';

  @override
  String get quotaUnlimited => 'データ無制限';

  @override
  String get quotaDaily => '本日のデータ';

  @override
  String get quotaLimitReached => '1 日の上限に達しました';

  @override
  String quotaLeftOf(String left, String limit) {
    return '$limit 中 残り $left';
  }

  @override
  String get quotaResetsShortly => 'まもなくリセットされます';

  @override
  String quotaResetsInHours(int hours) {
    return '$hours 時間後にリセット';
  }

  @override
  String quotaResetsInMinutes(int minutes) {
    return '$minutes 分後にリセット';
  }

  @override
  String get myServersSubtitle => 'この端末に割り当てられたサーバー';

  @override
  String get sharedServersTitle => '共有サーバー';

  @override
  String get sharedServersSubtitle => '予備として使う公開ロケーション';

  @override
  String get tabOfficial => '当社のサーバー';

  @override
  String get noOfficialServers => '現在 Fortiva サーバーはありません';

  @override
  String get inviteTitle => '友達を招待';

  @override
  String get inviteSubtitle => '毎日のデータを増やす';

  @override
  String get inviteYourCode => 'あなたの招待コード';

  @override
  String get inviteShareAction => '招待を共有';

  @override
  String get inviteCopyAction => 'コードをコピー';

  @override
  String get inviteCodeCopied => 'コードをコピーしました';

  @override
  String inviteShareMessage(String code, String url) {
    return '無料のVPN、Fortivaが快適に使えています。登録は不要です。\nこのリンクからインストールしてね：\n$url\n招待コード：$code';
  }

  @override
  String get inviteHowItWorks => '仕組み';

  @override
  String inviteHowItWorksBody(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '別々の$days日に',
      one: '$days日',
    );
    return 'コードを共有しましょう。相手がアプリをインストールしてコードを入力し、$_temp0 VPN を使うと、あなたの1日のデータに $amount が追加され、そのまま残ります。';
  }

  @override
  String inviteHowItWorksBodyNoAmount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '別々の$days日に',
      one: '$days日',
    );
    return 'コードを共有しましょう。相手がアプリをインストールしてコードを入力し、$_temp0 VPN を使うと、あなたの1日のデータが増え、そのまま残ります。';
  }

  @override
  String inviteHowItWorksBodyNoDays(String amount) {
    return 'コードを共有しましょう。相手がアプリをインストールしてコードを入力し、しばらく VPN を使うと、あなたの1日のデータに $amount が追加され、そのまま残ります。';
  }

  @override
  String get inviteHowItWorksBodyNoAmountNoDays =>
      'コードを共有しましょう。相手がアプリをインストールしてコードを入力し、しばらく VPN を使うと、あなたの1日のデータが増え、そのまま残ります。';

  @override
  String inviteHowItWorksCap(String max) {
    return '招待で増えるデータは1日最大 $max までです。';
  }

  @override
  String get inviteStatInvited => '招待した人数';

  @override
  String get inviteStatEarning => '条件達成';

  @override
  String get inviteStatBonus => 'ボーナスデータ';

  @override
  String inviteBonusPerDay(String amount) {
    return '毎日 +$amount';
  }

  @override
  String get inviteNoBonusYet => 'ボーナスはまだありません';

  @override
  String invitePendingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の招待がまだ条件を満たしていません',
      one: '1 件の招待がまだ条件を満たしていません',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String inviteJoinedWith(String code) {
    return 'コード $code で参加しました';
  }

  @override
  String get inviteLoadFailed => '招待コードを読み込めませんでした';

  @override
  String get inviteRetry => '再試行';

  @override
  String get inviteHaveCodeTitle => '招待コードをお持ちですか？';

  @override
  String inviteHaveCodeSubtitle(int hours) {
    return 'インストールから$hours時間以内に入力してください';
  }

  @override
  String get inviteHaveCodeSubtitleNoHours => 'インストール後、早めに入力してください';

  @override
  String get inviteEnterCodeHint => '招待コード';

  @override
  String get inviteApplyAction => '適用';

  @override
  String get inviteNotNowAction => '後で';

  @override
  String inviteClaimAccepted(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '別々の$days日に',
      one: '$days日',
    );
    return '招待を受け付けました。あなたが$_temp0 VPN を使うと、友達にボーナスデータが入ります。';
  }

  @override
  String get inviteClaimAcceptedNoDays =>
      '招待を受け付けました。あなたがしばらく VPN を使うと、友達にボーナスデータが入ります。';

  @override
  String get inviteClaimAlready => 'この端末はすでに招待コードを使用しています';

  @override
  String get inviteClaimRejected => 'このコードは使えませんでした。確認してもう一度お試しください';

  @override
  String get inviteClaimNetwork => 'サーバーに接続できませんでした。もう一度お試しください';

  @override
  String get inviteCardTitle => 'Fortivaは快適に使えていますか？友だちにも送りましょう';

  @override
  String get inviteCardBody => 'インストール用のリンクを送れば、友だちも無料で接続できます。';

  @override
  String inviteCardReward(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '友だちが Fortiva を使い始めると、プレミアムが$days日分もらえます。',
    );
    return '$_temp0';
  }

  @override
  String get inviteCardRewardNoAmount =>
      '友だちが Fortiva を使い始めると、プレミアムがプレゼントされます。';

  @override
  String get inviteSendTelegram => 'Telegram';

  @override
  String get inviteSendWhatsApp => 'WhatsApp';

  @override
  String get inviteCopyLink => 'リンクをコピー';

  @override
  String get inviteOtherApps => 'その他のアプリ';

  @override
  String get inviteLinkCopied => '招待メッセージをコピーしました';

  @override
  String get invitePasteBody => '友達から届いたメッセージのコードをコピーして、ここに貼り付けてください。';

  @override
  String get invitePasteAction => '貼り付け';

  @override
  String get inviteErrorTooLate => 'このスマホで招待コードを入力できる期間は終了しました。';

  @override
  String get inviteErrorUnknown => 'このコードが見つかりませんでした。友達のメッセージからもう一度コピーしてください。';

  @override
  String get inviteErrorOwnCode => 'これはあなた自身のコードです。友達のコードを入力してください。';

  @override
  String get inviteErrorMutual => 'あなたと友達がお互いを招待することはできません。';

  @override
  String inviteHowItWorksPremium(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '友達が Fortiva を使い始めるたびに、プレミアムも$days日分もらえます。',
    );
    return '$_temp0';
  }

  @override
  String inviteHowItWorksPremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '招待でもらえるプレミアムは最大$max日分です。',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeLive =>
      'ボーナスは、友だちが Fortiva を使い続けている間だけ続きます。友だちが使うのをやめると減ります。';

  @override
  String inviteTreeNext(String amount) {
    return '次に招待した友だちが Fortiva を使い始めると、毎日 $amount 増えます。';
  }

  @override
  String inviteTreeKept(String amount) {
    return '以前に招待した友だちのおかげで、ボーナスが毎日 $amount を下回ることはありません。';
  }

  @override
  String get inviteTreeSlotsTitle => 'あなたの枠';

  @override
  String get inviteTreeSlotActive => 'アクティブ';

  @override
  String get inviteTreeSlotNotActive => '今は非アクティブ';

  @override
  String get inviteTreeSlotEmpty => '空き枠';

  @override
  String inviteTreePaysNow(String amount) {
    return '今は毎日 +$amount';
  }

  @override
  String inviteTreePairFull(String amount) {
    return '両方アクティブなら毎日 +$amount';
  }

  @override
  String get inviteTreeNothingYet => 'まだありません';

  @override
  String get inviteTreeFriendsTitle => 'あなたの枠を通じて';

  @override
  String get inviteTreeRowFriends => 'あなたの枠にいる人';

  @override
  String get inviteTreeRowFriendsSlots => 'その人たちの枠にいる人';

  @override
  String inviteTreeRowSteps(int steps) {
    String _temp0 = intl.Intl.pluralLogic(
      steps,
      locale: localeName,
      other: '$steps ステップ先',
    );
    return '$_temp0';
  }

  @override
  String inviteTreeRowPeople(int people, int active) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people人',
    );
    return '$_temp0、アクティブ $active人';
  }

  @override
  String inviteTreeHowSlots(int slots) {
    String _temp0 = intl.Intl.pluralLogic(
      slots,
      locale: localeName,
      other: 'コードを共有しましょう。条件を満たした最初の$slots人の友だちが、ペアごとにあなたの枠を埋めます。',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeHowSlotsNoNumber =>
      'コードを共有しましょう。最初に条件を満たした友だちが、ペアごとにあなたの枠を埋めます。';

  @override
  String get inviteTreeHowPair => 'ペアの両方がアクティブだと、もらえる量が増えます。';

  @override
  String get inviteTreeHowFriendsSlots =>
      'あなたの枠が埋まると、その後に条件を満たしたあなたの友だちは、あなたから離れた次の空き枠に入ります。その人たちもあなたのデータを増やしますが、遠いほど少なくなります。';

  @override
  String get inviteTreeHowOthers =>
      'あなたの最初のペアには、あなたが招待していない人が入ることもあります。その人たちも同じようにあなたのデータを増やします。';

  @override
  String inviteTreeHowActive(int days, int window) {
    return '友だちは、直近 $window 日のうち $days 日以上 Fortiva を使っていればアクティブとして数えられます。';
  }

  @override
  String get inviteTreeHowActiveNoNumber =>
      '友だちは、Fortiva を使い続けている間アクティブとして数えられます。';

  @override
  String inviteTreeHowCap(String max) {
    return '招待で増やせるデータは、毎日最大 $max までです。';
  }

  @override
  String get inviteTreeHowCapNoAmount => '招待で増やせるデータには、毎日の上限があります。';

  @override
  String get premiumSourceInvite => '招待で獲得';

  @override
  String quotaBonusIncluded(String amount) {
    return '招待ボーナス $amount を含む';
  }

  @override
  String get updateTitle => 'アップデートがあります';

  @override
  String get updateRequiredTitle => 'アップデートが必要です';

  @override
  String updateBody(String version) {
    return 'Fortiva $version が公開されました。最新の修正を入れるには更新してください。';
  }

  @override
  String get updateRequiredBody =>
      'このバージョンはサポートされなくなりました。Fortiva を使い続けるには更新してください。';

  @override
  String get updateNow => '更新';

  @override
  String get updateLater => '後で';

  @override
  String get updateFromPlay => 'Google Play';

  @override
  String get updateFromTelegram => 'Telegram チャンネル';

  @override
  String get updateConnect => '接続';

  @override
  String get updateConnectHint =>
      'Google Play や Telegram が開かない場合は、先に「接続」をタップしてください。';

  @override
  String get updateConnected => '接続しました。今すぐ更新をダウンロードしてください。';

  @override
  String get updateReconnect => 'つながらない場合は再接続';

  @override
  String get updateDisconnect => '切断';

  @override
  String get updateDisconnectHint => '「切断」をタップすると、通常のインターネット接続で更新をダウンロードできます。';

  @override
  String get updateNotCarrying =>
      '接続していますが、通信できていません。再接続するか、「切断」をタップして通常のインターネット接続を使ってください。';

  @override
  String get diagVerdictNoInternet =>
      'お使いのスマホはインターネットに接続されていません。復旧するまで Fortiva は接続できません。';

  @override
  String get diagVerdictCutOff =>
      '現在、お使いのネットワークから国際インターネットに接続できません。数分後にもう一度お試しください。';

  @override
  String get diagVerdictNeedsPermission =>
      'Fortiva に VPN を実行する権限がないか、別の VPN アプリが常時接続に設定されています。';

  @override
  String get diagVerdictServerUnreachable =>
      'このサーバーにはお使いのネットワークから到達できません。ここでブロックされているか、停止しています。';

  @override
  String get diagVerdictBlockedTls =>
      'このサーバーへの接続が、確立の途中で切断されています。これはフィルタリングの特徴です。';

  @override
  String get diagVerdictThrottled =>
      'サーバーはすべての確認に応答しましたが、トンネルには何も通りませんでした。接続速度が制限されています。';

  @override
  String get diagCheckInternet => 'インターネット接続を確認';

  @override
  String diagTryServer(String server) {
    return '$server で新しく検索';
  }

  @override
  String get diagTryAnotherServer => '別のサーバーを試す';

  @override
  String get diagDetails => '詳細を表示';

  @override
  String get diagDetailsHide => '詳細を隠す';

  @override
  String privateDnsWarning(String host) {
    return 'プライベート DNS がオンになっています（$host）。そのため一部のサイトが開かないことがあります。端末の設定でプライベート DNS をオフにしてください。';
  }

  @override
  String get openNetworkSettings => 'ネットワーク設定を開く';

  @override
  String testPointStatus(String time, int open, int total) {
    return 'テストポイント · 最終確認 $time · $total 中 $open 経路が開通';
  }

  @override
  String get messagesTooltip => 'メッセージ';

  @override
  String get inboxTitle => 'メッセージ';

  @override
  String get inboxEmpty => '現在メッセージはありません。';

  @override
  String get messageClose => '閉じる';

  @override
  String get supportTitle => 'サポート';

  @override
  String get supportTooltip => 'サポートとチャット';

  @override
  String get supportAskAction => 'サポートに質問';

  @override
  String get supportContactSubtitle => 'アプリ内でチャットできます';

  @override
  String get supportAutomaticNotice => '回答は自動で作成されるため、誤りを含む場合があります。';

  @override
  String get supportStaffNotice => '現在、自動回答は停止しています。メッセージはチームに届きます。';

  @override
  String get supportInputHint => '質問を入力';

  @override
  String get supportInputHintTeam => 'チームへのメッセージを入力';

  @override
  String get supportSend => '送信';

  @override
  String supportQuotaLeft(int remaining, int limit) {
    return '今日の残り質問数：$remaining/$limit';
  }

  @override
  String supportWaitIn(String time) {
    return '$time後に再び質問できます。';
  }

  @override
  String supportDurationHours(int hours, int minutes) {
    return '$hours時間$minutes分';
  }

  @override
  String supportDurationMinutes(int minutes) {
    return '$minutes分';
  }

  @override
  String get supportNewConversation => '新しい会話';

  @override
  String get supportSending => '送信中';

  @override
  String get supportNotSent => '送信できませんでした。タップして再試行してください。';

  @override
  String get supportRateUp => '役に立った';

  @override
  String get supportRateDown => '役に立たなかった';

  @override
  String get supportRatedDown => 'ありがとうございます。チームがこの回答を確認します。';

  @override
  String get supportTeamLabel => 'Fortivaチーム';

  @override
  String get supportUnavailable => '現在チャットはご利用いただけません。';

  @override
  String get supportOpenTelegram => 'Telegramでメッセージを送る';

  @override
  String get supportGenericError => '問題が発生しました。もう一度お試しください。';

  @override
  String supportCodeTooLong(int max) {
    return 'メッセージが長すぎます。$max文字未満にしてください。';
  }

  @override
  String get supportCodeEmpty => 'メッセージが空です。';

  @override
  String get supportCodeWaitReply => '前の質問への回答をお待ちください。';

  @override
  String get supportCodeSlowDown => 'メッセージの送信が速すぎます。少しお待ちください。';

  @override
  String get supportCodeQuotaDay => '今日の質問はすべて使い切りました。';

  @override
  String get supportCodePaused => '自動回答は一時停止中です。';

  @override
  String get supportCodeBusy => 'アシスタントは現在混み合っています。数分後にもう一度お試しください。';

  @override
  String get supportCodeGreeting => 'こんにちは！Fortivaについて何をお手伝いしましょうか？';

  @override
  String get supportCodeGibberish => 'すみません、よくわかりませんでした。もう一度質問を書いてください。';

  @override
  String get supportCodeRedacted => 'メッセージから個人情報とリンクを削除しました。';

  @override
  String get supportCodeRedactedEmpty =>
      'メッセージが個人情報やリンクだけだったため、送信されませんでした。問題を言葉で説明してください。';

  @override
  String get supportCodeOffTopic => 'Fortivaの使い方に関する質問にのみお答えできます。';

  @override
  String get supportCodeAbuse => '丁寧な言葉でお願いします。Fortivaについてお手伝いします。';

  @override
  String get supportCodeAiUnavailable =>
      '今回はアシスタントが回答できませんでした。少ししてからもう一度お試しください。';

  @override
  String get supportCodeToStaff => 'チームに送信しました。返信はここに表示されます。';

  @override
  String get supportCodeTicketOpened => '質問をチームに引き継ぎました。返信はここに表示されます。';

  @override
  String get supportCodeNotSent => 'このメッセージは送信できませんでした。まだお困りの場合は、もう一度入力してください。';

  @override
  String get supportAssistantSubtitle => 'AIアシスタント';

  @override
  String get supportThinkingReading => '質問を読んでいます';

  @override
  String get supportThinkingSearching => '答えを探しています';

  @override
  String get supportThinkingWriting => '答えを書いています';

  @override
  String get supportThinkingStill => 'まだ対応中です。お待ちいただきありがとうございます';

  @override
  String get supportSuggestConnect => '接続できません';

  @override
  String get supportSuggestData => '今日はあとどれくらいデータを使えますか？';

  @override
  String get supportSuggestSlow => '接続が遅いです';

  @override
  String get supportWithTeam => 'この会話は現在チームが対応しています。';

  @override
  String get supportTryAgainSoon => '数分後にもう一度お試しください。';

  @override
  String supportDurationWholeHours(int hours) {
    return '$hours時間';
  }

  @override
  String get supportUnreadReply => '新しい返信があります';

  @override
  String get premiumTitle => 'プレミアム';

  @override
  String get premiumTileSubtitle => 'データ無制限、日ごとの上限なし';

  @override
  String get premiumTileActive => 'プレミアム有効';

  @override
  String get premiumGetUnlimited => '無制限にする';

  @override
  String get premiumHeadline => 'データを無制限に';

  @override
  String get premiumPitch => 'プレミアムでは日ごとの上限がなくなり、期間が終わるまで好きなだけデータを使えます。';

  @override
  String get premiumActiveTitle => 'プレミアム有効';

  @override
  String premiumActiveUntil(String date) {
    return '$date までデータ無制限';
  }

  @override
  String get premiumActiveNoDate => 'データ無制限';

  @override
  String get premiumRenews => 'Google Play で自動更新されます';

  @override
  String get premiumSourceKey => 'キーで有効化';

  @override
  String get premiumSourceCrypto => '暗号資産で支払い済み';

  @override
  String get premiumSourceStars => 'Telegram Stars で支払い済み';

  @override
  String get premiumSourceGooglePlay => 'Google Play で支払い済み';

  @override
  String get premiumSourceManual => 'Fortiva チームからのプレゼント';

  @override
  String get premiumYourKey => 'あなたのキー';

  @override
  String get premiumKeyHint => 'このキーは大切に保管してください。別のスマホで入力すると、プレミアムをそちらに移せます。';

  @override
  String premiumKeyMoves(int count, int days) {
    return 'キーは $days 日間に $count 回まで別のスマホへ移せます。';
  }

  @override
  String get premiumKeyMovesNoNumber => 'キーを別のスマホへ移せる回数には上限があります。';

  @override
  String get premiumCopy => 'コピー';

  @override
  String get premiumCopied => 'コピーしました';

  @override
  String get premiumChoosePlan => 'プランを選択';

  @override
  String premiumPlanDays(int days) {
    return '$days 日間データ無制限';
  }

  @override
  String get premiumPlanNoDays => 'データ無制限';

  @override
  String get premiumBuy => '購入';

  @override
  String get premiumPlayUnavailable => 'Google Play は現在利用できません。後でもう一度お試しください。';

  @override
  String get premiumPlayPending =>
      'お支払いは Google Play で保留中です。完了するとすぐにプレミアムが始まります。';

  @override
  String get premiumPlayConfirming => '購入を確認しています...';

  @override
  String get premiumPlayRetrying =>
      'お支払いは完了しましたが、まだ確認できていません。引き続き確認しますので、再度お支払いいただく必要はありません。';

  @override
  String get premiumPlayRefused => 'この購入を確認できませんでした。請求された場合はサポートにご連絡ください。';

  @override
  String get premiumPlayNotAvailable =>
      'プレミアムは現在このスマホではご利用いただけません。請求された場合はサポートにご連絡ください。';

  @override
  String get premiumNotAvailable => 'プレミアムは現在このスマホではご利用いただけません。';

  @override
  String get premiumPlayFailed => '購入が完了しませんでした。もう一度お試しください。';

  @override
  String get premiumNowOn => 'プレミアムが有効になりました。データ無制限をお楽しみください。';

  @override
  String get premiumRestore => '購入を復元';

  @override
  String get premiumRestoreDone => 'このスマホで購入を復元しました。';

  @override
  String get premiumRestoreNone => 'Google Play に復元できる購入がありません。';

  @override
  String get premiumRestoreFailed => '購入を復元できませんでした。後でもう一度お試しください。';

  @override
  String premiumRenewsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 日ごとに請求されます。解約するまで自動的に更新されます。',
      one: '毎日請求されます。解約するまで自動的に更新されます。',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 週間ごとに請求されます。解約するまで自動的に更新されます。',
      one: '毎週請求されます。解約するまで自動的に更新されます。',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count か月ごとに請求されます。解約するまで自動的に更新されます。',
      one: '毎月請求されます。解約するまで自動的に更新されます。',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 年ごとに請求されます。解約するまで自動的に更新されます。',
      one: '毎年請求されます。解約するまで自動的に更新されます。',
    );
    return '$_temp0';
  }

  @override
  String get premiumRenewsNoPeriod => '解約するまで自動的に更新されます。';

  @override
  String get premiumPlayCancelNote =>
      'Google Play でいつでも解約できます。プレミアムはお支払い済みの期間が終わるまで使えます。';

  @override
  String get premiumManageSubscription => '定期購入を管理・解約';

  @override
  String get premiumCurrentPlan => '現在のプラン';

  @override
  String get premiumPlaySubscribed =>
      'すでに Google Play の定期購入があります。管理や解約は Google Play で行えます。';

  @override
  String get premiumEnterCode => 'コードを入力';

  @override
  String get premiumNeedsPlayVersion =>
      'Google Play で購入するには、Google Play 版の Fortiva が必要です。';

  @override
  String get premiumOff => 'プレミアムは現在販売していません。';

  @override
  String get premiumLoadFailed => 'プレミアムを読み込めませんでした。接続を確認してもう一度お試しください。';

  @override
  String get premiumRetry => '再試行';

  @override
  String premiumPriceUsdt(String price) {
    return '$price USDT';
  }

  @override
  String premiumPriceStars(String stars) {
    return '$stars Telegram Stars';
  }

  @override
  String get premiumPayCrypto => '暗号資産で支払う';

  @override
  String get premiumTelegramTitle => 'Telegram で支払う';

  @override
  String get premiumTelegramBody =>
      '当社のボットで Telegram Stars を使って支払えます。キーが届き、このスマホですぐにプレミアムが始まります。';

  @override
  String get premiumTelegramButton => 'Telegram で購入';

  @override
  String get premiumTelegramFailed => 'Telegram を開けませんでした。もう一度お試しください。';

  @override
  String get checkoutTitle => '暗号資産で支払う';

  @override
  String get checkoutChooseNetwork => '送金に使うネットワークを選んでください';

  @override
  String get checkoutContinue => '続ける';

  @override
  String get checkoutSendExactly => 'この金額をそのまま送金してください';

  @override
  String get checkoutNetwork => 'ネットワーク';

  @override
  String get checkoutAddress => '送金先アドレス';

  @override
  String get checkoutMemo => 'メモ';

  @override
  String get checkoutMemoWarning => 'このメモを必ず送金に含めてください。含めないと、お支払いを照合できません。';

  @override
  String get checkoutExactWarning =>
      '正確な金額を、このネットワークでのみ送金してください。異なる金額やネットワークでは届かない場合があります。';

  @override
  String checkoutTimeLeft(String time) {
    return '残り時間: $time';
  }

  @override
  String get checkoutWaiting => 'お支払いを待っています。このページは自動で更新されます。';

  @override
  String get checkoutPaidTitle => 'お支払いを受け取りました';

  @override
  String get checkoutPaidKeyOnly => 'キーの準備ができました。プレミアムを使うスマホで入力してください。';

  @override
  String get checkoutDone => '完了';

  @override
  String get checkoutExpired => 'この注文は期限切れです。すでにお支払い済みの場合はサポートにご連絡ください。';

  @override
  String get checkoutUnderpaid => '受け取った金額が全額に足りません。サポートに連絡し、この注文番号をお伝えください:';

  @override
  String get checkoutCanceled => 'この注文はキャンセルされました。';

  @override
  String get checkoutStartAgain => '最初からやり直す';

  @override
  String get checkoutUnavailable => '暗号資産での支払いは現在利用できません。';

  @override
  String get checkoutTooManyOpen => '未払いの注文が多すぎます。いずれかを支払うか、期限切れになるまでお待ちください。';

  @override
  String get checkoutUnknownPlan => 'このプランは販売を終了しました。戻って別のプランを選んでください。';

  @override
  String get checkoutFailed => '支払いを開始できませんでした。接続を確認してもう一度お試しください。';

  @override
  String get redeemTitle => 'コードを入力';

  @override
  String get redeemSubtitle => 'プレミアムのキー、またはギフトコード';

  @override
  String get redeemHint => 'コード';

  @override
  String get redeemApply => '適用';

  @override
  String get redeemCancel => 'キャンセル';

  @override
  String get redeemInvalid => 'コードの形式ではないようです。確認してもう一度お試しください。';

  @override
  String get redeemUnknown => 'このコードは見つかりません。確認してもう一度お試しください。';

  @override
  String get redeemExpired => 'このコードは期限切れです。';

  @override
  String get redeemRevoked => 'このコードは無効になっています。';

  @override
  String get redeemMovedTooOften => 'このキーは最近スマホ間の移動が多すぎます。後でもう一度お試しください。';

  @override
  String get redeemExhausted => 'このコードは使用上限に達しました。';

  @override
  String get redeemAlreadyUsed => 'このスマホではすでにこのコードを使っています。';

  @override
  String get redeemUnmetered => 'このスマホはすでにデータ無制限なので、このコードは必要ありません。';

  @override
  String get redeemRateLimited => '試行回数が多すぎます。少し待ってからもう一度お試しください。';

  @override
  String get redeemUnavailable => '現在ご利用いただけません。後でもう一度お試しください。';

  @override
  String get redeemNetwork => 'サーバーに接続できませんでした。接続を確認してもう一度お試しください。';

  @override
  String get redeemFailed => 'このコードは使えませんでした。確認してもう一度お試しください。';

  @override
  String get redeemMoved => 'プレミアムをこのスマホに移しました。';

  @override
  String redeemPromo(String amount) {
    return 'コードを受け付けました。$amount の追加データを付与しました。';
  }

  @override
  String get redeemPromoNoAmount => 'コードを受け付けました。追加データを付与しました。';

  @override
  String get tvScanTitle => 'スマートフォンで開く';

  @override
  String get tvScanBody => 'スマートフォンのカメラをこのコードに向けてください。';

  @override
  String get refresh => '更新';

  @override
  String get premiumNotNow => '今はしない';

  @override
  String get premiumLimitSheetTitle => '本日のデータを使い切りました';

  @override
  String get premiumLimitWait => 'リセットを待つ';

  @override
  String get premiumLimitInvite => '友達を招待してデータを増やす';

  @override
  String get premiumNoDailyLimit => 'プレミアムには日ごとの上限がありません。';

  @override
  String get premiumCalmTitle => '日ごとの上限をなくしませんか？';

  @override
  String get premiumCalmBody => 'プレミアムならデータが無制限です。無料プランはそのまま使えます。';

  @override
  String get premiumNextStepTitle => '次のステップはプレミアム';

  @override
  String get premiumNextStepBody => '無料のデータはすでに最大です。プレミアムには日ごとの上限がありません。';

  @override
  String get premiumLockedTag => 'プレミアム';

  @override
  String premiumLockedTitle(String place) {
    return 'プレミアムで$placeのロックを解除';
  }

  @override
  String get premiumLockedBody => 'この場所はプレミアム専用です。無料のサーバーはこれまでどおりです。';

  @override
  String get premiumHeadlineLimit => '日ごとの上限なし';

  @override
  String premiumHeadlineLocked(String place) {
    return 'プレミアムで$placeのロックを解除';
  }

  @override
  String get premiumFreeStays => '無料プランはプレミアムなしでも引き続き使えます。';

  @override
  String premiumEndsOn(String date) {
    return 'プレミアムは$dateに終了します';
  }

  @override
  String get premiumRenewBody => '更新すると無制限のデータを使い続けられます。更新した期間は現在の終了日に追加されます。';

  @override
  String premiumEndedOn(String date) {
    return 'プレミアムは$dateに終了しました。無料プランに戻りました。';
  }

  @override
  String get premiumRenew => '更新';

  @override
  String get noticeChannelName => 'Fortiva からのメッセージ';

  @override
  String get noticeChannelDescription => 'Fortiva チームからのお知らせとメッセージ';

  @override
  String get noticesSettingTitle => '通知';

  @override
  String get noticesSettingOn => 'オン。アプリを閉じていても Fortiva チームからのメッセージを受け取れます。';

  @override
  String get noticesSettingOff =>
      'オフ。オンにすると、アプリを閉じていても Fortiva チームからのメッセージが届きます。';

  @override
  String get noticesOffCard => '通知をオンにすると、アプリを閉じていても Fortiva チームからのメッセージが届きます。';

  @override
  String get noticesTurnOn => 'オンにする';

  @override
  String get backgroundCard =>
      'アプリを閉じている間、端末が Fortiva チームからのメッセージを止めることがあります。メッセージが届くように、Fortiva のバックグラウンドでの実行を許可してください。';

  @override
  String get backgroundHint =>
      '次の画面で Fortiva を選んでください（表示されない場合はすべてのアプリを表示）。次に、電池の使用を「制限なし」にするか、自動起動とバックグラウンドでの実行を許可してください。';

  @override
  String get backgroundAllow => '許可する';

  @override
  String get backgroundNotNow => '後で';

  @override
  String get backgroundSettingTitle => 'アプリを閉じているときのメッセージ';

  @override
  String get backgroundSettingSubtitle =>
      'Fortiva のバックグラウンドでの実行を許可すると、アプリを閉じていてもメッセージが届きます。';

  @override
  String get backgroundCardData =>
      'アプリを閉じている間、端末のデータセーバーが Fortiva チームからのメッセージを止めることがあります。';

  @override
  String get backgroundHintData => '次の画面で「データ使用量を制限しない」をオンにしてください。';

  @override
  String get apnGuideTitle => 'このSIMの接続をより安定させる';

  @override
  String get apnGuideBody =>
      'この端末はこのSIMでIPv6を使っていません。オンにすると、Fortivaの接続が途切れにくくなります。';

  @override
  String get apnGuideShowMe => 'やり方を見る';

  @override
  String get apnGuideNotNow => '今はしない';

  @override
  String get apnGuideSheetTitle => 'このSIMでIPv6をオンにする';

  @override
  String apnGuideStepOpen(String button) {
    return '「$button」をタップします（または 設定 > 接続 > モバイルネットワーク > アクセスポイント名 を開きます）。';
  }

  @override
  String apnGuideStepAccessPoint(String apn) {
    return '使用中のアクセスポイント（$apn）をタップします。';
  }

  @override
  String get apnGuideStepAccessPointAny => '使用中のアクセスポイントをタップします。';

  @override
  String get apnGuideStepProtocol => '「APNプロトコル」をタップし、「IPv4/IPv6」を選びます。';

  @override
  String get apnGuideStepSave => '保存します（Samsungの場合は、三点メニューから「保存」）。';

  @override
  String get apnGuideStepRestart => 'モバイルデータをオフにして、もう一度オンにします。';

  @override
  String get apnGuideUndo => 'モバイルデータが使えなくなった場合は、APNプロトコルをIPv4に戻してください。';

  @override
  String get apnGuideOpenSettings => 'APN設定を開く';

  @override
  String get homeStallSearching => '接続が機能しなくなりました。別の経路を探しています。';

  @override
  String get homeStalled => '接続済みですが、データが通っていません';

  @override
  String get peerShareTitle => '友達の接続を手伝う';

  @override
  String get peerShareSubtitle => '接続に必要なものを友達のスマホに渡す';

  @override
  String get peerShareBody =>
      '友達の Fortiva が接続できないときは、必要なものをあなたのスマホから友達のスマホに渡せます。インターネットがなくても使えます。';

  @override
  String peerShareSteps(String action) {
    return '友達のスマホで Fortiva の設定を開き、「$action」をタップしてもらってください。そのあと、このコードを順番に見せるか、送信してください。';
  }

  @override
  String get peerShareLoading => '最新の内容を取得しています';

  @override
  String get peerShareNothing =>
      'このスマホには、まだ渡せる新しいものがありません。しばらくしてからもう一度お試しください。';

  @override
  String peerShareCodeOf(int current, int total) {
    return 'コード $current/$total';
  }

  @override
  String get peerSharePrevious => '前へ';

  @override
  String get peerShareNext => '次へ';

  @override
  String get peerShareCopy => 'コピー';

  @override
  String get peerShareSend => '送信';

  @override
  String get peerShareCopied => 'コピーしました。友達へのメッセージに貼り付けてください。';

  @override
  String get peerReceiveTitle => '友達に助けてもらう';

  @override
  String get peerReceiveSubtitle => 'ほかの方法で接続できないとき';

  @override
  String peerReceiveBody(String action) {
    return 'Fortiva が接続できている友達に、Fortiva の設定を開いて「$action」をタップするよう頼んでください。そのあと、次のいずれかの方法で友達のスマホから受け取ってください。';
  }

  @override
  String get peerReceivePhotograph => '友達のコードを撮影';

  @override
  String get peerReceivePhotographNext => '次のコードを撮影';

  @override
  String peerReceiveProgress(int have, int total) {
    return '$total 個中 $have 個のコードを読み取り済み';
  }

  @override
  String get peerReceiveFile => '友達から届いたファイルを開く';

  @override
  String get peerReceivePaste => '友達から届いた内容を貼り付け';

  @override
  String get peerReceiveNoCode => 'この写真ではコードが見つかりません。コード全体が写るように、スマホを近づけてください。';

  @override
  String get peerReceiveRefused => 'これは Fortiva で使えない内容です。友達にもう一度送ってもらってください。';

  @override
  String get peerReceiveNotNewer =>
      'すでに同じもの、またはより新しいものがあります。もう一度接続してみるか、別の友達に頼んでください。';

  @override
  String get peerReceiveTaken => '完了しました。ボタンをタップして接続してください。';

  @override
  String get peerReceiveUnavailable => 'このスマホではできません。別の方法をお試しください。';

  @override
  String get peerReceiveNothingToPaste =>
      'まだ何もコピーされていません。友達から届いた内容をコピーしてから、もう一度ここをタップしてください。';

  @override
  String get peerOfferBody =>
      'まだ接続できませんか？Fortiva が使えている友達がいれば、その友達のスマホから手伝ってもらえます。';

  @override
  String get peerReceiveAgain => 'このコードはすでに読み取り済みです。友達に次のコードを見せてもらってください。';

  @override
  String get peerReceivePasteNotOurs =>
      'コピーした内容は Fortiva のものではありません。友達のメッセージ全体をコピーして、もう一度お試しください。';

  @override
  String peerReceiveNoPhoto(String action) {
    return 'カメラから写真が返ってきませんでした。カメラアプリで撮影してから、「$action」をタップしてください。';
  }

  @override
  String get peerReceiveFileHint =>
      'メッセージアプリから届いたファイルは、先にダウンロードフォルダに保存する必要がある場合があります。';

  @override
  String get homeTryingBackup => 'ほかに接続できるものがありませんでした。予備のネットワークを試しています。';

  @override
  String get homeConnectedBackup => '予備のネットワーク経由で接続済み';

  @override
  String get backupNetwork => '予備のネットワーク';

  @override
  String get backupNetworkTitle => '予備のネットワーク';

  @override
  String get backupNetworkCaption => 'ほかに接続できないときに使われます。当社のサーバーより遅いことがあります。';

  @override
  String get backupNetworkPlace => '場所は自動で選ばれます';

  @override
  String get speedTestStart => 'テスト開始';

  @override
  String get speedTestAgain => '再テスト';

  @override
  String get speedTestRunning => 'テスト中';

  @override
  String get speedTestIdle => '今の接続速度を確かめましょう。';

  @override
  String get speedTestPhasePing => '応答時間を確認しています';

  @override
  String get speedTestPhaseDownload => 'ダウンロード速度を測定しています';

  @override
  String get speedTestPhaseUpload => 'アップロード速度を測定しています';

  @override
  String get speedTestDone => 'テスト完了';

  @override
  String get speedTestFailed => 'テストを完了できませんでした。インターネット接続を確認して、もう一度お試しください。';

  @override
  String get speedTestUnit => 'Mbps';

  @override
  String get ipAddressLabel => 'IPアドレス';

  @override
  String get ipCopied => 'アドレスをコピーしました';

  @override
  String get ipLocation => '場所';

  @override
  String get ipProvider => 'インターネット事業者';

  @override
  String get ipOrganization => '組織';

  @override
  String get ipTimeZone => 'タイムゾーン';

  @override
  String get ipCoordinates => '座標';

  @override
  String get ipCheckFailed => 'アドレスを確認できませんでした';

  @override
  String get historyAverage => '平均接続時間';

  @override
  String get historyRecentDays => '最近のアクティビティ';

  @override
  String yesterdayAt(String time) {
    return '昨日 $time';
  }

  @override
  String dateAt(String date, String time) {
    return '$date $time';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds秒';
  }

  @override
  String get stageOwn => 'Fortiva のサーバー';

  @override
  String get stageCommunity => 'コミュニティサーバー';

  @override
  String stageProgress(int n, int total) {
    return 'ステップ $n / $total';
  }

  @override
  String get stageTryingOwn => 'Fortiva のサーバーを試しています';

  @override
  String get stageTryingCommunity => 'コミュニティサーバーを試しています';

  @override
  String get stageOwnFailedTryingCommunity =>
      'ここでは Fortiva のサーバーに接続できませんでした。コミュニティサーバーを試しています。';

  @override
  String stageLastWorked(String server) {
    return '前回つながったサーバー: $server';
  }

  @override
  String stageTriedBlocked(int count) {
    return '$count 件の経路を試しました。ここではブロックされています';
  }

  @override
  String stageTriedFailed(int count) {
    return '$count 件の経路を試しました。どれも接続できませんでした';
  }

  @override
  String get stageNotConnected => '接続できませんでした';

  @override
  String get stageConnected => 'ここで接続しました';

  @override
  String get stageSkipped => '今回は使いませんでした';

  @override
  String stageMoreToCheck(int count) {
    return 'あと $count 件の経路を確認します';
  }

  @override
  String stageNextTry(String stage, String time) {
    return '$time 後に $stage から再試行します';
  }

  @override
  String get searchSlowHint => '少し時間がかかることがあります。ボタンをタップすると検索を止めます。';

  @override
  String get searchStopped => '検索を止めました';

  @override
  String get homeConnectedCommunity => 'コミュニティサーバー経由で接続済み';

  @override
  String get stageGettingServers => 'サーバーを取得しています';

  @override
  String stageNextTryStarting(String stage) {
    return '$stage から再試行を始めています';
  }
}
