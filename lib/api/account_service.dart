import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/network_keys.dart';
import '../services/vpn_event_reporter.dart';
import 'api_client.dart';
import 'api_routes.dart';
import 'device_identity.dart';
import 'device_service.dart';

/// Deletes this install's account: the backend device row, the VLESS
/// clients provisioned on every server, and the local state that
/// describes them.
///
/// Exists because App Store Review Guideline 5.1.1(v) requires an account
/// created in the app to be deletable from inside the app. Signing out is
/// not enough, and neither is asking the user to email support.
class AccountService {
  AccountService._();

  static final AccountService instance = AccountService._();

  /// SharedPreferences keys holding data that belongs to the account
  /// rather than to the app.
  ///
  /// Enumerated rather than wiped wholesale so that deleting an account
  /// does not also reset the app's appearance and settings, which is not
  /// what the user asked for and reads as a bug.
  static const List<String> accountPrefKeys = [
    // Connection history, per session, with server names and durations.
    'fortiva_connection_sessions',
    // The server this install was last connected to.
    'vpn_connected_server_id',
    'vpn_connected_server_name',
    'vpn_connected_start_time',
    // And the attempt behind that connection: its door, link and moves.
    'vpn_connected_attempt',
    // Which of the device's own servers it was set to use. The VLESS
    // clients behind that choice are removed from the panels by the
    // deletion, so the choice cannot outlive them.
    'fortiva_dedicated_server_id',
    // And whether the user picked it or the connect flow moved there.
    'fortiva_dedicated_server_by_user',
    // The device's own servers and allowance as the backend last sent them,
    // kept for a launch that cannot reach it. They are this account's
    // credentials, and the deletion removes them from the panels.
    'fortiva_dedicated_saved',
    // Which shared server the user picked instead of one of ours. A
    // choice about this device's connection, made under this account's
    // provisioning, so it does not outlive the deletion either.
    'fortiva_shared_server_uri',
    // And whether the connect fallback chose it rather than the user.
    'fortiva_shared_server_by_fallback',
    // Auto-connect, and the onboarding flag, so the app really does come
    // back looking like a first launch.
    'fortiva_auto_connect',
    'fortiva_onboarding_completed',
    // Whether the Play install referrer has been read. Cleared so the
    // install can accept the invite code it arrived with: the device row
    // is gone, so the backend will see a device with no claim on it.
    'fortiva_install_referrer_read',
    // The code Play carried while its claim waits for an answer. It was
    // meant for the device row the deletion removes; a fresh install reads
    // Play again (see above).
    'fortiva_install_referrer_pending',
    // Which released version the user had waved away, and when. Written
    // by builds up to 1.6.10 only, and removed at launch by later ones
    // (UpdateDialog.forgetOldLater), so this only matters for a deletion
    // that runs before that. Cleared so the app really does come back
    // looking like a first launch.
    'pref_update_dismissed_version',
    'pref_update_dismissed_at',
    // Tunnel events waiting to be reported. They describe this device's
    // sessions, so they go with the account rather than surviving it.
    'fortiva_vpn_events_queue',
    // Door checks waiting to be reported, for at most half an hour. They
    // describe this device's attempts, like the events above.
    'fortiva_vpn_probes_queue',
    // The attempt the keeper found dead while the app was away (Keeper), so
    // it reports it once, the tunnel it was on, and how many runs it left
    // one unreported while the phone looked offline. Notes about this
    // device's sessions.
    'keeper_stalled_attempt',
    'keeper_stalled_tunnel',
    'keeper_offline_skips',
    // Which door worked on which network. Learned through the servers
    // that are being deleted, and a fresh account should diagnose afresh
    // rather than trust a memory of credentials that no longer exist.
    'fortiva_path_memory',
    // What this device saw of each network it met, and the salt its Wi-Fi
    // network keys are made with (NetworkHistory, NetworkKeys). They
    // describe this device's networks, so they go with the account; with a
    // new salt every network gets a new key.
    'fortiva_network_history',
    'fortiva_network_salt',
    // When each network was last swept and last given a paired test, and
    // which networks reached IPv6 (DoorSweep, DoorPairRunner, Ipv6Reach).
    // They are kept by the same network keys, so they say which networks
    // this device was on and when; at worst the next connect sweeps, pairs
    // or tries IPv6 once sooner than it would have.
    'fortiva_door_sweep_marks',
    'fortiva_door_pair_marks',
    'fortiva_ipv6_reach',
    // Which networks already have a measured success today. A note about
    // this device's sessions, and clearing it only costs one extra second
    // of checks on the first connect after a deletion.
    'fortiva_success_baseline_days',
    // When this install last measured an operator's candidate links. A note
    // about what this device has already done, so it goes with the account;
    // at worst the next launch measures once sooner than it would have.
    'fortiva_candidate_probe_last_run',
    // Size probe readings and the record of this device's upload tries,
    // both waiting to be reported, and when each network was last
    // measured. They describe this device's networks and attempts, like
    // the door checks above, so they go with the account; at worst the
    // next run measures a network once sooner than it would have.
    'fortiva_size_probes_queue',
    'fortiva_delivery_log_queue',
    'fortiva_size_probe_marks',
    // Which relay carried a call and which failed lately, on each network
    // this device was on, by transport and carrier (ApiRelays.memoryKey).
    // It describes this device's networks like the marks above, so it goes
    // with the account; at worst the first call after a deletion that needs
    // a relay tries them in the backend's order.
    'api_relay_memory',
    // What this device's connect taps did, waiting to be reported. It
    // names this device's doors and attempts, like the door checks above.
    'fortiva_connect_traces_queue',
    // Messages from the Fortiva team: the last list, which ones popped up
    // or were read, and the receipts waiting to be sent. The list was
    // picked for this device's row, and the receipts name it, so they go
    // with the account. A fresh account sees the current messages again.
    'in_app_messages_cache',
    'in_app_messages_popped',
    'in_app_messages_read',
    'in_app_messages_reported',
    'in_app_messages_receipts',
    'in_app_messages_last_popped_sent_at',
    // The same for the checks made with the app off screen (NoticePull):
    // what they found, which messages got a notification, and their
    // receipts waiting to be sent.
    'notices_found',
    'notices_notified',
    'notices_last_sent_at',
    'notices_reported',
    'notices_receipts',
    // The support chat: the conversation, the messages waiting to be sent,
    // the last answer about whether the chat is on, and the newest reply
    // seen. All of it is this device's conversation with us, and the
    // backend deletes its copy with the device.
    'support_chat_status',
    'support_chat_messages',
    'support_chat_outbox',
    'support_chat_seen',
    // The crypto order this device was paying, kept by builds up to 1.6.17
    // so their checkout could find it again. This build writes it no more,
    // and still clears what an older build left.
    'billing_checkout_ref',
    // Every Google Play purchase token this device has handled: bought
    // here, restored by hand, restored on its own, or refused because
    // another phone holds it. The background check never sends these
    // again. It goes with the account because the purchases were taken up
    // by this device's row, and a new account should get back what the
    // Google account pays for. A token another phone holds is only asked
    // about once more, and that check never moves it.
    'billing_play_auto_restored',
    // Premium offers: the refill the limit sheet last opened for, when the
    // calm card last showed and how often, the end of Premium the note
    // after the end last showed for, and whether the tunnel has worked on
    // this install. All of it is about this account's use and Premium, so
    // a new account starts as a first launch does.
    'limit_sheet_shown_for',
    'premium_prompt_state',
    // The invite card: its good days, the last failure, how often and when
    // it showed, and whether a share ended it. About this account's use,
    // so a new account starts as a first launch does, seeded again from
    // the rating card's days.
    'invite_prompt_state',
    // Whether the introduction to the invite tree has opened by itself. A
    // new account sees it once again.
    'invite_tree_intro_seen',
    'renewal_lapse_seen',
    'upsell_after_first_connect',
  ];

