// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class SVi extends S {
  SVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Fortiva';

  @override
  String get statusDisconnected => 'Chưa kết nối';

  @override
  String get statusConnecting => 'Đang kết nối';

  @override
  String get statusConnected => 'Đã kết nối';

  @override
  String get statusDisconnecting => 'Đang ngắt kết nối...';

  @override
  String get statusError => 'Lỗi';

  @override
  String get statusVerifying => 'Đang kiểm tra...';

  @override
  String get disconnect => 'Ngắt kết nối';

  @override
  String get connectBtn => 'Kết nối';

  @override
  String get disconnectBtn => 'Ngắt kết nối';

  @override
  String get pleaseWait => 'VUI LÒNG CHỜ';

  @override
  String get locationLabel => 'Vị trí';

  @override
  String get selectServer => 'Chọn vị trí';

  @override
  String get serverLocation => 'Vị trí';

  @override
  String get searchServers => 'Tìm máy chủ';

  @override
  String get locationsTitle => 'Các vị trí';

  @override
  String get sortLatency => 'Sắp xếp: Độ trễ';

  @override
  String get sortAZ => 'Sắp xếp: A-Z';

  @override
  String get sortedByLatency => 'Đã sắp xếp theo độ trễ';

  @override
  String get sortedAZ => 'Đã sắp xếp A-Z';

  @override
  String get pingAll => 'Kiểm tra tất cả';

  @override
  String get pinging => 'Đang ping...';

  @override
  String get ping => 'Ping';

  @override
  String get stop => 'Dừng';

  @override
  String get fastestServer => 'Nhanh nhất';

  @override
  String get timeout => 'hết thời gian chờ';

  @override
  String get tabCommunity => 'Cộng đồng';

  @override
  String get tabFree => 'Miễn phí';

  @override
  String get tabPremium => 'Premium';

  @override
  String get noCommunityServers => 'Chưa có máy chủ cộng đồng';

  @override
  String get communityLoadFailed => 'Không tải được danh sách này';

  @override
  String get communityRetry => 'Thử lại';

  @override
  String get officialTabExplainer =>
      'Do Fortiva vận hành và duy trì hoạt động. Dùng chung cho mọi người dùng ứng dụng. Hãy bắt đầu từ đây.';

  @override
  String get communityTabExplainer =>
      'Các lựa chọn kết nối thêm. Tốc độ và tính sẵn sàng có thể thay đổi.';

  @override
  String get noFreeServers => 'Chưa có máy chủ miễn phí';

  @override
  String get noPremiumServers => 'Chưa có máy chủ Premium';

  @override
  String noResultsFor(String query) {
    return 'Không có kết quả cho \"$query\"';
  }

  @override
  String get proBadge => 'PREMIUM';

  @override
  String get freeBadge => 'MIỄN PHÍ';

  @override
  String get settings => 'Cài đặt';

  @override
  String get connection => 'Mạng';

  @override
  String get dnsConfiguration => 'DNS';

  @override
  String get customDns => 'Dùng máy chủ DNS của riêng bạn';

  @override
  String get about => 'Giới thiệu';

  @override
  String get privacyPolicy => 'Chính sách quyền riêng tư';

  @override
  String get contactUs => 'Liên hệ';

  @override
  String get rateOnGooglePlay => 'Đánh giá Fortiva trên Google Play';

  @override
  String get website => 'Trang web';

  @override
  String get copyright => '© 2026 NimusAI';

  @override
  String get version => 'Phiên bản';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get languageSubtitle => 'Ngôn ngữ giao diện';

  @override
  String get whatIsDns => 'DNS là gì?';

  @override
  String get dnsExplanation =>
      'DNS chuyển tên trang web thành địa chỉ mà điện thoại của bạn có thể truy cập. Dùng DNS khác có thể giúp trang web tải nhanh hơn và giúp truy cập những trang mà nhà mạng của bạn chặn.';

  @override
  String get configuration => 'Cài đặt';

  @override
  String get primaryDns => 'DNS chính';

  @override
  String get primaryDnsHint => 'Mặc định: 1.1.1.1';

  @override
  String get secondaryDns => 'DNS phụ (tùy chọn)';

  @override
  String get secondaryDnsHint => 'Mặc định: 8.8.8.8';

  @override
  String get saveConfiguration => 'Lưu';

  @override
  String get dnsSaved => 'Đã lưu cài đặt DNS';

  @override
  String get invalidPrimaryDns => 'Địa chỉ DNS chính không hợp lệ';

  @override
  String get invalidSecondaryDns => 'Địa chỉ DNS phụ không hợp lệ';

  @override
  String get statistics => 'Lịch sử';

  @override
  String get overview => 'TỔNG QUAN';

  @override
  String get connectionsLabel => 'Phiên kết nối';

  @override
  String get totalTime => 'Thời gian kết nối';

  @override
  String get dataUsage => 'Dữ liệu đã dùng';

  @override
  String get uploaded => 'Đã tải lên';

  @override
  String get downloaded => 'Đã tải xuống';

  @override
  String get total => 'Tổng cộng';

  @override
  String lastUpdated(String date) {
    return 'Cập nhật lần cuối: $date';
  }

  @override
  String today(String time) {
    return 'Hôm nay lúc $time';
  }

  @override
  String get yesterday => 'Hôm qua';

  @override
  String daysAgo(int count) {
    return '$count ngày trước';
  }

  @override
  String get noDataYet => 'Chưa có dữ liệu phiên';

  @override
  String get connectToStart => 'Kết nối để bắt đầu theo dõi';

  @override
  String get errorConnectionFailed => 'Không thể kết nối';

  @override
  String get errorServerNotWorking =>
      'Vị trí này không hoạt động. Hãy thử vị trí khác.';

  @override
  String get errorServerNotForwarding =>
      'Vị trí này không truyền được dữ liệu. Hãy thử vị trí khác.';

  @override
  String get errorUnexpected => 'Lỗi không mong muốn';

  @override
  String get errorDisconnectionFailed => 'Không thể ngắt kết nối';

  @override
  String get errorFailedToRegister => 'Không đăng ký được thiết bị';

  @override
  String get ipInformation => 'Kiểm tra IP của tôi';

  @override
  String get connectionAnalytics => 'Lịch sử';

  @override
  String get recentSessions => 'Kết nối gần đây';

  @override
  String get speedTest => 'Kiểm tra tốc độ';

  @override
  String get startTest => 'CHẠY CHẨN ĐOÁN';

  @override
  String get download => 'Tải xuống';

  @override
  String get upload => 'Tải lên';

  @override
  String get testingViaVpn => 'Đang kiểm tra qua đường hầm';

  @override
  String get testingDirect => 'Đang kiểm tra kết nối trực tiếp';

  @override
  String get splitTunneling => 'Cấu hình định tuyến';

  @override
  String get splitTunnelingDescription =>
      'Chọn những nhóm ứng dụng không đi qua đường hầm. Các ứng dụng được loại trừ sẽ dùng kết nối mạng trực tiếp của bạn.';

  @override
  String get enableSplitTunneling => 'Bật tách định tuyến';

  @override
  String get splitTunnelActive => 'Các ứng dụng đã chọn không đi qua đường hầm';

  @override
  String get splitTunnelInactive => 'Toàn bộ lưu lượng đi qua đường hầm';

  @override
  String get bypassVpnFor => 'Không dùng đường hầm cho';

  @override
  String get tools => 'Chẩn đoán';

  @override
  String get settingsGeneral => 'Chung';

  @override
  String get shareDiagnosticsTitle => 'Chia sẻ chẩn đoán kết nối';

  @override
  String get shareDiagnosticsBody =>
      'Gửi báo cáo kết nối, nhà mạng và quốc gia của bạn, mẫu điện thoại và phiên bản Android, tên các trang web bạn truy cập qua VPN kèm số lần mỗi ngày, và việc bạn đã xem hay nhấn vào tin nhắn, ưu đãi Premium và thẻ mời của chúng tôi. Chúng tôi không bao giờ thấy các trang bạn mở hay nội dung bạn gửi.';

  @override
  String get security => 'Tuân thủ';

  @override
  String get privacyDashboard => 'Phân tích điểm cuối';

  @override
  String get privacyDashboardSubtitle => 'Minh bạch IP và giám sát rò rỉ';

  @override
  String get connectionAnalyticsSubtitle => 'Lịch sử phiên và báo cáo';

  @override
  String get speedTestSubtitle => 'Đo thông lượng';

  @override
  String get splitTunnelingSubtitle => 'Cấu hình chính sách định tuyến';

  @override
  String get splashTagline => 'Truy cập riêng tư, dù bạn ở bất cứ đâu';

  @override
  String get openSourceLicence => 'Giấy phép mã nguồn mở';

  @override
  String get sourceOfferTitle => 'Giấy phép mã nguồn mở';

  @override
  String get sourceOfferBody =>
      'Fortiva VPN là phần mềm tự do theo GNU General Public License v3. Ứng dụng được xây dựng dựa trên Xray-core và các dự án mã nguồn mở khác.\n\nBạn có quyền nhận toàn bộ mã nguồn của phiên bản bạn đã cài. Để yêu cầu, hãy gửi email đến admin@fortivavpn.com kèm phiên bản ứng dụng của bạn. Đề nghị này có hiệu lực trong ba năm kể từ ngày bạn nhận được phiên bản này.';

  @override
  String get close => 'Đóng';

  @override
  String get account => 'Tài khoản';

  @override
  String get deleteAccount => 'Xóa tài khoản';

  @override
  String get deleteAccountSubtitle =>
      'Xóa vĩnh viễn thiết bị này và dữ liệu của bạn';

  @override
  String get deleteAccountConfirmTitle => 'Xóa tài khoản của bạn?';

  @override
  String get deleteAccountConfirmBody =>
      'Thao tác này sẽ xóa đăng ký thiết bị của bạn, tài khoản Google đã liên kết (nếu có), các máy chủ riêng được tạo cho bạn và tin nhắn của bạn trong trò chuyện hỗ trợ. Lịch sử kết nối trên điện thoại này cũng bị xóa.\n\nKhông thể hoàn tác. Bạn có thể bắt đầu lại bất cứ lúc nào bằng cách mở lại ứng dụng.';

  @override
  String deleteAccountConfirmRetention(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days ngày',
    );
    return 'Hồ sơ tài khoản của bạn được xóa ngay lập tức. Các bản sao trong bản sao lưu và nhật ký máy chủ ẩn danh được xóa trong vòng $_temp0.';
  }

  @override
  String get deleteAccountConfirmRetentionNoDays =>
      'Hồ sơ tài khoản của bạn được xóa ngay lập tức. Các bản sao trong bản sao lưu và nhật ký máy chủ ẩn danh được xóa sau đó, theo lịch trong chính sách quyền riêng tư của chúng tôi.';

  @override
  String get deleteAccountCancel => 'Giữ tài khoản của tôi';

  @override
  String get deleteAccountConfirm => 'Xóa';

  @override
  String get deleteAccountInProgress => 'Đang xóa tài khoản của bạn';

  @override
  String get deleteAccountDone => 'Tài khoản của bạn đã được xóa.';

  @override
  String get deleteAccountFailed =>
      'Không thể xóa tài khoản của bạn. Hãy kiểm tra kết nối và thử lại.';

  @override
  String get homeTapToConnect => 'Chạm để kết nối';

  @override
  String get homeChecking => 'Đang kiểm tra kết nối';

  @override
  String get homePreparing => 'Đang chuẩn bị máy chủ của bạn';

  @override
  String get homeDisconnecting => 'Đang ngắt kết nối';

  @override
  String get homeFindingPath => 'Đang tìm tuyến kết nối';

  @override
  String get diagCheckingInternet => 'Đang kiểm tra Internet của bạn';

  @override
  String get diagInternationalCut =>
      'Internet quốc tế đang bị cắt trên mạng này';

  @override
  String diagPathRow(String city, int n) {
    return '$city, tuyến $n';
  }

  @override
  String get diagOpen => 'mở';

  @override
  String get diagBlocked => 'bị chặn';

  @override
  String get diagSkipped => 'đã bỏ qua hôm nay';

  @override
  String diagConnectingThrough(String city) {
    return 'Đang kết nối qua $city';
  }

  @override
  String get diagVerifying => 'Đang kiểm tra lưu lượng';

  @override
  String get diagNoInternet => 'Điện thoại của bạn hiện không có Internet.';

  @override
  String get diagCutOff =>
      'Mạng của bạn hiện không truy cập được Internet quốc tế. Chạm để thử lại.';

  @override
  String get diagNothingOpen => 'Hiện mọi tuyến đều bị chặn. Chạm để thử lại.';

  @override
  String get homeTryingAgain =>
      'Hiện mọi tuyến đều bị chặn. Sẽ thử lại trong giây lát.';

  @override
  String get homeCutOffTryingAgain =>
      'Mạng của bạn hiện không truy cập được Internet quốc tế. Sẽ thử lại trong giây lát.';

  @override
  String get homeOfflineTryingAgain =>
      'Điện thoại của bạn hiện không có Internet. Sẽ thử lại trong giây lát.';

  @override
  String get diagPathFailed =>
      'Tuyến đã mở nhưng không tạo được đường hầm. Chạm để thử lại.';

  @override
  String get openVpnSettings => 'Mở cài đặt VPN';

  @override
  String get yourServer => 'MÁY CHỦ CỦA BẠN';

  @override
  String get yourServerCaption =>
      'Chỉ dành riêng cho bạn. Không ai khác kết nối qua máy chủ này.';

  @override
  String get ourServer => 'MÁY CHỦ CỦA CHÚNG TÔI';

  @override
  String get ourServerCaption =>
      'Do Fortiva vận hành và dùng chung cho mọi người. Được dùng cho đến khi máy chủ riêng của bạn sẵn sàng.';

  @override
  String get communityServer => 'MÁY CHỦ CỘNG ĐỒNG';

  @override
  String get communityServerCaption =>
      'Một lựa chọn kết nối thêm. Có thể ngừng hoạt động bất cứ lúc nào.';

  @override
  String communityServerNumber(String n) {
    return 'Máy chủ cộng đồng $n';
  }

  @override
  String get myServersTitle => 'Máy chủ của bạn';

  @override
  String get myServersExplainer =>
      'Mỗi thiết bị Fortiva được cấp máy chủ riêng tại từng vị trí, với thông tin đăng nhập chỉ thuộc về bản cài đặt này. Không cần tài khoản.';

  @override
  String get myServersInUse => 'Đang dùng';

  @override
  String get myServersEmpty => 'Chưa có máy chủ nào được cấp';

  @override
  String get myServersRetry => 'Thử lại';

  @override
  String get myServersBlockedTitle => 'Bạn đã dùng hết dữ liệu hôm nay';

  @override
  String get myServersBlockedWait =>
      'Hạn mức hằng ngày của bạn sẽ tự động được đặt lại. Hãy quay lại sau.';

  @override
  String myServersMoved(String place) {
    return 'Đang dùng $place';
  }

  @override
  String get copyLink => 'Sao chép liên kết';

  @override
  String get linkCopied => 'Đã sao chép liên kết';

  @override
  String quotaUsedToday(String used, String limit) {
    return 'Hôm nay đã dùng $used trên $limit';
  }

  @override
  String get quotaUsedUp => 'Đã dùng hết dữ liệu hằng ngày';

  @override
  String get quotaUnlimited => 'Dữ liệu không giới hạn';

  @override
  String get quotaDaily => 'Dữ liệu hằng ngày';

  @override
  String get quotaLimitReached => 'Đã đạt giới hạn hằng ngày';

  @override
  String quotaLeftOf(String left, String limit) {
    return 'Còn $left trên $limit';
  }

  @override
  String get quotaResetsShortly => 'Sắp được đặt lại';

  @override
  String quotaResetsInHours(int hours) {
    return 'Đặt lại sau $hours giờ';
  }

  @override
  String quotaResetsInMinutes(int minutes) {
    return 'Đặt lại sau $minutes phút';
  }

  @override
  String get myServersSubtitle => 'Các máy chủ được cấp cho thiết bị này';

  @override
  String get sharedServersTitle => 'Máy chủ dùng chung';

  @override
  String get sharedServersSubtitle =>
      'Vị trí công cộng, dùng làm phương án dự phòng';

  @override
  String get tabOfficial => 'Máy chủ của chúng tôi';

  @override
  String get noOfficialServers => 'Hiện không có máy chủ Fortiva';

  @override
  String get inviteTitle => 'Mời bạn bè';

  @override
  String get inviteSubtitle => 'Nhận thêm dữ liệu hằng ngày';

  @override
  String get inviteYourCode => 'Mã mời của bạn';

  @override
  String get inviteShareAction => 'Chia sẻ lời mời';

  @override
  String get inviteCopyAction => 'Sao chép mã';

  @override
  String get inviteCodeCopied => 'Đã sao chép mã';

  @override
  String inviteShareMessage(String code, String url) {
    return 'VPN miễn phí mà mình dùng rất ổn: Fortiva. Không cần đăng ký.\nCài từ liên kết này:\n$url\nMã mời của mình: $code';
  }

  @override
  String get inviteHowItWorks => 'Cách hoạt động';

  @override
  String inviteHowItWorksBody(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days ngày khác nhau',
    );
    return 'Chia sẻ mã của bạn. Khi ai đó cài ứng dụng, nhập mã và dùng VPN trong $_temp0, bạn được cộng $amount vào dữ liệu hằng ngày. Phần thưởng này được giữ lại trên tài khoản của bạn.';
  }

  @override
  String inviteHowItWorksBodyNoAmount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days ngày khác nhau',
    );
    return 'Chia sẻ mã của bạn. Khi ai đó cài ứng dụng, nhập mã và dùng VPN trong $_temp0, bạn được thêm dữ liệu mỗi ngày. Phần thưởng này được giữ lại trên tài khoản của bạn.';
  }

  @override
  String inviteHowItWorksBodyNoDays(String amount) {
    return 'Chia sẻ mã của bạn. Khi ai đó cài ứng dụng, nhập mã và dùng VPN đủ lâu, bạn được cộng $amount vào dữ liệu hằng ngày. Phần thưởng này được giữ lại trên tài khoản của bạn.';
  }

  @override
  String get inviteHowItWorksBodyNoAmountNoDays =>
      'Chia sẻ mã của bạn. Khi ai đó cài ứng dụng, nhập mã và dùng VPN đủ lâu, bạn được thêm dữ liệu mỗi ngày. Phần thưởng này được giữ lại trên tài khoản của bạn.';

  @override
  String inviteHowItWorksCap(String max) {
    return 'Bạn có thể nhận tối đa $max mỗi ngày từ lời mời.';
  }

  @override
  String get inviteStatInvited => 'Đã mời';

  @override
  String get inviteStatEarning => 'Đủ điều kiện';

  @override
  String get inviteStatBonus => 'Dữ liệu thưởng';

  @override
  String inviteBonusPerDay(String amount) {
    return '+$amount mỗi ngày';
  }

  @override
  String get inviteNoBonusYet => 'Chưa có thưởng';

  @override
  String invitePendingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lời mời chưa đủ điều kiện',
      one: '1 lời mời chưa đủ điều kiện',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String inviteJoinedWith(String code) {
    return 'Bạn đã tham gia với mã $code';
  }

  @override
  String get inviteLoadFailed => 'Không tải được mã mời của bạn';

  @override
  String get inviteRetry => 'Thử lại';

  @override
  String get inviteHaveCodeTitle => 'Bạn có mã mời?';

  @override
  String inviteHaveCodeSubtitle(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Nhập mã trong $hours giờ đầu tiên',
    );
    return '$_temp0';
  }

  @override
  String get inviteHaveCodeSubtitleNoHours => 'Nhập mã ngay sau khi cài';

  @override
  String get inviteEnterCodeHint => 'Mã mời';

  @override
  String get inviteApplyAction => 'Áp dụng';

  @override
  String get inviteNotNowAction => 'Để sau';

  @override
  String inviteClaimAccepted(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days ngày khác nhau',
    );
    return 'Đã chấp nhận lời mời. Bạn của bạn sẽ nhận dữ liệu thưởng sau khi bạn dùng VPN trong $_temp0.';
  }

  @override
  String get inviteClaimAcceptedNoDays =>
      'Đã chấp nhận lời mời. Bạn của bạn sẽ nhận dữ liệu thưởng sau khi bạn dùng VPN đủ lâu.';

  @override
  String get inviteClaimAlready => 'Thiết bị này đã dùng mã mời rồi';

  @override
  String get inviteClaimRejected =>
      'Mã đó không hoạt động. Hãy kiểm tra và thử lại';

  @override
  String get inviteClaimNetwork =>
      'Không kết nối được với máy chủ. Hãy thử lại';

  @override
  String get inviteCardTitle => 'Fortiva dùng có ổn không? Gửi cho bạn bè nhé';

  @override
  String get inviteCardBody =>
      'Gửi liên kết cài đặt cho bạn bè để họ cũng được kết nối miễn phí.';

  @override
  String inviteCardReward(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Khi bạn của bạn bắt đầu dùng Fortiva, bạn được nhận $days ngày Premium.',
    );
    return '$_temp0';
  }

  @override
  String get inviteCardRewardNoAmount =>
      'Khi bạn của bạn bắt đầu dùng Fortiva, bạn được tặng Premium.';

  @override
  String get inviteSendTelegram => 'Telegram';

  @override
  String get inviteSendWhatsApp => 'WhatsApp';

  @override
  String get inviteCopyLink => 'Sao chép liên kết';

  @override
  String get inviteOtherApps => 'Ứng dụng khác';

  @override
  String get inviteLinkCopied => 'Đã sao chép tin nhắn mời';

  @override
  String get invitePasteBody =>
      'Sao chép mã trong tin nhắn bạn bè gửi rồi dán vào đây.';

  @override
  String get invitePasteAction => 'Dán';

  @override
  String get inviteErrorTooLate =>
      'Đã hết thời gian nhập mã mời trên điện thoại này.';

  @override
  String get inviteErrorUnknown =>
      'Không tìm thấy mã này. Hãy sao chép lại từ tin nhắn bạn bè gửi.';

  @override
  String get inviteErrorOwnCode =>
      'Đây là mã của chính bạn. Hãy nhập mã của bạn bè.';

  @override
  String get inviteErrorMutual =>
      'Bạn và người bạn này không thể mời lẫn nhau.';

  @override
  String inviteHowItWorksPremium(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Mỗi người bạn bắt đầu dùng Fortiva còn mang lại cho bạn $days ngày Premium.',
    );
    return '$_temp0';
  }

  @override
  String inviteHowItWorksPremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Bạn có thể nhận tối đa $max ngày Premium từ lời mời.',
    );
    return '$_temp0';
  }

  @override
  String get premiumSourceInvite => 'Từ lời mời của bạn';

  @override
  String quotaBonusIncluded(String amount) {
    return 'gồm $amount thưởng từ lời mời';
  }

  @override
  String get updateTitle => 'Có bản cập nhật';

  @override
  String get updateRequiredTitle => 'Cần cập nhật';

  @override
  String updateBody(String version) {
    return 'Fortiva $version đã ra mắt. Hãy cập nhật để có các bản sửa lỗi mới nhất.';
  }

  @override
  String get updateRequiredBody =>
      'Phiên bản này không còn được hỗ trợ. Hãy cập nhật để tiếp tục dùng Fortiva.';

  @override
  String get updateNow => 'Cập nhật';

  @override
  String get updateLater => 'Để sau';

  @override
  String get updateFromPlay => 'Google Play';

  @override
  String get updateFromTelegram => 'Kênh Telegram';

  @override
  String get updateConnect => 'Kết nối';

  @override
  String get updateConnectHint =>
      'Nếu Google Play hoặc Telegram không mở được, hãy chạm Kết nối trước.';

  @override
  String get updateConnected => 'Bạn đã kết nối. Hãy tải bản cập nhật ngay.';

  @override
  String get updateReconnect => 'Không được? Kết nối lại';

  @override
  String get updateDisconnect => 'Ngắt kết nối';

  @override
  String get updateDisconnectHint =>
      'Chạm Ngắt kết nối để tải bản cập nhật qua Internet thông thường của bạn.';

  @override
  String get updateNotCarrying =>
      'Bạn đã kết nối nhưng không có dữ liệu nào đi qua. Hãy thử Kết nối lại, hoặc chạm Ngắt kết nối để dùng Internet thông thường.';

  @override
  String get diagVerdictNoInternet =>
      'Điện thoại của bạn không có kết nối Internet. Fortiva không thể kết nối cho đến khi có lại Internet.';

  @override
  String get diagVerdictCutOff =>
      'Mạng của bạn hiện không truy cập được Internet quốc tế. Hãy thử lại sau vài phút.';

  @override
  String get diagVerdictNeedsPermission =>
      'Fortiva không có quyền chạy VPN, hoặc một ứng dụng VPN khác đang được đặt luôn bật.';

  @override
  String get diagVerdictServerUnreachable =>
      'Không thể truy cập máy chủ này từ mạng của bạn. Máy chủ bị chặn ở đây hoặc đang ngừng hoạt động.';

  @override
  String get diagVerdictBlockedTls =>
      'Kết nối đến máy chủ này bị cắt ngay trong lúc đang thiết lập. Đó là dấu hiệu của việc lọc chặn.';

  @override
  String get diagVerdictThrottled =>
      'Máy chủ đã phản hồi mọi kiểm tra nhưng đường hầm vẫn không truyền được gì. Kết nối đang bị làm chậm.';

  @override
  String get diagCheckInternet => 'Kiểm tra Internet của bạn';

  @override
  String diagTryServer(String server) {
    return 'Tìm kiếm mới với $server';
  }

  @override
  String get diagTryAnotherServer => 'Thử máy chủ khác';

  @override
  String get diagDetails => 'Chi tiết';

  @override
  String get diagDetailsHide => 'Ẩn chi tiết';

  @override
  String privateDnsWarning(String host) {
    return 'DNS riêng tư đang bật ($host), nên một số trang web có thể không mở được. Hãy tắt DNS riêng tư trong cài đặt điện thoại của bạn.';
  }

  @override
  String get openNetworkSettings => 'Mở cài đặt mạng';

  @override
  String testPointStatus(String time, int open, int total) {
    return 'Điểm kiểm tra · kiểm tra lần cuối $time · $open trên $total cửa đang mở';
  }

  @override
  String get messagesTooltip => 'Tin nhắn';

  @override
  String get inboxTitle => 'Tin nhắn';

  @override
  String get inboxEmpty => 'Hiện không có tin nhắn nào.';

  @override
  String get messageClose => 'Đóng';

  @override
  String get supportTitle => 'Hỗ trợ';

  @override
  String get supportTooltip => 'Trò chuyện với bộ phận hỗ trợ';

  @override
  String get supportAskAction => 'Hỏi bộ phận hỗ trợ';

  @override
  String get supportContactSubtitle =>
      'Trò chuyện với chúng tôi trong ứng dụng';

  @override
  String get supportAutomaticNotice =>
      'Câu trả lời được viết tự động và có thể sai.';

  @override
  String get supportStaffNotice =>
      'Trả lời tự động hiện đang tắt. Tin nhắn của bạn sẽ được gửi đến đội ngũ của chúng tôi.';

  @override
  String get supportInputHint => 'Viết câu hỏi của bạn';

  @override
  String get supportInputHintTeam => 'Viết cho đội ngũ của chúng tôi';

  @override
  String get supportSend => 'Gửi';

  @override
  String supportQuotaLeft(int remaining, int limit) {
    return 'Hôm nay còn $remaining trên $limit câu hỏi';
  }

  @override
  String supportWaitIn(String time) {
    return 'Bạn có thể hỏi lại sau $time.';
  }

  @override
  String supportDurationHours(int hours, int minutes) {
    return '$hours giờ $minutes phút';
  }

  @override
  String supportDurationMinutes(int minutes) {
    return '$minutes phút';
  }

  @override
  String get supportNewConversation => 'Cuộc trò chuyện mới';

  @override
  String get supportSending => 'Đang gửi';

  @override
  String get supportNotSent => 'Chưa gửi được. Chạm để thử lại.';

  @override
  String get supportRateUp => 'Hữu ích';

  @override
  String get supportRateDown => 'Không hữu ích';

  @override
  String get supportRatedDown =>
      'Cảm ơn bạn. Đội ngũ của chúng tôi sẽ xem lại câu trả lời này.';

  @override
  String get supportTeamLabel => 'Đội ngũ Fortiva';

  @override
  String get supportUnavailable => 'Trò chuyện hiện không khả dụng.';

  @override
  String get supportOpenTelegram => 'Nhắn tin cho chúng tôi trên Telegram';

  @override
  String get supportGenericError => 'Đã xảy ra lỗi. Vui lòng thử lại.';

  @override
  String supportCodeTooLong(int max) {
    return 'Tin nhắn của bạn quá dài. Hãy giữ dưới $max ký tự.';
  }

  @override
  String get supportCodeEmpty => 'Tin nhắn của bạn đang trống.';

  @override
  String get supportCodeWaitReply =>
      'Vui lòng chờ câu trả lời cho câu hỏi trước của bạn.';

  @override
  String get supportCodeSlowDown =>
      'Bạn đang gửi tin nhắn quá nhanh. Vui lòng chờ một chút.';

  @override
  String get supportCodeQuotaDay => 'Bạn đã dùng hết số câu hỏi của hôm nay.';

  @override
  String get supportCodePaused => 'Trả lời tự động hiện đang tạm dừng.';

  @override
  String get supportCodeBusy =>
      'Trợ lý của chúng tôi đang bận. Vui lòng thử lại sau vài phút.';

  @override
  String get supportCodeGreeting =>
      'Xin chào! Mình có thể giúp gì cho bạn về Fortiva?';

  @override
  String get supportCodeGibberish =>
      'Xin lỗi, mình chưa hiểu. Vui lòng viết lại câu hỏi của bạn.';

  @override
  String get supportCodeRedacted =>
      'Chúng tôi đã xóa thông tin cá nhân và liên kết khỏi tin nhắn của bạn.';

  @override
  String get supportCodeRedactedEmpty =>
      'Tin nhắn của bạn chỉ có thông tin cá nhân hoặc liên kết nên chưa được gửi. Vui lòng mô tả vấn đề bằng lời.';

  @override
  String get supportCodeOffTopic =>
      'Mình chỉ có thể giúp các câu hỏi về cách dùng Fortiva.';

  @override
  String get supportCodeAbuse =>
      'Hãy giữ lịch sự nhé. Mình ở đây để giúp bạn dùng Fortiva.';

  @override
  String get supportCodeAiUnavailable =>
      'Trợ lý chưa trả lời được lần này. Vui lòng thử lại lát nữa.';

  @override
  String get supportCodeToStaff =>
      'Đã gửi đến đội ngũ của chúng tôi. Câu trả lời sẽ hiện ở đây.';

  @override
  String get supportCodeTicketOpened =>
      'Chúng tôi đã chuyển câu hỏi của bạn đến đội ngũ. Câu trả lời sẽ hiện ở đây.';

  @override
  String get supportCodeNotSent =>
      'Không gửi được tin nhắn này. Hãy viết lại nếu bạn vẫn cần hỗ trợ.';

  @override
  String get supportAssistantSubtitle => 'Trợ lý AI';

  @override
  String get supportThinkingReading => 'Đang đọc câu hỏi của bạn';

  @override
  String get supportThinkingSearching => 'Đang tìm câu trả lời';

  @override
  String get supportThinkingWriting => 'Đang viết câu trả lời';

  @override
  String get supportThinkingStill => 'Vẫn đang xử lý, cảm ơn bạn đã chờ';

  @override
  String get supportSuggestConnect => 'Tôi không kết nối được';

  @override
  String get supportSuggestData => 'Hôm nay tôi có bao nhiêu dữ liệu?';

  @override
  String get supportSuggestSlow => 'Kết nối của tôi bị chậm';

  @override
  String get supportWithTeam =>
      'Cuộc trò chuyện này hiện do đội ngũ của chúng tôi tiếp nhận.';

  @override
  String get supportTryAgainSoon => 'Thử lại sau vài phút.';

  @override
  String supportDurationWholeHours(int hours) {
    return '$hours giờ';
  }

  @override
  String get supportUnreadReply => 'Câu trả lời mới';

  @override
  String get premiumTitle => 'Premium';

  @override
  String get premiumTileSubtitle =>
      'Dữ liệu không giới hạn, không có giới hạn hằng ngày';

  @override
  String get premiumTileActive => 'Premium đang bật';

  @override
  String get premiumGetUnlimited => 'Dùng không giới hạn';

  @override
  String get premiumHeadline => 'Nhận dữ liệu không giới hạn';

  @override
  String get premiumPitch =>
      'Premium gỡ bỏ giới hạn hằng ngày, nên bạn có thể dùng bao nhiêu dữ liệu tùy thích cho đến khi Premium kết thúc.';

  @override
  String get premiumActiveTitle => 'Premium đang bật';

  @override
  String premiumActiveUntil(String date) {
    return 'Dữ liệu không giới hạn đến $date';
  }

  @override
  String get premiumActiveNoDate => 'Dữ liệu không giới hạn';

  @override
  String get premiumRenews => 'Tự động gia hạn qua Google Play';

  @override
  String get premiumSourceKey => 'Kích hoạt bằng khóa';

  @override
  String get premiumSourceCrypto => 'Thanh toán bằng tiền mã hóa';

  @override
  String get premiumSourceStars => 'Thanh toán bằng Sao Telegram';

  @override
  String get premiumSourceGooglePlay => 'Thanh toán qua Google Play';

  @override
  String get premiumSourceManual => 'Quà tặng từ đội ngũ Fortiva';

  @override
  String get premiumYourKey => 'Khóa của bạn';

  @override
  String get premiumKeyHint =>
      'Hãy giữ khóa này cẩn thận. Nhập khóa trên điện thoại khác để chuyển Premium sang đó.';

  @override
  String premiumKeyMoves(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tối đa $count lần',
      one: 'một lần',
    );
    String _temp1 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days ngày',
    );
    return 'Khóa có thể chuyển sang điện thoại khác $_temp0 trong $_temp1.';
  }

  @override
  String get premiumKeyMovesNoNumber =>
      'Khóa chỉ có thể chuyển sang điện thoại khác một số lần nhất định.';

  @override
  String get premiumCopy => 'Sao chép';

  @override
  String get premiumCopied => 'Đã sao chép';

  @override
  String get premiumChoosePlan => 'Chọn gói';

  @override
  String premiumPlanDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days ngày dữ liệu không giới hạn',
    );
    return '$_temp0';
  }

  @override
  String get premiumPlanNoDays => 'Dữ liệu không giới hạn';

  @override
  String get premiumBuy => 'Mua';

  @override
  String get premiumPlayUnavailable =>
      'Google Play hiện không khả dụng. Hãy thử lại sau.';

  @override
  String get premiumPlayPending =>
      'Thanh toán của bạn đang chờ xử lý trên Google Play. Premium sẽ bắt đầu ngay khi thanh toán hoàn tất.';

  @override
  String get premiumPlayConfirming => 'Đang xác nhận giao dịch mua của bạn...';

  @override
  String get premiumPlayRetrying =>
      'Thanh toán của bạn đã thành công nhưng chúng tôi chưa xác nhận được. Chúng tôi sẽ tiếp tục thử, bạn không cần thanh toán lại.';

  @override
  String get premiumPlayRefused =>
      'Chúng tôi không xác nhận được giao dịch mua này. Nếu bạn đã bị trừ tiền, hãy liên hệ bộ phận hỗ trợ.';

  @override
  String get premiumPlayNotAvailable =>
      'Premium hiện không khả dụng trên điện thoại này. Nếu bạn đã bị trừ tiền, hãy liên hệ bộ phận hỗ trợ.';

  @override
  String get premiumNotAvailable =>
      'Premium hiện không khả dụng trên điện thoại này.';

  @override
  String get premiumPlayFailed =>
      'Giao dịch mua không thành công. Hãy thử lại.';

  @override
  String get premiumNowOn =>
      'Premium đã bật. Hãy tận hưởng dữ liệu không giới hạn.';

  @override
  String get premiumRestore => 'Khôi phục giao dịch mua';

  @override
  String get premiumRestoreDone =>
      'Giao dịch mua của bạn đã được khôi phục trên điện thoại này.';

  @override
  String get premiumRestoreNone =>
      'Tài khoản Google này không có giao dịch mua nào để khôi phục.';

  @override
  String get premiumRestoreFailed =>
      'Không thể khôi phục giao dịch mua của bạn. Hãy thử lại sau.';

  @override
  String premiumRenewsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Thanh toán mỗi $count ngày. Tự động gia hạn cho đến khi bạn hủy.',
      one: 'Thanh toán mỗi ngày. Tự động gia hạn cho đến khi bạn hủy.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Thanh toán mỗi $count tuần. Tự động gia hạn cho đến khi bạn hủy.',
      one: 'Thanh toán mỗi tuần. Tự động gia hạn cho đến khi bạn hủy.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Thanh toán mỗi $count tháng. Tự động gia hạn cho đến khi bạn hủy.',
      one: 'Thanh toán mỗi tháng. Tự động gia hạn cho đến khi bạn hủy.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Thanh toán mỗi $count năm. Tự động gia hạn cho đến khi bạn hủy.',
      one: 'Thanh toán mỗi năm. Tự động gia hạn cho đến khi bạn hủy.',
    );
    return '$_temp0';
  }

  @override
  String get premiumRenewsNoPeriod => 'Tự động gia hạn cho đến khi bạn hủy.';

  @override
  String get premiumPlayCancelNote =>
      'Bạn có thể hủy bất cứ lúc nào trên Google Play. Premium vẫn bật cho đến hết thời gian bạn đã thanh toán.';

  @override
  String get premiumManageSubscription => 'Quản lý hoặc hủy đăng ký';

  @override
  String get premiumCurrentPlan => 'Gói hiện tại';

  @override
  String get premiumPlaySubscribed =>
      'Bạn đã có gói đăng ký trên Google Play. Hãy quản lý hoặc hủy gói đó trên Google Play.';

  @override
  String get premiumEnterCode => 'Nhập mã';

  @override
  String get premiumNeedsPlayVersion =>
      'Để mua qua Google Play, bạn cần bản Fortiva từ Google Play.';

  @override
  String get premiumOff => 'Premium hiện không mở bán.';

  @override
  String get premiumLoadFailed =>
      'Không tải được Premium. Hãy kiểm tra kết nối và thử lại.';

  @override
  String get premiumRetry => 'Thử lại';

  @override
  String premiumPriceUsdt(String price) {
    return '$price USDT';
  }

  @override
  String premiumPriceStars(String stars) {
    return '$stars Sao Telegram';
  }

  @override
  String get premiumPayCrypto => 'Thanh toán bằng tiền mã hóa';

  @override
  String get premiumTelegramTitle => 'Thanh toán trên Telegram';

  @override
  String get premiumTelegramBody =>
      'Thanh toán bằng Sao Telegram trong bot của chúng tôi. Bạn sẽ nhận được khóa, và Premium bắt đầu ngay trên điện thoại này.';

  @override
  String get premiumTelegramButton => 'Mua trên Telegram';

  @override
  String get premiumTelegramFailed => 'Không mở được Telegram. Hãy thử lại.';

  @override
  String get checkoutTitle => 'Thanh toán bằng tiền mã hóa';

  @override
  String get checkoutChooseNetwork => 'Chọn mạng bạn sẽ dùng để gửi';

  @override
  String get checkoutContinue => 'Tiếp tục';

  @override
  String get checkoutSendExactly => 'Gửi chính xác';

  @override
  String get checkoutNetwork => 'Mạng';

  @override
  String get checkoutAddress => 'Đến địa chỉ này';

  @override
  String get checkoutMemo => 'Kèm memo này';

  @override
  String get checkoutMemoWarning =>
      'Hãy ghi memo này vào giao dịch chuyển, nếu không chúng tôi không thể khớp thanh toán với bạn.';

  @override
  String get checkoutExactWarning =>
      'Hãy gửi đúng số tiền, chỉ trên mạng này. Số tiền hoặc mạng khác có thể không đến được chúng tôi.';

  @override
  String checkoutTimeLeft(String time) {
    return 'Thời gian còn lại: $time';
  }

  @override
  String get checkoutWaiting =>
      'Đang chờ thanh toán của bạn. Trang này tự cập nhật.';

  @override
  String get checkoutPaidTitle => 'Đã nhận thanh toán';

  @override
  String get checkoutPaidKeyOnly =>
      'Khóa của bạn đã sẵn sàng. Nhập khóa trên điện thoại cần nhận Premium.';

  @override
  String get checkoutDone => 'Xong';

  @override
  String get checkoutExpired =>
      'Đơn hàng này đã hết hạn. Nếu bạn đã thanh toán, hãy liên hệ bộ phận hỗ trợ.';

  @override
  String get checkoutUnderpaid =>
      'Chúng tôi nhận được ít hơn số tiền đầy đủ. Hãy liên hệ bộ phận hỗ trợ và cung cấp mã đơn hàng này:';

  @override
  String get checkoutCanceled => 'Đơn hàng này đã bị hủy.';

  @override
  String get checkoutStartAgain => 'Bắt đầu lại';

  @override
  String get checkoutUnavailable =>
      'Thanh toán bằng tiền mã hóa hiện không khả dụng.';

  @override
  String get checkoutTooManyOpen =>
      'Bạn có quá nhiều đơn hàng chưa thanh toán. Hãy thanh toán một đơn hoặc chờ chúng hết hạn.';

  @override
  String get checkoutUnknownPlan =>
      'Gói này không còn mở bán. Hãy quay lại và chọn gói khác.';

  @override
  String get checkoutFailed =>
      'Không thể bắt đầu thanh toán. Hãy kiểm tra kết nối và thử lại.';

  @override
  String get redeemTitle => 'Nhập mã';

  @override
  String get redeemSubtitle => 'Khóa Premium hoặc mã quà tặng';

  @override
  String get redeemHint => 'Mã';

  @override
  String get redeemApply => 'Áp dụng';

  @override
  String get redeemCancel => 'Hủy';

  @override
  String get redeemInvalid =>
      'Đây có vẻ không phải là mã. Hãy kiểm tra và thử lại.';

  @override
  String get redeemUnknown =>
      'Chúng tôi không nhận ra mã này. Hãy kiểm tra và thử lại.';

  @override
  String get redeemExpired => 'Mã này đã hết hạn.';

  @override
  String get redeemRevoked => 'Mã này không còn hiệu lực.';

  @override
  String get redeemMovedTooOften =>
      'Khóa này gần đây đã chuyển giữa các điện thoại quá nhiều lần. Hãy thử lại sau.';

  @override
  String get redeemExhausted => 'Mã này đã được dùng hết.';

  @override
  String get redeemAlreadyUsed => 'Điện thoại này đã dùng mã này rồi.';

  @override
  String get redeemUnmetered =>
      'Điện thoại này đã có dữ liệu không giới hạn nên không cần mã này.';

  @override
  String get redeemRateLimited =>
      'Thử quá nhiều lần. Hãy chờ một chút rồi thử lại.';

  @override
  String get redeemUnavailable =>
      'Tính năng này hiện không khả dụng. Hãy thử lại sau.';

  @override
  String get redeemNetwork =>
      'Không kết nối được với máy chủ. Hãy kiểm tra kết nối và thử lại.';

  @override
  String get redeemFailed => 'Mã đó không hoạt động. Hãy kiểm tra và thử lại.';

  @override
  String get redeemMoved => 'Premium đã chuyển sang điện thoại này.';

  @override
  String redeemPromo(String amount) {
    return 'Đã chấp nhận mã. Đã thêm $amount dữ liệu bổ sung.';
  }

  @override
  String get redeemPromoNoAmount => 'Đã chấp nhận mã. Đã thêm dữ liệu bổ sung.';

  @override
  String get tvScanTitle => 'Mở trên điện thoại của bạn';

  @override
  String get tvScanBody => 'Hướng camera điện thoại của bạn vào mã này.';

  @override
  String get refresh => 'Làm mới';

  @override
  String get premiumNotNow => 'Để sau';

  @override
  String get premiumLimitSheetTitle => 'Dữ liệu hôm nay đã dùng hết';

  @override
  String get premiumLimitWait => 'Chờ dữ liệu được đặt lại';

  @override
  String get premiumLimitInvite => 'Mời bạn bè để có thêm dữ liệu';

  @override
  String get premiumNoDailyLimit => 'Premium không có giới hạn hằng ngày.';

  @override
  String get premiumCalmTitle => 'Muốn không còn giới hạn hằng ngày?';

  @override
  String get premiumCalmBody =>
      'Premium cho bạn dữ liệu không giới hạn. Gói miễn phí của bạn vẫn giữ nguyên.';

  @override
  String get premiumNextStepTitle => 'Bước tiếp theo là Premium';

  @override
  String get premiumNextStepBody =>
      'Bạn đã có mức dữ liệu miễn phí cao nhất. Premium không có giới hạn hằng ngày.';

  @override
  String get premiumLockedTag => 'Premium';

  @override
  String premiumLockedTitle(String place) {
    return 'Mở khóa $place với Premium';
  }

  @override
  String get premiumLockedBody =>
      'Vị trí này dành cho Premium. Các máy chủ miễn phí của bạn vẫn giữ nguyên.';

  @override
  String get premiumHeadlineLimit => 'Không giới hạn hằng ngày';

  @override
  String premiumHeadlineLocked(String place) {
    return 'Mở khóa $place với Premium';
  }

  @override
  String get premiumFreeStays =>
      'Gói miễn phí vẫn hoạt động mà không cần Premium.';

  @override
  String premiumEndsOn(String date) {
    return 'Premium kết thúc vào $date';
  }

  @override
  String get premiumRenewBody =>
      'Gia hạn để giữ dữ liệu không giới hạn. Gia hạn sẽ cộng thêm thời gian vào ngày kết thúc hiện tại của bạn.';

  @override
  String premiumEndedOn(String date) {
    return 'Premium đã kết thúc vào $date. Gói miễn phí của bạn đã trở lại.';
  }

  @override
  String get premiumRenew => 'Gia hạn';

  @override
  String get noticeChannelName => 'Tin nhắn từ Fortiva';

  @override
  String get noticeChannelDescription =>
      'Tin tức và tin nhắn từ đội ngũ Fortiva';

  @override
  String get noticesSettingTitle => 'Thông báo';

  @override
  String get noticesSettingOn =>
      'Đang bật. Tin nhắn từ đội ngũ Fortiva có thể đến ngay cả khi ứng dụng đã đóng.';

  @override
  String get noticesSettingOff =>
      'Đang tắt. Hãy bật để nhận tin nhắn từ đội ngũ Fortiva ngay cả khi ứng dụng đã đóng.';

  @override
  String get noticesOffCard =>
      'Bật thông báo để nhận tin nhắn từ đội ngũ Fortiva ngay cả khi ứng dụng đã đóng.';

  @override
  String get noticesTurnOn => 'Bật';

  @override
  String get backgroundCard =>
      'Điện thoại có thể giữ lại tin nhắn từ đội ngũ Fortiva khi ứng dụng đã đóng. Hãy cho phép Fortiva chạy nền để tin nhắn đến được với bạn.';

  @override
  String get backgroundHint =>
      'Ở màn hình tiếp theo, chọn Fortiva (nếu không thấy, hãy hiện tất cả ứng dụng). Sau đó đặt mức dùng pin thành Không hạn chế, hoặc cho phép ứng dụng tự khởi động và chạy nền.';

  @override
  String get backgroundAllow => 'Cho phép';

  @override
  String get backgroundNotNow => 'Để sau';

  @override
  String get backgroundSettingTitle => 'Tin nhắn khi ứng dụng đã đóng';

  @override
  String get backgroundSettingSubtitle =>
      'Cho phép Fortiva chạy nền để tin nhắn vẫn đến khi ứng dụng đã đóng.';

  @override
  String get backgroundCardData =>
      'Trình tiết kiệm dữ liệu trên điện thoại có thể chặn tin nhắn từ đội ngũ Fortiva khi ứng dụng đã đóng.';

  @override
  String get backgroundHintData =>
      'Ở màn hình tiếp theo, bật Dữ liệu không hạn chế.';

  @override
  String get apnGuideTitle => 'Kết nối ổn định hơn trên SIM này';

  @override
  String get apnGuideBody =>
      'Điện thoại của bạn không dùng IPv6 trên SIM này. Bật lên sẽ giúp Fortiva giữ kết nối tốt hơn.';

  @override
  String get apnGuideShowMe => 'Chỉ cho tôi cách làm';

  @override
  String get apnGuideNotNow => 'Để sau';

  @override
  String get apnGuideSheetTitle => 'Bật IPv6 cho SIM này';

  @override
  String apnGuideStepOpen(String button) {
    return 'Nhấn \"$button\" (hoặc vào Cài đặt > Kết nối > Mạng di động > Tên điểm truy cập).';
  }

  @override
  String apnGuideStepAccessPoint(String apn) {
    return 'Nhấn vào điểm truy cập đang dùng ($apn).';
  }

  @override
  String get apnGuideStepAccessPointAny => 'Nhấn vào điểm truy cập đang dùng.';

  @override
  String get apnGuideStepProtocol =>
      'Nhấn \"Giao thức APN\" và chọn \"IPv4/IPv6\".';

  @override
  String get apnGuideStepSave =>
      'Lưu lại (trên Samsung: menu ba chấm, rồi \"Lưu\").';

  @override
  String get apnGuideStepRestart => 'Tắt dữ liệu di động rồi bật lại.';

  @override
  String get apnGuideUndo =>
      'Nếu dữ liệu di động ngừng hoạt động, hãy đặt lại giao thức APN về IPv4.';

  @override
  String get apnGuideOpenSettings => 'Mở cài đặt APN';

  @override
  String get homeStallSearching =>
      'Kết nối đã ngừng hoạt động. Đang tìm tuyến kết nối khác.';

  @override
  String get homeStalled => 'Đã kết nối, nhưng không có dữ liệu đi qua';

  @override
  String get peerShareTitle => 'Giúp bạn bè kết nối';

  @override
  String get peerShareSubtitle =>
      'Chuyển những gì Fortiva cần sang điện thoại của bạn bè';

  @override
  String get peerShareBody =>
      'Nếu Fortiva của bạn bè không kết nối được, điện thoại của họ có thể lấy những gì cần thiết từ điện thoại của bạn. Cách này dùng được cả khi không có Internet.';

  @override
  String peerShareSteps(String action) {
    return 'Trên điện thoại của họ, hãy mở Cài đặt trong Fortiva và chạm \"$action\". Sau đó cho họ xem lần lượt từng mã này, hoặc gửi cho họ.';
  }

  @override
  String get peerShareLoading => 'Đang lấy bản mới nhất';

  @override
  String get peerShareNothing =>
      'Điện thoại này chưa có gì mới để chuyển. Hãy thử lại sau.';

  @override
  String peerShareCodeOf(int current, int total) {
    return 'Mã $current trên $total';
  }

  @override
  String get peerSharePrevious => 'Quay lại';

  @override
  String get peerShareNext => 'Tiếp theo';

  @override
  String get peerShareCopy => 'Sao chép';

  @override
  String get peerShareSend => 'Gửi';

  @override
  String get peerShareCopied => 'Đã sao chép. Hãy dán vào tin nhắn gửi bạn bè.';

  @override
  String get peerReceiveTitle => 'Nhờ bạn bè giúp';

  @override
  String get peerReceiveSubtitle => 'Khi không còn cách nào kết nối được';

  @override
  String peerReceiveBody(String action) {
    return 'Nếu bạn bè có Fortiva kết nối được, hãy nhờ họ mở Cài đặt trong Fortiva và chạm \"$action\". Sau đó lấy từ điện thoại của họ bằng một trong các cách dưới đây.';
  }

  @override
  String get peerReceivePhotograph => 'Chụp ảnh mã của bạn bè';

  @override
  String get peerReceivePhotographNext => 'Chụp ảnh mã tiếp theo';

  @override
  String peerReceiveProgress(int have, int total) {
    return 'Đã đọc $have trên $total mã';
  }

  @override
  String get peerReceiveFile => 'Mở tệp bạn bè đã gửi';

  @override
  String get peerReceivePaste => 'Dán nội dung bạn bè đã gửi';

  @override
  String get peerReceiveNoCode =>
      'Không tìm thấy mã trong ảnh đó. Hãy đưa điện thoại lại gần hơn và giữ toàn bộ mã trong khung hình.';

  @override
  String get peerReceiveRefused =>
      'Fortiva không dùng được nội dung này. Hãy nhờ bạn bè gửi lại.';

  @override
  String get peerReceiveNotNewer =>
      'Bạn đã có nội dung này, hoặc bản mới hơn. Hãy thử kết nối lại, hoặc nhờ bạn bè khác giúp.';

  @override
  String get peerReceiveTaken => 'Xong. Chạm vào nút để kết nối.';

  @override
  String get peerReceiveUnavailable =>
      'Điện thoại này không làm được việc đó. Hãy thử cách khác.';

  @override
  String get peerReceiveNothingToPaste =>
      'Chưa sao chép gì. Hãy sao chép nội dung bạn bè đã gửi, rồi chạm lại vào đây.';

  @override
  String get peerOfferBody =>
      'Vẫn chưa kết nối được? Bạn bè có Fortiva hoạt động bình thường có thể giúp bạn từ điện thoại của họ.';

  @override
  String get peerReceiveAgain =>
      'Bạn đã có mã này rồi. Hãy nhờ bạn bè cho xem mã tiếp theo.';

  @override
  String get peerReceivePasteNotOurs =>
      'Nội dung bạn sao chép không phải từ Fortiva. Hãy sao chép toàn bộ tin nhắn của bạn bè, rồi thử lại.';

  @override
  String peerReceiveNoPhoto(String action) {
    return 'Máy ảnh không trả lại ảnh. Hãy chụp ảnh bằng ứng dụng máy ảnh, rồi chạm \"$action\".';
  }

  @override
  String get peerReceiveFileHint =>
      'Tệp từ ứng dụng nhắn tin có thể cần được lưu vào thư mục Tải xuống trước.';

  @override
  String get homeTryingBackup =>
      'Không có kết nối nào khác thành công. Đang thử một mạng dự phòng.';

  @override
  String get homeConnectedBackup => 'Đã kết nối qua mạng dự phòng';

  @override
  String get backupNetwork => 'MẠNG DỰ PHÒNG';

  @override
  String get backupNetworkTitle => 'Mạng dự phòng';

  @override
  String get backupNetworkCaption =>
      'Được dùng khi không có gì khác kết nối được. Có thể chậm hơn máy chủ của chúng tôi.';

  @override
  String get backupNetworkPlace => 'Vị trí được chọn tự động';

  @override
  String get speedTestStart => 'Bắt đầu kiểm tra';

  @override
  String get speedTestAgain => 'Kiểm tra lại';

  @override
  String get speedTestRunning => 'Đang kiểm tra';

  @override
  String get speedTestIdle => 'Xem kết nối của bạn nhanh đến đâu ngay lúc này.';

  @override
  String get speedTestPhasePing => 'Đang kiểm tra thời gian phản hồi';

  @override
  String get speedTestPhaseDownload => 'Đang đo tốc độ tải xuống';

  @override
  String get speedTestPhaseUpload => 'Đang đo tốc độ tải lên';

  @override
  String get speedTestDone => 'Đã kiểm tra xong';

  @override
  String get speedTestFailed =>
      'Không thể hoàn tất kiểm tra. Hãy kiểm tra internet và thử lại.';

  @override
  String get speedTestUnit => 'Mbps';

  @override
  String get ipAddressLabel => 'Địa chỉ IP';

  @override
  String get ipCopied => 'Đã sao chép địa chỉ';

  @override
  String get ipLocation => 'Vị trí';

  @override
  String get ipProvider => 'Nhà cung cấp internet';

  @override
  String get ipOrganization => 'Tổ chức';

  @override
  String get ipTimeZone => 'Múi giờ';

  @override
  String get ipCoordinates => 'Tọa độ';

  @override
  String get ipCheckFailed => 'Không kiểm tra được địa chỉ của bạn';

  @override
  String get historyAverage => 'Trung bình';

  @override
  String get historyRecentDays => 'Những ngày gần đây';

  @override
  String yesterdayAt(String time) {
    return 'Hôm qua lúc $time';
  }

  @override
  String dateAt(String date, String time) {
    return '$date lúc $time';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds giây';
  }

  @override
  String get stageOwn => 'Máy chủ Fortiva';

  @override
  String get stageCommunity => 'Máy chủ cộng đồng';

  @override
  String stageProgress(int n, int total) {
    return 'Giai đoạn $n trên $total';
  }

  @override
  String get stageTryingOwn => 'Đang thử máy chủ Fortiva';

  @override
  String get stageTryingCommunity => 'Đang thử máy chủ cộng đồng';

  @override
  String get stageOwnFailedTryingCommunity =>
      'Máy chủ Fortiva không kết nối được ở đây. Đang thử máy chủ cộng đồng.';

  @override
  String stageLastWorked(String server) {
    return 'Máy chủ hoạt động gần nhất: $server';
  }

  @override
  String stageTriedBlocked(int count) {
    return 'Đã thử $count tuyến, bị chặn ở đây';
  }

  @override
  String stageTriedFailed(int count) {
    return 'Đã thử $count tuyến, không tuyến nào kết nối';
  }

  @override
  String get stageNotConnected => 'Không kết nối được';

  @override
  String get stageConnected => 'Đã kết nối ở đây';

  @override
  String get stageSkipped => 'Lần này bỏ qua';

  @override
  String stageMoreToCheck(int count) {
    return 'Còn $count tuyến cần kiểm tra';
  }

  @override
  String stageNextTry(String stage, String time) {
    return 'Lần thử tiếp theo sau $time, bắt đầu với $stage';
  }

  @override
  String get searchSlowHint =>
      'Việc này có thể mất một hai phút. Chạm vào nút để dừng tìm kiếm.';

  @override
  String get searchStopped => 'Đã dừng tìm kiếm';

  @override
  String get homeConnectedCommunity => 'Đã kết nối qua máy chủ cộng đồng';

  @override
  String get stageGettingServers => 'Đang lấy máy chủ của bạn';

  @override
  String stageNextTryStarting(String stage) {
    return 'Lần thử tiếp theo đang bắt đầu với $stage';
  }
}
