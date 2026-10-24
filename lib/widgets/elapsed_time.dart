import 'dart:async';

import 'package:flutter/material.dart';

import '../core/design_system.dart';
import '../utils/number_localizer.dart';

/// How long the tunnel has been up, ticking once a second.
///
/// This has to keep its own clock. [VpnService] notifies only on status
/// changes, and `ConnectionInfo.duration` is measured from `DateTime.now()`
/// at the moment it is read, so a widget that reads it during build shows
/// the value frozen at the instant of connecting. It then jumped forward
/// whenever something unrelated rebuilt the tree, which made it look as
/// though the clock only ran while the app was in the background.
///
/// It is its own widget so that a rebuild every second costs one `Text`
/// rather than the whole home screen, which would otherwise re-run the
/// server lookups and the ping guard sixty times a minute.
class ElapsedTime extends StatefulWidget {
  /// When the tunnel came up.
  final DateTime startTime;

  /// Reads the current time.
  ///
  /// Injectable so a test can advance it. The widget deliberately measures
  /// against the wall clock rather than counting its own ticks, because a
  /// timer stops while iOS has the app suspended and a counted clock would
  /// come back minutes behind.
  final DateTime Function() clock;

  const ElapsedTime({
    super.key,
    required this.startTime,
    this.clock = DateTime.now,
  });

  /// The style the time is drawn in. The home screen reads it too, to keep
  /// a slot of the same height before the tunnel is up.
  ///
  /// A label weight, not body text: it is the one number on the home screen
  /// that changes, and at a regular weight Vazirmatn's ring-shaped zero
  /// read as a hole in the line. Tabular figures in Latin script only
  /// ([AppDesign.numberFeatures]), so the digits do not jump as they change.
  static TextStyle get style => AppDesign.textTheme.labelLarge!.copyWith(
    color: AppDesign.protected,
    fontFeatures: AppDesign.numberFeatures,
  );

  /// `m:ss` under an hour, `h:mm:ss` beyond it.
  static String format(Duration elapsed) {
    // A device whose wall clock moves backwards between connecting and now
    // would otherwise render a negative time.
    final d = elapsed.isNegative ? Duration.zero : elapsed;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  State<ElapsedTime> createState() => _ElapsedTimeState();
}

class _ElapsedTimeState extends State<ElapsedTime> {
  Timer? _ticker;

  /// Whether the screen it is on is the one showing. Under another route
  /// the clock does not rebuild, so a connected home screen behind
  /// Settings draws no frame a second for a clock nobody sees. Coming back
  /// rebuilds it, and it reads the wall clock, so it shows the right time
  /// at once.
  bool _shown = true;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _shown) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shown = TickerMode.of(context);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = ElapsedTime.format(
      widget.clock().difference(widget.startTime),
    );
    // Its own layer: the tick repaints this one line, not the power button
    // and the light around it.
    return RepaintBoundary(
      child: Text(
        NumberLocalizer.localize(text, context),
        style: ElapsedTime.style,
      ),
    );
  }
}
