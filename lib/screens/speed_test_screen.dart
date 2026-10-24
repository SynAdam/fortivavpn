import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/design_system.dart';
import '../core/haptics.dart';
import '../services/speed_test_service.dart';
import '../services/vpn_service.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/number_localizer.dart';

/// The speed test: a gauge with the download speed, two tiles for upload
/// and response time, and one button at the bottom.
///
/// The numbers come from [SpeedTestService] as they are. The gauge shows
/// zero until a result arrives, as before, and then sweeps once to it. It
/// never moves to suggest a reading the test has not made.
class SpeedTestScreen extends StatelessWidget {
  const SpeedTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final speedTest = context.watch<SpeedTestService>();
    final vpn = context.watch<VpnService>();
    final l10n = S.of(context)!;
    final text = AppDesign.textTheme;

    final result = speedTest.lastResult;
    final running = speedTest.isRunning;
    final downloadMbps = result?.downloadMbps ?? 0.0;
    final pingMs = result?.pingMs;

    return Scaffold(
      backgroundColor: AppDesign.canvas,
      appBar: AppBar(
        title: Text(l10n.speedTest),
        backgroundColor: AppDesign.appBarColor,
      ),
      // The one action sits at the bottom, where the thumb is, and does
      // not float in the middle of a tall phone. The readings above it
      // scroll when a small phone or large text needs the room.
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              children: [
                Center(child: _RouteChip(connected: vpn.isConnected)),
                const SizedBox(height: AppDesign.space24),
                Center(
                  child: _SpeedGauge(
                    mbps: downloadMbps,
                    label: l10n.download,
                    unit: l10n.speedTestUnit,
                  ),
                ),
                const SizedBox(height: AppDesign.space8),
                // A reserved line, so the screen does not jump when a run
                // starts.
                SizedBox(
                  height: 4,
                  child: running
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: speedTest.progress,
                            minHeight: 4,
                            color: AppDesign.steelLight,
                            backgroundColor: AppDesign.surfaceHighest,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: AppDesign.space12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _phaseLine(l10n, speedTest),
                    textAlign: TextAlign.center,
                    style: text.bodyMedium,
                  ),
                ),
                const SizedBox(height: AppDesign.space24),
                // Before a result the tiles show their labels and no number.
                // A muted "0 ms" read as a perfect measurement.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _ResultTile(
                        icon: Icons.upload_rounded,
                        label: l10n.upload,
                        value: result == null
                            ? null
                            : NumberLocalizer.localizeAmount(
                                result.uploadMbps.toStringAsFixed(1),
                                context,
                              ),
                        unit: l10n.speedTestUnit,
                      ),
                    ),
                    const SizedBox(width: AppDesign.space12),
                    Expanded(
                      child: _ResultTile(
                        icon: Icons.timer_outlined,
                        label: l10n.ping,
                        value: pingMs == null
                            ? null
                            : pingMs < 0
                            ? l10n.timeout
                            : NumberLocalizer.localize('$pingMs', context),
                        // "ms" as LatencyChip and History write it: the same
                        // short unit in every language.
                        unit: pingMs != null && pingMs < 0 ? '' : 'ms',
                        muted: pingMs != null && pingMs < 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: AppDesign.clearOfNavBar(
              context,
              const EdgeInsets.fromLTRB(16, 8, 16, 16),
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                // Stays enabled while the test runs and ignores taps, so a
                // TV remote's focus does not jump away from it. A second
                // run would not start anyway (SpeedTestService.runTest).
                onPressed: running
                    ? () {}
                    : () {
                        AppHaptics.tap();
                        speedTest.runTest();
                      },
                child: running
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppDesign.onBrand,
                            ),
                          ),
                          const SizedBox(width: AppDesign.space12),
                          Text(l10n.speedTestRunning),
                        ],
                      )
                    : Text(
                        result == null
                            ? l10n.speedTestStart
                            : l10n.speedTestAgain,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// What the test is doing, in the phone's language.
  ///
  /// The service names its phases in English for its own log. The screen
  /// reads the stage from the progress it reports instead: the service
  /// moves it to 0.2 when the ping is done and to 0.8 when the download is.
  static String _phaseLine(S l10n, SpeedTestService svc) {
    if (svc.isRunning) {
      if (svc.progress < 0.2) return l10n.speedTestPhasePing;
      if (svc.progress < 0.8) return l10n.speedTestPhaseDownload;
      return l10n.speedTestPhaseUpload;
    }
    if (svc.lastResult != null) return l10n.speedTestDone;
    // A run ended without a result: the service names a phase only once a
    // run has started, and clears the result when it starts.
    if (svc.phase.isNotEmpty) return l10n.speedTestFailed;
    return l10n.speedTestIdle;
  }
}

