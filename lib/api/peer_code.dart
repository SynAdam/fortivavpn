/// The fallback file (BootstrapFile in bootstrap.dart) as QR codes, for a
/// phone that has it to show and a phone that cannot get it to photograph.
/// See PeerShareScreen and PeerReceiveScreen.
///
/// The file is about 4 KB. One QR code holds under 3 KB, and a code that
/// full is too dense for a phone's camera to read off another phone's
/// screen. So the file is cut into a few codes of at most [maxPiece]
/// characters, each `FV1:<n>/<total>:<id>:<piece>`. The id is the end of
/// the file's signature, so pieces of two different files are never put
/// together. Nothing here is trusted: what comes out is opened and checked
/// like a file read from a host (Bootstrap.takeFromPeer).
library;

abstract final class PeerCode {
  /// The most characters of the file in one code: a QR code of version 25
  /// or so, which a phone camera reads off a screen at arm's length.
  static const maxPiece = 1300;

  /// The most codes one file is read from. The real file needs three or
  /// four; a code that claims more is not ours.
  static const maxPieces = 16;

  /// The most candidate lines tried from one text. Each one costs a
  /// signature check.
  static const maxCandidates = 8;

  static const _tag = 'FV1';

  static final _piece = RegExp(
    r'^FV1:(\d{1,2})/(\d{1,2}):([A-Za-z0-9_-]{1,16}):([A-Za-z0-9_.=-]+)$',
  );

  /// What a file line is made of: base64url, the dot between body and
  /// signature, and padding. Anything else ends a run.
  static final _notLine = RegExp(r'[^A-Za-z0-9_\-.=]+');
  static final _lineOnly = RegExp(r'^[A-Za-z0-9_\-.=]+$');
  static final _body = RegExp(r'^[A-Za-z0-9_-]{39,}={0,2}$');

  /// The signature is 64 bytes: 86 characters without padding.
  static final _signature = RegExp(r'^[A-Za-z0-9_-]{86}(?:==)?$');

  /// [line] as the codes to show, in order.
  static List<String> split(String line) {
    final text = line.trim();
    final count = (text.length / maxPiece).ceil().clamp(1, maxPieces);
    final size = (text.length / count).ceil();
    final id = text.substring(text.length < 8 ? 0 : text.length - 8);
    return [
      for (var i = 0; i < count; i++)
        '$_tag:${i + 1}/$count:$id:'
            '${text.substring(i * size, ((i + 1) * size).clamp(0, text.length))}',
    ];
  }

  /// The file lines that [text] may hold, longest first, at most
  /// [maxCandidates]: text pasted from a message, a file someone sent, or a
  /// code that holds a whole line. A messenger or a file can wrap the line
  /// in other words, or break it across lines, so the lines of [text] made
  /// only of a line's characters are also tried joined together. The caller
  /// tries each until one opens.
  ///
  /// Linear in the length of [text], which can be anything a user pastes.
  static List<String> linesIn(String text) {
    final found = <String>{..._runs(text)};
    final joined = StringBuffer();
    void flush() {
      if (joined.isNotEmpty) found.addAll(_runs(joined.toString()));
      joined.clear();
    }

    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isNotEmpty && _lineOnly.hasMatch(line)) {
        joined.write(line);
      } else {
        flush();
      }
    }
    flush();
    final sorted = found.toList()..sort((a, b) => b.length - a.length);
    return sorted.take(maxCandidates).toList();
  }

  /// The longest line in [text], or null when there is none.
  static String? lineIn(String text) {
    final all = linesIn(text);
    return all.isEmpty ? null : all.first;
  }

  static Iterable<String> _runs(String text) sync* {
    for (final found in text.split(_notLine)) {
      // A full stop after the line, at the end of a sentence. Trimmed by
      // hand: a pattern anchored at the end backtracks on a run of dots.
      var end = found.length;
      while (end > 0 && found.codeUnitAt(end - 1) == 0x2E) {
        end--;
      }
      final run = found.substring(0, end);
      final dot = run.indexOf('.');
      if (dot < 0 || dot != run.lastIndexOf('.')) continue;
      if (_body.hasMatch(run.substring(0, dot)) &&
          _signature.hasMatch(run.substring(dot + 1))) {
        yield run;
      }
    }
  }

  /// The parts of one scanned code, or null when it is not a piece of a
  /// file.
  static ({int n, int total, String id, String piece})? parse(String text) {
    final m = _piece.firstMatch(text.trim());
    if (m == null) return null;
    final n = int.parse(m[1]!);
    final total = int.parse(m[2]!);
    if (total < 1 || total > maxPieces || n < 1 || n > total) return null;
    return (n: n, total: total, id: m[3]!, piece: m[4]!);
  }
}

