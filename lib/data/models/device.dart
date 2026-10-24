import 'billing.dart';
import 'invite_prompt_rules.dart';

/// Device model representing a registered device from the backend
class Device {
  final int id;
  final String deviceId;
  final String platform;
  final String appVersion;
  final bool isPremium;
  final String? subscriptionProductId;
  final DateTime? subscriptionExpiresAt;
  final DateTime createdAt;

  /// When the invite card may show, or null when it is off for this
  /// device. Sent with every register; GET /devices/{id} sends null.
  final InvitePromptRules? invitePrompt;

  /// Until when this install may still enter an invite code, or null when
  /// it may not (already claimed, the window over, invites off). The home
  /// screen's "Have an invite code?" row reads it, so it needs no call that
  /// would mint a code.
  final DateTime? referralClaimOpenUntil;

  const Device({
    required this.id,
    required this.deviceId,
    required this.platform,
    required this.appVersion,
    required this.isPremium,
    this.subscriptionProductId,
    this.subscriptionExpiresAt,
    required this.createdAt,
    this.invitePrompt,
    this.referralClaimOpenUntil,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as int,
      deviceId: json['device_id'] as String,
      platform: json['platform'] as String,
      appVersion: json['app_version'] as String,
      isPremium: json['is_premium'] as bool? ?? false,
      subscriptionProductId: json['subscription_product_id'] as String?,
      subscriptionExpiresAt: json['subscription_expires_at'] != null
          ? DateTime.parse(json['subscription_expires_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      invitePrompt: InvitePromptRules.fromJson(json['invite_prompt']),
      referralClaimOpenUntil: readTime(json['referral_claim_open_until']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'platform': platform,
      'app_version': appVersion,
      'is_premium': isPremium,
      'subscription_product_id': subscriptionProductId,
      'subscription_expires_at': subscriptionExpiresAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'invite_prompt': invitePrompt?.toJson(),
      'referral_claim_open_until': referralClaimOpenUntil?.toIso8601String(),
    };
  }

  /// Check if subscription is currently active
  bool get hasActiveSubscription {
    if (!isPremium) return false;
    if (subscriptionExpiresAt == null) return isPremium;
    return subscriptionExpiresAt!.isAfter(DateTime.now());
  }

  Device copyWith({
    int? id,
    String? deviceId,
    String? platform,
    String? appVersion,
    bool? isPremium,
    String? subscriptionProductId,
    DateTime? subscriptionExpiresAt,
    DateTime? createdAt,
    InvitePromptRules? invitePrompt,
    DateTime? referralClaimOpenUntil,
  }) {
    return Device(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      platform: platform ?? this.platform,
      appVersion: appVersion ?? this.appVersion,
      isPremium: isPremium ?? this.isPremium,
      subscriptionProductId:
          subscriptionProductId ?? this.subscriptionProductId,
      subscriptionExpiresAt:
          subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      createdAt: createdAt ?? this.createdAt,
      invitePrompt: invitePrompt ?? this.invitePrompt,
      referralClaimOpenUntil:
          referralClaimOpenUntil ?? this.referralClaimOpenUntil,
    );
  }
}
