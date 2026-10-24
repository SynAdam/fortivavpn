import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../api/config_service.dart';

/// The backup network, from the app config's `psiphon` block (clients
/// issue #299).
///
/// When a tap and its keep-searching round end without a tunnel through
/// our doors or the community links, the connect flow can dial this
/// network by itself. It is off unless the backend sends a block with a
/// [network]: a block that is missing, is not an object, or has no network
/// reads as null, and null is off. Every other field that is missing or
/// cannot be read takes the default shown on it, and never throws away the
/// rest of the config.
///
/// Whether this phone may use it is decided by the backend per device, in
/// the answer to /configs/dedicated (DedicatedState.psiphon). [enabled]
/// stands in only on a phone that has never had that answer.
@immutable
class PsiphonSettings {
  const PsiphonSettings({
    required this.network,
    this.enabled = false,
    this.egressRegion = '',
    this.establishTimeout = defaultEstablishTimeout,
    this.startAfter,
    this.afterRounds = 0,
    this.everyRounds = 1,
    this.stages = defaultStages,
    this.tv = false,
    this.serverEntriesSha,
  });

  /// The network's own settings, passed to the tunnel unchanged except for
  /// the keys the phone sets itself ([deviceKeys]). Never empty.
  final Map<String, Object?> network;

  /// Whether the backend has the network on for every phone. Used only by
  /// a phone that has no per-device answer yet.
  final bool enabled;

  /// Where the network's traffic leaves, as two capital letters, or empty
  /// for "the network picks". The network treats it as a strict filter.
  final String egressRegion;

  /// How long the network gets to come up before the attempt is failed.
  final Duration establishTimeout;

  /// How long a tap looks for a door or a link before it stops looking and
  /// the network is dialled (`start_after_ms`). It counts only on a tap
  /// where every gate that does not wait on how the tap ends is open, see
  /// ConnectFlow._cutSearch. Null, when the backend sends none or a value
  /// out of range, lets every tap end on its own first, as before.
  final Duration? startAfter;

  /// The shortest and the longest [startAfter] the app takes from the
  /// backend, the range of its PSIPHON_START_AFTER_MS.
  static const shortestStartAfter = Duration(seconds: 3);
  static const longestStartAfter = Duration(minutes: 2);

  /// The first keep-searching round at which the network may be dialled:
  /// 0 is the tap itself.
  final int afterRounds;

  /// After [afterRounds], the network is dialled on every this many rounds.
  final int everyRounds;

  /// The words of the tap endings that may start the network, as the
  /// connect trace spells them ([endings]).
  final Set<String> stages;

  /// Whether a TV may use the network.
  final bool tv;

  /// The sha256 of the network's server list that the backend serves at
  /// /app/psiphon/server-entries, as 64 lowercase hex characters, or null
  /// when it serves none. See PsiphonEntries, which keeps the list on the
  /// phone for the tunnel.
  final String? serverEntriesSha;

  static const defaultEstablishTimeout = Duration(seconds: 60);

  /// The longest [establishTimeout] the app takes from the backend. A
  /// longer one keeps the button turning for longer than anyone waits.
  static const longestEstablishTimeout = Duration(minutes: 10);

  static const defaultStages = {'all_closed', 'failed', 'cut_off'};

  /// Every ending word [stages] can name.
  static const endings = {'all_closed', 'failed', 'cut_off', 'no_internet'};

  /// Keys the phone owns. The backend strips them from [network], and they
  /// are left out here too, so a value the backend sends by mistake never
  /// reaches the tunnel. The tunnel sets the ones it needs itself, and the
  /// exit region comes from [egressRegion].
  static const deviceKeys = {
    'DataRootDirectory',
    'LocalSocksProxyPort',
    'LocalHttpProxyPort',
    'DisableLocalHTTPProxy',
    'EgressRegion',
    'ClientPlatform',
    'ClientVersion',
    'EstablishTunnelTimeoutSeconds',
    'EmitDiagnosticNotices',
  };

