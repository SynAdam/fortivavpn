import 'package:flutter/material.dart';
import '../core/design_system.dart';
import '../data/models/server.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/vless_link.dart';
import 'server_title.dart';
import 'ui/pressable.dart';
import 'ui/signal_bars.dart';

/// One shared server in the Locations list, with its latency and the way
/// to measure it.
///
/// The name is the loudest thing on the tile: a place for one of our
/// servers, the country or the number for a community link
/// ([serverTitle]). Below it, see [subtitleFor]. A line that would say
/// nothing is left out.
class ServerCard extends StatelessWidget {
  final Server server;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onPing;
  final bool isPinging;
  final bool isQueued;
  final int? pingResult; // -1 = timeout, null = not pinged, >0 = ms

  /// A small line above the name, such as "Fastest". The lead row of the
  /// community list is this same widget with a heading, so a row that
  /// moves into the lead keeps its element and a TV remote's focus.
  final Widget? heading;

  /// Whether the tunnel is up. See [ServerRow.live].
  final bool live;

  const ServerCard({
    super.key,
    required this.server,
    required this.isSelected,
    required this.onTap,
    this.onPing,
    this.isPinging = false,
    this.isQueued = false,
    this.pingResult,
    this.heading,
    this.live = true,
  });

  /// The second line of a tile.
  ///
  /// For one of our servers, where it is. For a community link, how it is
  /// secured and the port: what a user who knows what is blocked on their
  /// network can act on. Not the host: a raw address or someone else's
  /// hostname tells a user nothing and tells a screenshot too much.
  static String subtitleFor(Server server) {
    if (server.isCommunity) {
      final uri = server.connectionUri;
      final security = VlessLink.security(uri);
      final how = security == 'none' ? VlessLink.transport(uri) : security;
      return [how.toUpperCase(), '${VlessLink.port(uri)}'].join(' · ');
    }
    if (server.country.isEmpty) return server.city;
    if (server.city.isNotEmpty && server.city != server.country) {
      return '${server.country} · ${server.city}';
    }
    return server.country;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    // The chosen row says "In use" beside the name, as on Your servers, so
    // one mark means the chosen server on both lists. Only the premium
    // badge earns its place besides: a "FREE" badge on every tile of a
    // free list said nothing.
    final inUse = isSelected
        ? InUseBadge(label: l10n.myServersInUse, live: live)
        : null;
    final premium = server.isPremium ? _PremiumTag(label: l10n.proBadge) : null;
    return ServerRow(
      flag: server.flagEmoji,
      title: serverTitle(context, server),
      subtitle: subtitleFor(server),
      heading: heading,
      isSelected: isSelected,
      live: live,
      onTap: onTap,
      badge: inUse != null && premium != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                inUse,
                const SizedBox(width: AppDesign.space4),
                premium,
              ],
            )
          : inUse ?? premium,
      trailing: [_pingIndicator(l10n)],
    );
  }

  /// The latency, the way to measure it, or that a measurement is coming.
  Widget _pingIndicator(S l10n) {
    if (isPinging) return const _PingWait(running: true);
    final ms = pingResult;
    if (ms != null) return LatencyChip(ms: ms, timeoutLabel: l10n.timeout);
    if (isQueued) return const _PingWait(running: false);
    final onPing = this.onPing;
    if (onPing != null) return PingPill(label: l10n.ping, onTap: onPing);
    return const SizedBox.shrink();
  }
}

/// The row both server lists draw: the flag in a disc, the name, one quiet
/// line under it, and what the row can do at its end.
///
/// Your servers and the community list drew their rows two ways, so one
/// server looked like two different things. The chosen row gets an edge,
/// protected while the tunnel is up. Color is never the only sign of it,
/// so callers add the "In use" badge as well.
class ServerRow extends StatelessWidget {
  const ServerRow({
    super.key,
    required this.flag,
    required this.title,
    required this.onTap,
    this.heading,
    this.subtitle,
    this.badge,
    this.trailing = const [],
    this.isSelected = false,
    this.live = true,
    this.endPadding = AppDesign.space12,
  });

  /// The flag emoji. Empty draws a globe.
  final String flag;
  final String title;
  final VoidCallback onTap;

  /// A small line above the title, such as "Fastest".
  final Widget? heading;

  /// The second line, kept as its caller wrote it.
  final String? subtitle;

  /// Beside the title, such as the "In use" pill.
  final Widget? badge;

