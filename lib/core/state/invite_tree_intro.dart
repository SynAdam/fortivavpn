import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the introduction to the invite tree (InviteTreeIntroScreen) has
/// opened on this install, and whether it opened in this run of the app.
///
/// It opens by itself once: on the home screen at the first calm moment
/// of a run that knows the tree rule is on, or on the invite screen the
/// first time it loads a status under the tree rule, whichever comes
/// first. After that it opens only when the user asks for it. The flag is
/// set before the story opens, so a story that crashes never opens again
/// on every visit. Cleared when the account is deleted.
///
/// One record lives for the whole run of the app, so [shownThisRun] is
/// the run's: the story counts as the run's one popup, and the cards and
/// questions that come after it on the home screen wait for the next run.
class InviteTreeIntroRecord {
  InviteTreeIntroRecord({Future<SharedPreferences> Function()? prefs})
    : _prefs = prefs ?? SharedPreferences.getInstance;

  /// Where the flag lives: true once the story has opened.
  static const seenKey = 'invite_tree_intro_seen';

  final Future<SharedPreferences> Function() _prefs;

  bool _shownThisRun = false;

  /// Whether the story opened in this run of the app, by itself or when
  /// the user asked for it.
  bool get shownThisRun => _shownThisRun;

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
    _shownThisRun = true;
    try {
      final prefs = await _prefs();
      await prefs.setBool(seenKey, true);
    } catch (e) {
      debugPrint('InviteTreeIntroRecord: could not save ($e)');
    }
  }
}
