import '../data/models/server.dart';

/// Order a shared list for display.
///
/// Tested rows come first, fastest first, and timeouts go last. Between
/// them sit the rows nobody has tested yet. Those used to sit in crawl
/// order, because every untested row scored the same, which made the
/// community list unreadable until Test all had run. They are now
/// grouped by country, with rows that name no country after the ones
/// that do.
///
/// Ties keep their incoming order, so a rebuild never reshuffles the list
/// under the user's thumb.
List<Server> sortForDisplay(
  List<Server> servers,
  int? Function(Server server) latencyOf,
) {
  int band(Server s) {
    final latency = latencyOf(s);
    if (latency == null) return s.country.isEmpty ? 2 : 1;
    return latency < 0 ? 3 : 0;
  }

  final indexed = [for (var i = 0; i < servers.length; i++) (i, servers[i])];
  indexed.sort((a, b) {
    final bandA = band(a.$2);
    final bandB = band(b.$2);
    if (bandA != bandB) return bandA.compareTo(bandB);
    if (bandA == 0) {
      final byLatency = latencyOf(a.$2)!.compareTo(latencyOf(b.$2)!);
      if (byLatency != 0) return byLatency;
    } else if (bandA == 1) {
      final byCountry = a.$2.country.compareTo(b.$2.country);
      if (byCountry != 0) return byCountry;
    }
    return a.$1.compareTo(b.$1);
  });
  return [for (final entry in indexed) entry.$2];
}