  /// At the end of the row: the latency, the Ping pill, Copy link.
  final List<Widget> trailing;
  final bool isSelected;

  /// Whether the tunnel is up. The chosen row's edge is protected green
  /// only then, because on home that green means protected. With the VPN
  /// off, which is often when this list is opened, the edge is steel.
  final bool live;

  /// Space after the last trailing widget. An IconButton at the end
  /// carries its own, so its row passes less.
  final double endPadding;

  /// Every row is at least this tall.
  static const double minHeight = 72;
  static const double _verticalPadding = 12;

  @override
  Widget build(BuildContext context) {
    final text = AppDesign.textTheme;
    final subtitle = this.subtitle;
    final heading = this.heading;
    final badge = this.badge;
    // Only the chosen row says it is selected. Saying "not selected" on
    // every other row would only add noise for a screen reader.
    return Semantics(
      selected: isSelected ? true : null,
      child: Pressable(
        onTap: onTap,
        color: AppDesign.surfaceLow,
        border: isSelected
            ? BorderSide(
                color: live ? AppDesign.protected : AppDesign.steelLight,
                width: 1.5,
              )
            : BorderSide.none,
        padding: EdgeInsetsDirectional.fromSTEB(
          AppDesign.space12,
          _verticalPadding,
          endPadding,
          _verticalPadding,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: minHeight - 2 * _verticalPadding,
          ),
          child: Row(
            children: [
              FlagDisc(flag: flag),
              const SizedBox(width: AppDesign.space12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (heading != null) ...[
                      heading,
                      const SizedBox(height: AppDesign.space2),
                    ],
                    // The name is what the row has to show, so it gets the
                    // whole width. The badge goes under it when both do not
                    // fit: in a Row beside a Persian "In use" and the
                    // latency, a 360dp phone cut "Nuremberg" to "N...".
                    Wrap(
                      spacing: AppDesign.space8,
                      runSpacing: AppDesign.space4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium,
                        ),
                        ?badge,
                      ],
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: AppDesign.space2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: AppDesign.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing.isNotEmpty) ...[
                const SizedBox(width: AppDesign.space8),
                ...trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A flag emoji in a round steel disc, the leading mark of a server row.
///
/// The emoji is drawn at a fixed size: it is a picture, not text, and at a
/// large text size it would spill out of its disc. Screen readers skip it,
/// because the row's title already names the place.
class FlagDisc extends StatelessWidget {
  const FlagDisc({
    super.key,
    required this.flag,
    this.size = 40,
    this.spent = false,
  });

  /// The emoji, or empty for the steel globe. A [placeholderFlags] globe
  /// draws the steel globe too, so a server with no country looks the same
  /// on home, the server lists and History.
  final String flag;
  final double size;

  /// The home card's look while the day's data is used up: an hourglass
  /// on the error tone in place of the flag.
  final bool spent;

  /// The globes the app stores for a server or a session with no country.
  /// Each is a full-color picture, so the disc draws its steel globe for
  /// them instead. Only the drawing changes; the server or session keeps
  /// what it saved.
  static const placeholderFlags = {'\u{1F310}', '\u{1F30D}'};

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: spent ? AppDesign.errorContainer : AppDesign.surfaceHigh,
          shape: BoxShape.circle,
        ),
        child: spent
            ? Icon(
                Icons.hourglass_empty_rounded,
                size: size / 2,
                color: AppDesign.error,
              )
            : flag.isEmpty || placeholderFlags.contains(flag)
            ? Icon(
                Icons.public_rounded,
                size: size / 2,
                color: AppDesign.textTertiary,
              )
            : Text(
                flag,
                textScaler: TextScaler.noScaling,
                style: TextStyle(fontSize: size / 2, height: 1.0),
              ),
      ),
    );
  }
}

/// The text style of the small pills and headings on a server row.
///
/// labelSmall (11.5sp) in Latin scripts. In Persian, Arabic and Urdu it is
/// labelMedium (13sp): Vazirmatn at 11.5sp drew "در حال استفاده" 11dp tall,
/// under the 12.5sp floor for secondary text in those scripts.
TextStyle? serverRowLabelStyle(BuildContext context) {
  final text = AppDesign.textTheme;
  return Directionality.of(context) == TextDirection.rtl
      ? text.labelMedium
      : text.labelSmall;
}

/// The "In use" mark beside the name of the server a device is on.
class InUseBadge extends StatelessWidget {
  const InUseBadge({super.key, required this.label, this.live = true});

  final String label;

  /// Whether the tunnel is up. The pill is protected green only then; with
  /// the VPN off it is a neutral steel pill. See [ServerRow.live].
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesign.space8,
        vertical: AppDesign.space2,
      ),
      decoration: BoxDecoration(
        color: live ? AppDesign.protectedContainer : AppDesign.surfaceHighest,
        borderRadius: const BorderRadius.all(
          Radius.circular(AppDesign.radiusFull),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: serverRowLabelStyle(context)?.copyWith(
          color: live ? AppDesign.protected : AppDesign.textSecondary,
        ),
      ),
    );
  }
}