/// What one scanned code did. See [PeerCodeReader.add].
enum PeerPiece {
  /// A piece not read before, or a whole file.
  added,

  /// A piece already read.
  again,

  /// Not a code of ours.
  notOurs,
}

/// Collects the codes of one file as they are photographed, in any order.
class PeerCodeReader {
  PeerCodeReader();

  /// A reader with the pieces [toJson] gave, or an empty one when [json] is
  /// not that.
  factory PeerCodeReader.fromJson(Object? json) {
    final reader = PeerCodeReader();
    if (json is! Map) return reader;
    final id = json['id'];
    final total = json['total'];
    final pieces = json['pieces'];
    if (id is! String || total is! int || pieces is! Map) return reader;
    if (total < 1 || total > PeerCode.maxPieces) return reader;
    for (final entry in pieces.entries) {
      final n = int.tryParse('${entry.key}');
      final piece = entry.value;
      if (n == null || n < 1 || n > total || piece is! String) continue;
      reader.add('FV1:$n/$total:$id:$piece');
    }
    return reader;
  }

  String? _id;
  int? _total;
  final _pieces = <int, String>{};
  List<String> _lines = const [];

  /// How many codes of the file are in.
  int get have => _pieces.length;

  /// How many codes the file is in, once one has been read.
  int? get total => _total;

  /// The lines to try, best first: the whole file once every code is in,
  /// or what a text held. Empty until then.
  List<String> get lines => _lines;

  /// The best of [lines], or null.
  String? get line => _lines.isEmpty ? null : _lines.first;

  /// Take the text of one scanned code, a file or a paste. A piece of
  /// another file than the pieces read so far starts the file again: the
  /// other phone fetched a newer one meanwhile, or this is another
  /// friend's.
  PeerPiece add(String text) {
    final part = PeerCode.parse(text);
    if (part == null) {
      final whole = PeerCode.linesIn(text);
      if (whole.isEmpty) return PeerPiece.notOurs;
      reset();
      _lines = whole;
      return PeerPiece.added;
    }
    if (part.id != _id || part.total != _total) {
      reset();
      _id = part.id;
      _total = part.total;
    }
    if (_pieces.containsKey(part.n)) return PeerPiece.again;
    _pieces[part.n] = part.piece;
    if (_pieces.length == part.total) {
      _lines = [
        [for (var i = 1; i <= part.total; i++) _pieces[i]].join(),
      ];
    }
    return PeerPiece.added;
  }

  /// The codes read so far, to keep across a restart of the app: Android
  /// may stop it while the camera app is open. Null when there is nothing
  /// to keep.
  Map<String, Object>? toJson() {
    final id = _id;
    final total = _total;
    if (id == null || total == null || _pieces.isEmpty || _lines.isNotEmpty) {
      return null;
    }
    return {
      'id': id,
      'total': total,
      'pieces': {for (final e in _pieces.entries) '${e.key}': e.value},
    };
  }

  /// Forget everything read.
  void reset() {
    _id = null;
    _total = null;
    _pieces.clear();
    _lines = const [];
  }
}
