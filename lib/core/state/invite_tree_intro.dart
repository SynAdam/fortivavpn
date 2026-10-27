import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the introduction to the invite tree (InviteTreeIntroScreen) has
/// opened by itself on this install.
///
/// The invite screen opens it once, the first time it loads a status under
/// the tree rule. After that it opens only when the user asks for it. The
/// flag is set before the story opens, so a story that crashes never opens
/// again on every visit. Cleared when the account is deleted.
class InviteTreeIntroRecord {
  InviteTreeIntroRecord({Future<SharedPreferences> Function()? prefs})
    : _prefs = prefs ?? SharedPreferences.getInstance;

  /// Where the flag lives: true once the story has opened.
  static const seenKey = 'invite_tree_intro_seen';

  final Future<SharedPreferences> Function() _prefs;

  /// Whether the story has opened before. True when the flag cannot be
  /// read, so a broken store never opens it on every visit.
  Future<bool> seen() async {
    try {
      final prefs = await _prefs();
      return prefs.getBool(seenKey) ?? false;
    } catch (e) {
      debugPrint('InviteTreeIntroRecord: could not read ($e)');
      return true;
    }
  }

  /// Note that the story opened. Never throws.
  Future<void> markSeen() async {
    try {
      final prefs = await _prefs();
      await prefs.setBool(seenKey, true);
    } catch (e) {
      debugPrint('InviteTreeIntroRecord: could not save ($e)');
    }
  }
}
