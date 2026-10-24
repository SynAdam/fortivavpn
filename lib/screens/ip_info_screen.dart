import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/design_system.dart';
import '../core/haptics.dart';
import '../data/models/ip_info.dart';
import '../services/ip_info_service.dart';
import '../services/vpn_service.dart';
import '../utils/number_localizer.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/pressable.dart';
import '../widgets/ui/section_label.dart';
import '../l10n/generated/app_localizations.dart';

/// Check my IP: whether the connection is on, and the address the backend
/// saw this phone come from.
///
/// The address comes from Fortiva's own backend only (IpInfoService), and
/// the screen shows only the fields it reported. It makes no claim about
/// what the connection protects: the app checks none of that, and the
/// address shown here can be the phone's own while connected.
class IpInfoScreen extends StatefulWidget {
  const IpInfoScreen({super.key});

  @override
  State<IpInfoScreen> createState() => _IpInfoScreenState();
}

class _IpInfoScreenState extends State<IpInfoScreen> {
  IpInfo? _ipInfo;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchIpInfo();
  }

  Future<void> _fetchIpInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final info = await IpInfoService.fetchIpInfo();
      if (mounted) {
        setState(() {
          _ipInfo = info;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _copy(IpInfo info) {
    Clipboard.setData(ClipboardData(text: info.ip));
    AppHaptics.light();
    final l10n = S.of(context)!;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.ipCopied),
          duration: const Duration(seconds: 1),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnService>();
    final l10n = S.of(context)!;
    final isActive = vpn.isConnected;
    final info = _ipInfo;
    // Asking again with an address on screen keeps the page as it is and
    // turns only the button into a spinner, rather than swapping the whole
    // page for one and back.
    final refreshing = _isLoading && info != null;

    return Scaffold(
      backgroundColor: AppDesign.canvas,
      appBar: AppBar(
        title: Text(l10n.ipInformation),
        backgroundColor: AppDesign.appBarColor,
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: refreshing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppDesign.steelLight,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 22),
            // Stays on while a lookup runs, so a TV remote keeps its focus
            // on it; a press then does nothing.
            onPressed: () {
              if (!_isLoading) _fetchIpInfo();
            },
          ),
        ],
      ),
      body: _isLoading && info == null
          ? const Center(
              child: CircularProgressIndicator(color: AppDesign.steelLight),
            )
          : ListView(
              padding: AppDesign.clearOfNavBar(
                context,
                const EdgeInsets.fromLTRB(16, 8, 16, 24),
              ),
              children: [
                _StatusCard(active: isActive),
                const SizedBox(height: AppDesign.space24),
                SectionLabel(l10n.ipAddressLabel),
                // No answer and an error read the same to the user: the
                // address could not be read, and they can ask again.
                if (info == null || _error != null)
                  _LookupFailed(onRetry: _fetchIpInfo)
                else
                  _AddressGroup(
                    info: info,
                    onCopy: () => _copy(info),
                    rows: _details(context, info),
                  ),
              ],
            ),
    );
  }

  /// The rows the backend reported beyond the address. A row reading
  /// "Unknown" or "0.0, 0.0" is worse than no row, so empty fields are
  /// left out.
  List<(String, String)> _details(BuildContext context, IpInfo info) {
    final l10n = S.of(context)!;
    return [
      if (info.country.isNotEmpty)
        (
          l10n.ipLocation,
          info.city.isEmpty ? info.country : '${info.country}, ${info.city}',
        ),
      if (info.isp.isNotEmpty) (l10n.ipProvider, info.isp),
      if (info.org.isNotEmpty) (l10n.ipOrganization, info.org),
      if (info.timezone.isNotEmpty) (l10n.ipTimeZone, info.timezone),
      if (info.lat != 0 || info.lon != 0)
        (
          l10n.ipCoordinates,
          NumberLocalizer.localizeAmount('${info.lat}, ${info.lon}', context),
        ),
    ];
  }
}

/// The address and what the backend reported with it, as one card: the
/// address first, then a row for each field, divided by hairlines.
class _AddressGroup extends StatelessWidget {
  const _AddressGroup({
    required this.info,
    required this.onCopy,
    required this.rows,
  });

  final IpInfo info;
  final VoidCallback onCopy;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    // A Material, so the address row's ripple shows on the card, and its
    // corners clip that ripple.
    return Material(
      color: AppDesign.surfaceLow,
      shape: RoundedRectangleBorder(borderRadius: AppDesign.borderRadiusLarge),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _AddressCard(info: info, onCopy: onCopy),
          for (final (label, value) in rows) ...[
            const Divider(
              height: 1,
              thickness: 1,
              indent: AppDesign.space16,
              endIndent: AppDesign.space16,
              color: AppDesign.hairline,
            ),
            _DetailRow(label: label, value: value),
          ],
        ],
      ),
    );
  }
}

/// Whether the connection is on, in words and with a shield. Only the
/// state: a line about what it protects would be a claim the app does not
/// check.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final text = AppDesign.textTheme;
    // The top card carries the screen: the state is its largest words.
    // The disc is the size of a flag disc in the lists.
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: active
                  ? AppDesign.protectedContainer
                  : AppDesign.surfaceHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(
              active ? Icons.shield_rounded : Icons.shield_outlined,
              color: active ? AppDesign.protected : AppDesign.steelMid,
              size: 20,
            ),
          ),
          const SizedBox(width: AppDesign.space16),
          Expanded(
            child: Text(
              active ? l10n.statusConnected : l10n.statusDisconnected,
              style: text.titleLarge?.copyWith(
                color: active ? AppDesign.protected : AppDesign.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The address itself, the first row of its card. A tap anywhere on it
/// copies it.
class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.info, required this.onCopy});

  final IpInfo info;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final copy = MaterialLocalizations.of(context).copyButtonLabel;
    // No fill and no corners of its own: the card under it has both.
    return Pressable(
      onTap: onCopy,
      semanticsLabel: copy,
      color: Colors.transparent,
      borderRadius: BorderRadius.zero,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 12, 16),
      child: Row(
        children: [
          Expanded(
            // An address is Latin machine text, read left to right in
            // every language.
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: AlignmentDirectional.centerStart.resolve(
                  Directionality.of(context),
                ),
                child: Text(
                  info.ip,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppDesign.textTheme.headlineSmall?.copyWith(
                    fontFeatures: AppDesign.numberFeatures,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDesign.space12),
          const Icon(
            Icons.copy_rounded,
            color: AppDesign.textTertiary,
            size: 20,
          ),
        ],
      ),
    );
  }
}

/// One reported field: its name at the start, its value at the end.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = AppDesign.textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesign.space16,
          vertical: AppDesign.space8,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: text.bodyMedium?.copyWith(color: AppDesign.textTertiary),
            ),
            const SizedBox(width: AppDesign.space16),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(color: AppDesign.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What shows in place of the address when it could not be read.
class _LookupFailed extends StatelessWidget {
  const _LookupFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    // The button sits under the message, not beside it: at a large text
    // size a long "Try again" beside the line left the line no room.
    return AppCard(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppDesign.space8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: AppDesign.textTertiary,
                  size: 20,
                ),
                const SizedBox(width: AppDesign.space12),
                Expanded(
                  child: Text(
                    l10n.ipCheckFailed,
                    style: AppDesign.textTheme.bodyMedium?.copyWith(
                      color: AppDesign.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: onRetry,
              child: Text(l10n.myServersRetry),
            ),
          ),
        ],
      ),
    );
  }
}