  /// SharedPreferences keys that deliberately survive a deletion.
  ///
  /// Listed rather than merely omitted so that a test can assert every
  /// key the app writes is a considered decision. A key that is neither
  /// here nor in [accountPrefKeys] is one somebody forgot about.
  static const List<String> keptPrefKeys = [
    // The device id. Cleared through DeviceIdentity.clear() instead,
    // which also has to reach the secure store the value really lives in.
    'fortivavpn_device_id',
    // Chosen language. A UI preference, not account data, and clearing it
    // would drop the user back to English in the middle of a flow they
    // just confirmed in their own language.
    'pref_locale',
    // DNS servers. A network preference the user configured by hand; it
    // describes their network, not their account.
    'pref_remote_dns',
    'pref_domestic_dns',
    // Whether to send failure diagnostics. A choice about the app, not
    // data about the account.
    'pref_share_diagnostics',
    // How the backend last said to send the TLS hello. The same for every
    // device and nothing about the account; without it the next connect
    // falls back to the built-in setting.
    'remote_tls_fragment',
    // The relays the backend last listed. The same for every device and
    // nothing about the account; without them a phone whose network cuts
    // our calls has one way fewer to reach us.
    'api_relays',
    // When that list was saved, so a newer fallback file can be told from
    // an older one. Nothing about the account.
    'api_relays_at',
    // The relay that last carried a call, tried first. Nothing about the
    // account; without it the next call that needs a relay may wait out a
    // blocked one first.
    'api_relay_worked',
    // The fallback file from the public hosts, and the extra hosts the
    // backend named. The same for every device and nothing about the
    // account; without them a phone that cannot reach us has no relay or
    // link from the file until it reads it again.
    'bootstrap_file',
    'bootstrap_mirrors',
    // Codes of that file read from a friend's phone, kept for half an hour
    // so Android stopping the app while the camera is open loses none. The
    // same for every device and nothing about the account.
    'peer_codes',
    // The notices file from the same hosts, and when it was last read. The
    // same for every device, like the fallback file; without it the next
    // read would come sooner than the hosts' limits allow for.
    'notices_file',
    'notices_file_read_at',
    'notices_file_quiet_until',
    'notices_file_api_read_at',
    // When a background check last ran, and what the user did with the card
    // that asks to let the app run in the background. About this phone, not
    // the account.
    'notices_last_check_at',
    'notices_backend_failed_at',
    'notices_off_card_hidden_at',
    'notices_background_watch_since',
    'notices_background_hidden_at',
    'notices_background_opened_at',
    // How often and when the app asked Android to allow message
    // notifications. It asks at most twice per install, and a new account
    // must not start the count again.
    'notices_permission_asks',
    'notices_permission_last_ask',
    // The version rules the backend last sent. The same for every device
    // and nothing about the account; without them a phone that cannot
    // reach us is not told its build is no longer supported.
    'remote_version_rules',
    // How the backend last said to run the connect checklist. The same for
    // every device and nothing about the account; without it a phone that
    // cannot reach us runs the checklist with no last pass.
    'remote_checklist',
    // Whether the backend last turned the connect trace on. The same for
    // every device and nothing about the account; without it a phone that
    // cannot reach us records no trace of its taps.
    'remote_connect_trace',
    // The backend's last standby doors flag. A setting of the app, kept
    // like the connect trace flag above.
    'remote_standby_doors',
    // Set while the backend last turned the stall watch off. A setting of
    // the app, kept like the flags above.
    'remote_stall_watch_off',
    // How the backend last asked the stall watch to decide. The same for
    // every device and nothing about the account, kept like the flags above.
    'remote_stall_watch_settings',
    // The backend's last APN guide settings. The same for every device and
    // nothing about the account, kept like the flags above.
    'remote_apn_guide',
    // What the backend last asked the phone to measure about its
    // connections. The same for every device and nothing about the account,
    // kept like the flags above.
    'remote_connection_data',
    // The backend's last backup network settings. The same for every device
    // and nothing about the account, kept like the flags above. Whether this
    // device may use the network comes with the device's own answer, which
    // a deletion clears.
    'remote_psiphon',
    // The sha256 of the backup network's server list kept on the phone
    // (PsiphonEntries). The list is the same for every device and nothing
    // about the account; without the sha the kept file is not used until
    // it is downloaded again.
    'psiphon_entries_sha',
    // When a download of that list last failed, and for which sha, so a
    // phone that cannot download it does not pay for it at every settings
    // load. About the list, not the account.
    'psiphon_entries_failed',
    // When "Not now" was tapped on the APN guide card. It is about this
    // phone's SIM, not the account, and clearing it would bring the card
    // back to someone who has just put it off.
    'apn_guide_dismissed_at',
    // The public list the backend last sent, and when. The same for every
    // device and nothing about the account; without it a phone that cannot
    // reach us has no public link to show or to try.
    'community_list_saved',
    // When this install asked for a Google Play rating and how often, with
    // the days and the last failure that decide when. Nothing about the
    // account, and clearing it would let a new account ask again a user
    // who has already been asked.
    'review_prompt_state',
    // Google Play purchases the backend has not confirmed yet. They are
    // paid for, and Play bills the Google account, not this device's row,
    // so they must still reach the backend after a deletion. The new
    // account gets the Premium they paid for.
    'billing_play_unconfirmed',
  ];

