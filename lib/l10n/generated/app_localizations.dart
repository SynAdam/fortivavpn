import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_uk.dart';
import 'app_localizations_ur.dart';
import 'app_localizations_uz.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S? of(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fa'),
    Locale('fr'),
    Locale('hi'),
    Locale('id'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('ru'),
    Locale('tr'),
    Locale('uk'),
    Locale('ur'),
    Locale('uz'),
    Locale('vi'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Fortiva'**
  String get appTitle;

  /// No description provided for @statusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get statusDisconnected;

  /// No description provided for @statusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get statusConnecting;

  /// No description provided for @statusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get statusConnected;

  /// No description provided for @statusDisconnecting.
  ///
  /// In en, this message translates to:
  /// **'Terminating...'**
  String get statusDisconnecting;

  /// No description provided for @statusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get statusError;

  /// No description provided for @statusVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get statusVerifying;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Terminate'**
  String get disconnect;

  /// No description provided for @connectBtn.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectBtn;

  /// No description provided for @disconnectBtn.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnectBtn;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'PLEASE WAIT'**
  String get pleaseWait;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @selectServer.
  ///
  /// In en, this message translates to:
  /// **'Choose a location'**
  String get selectServer;

  /// No description provided for @serverLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get serverLocation;

  /// No description provided for @searchServers.
  ///
  /// In en, this message translates to:
  /// **'Search servers'**
  String get searchServers;

  /// No description provided for @locationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get locationsTitle;

  /// No description provided for @sortLatency.
  ///
  /// In en, this message translates to:
  /// **'Sort: Latency'**
  String get sortLatency;

  /// No description provided for @sortAZ.
  ///
  /// In en, this message translates to:
  /// **'Sort: A-Z'**
  String get sortAZ;

  /// No description provided for @sortedByLatency.
  ///
  /// In en, this message translates to:
  /// **'Sorted by latency'**
  String get sortedByLatency;

  /// No description provided for @sortedAZ.
  ///
  /// In en, this message translates to:
  /// **'Sorted A–Z'**
  String get sortedAZ;

  /// No description provided for @pingAll.
  ///
  /// In en, this message translates to:
  /// **'Test all'**
  String get pingAll;

  /// No description provided for @pinging.
  ///
  /// In en, this message translates to:
  /// **'Pinging...'**
  String get pinging;

  /// No description provided for @ping.
  ///
  /// In en, this message translates to:
  /// **'Ping'**
  String get ping;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @fastestServer.
  ///
  /// In en, this message translates to:
  /// **'Fastest'**
  String get fastestServer;

  /// No description provided for @timeout.
  ///
  /// In en, this message translates to:
  /// **'timeout'**
  String get timeout;

  /// No description provided for @tabCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get tabCommunity;

  /// No description provided for @tabFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get tabFree;

  /// No description provided for @tabPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get tabPremium;

  /// No description provided for @noCommunityServers.
  ///
  /// In en, this message translates to:
  /// **'No community servers yet'**
  String get noCommunityServers;

  /// No description provided for @communityLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this list'**
  String get communityLoadFailed;

  /// No description provided for @communityRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get communityRetry;

  /// No description provided for @officialTabExplainer.
  ///
  /// In en, this message translates to:
  /// **'Run by Fortiva and kept online by us. Shared by everyone who uses the app. Start here.'**
  String get officialTabExplainer;

  /// No description provided for @communityTabExplainer.
  ///
  /// In en, this message translates to:
  /// **'Extra connection options. Speed and availability vary.'**
  String get communityTabExplainer;

  /// No description provided for @noFreeServers.
  ///
  /// In en, this message translates to:
  /// **'No free servers yet'**
  String get noFreeServers;

  /// No description provided for @noPremiumServers.
  ///
  /// In en, this message translates to:
  /// **'No premium servers yet'**
  String get noPremiumServers;

  /// No description provided for @noResultsFor.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String noResultsFor(String query);

  /// No description provided for @proBadge.
  ///
  /// In en, this message translates to:
  /// **'PREMIUM'**
  String get proBadge;

  /// No description provided for @freeBadge.
  ///
  /// In en, this message translates to:
  /// **'FREE'**
  String get freeBadge;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @connection.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get connection;

  /// No description provided for @dnsConfiguration.
  ///
  /// In en, this message translates to:
  /// **'DNS'**
  String get dnsConfiguration;

  /// No description provided for @customDns.
  ///
  /// In en, this message translates to:
  /// **'Use your own DNS servers'**
  String get customDns;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// Settings item that opens the app's Google Play page so the user can rate it. Shown only when the app was installed from Google Play.
  ///
  /// In en, this message translates to:
  /// **'Rate Fortiva on Google Play'**
  String get rateOnGooglePlay;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @copyright.
  ///
  /// In en, this message translates to:
  /// **'© 2026 NimusAI'**
  String get copyright;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Interface language'**
  String get languageSubtitle;

  /// No description provided for @whatIsDns.
  ///
  /// In en, this message translates to:
  /// **'What is DNS?'**
  String get whatIsDns;

  /// No description provided for @dnsExplanation.
  ///
  /// In en, this message translates to:
  /// **'DNS turns website names into addresses your phone can reach. Using a different DNS can make sites load faster and can help reach sites your provider blocks.'**
  String get dnsExplanation;

  /// No description provided for @configuration.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get configuration;

  /// No description provided for @primaryDns.
  ///
  /// In en, this message translates to:
  /// **'Primary DNS'**
  String get primaryDns;

  /// No description provided for @primaryDnsHint.
  ///
  /// In en, this message translates to:
  /// **'Default: 1.1.1.1'**
  String get primaryDnsHint;

  /// No description provided for @secondaryDns.
  ///
  /// In en, this message translates to:
  /// **'Secondary DNS (optional)'**
  String get secondaryDns;

  /// No description provided for @secondaryDnsHint.
  ///
  /// In en, this message translates to:
  /// **'Default: 8.8.8.8'**
  String get secondaryDnsHint;

  /// No description provided for @saveConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveConfiguration;

  /// No description provided for @dnsSaved.
  ///
  /// In en, this message translates to:
  /// **'DNS settings saved'**
  String get dnsSaved;

  /// No description provided for @invalidPrimaryDns.
  ///
  /// In en, this message translates to:
  /// **'That primary DNS address is not valid'**
  String get invalidPrimaryDns;

  /// No description provided for @invalidSecondaryDns.
  ///
  /// In en, this message translates to:
  /// **'That secondary DNS address is not valid'**
  String get invalidSecondaryDns;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get statistics;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'OVERVIEW'**
  String get overview;

  /// No description provided for @connectionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get connectionsLabel;

  /// No description provided for @totalTime.
  ///
  /// In en, this message translates to:
  /// **'Time connected'**
  String get totalTime;

  /// No description provided for @dataUsage.
  ///
  /// In en, this message translates to:
  /// **'Data used'**
  String get dataUsage;

  /// No description provided for @uploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get uploaded;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated: {date}'**
  String lastUpdated(String date);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today at {time}'**
  String today(String time);

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(int count);

  /// No description provided for @noDataYet.
  ///
  /// In en, this message translates to:
  /// **'No session data'**
  String get noDataYet;

  /// No description provided for @connectToStart.
  ///
  /// In en, this message translates to:
  /// **'Connect to start tracking'**
  String get connectToStart;

  /// No description provided for @errorConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect'**
  String get errorConnectionFailed;

  /// No description provided for @errorServerNotWorking.
  ///
  /// In en, this message translates to:
  /// **'This location is not working. Try another one.'**
  String get errorServerNotWorking;

  /// No description provided for @errorServerNotForwarding.
  ///
  /// In en, this message translates to:
  /// **'This location is not passing traffic. Try another one.'**
  String get errorServerNotForwarding;

  /// No description provided for @errorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error'**
  String get errorUnexpected;

  /// No description provided for @errorDisconnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not disconnect'**
  String get errorDisconnectionFailed;

  /// No description provided for @errorFailedToRegister.
  ///
  /// In en, this message translates to:
  /// **'Failed to register device'**
  String get errorFailedToRegister;

  /// No description provided for @ipInformation.
  ///
  /// In en, this message translates to:
  /// **'Check my IP'**
  String get ipInformation;

  /// No description provided for @connectionAnalytics.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get connectionAnalytics;

  /// No description provided for @recentSessions.
  ///
  /// In en, this message translates to:
  /// **'Recent connections'**
  String get recentSessions;

  /// No description provided for @speedTest.
  ///
  /// In en, this message translates to:
  /// **'Speed test'**
  String get speedTest;

  /// No description provided for @startTest.
  ///
  /// In en, this message translates to:
  /// **'RUN DIAGNOSTICS'**
  String get startTest;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @testingViaVpn.
  ///
  /// In en, this message translates to:
  /// **'Testing via tunnel'**
  String get testingViaVpn;

  /// No description provided for @testingDirect.
  ///
  /// In en, this message translates to:
  /// **'Testing direct connection'**
  String get testingDirect;

  /// No description provided for @splitTunneling.
  ///
  /// In en, this message translates to:
  /// **'Route Configuration'**
  String get splitTunneling;

  /// No description provided for @splitTunnelingDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose which app categories bypass the tunnel. Excluded apps use your direct network connection.'**
  String get splitTunnelingDescription;

  /// No description provided for @enableSplitTunneling.
  ///
  /// In en, this message translates to:
  /// **'Enable Route Splitting'**
  String get enableSplitTunneling;

  /// No description provided for @splitTunnelActive.
  ///
  /// In en, this message translates to:
  /// **'Selected apps bypass tunnel'**
  String get splitTunnelActive;

  /// No description provided for @splitTunnelInactive.
  ///
  /// In en, this message translates to:
  /// **'All traffic routed through tunnel'**
  String get splitTunnelInactive;

  /// No description provided for @bypassVpnFor.
  ///
  /// In en, this message translates to:
  /// **'Bypass tunnel for'**
  String get bypassVpnFor;

  /// No description provided for @tools.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get tools;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @shareDiagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Share connection diagnostics'**
  String get shareDiagnosticsTitle;

  /// Under the Share connection diagnostics switch in Settings. It names what the switch sends, so it must change when the switch starts or stops sending something.
  ///
  /// In en, this message translates to:
  /// **'Sends connection reports, your carrier and country, phone model and Android version, the names of sites you reach through the VPN with a daily count, and whether you saw or tapped our messages, Premium offers and invite card. We never see the pages you open or what you send.'**
  String get shareDiagnosticsBody;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Compliance'**
  String get security;

  /// No description provided for @privacyDashboard.
  ///
  /// In en, this message translates to:
  /// **'Endpoint Analysis'**
  String get privacyDashboard;

  /// No description provided for @privacyDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'IP transparency & leak monitoring'**
  String get privacyDashboardSubtitle;

  /// No description provided for @connectionAnalyticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Session history & reports'**
  String get connectionAnalyticsSubtitle;

  /// No description provided for @speedTestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Throughput measurement'**
  String get speedTestSubtitle;

  /// No description provided for @splitTunnelingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure route policies'**
  String get splitTunnelingSubtitle;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Private access, wherever you are'**
  String get splashTagline;

  /// No description provided for @openSourceLicence.
  ///
  /// In en, this message translates to:
  /// **'Open source licence'**
  String get openSourceLicence;

  /// No description provided for @sourceOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'Open source licence'**
  String get sourceOfferTitle;

  /// No description provided for @sourceOfferBody.
  ///
  /// In en, this message translates to:
  /// **'Fortiva VPN is free software under the GNU General Public License v3. It builds on Xray-core and other open-source projects.\n\nYou are entitled to the complete source code for the version you have installed. To request it, email admin@fortivavpn.com with your app version. This offer is valid for three years from the date you received this version.'**
  String get sourceOfferBody;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove this device and your data'**
  String get deleteAccountSubtitle;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes your device registration, any linked Google account, the personal servers created for you, and your support chat messages. Your connection history on this phone is erased too.\n\nThis cannot be undone. You can start again at any time by reopening the app.'**
  String get deleteAccountConfirmBody;

  /// Shown when GET /api/v1/app/config sends deleted_data_retention_days.
  ///
  /// In en, this message translates to:
  /// **'Your account record is removed immediately. Copies in backups and anonymous server logs are cleared within {days, plural, one{{days} day} other{{days} days}}.'**
  String deleteAccountConfirmRetention(int days);

  /// Shown when the backend sends no retention period. Names no number.
  ///
  /// In en, this message translates to:
  /// **'Your account record is removed immediately. Copies in backups and anonymous server logs are cleared later, on the schedule in our privacy policy.'**
  String get deleteAccountConfirmRetentionNoDays;

  /// No description provided for @deleteAccountCancel.
  ///
  /// In en, this message translates to:
  /// **'Keep my account'**
  String get deleteAccountCancel;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountInProgress.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account'**
  String get deleteAccountInProgress;

  /// No description provided for @deleteAccountDone.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get deleteAccountDone;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete your account. Check your connection and try again.'**
  String get deleteAccountFailed;

  /// No description provided for @homeTapToConnect.
  ///
  /// In en, this message translates to:
  /// **'Tap to connect'**
  String get homeTapToConnect;

  /// No description provided for @homeChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking connection'**
  String get homeChecking;

  /// No description provided for @homePreparing.
  ///
  /// In en, this message translates to:
  /// **'Setting up your server'**
  String get homePreparing;

  /// No description provided for @homeDisconnecting.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting'**
  String get homeDisconnecting;

  /// No description provided for @homeFindingPath.
  ///
  /// In en, this message translates to:
  /// **'Finding a path'**
  String get homeFindingPath;

  /// No description provided for @diagCheckingInternet.
  ///
  /// In en, this message translates to:
  /// **'Checking your internet'**
  String get diagCheckingInternet;

  /// No description provided for @diagInternationalCut.
  ///
  /// In en, this message translates to:
  /// **'International internet is cut on this network'**
  String get diagInternationalCut;

  /// No description provided for @diagPathRow.
  ///
  /// In en, this message translates to:
  /// **'{city}, path {n}'**
  String diagPathRow(String city, int n);

  /// No description provided for @diagOpen.
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get diagOpen;

  /// No description provided for @diagBlocked.
  ///
  /// In en, this message translates to:
  /// **'blocked'**
  String get diagBlocked;

  /// No description provided for @diagSkipped.
  ///
  /// In en, this message translates to:
  /// **'skipped today'**
  String get diagSkipped;

  /// No description provided for @diagConnectingThrough.
  ///
  /// In en, this message translates to:
  /// **'Connecting through {city}'**
  String diagConnectingThrough(String city);

  /// No description provided for @diagVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying traffic'**
  String get diagVerifying;

  /// No description provided for @diagNoInternet.
  ///
  /// In en, this message translates to:
  /// **'Your phone has no internet right now.'**
  String get diagNoInternet;

  /// No description provided for @diagCutOff.
  ///
  /// In en, this message translates to:
  /// **'Your network cannot reach the international internet right now. Tap to try again.'**
  String get diagCutOff;

  /// No description provided for @diagNothingOpen.
  ///
  /// In en, this message translates to:
  /// **'Every path is blocked right now. Tap to try again.'**
  String get diagNothingOpen;

  /// No description provided for @homeTryingAgain.
  ///
  /// In en, this message translates to:
  /// **'Every path is blocked right now. Trying again soon.'**
  String get homeTryingAgain;

  /// No description provided for @homeCutOffTryingAgain.
  ///
  /// In en, this message translates to:
  /// **'Your network cannot reach the international internet right now. Trying again soon.'**
  String get homeCutOffTryingAgain;

  /// No description provided for @homeOfflineTryingAgain.
  ///
  /// In en, this message translates to:
  /// **'Your phone has no internet right now. Trying again soon.'**
  String get homeOfflineTryingAgain;

  /// No description provided for @diagPathFailed.
  ///
  /// In en, this message translates to:
  /// **'The path was open but the tunnel did not come up. Tap to try again.'**
  String get diagPathFailed;

  /// No description provided for @openVpnSettings.
  ///
  /// In en, this message translates to:
  /// **'Open VPN settings'**
  String get openVpnSettings;

  /// No description provided for @yourServer.
  ///
  /// In en, this message translates to:
  /// **'YOUR SERVER'**
  String get yourServer;

  /// No description provided for @yourServerCaption.
  ///
  /// In en, this message translates to:
  /// **'Yours alone. No one else connects through it.'**
  String get yourServerCaption;

  /// No description provided for @ourServer.
  ///
  /// In en, this message translates to:
  /// **'OUR SERVER'**
  String get ourServer;

  /// No description provided for @ourServerCaption.
  ///
  /// In en, this message translates to:
  /// **'Run by Fortiva and shared with everyone. Used until your own server is ready.'**
  String get ourServerCaption;

  /// No description provided for @communityServer.
  ///
  /// In en, this message translates to:
  /// **'COMMUNITY SERVER'**
  String get communityServer;

  /// No description provided for @communityServerCaption.
  ///
  /// In en, this message translates to:
  /// **'An extra connection option. It may stop working at any time.'**
  String get communityServerCaption;

  /// Title of a community link that names no country; n is its position in the list, already in the phone's digits.
  ///
  /// In en, this message translates to:
  /// **'Community server {n}'**
  String communityServerNumber(String n);

  /// No description provided for @myServersTitle.
  ///
  /// In en, this message translates to:
  /// **'Your servers'**
  String get myServersTitle;

  /// No description provided for @myServersExplainer.
  ///
  /// In en, this message translates to:
  /// **'Every Fortiva device is given its own server in each location, with credentials that belong to this install alone. No account is needed.'**
  String get myServersExplainer;

  /// No description provided for @myServersInUse.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get myServersInUse;

  /// No description provided for @myServersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No servers assigned yet'**
  String get myServersEmpty;

  /// No description provided for @myServersRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get myServersRetry;

  /// No description provided for @myServersBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'You have used today\'s data'**
  String get myServersBlockedTitle;

  /// No description provided for @myServersBlockedWait.
  ///
  /// In en, this message translates to:
  /// **'Your allowance resets automatically. Check back soon.'**
  String get myServersBlockedWait;

  /// No description provided for @myServersMoved.
  ///
  /// In en, this message translates to:
  /// **'Now using {place}'**
  String myServersMoved(String place);

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// No description provided for @quotaUsedToday.
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit} used today'**
  String quotaUsedToday(String used, String limit);

  /// No description provided for @quotaUsedUp.
  ///
  /// In en, this message translates to:
  /// **'Daily data used up'**
  String get quotaUsedUp;

  /// No description provided for @quotaUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited data'**
  String get quotaUnlimited;

  /// No description provided for @quotaDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily data'**
  String get quotaDaily;

  /// No description provided for @quotaLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Daily limit reached'**
  String get quotaLimitReached;

  /// No description provided for @quotaLeftOf.
  ///
  /// In en, this message translates to:
  /// **'{left} of {limit} left'**
  String quotaLeftOf(String left, String limit);

  /// No description provided for @quotaResetsShortly.
  ///
  /// In en, this message translates to:
  /// **'Resets shortly'**
  String get quotaResetsShortly;

  /// No description provided for @quotaResetsInHours.
  ///
  /// In en, this message translates to:
  /// **'Resets in {hours}h'**
  String quotaResetsInHours(int hours);

  /// No description provided for @quotaResetsInMinutes.
  ///
  /// In en, this message translates to:
  /// **'Resets in {minutes}m'**
  String quotaResetsInMinutes(int minutes);

  /// No description provided for @myServersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The servers provisioned for this device'**
  String get myServersSubtitle;

  /// No description provided for @sharedServersTitle.
  ///
  /// In en, this message translates to:
  /// **'Shared servers'**
  String get sharedServersTitle;

  /// No description provided for @sharedServersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Public locations, used as a fallback'**
  String get sharedServersSubtitle;

  /// No description provided for @tabOfficial.
  ///
  /// In en, this message translates to:
  /// **'Our servers'**
  String get tabOfficial;

  /// No description provided for @noOfficialServers.
  ///
  /// In en, this message translates to:
  /// **'No Fortiva servers right now'**
  String get noOfficialServers;

  /// No description provided for @inviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get inviteTitle;

  /// No description provided for @inviteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Earn extra daily data'**
  String get inviteSubtitle;

  /// No description provided for @inviteYourCode.
  ///
  /// In en, this message translates to:
  /// **'Your invite code'**
  String get inviteYourCode;

  /// No description provided for @inviteShareAction.
  ///
  /// In en, this message translates to:
  /// **'Share invite'**
  String get inviteShareAction;

  /// No description provided for @inviteCopyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get inviteCopyAction;

  /// No description provided for @inviteCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get inviteCodeCopied;

  /// No description provided for @inviteShareMessage.
  ///
  /// In en, this message translates to:
  /// **'A free VPN that works well for me: Fortiva. No sign-up needed.\nInstall it from this link:\n{url}\nMy invite code: {code}'**
  String inviteShareMessage(String code, String url);

  /// No description provided for @inviteHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get inviteHowItWorks;

  /// Shown when the referral status sends bonus_per_referral_bytes and confirm_active_days.
  ///
  /// In en, this message translates to:
  /// **'Share your code. When someone installs the app, enters it, and uses the VPN on {days, plural, one{{days} day} other{{days} different days}}, you get {amount} added to your daily data. It stays on your account.'**
  String inviteHowItWorksBody(String amount, int days);

  /// Shown when the referral status sends confirm_active_days but no bonus_per_referral_bytes.
  ///
  /// In en, this message translates to:
  /// **'Share your code. When someone installs the app, enters it, and uses the VPN on {days, plural, one{{days} day} other{{days} different days}}, you get more data every day. It stays on your account.'**
  String inviteHowItWorksBodyNoAmount(int days);

  /// Shown when the referral status sends bonus_per_referral_bytes but no confirm_active_days.
  ///
  /// In en, this message translates to:
  /// **'Share your code. When someone installs the app, enters it, and uses the VPN for a while, you get {amount} added to your daily data. It stays on your account.'**
  String inviteHowItWorksBodyNoDays(String amount);

  /// No description provided for @inviteHowItWorksBodyNoAmountNoDays.
  ///
  /// In en, this message translates to:
  /// **'Share your code. When someone installs the app, enters it, and uses the VPN for a while, you get more data every day. It stays on your account.'**
  String get inviteHowItWorksBodyNoAmountNoDays;

  /// No description provided for @inviteHowItWorksCap.
  ///
  /// In en, this message translates to:
  /// **'You can earn up to {max} a day from invites.'**
  String inviteHowItWorksCap(String max);

  /// No description provided for @inviteStatInvited.
  ///
  /// In en, this message translates to:
  /// **'Invited'**
  String get inviteStatInvited;

  /// No description provided for @inviteStatEarning.
  ///
  /// In en, this message translates to:
  /// **'Qualified'**
  String get inviteStatEarning;

  /// No description provided for @inviteStatBonus.
  ///
  /// In en, this message translates to:
  /// **'Bonus data'**
  String get inviteStatBonus;

  /// No description provided for @inviteBonusPerDay.
  ///
  /// In en, this message translates to:
  /// **'+{amount} every day'**
  String inviteBonusPerDay(String amount);

  /// No description provided for @inviteNoBonusYet.
  ///
  /// In en, this message translates to:
  /// **'No bonus yet'**
  String get inviteNoBonusYet;

  /// No description provided for @invitePendingNote.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{} =1{1 invite has not qualified yet} other{{count} invites have not qualified yet}}'**
  String invitePendingNote(int count);

  /// No description provided for @inviteJoinedWith.
  ///
  /// In en, this message translates to:
  /// **'You joined with code {code}'**
  String inviteJoinedWith(String code);

  /// No description provided for @inviteLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your invite code'**
  String get inviteLoadFailed;

  /// No description provided for @inviteRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get inviteRetry;

  /// No description provided for @inviteHaveCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Have an invite code?'**
  String get inviteHaveCodeTitle;

  /// Shown when the referral status sends claim_window_hours.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, one{Enter it in your first hour} other{Enter it in your first {hours} hours}}'**
  String inviteHaveCodeSubtitle(int hours);

  /// No description provided for @inviteHaveCodeSubtitleNoHours.
  ///
  /// In en, this message translates to:
  /// **'Enter it soon after installing'**
  String get inviteHaveCodeSubtitleNoHours;

  /// No description provided for @inviteEnterCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteEnterCodeHint;

  /// No description provided for @inviteApplyAction.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get inviteApplyAction;

  /// No description provided for @inviteNotNowAction.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get inviteNotNowAction;

  /// Shown when the referral status sends confirm_active_days.
  ///
  /// In en, this message translates to:
  /// **'Invite accepted. Your friend earns bonus data once you have used the VPN on {days, plural, one{{days} day} other{{days} different days}}.'**
  String inviteClaimAccepted(int days);

  /// No description provided for @inviteClaimAcceptedNoDays.
  ///
  /// In en, this message translates to:
  /// **'Invite accepted. Your friend earns bonus data once you have used the VPN for a while.'**
  String get inviteClaimAcceptedNoDays;

  /// No description provided for @inviteClaimAlready.
  ///
  /// In en, this message translates to:
  /// **'This device has already used an invite code'**
  String get inviteClaimAlready;

  /// No description provided for @inviteClaimRejected.
  ///
  /// In en, this message translates to:
  /// **'That code did not work. Check it and try again'**
  String get inviteClaimRejected;

  /// No description provided for @inviteClaimNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Try again'**
  String get inviteClaimNetwork;

  /// The title of the invite card on the home screen, shown after good connection days.
  ///
  /// In en, this message translates to:
  /// **'Is Fortiva working well for you? Send it to a friend'**
  String get inviteCardTitle;

  /// No description provided for @inviteCardBody.
  ///
  /// In en, this message translates to:
  /// **'Send your friend the install link so they can connect for free too.'**
  String get inviteCardBody;

  /// The invite card's reward line, shown when the backend sends reward_premium_days.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{When your friend starts using Fortiva, you get {days} day of Premium.} other{When your friend starts using Fortiva, you get {days} days of Premium.}}'**
  String inviteCardReward(int days);

  /// The invite card's reward line when the backend says the device earns but sends no number.
  ///
  /// In en, this message translates to:
  /// **'When your friend starts using Fortiva, you get Premium as a gift.'**
  String get inviteCardRewardNoAmount;

  /// No description provided for @inviteSendTelegram.
  ///
  /// In en, this message translates to:
  /// **'Telegram'**
  String get inviteSendTelegram;

  /// No description provided for @inviteSendWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get inviteSendWhatsApp;

  /// No description provided for @inviteCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get inviteCopyLink;

  /// No description provided for @inviteOtherApps.
  ///
  /// In en, this message translates to:
  /// **'Other apps'**
  String get inviteOtherApps;

  /// Shown after Copy link on Android 12 and older. Android 13 and later show their own notice.
  ///
  /// In en, this message translates to:
  /// **'Invite message copied'**
  String get inviteLinkCopied;

  /// No description provided for @invitePasteBody.
  ///
  /// In en, this message translates to:
  /// **'Copy the code from your friend\'s message and paste it here.'**
  String get invitePasteBody;

  /// Reads the clipboard only when tapped. The website's invite page names this label, so keep both the same.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get invitePasteAction;

  /// No description provided for @inviteErrorTooLate.
  ///
  /// In en, this message translates to:
  /// **'The time to enter an invite code on this phone has passed.'**
  String get inviteErrorTooLate;

  /// No description provided for @inviteErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'We could not find this code. Copy it again from your friend\'s message.'**
  String get inviteErrorUnknown;

  /// No description provided for @inviteErrorOwnCode.
  ///
  /// In en, this message translates to:
  /// **'This is your own code. Enter your friend\'s code.'**
  String get inviteErrorOwnCode;

  /// No description provided for @inviteErrorMutual.
  ///
  /// In en, this message translates to:
  /// **'You and your friend cannot invite each other.'**
  String get inviteErrorMutual;

  /// No description provided for @inviteHowItWorksPremium.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{Each friend who starts using Fortiva also gives you {days} day of Premium.} other{Each friend who starts using Fortiva also gives you {days} days of Premium.}}'**
  String inviteHowItWorksPremium(int days);

  /// No description provided for @inviteHowItWorksPremiumCap.
  ///
  /// In en, this message translates to:
  /// **'{max, plural, one{You can earn up to {max} day of Premium from invites.} other{You can earn up to {max} days of Premium from invites.}}'**
  String inviteHowItWorksPremiumCap(int max);

  /// How Premium was paid: days earned by inviting friends (source referral).
  ///
  /// In en, this message translates to:
  /// **'From your invites'**
  String get premiumSourceInvite;

  /// No description provided for @quotaBonusIncluded.
  ///
  /// In en, this message translates to:
  /// **'includes {amount} invite bonus'**
  String quotaBonusIncluded(String amount);

  /// No description provided for @updateTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateTitle;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequiredTitle;

  /// No description provided for @updateBody.
  ///
  /// In en, this message translates to:
  /// **'Fortiva {version} is out. Update for the newest fixes.'**
  String updateBody(String version);

  /// No description provided for @updateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'This version is no longer supported. Update to keep using Fortiva.'**
  String get updateRequiredBody;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateNow;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateFromPlay.
  ///
  /// In en, this message translates to:
  /// **'Google Play'**
  String get updateFromPlay;

  /// No description provided for @updateFromTelegram.
  ///
  /// In en, this message translates to:
  /// **'Telegram channel'**
  String get updateFromTelegram;

  /// No description provided for @updateConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get updateConnect;

  /// No description provided for @updateConnectHint.
  ///
  /// In en, this message translates to:
  /// **'If Google Play or Telegram does not open, tap Connect first.'**
  String get updateConnectHint;

  /// No description provided for @updateConnected.
  ///
  /// In en, this message translates to:
  /// **'You are connected. Download the update now.'**
  String get updateConnected;

  /// No description provided for @updateReconnect.
  ///
  /// In en, this message translates to:
  /// **'Not working? Reconnect'**
  String get updateReconnect;

  /// No description provided for @updateDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get updateDisconnect;

  /// No description provided for @updateDisconnectHint.
  ///
  /// In en, this message translates to:
  /// **'Tap Disconnect to download the update over your normal internet.'**
  String get updateDisconnectHint;

  /// No description provided for @updateNotCarrying.
  ///
  /// In en, this message translates to:
  /// **'You are connected, but nothing is getting through. Try Reconnect, or tap Disconnect to use your normal internet.'**
  String get updateNotCarrying;

  /// No description provided for @diagVerdictNoInternet.
  ///
  /// In en, this message translates to:
  /// **'Your phone has no internet connection. Fortiva cannot connect until that is back.'**
  String get diagVerdictNoInternet;

  /// No description provided for @diagVerdictCutOff.
  ///
  /// In en, this message translates to:
  /// **'Your network cannot reach the international internet right now. Try again in a few minutes.'**
  String get diagVerdictCutOff;

  /// No description provided for @diagVerdictNeedsPermission.
  ///
  /// In en, this message translates to:
  /// **'Fortiva does not have permission to run a VPN, or another VPN app is set to always on.'**
  String get diagVerdictNeedsPermission;

  /// No description provided for @diagVerdictServerUnreachable.
  ///
  /// In en, this message translates to:
  /// **'This server cannot be reached from your network. It is either blocked here or down.'**
  String get diagVerdictServerUnreachable;

  /// No description provided for @diagVerdictBlockedTls.
  ///
  /// In en, this message translates to:
  /// **'The connection to this server is being cut while it is being set up. That is what filtering looks like.'**
  String get diagVerdictBlockedTls;

  /// No description provided for @diagVerdictThrottled.
  ///
  /// In en, this message translates to:
  /// **'The server answered every check and the tunnel still carried nothing. The connection is being slowed.'**
  String get diagVerdictThrottled;

  /// No description provided for @diagCheckInternet.
  ///
  /// In en, this message translates to:
  /// **'Check your internet'**
  String get diagCheckInternet;

  /// No description provided for @diagTryServer.
  ///
  /// In en, this message translates to:
  /// **'Start a new search on {server}'**
  String diagTryServer(String server);

  /// No description provided for @diagTryAnotherServer.
  ///
  /// In en, this message translates to:
  /// **'Try another server'**
  String get diagTryAnotherServer;

  /// No description provided for @diagDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get diagDetails;

  /// No description provided for @diagDetailsHide.
  ///
  /// In en, this message translates to:
  /// **'Hide details'**
  String get diagDetailsHide;

  /// Shown while connected when the phone has Private DNS set to a hostname and name lookups fail through it. Android keeps using that DNS server even with a VPN on, and some providers in Iran do not answer phones that reach them from abroad.
  ///
  /// In en, this message translates to:
  /// **'Private DNS is on ({host}), so some sites may not open. Turn Private DNS off in your phone\'s settings.'**
  String privateDnsWarning(String host);

  /// No description provided for @openNetworkSettings.
  ///
  /// In en, this message translates to:
  /// **'Open network settings'**
  String get openNetworkSettings;

  /// No description provided for @testPointStatus.
  ///
  /// In en, this message translates to:
  /// **'Test point · last check {time} · {open} of {total} doors open'**
  String testPointStatus(String time, int open, int total);

  /// Tooltip of the bell on the home screen that opens the messages from the Fortiva team.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messagesTooltip;

  /// Title of the screen that lists the messages from the Fortiva team.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get inboxTitle;

  /// Shown on the messages screen when there is no message.
  ///
  /// In en, this message translates to:
  /// **'No messages right now.'**
  String get inboxEmpty;

  /// Closes a message from the Fortiva team that popped up.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get messageClose;

  /// Title of the in-app support chat screen. Also the name the support assistant uses for the chat.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get supportTitle;

  /// Tooltip and screen reader label of the round chatbot button on the home screen that opens the support chat.
  ///
  /// In en, this message translates to:
  /// **'Chat with support'**
  String get supportTooltip;

  /// Line under a failed connection on the home screen that opens the support chat.
  ///
  /// In en, this message translates to:
  /// **'Ask support'**
  String get supportAskAction;

  /// Subtitle of Contact Us in Settings when it opens the support chat.
  ///
  /// In en, this message translates to:
  /// **'Chat with us in the app'**
  String get supportContactSubtitle;

  /// Short line at the top of the support chat saying the answers are written automatically.
  ///
  /// In en, this message translates to:
  /// **'Answers are written automatically and can be wrong.'**
  String get supportAutomaticNotice;

  /// Line at the top of the support chat while automatic answers are switched off and every message goes to people on the Fortiva team.
  ///
  /// In en, this message translates to:
  /// **'Automatic answers are off for now. Your messages go to our team.'**
  String get supportStaffNotice;

  /// Hint in the support chat's input box.
  ///
  /// In en, this message translates to:
  /// **'Write your question'**
  String get supportInputHint;

  /// Hint in the support chat's input box when the message will go to people on the Fortiva team.
  ///
  /// In en, this message translates to:
  /// **'Write to our team'**
  String get supportInputHintTeam;

  /// Tooltip of the send button in the support chat.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get supportSend;

  /// How many questions the user can still ask the assistant today.
  ///
  /// In en, this message translates to:
  /// **'{remaining} of {limit} questions left today'**
  String supportQuotaLeft(int remaining, int limit);

  /// When the user can ask the assistant again. {time} is a duration such as '5 h 20 min'.
  ///
  /// In en, this message translates to:
  /// **'You can ask again in {time}.'**
  String supportWaitIn(String time);

  /// A duration of hours and minutes, short form.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String supportDurationHours(int hours, int minutes);

  /// A duration of minutes, short form.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String supportDurationMinutes(int minutes);

  /// Starts a new conversation in the support chat; also the mark where a new conversation starts.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get supportNewConversation;

  /// Under a message that is being sent.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get supportSending;

  /// Under a message that could not be sent yet. Tapping it tries again.
  ///
  /// In en, this message translates to:
  /// **'Not sent. Tap to try again.'**
  String get supportNotSent;

  /// Tooltip of the thumbs up under an answer.
  ///
  /// In en, this message translates to:
  /// **'Helpful'**
  String get supportRateUp;

  /// Tooltip of the thumbs down under an answer.
  ///
  /// In en, this message translates to:
  /// **'Not helpful'**
  String get supportRateDown;

  /// Shown after the user marks an answer as not helpful.
  ///
  /// In en, this message translates to:
  /// **'Thanks. Our team will look at this answer.'**
  String get supportRatedDown;

  /// Label above a reply written by a person on the Fortiva team.
  ///
  /// In en, this message translates to:
  /// **'Fortiva team'**
  String get supportTeamLabel;

  /// Shown when the support chat is switched off.
  ///
  /// In en, this message translates to:
  /// **'Chat is not available right now.'**
  String get supportUnavailable;

  /// Button that opens the Fortiva Telegram channel when the chat is switched off.
  ///
  /// In en, this message translates to:
  /// **'Message us on Telegram'**
  String get supportOpenTelegram;

  /// Shown when a message could not be sent for a reason the app cannot name.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get supportGenericError;

  /// The message is longer than the limit.
  ///
  /// In en, this message translates to:
  /// **'Your message is too long. Keep it under {max} characters.'**
  String supportCodeTooLong(int max);

  /// The message had no text.
  ///
  /// In en, this message translates to:
  /// **'Your message is empty.'**
  String get supportCodeEmpty;

  /// The user tried to ask while the previous question is still being answered.
  ///
  /// In en, this message translates to:
  /// **'Please wait for the answer to your last question.'**
  String get supportCodeWaitReply;

  /// The user sent too many messages in a short time.
  ///
  /// In en, this message translates to:
  /// **'You are sending messages too quickly. Please wait a little.'**
  String get supportCodeSlowDown;

  /// The user has asked all of today's questions.
  ///
  /// In en, this message translates to:
  /// **'You have used all of today\'s questions.'**
  String get supportCodeQuotaDay;

  /// Automatic answers are paused for a while.
  ///
  /// In en, this message translates to:
  /// **'Automatic answers are paused for now.'**
  String get supportCodePaused;

  /// Too many people are asking at once.
  ///
  /// In en, this message translates to:
  /// **'Our assistant is busy right now. Please try again in a few minutes.'**
  String get supportCodeBusy;

  /// Friendly reply when the user only said hello or thanks.
  ///
  /// In en, this message translates to:
  /// **'Hi! How can I help you with Fortiva?'**
  String get supportCodeGreeting;

  /// The message could not be read as a question.
  ///
  /// In en, this message translates to:
  /// **'Sorry, I did not understand that. Please write your question again.'**
  String get supportCodeGibberish;

  /// Personal details or links were removed from the user's message before it was answered.
  ///
  /// In en, this message translates to:
  /// **'We removed personal details and links from your message.'**
  String get supportCodeRedacted;

  /// The message was only personal details or links, so nothing was left to send.
  ///
  /// In en, this message translates to:
  /// **'Your message only had personal details or links, so it was not sent. Please describe the problem in words.'**
  String get supportCodeRedactedEmpty;

  /// The question is not about using Fortiva.
  ///
  /// In en, this message translates to:
  /// **'I can only help with questions about using Fortiva.'**
  String get supportCodeOffTopic;

  /// The message was rude.
  ///
  /// In en, this message translates to:
  /// **'Let\'s keep it respectful. I am here to help you with Fortiva.'**
  String get supportCodeAbuse;

  /// The assistant could not answer this time.
  ///
  /// In en, this message translates to:
  /// **'The assistant could not answer this time. Please try again in a little while.'**
  String get supportCodeAiUnavailable;

  /// The message went to people on the Fortiva team.
  ///
  /// In en, this message translates to:
  /// **'Sent to our team. Their reply will show up here.'**
  String get supportCodeToStaff;

  /// The question was passed to people on the Fortiva team.
  ///
  /// In en, this message translates to:
  /// **'We passed your question to our team. Their reply will show up here.'**
  String get supportCodeTicketOpened;

  /// Under a message that waited on the phone for a day without reaching us. It will not be sent.
  ///
  /// In en, this message translates to:
  /// **'This message could not be sent. Write it again if you still need help.'**
  String get supportCodeNotSent;

  /// Under the title of the support chat: who answers there. Short.
  ///
  /// In en, this message translates to:
  /// **'AI assistant'**
  String get supportAssistantSubtitle;

  /// Shown with animated dots in the first seconds after the user asked the assistant a question.
  ///
  /// In en, this message translates to:
  /// **'Reading your question'**
  String get supportThinkingReading;

  /// Shown with animated dots a few seconds after the question, while the answer is being looked for.
  ///
  /// In en, this message translates to:
  /// **'Looking for the answer'**
  String get supportThinkingSearching;

  /// Shown with animated dots once the assistant has been working on the answer for a while.
  ///
  /// In en, this message translates to:
  /// **'Writing the answer'**
  String get supportThinkingWriting;

  /// Shown with animated dots when the answer takes unusually long.
  ///
  /// In en, this message translates to:
  /// **'Still on it, thanks for waiting'**
  String get supportThinkingStill;

  /// Suggested question on the empty support chat. Tapping it asks it. The user speaks.
  ///
  /// In en, this message translates to:
  /// **'I can\'t connect'**
  String get supportSuggestConnect;

  /// Suggested question on the empty support chat, about how much data the user has left today. The user speaks.
  ///
  /// In en, this message translates to:
  /// **'How much data do I have today?'**
  String get supportSuggestData;

  /// Suggested question on the empty support chat. The user speaks.
  ///
  /// In en, this message translates to:
  /// **'My connection is slow'**
  String get supportSuggestSlow;

  /// Above the input box once people on the Fortiva team took over the conversation and the user is writing to them.
  ///
  /// In en, this message translates to:
  /// **'This conversation is now with our team.'**
  String get supportWithTeam;

  /// Hint in the disabled input box while the assistant is too busy to take questions.
  ///
  /// In en, this message translates to:
  /// **'Try again in a few minutes.'**
  String get supportTryAgainSoon;

  /// A duration of a whole number of hours, short form, in the same style as supportDurationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String supportDurationWholeHours(int hours);

  /// Read by a screen reader on the home screen chat button when a reply in the support chat has not been seen yet. Short.
  ///
  /// In en, this message translates to:
  /// **'New reply'**
  String get supportUnreadReply;

  /// Name of the paid tier that lifts the daily data limit. Title of the Premium screen and of its tile in Settings.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premiumTitle;

  /// No description provided for @premiumTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlimited data with no daily limit'**
  String get premiumTileSubtitle;

  /// No description provided for @premiumTileActive.
  ///
  /// In en, this message translates to:
  /// **'Premium is on'**
  String get premiumTileActive;

  /// Short action on the quota card and the spent-allowance notice that opens the Premium screen.
  ///
  /// In en, this message translates to:
  /// **'Get unlimited'**
  String get premiumGetUnlimited;

  /// No description provided for @premiumHeadline.
  ///
  /// In en, this message translates to:
  /// **'Get unlimited data'**
  String get premiumHeadline;

  /// No description provided for @premiumPitch.
  ///
  /// In en, this message translates to:
  /// **'Premium lifts the daily limit, so you can use as much data as you like until it ends.'**
  String get premiumPitch;

  /// No description provided for @premiumActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium is on'**
  String get premiumActiveTitle;

  /// Premium status line. {date} is the end date, already formatted for the language.
  ///
  /// In en, this message translates to:
  /// **'Unlimited data until {date}'**
  String premiumActiveUntil(String date);

  /// Premium status line when the backend sent no end date. Names no date.
  ///
  /// In en, this message translates to:
  /// **'Unlimited data'**
  String get premiumActiveNoDate;

  /// Shown under the status of a Google Play subscription that renews by itself.
  ///
  /// In en, this message translates to:
  /// **'Renews automatically through Google Play'**
  String get premiumRenews;

  /// How Premium was paid: an access key typed into the app.
  ///
  /// In en, this message translates to:
  /// **'Activated with a key'**
  String get premiumSourceKey;

  /// No description provided for @premiumSourceCrypto.
  ///
  /// In en, this message translates to:
  /// **'Paid with crypto'**
  String get premiumSourceCrypto;

  /// No description provided for @premiumSourceStars.
  ///
  /// In en, this message translates to:
  /// **'Paid with Telegram Stars'**
  String get premiumSourceStars;

  /// No description provided for @premiumSourceGooglePlay.
  ///
  /// In en, this message translates to:
  /// **'Paid through Google Play'**
  String get premiumSourceGooglePlay;

  /// How Premium was paid: the team gave it by hand.
  ///
  /// In en, this message translates to:
  /// **'A gift from the Fortiva team'**
  String get premiumSourceManual;

  /// No description provided for @premiumYourKey.
  ///
  /// In en, this message translates to:
  /// **'Your key'**
  String get premiumYourKey;

  /// No description provided for @premiumKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Keep this key safe. Enter it on another phone to move Premium there.'**
  String get premiumKeyHint;

  /// Shown under the access key when the backend sends move_limit and move_window_days.
  ///
  /// In en, this message translates to:
  /// **'A key can move to another phone {count, plural, =1{once} other{up to {count} times}} in {days, plural, one{{days} day} other{{days} days}}.'**
  String premiumKeyMoves(int count, int days);

  /// Shown under the access key when the backend sends no move limit. Names no number.
  ///
  /// In en, this message translates to:
  /// **'A key can move to another phone only a limited number of times.'**
  String get premiumKeyMovesNoNumber;

  /// No description provided for @premiumCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get premiumCopy;

  /// No description provided for @premiumCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get premiumCopied;

  /// No description provided for @premiumChoosePlan.
  ///
  /// In en, this message translates to:
  /// **'Choose a plan'**
  String get premiumChoosePlan;

  /// Title of a plan. {days} is the plan length the backend sends.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{{days} day of unlimited data} other{{days} days of unlimited data}}'**
  String premiumPlanDays(int days);

  /// Title of a plan when the backend sent no length. Names no number.
  ///
  /// In en, this message translates to:
  /// **'Unlimited data'**
  String get premiumPlanNoDays;

  /// No description provided for @premiumBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get premiumBuy;

  /// No description provided for @premiumPlayUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Google Play is not available right now. Try again later.'**
  String get premiumPlayUnavailable;

  /// No description provided for @premiumPlayPending.
  ///
  /// In en, this message translates to:
  /// **'Your payment is pending in Google Play. Premium starts as soon as it goes through.'**
  String get premiumPlayPending;

  /// No description provided for @premiumPlayConfirming.
  ///
  /// In en, this message translates to:
  /// **'Confirming your purchase...'**
  String get premiumPlayConfirming;

  /// Google Play took the money but our server could not confirm it yet. The app keeps the purchase and sends it again by itself.
  ///
  /// In en, this message translates to:
  /// **'Your payment went through, but we could not confirm it yet. We will keep trying, so you do not need to pay again.'**
  String get premiumPlayRetrying;

  /// No description provided for @premiumPlayRefused.
  ///
  /// In en, this message translates to:
  /// **'We could not confirm this purchase. If you were charged, contact support.'**
  String get premiumPlayRefused;

  /// No description provided for @premiumPlayNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Premium is not available on this phone right now. If you were charged, contact support.'**
  String get premiumPlayNotAvailable;

  /// No description provided for @premiumNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Premium is not available on this phone right now.'**
  String get premiumNotAvailable;

  /// No description provided for @premiumPlayFailed.
  ///
  /// In en, this message translates to:
  /// **'The purchase did not go through. Try again.'**
  String get premiumPlayFailed;

  /// No description provided for @premiumNowOn.
  ///
  /// In en, this message translates to:
  /// **'Premium is on. Enjoy unlimited data.'**
  String get premiumNowOn;

  /// No description provided for @premiumRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get premiumRestore;

  /// No description provided for @premiumRestoreDone.
  ///
  /// In en, this message translates to:
  /// **'Your purchase is restored on this phone.'**
  String get premiumRestoreDone;

  /// No description provided for @premiumRestoreNone.
  ///
  /// In en, this message translates to:
  /// **'This Google account has no purchase to restore.'**
  String get premiumRestoreNone;

  /// No description provided for @premiumRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore your purchase. Try again later.'**
  String get premiumRestoreFailed;

  /// Under a Google Play plan's price: how often Play bills and that it renews until cancelled. {count} is the number of days in Play's own billing period, never a number from the app.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Billed every day. Renews automatically until you cancel.} other{Billed every {count} days. Renews automatically until you cancel.}}'**
  String premiumRenewsDays(int count);

  /// As premiumRenewsDays, for a billing period in weeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Billed every week. Renews automatically until you cancel.} other{Billed every {count} weeks. Renews automatically until you cancel.}}'**
  String premiumRenewsWeeks(int count);

  /// As premiumRenewsDays, for a billing period in months.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Billed every month. Renews automatically until you cancel.} other{Billed every {count} months. Renews automatically until you cancel.}}'**
  String premiumRenewsMonths(int count);

  /// As premiumRenewsDays, for a billing period in years.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Billed every year. Renews automatically until you cancel.} other{Billed every {count} years. Renews automatically until you cancel.}}'**
  String premiumRenewsYears(int count);

  /// Under a Google Play plan's price when Play gave no billing period that could be read. Names no number.
  ///
  /// In en, this message translates to:
  /// **'Renews automatically until you cancel.'**
  String get premiumRenewsNoPeriod;

  /// Under the Google Play plans: how to cancel, and what happens after. Names no number.
  ///
  /// In en, this message translates to:
  /// **'You can cancel anytime in Google Play. Premium stays on until the end of the time you paid for.'**
  String get premiumPlayCancelNote;

  /// Button that opens Google Play's page for managing or cancelling the subscription.
  ///
  /// In en, this message translates to:
  /// **'Manage or cancel subscription'**
  String get premiumManageSubscription;

  /// In place of the Buy button on the Google Play plan this phone already subscribes to.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get premiumCurrentPlan;

  /// Under the Google Play plans when this phone already has a Google Play subscription, so another plan of it is not sold here.
  ///
  /// In en, this message translates to:
  /// **'You already have a Google Play subscription. Manage or cancel it in Google Play.'**
  String get premiumPlaySubscribed;

  /// No description provided for @premiumEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter a code'**
  String get premiumEnterCode;

  /// On the Premium screen of a copy of the app that was not installed from Google Play, where Google Play cannot sell. Names no other way to pay: no Telegram, Stars, crypto or website.
  ///
  /// In en, this message translates to:
  /// **'To buy through Google Play, you need the Google Play version of Fortiva.'**
  String get premiumNeedsPlayVersion;

  /// No description provided for @premiumOff.
  ///
  /// In en, this message translates to:
  /// **'Premium is not on sale right now.'**
  String get premiumOff;

  /// No description provided for @premiumLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load Premium. Check your connection and try again.'**
  String get premiumLoadFailed;

  /// No description provided for @premiumRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get premiumRetry;

  /// A plan's price in the USDT stablecoin. {price} is the amount the backend sends, such as a decimal number.
  ///
  /// In en, this message translates to:
  /// **'{price} USDT'**
  String premiumPriceUsdt(String price);

  /// A plan's price in Telegram Stars, the in-app currency of Telegram. {stars} is the amount the backend sends.
  ///
  /// In en, this message translates to:
  /// **'{stars} Telegram Stars'**
  String premiumPriceStars(String stars);

  /// No description provided for @premiumPayCrypto.
  ///
  /// In en, this message translates to:
  /// **'Pay with crypto'**
  String get premiumPayCrypto;

  /// No description provided for @premiumTelegramTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay in Telegram'**
  String get premiumTelegramTitle;

  /// No description provided for @premiumTelegramBody.
  ///
  /// In en, this message translates to:
  /// **'Pay with Telegram Stars in our bot. You get a key, and Premium starts on this phone right away.'**
  String get premiumTelegramBody;

  /// No description provided for @premiumTelegramButton.
  ///
  /// In en, this message translates to:
  /// **'Buy in Telegram'**
  String get premiumTelegramButton;

  /// No description provided for @premiumTelegramFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open Telegram. Try again.'**
  String get premiumTelegramFailed;

  /// No description provided for @checkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay with crypto'**
  String get checkoutTitle;

  /// No description provided for @checkoutChooseNetwork.
  ///
  /// In en, this message translates to:
  /// **'Choose the network you will send from'**
  String get checkoutChooseNetwork;

  /// No description provided for @checkoutContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get checkoutContinue;

  /// No description provided for @checkoutSendExactly.
  ///
  /// In en, this message translates to:
  /// **'Send exactly'**
  String get checkoutSendExactly;

  /// No description provided for @checkoutNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get checkoutNetwork;

  /// No description provided for @checkoutAddress.
  ///
  /// In en, this message translates to:
  /// **'To this address'**
  String get checkoutAddress;

  /// Label above the memo (a short text some networks need with a transfer so it can be matched to the order).
  ///
  /// In en, this message translates to:
  /// **'With this memo'**
  String get checkoutMemo;

  /// No description provided for @checkoutMemoWarning.
  ///
  /// In en, this message translates to:
  /// **'Put this memo in your transfer, or we cannot match the payment to you.'**
  String get checkoutMemoWarning;

  /// No description provided for @checkoutExactWarning.
  ///
  /// In en, this message translates to:
  /// **'Send the exact amount, on this network only. A different amount or network may not reach us.'**
  String get checkoutExactWarning;

  /// Countdown until the crypto order expires. {time} is minutes and seconds, such as a clock reading.
  ///
  /// In en, this message translates to:
  /// **'Time left: {time}'**
  String checkoutTimeLeft(String time);

  /// No description provided for @checkoutWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your payment. This page updates by itself.'**
  String get checkoutWaiting;

  /// No description provided for @checkoutPaidTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get checkoutPaidTitle;

  /// No description provided for @checkoutPaidKeyOnly.
  ///
  /// In en, this message translates to:
  /// **'Your key is ready. Enter it on the phone that should get Premium.'**
  String get checkoutPaidKeyOnly;

  /// No description provided for @checkoutDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get checkoutDone;

  /// No description provided for @checkoutExpired.
  ///
  /// In en, this message translates to:
  /// **'This order has expired. If you already paid, contact support.'**
  String get checkoutExpired;

  /// The order number is shown under this text, with a Copy button.
  ///
  /// In en, this message translates to:
  /// **'We received less than the full amount. Contact support and give them this order number:'**
  String get checkoutUnderpaid;

  /// No description provided for @checkoutCanceled.
  ///
  /// In en, this message translates to:
  /// **'This order was canceled.'**
  String get checkoutCanceled;

  /// No description provided for @checkoutStartAgain.
  ///
  /// In en, this message translates to:
  /// **'Start again'**
  String get checkoutStartAgain;

  /// No description provided for @checkoutUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Crypto payments are not available right now.'**
  String get checkoutUnavailable;

  /// No description provided for @checkoutTooManyOpen.
  ///
  /// In en, this message translates to:
  /// **'You have too many unpaid orders. Pay one of them or wait until they expire.'**
  String get checkoutTooManyOpen;

  /// No description provided for @checkoutUnknownPlan.
  ///
  /// In en, this message translates to:
  /// **'This plan is no longer on sale. Go back and choose another.'**
  String get checkoutUnknownPlan;

  /// No description provided for @checkoutFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the payment. Check your connection and try again.'**
  String get checkoutFailed;

  /// No description provided for @redeemTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a code'**
  String get redeemTitle;

  /// Under the title of the code dialog. A key is what a Premium purchase outside Google Play gives; a gift code adds data.
  ///
  /// In en, this message translates to:
  /// **'A Premium key or a gift code'**
  String get redeemSubtitle;

  /// No description provided for @redeemHint.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get redeemHint;

  /// No description provided for @redeemApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get redeemApply;

  /// No description provided for @redeemCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get redeemCancel;

  /// No description provided for @redeemInvalid.
  ///
  /// In en, this message translates to:
  /// **'That does not look like a code. Check it and try again.'**
  String get redeemInvalid;

  /// No description provided for @redeemUnknown.
  ///
  /// In en, this message translates to:
  /// **'We do not know this code. Check it and try again.'**
  String get redeemUnknown;

  /// No description provided for @redeemExpired.
  ///
  /// In en, this message translates to:
  /// **'This code has expired.'**
  String get redeemExpired;

  /// No description provided for @redeemRevoked.
  ///
  /// In en, this message translates to:
  /// **'This code is no longer valid.'**
  String get redeemRevoked;

  /// No description provided for @redeemMovedTooOften.
  ///
  /// In en, this message translates to:
  /// **'This key has moved between phones too often lately. Try again later.'**
  String get redeemMovedTooOften;

  /// No description provided for @redeemExhausted.
  ///
  /// In en, this message translates to:
  /// **'This code has been used up.'**
  String get redeemExhausted;

  /// No description provided for @redeemAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'This phone has already used this code.'**
  String get redeemAlreadyUsed;

  /// No description provided for @redeemUnmetered.
  ///
  /// In en, this message translates to:
  /// **'This phone already has unlimited data, so it does not need this code.'**
  String get redeemUnmetered;

  /// No description provided for @redeemRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Wait a little and try again.'**
  String get redeemRateLimited;

  /// No description provided for @redeemUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This is not available right now. Try again later.'**
  String get redeemUnavailable;

  /// No description provided for @redeemNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check your connection and try again.'**
  String get redeemNetwork;

  /// No description provided for @redeemFailed.
  ///
  /// In en, this message translates to:
  /// **'That code did not work. Check it and try again.'**
  String get redeemFailed;

  /// No description provided for @redeemMoved.
  ///
  /// In en, this message translates to:
  /// **'Premium moved to this phone.'**
  String get redeemMoved;

  /// After a gift code worked. {amount} is the data it added, such as a size with its unit.
  ///
  /// In en, this message translates to:
  /// **'Code accepted. {amount} of extra data added.'**
  String redeemPromo(String amount);

  /// After a gift code worked, when the backend did not say how much it added. Names no number.
  ///
  /// In en, this message translates to:
  /// **'Code accepted. Extra data added.'**
  String get redeemPromoNoAmount;

  /// Title over a QR code a TV shows for a link it cannot open, such as Telegram or a website. The user scans it with their phone.
  ///
  /// In en, this message translates to:
  /// **'Open on your phone'**
  String get tvScanTitle;

  /// Under that title: how to open the link on a phone.
  ///
  /// In en, this message translates to:
  /// **'Point your phone\'s camera at this code.'**
  String get tvScanBody;

  /// Tooltip of the refresh button a list shows on a TV, where it cannot be pulled down to refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Closes an offer of Premium without buying. Short.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get premiumNotNow;

  /// Title of the sheet that opens when the user taps Connect after the daily data is used up.
  ///
  /// In en, this message translates to:
  /// **'Today\'s data is used up'**
  String get premiumLimitSheetTitle;

  /// First row of that sheet: the free way back, waiting until the daily data resets. The reset time is shown under it.
  ///
  /// In en, this message translates to:
  /// **'Wait for the reset'**
  String get premiumLimitWait;

  /// Row of that sheet that opens the invite screen. Names no amount.
  ///
  /// In en, this message translates to:
  /// **'Invite friends for more data'**
  String get premiumLimitInvite;

  /// Under Get unlimited on that sheet: what Premium gives. Never says faster.
  ///
  /// In en, this message translates to:
  /// **'Premium has no daily limit.'**
  String get premiumNoDailyLimit;

  /// Title of a quiet card on the home screen offering Premium, shown only while the connection works.
  ///
  /// In en, this message translates to:
  /// **'Want no daily limit?'**
  String get premiumCalmTitle;

  /// Body of that card. Says the free plan does not change.
  ///
  /// In en, this message translates to:
  /// **'Premium gives you unlimited data. Your free plan stays as it is.'**
  String get premiumCalmBody;

  /// Title of a card on My servers, shown once invites can add no more daily data, so the phone has the most free data there is.
  ///
  /// In en, this message translates to:
  /// **'The next step is Premium'**
  String get premiumNextStepTitle;

  /// Body of that card. Names no amount.
  ///
  /// In en, this message translates to:
  /// **'You already have the most free data. Premium has no daily limit.'**
  String get premiumNextStepBody;

  /// Small tag on a location only Premium can use, in the list of servers. Same word as the Premium name.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premiumLockedTag;

  /// Title of the sheet opened from a locked location. {place} is a city name.
  ///
  /// In en, this message translates to:
  /// **'Unlock {place} with Premium'**
  String premiumLockedTitle(String place);

  /// Body of that sheet. Says the free servers do not change.
  ///
  /// In en, this message translates to:
  /// **'This location is for Premium. Your free servers stay the same.'**
  String get premiumLockedBody;

  /// Headline of the Premium screen when the user came from the daily limit.
  ///
  /// In en, this message translates to:
  /// **'No daily limit'**
  String get premiumHeadlineLimit;

  /// Headline of the Premium screen when the user came from a locked location. {place} is a city name.
  ///
  /// In en, this message translates to:
  /// **'Unlock {place} with Premium'**
  String premiumHeadlineLocked(String place);

  /// Line under the plans on the Premium screen, as Google Play asks: the free plan still works without buying.
  ///
  /// In en, this message translates to:
  /// **'The free plan keeps working without Premium.'**
  String get premiumFreeStays;

  /// Reminder on the home screen before Premium that does not renew by itself ends. {date} is the end date, already formatted for the language.
  ///
  /// In en, this message translates to:
  /// **'Premium ends on {date}'**
  String premiumEndsOn(String date);

  /// Under that reminder, only in the build that sells keys, where renewing adds the new time after the current end, so nothing paid is lost.
  ///
  /// In en, this message translates to:
  /// **'Renew to keep unlimited data. Renewing adds time to your current end date.'**
  String get premiumRenewBody;

  /// Note on the home screen after Premium ended. {date} is the end date, already formatted for the language.
  ///
  /// In en, this message translates to:
  /// **'Premium ended on {date}. Your free plan is back.'**
  String premiumEndedOn(String date);

  /// Button that opens the Premium screen to buy more time. Short.
  ///
  /// In en, this message translates to:
  /// **'Renew'**
  String get premiumRenew;

  /// Name of the Android notification channel for messages from the Fortiva team, shown in the system notification settings. Short.
  ///
  /// In en, this message translates to:
  /// **'Messages from Fortiva'**
  String get noticeChannelName;

  /// Description of that notification channel, shown under its name in the system notification settings.
  ///
  /// In en, this message translates to:
  /// **'News and messages from the Fortiva team'**
  String get noticeChannelDescription;

  /// Title of the Settings row about notifications for messages from the Fortiva team. Short.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get noticesSettingTitle;

  /// Under that row while notifications are allowed.
  ///
  /// In en, this message translates to:
  /// **'On. Messages from the Fortiva team can reach you even when the app is closed.'**
  String get noticesSettingOn;

  /// Under that row while notifications are not allowed. Tapping the row turns them on.
  ///
  /// In en, this message translates to:
  /// **'Off. Turn them on to get messages from the Fortiva team even when the app is closed.'**
  String get noticesSettingOff;

  /// A short card at the top of the Messages screen while notifications are off.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications to get messages from the Fortiva team even when the app is closed.'**
  String get noticesOffCard;

  /// Button on that card that turns notifications on. Short.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get noticesTurnOn;

  /// A card on the Messages screen, shown only when something on the phone may stop messages arriving while the app is closed.
  ///
  /// In en, this message translates to:
  /// **'Your phone may hold back messages from the Fortiva team while the app is closed. Let Fortiva run in the background so they reach you.'**
  String get backgroundCard;

  /// Under that card: what to do on the system screen the button opens.
  ///
  /// In en, this message translates to:
  /// **'On the next screen, choose Fortiva (if it is not listed, show all apps). Then set its battery use to Unrestricted, or allow it to start and run in the background.'**
  String get backgroundHint;

  /// Button on that card that opens the phone's settings. Short.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get backgroundAllow;

  /// Button on that card that closes it for a while. Short.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get backgroundNotNow;

  /// Title of the Settings row that opens the phone's background settings. Short.
  ///
  /// In en, this message translates to:
  /// **'Messages while closed'**
  String get backgroundSettingTitle;

  /// Under that row.
  ///
  /// In en, this message translates to:
  /// **'Let Fortiva run in the background so messages reach you while the app is closed.'**
  String get backgroundSettingSubtitle;

  /// The same card when Data Saver is what holds messages back.
  ///
  /// In en, this message translates to:
  /// **'Data Saver on your phone may stop messages from the Fortiva team while the app is closed.'**
  String get backgroundCardData;

  /// Under that card: what to do on the Data Saver page the button opens.
  ///
  /// In en, this message translates to:
  /// **'On the next screen, turn on Unrestricted data.'**
  String get backgroundHintData;

  /// Title of the home screen card that shows how to turn on IPv6 for the SIM. Shown only on mobile data from operators the backend names, on phones with no IPv6 route. Short.
  ///
  /// In en, this message translates to:
  /// **'A steadier connection on this SIM'**
  String get apnGuideTitle;

  /// One sentence under that title. IPv6 is not translated.
  ///
  /// In en, this message translates to:
  /// **'Your phone is not using IPv6 on this SIM. Turning it on helps Fortiva stay connected.'**
  String get apnGuideBody;

  /// Button on that card that opens the steps. Short.
  ///
  /// In en, this message translates to:
  /// **'Show me how'**
  String get apnGuideShowMe;

  /// Button on that card that hides it for 14 days. Short.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get apnGuideNotNow;

  /// Title of the sheet with the steps. IPv6 is not translated.
  ///
  /// In en, this message translates to:
  /// **'Turn on IPv6 for this SIM'**
  String get apnGuideSheetTitle;

  /// Step 1. {button} is the label of the button at the bottom of the sheet (apnGuideOpenSettings). The path is the one on Samsung phones; use the names Samsung shows in the language.
  ///
  /// In en, this message translates to:
  /// **'Tap \"{button}\" (or go to Settings > Connections > Mobile networks > Access Point Names).'**
  String apnGuideStepOpen(String button);

  /// Step 2. {apn} is the access point the SIM uses, such as mcinet or mtnirancell, and is not translated.
  ///
  /// In en, this message translates to:
  /// **'Tap the access point in use ({apn}).'**
  String apnGuideStepAccessPoint(String apn);

  /// Step 2 when the app does not know the access point's name.
  ///
  /// In en, this message translates to:
  /// **'Tap the access point in use.'**
  String get apnGuideStepAccessPointAny;

  /// Step 3. APN protocol is the setting's name on the phone; IPv4/IPv6 is the value to pick and is not translated.
  ///
  /// In en, this message translates to:
  /// **'Tap \"APN protocol\" and choose \"IPv4/IPv6\".'**
  String get apnGuideStepProtocol;

  /// Step 4. On Samsung, Save is in the menu behind the three dots.
  ///
  /// In en, this message translates to:
  /// **'Save (on Samsung: the three-dot menu, then Save).'**
  String get apnGuideStepSave;

  /// Step 5.
  ///
  /// In en, this message translates to:
  /// **'Turn mobile data off and on again.'**
  String get apnGuideStepRestart;

  /// Reassurance under the steps: how to undo the change. IPv4 is not translated.
  ///
  /// In en, this message translates to:
  /// **'If mobile data stops working, set APN protocol back to IPv4.'**
  String get apnGuideUndo;

  /// Button that opens the phone's list of access points (APNs). APN is not translated.
  ///
  /// In en, this message translates to:
  /// **'Open APN settings'**
  String get apnGuideOpenSettings;

  /// Status line under the connect button while the app, on its own, looks for another server because the connected tunnel stopped carrying any data.
  ///
  /// In en, this message translates to:
  /// **'The connection stopped working. Finding another path.'**
  String get homeStallSearching;

  /// Status line under the connect button when the tunnel is up but the app found that no data gets through it.
  ///
  /// In en, this message translates to:
  /// **'Connected, but no data is getting through'**
  String get homeStalled;

  /// Settings row and screen title. The screen shows codes that a friend's phone can photograph, so a friend whose Fortiva cannot connect gets what it needs from this phone. Also named inside peerReceiveBody, so keep it short.
  ///
  /// In en, this message translates to:
  /// **'Help a friend connect'**
  String get peerShareTitle;

  /// Under that Settings row.
  ///
  /// In en, this message translates to:
  /// **'Pass what Fortiva needs to a friend\'s phone'**
  String get peerShareSubtitle;

  /// First text on that screen. Says what the user gets, never how it works.
  ///
  /// In en, this message translates to:
  /// **'If a friend\'s Fortiva cannot connect, their phone can get what it needs from yours. This works without internet.'**
  String get peerShareBody;

  /// Under the first text, when there is something to pass on. {action} is the name of the other phone's button, peerReceiveTitle, already translated.
  ///
  /// In en, this message translates to:
  /// **'In Fortiva on their phone, open Settings and tap {action}. Then show them these codes one at a time, or send this to them.'**
  String peerShareSteps(String action);

  /// Under a spinner while the screen gets the newest copy before showing the codes.
  ///
  /// In en, this message translates to:
  /// **'Getting the newest copy'**
  String get peerShareLoading;

  /// Shown instead of the codes when this phone has nothing recent enough to pass on, even after trying to get a newer copy. The user may already be connected, so never tell them to connect.
  ///
  /// In en, this message translates to:
  /// **'This phone has nothing recent to pass on. Try again later.'**
  String get peerShareNothing;

  /// Under the code on screen, when there are several. Digits are filled in by the app.
  ///
  /// In en, this message translates to:
  /// **'Code {current} of {total}'**
  String peerShareCodeOf(int current, int total);

  /// Button that shows the previous code. Short.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get peerSharePrevious;

  /// Button that shows the next code. Short.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get peerShareNext;

  /// Button that copies what the friend needs, to paste into a message. Short.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get peerShareCopy;

  /// Button that opens the phone's share sheet (Quick Share, Bluetooth, messengers) to send it to the friend. Short.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get peerShareSend;

  /// Short note after Copy.
  ///
  /// In en, this message translates to:
  /// **'Copied. Paste it in a message to your friend.'**
  String get peerShareCopied;

  /// Settings row, screen title, and the button under the home screen's offer. Opens the screen where this phone takes what it needs from a friend's phone. Also named inside peerShareSteps, so keep it short.
  ///
  /// In en, this message translates to:
  /// **'Get help from a friend'**
  String get peerReceiveTitle;

  /// Under that Settings row.
  ///
  /// In en, this message translates to:
  /// **'When nothing else connects'**
  String get peerReceiveSubtitle;

  /// First text on that screen. {action} is the name of the friend's Settings row, peerShareTitle, already translated.
  ///
  /// In en, this message translates to:
  /// **'Ask a friend whose Fortiva connects to open Settings in Fortiva and tap {action}. Then get it from their phone in one of these ways.'**
  String peerReceiveBody(String action);

  /// Button that opens the phone's camera app to take a photo of the code on the friend's screen.
  ///
  /// In en, this message translates to:
  /// **'Photograph their codes'**
  String get peerReceivePhotograph;

  /// The same button once some codes are read and more are needed.
  ///
  /// In en, this message translates to:
  /// **'Photograph the next code'**
  String get peerReceivePhotographNext;

  /// Under that button while codes are being read. Digits are filled in by the app.
  ///
  /// In en, this message translates to:
  /// **'{have} of {total} codes read'**
  String peerReceiveProgress(int have, int total);

  /// Button that opens the file picker, for a file the friend sent by Quick Share, Bluetooth or a messenger.
  ///
  /// In en, this message translates to:
  /// **'Open a file they sent'**
  String get peerReceiveFile;

  /// Button that reads what the user copied from a message the friend sent.
  ///
  /// In en, this message translates to:
  /// **'Paste what they sent'**
  String get peerReceivePaste;

  /// After a photo in which no code could be read.
  ///
  /// In en, this message translates to:
  /// **'No code found in that photo. Hold the phone closer, with the whole code in view.'**
  String get peerReceiveNoCode;

  /// After a photo, file or paste that is not something Fortiva can use, or is incomplete.
  ///
  /// In en, this message translates to:
  /// **'Fortiva cannot use that. Ask your friend to send it again.'**
  String get peerReceiveRefused;

  /// After a photo, file or paste of something this phone already has.
  ///
  /// In en, this message translates to:
  /// **'You already have this, or something newer. Try connecting again, or ask another friend.'**
  String get peerReceiveNotNewer;

  /// Short note after it worked. The screen closes and the user is back where the connect button is.
  ///
  /// In en, this message translates to:
  /// **'Done. Tap the button to connect.'**
  String get peerReceiveTaken;

  /// When the phone has no camera app or no file picker to open.
  ///
  /// In en, this message translates to:
  /// **'This phone cannot do that. Try another way.'**
  String get peerReceiveUnavailable;

  /// After Paste when nothing was copied.
  ///
  /// In en, this message translates to:
  /// **'Nothing copied yet. Copy what your friend sent, then tap here again.'**
  String get peerReceiveNothingToPaste;

  /// Note on the home screen when connecting failed and the app could not get anything newer by itself. The button under it is peerReceiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Still cannot connect? A friend whose Fortiva works can help from their phone.'**
  String get peerOfferBody;

  /// After a photo of a code this phone has already read.
  ///
  /// In en, this message translates to:
  /// **'You already have this code. Ask your friend to show the next one.'**
  String get peerReceiveAgain;

  /// After Paste when the copied text is not something Fortiva can use.
  ///
  /// In en, this message translates to:
  /// **'What you copied is not from Fortiva. Copy your friend\'s whole message, then try again.'**
  String get peerReceivePasteNotOurs;

  /// When the camera app said it took a photo but gave none back. {action} is the name of the Open a file button (peerReceiveFile), already translated.
  ///
  /// In en, this message translates to:
  /// **'The camera did not hand the photo back. Take the photo with the camera app, then tap {action}.'**
  String peerReceiveNoPhoto(String action);

  /// Small hint under the Open a file button.
  ///
  /// In en, this message translates to:
  /// **'A file from a messenger may need to be saved to Downloads first.'**
  String get peerReceiveFileHint;

  /// Home status line while the app dials the backup network by itself, after our servers and the community links did not connect. Do not name the network.
  ///
  /// In en, this message translates to:
  /// **'Nothing else connected. Trying a backup network now.'**
  String get homeTryingBackup;

  /// Home status line while connected through the backup network, in place of statusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected through a backup network'**
  String get homeConnectedBackup;

  /// Heading of the home server card while connected through the backup network. In capitals, like yourServer and communityServer.
  ///
  /// In en, this message translates to:
  /// **'BACKUP NETWORK'**
  String get backupNetwork;

  /// What the checklist row and the session history call the backup network.
  ///
  /// In en, this message translates to:
  /// **'Backup network'**
  String get backupNetworkTitle;

  /// Caption of the home server card while connected through the backup network.
  ///
  /// In en, this message translates to:
  /// **'Used when nothing else connects. It can be slower than our servers.'**
  String get backupNetworkCaption;

  /// Place line of the home server card on the backup network when its country is not known.
  ///
  /// In en, this message translates to:
  /// **'Location picked automatically'**
  String get backupNetworkPlace;

  /// Button that starts the speed test.
  ///
  /// In en, this message translates to:
  /// **'Start test'**
  String get speedTestStart;

  /// Button that starts the speed test again after a result.
  ///
  /// In en, this message translates to:
  /// **'Test again'**
  String get speedTestAgain;

  /// Button label while the speed test runs.
  ///
  /// In en, this message translates to:
  /// **'Testing'**
  String get speedTestRunning;

  /// Line under the speed gauge before a test has run.
  ///
  /// In en, this message translates to:
  /// **'See how fast your connection is right now.'**
  String get speedTestIdle;

  /// Line under the speed gauge while the first step of the test runs.
  ///
  /// In en, this message translates to:
  /// **'Checking response time'**
  String get speedTestPhasePing;

  /// Line under the speed gauge while the download speed is measured.
  ///
  /// In en, this message translates to:
  /// **'Measuring download speed'**
  String get speedTestPhaseDownload;

  /// Line under the speed gauge while the upload speed is measured.
  ///
  /// In en, this message translates to:
  /// **'Measuring upload speed'**
  String get speedTestPhaseUpload;

  /// Line under the speed gauge once a result is shown.
  ///
  /// In en, this message translates to:
  /// **'Test finished'**
  String get speedTestDone;

  /// Line under the speed gauge when the test stopped without a result.
  ///
  /// In en, this message translates to:
  /// **'The test could not finish. Check your internet and try again.'**
  String get speedTestFailed;

  /// Unit of the speed numbers: megabits per second, short form.
  ///
  /// In en, this message translates to:
  /// **'Mbps'**
  String get speedTestUnit;

  /// Check my IP: heading over the address.
  ///
  /// In en, this message translates to:
  /// **'IP address'**
  String get ipAddressLabel;

  /// Check my IP: message after the address was copied.
  ///
  /// In en, this message translates to:
  /// **'Address copied'**
  String get ipCopied;

  /// Check my IP: label of the country and city row.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get ipLocation;

  /// Check my IP: label of the internet provider row.
  ///
  /// In en, this message translates to:
  /// **'Internet provider'**
  String get ipProvider;

  /// Check my IP: label of the organization row.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get ipOrganization;

  /// Check my IP: label of the time zone row.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get ipTimeZone;

  /// Check my IP: label of the map coordinates row.
  ///
  /// In en, this message translates to:
  /// **'Coordinates'**
  String get ipCoordinates;

  /// Check my IP: shown when the address could not be read.
  ///
  /// In en, this message translates to:
  /// **'Could not check your address'**
  String get ipCheckFailed;

  /// History: label of the average length of one connection.
  ///
  /// In en, this message translates to:
  /// **'Average connection'**
  String get historyAverage;

  /// History: heading over the chart of time connected on each of the most recent days. Not the calendar week: the chart ends today.
  ///
  /// In en, this message translates to:
  /// **'Recent days'**
  String get historyRecentDays;

  /// History: when a connection started, for yesterday. {time} is a clock time.
  ///
  /// In en, this message translates to:
  /// **'Yesterday at {time}'**
  String yesterdayAt(String time);

  /// History: when a connection started, for an earlier day. {date} is a date and {time} a clock time.
  ///
  /// In en, this message translates to:
  /// **'{date} at {time}'**
  String dateAt(String date, String time);

  /// A duration of seconds, short form, in the same style as supportDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String durationSeconds(int seconds);

  /// Name of the first stage of the connect search: this device's own servers, run by Fortiva.
  ///
  /// In en, this message translates to:
  /// **'Fortiva servers'**
  String get stageOwn;

  /// Name of the second stage of the connect search: the community servers, in the app's usual name for them.
  ///
  /// In en, this message translates to:
  /// **'Community servers'**
  String get stageCommunity;

  /// Small line over the search: which stage runs now. n and total are already in the phone's digits. No percentage.
  ///
  /// In en, this message translates to:
  /// **'Stage {n} of {total}'**
  String stageProgress(int n, int total);

  /// Home status line while the app tries this device's own servers.
  ///
  /// In en, this message translates to:
  /// **'Trying Fortiva servers'**
  String get stageTryingOwn;

  /// Home status line while the app tries community servers, when our own servers were not tried first.
  ///
  /// In en, this message translates to:
  /// **'Trying community servers'**
  String get stageTryingCommunity;

  /// Home status line once our own servers did not connect and the app tries community servers. Do not name how they are blocked.
  ///
  /// In en, this message translates to:
  /// **'Fortiva servers did not connect here. Trying community servers.'**
  String get stageOwnFailedTryingCommunity;

  /// Checklist row while the app dials the server that worked last time on this network, before any check. server is a place name.
  ///
  /// In en, this message translates to:
  /// **'Last server that worked: {server}'**
  String stageLastWorked(String server);

  /// One line for a finished stage of the search whose paths all read blocked. count is how many paths were tried.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} path tried, blocked here} other{{count} paths tried, blocked here}}'**
  String stageTriedBlocked(int count);

  /// One line for a finished stage of the search where a path was open but nothing connected. count is how many paths were tried.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} path tried, it did not connect} other{{count} paths tried, none connected}}'**
  String stageTriedFailed(int count);

  /// One line for a finished stage of the search that did not connect, when no path count is known.
  ///
  /// In en, this message translates to:
  /// **'Did not connect'**
  String get stageNotConnected;

  /// One line for the stage of the search that connected.
  ///
  /// In en, this message translates to:
  /// **'Connected here'**
  String get stageConnected;

  /// One line for a stage of the search that was not tried on this try.
  ///
  /// In en, this message translates to:
  /// **'Skipped this time'**
  String get stageSkipped;

  /// One line in the stage of the search that runs now, in place of the paths it has not checked yet when they do not all fit on screen. count is how many.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} more path to check} other{{count} more paths to check}}'**
  String stageMoreToCheck(int count);

  /// While the app waits to try again by itself: when, and the stage it starts with. time is a countdown such as 0:42, stage a stage name.
  ///
  /// In en, this message translates to:
  /// **'Next try starts with {stage} in {time}'**
  String stageNextTry(String stage, String time);

  /// Second line under the status after about 15 seconds of searching. Says the search can take a while and that the power button stops it. No exact time.
  ///
  /// In en, this message translates to:
  /// **'This can take a minute or two. Tap the button to stop the search.'**
  String get searchSlowHint;

  /// Home status line for a moment after the user stopped a search with the power button.
  ///
  /// In en, this message translates to:
  /// **'Search stopped'**
  String get searchStopped;

  /// Home status line while connected through a community server, in place of statusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected through a community server'**
  String get homeConnectedCommunity;

  /// Row under the first stage of the search while the app asks for this device's own servers before its first try, on a phone that has none yet.
  ///
  /// In en, this message translates to:
  /// **'Getting your servers'**
  String get stageGettingServers;

  /// Small line over the search once the wait before the next try is over and that try is being made ready. stage is a stage name.
  ///
  /// In en, this message translates to:
  /// **'Starting the next try with {stage}'**
  String stageNextTryStarting(String stage);
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'fa',
    'fr',
    'hi',
    'id',
    'ja',
    'ko',
    'pt',
    'ru',
    'tr',
    'uk',
    'ur',
    'uz',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return SAr();
    case 'de':
      return SDe();
    case 'en':
      return SEn();
    case 'es':
      return SEs();
    case 'fa':
      return SFa();
    case 'fr':
      return SFr();
    case 'hi':
      return SHi();
    case 'id':
      return SId();
    case 'ja':
      return SJa();
    case 'ko':
      return SKo();
    case 'pt':
      return SPt();
    case 'ru':
      return SRu();
    case 'tr':
      return STr();
    case 'uk':
      return SUk();
    case 'ur':
      return SUr();
    case 'uz':
      return SUz();
    case 'vi':
      return SVi();
    case 'zh':
      return SZh();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
