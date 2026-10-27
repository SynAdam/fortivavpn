import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/account_service.dart';
import '../api/api_client.dart';
import '../api/device_service.dart';
import '../core/design_system.dart';
import '../core/form_factor.dart';
import '../core/haptics.dart';
import '../core/state/app_config_state.dart';
import '../core/state/billing_state.dart';
import '../core/state/dedicated_state.dart';
import '../core/state/device_state.dart';
import '../core/state/locale_state.dart';
import '../core/state/message_state.dart';
import '../core/state/invite_events.dart';
import '../core/state/referral_state.dart';
import '../core/state/review_prompt.dart';
import '../core/state/support_state.dart';
import '../data/models/version_info.dart';
import '../services/notice_channel.dart';
import '../services/session_tracker.dart';
import '../services/vpn_event_reporter.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/number_localizer.dart';
import '../utils/site_links.dart';
import '../widgets/background_card.dart';
import '../widgets/language_picker.dart';
import '../widgets/notices_switch.dart';
import '../widgets/outside_link.dart';
import '../widgets/readable_width.dart';
import '../widgets/redeem_code_dialog.dart';
import '../widgets/support_button.dart';
import '../widgets/tappable.dart';
import '../widgets/ui/section_label.dart';
import 'dns_settings_screen.dart';
import 'invite_screen.dart';
import 'ip_info_screen.dart';
import 'my_servers_screen.dart';
import 'peer_receive_screen.dart';
import 'peer_share_screen.dart';
import 'premium_screen.dart';
import 'analytics_screen.dart';
import 'speed_test_screen.dart';

/// The line in the delete-account confirmation that says how long copies
/// in backups and anonymous server logs are kept: the number of days the
/// backend sends (deleted_data_retention_days in GET /api/v1/app/config),
/// or text that names no number when it sends none.
///
/// The backend's privacy policy states the same setting, so the two
/// cannot disagree. The app used to say 30 days on its own.
String deleteAccountRetentionText(BuildContext context, int? days) {
  final l10n = S.of(context)!;
  if (days == null) return l10n.deleteAccountConfirmRetentionNoDays;
  return NumberLocalizer.localize(
    l10n.deleteAccountConfirmRetention(days),
    context,
  );
}