/// Which way the test goes: through the tunnel while connected, or over
/// the phone's own connection.
class _RouteChip extends StatelessWidget {
  const _RouteChip({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final color = connected ? AppDesign.protected : AppDesign.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesign.space12,
        vertical: AppDesign.space8,
      ),
      decoration: BoxDecoration(
        color: connected ? AppDesign.protectedContainer : AppDesign.surfaceLow,
        borderRadius: const BorderRadius.all(
          Radius.circular(AppDesign.radiusFull),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppDesign.space8),
          Flexible(
            child: Text(
              connected ? l10n.testingViaVpn : l10n.testingDirect,
              style: AppDesign.textTheme.labelMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// A 270 degree dial with the download speed in its middle.
///
/// The arc follows a log scale, so a slow line still lights part of the
/// dial and a fast one does not pin it. It sweeps to a new result once,
/// and not at all under reduce motion.
class _SpeedGauge extends StatelessWidget {
  const _SpeedGauge({
    required this.mbps,
    required this.label,
    required this.unit,
  });

  final double mbps;
  final String label;
  final String unit;

  static const double diameter = 240;

  /// The dial is open at the bottom, so its box ends just under the ends
  /// of the arc instead of leaving the empty quarter as a gap.
  static const double boxHeight = 212;

  /// The speed the full dial stands for. Faster lines stay at the end.
  static const double topMbps = 1000;

  static double fractionFor(double mbps) {
    if (mbps <= 0) return 0;
    final f = math.log(1 + mbps) / math.log(1 + topMbps);
    return f.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppDesign.textTheme;
    final shown = mbps > 0;
    final target = fractionFor(mbps);
    final reduced = AppMotion.reduced(context);
    // The middle of the circle as an alignment inside the shorter box.
    const middle = Alignment(0, diameter / boxHeight - 1);
    return SizedBox(
      width: diameter,
      height: boxHeight,
      child: Stack(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: target),
            duration: reduced ? Duration.zero : AppMotion.hero,
            curve: AppMotion.emphasizedDecelerate,
            builder: (context, value, _) => CustomPaint(
              size: const Size(diameter, boxHeight),
              painter: GaugePainter(fraction: value),
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: middle,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: text.labelMedium),
                  const SizedBox(height: AppDesign.space4),
                  Text(
                    // At rest a plain muted zero: "0.0" read as two
                    // digits around a stray dot.
                    shown
                        ? NumberLocalizer.localizeAmount(
                            mbps.toStringAsFixed(1),
                            context,
                          )
                        : NumberLocalizer.localize('0', context),
                    maxLines: 1,
                    style: text.displayMedium?.copyWith(
                      color: shown
                          ? AppDesign.textPrimary
                          : AppDesign.textTertiary,
                      fontFeatures: AppDesign.numberFeatures,
                    ),
                  ),
                  Text(unit, style: text.titleSmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the speed dial: a 270 degree track open at the bottom, and the
/// lit part of it from steel to protected green. Public so a test can
/// read the share it draws.
class GaugePainter extends CustomPainter {
  GaugePainter({required this.fraction});

  /// How much of the arc is lit, 0 to 1.
  final double fraction;

  static const double stroke = 10;

  /// The arc starts at the lower left and runs clockwise to the lower
  /// right, leaving the bottom quarter open.
  static const double startAngle = 0.75 * math.pi;
  static const double sweepAngle = 1.5 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    // The circle fills the width. The box may be shorter than it, since
    // the bottom quarter of the circle is never drawn.
    final radius = (size.width - stroke) / 2;
    final center = Offset(size.width / 2, size.width / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppDesign.surfaceHighest;
    canvas.drawArc(rect, startAngle, sweepAngle, false, track);

    final lit = fraction.clamp(0.0, 1.0);
    if (lit <= 0) return;
    // The round cap reaches a little behind the start of the arc. The
    // gradient starts that much earlier, so the cap is steel too.
    final cap = (stroke / 2) / radius;
    final value = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        endAngle: sweepAngle + 2 * cap,
        colors: const [AppDesign.steelLight, AppDesign.protected],
        transform: GradientRotation(startAngle - cap),
      ).createShader(rect);
    canvas.drawArc(rect, startAngle, sweepAngle * lit, false, value);
  }

  @override
  bool shouldRepaint(GaugePainter old) => old.fraction != fraction;
}

/// One result under the dial: an icon and a label, then the value with its
/// unit.
class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.muted = false,
  });

  final IconData icon;
  final String label;

  /// Null before there is a result: the line keeps its height, so the
  /// tile does not grow when the result arrives, and shows a still bar in
  /// place of a number.
  final String? value;
  final String unit;

  /// Drawn quieter, for a timeout.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final text = AppDesign.textTheme;
    // The tile shape of the invite screen's stat tiles. The label in the
    // dial's label color, and the icon a step quieter than its words.
    return Container(
      padding: const EdgeInsets.all(AppDesign.space12),
      decoration: BoxDecoration(
        color: AppDesign.surfaceLow,
        borderRadius: AppDesign.borderRadiusMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppDesign.textTertiary),
              const SizedBox(width: AppDesign.space6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(
                    color: AppDesign.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.space8),
          Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              Visibility(
                visible: value != null,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: AppDesign.space4,
                  children: [
                    // A hidden stand in before a result, only to keep the
                    // line's height.
                    Text(
                      value ?? '0',
                      style: text.headlineSmall?.copyWith(
                        color: muted
                            ? AppDesign.textTertiary
                            : AppDesign.textPrimary,
                        fontFeatures: AppDesign.numberFeatures,
                      ),
                    ),
                    if (value != null && unit.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(unit, style: text.labelMedium),
                      ),
                  ],
                ),
              ),
              // Not measured yet: a still bar where the value goes, so the
              // tile does not look empty or broken. It claims no number and
              // draws no frames.
              if (value == null)
                ExcludeSemantics(
                  child: Container(
                    key: const ValueKey('speed-tile-placeholder'),
                    width: 40,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppDesign.surfaceHigh,
                      borderRadius: AppDesign.borderRadiusXSmall,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