  final DeviceService _deviceService = DeviceService();

  /// Stands in for the backend call in tests.
  @visibleForTesting
  Future<void> Function()? backendDelete;

  /// Delete the account, then wipe everything local that referred to it.
  ///
  /// Order matters. The backend call goes first and its failure is
  /// propagated, because clearing local state first would destroy the
  /// device id and leave an undeletable row on the server with no way for
  /// this install to ever name it again.
  ///
  /// Once the server side is done, the local clean-up runs to completion
  /// regardless of what any single step does. Each of those steps can
  /// fail for reasons that have nothing to do with the deletion (a broken
  /// keystore), and none of them should turn a completed deletion into an
  /// error the user is told to retry.
  ///
  /// Throws [ApiException] if the backend could not be reached or refused
  /// the request.
  Future<void> deleteAccount() async {
    // What the phone knows of its networks is closed from before the
    // backend call, not only for the local removal: an upload that comes
    // back 404 once the row is gone registers the device again and tries
    // once more, and must not take a key made with the old salt with it.
    // It opens again however the deletion ends, also when the backend
    // refuses it. No device is registered meanwhile (DeviceService).
    _closeNetworks();
    DeviceService.deletionRuns(true);
    try {
      await (backendDelete ?? _deviceService.deleteAccount)();

      try {
        await DeviceIdentity.instance.clear();
      } catch (e) {
        debugPrint('AccountService: could not clear device identity ($e)');
      }

      await clearLocal();
    } finally {
      DeviceService.deletionRuns(false);
      _reopenNetworks();
    }
  }

