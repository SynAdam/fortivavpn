import 'billing.dart';

/// When the invite card may show on this device, as the backend sent it
/// in the `invite_prompt` block of the register answer.
///
/// Every number comes from the backend's INVITE_PROMPT_* settings. The app
/// has none of its own, so the card is off on a device whose block is
/// missing or has a number missing (the feature off, or the device in the
/// holdout). See InvitePrompt.
class InvitePromptRules {
  const InvitePromptRules({
    required this.minGoodDays,
    required this.minSessionMinutes,
    required this.quietAfterFailureHours,
    required this.everyDays,
    required this.maxShows,
    this.earns = false,
    this.rewardPremiumDays,
  });

  /// Tehran days with a verified connect before the first card.
  final int minGoodDays;

  /// How long the current tunnel must have been up.
  final int minSessionMinutes;

  /// No card this long after a failed tap or a drop.
  final int quietAfterFailureHours;

  /// The wait after each show.
  final int everyDays;

  /// Shows per install, ever.
  final int maxShows;

  /// Whether a confirmed friend still gives this device Premium days. False
  /// at the cap, and then the card shows no reward line.
  final bool earns;

  /// The Premium days the next confirmed friend gives. Null when [earns] is
  /// false or the backend sent no number, and then the line names none.
  final int? rewardPremiumDays;

  /// Null unless all five numbers are whole numbers above zero.
  static InvitePromptRules? fromJson(Object? json) {
    if (json is! Map) return null;
    final minGoodDays = readPositiveInt(json['min_good_days']);
    final minSessionMinutes = readPositiveInt(json['min_session_minutes']);
    final quiet = readPositiveInt(json['quiet_after_failure_hours']);
    final everyDays = readPositiveInt(json['every_days']);
    final maxShows = readPositiveInt(json['max_shows']);
    if (minGoodDays == null ||
        minSessionMinutes == null ||
        quiet == null ||
        everyDays == null ||
        maxShows == null) {
      return null;
    }
    final earns = json['earns'] == true;
    return InvitePromptRules(
      minGoodDays: minGoodDays,
      minSessionMinutes: minSessionMinutes,
      quietAfterFailureHours: quiet,
      everyDays: everyDays,
      maxShows: maxShows,
      earns: earns,
      rewardPremiumDays: earns
          ? readPositiveInt(json['reward_premium_days'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'min_good_days': minGoodDays,
    'min_session_minutes': minSessionMinutes,
    'quiet_after_failure_hours': quietAfterFailureHours,
    'every_days': everyDays,
    'max_shows': maxShows,
    'earns': earns,
    'reward_premium_days': rewardPremiumDays,
  };
}
