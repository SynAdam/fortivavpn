/// One spelling per Iranian mobile operator.
///
/// Android names the operator a phone is on (TelephonyManager's
/// networkOperatorName), and one operator arrives spelled several ways:
/// "MCI", "IR-MCI" and "Hamrah Aval" are one network. The names here are
/// the ones the backend files operators under (its CARRIER_ALIASES), so a
/// list of carriers the backend sends matches the phone whichever spelling
/// the phone uses.
abstract final class CarrierName {
  static const hamrahAval = 'Hamrah Aval';
  static const irancell = 'Irancell';
  static const rightel = 'Rightel';

  /// Spellings, lower-cased with each run of spaces, hyphens and
  /// underscores made one space, mapped to the operator: the backend's
  /// aliases for the mobile operators, and "HAMRAHE AVVAL".
  static const _aliases = {
    'mci': hamrahAval,
    'ir mci': hamrahAval,
    'irmci': hamrahAval,
    'mcci': hamrahAval,
    'hamrah aval': hamrahAval,
    'hamrahe aval': hamrahAval,
    'hamrahe avval': hamrahAval,
    'irancell': irancell,
    'mtn irancell': irancell,
    'ir mtn': irancell,
    'rightel': rightel,
    'ir rightel': rightel,
  };

  static final _separators = RegExp(r'[\s_-]+');

  /// The operator [name] spells, or [name] without the spaces around it
  /// when it is no spelling known here. Null for no name. An unknown name
  /// is kept rather than dropped, as the backend does.
  static String? normalise(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final key = trimmed.toLowerCase().replaceAll(_separators, ' ');
    return _aliases[key] ?? trimmed;
  }
}