  /// The settings in force, read by the connect flow and the tunnel, which
  /// live outside the widget tree. Set by AppConfigState.
  static PsiphonSettings? current;

  static final _region = RegExp(r'^[A-Z]{2}$');

  static final _sha = RegExp(r'^[0-9a-f]{64}$');

  /// The settings in [json], or null when the block is off.
  static PsiphonSettings? fromJson(Object? json) {
    if (json is! Map) return null;
    final raw = json['network'];
    if (raw is! Map) return null;
    final network = <String, Object?>{
      for (final e in raw.entries)
        if (e.key is String && !deviceKeys.contains(e.key))
          e.key as String: e.value,
    };
    if (network.isEmpty) return null;
    final region = json['egress_region'];
    final timeout = json['establish_timeout_seconds'];
    final startAfter = json['start_after_ms'];
    final after = json['after_rounds'];
    final every = json['every_rounds'];
    final stages = json['stages'];
    final sha = json['server_entries_sha'];
    return PsiphonSettings(
      network: Map.unmodifiable(network),
      enabled: json['enabled'] == true,
      egressRegion: region is String && _region.hasMatch(region) ? region : '',
      establishTimeout:
          timeout is int &&
              timeout > 0 &&
              timeout <= longestEstablishTimeout.inSeconds
          ? Duration(seconds: timeout)
          : defaultEstablishTimeout,
      startAfter:
          startAfter is int &&
              startAfter >= shortestStartAfter.inMilliseconds &&
              startAfter <= longestStartAfter.inMilliseconds
          ? Duration(milliseconds: startAfter)
          : null,
      afterRounds: after is int && after >= 0 ? after : 0,
      everyRounds: every is int && every >= 1 ? every : 1,
      // A list names the endings it holds, and only the words the app
      // knows. Anything else is the default.
      stages: stages is List
          ? Set.unmodifiable({
              for (final s in stages)
                if (s is String && endings.contains(s)) s,
            })
          : defaultStages,
      tv: json['tv'] == true,
      serverEntriesSha: sha is String && _sha.hasMatch(sha) ? sha : null,
    );
  }

  /// Whether the keep-searching round [round] may dial the network: 0 is
  /// the tap, n the try after the n-th wait.
  bool allowsRound(int round) =>
      round >= afterRounds && (round - afterRounds) % everyRounds == 0;

  /// What the tunnel is given: [network], with the exit region when one is
  /// set, as one JSON object.
  String get tunnelConfig => jsonEncode({
    ...network,
    if (egressRegion.isNotEmpty) 'EgressRegion': egressRegion,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'network': network,
    'egress_region': egressRegion,
    'establish_timeout_seconds': establishTimeout.inSeconds,
    'start_after_ms': ?startAfter?.inMilliseconds,
    'after_rounds': afterRounds,
    'every_rounds': everyRounds,
    'stages': stages.toList(),
    'tv': tv,
    'server_entries_sha': serverEntriesSha,
  };
}

/// What this device's last answers from the backend say about the backup
/// network, read when the connect flow is about to dial it.
@immutable
class PsiphonDevice {
  const PsiphonDevice({
    this.allowed,
    this.blocked = false,
    this.quota,
    this.quotaFresh = false,
  });

  /// The `psiphon` field of the last /configs/dedicated answer, or null
  /// when no answer this phone kept had one.
  final bool? allowed;

  /// Whether the allowance is spent (DedicatedState.isBlocked).
  final bool blocked;

  /// The allowance as the phone last heard it.
  final QuotaStatus? quota;

  /// Whether [quota] is the backend's answer to the last refresh, rather
  /// than one kept from before.
  final bool quotaFresh;

  /// Whether [quota] says nothing is left: spent, or no bytes remaining on
  /// a metered allowance.
  bool get quotaSpent {
    final q = quota;
    if (q == null) return false;
    if (q.blocked) return true;
    return !q.unlimited && q.limitBytes > 0 && q.remainingBytes <= 0;
  }
}
