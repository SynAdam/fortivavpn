// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class SZh extends S {
  SZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Fortiva';

  @override
  String get statusDisconnected => '未连接';

  @override
  String get statusConnecting => '正在连接';

  @override
  String get statusConnected => '已连接';

  @override
  String get statusDisconnecting => '正在断开...';

  @override
  String get statusError => '错误';

  @override
  String get statusVerifying => '正在验证...';

  @override
  String get disconnect => '断开';

  @override
  String get connectBtn => '连接';

  @override
  String get disconnectBtn => '断开连接';

  @override
  String get pleaseWait => '请稍候';

  @override
  String get locationLabel => '位置';

  @override
  String get selectServer => '选择位置';

  @override
  String get serverLocation => '位置';

  @override
  String get searchServers => '搜索服务器';

  @override
  String get locationsTitle => '位置';

  @override
  String get sortLatency => '排序：延迟';

  @override
  String get sortAZ => '排序：A-Z';

  @override
  String get sortedByLatency => '已按延迟排序';

  @override
  String get sortedAZ => '已按 A-Z 排序';

  @override
  String get pingAll => '全部测试';

  @override
  String get pinging => '正在测试...';

  @override
  String get ping => 'Ping';

  @override
  String get stop => '停止';

  @override
  String get fastestServer => '最快';

  @override
  String get timeout => '超时';

  @override
  String get tabCommunity => '社区';

  @override
  String get tabFree => '免费';

  @override
  String get tabPremium => '高级版';

  @override
  String get noCommunityServers => '暂无社区服务器';

  @override
  String get communityLoadFailed => '无法加载此列表';

  @override
  String get communityRetry => '重试';

  @override
  String get officialTabExplainer => '由 Fortiva 运营并保持在线。所有使用本应用的用户共享。从这里开始。';

  @override
  String get communityTabExplainer => '额外的连接选项。速度和可用性可能有所不同。';

  @override
  String get noFreeServers => '暂无免费服务器';

  @override
  String get noPremiumServers => '暂无高级版服务器';

  @override
  String noResultsFor(String query) {
    return '没有找到「$query」的结果';
  }

  @override
  String get proBadge => '高级版';

  @override
  String get freeBadge => '免费';

  @override
  String get settings => '设置';

  @override
  String get connection => '网络';

  @override
  String get dnsConfiguration => 'DNS';

  @override
  String get customDns => '使用您自己的 DNS 服务器';

  @override
  String get about => '关于';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get contactUs => '联系我们';

  @override
  String get rateOnGooglePlay => '在 Google Play 上为 Fortiva 评分';

  @override
  String get website => '网站';

  @override
  String get copyright => '© 2026 NimusAI';

  @override
  String get version => '版本';

  @override
  String get language => '语言';

  @override
  String get languageSubtitle => '界面语言';

  @override
  String get whatIsDns => '什么是 DNS？';

  @override
  String get dnsExplanation =>
      'DNS 会把网站名称转换成您的手机可以访问的地址。使用不同的 DNS 可以让网站加载更快，也有助于访问被您的运营商屏蔽的网站。';

  @override
  String get configuration => '设置';

  @override
  String get primaryDns => '主 DNS';

  @override
  String get primaryDnsHint => '默认：1.1.1.1';

  @override
  String get secondaryDns => '备用 DNS（可选）';

  @override
  String get secondaryDnsHint => '默认：8.8.8.8';

  @override
  String get saveConfiguration => '保存';

  @override
  String get dnsSaved => 'DNS 设置已保存';

  @override
  String get invalidPrimaryDns => '该主 DNS 地址无效';

  @override
  String get invalidSecondaryDns => '该备用 DNS 地址无效';

  @override
  String get statistics => '历史记录';

  @override
  String get overview => '概览';

  @override
  String get connectionsLabel => '会话次数';

  @override
  String get totalTime => '连接时长';

  @override
  String get dataUsage => '已用流量';

  @override
  String get uploaded => '已上传';

  @override
  String get downloaded => '已下载';

  @override
  String get total => '总计';

  @override
  String lastUpdated(String date) {
    return '最后更新：$date';
  }

  @override
  String today(String time) {
    return '今天 $time';
  }

  @override
  String get yesterday => '昨天';

  @override
  String daysAgo(int count) {
    return '$count 天前';
  }

  @override
  String get noDataYet => '暂无会话数据';

  @override
  String get connectToStart => '连接后开始记录';

  @override
  String get errorConnectionFailed => '无法连接';

  @override
  String get errorServerNotWorking => '此位置无法使用。请试试其他位置。';

  @override
  String get errorServerNotForwarding => '此位置无法传输流量。请试试其他位置。';

  @override
  String get errorUnexpected => '意外错误';

  @override
  String get errorDisconnectionFailed => '无法断开连接';

  @override
  String get errorFailedToRegister => '设备注册失败';

  @override
  String get ipInformation => '查看我的 IP';

  @override
  String get connectionAnalytics => '历史记录';

  @override
  String get recentSessions => '最近的连接';

  @override
  String get speedTest => '速度测试';

  @override
  String get startTest => '运行诊断';

  @override
  String get download => '下载';

  @override
  String get upload => '上传';

  @override
  String get testingViaVpn => '正在通过隧道测试';

  @override
  String get testingDirect => '正在测试直接连接';

  @override
  String get splitTunneling => '路由配置';

  @override
  String get splitTunnelingDescription => '选择哪些应用类别绕过隧道。被排除的应用将使用您的直接网络连接。';

  @override
  String get enableSplitTunneling => '启用分流';

  @override
  String get splitTunnelActive => '所选应用绕过隧道';

  @override
  String get splitTunnelInactive => '所有流量都经过隧道';

  @override
  String get bypassVpnFor => '绕过隧道的应用';

  @override
  String get tools => '诊断';

  @override
  String get settingsGeneral => '通用';

  @override
  String get shareDiagnosticsTitle => '分享连接诊断信息';

  @override
  String get shareDiagnosticsBody =>
      '发送连接报告、您的运营商和国家/地区、手机型号和 Android 版本、您通过 VPN 访问的网站名称及每日次数，以及您是否看过或点击过我们的消息、高级版优惠和邀请卡片。我们绝不会看到您打开的页面或您发送的内容。';

  @override
  String get security => '合规';

  @override
  String get privacyDashboard => '端点分析';

  @override
  String get privacyDashboardSubtitle => 'IP 透明度与泄漏监测';

  @override
  String get connectionAnalyticsSubtitle => '会话历史与报告';

  @override
  String get speedTestSubtitle => '吞吐量测量';

  @override
  String get splitTunnelingSubtitle => '配置路由策略';

  @override
  String get splashTagline => '无论您身在何处，都能私密访问';

  @override
  String get openSourceLicence => '开源许可证';

  @override
  String get sourceOfferTitle => '开源许可证';

  @override
  String get sourceOfferBody =>
      'Fortiva VPN 是基于 GNU General Public License v3 的自由软件。它构建于 Xray-core 和其他开源项目之上。\n\n您有权获得您所安装版本的完整源代码。如需索取，请发送邮件至 admin@fortivavpn.com 并注明您的应用版本。此承诺自您收到此版本之日起三年内有效。';

  @override
  String get close => '关闭';

  @override
  String get account => '账户';

  @override
  String get deleteAccount => '删除账户';

  @override
  String get deleteAccountSubtitle => '永久移除此设备和您的数据';

  @override
  String get deleteAccountConfirmTitle => '删除您的账户？';

  @override
  String get deleteAccountConfirmBody =>
      '这将移除您的设备注册、已关联的 Google 账户、为您创建的个人服务器以及您的客服聊天消息。此手机上的连接历史也会被清除。\n\n此操作无法撤销。您随时可以重新打开应用，从头开始。';

  @override
  String deleteAccountConfirmRetention(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days 天',
    );
    return '您的账户记录会立即删除。备份中的副本和匿名服务器日志会在 $_temp0 内清除。';
  }

  @override
  String get deleteAccountConfirmRetentionNoDays =>
      '您的账户记录会立即删除。备份中的副本和匿名服务器日志会稍后按照我们隐私政策中的时间安排清除。';

  @override
  String get deleteAccountCancel => '保留我的账户';

  @override
  String get deleteAccountConfirm => '删除';

  @override
  String get deleteAccountInProgress => '正在删除您的账户';

  @override
  String get deleteAccountDone => '您的账户已删除。';

  @override
  String get deleteAccountFailed => '无法删除您的账户。请检查网络连接后重试。';

  @override
  String get homeTapToConnect => '点击连接';

  @override
  String get homeChecking => '正在检查连接';

  @override
  String get homePreparing => '正在准备您的服务器';

  @override
  String get homeDisconnecting => '正在断开连接';

  @override
  String get homeFindingPath => '正在寻找路径';

  @override
  String get diagCheckingInternet => '正在检查您的网络';

  @override
  String get diagInternationalCut => '此网络的国际互联网已中断';

  @override
  String diagPathRow(String city, int n) {
    return '$city，路径 $n';
  }

  @override
  String get diagOpen => '畅通';

  @override
  String get diagBlocked => '已屏蔽';

  @override
  String get diagSkipped => '今天已跳过';

  @override
  String diagConnectingThrough(String city) {
    return '正在通过 $city 连接';
  }

  @override
  String get diagVerifying => '正在验证流量';

  @override
  String get diagNoInternet => '您的手机目前没有网络。';

  @override
  String get diagCutOff => '您的网络目前无法访问国际互联网。点击重试。';

  @override
  String get diagNothingOpen => '目前所有路径都被屏蔽。点击重试。';

  @override
  String get homeTryingAgain => '目前所有路径都被屏蔽。稍后将自动重试。';

  @override
  String get homeCutOffTryingAgain => '您的网络目前无法访问国际互联网。稍后将自动重试。';

  @override
  String get homeOfflineTryingAgain => '您的手机目前没有网络。稍后将自动重试。';

  @override
  String get diagPathFailed => '路径畅通，但隧道未能建立。点击重试。';

  @override
  String get openVpnSettings => '打开 VPN 设置';

  @override
  String get yourServer => '您的服务器';

  @override
  String get yourServerCaption => '专属于您。没有其他人通过它连接。';

  @override
  String get ourServer => '我们的服务器';

  @override
  String get ourServerCaption => '由 Fortiva 运营，所有人共享。在您自己的服务器准备好之前使用。';

  @override
  String get communityServer => '社区服务器';

  @override
  String get communityServerCaption => '额外的连接选项。随时可能停止工作。';

  @override
  String communityServerNumber(String n) {
    return '社区服务器 $n';
  }

  @override
  String get myServersTitle => '您的服务器';

  @override
  String get myServersExplainer => '每台 Fortiva 设备在每个位置都有自己的服务器，凭据仅属于本次安装。无需账户。';

  @override
  String get myServersInUse => '使用中';

  @override
  String get myServersEmpty => '尚未分配服务器';

  @override
  String get myServersRetry => '重试';

  @override
  String get myServersBlockedTitle => '您已用完今天的流量';

  @override
  String get myServersBlockedWait => '您的流量额度会自动重置。请稍后再来查看。';

  @override
  String myServersMoved(String place) {
    return '现在使用 $place';
  }

  @override
  String get copyLink => '复制链接';

  @override
  String get linkCopied => '链接已复制';

  @override
  String quotaUsedToday(String used, String limit) {
    return '今天已用 $used，共 $limit';
  }

  @override
  String get quotaUsedUp => '每日流量已用完';

  @override
  String get quotaUnlimited => '无限流量';

  @override
  String get quotaDaily => '每日流量';

  @override
  String get quotaLimitReached => '已达每日上限';

  @override
  String quotaLeftOf(String left, String limit) {
    return '剩余 $left，共 $limit';
  }

  @override
  String get quotaResetsShortly => '即将重置';

  @override
  String quotaResetsInHours(int hours) {
    return '$hours 小时后重置';
  }

  @override
  String quotaResetsInMinutes(int minutes) {
    return '$minutes 分钟后重置';
  }

  @override
  String get myServersSubtitle => '为此设备配置的服务器';

  @override
  String get sharedServersTitle => '共享服务器';

  @override
  String get sharedServersSubtitle => '公共位置，作为备用';

  @override
  String get tabOfficial => '我们的服务器';

  @override
  String get noOfficialServers => '目前没有 Fortiva 服务器';

  @override
  String get inviteTitle => '邀请好友';

  @override
  String get inviteSubtitle => '赚取额外的每日流量';

  @override
  String get inviteYourCode => '您的邀请码';

  @override
  String get inviteShareAction => '分享邀请';

  @override
  String get inviteCopyAction => '复制邀请码';

  @override
  String get inviteCodeCopied => '邀请码已复制';

  @override
  String inviteShareMessage(String code, String url) {
    return '我在用的免费 VPN：Fortiva，很好用，无需注册。\n通过这个链接安装：\n$url\n我的邀请码：$code';
  }

  @override
  String get inviteHowItWorks => '运作方式';

  @override
  String inviteHowItWorksBody(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days 天',
    );
    return '分享您的邀请码。当有人安装应用、输入邀请码并累计使用 VPN $_temp0 后，您的每日流量将增加 $amount。它会一直保留在您的账户中。';
  }

  @override
  String inviteHowItWorksBodyNoAmount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days 天',
    );
    return '分享您的邀请码。当有人安装应用、输入邀请码并累计使用 VPN $_temp0 后，您每天都会获得更多流量。它会一直保留在您的账户中。';
  }

  @override
  String inviteHowItWorksBodyNoDays(String amount) {
    return '分享您的邀请码。当有人安装应用、输入邀请码并使用 VPN 一段时间后，您的每日流量将增加 $amount。它会一直保留在您的账户中。';
  }

  @override
  String get inviteHowItWorksBodyNoAmountNoDays =>
      '分享您的邀请码。当有人安装应用、输入邀请码并使用 VPN 一段时间后，您每天都会获得更多流量。它会一直保留在您的账户中。';

  @override
  String inviteHowItWorksCap(String max) {
    return '通过邀请，您每天最多可获得 $max。';
  }

  @override
  String get inviteStatInvited => '已邀请';

  @override
  String get inviteStatEarning => '已达标';

  @override
  String get inviteStatBonus => '奖励流量';

  @override
  String inviteBonusPerDay(String amount) {
    return '每天 +$amount';
  }

  @override
  String get inviteNoBonusYet => '暂无奖励';

  @override
  String invitePendingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个邀请尚未达标',
      one: '1 个邀请尚未达标',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String inviteJoinedWith(String code) {
    return '您通过邀请码 $code 加入';
  }

  @override
  String get inviteLoadFailed => '无法加载您的邀请码';

  @override
  String get inviteRetry => '重试';

  @override
  String get inviteHaveCodeTitle => '有邀请码吗？';

  @override
  String inviteHaveCodeSubtitle(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '请在安装后 $hours 小时内输入',
    );
    return '$_temp0';
  }

  @override
  String get inviteHaveCodeSubtitleNoHours => '请在安装后尽快输入';

  @override
  String get inviteEnterCodeHint => '邀请码';

  @override
  String get inviteApplyAction => '使用';

  @override
  String get inviteNotNowAction => '暂不';

  @override
  String inviteClaimAccepted(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days 天',
    );
    return '邀请已接受。当您累计使用 VPN $_temp0 后，您的好友将获得奖励流量。';
  }

  @override
  String get inviteClaimAcceptedNoDays => '邀请已接受。当您使用 VPN 一段时间后，您的好友将获得奖励流量。';

  @override
  String get inviteClaimAlready => '此设备已使用过邀请码';

  @override
  String get inviteClaimRejected => '该邀请码无效。请检查后重试';

  @override
  String get inviteClaimNetwork => '无法连接到服务器。请重试';

  @override
  String get inviteCardTitle => 'Fortiva 用着还好吗？发给朋友吧';

  @override
  String get inviteCardBody => '把安装链接发给朋友，让他们也能免费连接。';

  @override
  String inviteCardReward(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '朋友开始使用 Fortiva 后，您将获得 $days 天高级版。',
    );
    return '$_temp0';
  }

  @override
  String get inviteCardRewardNoAmount => '朋友开始使用 Fortiva 后，您将获赠高级版。';

  @override
  String get inviteSendTelegram => 'Telegram';

  @override
  String get inviteSendWhatsApp => 'WhatsApp';

  @override
  String get inviteCopyLink => '复制链接';

  @override
  String get inviteOtherApps => '其他应用';

  @override
  String get inviteLinkCopied => '邀请消息已复制';

  @override
  String get invitePasteBody => '从好友发来的消息中复制邀请码，然后粘贴到这里。';

  @override
  String get invitePasteAction => '粘贴';

  @override
  String get inviteErrorTooLate => '这部手机已超过输入邀请码的期限。';

  @override
  String get inviteErrorUnknown => '找不到这个邀请码。请从好友的消息中重新复制。';

  @override
  String get inviteErrorOwnCode => '这是您自己的邀请码。请输入好友的邀请码。';

  @override
  String get inviteErrorMutual => '您和好友不能互相邀请。';

  @override
  String inviteHowItWorksPremium(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '每位开始使用 Fortiva 的好友还会为您带来 $days 天高级版。',
    );
    return '$_temp0';
  }

  @override
  String inviteHowItWorksPremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '通过邀请，您最多可获得 $max 天高级版。',
    );
    return '$_temp0';
  }

  @override
  String get premiumSourceInvite => '来自您的邀请';

  @override
  String quotaBonusIncluded(String amount) {
    return '包含 $amount 邀请奖励';
  }

  @override
  String get updateTitle => '有可用更新';

  @override
  String get updateRequiredTitle => '需要更新';

  @override
  String updateBody(String version) {
    return 'Fortiva $version 已发布。请更新以获取最新修复。';
  }

  @override
  String get updateRequiredBody => '此版本已不再受支持。请更新以继续使用 Fortiva。';

  @override
  String get updateNow => '更新';

  @override
  String get updateLater => '稍后';

  @override
  String get updateFromPlay => 'Google Play';

  @override
  String get updateFromTelegram => 'Telegram 频道';

  @override
  String get updateConnect => '连接';

  @override
  String get updateConnectHint => '如果 Google Play 或 Telegram 打不开，请先点击「连接」。';

  @override
  String get updateConnected => '您已连接。现在就下载更新吧。';

  @override
  String get updateReconnect => '无法使用？重新连接';

  @override
  String get updateDisconnect => '断开连接';

  @override
  String get updateDisconnectHint => '点击「断开连接」，通过您的普通网络下载更新。';

  @override
  String get updateNotCarrying => '您已连接，但没有任何数据通过。请尝试重新连接，或点击「断开连接」使用您的普通网络。';

  @override
  String get diagVerdictNoInternet => '您的手机没有网络连接。在网络恢复之前，Fortiva 无法连接。';

  @override
  String get diagVerdictCutOff => '您的网络目前无法访问国际互联网。请几分钟后再试。';

  @override
  String get diagVerdictNeedsPermission =>
      'Fortiva 没有运行 VPN 的权限，或者其他 VPN 应用被设为始终开启。';

  @override
  String get diagVerdictServerUnreachable => '无法从您的网络访问此服务器。它要么在此处被屏蔽，要么已停机。';

  @override
  String get diagVerdictBlockedTls => '与此服务器的连接在建立过程中被切断。这正是网络过滤的表现。';

  @override
  String get diagVerdictThrottled => '服务器通过了所有检查，但隧道仍然没有传输任何数据。连接正在被限速。';

  @override
  String get diagCheckInternet => '检查您的网络';

  @override
  String diagTryServer(String server) {
    return '用 $server 重新搜索';
  }

  @override
  String get diagTryAnotherServer => '试试其他服务器';

  @override
  String get diagDetails => '详情';

  @override
  String get diagDetailsHide => '隐藏详情';

  @override
  String privateDnsWarning(String host) {
    return '私人 DNS 已开启（$host），因此部分网站可能无法打开。请在手机设置中关闭私人 DNS。';
  }

  @override
  String get openNetworkSettings => '打开网络设置';

  @override
  String testPointStatus(String time, int open, int total) {
    return '测试点 · 最后检查 $time · $total 个通道中有 $open 个畅通';
  }

  @override
  String get messagesTooltip => '消息';

  @override
  String get inboxTitle => '消息';

  @override
  String get inboxEmpty => '目前没有消息。';

  @override
  String get messageClose => '关闭';

  @override
  String get supportTitle => '客服';

  @override
  String get supportTooltip => '与客服聊天';

  @override
  String get supportAskAction => '咨询客服';

  @override
  String get supportContactSubtitle => '在应用内与我们聊天';

  @override
  String get supportAutomaticNotice => '回答由系统自动生成，可能有误。';

  @override
  String get supportStaffNotice => '自动回答暂时关闭。您的消息将发送给我们的团队。';

  @override
  String get supportInputHint => '请输入您的问题';

  @override
  String get supportInputHintTeam => '给我们的团队留言';

  @override
  String get supportSend => '发送';

  @override
  String supportQuotaLeft(int remaining, int limit) {
    return '今天剩余提问次数：$remaining/$limit';
  }

  @override
  String supportWaitIn(String time) {
    return '您可以在 $time 后再次提问。';
  }

  @override
  String supportDurationHours(int hours, int minutes) {
    return '$hours 小时 $minutes 分钟';
  }

  @override
  String supportDurationMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String get supportNewConversation => '新对话';

  @override
  String get supportSending => '正在发送';

  @override
  String get supportNotSent => '未发送。点击重试。';

  @override
  String get supportRateUp => '有帮助';

  @override
  String get supportRateDown => '没有帮助';

  @override
  String get supportRatedDown => '谢谢。我们的团队会查看这条回答。';

  @override
  String get supportTeamLabel => 'Fortiva 团队';

  @override
  String get supportUnavailable => '聊天功能目前不可用。';

  @override
  String get supportOpenTelegram => '在 Telegram 上给我们留言';

  @override
  String get supportGenericError => '出了点问题。请重试。';

  @override
  String supportCodeTooLong(int max) {
    return '您的消息太长了。请控制在 $max 个字符以内。';
  }

  @override
  String get supportCodeEmpty => '您的消息是空的。';

  @override
  String get supportCodeWaitReply => '请等待上一个问题的回答。';

  @override
  String get supportCodeSlowDown => '您发送消息太快了。请稍等片刻。';

  @override
  String get supportCodeQuotaDay => '您已用完今天的提问次数。';

  @override
  String get supportCodePaused => '自动回答已暂停。';

  @override
  String get supportCodeBusy => '我们的助手目前很忙。请过几分钟再试。';

  @override
  String get supportCodeGreeting => '您好！关于 Fortiva，有什么可以帮您？';

  @override
  String get supportCodeGibberish => '抱歉，我没有理解。请重新写一下您的问题。';

  @override
  String get supportCodeRedacted => '我们已从您的消息中移除了个人信息和链接。';

  @override
  String get supportCodeRedactedEmpty => '您的消息只包含个人信息或链接，因此未发送。请用文字描述问题。';

  @override
  String get supportCodeOffTopic => '我只能解答关于使用 Fortiva 的问题。';

  @override
  String get supportCodeAbuse => '请保持礼貌。我是来帮您解决 Fortiva 相关问题的。';

  @override
  String get supportCodeAiUnavailable => '助手这次无法回答。请稍后再试。';

  @override
  String get supportCodeToStaff => '已发送给我们的团队。他们的回复会显示在这里。';

  @override
  String get supportCodeTicketOpened => '我们已将您的问题转交给团队。他们的回复会显示在这里。';

  @override
  String get supportCodeNotSent => '此消息无法发送。如果您仍需帮助，请重新输入。';

  @override
  String get supportAssistantSubtitle => 'AI 助手';

  @override
  String get supportThinkingReading => '正在阅读您的问题';

  @override
  String get supportThinkingSearching => '正在寻找答案';

  @override
  String get supportThinkingWriting => '正在撰写回答';

  @override
  String get supportThinkingStill => '仍在处理中，感谢您的耐心等待';

  @override
  String get supportSuggestConnect => '我无法连接';

  @override
  String get supportSuggestData => '我今天还有多少流量？';

  @override
  String get supportSuggestSlow => '我的连接很慢';

  @override
  String get supportWithTeam => '此对话现在由我们的团队处理。';

  @override
  String get supportTryAgainSoon => '请过几分钟再试。';

  @override
  String supportDurationWholeHours(int hours) {
    return '$hours 小时';
  }

  @override
  String get supportUnreadReply => '新回复';

  @override
  String get premiumTitle => '高级版';

  @override
  String get premiumTileSubtitle => '无限流量，没有每日上限';

  @override
  String get premiumTileActive => '高级版已开启';

  @override
  String get premiumGetUnlimited => '获取无限流量';

  @override
  String get premiumHeadline => '获取无限流量';

  @override
  String get premiumPitch => '高级版取消每日上限，在到期之前您可以随意使用流量。';

  @override
  String get premiumActiveTitle => '高级版已开启';

  @override
  String premiumActiveUntil(String date) {
    return '无限流量至 $date';
  }

  @override
  String get premiumActiveNoDate => '无限流量';

  @override
  String get premiumRenews => '通过 Google Play 自动续订';

  @override
  String get premiumSourceKey => '已通过密钥激活';

  @override
  String get premiumSourceCrypto => '已通过加密货币支付';

  @override
  String get premiumSourceStars => '已通过 Telegram Stars 支付';

  @override
  String get premiumSourceGooglePlay => '已通过 Google Play 支付';

  @override
  String get premiumSourceManual => '来自 Fortiva 团队的礼物';

  @override
  String get premiumYourKey => '您的密钥';

  @override
  String get premiumKeyHint => '请妥善保管此密钥。在其他手机上输入它，即可将高级版转移过去。';

  @override
  String premiumKeyMoves(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days 天',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '最多可转移到其他手机 $count 次',
      one: '只能转移到其他手机 1 次',
    );
    return '密钥在 $_temp0 内$_temp1。';
  }

  @override
  String get premiumKeyMovesNoNumber => '密钥转移到其他手机的次数有限。';

  @override
  String get premiumCopy => '复制';

  @override
  String get premiumCopied => '已复制';

  @override
  String get premiumChoosePlan => '选择套餐';

  @override
  String premiumPlanDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days 天无限流量',
    );
    return '$_temp0';
  }

  @override
  String get premiumPlanNoDays => '无限流量';

  @override
  String get premiumBuy => '购买';

  @override
  String get premiumPlayUnavailable => 'Google Play 目前不可用。请稍后再试。';

  @override
  String get premiumPlayPending => '您的付款正在 Google Play 中等待处理。付款完成后高级版将立即开启。';

  @override
  String get premiumPlayConfirming => '正在确认您的购买...';

  @override
  String get premiumPlayRetrying => '您的付款已完成，但我们尚未能确认。我们会继续尝试，您无需再次付款。';

  @override
  String get premiumPlayRefused => '我们无法确认此次购买。如果您已被扣款，请联系客服。';

  @override
  String get premiumPlayNotAvailable => '高级版目前在此手机上不可用。如果您已被扣款，请联系客服。';

  @override
  String get premiumNotAvailable => '高级版目前在此手机上不可用。';

  @override
  String get premiumPlayFailed => '购买未完成。请重试。';

  @override
  String get premiumNowOn => '高级版已开启。尽情享用无限流量吧。';

  @override
  String get premiumRestore => '恢复购买';

  @override
  String get premiumRestoreDone => '您的购买已在此手机上恢复。';

  @override
  String get premiumRestoreNone => '此 Google 账户没有可恢复的购买。';

  @override
  String get premiumRestoreFailed => '无法恢复您的购买。请稍后再试。';

  @override
  String premiumRenewsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '每 $count 天扣费。自动续订，直到您取消。',
      one: '每天扣费。自动续订，直到您取消。',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '每 $count 周扣费。自动续订，直到您取消。',
      one: '每周扣费。自动续订，直到您取消。',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '每 $count 个月扣费。自动续订，直到您取消。',
      one: '每月扣费。自动续订，直到您取消。',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '每 $count 年扣费。自动续订，直到您取消。',
      one: '每年扣费。自动续订，直到您取消。',
    );
    return '$_temp0';
  }

  @override
  String get premiumRenewsNoPeriod => '自动续订，直到您取消。';

  @override
  String get premiumPlayCancelNote =>
      '您可以随时在 Google Play 中取消。高级版会持续到您已付费的期限结束。';

  @override
  String get premiumManageSubscription => '管理或取消订阅';

  @override
  String get premiumCurrentPlan => '当前套餐';

  @override
  String get premiumPlaySubscribed =>
      '您已有 Google Play 订阅。请在 Google Play 中管理或取消。';

  @override
  String get premiumEnterCode => '输入代码';

  @override
  String get premiumNeedsPlayVersion =>
      '要通过 Google Play 购买，您需要 Google Play 版本的 Fortiva。';

  @override
  String get premiumOff => '高级版目前暂停销售。';

  @override
  String get premiumLoadFailed => '无法加载高级版。请检查网络连接后重试。';

  @override
  String get premiumRetry => '重试';

  @override
  String premiumPriceUsdt(String price) {
    return '$price USDT';
  }

  @override
  String premiumPriceStars(String stars) {
    return '$stars 个 Telegram Stars';
  }

  @override
  String get premiumPayCrypto => '使用加密货币支付';

  @override
  String get premiumTelegramTitle => '在 Telegram 中支付';

  @override
  String get premiumTelegramBody =>
      '在我们的机器人中使用 Telegram Stars 支付。您会收到密钥，高级版会立即在此手机上开启。';

  @override
  String get premiumTelegramButton => '在 Telegram 中购买';

  @override
  String get premiumTelegramFailed => '无法打开 Telegram。请重试。';

  @override
  String get checkoutTitle => '使用加密货币支付';

  @override
  String get checkoutChooseNetwork => '选择您将用来转账的网络';

  @override
  String get checkoutContinue => '继续';

  @override
  String get checkoutSendExactly => '请准确发送';

  @override
  String get checkoutNetwork => '网络';

  @override
  String get checkoutAddress => '至此地址';

  @override
  String get checkoutMemo => '附带此备注';

  @override
  String get checkoutMemoWarning => '请在转账中填写此备注，否则我们无法将付款与您匹配。';

  @override
  String get checkoutExactWarning => '请发送准确的金额，且仅使用此网络。不同的金额或网络可能无法到达我们这里。';

  @override
  String checkoutTimeLeft(String time) {
    return '剩余时间：$time';
  }

  @override
  String get checkoutWaiting => '正在等待您的付款。此页面会自动更新。';

  @override
  String get checkoutPaidTitle => '已收到付款';

  @override
  String get checkoutPaidKeyOnly => '您的密钥已准备好。请在需要开启高级版的手机上输入。';

  @override
  String get checkoutDone => '完成';

  @override
  String get checkoutExpired => '此订单已过期。如果您已付款，请联系客服。';

  @override
  String get checkoutUnderpaid => '我们收到的金额不足。请联系客服并提供此订单号：';

  @override
  String get checkoutCanceled => '此订单已取消。';

  @override
  String get checkoutStartAgain => '重新开始';

  @override
  String get checkoutUnavailable => '加密货币支付目前不可用。';

  @override
  String get checkoutTooManyOpen => '您有太多未付款的订单。请支付其中之一，或等待它们过期。';

  @override
  String get checkoutUnknownPlan => '此套餐已停售。请返回并选择其他套餐。';

  @override
  String get checkoutFailed => '无法开始付款。请检查网络连接后重试。';

  @override
  String get redeemTitle => '输入代码';

  @override
  String get redeemSubtitle => '高级版密钥或礼品码';

  @override
  String get redeemHint => '代码';

  @override
  String get redeemApply => '使用';

  @override
  String get redeemCancel => '取消';

  @override
  String get redeemInvalid => '这看起来不像是代码。请检查后重试。';

  @override
  String get redeemUnknown => '无法识别此代码。请检查后重试。';

  @override
  String get redeemExpired => '此代码已过期。';

  @override
  String get redeemRevoked => '此代码已失效。';

  @override
  String get redeemMovedTooOften => '此密钥最近在手机之间转移得太频繁。请稍后再试。';

  @override
  String get redeemExhausted => '此代码已用完。';

  @override
  String get redeemAlreadyUsed => '此手机已使用过此代码。';

  @override
  String get redeemUnmetered => '此手机已拥有无限流量，不需要此代码。';

  @override
  String get redeemRateLimited => '尝试次数过多。请稍等片刻后重试。';

  @override
  String get redeemUnavailable => '此功能目前不可用。请稍后再试。';

  @override
  String get redeemNetwork => '无法连接到服务器。请检查网络连接后重试。';

  @override
  String get redeemFailed => '此代码无效。请检查后重试。';

  @override
  String get redeemMoved => '高级版已转移到此手机。';

  @override
  String redeemPromo(String amount) {
    return '代码已接受。已添加 $amount 额外流量。';
  }

  @override
  String get redeemPromoNoAmount => '代码已接受。已添加额外流量。';

  @override
  String get tvScanTitle => '在手机上打开';

  @override
  String get tvScanBody => '将手机摄像头对准此二维码。';

  @override
  String get refresh => '刷新';

  @override
  String get premiumNotNow => '暂不';

  @override
  String get premiumLimitSheetTitle => '今天的流量已用完';

  @override
  String get premiumLimitWait => '等待重置';

  @override
  String get premiumLimitInvite => '邀请好友获得更多流量';

  @override
  String get premiumNoDailyLimit => '高级版没有每日上限。';

  @override
  String get premiumCalmTitle => '想要取消每日上限吗？';

  @override
  String get premiumCalmBody => '高级版为您提供无限流量。您的免费套餐保持不变。';

  @override
  String get premiumNextStepTitle => '下一步是高级版';

  @override
  String get premiumNextStepBody => '您已拥有最多的免费流量。高级版没有每日上限。';

  @override
  String get premiumLockedTag => '高级版';

  @override
  String premiumLockedTitle(String place) {
    return '使用高级版解锁 $place';
  }

  @override
  String get premiumLockedBody => '此位置仅限高级版。您的免费服务器保持不变。';

  @override
  String get premiumHeadlineLimit => '没有每日上限';

  @override
  String premiumHeadlineLocked(String place) {
    return '使用高级版解锁 $place';
  }

  @override
  String get premiumFreeStays => '没有高级版，免费套餐也能继续使用。';

  @override
  String premiumEndsOn(String date) {
    return '高级版将于 $date 到期';
  }

  @override
  String get premiumRenewBody => '续订即可继续享用无限流量。续订会在您当前的到期日之后增加时间。';

  @override
  String premiumEndedOn(String date) {
    return '高级版已于 $date 到期。您已回到免费套餐。';
  }

  @override
  String get premiumRenew => '续订';

  @override
  String get noticeChannelName => 'Fortiva 消息';

  @override
  String get noticeChannelDescription => '来自 Fortiva 团队的新闻和消息';

  @override
  String get noticesSettingTitle => '通知';

  @override
  String get noticesSettingOn => '已开启。即使应用已关闭，也可以收到 Fortiva 团队的消息。';

  @override
  String get noticesSettingOff => '已关闭。开启后，即使应用已关闭，也能收到 Fortiva 团队的消息。';

  @override
  String get noticesOffCard => '开启通知，即使应用已关闭，也能收到 Fortiva 团队的消息。';

  @override
  String get noticesTurnOn => '开启';

  @override
  String get backgroundCard =>
      '应用关闭时，手机可能会拦下 Fortiva 团队的消息。请允许 Fortiva 在后台运行，以便收到消息。';

  @override
  String get backgroundHint =>
      '在下一个页面选择 Fortiva（如果没有列出，请显示全部应用）。然后将电池使用设为不受限制，或允许它自动启动并在后台运行。';

  @override
  String get backgroundAllow => '允许';

  @override
  String get backgroundNotNow => '以后再说';

  @override
  String get backgroundSettingTitle => '应用关闭时的消息';

  @override
  String get backgroundSettingSubtitle => '允许 Fortiva 在后台运行，应用关闭时也能收到消息。';

  @override
  String get backgroundCardData => '应用关闭时，手机的流量节省程序可能会拦下 Fortiva 团队的消息。';

  @override
  String get backgroundHintData => '在下一个页面开启不受限制的数据使用。';

  @override
  String get apnGuideTitle => '让这张 SIM 卡的连接更稳定';

  @override
  String get apnGuideBody => '您的手机在这张 SIM 卡上没有使用 IPv6。开启后，Fortiva 能更稳定地保持连接。';

  @override
  String get apnGuideShowMe => '查看方法';

  @override
  String get apnGuideNotNow => '暂不';

  @override
  String get apnGuideSheetTitle => '为这张 SIM 卡开启 IPv6';

  @override
  String apnGuideStepOpen(String button) {
    return '点击「$button」（或前往 设置 > 连接 > 移动网络 > 接入点名称）。';
  }

  @override
  String apnGuideStepAccessPoint(String apn) {
    return '点击正在使用的接入点（$apn）。';
  }

  @override
  String get apnGuideStepAccessPointAny => '点击正在使用的接入点。';

  @override
  String get apnGuideStepProtocol => '点击「APN 协议」，然后选择「IPv4/IPv6」。';

  @override
  String get apnGuideStepSave => '保存（三星手机：点击三点菜单，然后点击「保存」）。';

  @override
  String get apnGuideStepRestart => '关闭移动数据，然后重新开启。';

  @override
  String get apnGuideUndo => '如果移动数据无法使用，请把 APN 协议改回 IPv4。';

  @override
  String get apnGuideOpenSettings => '打开 APN 设置';

  @override
  String get homeStallSearching => '连接已停止工作。正在寻找其他路径。';

  @override
  String get homeStalled => '已连接，但没有数据通过';

  @override
  String get peerShareTitle => '帮好友连接';

  @override
  String get peerShareSubtitle => '把连接所需的内容传给好友的手机';

  @override
  String get peerShareBody => '如果好友的 Fortiva 无法连接，对方的手机可以从您的手机获取所需内容。无需网络也能完成。';

  @override
  String peerShareSteps(String action) {
    return '请在对方手机上打开 Fortiva 的设置，点击「$action」。然后把这些二维码逐个给对方看，或直接发送给对方。';
  }

  @override
  String get peerShareLoading => '正在获取最新内容';

  @override
  String get peerShareNothing => '这部手机暂时没有可传递的新内容。请稍后再试。';

  @override
  String peerShareCodeOf(int current, int total) {
    return '第 $current 个二维码，共 $total 个';
  }

  @override
  String get peerSharePrevious => '上一个';

  @override
  String get peerShareNext => '下一个';

  @override
  String get peerShareCopy => '复制';

  @override
  String get peerShareSend => '发送';

  @override
  String get peerShareCopied => '已复制。请粘贴到发给好友的消息里。';

  @override
  String get peerReceiveTitle => '向好友求助';

  @override
  String get peerReceiveSubtitle => '其他方式都连不上时';

  @override
  String peerReceiveBody(String action) {
    return '请让 Fortiva 能正常连接的好友打开应用内的设置，点击「$action」。然后用以下任一方式从对方手机获取。';
  }

  @override
  String get peerReceivePhotograph => '拍摄好友的二维码';

  @override
  String get peerReceivePhotographNext => '拍摄下一个二维码';

  @override
  String peerReceiveProgress(int have, int total) {
    return '已读取 $have 个二维码，共 $total 个';
  }

  @override
  String get peerReceiveFile => '打开好友发来的文件';

  @override
  String get peerReceivePaste => '粘贴好友发来的内容';

  @override
  String get peerReceiveNoCode => '照片中没有找到二维码。请把手机靠近些，让整个二维码都在画面内。';

  @override
  String get peerReceiveRefused => '本应用无法使用这个内容。请让好友重新发送。';

  @override
  String get peerReceiveNotNewer => '您已经有这个内容，或更新的内容。请重新尝试连接，或请其他好友帮忙。';

  @override
  String get peerReceiveTaken => '完成。点击按钮即可连接。';

  @override
  String get peerReceiveUnavailable => '此手机不支持该操作。请换个方式试试。';

  @override
  String get peerReceiveNothingToPaste => '还没有复制任何内容。请先复制好友发来的内容，再点击这里。';

  @override
  String get peerOfferBody => '还是无法连接？如果有好友的 Fortiva 能正常使用，对方可以用自己的手机帮您连接。';

  @override
  String get peerReceiveAgain => '您已经有这个二维码了。请让好友给您看下一个二维码。';

  @override
  String get peerReceivePasteNotOurs => '您复制的内容并非来自本应用。请复制好友发来的整条消息，然后再试。';

  @override
  String peerReceiveNoPhoto(String action) {
    return '相机应用没有返回照片。请先用相机应用拍照，然后点击「$action」。';
  }

  @override
  String get peerReceiveFileHint => '通过聊天软件收到的文件，可能需要先保存到「下载」文件夹。';

  @override
  String get homeTryingBackup => '其他方式都未能连接。正在尝试备用网络。';

  @override
  String get homeConnectedBackup => '已通过备用网络连接';

  @override
  String get backupNetwork => '备用网络';

  @override
  String get backupNetworkTitle => '备用网络';

  @override
  String get backupNetworkCaption => '在其他方式都无法连接时使用。可能比我们的服务器慢。';

  @override
  String get backupNetworkPlace => '位置自动选择';

  @override
  String get speedTestStart => '开始测试';

  @override
  String get speedTestAgain => '重新测试';

  @override
  String get speedTestRunning => '正在测试';

  @override
  String get speedTestIdle => '看看您现在的网速有多快。';

  @override
  String get speedTestPhasePing => '正在检查响应时间';

  @override
  String get speedTestPhaseDownload => '正在测量下载速度';

  @override
  String get speedTestPhaseUpload => '正在测量上传速度';

  @override
  String get speedTestDone => '测试完成';

  @override
  String get speedTestFailed => '测试未能完成。请检查网络后重试。';

  @override
  String get speedTestUnit => 'Mbps';

  @override
  String get ipAddressLabel => 'IP 地址';

  @override
  String get ipCopied => '地址已复制';

  @override
  String get ipLocation => '位置';

  @override
  String get ipProvider => '网络服务商';

  @override
  String get ipOrganization => '机构';

  @override
  String get ipTimeZone => '时区';

  @override
  String get ipCoordinates => '坐标';

  @override
  String get ipCheckFailed => '无法检查您的地址';

  @override
  String get historyAverage => '平均时长';

  @override
  String get historyRecentDays => '最近活动';

  @override
  String yesterdayAt(String time) {
    return '昨天 $time';
  }

  @override
  String dateAt(String date, String time) {
    return '$date $time';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds 秒';
  }

  @override
  String get stageOwn => 'Fortiva 服务器';

  @override
  String get stageCommunity => '社区服务器';

  @override
  String stageProgress(int n, int total) {
    return '第 $n 步，共 $total 步';
  }

  @override
  String get stageTryingOwn => '正在尝试 Fortiva 服务器';

  @override
  String get stageTryingCommunity => '正在尝试社区服务器';

  @override
  String get stageOwnFailedTryingCommunity => 'Fortiva 服务器在这里无法连接。正在尝试社区服务器。';

  @override
  String stageLastWorked(String server) {
    return '上次可用的服务器：$server';
  }

  @override
  String stageTriedBlocked(int count) {
    return '已尝试 $count 条路径，在这里被屏蔽';
  }

  @override
  String stageTriedFailed(int count) {
    return '已尝试 $count 条路径，均未连接';
  }

  @override
  String get stageNotConnected => '未连接';

  @override
  String get stageConnected => '在这里连接';

  @override
  String get stageSkipped => '这次跳过';

  @override
  String stageMoreToCheck(int count) {
    return '还有 $count 条路径待检查';
  }

  @override
  String stageNextTry(String stage, String time) {
    return '$time 后重试，从$stage开始';
  }

  @override
  String get searchSlowHint => '这可能需要一两分钟。点击按钮可停止搜索。';

  @override
  String get searchStopped => '已停止搜索';

  @override
  String get homeConnectedCommunity => '已通过社区服务器连接';

  @override
  String get stageGettingServers => '正在获取您的服务器';

  @override
  String stageNextTryStarting(String stage) {
    return '正在从$stage开始下一次尝试';
  }
}