/// The Settings screen: network options, diagnostics, account, and about.
///
/// Each section is a heading over one rounded group of rows, divided by
/// hairlines that start under the text, so the icons stand in one column.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  /// The space from a row's start edge to its text: the icon box and the
  /// gaps on either side of it. The dividers between rows start here.
  static const double textInset = _rowPaddingStart + _iconBox + _iconGap;

  static const double _rowPaddingStart = 16;
  static const double _iconBox = 36;
  static const double _iconGap = 12;

  /// The least height of a row.
  static const double rowMinHeight = 64;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _appVersion;
  bool _shareDiagnostics = true;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadShareDiagnostics();
  }

  void _showSourceOffer(BuildContext context, S l10n) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sourceOfferTitle),
        content: SingleChildScrollView(
          child: SelectableText(
            l10n.sourceOfferBody,
            style: AppDesign.textTheme.bodyMedium?.copyWith(
              color: AppDesign.textSecondary,
              fontSize: 15,
            ),
          ),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Future<void> _loadShareDiagnostics() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(
      () => _shareDiagnostics = prefs.getBool('pref_share_diagnostics') ?? true,
    );
  }

  Future<void> _setShareDiagnostics(bool value) async {
    AppHaptics.selection();
    // Off also drops the reports already waiting on the phone, the Premium
    // offer events among them.
    final billing = context.read<BillingState?>();
    final invites = context.read<InviteEvents?>();
    await VpnEventReporter.setSharing(value);
    billing?.sharingChanged(value);
    invites?.sharingChanged(value);
    if (mounted) setState(() => _shareDiagnostics = value);
  }

  Future<void> _loadVersion() async {
    final version = await DeviceService().getAppVersion();
    if (mounted) setState(() => _appVersion = version);
  }

  /// Whether invites are known to run under today's flat rule, as a
  /// referral answer loaded in this run or the config says. Watched, so the
  /// invite row's line follows the rule. While the rule is not known, which
  /// is most runs, the row uses the line that is true under both rules, so
  /// the tree never shows a line that says the user earns.
  static bool _inviteFlat(BuildContext context) {
    final status = context.watch<ReferralState?>()?.status;
    if (status != null) return !status.isTree;
    return context.watch<AppConfigState>().flags.referralRules == 'flat';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;

    return Scaffold(
      backgroundColor: AppDesign.canvas,
      appBar: AppBar(
        title: Text(l10n.settings),
        // A step lighter once the groups scroll under it, so a card is cut
        // by a change of tone rather than by a hard edge.
        backgroundColor: AppDesign.appBarColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: AppDesign.clearOfNavBar(
          context,
          const EdgeInsets.fromLTRB(16, 8, 16, 24),
        ),
        children: [
          // Network Configuration
          _buildSection(
            context,
            title: l10n.connection,
            first: true,
            children: [
              _buildTile(
                context,
                icon: Icons.verified_user_outlined,
                title: l10n.myServersTitle,
                subtitle: l10n.myServersSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ReadableWidth(child: MyServersScreen()),
                  ),
                ),
              ),
              _buildTile(
                context,
                icon: Icons.dns_outlined,
                title: l10n.dnsConfiguration,
                subtitle: l10n.customDns,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ReadableWidth(child: DnsSettingsScreen()),
                  ),
                ),
              ),
              // Passing the fallback file between two phones, with no
              // network between them. See PeerShareScreen.
              _buildTile(
                context,
                icon: Icons.qr_code_2_rounded,
                title: l10n.peerShareTitle,
                subtitle: l10n.peerShareSubtitle,
                onTap: () => PeerShareScreen.open(context),
              ),
              // A TV has no camera, and seldom a friend's file to open.
              if (!FormFactor.isTv)
                _buildTile(
                  context,
                  icon: Icons.phonelink_ring_outlined,
                  title: l10n.peerReceiveTitle,
                  subtitle: l10n.peerReceiveSubtitle,
                  onTap: () => PeerReceiveScreen.open(context),
                ),
            ],
          ),

          // Diagnostics
          _buildSection(
            context,
            title: l10n.tools,
            children: [
              _buildShareDiagnosticsTile(context),
              // A globe with a lens: the DNS row above has the server
              // stack, and one glyph should not name two screens.
              _buildTile(
                context,
                icon: Icons.travel_explore_rounded,
                title: l10n.privacyDashboard,
                subtitle: l10n.privacyDashboardSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReadableWidth(child: IpInfoScreen()),
                  ),
                ),
              ),
              _buildTile(
                context,
                icon: Icons.speed_rounded,
                title: l10n.speedTest,
                subtitle: l10n.speedTestSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ReadableWidth(child: SpeedTestScreen()),
                  ),
                ),
              ),
              _buildTile(
                context,
                icon: Icons.insights_rounded,
                title: l10n.connectionAnalytics,
                subtitle: l10n.connectionAnalyticsSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ReadableWidth(child: AnalyticsScreen()),
                  ),
                ),
              ),
            ],
          ),

          // General
          _buildSection(
            context,
            title: l10n.settingsGeneral,
            children: [
              _buildLanguageTile(context, l10n),
              // Android phones only (NoticesStatus). Off, a tap turns them
              // on; on, it opens the system page to change them there.
              // The row brings its own divider, so a phone that shows no
              // row shows no divider either.
              NoticesStatus(
                builder: (context, state, turnOn) {
                  final on = state == NoticePermission.granted;
                  return _divided(
                    _buildTile(
                      context,
                      icon: on
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                      title: l10n.noticesSettingTitle,
                      subtitle: on
                          ? l10n.noticesSettingOn
                          : l10n.noticesSettingOff,
                      onTap: on
                          ? () => NoticeChannel.openSettings()
                          : () => turnOn(),
                    ),
                  );
                },
              ),
              // On the same phones: the system screen where the user lets
              // the app run in the background, for makers that stop it.
              NoticesStatus(
                builder: (context, state, turnOn) => _divided(
                  _buildTile(
                    context,
                    icon: Icons.battery_charging_full_outlined,
                    title: l10n.backgroundSettingTitle,
                    subtitle: l10n.backgroundSettingSubtitle,
                    onTap: () => BackgroundCard.openSettings(),
                  ),
                ),
              ),
            ],
          ),

          // Account
          _buildSection(
            context,
            title: l10n.account,
            children: [
              ?_buildPremiumTile(context, l10n),
              // Hidden until the backend says the program is live, so a
              // build cannot offer a screen whose endpoints are switched
              // off.
              if (context.watch<AppConfigState>().referralsEnabled)
                _buildTile(
                  context,
                  icon: Icons.card_giftcard_outlined,
                  title: l10n.inviteTitle,
                  // Under the tree rule friends add data while they are
                  // active, so the row never says the user earns it. Only
                  // a rule known to be flat gets the flat line.
                  subtitle: _inviteFlat(context)
                      ? l10n.inviteSubtitle
                      : l10n.inviteTreeHero,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const ReadableWidth(child: InviteScreen()),
                    ),
                  ),
                ),
              _buildTile(
                context,
                icon: Icons.delete_outline_rounded,
                title: l10n.deleteAccount,
                subtitle: _isDeletingAccount
                    ? l10n.deleteAccountInProgress
                    : l10n.deleteAccountSubtitle,
                destructive: true,
                // Stays enabled while the deletion runs, so a TV remote
                // that pressed it keeps its focus; a second press does
                // nothing.
                onTap: () {
                  if (_isDeletingAccount) return;
                  _confirmDeleteAccount(context, l10n);
                },
              ),
            ],
          ),

          // About
          _buildSection(
            context,
            title: l10n.about,
            children: [
              _buildTile(
                context,
                icon: Icons.article_outlined,
                title: l10n.privacyPolicy,
                outside: true,
                onTap: () => openOutside(
                  sitePage(
                    '/privacy',
                    Localizations.localeOf(context).languageCode,
                  ),
                ),
              ),
              _buildContactTile(context, l10n),
              // Only a Play install can be rated. This opens the store
              // listing, never Play's review card: Google's rules say a
              // button must go to the store.
              if (context.watch<ReviewPrompt?>()?.fromPlay ?? false)
                _buildTile(
                  context,
                  icon: Icons.star_rate_rounded,
                  title: l10n.rateOnGooglePlay,
                  outside: true,
                  onTap: () => context.read<ReviewPrompt>().openListing(),
                ),
              _buildTile(
                context,
                icon: Icons.language,
                title: l10n.website,
                outside: true,
                onTap: () => openOutside(
                  sitePage('/', Localizations.localeOf(context).languageCode),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.space16),

          // Version
          _buildFooter(context, l10n),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, S l10n) {
    final small = AppDesign.textTheme.labelSmall?.copyWith(
      color: AppDesign.textTertiary,
      fontWeight: FontWeight.w500,
    );
    // The copyright and the source link are words, translated, so they
    // keep the 12.5sp floor for secondary text in Persian, Arabic and
    // Urdu. Only the version line is set as a label.
    final words = AppDesign.textTheme.bodySmall?.copyWith(
      color: AppDesign.textTertiary,
    );
    return Center(
      child: Column(
        children: [
          Text(
            // The version number used to be baked into all 13
            // translation files, which is why it still read 1.0.1
            // twenty releases later. It comes from the build now.
            // In the language's own digits, like every number in the app.
            NumberLocalizer.localize(
              '${l10n.version} ${_appVersion ?? ''}'.trim(),
              context,
            ),
            style: small?.copyWith(fontFeatures: AppDesign.numberFeatures),
          ),
          const SizedBox(height: AppDesign.space4),
          Text(l10n.copyright, style: words),
          // The Android and Windows builds are GPL-3.0 (LICENSING.md),
          // which requires that anyone who receives the binary can
          // obtain the corresponding source. The app ships as a binary
          // rather than as a repository, so the written offer has to
          // travel with the app. Its words must hold in both builds, so
          // they name Xray-core, which both carry, and not v2rayNG,
          // which only Android has. A footer line, not a menu entry, with
          // a finger-sized target around it. The words sit at the top of
          // the target, as close to the line above as the lines above are
          // to each other, and the rest of the target hangs below them.
          Tappable(
            onTap: () => _showSourceOffer(context, l10n),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Align(
                  alignment: Alignment.topCenter,
                  widthFactor: 1,
                  child: Text(
                    l10n.openSourceLicence,
                    style: words?.copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: AppDesign.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ask, then delete. App Store Review Guideline 5.1.1(v) requires this
  /// path to exist inside the app; the confirmation exists because the
  /// action is irreversible and the tile sits one tap away.
  Future<void> _confirmDeleteAccount(BuildContext context, S l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteAccountConfirmTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.deleteAccountConfirmBody,
                style: AppDesign.textTheme.bodyMedium?.copyWith(
                  color: AppDesign.textSecondary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: AppDesign.space12),
              Text(
                deleteAccountRetentionText(
                  dialogContext,
                  dialogContext.read<AppConfigState>().deletedDataRetentionDays,
                ),
                style: AppDesign.textTheme.bodySmall?.copyWith(
                  color: AppDesign.textTertiary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          // The safe answer has the focus, so a TV remote that opened
          // this by mistake backs out with one press.
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppDesign.textPrimary),
            child: Text(l10n.deleteAccountCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppDesign.error),
            child: Text(l10n.deleteAccountConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _deleteAccount(l10n);
  }

  Future<void> _deleteAccount(S l10n) async {
    setState(() => _isDeletingAccount = true);

    // Captured before the await: the states must be reset even though
    // this widget may have been disposed by the time the call returns,
    // otherwise the rest of the app keeps rendering a deleted account.
    final deviceState = context.read<DeviceState>();
    final dedicatedState = context.read<DedicatedState>();
    final referralState = context.read<ReferralState>();
    final sessionTracker = context.read<SessionTracker>();
    final messages = context.read<MessageState?>();
    final support = context.read<SupportState?>();
    final billing = context.read<BillingState?>();
    final messenger = ScaffoldMessenger.of(context);

    String message;
    // Whether the deletion call returned, and whether DedicatedState was
    // cleared after it. Whatever fails, forgetAccount must end in one of
    // the two (see the finally below), or no answer would be taken up for
    // the rest of the run.
    var deleted = false;
    var dedicatedCleared = false;
    try {
      // An answer still on its way must not put the account's servers back
      // while its saved copy is being removed.
      dedicatedState.forgetAccount();
      await AccountService.instance.deleteAccount();
      deleted = true;
      deviceState.reset();
      dedicatedState.reset();
      dedicatedCleared = true;
      referralState.reset();
      billing?.reset();
      await messages?.reset();
      await support?.reset();
      await sessionTracker.clear();
      message = l10n.deleteAccountDone;
    } on ApiException {
      message = l10n.deleteAccountFailed;
    } catch (_) {
      message = l10n.deleteAccountFailed;
    } finally {
      if (!deleted) {
        dedicatedState.keepAccount();
      } else if (!dedicatedCleared) {
        dedicatedState.reset();
      }
    }

    if (!mounted) return;
    setState(() => _isDeletingAccount = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Premium, as BillingState.tile says: the Premium screen for a device
  /// that has Premium (even while sales are off, so its key can be copied)
  /// or can buy it here, a plain "Enter a code" where sales are on but
  /// nothing can be bought, and nothing otherwise. Null hides it.
  Widget? _buildPremiumTile(BuildContext context, S l10n) {
    final billing = context.watch<BillingState?>();
    switch (billing?.tile ?? PremiumTile.hidden) {
      case PremiumTile.hidden:
        return null;
      case PremiumTile.premium:
        return _buildTile(
          context,
          icon: Icons.workspace_premium_outlined,
          title: l10n.premiumTitle,
          subtitle: billing!.premium.active
              ? l10n.premiumTileActive
              : l10n.premiumTileSubtitle,
          onTap: () => PremiumScreen.open(context),
        );
      case PremiumTile.enterCode:
        // No price and no word about buying: nothing is on sale here.
        return _buildTile(
          context,
          icon: Icons.vpn_key_outlined,
          title: l10n.premiumEnterCode,
          subtitle: l10n.redeemSubtitle,
          onTap: () => showRedeemCodeDialog(context),
        );
    }
  }

  /// Contact Us opens the support chat once the backend says it is on for
  /// this phone. Until then, and whenever it is off, it opens Telegram, not
  /// email: the channel's direct messages reach the support bot and a
  /// human, and it is where users already are.
  ///
  /// The channel is the one the backend names (AppConfigState.channelUrl),
  /// so it can be changed without a release.
  Widget _buildContactTile(BuildContext context, S l10n) {
    var chat = false;
    try {
      chat = context.watch<SupportState?>()?.enabled ?? false;
    } catch (e) {
      debugPrint('SettingsScreen: support chat not read ($e)');
    }
    final channel = context.watch<AppConfigState>().channelUrl;
    final handle = PlatformVersion.channelHandle(channel);
    return _buildTile(
      context,
      icon: chat ? Icons.chat_bubble_outline_rounded : Icons.send_rounded,
      title: l10n.contactUs,
      subtitle: chat
          ? l10n.supportContactSubtitle
          : handle == null
          ? 'Telegram'
          : 'Telegram · $handle',
      // Telegram opens in its own app; the chat opens here.
      outside: !chat,
      onTap: () {
        if (chat) {
          openSupportChat(context);
          return;
        }
        openOutside(channel);
      },
    );
  }

  Widget _buildLanguageTile(BuildContext context, S l10n) {
    return Consumer<LocaleState>(
      builder: (context, localeState, _) {
        return _buildTile(
          context,
          icon: Icons.translate_rounded,
          title: l10n.language,
          subtitle: l10n.languageSubtitle,
          onTap: () => showLanguagePicker(context, localeState),
        );
      },
    );
  }

  /// The diagnostics switch, with the whole of what it sends written next
  /// to it. That text is Google Play's prominent disclosure: its words and
  /// its place beside the switch stay as they are. A screen reader hears
  /// the title and the text together with the switch, as one control.
  ///
  /// The disclosure is set at the reading size in the secondary color,
  /// not as fine print, because Play asks for it to be prominent. The icon
  /// stands beside the title's line, not beside the middle of a paragraph
  /// eight lines long. The switch stays level with the paragraph, which is
  /// what it turns on.
  Widget _buildShareDiagnosticsTile(BuildContext context) {
    final l10n = S.of(context)!;
    final title = _titleStyle();
    final line =
        MediaQuery.textScalerOf(context).scale(title?.fontSize ?? 16) *
        (title?.height ?? 1.5);
    return MergeSemantics(
      child: Padding(
        // The end inset puts the switch's track as far from the card's
        // edge as the arrows of the other rows: the switch keeps 4 of
        // its own on each side.
        padding: const EdgeInsetsDirectional.fromSTEB(
          SettingsScreen._rowPaddingStart,
          14,
          12,
          14,
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      top: math.max(0, (line - SettingsScreen._iconBox) / 2),
                    ),
                    child: const _IconBox(icon: Icons.troubleshoot_outlined),
                  ),
                  const SizedBox(width: SettingsScreen._iconGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            top: math.max(
                              0,
                              (SettingsScreen._iconBox - line) / 2,
                            ),
                          ),
                          child: Text(l10n.shareDiagnosticsTitle, style: title),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: AppDesign.space2),
                          child: Text(
                            l10n.shareDiagnosticsBody,
                            style: AppDesign.textTheme.bodyMedium?.copyWith(
                              color: AppDesign.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDesign.space8),
            Switch.adaptive(
              value: _shareDiagnostics,
              onChanged: _setShareDiagnostics,
            ),
          ],
        ),
      ),
    );
  }

  /// A row the group draws no divider above, because it brings its own:
  /// see the Notifications rows, which may draw nothing.
  Widget _divided(Widget row) =>
      Column(mainAxisSize: MainAxisSize.min, children: [_rowDivider, row]);

  static const Widget _rowDivider = Divider(
    height: 1,
    thickness: 1,
    indent: SettingsScreen.textInset,
    color: AppDesign.hairline,
  );

  /// A heading over one group. A group after the first gets more room
  /// above its heading than the heading has below it, so the heading
  /// reads as the start of its own group, not the end of the last one.
  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
    bool first = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        top: first ? AppDesign.space16 : AppDesign.space28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(title),
          // The fill is a Material, so the rows' ripple shows on it, and
          // its corners clip the ripple of the first and last row.
          Material(
            color: AppDesign.surfaceLow,
            shape: RoundedRectangleBorder(
              borderRadius: AppDesign.borderRadiusLarge,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, child) in children.indexed) ...[
                  // NoticesStatus rows draw their own divider (_divided).
                  if (i > 0 && child is! NoticesStatus) _rowDivider,
                  child,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle? _titleStyle({bool destructive = false}) =>
      AppDesign.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
        color: destructive ? AppDesign.error : AppDesign.textPrimary,
      );

  TextStyle? _subtitleStyle() =>
      AppDesign.textTheme.bodySmall?.copyWith(color: AppDesign.textTertiary);

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    bool destructive = false,
    bool outside = false,
  }) {
    final Widget? trailing = destructive || onTap == null
        ? null
        : outside
        // Leaves the app: Telegram, the store or the browser.
        ? const Icon(
            Icons.open_in_new_rounded,
            color: AppDesign.textTertiary,
            size: 18,
          )
        : const Icon(
            Icons.chevron_right_rounded,
            color: AppDesign.textTertiary,
            size: 20,
          );
    // Every end mark's ink 16 from the card's edge, as the icon boxes are
    // at the start. The arrow's glyph has about 7 of empty room on each
    // side at this size, and the outside link's about 2.
    final double endPadding = trailing == null
        ? 16
        : outside
        ? 14
        : 9;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: SettingsScreen.rowMinHeight,
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            SettingsScreen._rowPaddingStart,
            12,
            endPadding,
            12,
          ),
          child: Row(
            children: [
              _IconBox(icon: icon, destructive: destructive),
              const SizedBox(width: SettingsScreen._iconGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: _titleStyle(destructive: destructive)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppDesign.space2),
                        child: Text(subtitle, style: _subtitleStyle()),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppDesign.space8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A row's icon in a small rounded square, steel on a raised tone, or the
/// error color for the one row that destroys something.
class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, this.destructive = false});

  final IconData icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: SettingsScreen._iconBox,
      height: SettingsScreen._iconBox,
      decoration: BoxDecoration(
        color: destructive ? AppDesign.errorContainer : AppDesign.surfaceHigh,
        borderRadius: AppDesign.borderRadiusSmall,
      ),
      child: Icon(
        icon,
        color: destructive ? AppDesign.error : AppDesign.steelLight,
        size: 20,
      ),
    );
  }
}
