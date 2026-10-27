// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fortiva';

  @override
  String get statusDisconnected => 'Not connected';

  @override
  String get statusConnecting => 'Connecting';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusDisconnecting => 'Terminating...';

  @override
  String get statusError => 'Error';

  @override
  String get statusVerifying => 'Verifying...';

  @override
  String get disconnect => 'Terminate';

  @override
  String get connectBtn => 'Connect';

  @override
  String get disconnectBtn => 'Disconnect';

  @override
  String get pleaseWait => 'PLEASE WAIT';

  @override
  String get locationLabel => 'Location';

  @override
  String get selectServer => 'Choose a location';

  @override
  String get serverLocation => 'Location';

  @override
  String get searchServers => 'Search servers';

  @override
  String get locationsTitle => 'Locations';

  @override
  String get sortLatency => 'Sort: Latency';

  @override
  String get sortAZ => 'Sort: A-Z';

  @override
  String get sortedByLatency => 'Sorted by latency';

  @override
  String get sortedAZ => 'Sorted A–Z';

  @override
  String get pingAll => 'Test all';

  @override
  String get pinging => 'Pinging...';

  @override
  String get ping => 'Ping';

  @override
  String get stop => 'Stop';

  @override
  String get fastestServer => 'Fastest';

  @override
  String get timeout => 'timeout';

  @override
  String get tabCommunity => 'Community';

  @override
  String get tabFree => 'Free';

  @override
  String get tabPremium => 'Premium';

  @override
  String get noCommunityServers => 'No community servers yet';

  @override
  String get communityLoadFailed => 'Could not load this list';

  @override
  String get communityRetry => 'Try again';

  @override
  String get officialTabExplainer =>
      'Run by Fortiva and kept online by us. Shared by everyone who uses the app. Start here.';

  @override
  String get communityTabExplainer =>
      'Extra connection options. Speed and availability vary.';

  @override
  String get noFreeServers => 'No free servers yet';

  @override
  String get noPremiumServers => 'No premium servers yet';

  @override
  String noResultsFor(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get proBadge => 'PREMIUM';

  @override
  String get freeBadge => 'FREE';

  @override
  String get settings => 'Settings';

  @override
  String get connection => 'Network';

  @override
  String get dnsConfiguration => 'DNS';

  @override
  String get customDns => 'Use your own DNS servers';

  @override
  String get about => 'About';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get contactUs => 'Contact Us';

  @override
  String get rateOnGooglePlay => 'Rate Fortiva on Google Play';

  @override
  String get website => 'Website';

  @override
  String get copyright => '© 2026 NimusAI';

  @override
  String get version => 'Version';

  @override
  String get language => 'Language';

  @override
  String get languageSubtitle => 'Interface language';

  @override
  String get whatIsDns => 'What is DNS?';

  @override
  String get dnsExplanation =>
      'DNS turns website names into addresses your phone can reach. Using a different DNS can make sites load faster and can help reach sites your provider blocks.';

  @override
  String get configuration => 'Settings';

  @override
  String get primaryDns => 'Primary DNS';

  @override
  String get primaryDnsHint => 'Default: 1.1.1.1';

  @override
  String get secondaryDns => 'Secondary DNS (optional)';

  @override
  String get secondaryDnsHint => 'Default: 8.8.8.8';

  @override
  String get saveConfiguration => 'Save';

  @override
  String get dnsSaved => 'DNS settings saved';

  @override
  String get invalidPrimaryDns => 'That primary DNS address is not valid';

  @override
  String get invalidSecondaryDns => 'That secondary DNS address is not valid';

  @override
  String get statistics => 'History';

  @override
  String get overview => 'OVERVIEW';

  @override
  String get connectionsLabel => 'Sessions';

  @override
  String get totalTime => 'Time connected';

  @override
  String get dataUsage => 'Data used';

  @override
  String get uploaded => 'Uploaded';

  @override
  String get downloaded => 'Downloaded';

  @override
  String get total => 'Total';

  @override
  String lastUpdated(String date) {
    return 'Last updated: $date';
  }

  @override
  String today(String time) {
    return 'Today at $time';
  }

  @override
  String get yesterday => 'Yesterday';

  @override
  String daysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get noDataYet => 'No session data';

  @override
  String get connectToStart => 'Connect to start tracking';

  @override
  String get errorConnectionFailed => 'Could not connect';

  @override
  String get errorServerNotWorking =>
      'This location is not working. Try another one.';

  @override
  String get errorServerNotForwarding =>
      'This location is not passing traffic. Try another one.';

  @override
  String get errorUnexpected => 'Unexpected error';

  @override
  String get errorDisconnectionFailed => 'Could not disconnect';

  @override
  String get errorFailedToRegister => 'Failed to register device';

  @override
  String get ipInformation => 'Check my IP';

  @override
  String get connectionAnalytics => 'History';

  @override
  String get recentSessions => 'Recent connections';

  @override
  String get speedTest => 'Speed test';

  @override
  String get startTest => 'RUN DIAGNOSTICS';

  @override
  String get download => 'Download';

  @override
  String get upload => 'Upload';

  @override
  String get testingViaVpn => 'Testing via tunnel';

  @override
  String get testingDirect => 'Testing direct connection';

  @override
  String get splitTunneling => 'Route Configuration';

  @override
  String get splitTunnelingDescription =>
      'Choose which app categories bypass the tunnel. Excluded apps use your direct network connection.';

  @override
  String get enableSplitTunneling => 'Enable Route Splitting';

  @override
  String get splitTunnelActive => 'Selected apps bypass tunnel';

  @override
  String get splitTunnelInactive => 'All traffic routed through tunnel';

  @override
  String get bypassVpnFor => 'Bypass tunnel for';

  @override
  String get tools => 'Diagnostics';

  @override
  String get settingsGeneral => 'General';

  @override
  String get shareDiagnosticsTitle => 'Share connection diagnostics';

  @override
  String get shareDiagnosticsBody =>
      'Sends connection reports, your carrier and country, phone model and Android version, the names of sites you reach through the VPN with a daily count, and whether you saw or tapped our messages, Premium offers and invite card. We never see the pages you open or what you send.';

  @override
  String get security => 'Compliance';

  @override
  String get privacyDashboard => 'Endpoint Analysis';

  @override
  String get privacyDashboardSubtitle => 'IP transparency & leak monitoring';

  @override
  String get connectionAnalyticsSubtitle => 'Session history & reports';

  @override
  String get speedTestSubtitle => 'Throughput measurement';

  @override
  String get splitTunnelingSubtitle => 'Configure route policies';

  @override
  String get splashTagline => 'Private access, wherever you are';

  @override
  String get openSourceLicence => 'Open source licence';

  @override
  String get sourceOfferTitle => 'Open source licence';

  @override
  String get sourceOfferBody =>
      'Fortiva VPN is free software under the GNU General Public License v3. It builds on Xray-core and other open-source projects.\n\nYou are entitled to the complete source code for the version you have installed. To request it, email admin@fortivavpn.com with your app version. This offer is valid for three years from the date you received this version.';

  @override
  String get close => 'Close';

  @override
  String get account => 'Account';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountSubtitle =>
      'Permanently remove this device and your data';

  @override
  String get deleteAccountConfirmTitle => 'Delete your account?';

  @override
  String get deleteAccountConfirmBody =>
      'This removes your device registration, the personal servers created for you, and your support chat messages. Your connection history on this phone is erased too.\n\nThis cannot be undone. You can start again at any time by reopening the app.';

  @override
  String deleteAccountConfirmRetention(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '$days day',
    );
    return 'Your account record is removed immediately. Copies in backups and anonymous server logs are cleared within $_temp0.';
  }

  @override
  String get deleteAccountConfirmRetentionNoDays =>
      'Your account record is removed immediately. Copies in backups and anonymous server logs are cleared later, on the schedule in our privacy policy.';

  @override
  String get deleteAccountCancel => 'Keep my account';

  @override
  String get deleteAccountConfirm => 'Delete';

  @override
  String get deleteAccountInProgress => 'Deleting your account';

  @override
  String get deleteAccountDone => 'Your account has been deleted.';

  @override
  String get deleteAccountFailed =>
      'Could not delete your account. Check your connection and try again.';

  @override
  String get homeTapToConnect => 'Tap to connect';

  @override
  String get homeChecking => 'Checking connection';

  @override
  String get homePreparing => 'Setting up your server';

  @override
  String get homeDisconnecting => 'Disconnecting';

  @override
  String get homeFindingPath => 'Finding a path';

  @override
  String get diagCheckingInternet => 'Checking your internet';

  @override
  String get diagInternationalCut =>
      'International internet is cut on this network';

  @override
  String diagPathRow(String city, int n) {
    return '$city, path $n';
  }

  @override
  String get diagOpen => 'open';

  @override
  String get diagBlocked => 'blocked';

  @override
  String get diagSkipped => 'skipped today';

  @override
  String diagConnectingThrough(String city) {
    return 'Connecting through $city';
  }

  @override
  String get diagVerifying => 'Verifying traffic';

  @override
  String get diagNoInternet => 'Your phone has no internet right now.';

  @override
  String get diagCutOff =>
      'Your network cannot reach the international internet right now. Tap to try again.';

  @override
  String get diagNothingOpen =>
      'Every path is blocked right now. Tap to try again.';

  @override
  String get homeTryingAgain =>
      'Every path is blocked right now. Trying again soon.';

  @override
  String get homeCutOffTryingAgain =>
      'Your network cannot reach the international internet right now. Trying again soon.';

  @override
  String get homeOfflineTryingAgain =>
      'Your phone has no internet right now. Trying again soon.';

  @override
  String get diagPathFailed =>
      'The path was open but the tunnel did not come up. Tap to try again.';

  @override
  String get openVpnSettings => 'Open VPN settings';

  @override
  String get yourServer => 'YOUR SERVER';

  @override
  String get yourServerCaption =>
      'Yours alone. No one else connects through it.';

  @override
  String get ourServer => 'OUR SERVER';

  @override
  String get ourServerCaption =>
      'Run by Fortiva and shared with everyone. Used until your own server is ready.';

  @override
  String get communityServer => 'COMMUNITY SERVER';

  @override
  String get communityServerCaption =>
      'An extra connection option. It may stop working at any time.';

  @override
  String communityServerNumber(String n) {
    return 'Community server $n';
  }

  @override
  String get myServersTitle => 'Your servers';

  @override
  String get myServersExplainer =>
      'Every Fortiva device is given its own server in each location, with credentials that belong to this install alone. No account is needed.';

  @override
  String get myServersInUse => 'In use';

  @override
  String get myServersEmpty => 'No servers assigned yet';

  @override
  String get myServersRetry => 'Try again';

  @override
  String get myServersBlockedTitle => 'You have used today\'s data';

  @override
  String get myServersBlockedWait =>
      'Your allowance resets automatically. Check back soon.';

  @override
  String myServersMoved(String place) {
    return 'Now using $place';
  }

  @override
  String get copyLink => 'Copy link';

  @override
  String get linkCopied => 'Link copied';

  @override
  String quotaUsedToday(String used, String limit) {
    return '$used of $limit used today';
  }

  @override
  String get quotaUsedUp => 'Daily data used up';

  @override
  String get quotaUnlimited => 'Unlimited data';

  @override
  String get quotaDaily => 'Daily data';

  @override
  String get quotaLimitReached => 'Daily limit reached';

  @override
  String quotaLeftOf(String left, String limit) {
    return '$left of $limit left';
  }

  @override
  String get quotaResetsShortly => 'Resets shortly';

  @override
  String quotaResetsInHours(int hours) {
    return 'Resets in ${hours}h';
  }

  @override
  String quotaResetsInMinutes(int minutes) {
    return 'Resets in ${minutes}m';
  }

  @override
  String get myServersSubtitle => 'The servers provisioned for this device';

  @override
  String get sharedServersTitle => 'Shared servers';

  @override
  String get sharedServersSubtitle => 'Public locations, used as a fallback';

  @override
  String get tabOfficial => 'Our servers';

  @override
  String get noOfficialServers => 'No Fortiva servers right now';

  @override
  String get inviteTitle => 'Invite friends';

  @override
  String get inviteSubtitle => 'Earn extra daily data';

  @override
  String get inviteYourCode => 'Your invite code';

  @override
  String get inviteShareAction => 'Share invite';

  @override
  String get inviteCopyAction => 'Copy code';

  @override
  String get inviteCodeCopied => 'Code copied';

  @override
  String inviteShareMessage(String code, String url) {
    return 'A free VPN that works well for me: Fortiva. No sign-up needed.\nInstall it from this link:\n$url\nMy invite code: $code';
  }

  @override
  String get inviteHowItWorks => 'How it works';

  @override
  String inviteHowItWorksBody(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days different days',
      one: '$days day',
    );
    return 'Share your code. When someone installs the app, enters it, and uses the VPN on $_temp0, you get $amount added to your daily data. It stays on your account.';
  }

  @override
  String inviteHowItWorksBodyNoAmount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days different days',
      one: '$days day',
    );
    return 'Share your code. When someone installs the app, enters it, and uses the VPN on $_temp0, you get more data every day. It stays on your account.';
  }

  @override
  String inviteHowItWorksBodyNoDays(String amount) {
    return 'Share your code. When someone installs the app, enters it, and uses the VPN for a while, you get $amount added to your daily data. It stays on your account.';
  }

  @override
  String get inviteHowItWorksBodyNoAmountNoDays =>
      'Share your code. When someone installs the app, enters it, and uses the VPN for a while, you get more data every day. It stays on your account.';

  @override
  String inviteHowItWorksCap(String max) {
    return 'You can earn up to $max a day from invites.';
  }

  @override
  String get inviteStatInvited => 'Invited';

  @override
  String get inviteStatEarning => 'Qualified';

  @override
  String get inviteStatBonus => 'Bonus data';

  @override
  String inviteBonusPerDay(String amount) {
    return '+$amount every day';
  }

  @override
  String get inviteNoBonusYet => 'No bonus yet';

  @override
  String invitePendingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invites have not qualified yet',
      one: '1 invite has not qualified yet',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String inviteJoinedWith(String code) {
    return 'You joined with code $code';
  }

  @override
  String get inviteLoadFailed => 'Could not load your invite code';

  @override
  String get inviteRetry => 'Try again';

  @override
  String get inviteHaveCodeTitle => 'Have an invite code?';

  @override
  String inviteHaveCodeSubtitle(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Enter it in your first $hours hours',
      one: 'Enter it in your first hour',
    );
    return '$_temp0';
  }

  @override
  String get inviteHaveCodeSubtitleNoHours => 'Enter it soon after installing';

  @override
  String get inviteEnterCodeHint => 'Invite code';

  @override
  String get inviteApplyAction => 'Apply';

  @override
  String get inviteNotNowAction => 'Not now';

  @override
  String inviteClaimAccepted(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days different days',
      one: '$days day',
    );
    return 'Invite accepted. Your friend earns bonus data once you have used the VPN on $_temp0.';
  }

  @override
  String get inviteClaimAcceptedNoDays =>
      'Invite accepted. Your friend earns bonus data once you have used the VPN for a while.';

  @override
  String get inviteClaimAlready =>
      'This device has already used an invite code';

  @override
  String get inviteClaimRejected =>
      'That code did not work. Check it and try again';

  @override
  String get inviteClaimNetwork => 'Could not reach the server. Try again';

  @override
  String get inviteCardTitle =>
      'Is Fortiva working well for you? Send it to a friend';

  @override
  String get inviteCardBody =>
      'Send your friend the install link so they can connect for free too.';

  @override
  String inviteCardReward(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'When your friend starts using Fortiva, you get $days days of Premium.',
      one:
          'When your friend starts using Fortiva, you get $days day of Premium.',
    );
    return '$_temp0';
  }

  @override
  String get inviteCardRewardNoAmount =>
      'When your friend starts using Fortiva, you get Premium as a gift.';

  @override
  String get inviteSendTelegram => 'Telegram';

  @override
  String get inviteSendWhatsApp => 'WhatsApp';

  @override
  String get inviteCopyLink => 'Copy link';

  @override
  String get inviteOtherApps => 'Other apps';

  @override
  String get inviteLinkCopied => 'Invite message copied';

  @override
  String get invitePasteBody =>
      'Copy the code from your friend\'s message and paste it here.';

  @override
  String get invitePasteAction => 'Paste';

  @override
  String get inviteErrorTooLate =>
      'The time to enter an invite code on this phone has passed.';

  @override
  String get inviteErrorUnknown =>
      'We could not find this code. Copy it again from your friend\'s message.';

  @override
  String get inviteErrorOwnCode =>
      'This is your own code. Enter your friend\'s code.';

  @override
  String get inviteErrorMutual =>
      'You and your friend cannot invite each other.';

  @override
  String inviteHowItWorksPremium(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Each friend who starts using Fortiva also gives you $days days of Premium.',
      one:
          'Each friend who starts using Fortiva also gives you $days day of Premium.',
    );
    return '$_temp0';
  }

  @override
  String inviteHowItWorksPremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'You can earn up to $max days of Premium from invites.',
      one: 'You can earn up to $max day of Premium from invites.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeLive =>
      'Your bonus lasts while your friends keep using Fortiva. If a friend stops, it goes down.';

  @override
  String inviteTreeNext(String amount) {
    return 'Your next friend adds $amount a day once they start using Fortiva.';
  }

  @override
  String inviteTreeKept(String amount) {
    return 'Your bonus never goes below $amount a day, because of friends you invited before.';
  }

  @override
  String get inviteTreeSlotsTitle => 'Your slots';

  @override
  String get inviteTreeSlotActive => 'Active';

  @override
  String get inviteTreeSlotNotActive => 'Not active now';

  @override
  String get inviteTreeSlotEmpty => 'Open slot';

  @override
  String inviteTreePaysNow(String amount) {
    return '+$amount a day now';
  }

  @override
  String inviteTreePairFull(String amount) {
    return '+$amount a day when both are active';
  }

  @override
  String get inviteTreeNothingYet => 'Nothing yet';

  @override
  String get inviteTreeFriendsTitle => 'Through your slots';

  @override
  String get inviteTreeRowFriends => 'In your slots';

  @override
  String get inviteTreeRowFriendsSlots => 'In their slots';

  @override
  String inviteTreeRowSteps(int steps) {
    String _temp0 = intl.Intl.pluralLogic(
      steps,
      locale: localeName,
      other: '$steps steps away',
      one: '$steps step away',
    );
    return '$_temp0';
  }

  @override
  String inviteTreeRowPeople(int people, int active) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people people',
      one: '$people person',
    );
    return '$_temp0, $active active';
  }

  @override
  String inviteTreeHowSlots(int slots) {
    String _temp0 = intl.Intl.pluralLogic(
      slots,
      locale: localeName,
      other:
          'Share your code. The first $slots friends who qualify fill your slots, in pairs.',
      one: 'Share your code. The first friend who qualifies fills your slot.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeHowSlotsNoNumber =>
      'Share your code. The first friends who qualify fill your slots, in pairs.';

  @override
  String get inviteTreeHowPair =>
      'A pair adds more data when both people in it are active.';

  @override
  String get inviteTreeHowFriendsSlots =>
      'When your slots are full, your next friends who qualify take the next open slots, further from you. They still add data for you, less the further they are.';

  @override
  String get inviteTreeHowOthers =>
      'Your first pair can also take people you did not invite. They add data for you in the same way.';

  @override
  String inviteTreeHowActive(int days, int window) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '$days day',
    );
    String _temp1 = intl.Intl.pluralLogic(
      window,
      locale: localeName,
      other: '$window days',
      one: '$window day',
    );
    return 'A friend is active while they have used Fortiva on at least $_temp0 in the last $_temp1.';
  }

  @override
  String get inviteTreeHowActiveNoNumber =>
      'A friend is active while they keep using Fortiva.';

  @override
  String inviteTreeHowCap(String max) {
    return 'Invites can add up to $max a day.';
  }

  @override
  String get inviteTreeHowCapNoAmount =>
      'There is a daily limit to what invites can add.';

  @override
  String get inviteTreeIntroTitle => 'How friends add data';

  @override
  String get inviteTreeIntroOpen => 'Show me step by step';

  @override
  String inviteTreeIntroStep(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get inviteTreeIntroSkip => 'Skip';

  @override
  String get inviteTreeIntroNext => 'Next';

  @override
  String get inviteTreeIntroBack => 'Back';

  @override
  String get inviteTreeIntroDone => 'Done';

  @override
  String get inviteTreeIntroYou => 'You';

  @override
  String get inviteTreeIntroSlotsTitle => 'Friends fill your slots in pairs';

  @override
  String get inviteTreeIntroSlotsWhen =>
      'A friend takes a slot once they start using Fortiva.';

  @override
  String get inviteTreeIntroSlotsArt =>
      'Your slots, in pairs, filling as friends join.';

  @override
  String get inviteTreeIntroPairTitle =>
      'A pair adds the most when both are active';

  @override
  String inviteTreeIntroPairBoth(String full, String one) {
    return 'When both friends in your first pair are active, it adds $full a day. When only one of them is active, it adds $one a day.';
  }

  @override
  String inviteTreeIntroPairBothOnly(String full) {
    return 'When both friends in your first pair are active, it adds $full a day. When only one of them is active, it adds nothing.';
  }

  @override
  String inviteTreeIntroPairNoOne(String full) {
    return 'When both friends in your first pair are active, it adds $full a day. When only one of them is active, it adds less.';
  }

  @override
  String get inviteTreeIntroPairOthersLess => 'Your other pairs add less.';

  @override
  String inviteTreeIntroAdds(String amount) {
    return '+$amount a day';
  }

  @override
  String get inviteTreeIntroPairArt =>
      'A pair of slots. It adds more data when both friends in it are active.';

  @override
  String get inviteTreeIntroFurtherTitle =>
      'Friends further away still add data';

  @override
  String get inviteTreeIntroFirstPairOnly =>
      'From your friend\'s slots, only their first pair adds data for you.';

  @override
  String get inviteTreeIntroYourFriend => 'Your friend';

  @override
  String get inviteTreeIntroTheirPair => 'Their first pair';

  @override
  String get inviteTreeIntroFurtherArt =>
      'Your friend\'s first pair adds data for your friend and for you. Pairs further away add less.';

  @override
  String get inviteTreeIntroTotalTitle => 'Your data from friends';

  @override
  String get inviteTreeIntroTotalNow => 'From friends now';

  @override
  String get inviteTreeIntroTotalMost => 'The most invites can add';

  @override
  String get inviteTreeIntroTotalKept => 'Kept from earlier invites';

  @override
  String inviteTreeIntroTotalReach(String max) {
    return 'Free data plus data from friends can reach $max a day.';
  }

  @override
  String inviteTreeIntroPerDay(String amount) {
    return '$amount a day';
  }

  @override
  String inviteTreeSheetNext(String amount) {
    return 'Your next friend adds $amount a day once they start using Fortiva. It does not add to today\'s data.';
  }

  @override
  String get inviteTreeHero => 'Friends add to your daily data';

  @override
  String inviteTreePremiumEach(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Each friend who starts using Fortiva also gives you $days days of Premium.',
      one:
          'Each friend who starts using Fortiva also gives you $days day of Premium.',
    );
    return '$_temp0';
  }

  @override
  String inviteTreePremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Invites can add up to $max days of Premium.',
      one: 'Invites can add up to $max day of Premium.',
    );
    return '$_temp0';
  }

  @override
  String get premiumSourceInvite => 'From your invites';

  @override
  String quotaBonusIncluded(String amount) {
    return 'includes $amount invite bonus';
  }

  @override
  String get updateTitle => 'Update available';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String updateBody(String version) {
    return 'Fortiva $version is out. Update for the newest fixes.';
  }

  @override
  String get updateRequiredBody =>
      'This version is no longer supported. Update to keep using Fortiva.';

  @override
  String get updateNow => 'Update';

  @override
  String get updateLater => 'Later';

  @override
  String get updateFromPlay => 'Google Play';

  @override
  String get updateFromTelegram => 'Telegram channel';

  @override
  String get updateConnect => 'Connect';

  @override
  String get updateConnectHint =>
      'If Google Play or Telegram does not open, tap Connect first.';

  @override
  String get updateConnected => 'You are connected. Download the update now.';

  @override
  String get updateReconnect => 'Not working? Reconnect';

  @override
  String get updateDisconnect => 'Disconnect';

  @override
  String get updateDisconnectHint =>
      'Tap Disconnect to download the update over your normal internet.';

  @override
  String get updateNotCarrying =>
      'You are connected, but nothing is getting through. Try Reconnect, or tap Disconnect to use your normal internet.';

  @override
  String get diagVerdictNoInternet =>
      'Your phone has no internet connection. Fortiva cannot connect until that is back.';

  @override
  String get diagVerdictCutOff =>
      'Your network cannot reach the international internet right now. Try again in a few minutes.';

  @override
  String get diagVerdictNeedsPermission =>
      'Fortiva does not have permission to run a VPN, or another VPN app is set to always on.';

  @override
  String get diagVerdictServerUnreachable =>
      'This server cannot be reached from your network. It is either blocked here or down.';

  @override
  String get diagVerdictBlockedTls =>
      'The connection to this server is being cut while it is being set up. That is what filtering looks like.';

  @override
  String get diagVerdictThrottled =>
      'The server answered every check and the tunnel still carried nothing. The connection is being slowed.';

  @override
  String get diagCheckInternet => 'Check your internet';

  @override
  String diagTryServer(String server) {
    return 'Start a new search on $server';
  }

  @override
  String get diagTryAnotherServer => 'Try another server';

  @override
  String get diagDetails => 'Details';

  @override
  String get diagDetailsHide => 'Hide details';

  @override
  String privateDnsWarning(String host) {
    return 'Private DNS is on ($host), so some sites may not open. Turn Private DNS off in your phone\'s settings.';
  }

  @override
  String get openNetworkSettings => 'Open network settings';

  @override
  String testPointStatus(String time, int open, int total) {
    return 'Test point · last check $time · $open of $total doors open';
  }

  @override
  String get messagesTooltip => 'Messages';

  @override
  String get inboxTitle => 'Messages';

  @override
  String get inboxEmpty => 'No messages right now.';

  @override
  String get messageClose => 'Close';

  @override
  String get supportTitle => 'Support';

  @override
  String get supportTooltip => 'Chat with support';

  @override
  String get supportAskAction => 'Ask support';

  @override
  String get supportContactSubtitle => 'Chat with us in the app';

  @override
  String get supportAutomaticNotice =>
      'Answers are written automatically and can be wrong.';

  @override
  String get supportStaffNotice =>
      'Automatic answers are off for now. Your messages go to our team.';

  @override
  String get supportInputHint => 'Write your question';

  @override
  String get supportInputHintTeam => 'Write to our team';

  @override
  String get supportSend => 'Send';

  @override
  String supportQuotaLeft(int remaining, int limit) {
    return '$remaining of $limit questions left today';
  }

  @override
  String supportWaitIn(String time) {
    return 'You can ask again in $time.';
  }

  @override
  String supportDurationHours(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String supportDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get supportNewConversation => 'New conversation';

  @override
  String get supportSending => 'Sending';

  @override
  String get supportNotSent => 'Not sent. Tap to try again.';

  @override
  String get supportRateUp => 'Helpful';

  @override
  String get supportRateDown => 'Not helpful';

  @override
  String get supportRatedDown => 'Thanks. Our team will look at this answer.';

  @override
  String get supportTeamLabel => 'Fortiva team';

  @override
  String get supportUnavailable => 'Chat is not available right now.';

  @override
  String get supportOpenTelegram => 'Message us on Telegram';

  @override
  String get supportGenericError => 'Something went wrong. Please try again.';

  @override
  String supportCodeTooLong(int max) {
    return 'Your message is too long. Keep it under $max characters.';
  }

  @override
  String get supportCodeEmpty => 'Your message is empty.';

  @override
  String get supportCodeWaitReply =>
      'Please wait for the answer to your last question.';

  @override
  String get supportCodeSlowDown =>
      'You are sending messages too quickly. Please wait a little.';

  @override
  String get supportCodeQuotaDay => 'You have used all of today\'s questions.';

  @override
  String get supportCodePaused => 'Automatic answers are paused for now.';

  @override
  String get supportCodeBusy =>
      'Our assistant is busy right now. Please try again in a few minutes.';

  @override
  String get supportCodeGreeting => 'Hi! How can I help you with Fortiva?';

  @override
  String get supportCodeGibberish =>
      'Sorry, I did not understand that. Please write your question again.';

  @override
  String get supportCodeRedacted =>
      'We removed personal details and links from your message.';

  @override
  String get supportCodeRedactedEmpty =>
      'Your message only had personal details or links, so it was not sent. Please describe the problem in words.';

  @override
  String get supportCodeOffTopic =>
      'I can only help with questions about using Fortiva.';

  @override
  String get supportCodeAbuse =>
      'Let\'s keep it respectful. I am here to help you with Fortiva.';

  @override
  String get supportCodeAiUnavailable =>
      'The assistant could not answer this time. Please try again in a little while.';

  @override
  String get supportCodeToStaff =>
      'Sent to our team. Their reply will show up here.';

  @override
  String get supportCodeTicketOpened =>
      'We passed your question to our team. Their reply will show up here.';

  @override
  String get supportCodeNotSent =>
      'This message could not be sent. Write it again if you still need help.';

  @override
  String get supportAssistantSubtitle => 'AI assistant';

  @override
  String get supportThinkingReading => 'Reading your question';

  @override
  String get supportThinkingSearching => 'Looking for the answer';

  @override
  String get supportThinkingWriting => 'Writing the answer';

  @override
  String get supportThinkingStill => 'Still on it, thanks for waiting';

  @override
  String get supportSuggestConnect => 'I can\'t connect';

  @override
  String get supportSuggestData => 'How much data do I have today?';

  @override
  String get supportSuggestSlow => 'My connection is slow';

  @override
  String get supportWithTeam => 'This conversation is now with our team.';

  @override
  String get supportTryAgainSoon => 'Try again in a few minutes.';

  @override
  String supportDurationWholeHours(int hours) {
    return '$hours h';
  }

  @override
  String get supportUnreadReply => 'New reply';

  @override
  String get premiumTitle => 'Premium';

  @override
  String get premiumTileSubtitle => 'Unlimited data with no daily limit';

  @override
  String get premiumTileActive => 'Premium is on';

  @override
  String get premiumGetUnlimited => 'Get unlimited';

  @override
  String get premiumHeadline => 'Get unlimited data';

  @override
  String get premiumPitch =>
      'Premium lifts the daily limit, so you can use as much data as you like until it ends.';

  @override
  String get premiumActiveTitle => 'Premium is on';

  @override
  String premiumActiveUntil(String date) {
    return 'Unlimited data until $date';
  }

  @override
  String get premiumActiveNoDate => 'Unlimited data';

  @override
  String get premiumRenews => 'Renews automatically through Google Play';

  @override
  String get premiumSourceKey => 'Activated with a key';

  @override
  String get premiumSourceCrypto => 'Paid with crypto';

  @override
  String get premiumSourceStars => 'Paid with Telegram Stars';

  @override
  String get premiumSourceGooglePlay => 'Paid through Google Play';

  @override
  String get premiumSourceManual => 'A gift from the Fortiva team';

  @override
  String get premiumYourKey => 'Your key';

  @override
  String get premiumKeyHint =>
      'Keep this key safe. Enter it on another phone to move Premium there.';

  @override
  String premiumKeyMoves(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'up to $count times',
      one: 'once',
    );
    String _temp1 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '$days day',
    );
    return 'A key can move to another phone $_temp0 in $_temp1.';
  }

  @override
  String get premiumKeyMovesNoNumber =>
      'A key can move to another phone only a limited number of times.';

  @override
  String get premiumCopy => 'Copy';

  @override
  String get premiumCopied => 'Copied';

  @override
  String get premiumChoosePlan => 'Choose a plan';

  @override
  String premiumPlanDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days of unlimited data',
      one: '$days day of unlimited data',
    );
    return '$_temp0';
  }

  @override
  String get premiumPlanNoDays => 'Unlimited data';

  @override
  String get premiumBuy => 'Buy';

  @override
  String get premiumPlayUnavailable =>
      'Google Play is not available right now. Try again later.';

  @override
  String get premiumPlayPending =>
      'Your payment is pending in Google Play. Premium starts as soon as it goes through.';

  @override
  String get premiumPlayConfirming => 'Confirming your purchase...';

  @override
  String get premiumPlayRetrying =>
      'Your payment went through, but we could not confirm it yet. We will keep trying, so you do not need to pay again.';

  @override
  String get premiumPlayRefused =>
      'We could not confirm this purchase. If you were charged, contact support.';

  @override
  String get premiumPlayNotAvailable =>
      'Premium is not available on this phone right now. If you were charged, contact support.';

  @override
  String get premiumNotAvailable =>
      'Premium is not available on this phone right now.';

  @override
  String get premiumPlayFailed => 'The purchase did not go through. Try again.';

  @override
  String get premiumNowOn => 'Premium is on. Enjoy unlimited data.';

  @override
  String get premiumRestore => 'Restore purchases';

  @override
  String get premiumRestoreDone => 'Your purchase is restored on this phone.';

  @override
  String get premiumRestoreNone => 'Google Play has no purchase to restore.';

  @override
  String get premiumRestoreFailed =>
      'Could not restore your purchase. Try again later.';

  @override
  String premiumRenewsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Billed every $count days. Renews automatically until you cancel.',
      one: 'Billed every day. Renews automatically until you cancel.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Billed every $count weeks. Renews automatically until you cancel.',
      one: 'Billed every week. Renews automatically until you cancel.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Billed every $count months. Renews automatically until you cancel.',
      one: 'Billed every month. Renews automatically until you cancel.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Billed every $count years. Renews automatically until you cancel.',
      one: 'Billed every year. Renews automatically until you cancel.',
    );
    return '$_temp0';
  }

  @override
  String get premiumRenewsNoPeriod => 'Renews automatically until you cancel.';

  @override
  String get premiumPlayCancelNote =>
      'You can cancel anytime in Google Play. Premium stays on until the end of the time you paid for.';

  @override
  String get premiumManageSubscription => 'Manage or cancel subscription';

  @override
  String get premiumCurrentPlan => 'Current plan';

  @override
  String get premiumPlaySubscribed =>
      'You already have a Google Play subscription. Manage or cancel it in Google Play.';

  @override
  String get premiumEnterCode => 'Enter a code';

  @override
  String get premiumNeedsPlayVersion =>
      'To buy through Google Play, you need the Google Play version of Fortiva.';

  @override
  String get premiumOff => 'Premium is not on sale right now.';

  @override
  String get premiumLoadFailed =>
      'Could not load Premium. Check your connection and try again.';

  @override
  String get premiumRetry => 'Try again';

  @override
  String premiumPriceUsdt(String price) {
    return '$price USDT';
  }

  @override
  String premiumPriceStars(String stars) {
    return '$stars Telegram Stars';
  }

  @override
  String get premiumPayCrypto => 'Pay with crypto';

  @override
  String get premiumTelegramTitle => 'Pay in Telegram';

  @override
  String get premiumTelegramBody =>
      'Pay with Telegram Stars in our bot. You get a key, and Premium starts on this phone right away.';

  @override
  String get premiumTelegramButton => 'Buy in Telegram';

  @override
  String get premiumTelegramFailed => 'Could not open Telegram. Try again.';

  @override
  String get checkoutTitle => 'Pay with crypto';

  @override
  String get checkoutChooseNetwork => 'Choose the network you will send from';

  @override
  String get checkoutContinue => 'Continue';

  @override
  String get checkoutSendExactly => 'Send exactly';

  @override
  String get checkoutNetwork => 'Network';

  @override
  String get checkoutAddress => 'To this address';

  @override
  String get checkoutMemo => 'With this memo';

  @override
  String get checkoutMemoWarning =>
      'Put this memo in your transfer, or we cannot match the payment to you.';

  @override
  String get checkoutExactWarning =>
      'Send the exact amount, on this network only. A different amount or network may not reach us.';

  @override
  String checkoutTimeLeft(String time) {
    return 'Time left: $time';
  }

  @override
  String get checkoutWaiting =>
      'Waiting for your payment. This page updates by itself.';

  @override
  String get checkoutPaidTitle => 'Payment received';

  @override
  String get checkoutPaidKeyOnly =>
      'Your key is ready. Enter it on the phone that should get Premium.';

  @override
  String get checkoutDone => 'Done';

  @override
  String get checkoutExpired =>
      'This order has expired. If you already paid, contact support.';

  @override
  String get checkoutUnderpaid =>
      'We received less than the full amount. Contact support and give them this order number:';

  @override
  String get checkoutCanceled => 'This order was canceled.';

  @override
  String get checkoutStartAgain => 'Start again';

  @override
  String get checkoutUnavailable =>
      'Crypto payments are not available right now.';

  @override
  String get checkoutTooManyOpen =>
      'You have too many unpaid orders. Pay one of them or wait until they expire.';

  @override
  String get checkoutUnknownPlan =>
      'This plan is no longer on sale. Go back and choose another.';

  @override
  String get checkoutFailed =>
      'Could not start the payment. Check your connection and try again.';

  @override
  String get redeemTitle => 'Enter a code';

  @override
  String get redeemSubtitle => 'A Premium key or a gift code';

  @override
  String get redeemHint => 'Code';

  @override
  String get redeemApply => 'Apply';

  @override
  String get redeemCancel => 'Cancel';

  @override
  String get redeemInvalid =>
      'That does not look like a code. Check it and try again.';

  @override
  String get redeemUnknown =>
      'We do not know this code. Check it and try again.';

  @override
  String get redeemExpired => 'This code has expired.';

  @override
  String get redeemRevoked => 'This code is no longer valid.';

  @override
  String get redeemMovedTooOften =>
      'This key has moved between phones too often lately. Try again later.';

  @override
  String get redeemExhausted => 'This code has been used up.';

  @override
  String get redeemAlreadyUsed => 'This phone has already used this code.';

  @override
  String get redeemUnmetered =>
      'This phone already has unlimited data, so it does not need this code.';

  @override
  String get redeemRateLimited =>
      'Too many tries. Wait a little and try again.';

  @override
  String get redeemUnavailable =>
      'This is not available right now. Try again later.';

  @override
  String get redeemNetwork =>
      'Could not reach the server. Check your connection and try again.';

  @override
  String get redeemFailed => 'That code did not work. Check it and try again.';

  @override
  String get redeemMoved => 'Premium moved to this phone.';

  @override
  String redeemPromo(String amount) {
    return 'Code accepted. $amount of extra data added.';
  }

  @override
  String get redeemPromoNoAmount => 'Code accepted. Extra data added.';

  @override
  String get tvScanTitle => 'Open on your phone';

  @override
  String get tvScanBody => 'Point your phone\'s camera at this code.';

  @override
  String get refresh => 'Refresh';

  @override
  String get premiumNotNow => 'Not now';

  @override
  String get premiumLimitSheetTitle => 'Today\'s data is used up';

  @override
  String get premiumLimitWait => 'Wait for the reset';

  @override
  String get premiumLimitInvite => 'Invite friends for more data';

  @override
  String premiumLimitInviteNext(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days different days',
      one: '$days day',
    );
    return 'Your next friend adds $amount a day once they have used Fortiva on $_temp0. It does not add to today\'s data.';
  }

  @override
  String premiumLimitInviteNextNoDays(String amount) {
    return 'Your next friend adds $amount a day once they have used Fortiva for a while. It does not add to today\'s data.';
  }

  @override
  String get premiumLimitInviteNoAmount =>
      'Friends you invite add to your daily data once they start using Fortiva. It does not add to today\'s data.';

  @override
  String get premiumLimitInvitesFull =>
      'Your invites already add the most data they can.';

  @override
  String get premiumLimitSeeInvites => 'See your invites';

  @override
  String get premiumLimitShareAgain => 'Share with another friend';

  @override
  String get premiumNoDailyLimit => 'Premium has no daily limit.';

  @override
  String get premiumCalmTitle => 'Want no daily limit?';

  @override
  String get premiumCalmBody =>
      'Premium gives you unlimited data. Your free plan stays as it is.';

  @override
  String get premiumNextStepTitle => 'The next step is Premium';

  @override
  String get premiumNextStepBody =>
      'You already have the most free data. Premium has no daily limit.';

  @override
  String get premiumLockedTag => 'Premium';

  @override
  String premiumLockedTitle(String place) {
    return 'Unlock $place with Premium';
  }

  @override
  String get premiumLockedBody =>
      'This location is for Premium. Your free servers stay the same.';

  @override
  String get premiumHeadlineLimit => 'No daily limit';

  @override
  String premiumHeadlineLocked(String place) {
    return 'Unlock $place with Premium';
  }

  @override
  String get premiumFreeStays => 'The free plan keeps working without Premium.';

  @override
  String premiumEndsOn(String date) {
    return 'Premium ends on $date';
  }

  @override
  String get premiumRenewBody =>
      'Renew to keep unlimited data. Renewing adds time to your current end date.';

  @override
  String premiumEndedOn(String date) {
    return 'Premium ended on $date. Your free plan is back.';
  }

  @override
  String get premiumRenew => 'Renew';

  @override
  String get noticeChannelName => 'Messages from Fortiva';

  @override
  String get noticeChannelDescription =>
      'News and messages from the Fortiva team';

  @override
  String get noticesSettingTitle => 'Notifications';

  @override
  String get noticesSettingOn =>
      'On. Messages from the Fortiva team can reach you even when the app is closed.';

  @override
  String get noticesSettingOff =>
      'Off. Turn them on to get messages from the Fortiva team even when the app is closed.';

  @override
  String get noticesOffCard =>
      'Turn on notifications to get messages from the Fortiva team even when the app is closed.';

  @override
  String get noticesTurnOn => 'Turn on';

  @override
  String get backgroundCard =>
      'Your phone may hold back messages from the Fortiva team while the app is closed. Let Fortiva run in the background so they reach you.';

  @override
  String get backgroundHint =>
      'On the next screen, choose Fortiva (if it is not listed, show all apps). Then set its battery use to Unrestricted, or allow it to start and run in the background.';

  @override
  String get backgroundAllow => 'Allow';

  @override
  String get backgroundNotNow => 'Not now';

  @override
  String get backgroundSettingTitle => 'Messages while closed';

  @override
  String get backgroundSettingSubtitle =>
      'Let Fortiva run in the background so messages reach you while the app is closed.';

  @override
  String get backgroundCardData =>
      'Data Saver on your phone may stop messages from the Fortiva team while the app is closed.';

  @override
  String get backgroundHintData =>
      'On the next screen, turn on Unrestricted data.';

  @override
  String get apnGuideTitle => 'A steadier connection on this SIM';

  @override
  String get apnGuideBody =>
      'Your phone is not using IPv6 on this SIM. Turning it on helps Fortiva stay connected.';

  @override
  String get apnGuideShowMe => 'Show me how';

  @override
  String get apnGuideNotNow => 'Not now';

  @override
  String get apnGuideSheetTitle => 'Turn on IPv6 for this SIM';

  @override
  String apnGuideStepOpen(String button) {
    return 'Tap \"$button\" (or go to Settings > Connections > Mobile networks > Access Point Names).';
  }

  @override
  String apnGuideStepAccessPoint(String apn) {
    return 'Tap the access point in use ($apn).';
  }

  @override
  String get apnGuideStepAccessPointAny => 'Tap the access point in use.';

  @override
  String get apnGuideStepProtocol =>
      'Tap \"APN protocol\" and choose \"IPv4/IPv6\".';

  @override
  String get apnGuideStepSave =>
      'Save (on Samsung: the three-dot menu, then Save).';

  @override
  String get apnGuideStepRestart => 'Turn mobile data off and on again.';

  @override
  String get apnGuideUndo =>
      'If mobile data stops working, set APN protocol back to IPv4.';

  @override
  String get apnGuideOpenSettings => 'Open APN settings';

  @override
  String get homeStallSearching =>
      'The connection stopped working. Finding another path.';

  @override
  String get homeStalled => 'Connected, but no data is getting through';

  @override
  String get peerShareTitle => 'Help a friend connect';

  @override
  String get peerShareSubtitle =>
      'Pass what Fortiva needs to a friend\'s phone';

  @override
  String get peerShareBody =>
      'If a friend\'s Fortiva cannot connect, their phone can get what it needs from yours. This works without internet.';

  @override
  String peerShareSteps(String action) {
    return 'In Fortiva on their phone, open Settings and tap $action. Then show them these codes one at a time, or send this to them.';
  }

  @override
  String get peerShareLoading => 'Getting the newest copy';

  @override
  String get peerShareNothing =>
      'This phone has nothing recent to pass on. Try again later.';

  @override
  String peerShareCodeOf(int current, int total) {
    return 'Code $current of $total';
  }

  @override
  String get peerSharePrevious => 'Back';

  @override
  String get peerShareNext => 'Next';

  @override
  String get peerShareCopy => 'Copy';

  @override
  String get peerShareSend => 'Send';

  @override
  String get peerShareCopied => 'Copied. Paste it in a message to your friend.';

  @override
  String get peerReceiveTitle => 'Get help from a friend';

  @override
  String get peerReceiveSubtitle => 'When nothing else connects';

  @override
  String peerReceiveBody(String action) {
    return 'Ask a friend whose Fortiva connects to open Settings in Fortiva and tap $action. Then get it from their phone in one of these ways.';
  }

  @override
  String get peerReceivePhotograph => 'Photograph their codes';

  @override
  String get peerReceivePhotographNext => 'Photograph the next code';

  @override
  String peerReceiveProgress(int have, int total) {
    return '$have of $total codes read';
  }

  @override
  String get peerReceiveFile => 'Open a file they sent';

  @override
  String get peerReceivePaste => 'Paste what they sent';

  @override
  String get peerReceiveNoCode =>
      'No code found in that photo. Hold the phone closer, with the whole code in view.';

  @override
  String get peerReceiveRefused =>
      'Fortiva cannot use that. Ask your friend to send it again.';

  @override
  String get peerReceiveNotNewer =>
      'You already have this, or something newer. Try connecting again, or ask another friend.';

  @override
  String get peerReceiveTaken => 'Done. Tap the button to connect.';

  @override
  String get peerReceiveUnavailable =>
      'This phone cannot do that. Try another way.';

  @override
  String get peerReceiveNothingToPaste =>
      'Nothing copied yet. Copy what your friend sent, then tap here again.';

  @override
  String get peerOfferBody =>
      'Still cannot connect? A friend whose Fortiva works can help from their phone.';

  @override
  String get peerReceiveAgain =>
      'You already have this code. Ask your friend to show the next one.';

  @override
  String get peerReceivePasteNotOurs =>
      'What you copied is not from Fortiva. Copy your friend\'s whole message, then try again.';

  @override
  String peerReceiveNoPhoto(String action) {
    return 'The camera did not hand the photo back. Take the photo with the camera app, then tap $action.';
  }

  @override
  String get peerReceiveFileHint =>
      'A file from a messenger may need to be saved to Downloads first.';

  @override
  String get homeTryingBackup =>
      'Nothing else connected. Trying a backup network now.';

  @override
  String get homeConnectedBackup => 'Connected through a backup network';

  @override
  String get backupNetwork => 'BACKUP NETWORK';

  @override
  String get backupNetworkTitle => 'Backup network';

  @override
  String get backupNetworkCaption =>
      'Used when nothing else connects. It can be slower than our servers.';

  @override
  String get backupNetworkPlace => 'Location picked automatically';

  @override
  String get speedTestStart => 'Start test';

  @override
  String get speedTestAgain => 'Test again';

  @override
  String get speedTestRunning => 'Testing';

  @override
  String get speedTestIdle => 'See how fast your connection is right now.';

  @override
  String get speedTestPhasePing => 'Checking response time';

  @override
  String get speedTestPhaseDownload => 'Measuring download speed';

  @override
  String get speedTestPhaseUpload => 'Measuring upload speed';

  @override
  String get speedTestDone => 'Test finished';

  @override
  String get speedTestFailed =>
      'The test could not finish. Check your internet and try again.';

  @override
  String get speedTestUnit => 'Mbps';

  @override
  String get ipAddressLabel => 'IP address';

  @override
  String get ipCopied => 'Address copied';

  @override
  String get ipLocation => 'Location';

  @override
  String get ipProvider => 'Internet provider';

  @override
  String get ipOrganization => 'Organization';

  @override
  String get ipTimeZone => 'Time zone';

  @override
  String get ipCoordinates => 'Coordinates';

  @override
  String get ipCheckFailed => 'Could not check your address';

  @override
  String get historyAverage => 'Average connection';

  @override
  String get historyRecentDays => 'Recent days';

  @override
  String yesterdayAt(String time) {
    return 'Yesterday at $time';
  }

  @override
  String dateAt(String date, String time) {
    return '$date at $time';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String get stageOwn => 'Fortiva servers';

  @override
  String get stageCommunity => 'Community servers';

  @override
  String stageProgress(int n, int total) {
    return 'Stage $n of $total';
  }

  @override
  String get stageTryingOwn => 'Trying Fortiva servers';

  @override
  String get stageTryingCommunity => 'Trying community servers';

  @override
  String get stageOwnFailedTryingCommunity =>
      'Fortiva servers did not connect here. Trying community servers.';

  @override
  String stageLastWorked(String server) {
    return 'Last server that worked: $server';
  }

  @override
  String stageTriedBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paths tried, blocked here',
      one: '$count path tried, blocked here',
    );
    return '$_temp0';
  }

  @override
  String stageTriedFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paths tried, none connected',
      one: '$count path tried, it did not connect',
    );
    return '$_temp0';
  }

  @override
  String get stageNotConnected => 'Did not connect';

  @override
  String get stageConnected => 'Connected here';

  @override
  String get stageSkipped => 'Skipped this time';

  @override
  String stageMoreToCheck(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more paths to check',
      one: '$count more path to check',
    );
    return '$_temp0';
  }

  @override
  String stageNextTry(String stage, String time) {
    return 'Next try starts with $stage in $time';
  }

  @override
  String get searchSlowHint =>
      'This can take a minute or two. Tap the button to stop the search.';

  @override
  String get searchStopped => 'Search stopped';

  @override
  String get homeConnectedCommunity => 'Connected through a community server';

  @override
  String get stageGettingServers => 'Getting your servers';

  @override
  String stageNextTryStarting(String stage) {
    return 'Starting the next try with $stage';
  }
}