  static void _closeNetworks() {
    NetworkKeys.close();
    ApiRelays.closeNetworks();
    VpnEventReporter.forgetAttemptKeys();
  }

  static void _reopenNetworks() {
    NetworkKeys.reopen();
    ApiRelays.reopenNetworks();
  }

  /// The keys in [accountPrefKeys] that say which networks this device was
  /// on. [clearLocal] removes them once more at its end: work that was
  /// already running when the deletion began (a sweep, a connect) can
  /// write them again while the removal runs.
  static const List<String> networkPrefKeys = [
    'fortiva_path_memory',
    'fortiva_network_history',
    'fortiva_network_salt',
    'fortiva_door_sweep_marks',
    'fortiva_door_pair_marks',
    'fortiva_ipv6_reach',
    'api_relay_memory',
    'fortiva_success_baseline_days',
    'fortiva_size_probe_marks',
  ];

  /// Remove every key in [accountPrefKeys], then [networkPrefKeys] again.
  ///
  /// The salt, the relays' memory of networks and the network keys the
  /// recent taps sent are also held in memory. For the whole removal no
  /// network key is read or handed out, the relays keep no memory of
  /// networks, and no network history is written (NetworkKeys.close,
  /// ApiRelays.closeNetworks): a reading in the middle would load the old
  /// salt or map again and put it back. They open again at the end, and
  /// the next key is made with a new salt.
  @visibleForTesting
  static Future<void> clearLocal() async {
    _closeNetworks();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in [...accountPrefKeys, ...networkPrefKeys]) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('AccountService: could not clear preferences ($e)');
    } finally {
      _reopenNetworks();
    }
  }
}
