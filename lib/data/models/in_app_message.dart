/// One message from the Fortiva team, already in the language the backend
/// picked for this phone.
///
/// The backend sends every message in all 12 app languages and answers
/// with the one the app asked for, so [language] is what the text is
/// written in. It decides the text direction, whatever the app language.
class InAppMessage {
  const InAppMessage({
    required this.id,
    required this.language,
    required this.title,
    required this.body,
    this.button,
    this.link,
    required this.sentAt,
    required this.endsAt,
  });

  final int id;

  /// The language code of [title], [body] and [button], such as `fa`.
  final String language;

  /// May be empty: an operator can send a message with no title.
  final String title;
  final String body;

  /// The label of the one button, or null when there is none. Never set
  /// without [link].
  final String? button;
  final Uri? link;

  /// When the operator sent it, on the server's clock, in UTC.
  final DateTime sentAt;

  /// When it stops showing, on the server's clock, in UTC.
  final DateTime endsAt;

  /// Whether the text runs right to left.
  bool get isRtl => const {'fa', 'ar', 'ur'}.contains(language);

  /// Throws [FormatException] when [json] is not a message this app can
  /// show. Most callers want [tryParse].
  factory InAppMessage.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final language = json['language'];
    final title = json['title'];
    final body = json['body'];
    final sentAt = _time(json['sent_at']);
    final endsAt = _time(json['ends_at']);
    if (id is! int ||
        language is! String ||
        language.trim().isEmpty ||
        body is! String ||
        body.trim().isEmpty ||
        sentAt == null ||
        endsAt == null) {
      throw const FormatException('not an in-app message');
    }

    // A button is only worth showing when it opens something, and only
    // https is opened: anything else could start an app or a download the
    // user never asked for. A bad link drops the button, not the message.
    final label = json['button'];
    final link = json['link'] is String
        ? Uri.tryParse((json['link'] as String).trim())
        : null;
    final usable =
        label is String &&
        label.trim().isNotEmpty &&
        link != null &&
        link.scheme == 'https' &&
        link.host.isNotEmpty;

    return InAppMessage(
      id: id,
      language: language.trim().toLowerCase(),
      title: title is String ? title.trim() : '',
      body: body.trim(),
      button: usable ? label.trim() : null,
      link: usable ? link : null,
      sentAt: sentAt,
      endsAt: endsAt,
    );
  }

  /// The message in [json], or null when it is not one. Never throws, so
  /// one bad entry costs that entry and not the whole list.
  static InAppMessage? tryParse(Object? json) {
    if (json is! Map) return null;
    try {
      return InAppMessage.fromJson(json.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'language': language,
    'title': title,
    'body': body,
    'button': button,
    'link': link?.toString(),
    'sent_at': sentAt.toIso8601String(),
    'ends_at': endsAt.toIso8601String(),
  };

  static DateTime? _time(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}

/// What one successful check for messages returned.
class MessagesPage {
  const MessagesPage({required this.messages, this.serverTime});

  /// The messages for this phone, as the server ordered them, with any
  /// entry this app cannot read left out.
  final List<InAppMessage> messages;

  /// The server's clock when it answered, or null when it did not say.
  final DateTime? serverTime;

  /// Throws [FormatException] when [json] is not a messages answer at all,
  /// such as a captive portal's page, so the caller keeps what it had
  /// rather than taking it for an empty list.
  factory MessagesPage.fromJson(Object? json) {
    if (json is! Map || json['messages'] is! List) {
      throw const FormatException('not a messages answer');
    }
    return MessagesPage(
      messages: [
        for (final entry in json['messages'] as List)
          ?InAppMessage.tryParse(entry),
      ],
      serverTime: InAppMessage._time(json['server_time']),
    );
  }
}