/// The "Ping" control on a row: a small pill with a full 48dp tap area of
/// its own, so a tap on it measures the server and never picks it.
class PingPill extends StatelessWidget {
  const PingPill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  /// The same height as the Test all pill, so the two pills on one screen
  /// match.
  static const double _pillHeight = 32;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Container(
                height: _pillHeight,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDesign.space12,
                ),
                // No border: the fill is already a tonal step above the
                // row, and a border on top doubled the edge on every row.
                decoration: const BoxDecoration(
                  color: AppDesign.surfaceHigh,
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppDesign.radiusFull),
                  ),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppDesign.textTheme.labelMedium?.copyWith(
                    color: AppDesign.steelLight,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Test all control in a server list's app bar: an outlined steel pill
/// with a 48dp tap area. It is a utility, so it is not in the brand color,
/// which is for primary actions and offers.
///
/// While a run is going it shows a spinner. With [onStop] it turns into a
/// Stop pill in the error color that ends the run. Without one it keeps
/// its place and ignores taps, so a TV remote's focus does not jump away
/// from a control that went disabled.
class TestAllButton extends StatelessWidget {
  const TestAllButton({
    super.key,
    required this.label,
    required this.onTest,
    this.busy = false,
    this.busyLabel,
    this.onStop,
  });

  /// "Test all".
  final String label;
  final VoidCallback onTest;
  final bool busy;

  /// What the pill says during a run that cannot be stopped.
  final String? busyLabel;

  /// Ends a run. When set, a busy pill reads [busyLabel] in the error color.
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final stoppable = busy && onStop != null;
    final color = !busy
        ? AppDesign.steelLight
        : stoppable
        ? AppDesign.error
        : AppDesign.textSecondary;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppDesign.space8),
      child: Center(
        child: OutlinedButton(
          onPressed: !busy ? onTest : (onStop ?? () {}),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            // The control edge outline, as the theme's outlined buttons
            // have. Stop keeps an edge in its own color.
            side: BorderSide(
              color: stoppable
                  ? AppDesign.error.withValues(alpha: 0.7)
                  : AppDesign.outline,
            ),
            shape: const StadiumBorder(),
            // As tall as the Ping pill on the rows below it. The padded
            // tap target keeps the 48dp hit area.
            minimumSize: const Size(48, 32),
            padding: const EdgeInsets.symmetric(horizontal: AppDesign.space12),
            tapTargetSize: MaterialTapTargetSize.padded,
            textStyle: AppDesign.textTheme.labelMedium,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[
                SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                ),
                const SizedBox(width: AppDesign.space8),
              ],
              Text(busy ? (busyLabel ?? label) : label, maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Premium tag on a premium row: the crest's container color with its
/// own text color, which reads at small sizes where white on the brand
/// gradient did not.
class _PremiumTag extends StatelessWidget {
  const _PremiumTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesign.space8,
        vertical: AppDesign.space2,
      ),
      decoration: const BoxDecoration(
        color: AppDesign.brandContainer,
        borderRadius: BorderRadius.all(Radius.circular(AppDesign.radiusFull)),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: serverRowLabelStyle(
          context,
        )?.copyWith(color: AppDesign.onBrandContainer),
      ),
    );
  }
}

/// Where the latency will be: a spinner while this row is measured, and a
/// still mark while it waits its turn in a Test all run. The waiting mark
/// does not move, so a long queue draws no frames.
class _PingWait extends StatelessWidget {
  const _PingWait({required this.running});

  final bool running;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 32,
      child: Center(
        child: running
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppDesign.steelLight,
                ),
              )
            : const Icon(
                Icons.more_horiz_rounded,
                size: 20,
                color: AppDesign.textTertiary,
              ),
      ),
    );
  }
}
