/// What the support chat endpoints send, read the way InAppMessage reads a
/// message: a field this app cannot read is left out, and an entry it
/// cannot read costs that entry rather than the whole answer.
library;

DateTime? _time(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

int? _int(Object? value) => value is int ? value : null;

String? _string(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

/// The server's clock in an answer: at the top, or inside its quota.
DateTime? _serverTime(Map json) {
  final quota = json['quota'];
  return _time(json['server_time']) ??
      (quota is Map ? _time(quota['server_time']) : null);
}

/// How many questions this phone may still ask today, as the backend counts
/// them.
///
/// The day's count is the only question limit. An older backend also sends
/// a count for the conversation (conversation_limit, conversation_left and
/// conversation_resets_at); those fields are ignored and never shown.
class SupportQuota {
  const SupportQuota({
    required this.limit,
    required this.remaining,
    this.resetsAt,
    this.pausedUntil,
  });

  /// Questions per Tehran day, as the backend sets it.
  final int limit;
  final int remaining;

  /// The next Tehran midnight, in UTC, on the server's clock.
  final DateTime? resetsAt;

  /// Set while automatic answers are paused for this phone or for everyone.
  final DateTime? pausedUntil;

  static SupportQuota? tryParse(Object? json) {
    if (json is! Map) return null;
    final limit = _int(json['limit']);
    final remaining = _int(json['remaining']);
    if (limit == null || remaining == null) return null;
    return SupportQuota(
      limit: limit,
      remaining: remaining,
      resetsAt: _time(json['resets_at']),
      pausedUntil: _time(json['paused_until']),
    );
  }

  Map<String, dynamic> toJson() => {
    'limit': limit,
    'remaining': remaining,
    'resets_at': resetsAt?.toIso8601String(),
    'paused_until': pausedUntil?.toIso8601String(),
  };
}

/// The current conversation and whether our team has it as a ticket.
class SupportThread {
  const SupportThread({this.id, this.ticket = 'none'});

  final int? id;

  /// `none`, `open` or `closed`.
  final String ticket;

  bool get ticketOpen => ticket == 'open';

  static SupportThread? tryParse(Object? json) {
    if (json is! Map) return null;
    return SupportThread(
      id: _int(json['id']),
      ticket: _string(json['ticket']) ?? 'none',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'ticket': ticket};
}

/// One line of the chat.
///
/// Most come from the backend and carry its [id]. A few exist only on this
/// phone and have none: a question the backend refused before storing it,
/// and the mark where a new conversation starts.
class SupportMessage {
  const SupportMessage({
    this.id,
    this.clientId,
    required this.role,
    this.status = 'sent',
    this.code,
    this.redacted = false,
    this.text = '',
    this.rating,
    required this.createdAt,
  });

  /// Role of the mark this phone adds where a new conversation starts.
  static const divider = 'divider';

  final int? id;
  final String? clientId;

  /// `user`, `assistant`, `staff` or `system`, or [divider].
  final String role;

  /// `queued`, `answering`, `handled`, `failed`, `refused`, `to_staff` or
  /// `sent`.
  final String status;

  /// Why a question was refused or failed, or what a system line says.
  final String? code;

  /// Whether the backend removed personal details or links from [text].
  final bool redacted;
  final String text;

  /// `up` or `down` on an answer the user rated.
  final String? rating;

  /// On the server's clock, in UTC.
  final DateTime createdAt;

  bool get local => id == null;

  /// A question still waiting for its answer.
  bool get inFlight =>
      role == 'user' && (status == 'queued' || status == 'answering');

  SupportMessage withRating(String? value) => SupportMessage(
    id: id,
    clientId: clientId,
    role: role,
    status: status,
    code: code,
    redacted: redacted,
    text: text,
    rating: value,
    createdAt: createdAt,
  );

  static const _roles = {'user', 'assistant', 'staff', 'system', divider};

  static SupportMessage? tryParse(Object? json) {
    if (json is! Map) return null;
    final role = json['role'];
    final createdAt = _time(json['created_at']);
    if (role is! String || !_roles.contains(role) || createdAt == null) {
      return null;
    }
    final id = _int(json['id']);
    // Only the phone's own marks may come without an id.
    if (id == null && role != divider && json['local'] != true) return null;
    final rating = json['rating'];
    return SupportMessage(
      id: id,
      clientId: _string(json['client_id']),
      role: role,
      status: _string(json['status']) ?? 'sent',
      code: _string(json['code']),
      redacted: json['redacted'] == true,
      text: json['text'] is String ? json['text'] as String : '',
      rating: rating == 'up' || rating == 'down' ? rating as String : null,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'client_id': clientId,
    'role': role,
    'status': status,
    'code': code,
    'redacted': redacted,
    'text': text,
    'rating': rating,
    'created_at': createdAt.toIso8601String(),
    if (id == null) 'local': true,
  };
}

/// GET .../support/status: whether the chat is on for this phone.
class SupportStatus {
  const SupportStatus({
    required this.enabled,
    this.mode = 'ai',
    this.quota,
    this.thread,
    this.pending = false,
    this.serverTime,
  });

  final bool enabled;

  /// `ai`, `staff`, `paused` or `off`.
  final String mode;
  final SupportQuota? quota;
  final SupportThread? thread;

  /// Whether a question of this phone is waiting for its answer.
  final bool pending;
  final DateTime? serverTime;

  /// Throws [FormatException] for a body that is not a status answer, such
  /// as a captive portal's page, so the caller keeps what it had.
  factory SupportStatus.fromJson(Object? json) {
    if (json is! Map || json['enabled'] is! bool) {
      throw const FormatException('not a support status');
    }
    return SupportStatus(
      enabled: json['enabled'] as bool,
      mode: _string(json['mode']) ?? 'ai',
      quota: SupportQuota.tryParse(json['quota']),
      thread: SupportThread.tryParse(json['thread']),
      pending: json['pending'] == true,
      serverTime: _serverTime(json),
    );
  }
}

/// GET .../support?after=: the messages after a given id.
class SupportPage {
  const SupportPage({
    required this.messages,
    this.mode = 'ai',
    this.thread,
    this.quota,
    this.pending = false,
    this.serverTime,
  });

  /// Oldest first, at most [pageSize].
  final List<SupportMessage> messages;
  final String mode;
  final SupportThread? thread;
  final SupportQuota? quota;
  final bool pending;
  final DateTime? serverTime;

  /// The most the backend sends in one answer.
  static const pageSize = 50;

  factory SupportPage.fromJson(Object? json) {
    if (json is! Map || json['messages'] is! List) {
      throw const FormatException('not a support page');
    }
    return SupportPage(
      messages: [
        for (final entry in json['messages'] as List)
          ?SupportMessage.tryParse(entry),
      ],
      mode: _string(json['mode']) ?? 'ai',
      thread: SupportThread.tryParse(json['thread']),
      quota: SupportQuota.tryParse(json['quota']),
      pending: json['pending'] == true,
      serverTime: _serverTime(json),
    );
  }
}

/// What a POST of a message, or of a new conversation, answered.
class SupportReply {
  const SupportReply({
    this.message,
    this.quota,
    this.thread,
    this.mode,
    this.serverTime,
  });

  /// The stored message. Null for a new conversation.
  final SupportMessage? message;
  final SupportQuota? quota;
  final SupportThread? thread;
  final String? mode;
  final DateTime? serverTime;

  factory SupportReply.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('not a support answer');
    return SupportReply(
      message: SupportMessage.tryParse(json['message']),
      quota: SupportQuota.tryParse(json['quota']),
      thread: SupportThread.tryParse(json['thread']),
      mode: _string(json['mode']),
      serverTime: _serverTime(json),
    );
  }
}

/// Why the backend would not take a message: the `detail` of a 4xx or of
/// the 503 that means the chat is off.
class SupportRefusal {
  const SupportRefusal({required this.code, this.retryAt, this.quota});

  final String code;
  final DateTime? retryAt;
  final SupportQuota? quota;

  /// The refusal in an error body, or null when the body has no code, as a
  /// validation list or a proxy's error page has not.
  static SupportRefusal? fromBody(Object? body) {
    if (body is! Map) return null;
    final detail = body['detail'];
    if (detail is! Map) return null;
    final code = _string(detail['code']);
    if (code == null) return null;
    return SupportRefusal(
      code: code,
      retryAt: _time(detail['retry_at']),
      quota: SupportQuota.tryParse(detail['quota']),
    );
  }
}
