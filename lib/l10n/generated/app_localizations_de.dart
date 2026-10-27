// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class SDe extends S {
  SDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'FortivaVPN';

  @override
  String get statusDisconnected => 'Getrennt';

  @override
  String get statusConnecting => 'Verbindet...';

  @override
  String get statusConnected => 'Verbunden';

  @override
  String get statusDisconnecting => 'Trenne...';

  @override
  String get statusError => 'Fehler';

  @override
  String get statusVerifying => 'Überprüfe...';

  @override
  String get disconnect => 'Trennen';

  @override
  String get connectBtn => 'VERBINDEN';

  @override
  String get disconnectBtn => 'TRENNEN';

  @override
  String get pleaseWait => 'BITTE WARTEN';

  @override
  String get locationLabel => 'Standort:';

  @override
  String get selectServer => 'Server wählen';

  @override
  String get serverLocation => 'Serverstandort';

  @override
  String get searchServers => 'Server suchen';

  @override
  String get locationsTitle => 'Standorte';

  @override
  String get sortLatency => 'Sortierung: Latenz';

  @override
  String get sortAZ => 'Sortierung: A-Z';

  @override
  String get sortedByLatency => 'Nach Latenz sortiert';

  @override
  String get sortedAZ => 'Sortiert A–Z';

  @override
  String get pingAll => 'Alle anpingen';

  @override
  String get pinging => 'Pinge...';

  @override
  String get ping => 'Ping';

  @override
  String get stop => 'Stopp';

  @override
  String get fastestServer => 'SCHNELLSTER SERVER';

  @override
  String get timeout => 'Zeitüberschreitung';

  @override
  String get tabCommunity => 'Community';

  @override
  String get tabFree => 'Kostenlos';

  @override
  String get tabPremium => 'Premium';

  @override
  String get noCommunityServers => 'Keine Community-Server';

  @override
  String get communityLoadFailed => 'Diese Liste konnte nicht geladen werden';

  @override
  String get communityRetry => 'Erneut versuchen';

  @override
  String get officialTabExplainer =>
      'Von Fortiva betrieben und von uns online gehalten. Geteilt mit allen, die die App nutzen. Fang hier an.';

  @override
  String get communityTabExplainer =>
      'Zusätzliche Verbindungsoptionen. Geschwindigkeit und Verfügbarkeit variieren.';

  @override
  String get noFreeServers => 'Keine kostenlosen Server';

  @override
  String get noPremiumServers => 'Keine Premium-Server';

  @override
  String noResultsFor(String query) {
    return 'Keine Ergebnisse für \"$query\"';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get freeBadge => 'GRATIS';

  @override
  String get settings => 'Einstellungen';

  @override
  String get connection => 'Verbindung';

  @override
  String get dnsConfiguration => 'DNS-Konfiguration';

  @override
  String get customDns => 'Benutzerdefinierte DNS-Server';

  @override
  String get about => 'Über';

  @override
  String get privacyPolicy => 'Datenschutzrichtlinie';

  @override
  String get contactUs => 'Kontakt';

  @override
  String get rateOnGooglePlay => 'Fortiva bei Google Play bewerten';

  @override
  String get website => 'Webseite';

  @override
  String get copyright => '© 2026 NimusAI';

  @override
  String get version => 'Version';

  @override
  String get language => 'Sprache';

  @override
  String get languageSubtitle => 'App-Anzeigesprache';

  @override
  String get whatIsDns => 'Was ist DNS?';

  @override
  String get dnsExplanation =>
      'DNS (Domain Name System) ist das Telefonbuch des Internets. Es übersetzt Webseiten-Namen in IP-Adressen.\n\nDurch die Anpassung Ihres DNS können Sie:\n• Verbindungsgeschwindigkeit verbessern ⚡\n• Privatsphäre erhöhen 🔒\n• Zensurblockaden umgehen 🌍';

  @override
  String get configuration => 'Konfiguration';

  @override
  String get primaryDns => 'Primäres DNS';

  @override
  String get primaryDnsHint => 'Standard: 1.1.1.1';

  @override
  String get secondaryDns => 'Sekundäres DNS (Optional)';

  @override
  String get secondaryDnsHint => 'Standard: 8.8.8.8';

  @override
  String get saveConfiguration => 'Konfiguration speichern';

  @override
  String get dnsSaved => 'DNS-Konfiguration gespeichert';

  @override
  String get invalidPrimaryDns => 'Ungültige primäre DNS-IP-Adresse';

  @override
  String get invalidSecondaryDns => 'Ungültige sekundäre DNS-IP-Adresse';

  @override
  String get statistics => 'Statistiken';

  @override
  String get overview => 'ÜBERSICHT';

  @override
  String get connectionsLabel => 'Verbindungen';

  @override
  String get totalTime => 'Gesamtzeit';

  @override
  String get dataUsage => 'DATENVERBRAUCH';

  @override
  String get uploaded => 'Hochgeladen';

  @override
  String get downloaded => 'Heruntergeladen';

  @override
  String get total => 'Gesamt';

  @override
  String lastUpdated(String date) {
    return 'Zuletzt aktualisiert: $date';
  }

  @override
  String today(String time) {
    return 'Heute um $time';
  }

  @override
  String get yesterday => 'Gestern';

  @override
  String daysAgo(int count) {
    return 'Vor $count Tagen';
  }

  @override
  String get noDataYet => 'Noch keine Daten';

  @override
  String get connectToStart =>
      'Verbinde dich mit einem VPN, um das Tracking zu starten';

  @override
  String get errorConnectionFailed => 'Verbindung fehlgeschlagen';

  @override
  String get errorServerNotWorking =>
      'Server funktioniert nicht – versuche einen anderen';

  @override
  String get errorServerNotForwarding => 'Server leitet Traffic nicht weiter';

  @override
  String get errorUnexpected => 'Unerwarteter Fehler';

  @override
  String get errorDisconnectionFailed => 'Trennung fehlgeschlagen';

  @override
  String get errorFailedToRegister => 'Geräteregistrierung fehlgeschlagen';

  @override
  String get ipInformation => 'IP-Informationen';

  @override
  String get connectionAnalytics => 'Verbindungsanalyse';

  @override
  String get recentSessions => 'Letzte Sitzungen';

  @override
  String get speedTest => 'Geschwindigkeitstest';

  @override
  String get startTest => 'Test starten';

  @override
  String get download => 'Download';

  @override
  String get upload => 'Upload';

  @override
  String get testingViaVpn => 'Test über VPN';

  @override
  String get testingDirect => 'Direktverbindungstest';

  @override
  String get splitTunneling => 'Split-Tunneling';

  @override
  String get splitTunnelingDescription =>
      'Wählen Sie App-Kategorien, die den VPN-Tunnel umgehen. Ausgeschlossene Apps nutzen Ihre reguläre Internetverbindung.';

  @override
  String get enableSplitTunneling => 'Split-Tunneling aktivieren';

  @override
  String get splitTunnelActive => 'Ausgewählte Apps umgehen VPN';

  @override
  String get splitTunnelInactive => 'Gesamter Datenverkehr über VPN';

  @override
  String get bypassVpnFor => 'VPN umgehen für';

  @override
  String get tools => 'Tools';

  @override
  String get settingsGeneral => 'Allgemein';

  @override
  String get shareDiagnosticsTitle => 'Verbindungsdiagnose teilen';

  @override
  String get shareDiagnosticsBody =>
      'Sendet Verbindungsberichte, deinen Netzbetreiber und dein Land, das Handymodell und die Android-Version, die Namen der Websites, die du über das VPN aufrufst, mit ihrer Anzahl pro Tag, und ob du unsere Nachrichten, Premium-Angebote und die Einladungskarte gesehen oder angetippt hast. Wir sehen nie die Seiten, die du öffnest, oder was du sendest.';

  @override
  String get security => 'Sicherheit';

  @override
  String get privacyDashboard => 'Datenschutz-Dashboard';

  @override
  String get privacyDashboardSubtitle => 'IP-Info & Leak-Schutz';

  @override
  String get connectionAnalyticsSubtitle => 'Sitzungsverlauf & Diagramme';

  @override
  String get speedTestSubtitle => 'Testen Sie Ihre Verbindung';

  @override
  String get splitTunnelingSubtitle => 'App-VPN-Routing';

  @override
  String get splashTagline => 'Privater Zugang, wo immer du bist';

  @override
  String get openSourceLicence => 'Open-Source-Lizenz';

  @override
  String get sourceOfferTitle => 'Open-Source-Lizenz';

  @override
  String get sourceOfferBody =>
      'Fortiva VPN ist freie Software unter der GNU General Public License v3. Es baut auf Xray-core und anderen Open-Source-Projekten auf.\n\nDu hast Anspruch auf den vollständigen Quellcode der Version, die du installiert hast. Um ihn anzufordern, schreib eine E-Mail mit deiner App-Version an admin@fortivavpn.com. Dieses Angebot gilt drei Jahre ab dem Datum, an dem du diese Version erhalten hast.';

  @override
  String get close => 'Schließen';

  @override
  String get account => 'Konto';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get deleteAccountSubtitle =>
      'Dieses Gerät und deine Daten dauerhaft entfernen';

  @override
  String get deleteAccountConfirmTitle => 'Konto wirklich löschen?';

  @override
  String get deleteAccountConfirmBody =>
      'Damit werden die Registrierung deines Geräts, die für dich angelegten persönlichen Server und deine Nachrichten im Support-Chat entfernt. Auch der Verbindungsverlauf auf diesem Telefon wird gelöscht.\n\nDas lässt sich nicht rückgängig machen. Du kannst jederzeit neu beginnen, indem du die App wieder öffnest.';

  @override
  String deleteAccountConfirmRetention(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tagen',
      one: '$days Tag',
    );
    return 'Dein Kontodatensatz wird sofort entfernt. Kopien in Backups und anonyme Serverprotokolle werden innerhalb von $_temp0 gelöscht.';
  }

  @override
  String get deleteAccountConfirmRetentionNoDays =>
      'Dein Kontodatensatz wird sofort entfernt. Kopien in Backups und anonyme Serverprotokolle werden später gelöscht, innerhalb der Fristen in unserer Datenschutzerklärung.';

  @override
  String get deleteAccountCancel => 'Konto behalten';

  @override
  String get deleteAccountConfirm => 'Löschen';

  @override
  String get deleteAccountInProgress => 'Konto wird gelöscht';

  @override
  String get deleteAccountDone => 'Dein Konto wurde gelöscht.';

  @override
  String get deleteAccountFailed =>
      'Das Konto konnte nicht gelöscht werden. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get homeTapToConnect => 'Zum Verbinden tippen';

  @override
  String get homeChecking => 'Verbindung wird geprüft';

  @override
  String get homePreparing => 'Dein Server wird eingerichtet';

  @override
  String get homeDisconnecting => 'Verbindung wird getrennt';

  @override
  String get homeFindingPath => 'Weg wird gesucht';

  @override
  String get diagCheckingInternet => 'Internetverbindung wird geprüft';

  @override
  String get diagInternationalCut =>
      'Das internationale Internet ist in diesem Netz unterbrochen';

  @override
  String diagPathRow(String city, int n) {
    return '$city, Weg $n';
  }

  @override
  String get diagOpen => 'offen';

  @override
  String get diagBlocked => 'blockiert';

  @override
  String get diagSkipped => 'heute übersprungen';

  @override
  String diagConnectingThrough(String city) {
    return 'Verbindung über $city wird aufgebaut';
  }

  @override
  String get diagVerifying => 'Datenverkehr wird geprüft';

  @override
  String get diagNoInternet => 'Dein Handy hat gerade kein Internet.';

  @override
  String get diagCutOff =>
      'Dein Netz erreicht das internationale Internet gerade nicht. Tippe, um es erneut zu versuchen.';

  @override
  String get diagNothingOpen =>
      'Alle Wege sind gerade blockiert. Tippe, um es erneut zu versuchen.';

  @override
  String get homeTryingAgain =>
      'Alle Wege sind gerade blockiert. Wir versuchen es gleich erneut.';

  @override
  String get homeCutOffTryingAgain =>
      'Dein Netz erreicht das internationale Internet gerade nicht. Wir versuchen es gleich erneut.';

  @override
  String get homeOfflineTryingAgain =>
      'Dein Handy hat gerade kein Internet. Wir versuchen es gleich erneut.';

  @override
  String get diagPathFailed =>
      'Der Weg war offen, aber der Tunnel kam nicht zustande. Tippe, um es erneut zu versuchen.';

  @override
  String get openVpnSettings => 'VPN-Einstellungen öffnen';

  @override
  String get yourServer => 'DEIN SERVER';

  @override
  String get yourServerCaption =>
      'Nur für dich. Niemand sonst verbindet sich darüber.';

  @override
  String get ourServer => 'UNSER SERVER';

  @override
  String get ourServerCaption =>
      'Von Fortiva betrieben und mit allen geteilt. Wird genutzt, bis dein eigener Server bereit ist.';

  @override
  String get communityServer => 'COMMUNITY-SERVER';

  @override
  String get communityServerCaption =>
      'Eine zusätzliche Verbindungsoption. Sie kann jederzeit ausfallen.';

  @override
  String communityServerNumber(String n) {
    return 'Community-Server $n';
  }

  @override
  String get myServersTitle => 'Deine Server';

  @override
  String get myServersExplainer =>
      'Jedes Fortiva-Gerät bekommt an jedem Standort einen eigenen Server, mit Zugangsdaten, die nur zu dieser Installation gehören. Ein Konto ist nicht nötig.';

  @override
  String get myServersInUse => 'In Verwendung';

  @override
  String get myServersEmpty => 'Noch keine Server zugewiesen';

  @override
  String get myServersRetry => 'Erneut versuchen';

  @override
  String get myServersBlockedTitle =>
      'Du hast das heutige Datenvolumen aufgebraucht';

  @override
  String get myServersBlockedWait =>
      'Dein Volumen wird automatisch zurückgesetzt. Schau bald wieder vorbei.';

  @override
  String myServersMoved(String place) {
    return 'Jetzt wird $place verwendet';
  }

  @override
  String get copyLink => 'Link kopieren';

  @override
  String get linkCopied => 'Link kopiert';

  @override
  String quotaUsedToday(String used, String limit) {
    return '$used von $limit heute verbraucht';
  }

  @override
  String get quotaUsedUp => 'Tagesvolumen aufgebraucht';

  @override
  String get quotaUnlimited => 'Unbegrenztes Datenvolumen';

  @override
  String get quotaDaily => 'Tagesvolumen';

  @override
  String get quotaLimitReached => 'Tageslimit erreicht';

  @override
  String quotaLeftOf(String left, String limit) {
    return '$left von $limit übrig';
  }

  @override
  String get quotaResetsShortly => 'Wird gleich zurückgesetzt';

  @override
  String quotaResetsInHours(int hours) {
    return 'Wird in $hours Std. zurückgesetzt';
  }

  @override
  String quotaResetsInMinutes(int minutes) {
    return 'Wird in $minutes Min. zurückgesetzt';
  }

  @override
  String get myServersSubtitle =>
      'Die für dieses Gerät bereitgestellten Server';

  @override
  String get sharedServersTitle => 'Geteilte Server';

  @override
  String get sharedServersSubtitle => 'Öffentliche Standorte, als Reserve';

  @override
  String get tabOfficial => 'Unsere Server';

  @override
  String get noOfficialServers => 'Zurzeit keine Fortiva-Server';

  @override
  String get inviteTitle => 'Freunde einladen';

  @override
  String get inviteSubtitle => 'Mehr Datenvolumen pro Tag';

  @override
  String get inviteYourCode => 'Dein Einladungscode';

  @override
  String get inviteShareAction => 'Einladung teilen';

  @override
  String get inviteCopyAction => 'Code kopieren';

  @override
  String get inviteCodeCopied => 'Code kopiert';

  @override
  String inviteShareMessage(String code, String url) {
    return 'Ein kostenloses VPN, das bei mir gut läuft: Fortiva. Keine Anmeldung nötig.\nHier installieren:\n$url\nMein Einladungscode: $code';
  }

  @override
  String get inviteHowItWorks => 'So funktioniert es';

  @override
  String inviteHowItWorksBody(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days verschiedenen Tagen',
      one: '$days Tag',
    );
    return 'Teile deinen Code. Wenn jemand die App installiert, den Code eingibt und das VPN an $_temp0 nutzt, bekommst du $amount mehr Datenvolumen pro Tag. Das bleibt dauerhaft.';
  }

  @override
  String inviteHowItWorksBodyNoAmount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days verschiedenen Tagen',
      one: '$days Tag',
    );
    return 'Teile deinen Code. Wenn jemand die App installiert, den Code eingibt und das VPN an $_temp0 nutzt, bekommst du mehr Datenvolumen pro Tag. Das bleibt dauerhaft.';
  }

  @override
  String inviteHowItWorksBodyNoDays(String amount) {
    return 'Teile deinen Code. Wenn jemand die App installiert, den Code eingibt und das VPN eine Weile nutzt, bekommst du $amount mehr Datenvolumen pro Tag. Das bleibt dauerhaft.';
  }

  @override
  String get inviteHowItWorksBodyNoAmountNoDays =>
      'Teile deinen Code. Wenn jemand die App installiert, den Code eingibt und das VPN eine Weile nutzt, bekommst du mehr Datenvolumen pro Tag. Das bleibt dauerhaft.';

  @override
  String inviteHowItWorksCap(String max) {
    return 'Über Einladungen bekommst du bis zu $max pro Tag.';
  }

  @override
  String get inviteStatInvited => 'Eingeladen';

  @override
  String get inviteStatEarning => 'Qualifiziert';

  @override
  String get inviteStatBonus => 'Bonusdaten';

  @override
  String inviteBonusPerDay(String amount) {
    return '+$amount pro Tag';
  }

  @override
  String get inviteNoBonusYet => 'Noch kein Bonus';

  @override
  String invitePendingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einladungen sind noch nicht qualifiziert',
      one: '1 Einladung ist noch nicht qualifiziert',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String inviteJoinedWith(String code) {
    return 'Du bist mit dem Code $code beigetreten';
  }

  @override
  String get inviteLoadFailed => 'Einladungscode konnte nicht geladen werden';

  @override
  String get inviteRetry => 'Erneut versuchen';

  @override
  String get inviteHaveCodeTitle => 'Hast du einen Einladungscode?';

  @override
  String inviteHaveCodeSubtitle(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Gib ihn in den ersten $hours Stunden ein',
      one: 'Gib ihn in der ersten Stunde ein',
    );
    return '$_temp0';
  }

  @override
  String get inviteHaveCodeSubtitleNoHours =>
      'Gib ihn bald nach der Installation ein';

  @override
  String get inviteEnterCodeHint => 'Einladungscode';

  @override
  String get inviteApplyAction => 'Anwenden';

  @override
  String get inviteNotNowAction => 'Später';

  @override
  String inviteClaimAccepted(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days verschiedenen Tagen',
      one: '$days Tag',
    );
    return 'Einladung angenommen. Dein Freund bekommt Bonusdaten, sobald du das VPN an $_temp0 genutzt hast.';
  }

  @override
  String get inviteClaimAcceptedNoDays =>
      'Einladung angenommen. Dein Freund bekommt Bonusdaten, sobald du das VPN eine Weile genutzt hast.';

  @override
  String get inviteClaimAlready =>
      'Dieses Gerät hat bereits einen Einladungscode verwendet';

  @override
  String get inviteClaimRejected =>
      'Dieser Code hat nicht funktioniert. Prüfe ihn und versuche es erneut';

  @override
  String get inviteClaimNetwork =>
      'Server nicht erreichbar. Versuche es erneut';

  @override
  String get inviteCardTitle =>
      'Läuft Fortiva gut bei dir? Schick es an deine Freunde';

  @override
  String get inviteCardBody =>
      'Schick deinen Freunden den Installationslink, damit auch sie sich kostenlos verbinden können.';

  @override
  String inviteCardReward(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Sobald ein Freund anfängt, Fortiva zu nutzen, bekommst du $days Tage Premium.',
      one:
          'Sobald ein Freund anfängt, Fortiva zu nutzen, bekommst du $days Tag Premium.',
    );
    return '$_temp0';
  }

  @override
  String get inviteCardRewardNoAmount =>
      'Sobald ein Freund anfängt, Fortiva zu nutzen, bekommst du Premium geschenkt.';

  @override
  String get inviteSendTelegram => 'Telegram';

  @override
  String get inviteSendWhatsApp => 'WhatsApp';

  @override
  String get inviteCopyLink => 'Link kopieren';

  @override
  String get inviteOtherApps => 'Andere Apps';

  @override
  String get inviteLinkCopied => 'Einladungsnachricht kopiert';

  @override
  String get invitePasteBody =>
      'Kopiere den Code aus der Nachricht deines Freundes und füge ihn hier ein.';

  @override
  String get invitePasteAction => 'Einfügen';

  @override
  String get inviteErrorTooLate =>
      'Die Zeit für die Eingabe eines Einladungscodes auf diesem Handy ist abgelaufen.';

  @override
  String get inviteErrorUnknown =>
      'Wir konnten diesen Code nicht finden. Kopiere ihn erneut aus der Nachricht deines Freundes.';

  @override
  String get inviteErrorOwnCode =>
      'Das ist dein eigener Code. Gib den Code deines Freundes ein.';

  @override
  String get inviteErrorMutual =>
      'Du und dein Freund könnt euch nicht gegenseitig einladen.';

  @override
  String inviteHowItWorksPremium(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Jeder Freund, der anfängt, Fortiva zu nutzen, bringt dir zusätzlich $days Tage Premium.',
      one:
          'Jeder Freund, der anfängt, Fortiva zu nutzen, bringt dir zusätzlich $days Tag Premium.',
    );
    return '$_temp0';
  }

  @override
  String inviteHowItWorksPremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Über Einladungen bekommst du bis zu $max Tage Premium.',
      one: 'Über Einladungen bekommst du bis zu $max Tag Premium.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeLive =>
      'Dein Bonus gilt, solange deine Freunde Fortiva weiter nutzen. Hört ein Freund auf, sinkt er.';

  @override
  String inviteTreeNext(String amount) {
    return 'Dein nächster Freund bringt dir $amount pro Tag, sobald er Fortiva nutzt.';
  }

  @override
  String inviteTreeKept(String amount) {
    return 'Dein Bonus fällt nie unter $amount pro Tag, dank Freunden, die du früher eingeladen hast.';
  }

  @override
  String get inviteTreeSlotsTitle => 'Deine Plätze';

  @override
  String get inviteTreeSlotActive => 'Aktiv';

  @override
  String get inviteTreeSlotNotActive => 'Gerade nicht aktiv';

  @override
  String get inviteTreeSlotEmpty => 'Freier Platz';

  @override
  String inviteTreePaysNow(String amount) {
    return '+$amount pro Tag jetzt';
  }

  @override
  String inviteTreePairFull(String amount) {
    return '+$amount pro Tag, wenn beide aktiv sind';
  }

  @override
  String get inviteTreeNothingYet => 'Noch nichts';

  @override
  String get inviteTreeFriendsTitle => 'Über deine Plätze';

  @override
  String get inviteTreeRowFriends => 'Auf deinen Plätzen';

  @override
  String get inviteTreeRowFriendsSlots => 'Auf ihren Plätzen';

  @override
  String inviteTreeRowSteps(int steps) {
    String _temp0 = intl.Intl.pluralLogic(
      steps,
      locale: localeName,
      other: '$steps Schritte entfernt',
      one: '$steps Schritt entfernt',
    );
    return '$_temp0';
  }

  @override
  String inviteTreeRowPeople(int people, int active) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people Personen',
      one: '$people Person',
    );
    return '$_temp0, $active aktiv';
  }

  @override
  String inviteTreeHowSlots(int slots) {
    String _temp0 = intl.Intl.pluralLogic(
      slots,
      locale: localeName,
      other:
          'Teile deinen Code. Die ersten $slots Freunde, die sich qualifizieren, füllen deine Plätze paarweise.',
      one:
          'Teile deinen Code. Der erste Freund, der sich qualifiziert, füllt deinen Platz.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeHowSlotsNoNumber =>
      'Teile deinen Code. Die ersten Freunde, die sich qualifizieren, füllen deine Plätze paarweise.';

  @override
  String get inviteTreeHowPair =>
      'Ein Paar bringt mehr, wenn beide darin aktiv sind.';

  @override
  String get inviteTreeHowFriendsSlots =>
      'Wenn deine Plätze voll sind, nehmen deine nächsten Freunde, die sich qualifizieren, die nächsten freien Plätze, weiter von dir entfernt. Auch sie bringen dir zusätzliche Daten, umso weniger, je weiter sie entfernt sind.';

  @override
  String get inviteTreeHowOthers =>
      'Dein erstes Paar kann auch Leute aufnehmen, die du nicht eingeladen hast. Sie bringen dir genauso zusätzliche Daten.';

  @override
  String inviteTreeHowActive(int days, int window) {
    String _temp0 = intl.Intl.pluralLogic(
      window,
      locale: localeName,
      other: '$window Tagen',
      one: '$window Tag',
    );
    String _temp1 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tagen',
      one: '$days Tag',
    );
    return 'Ein Freund zählt als aktiv, solange er Fortiva in den letzten $_temp0 an mindestens $_temp1 genutzt hat.';
  }

  @override
  String get inviteTreeHowActiveNoNumber =>
      'Ein Freund zählt als aktiv, solange er Fortiva weiter nutzt.';

  @override
  String inviteTreeHowCap(String max) {
    return 'Einladungen bringen dir bis zu $max pro Tag.';
  }

  @override
  String get inviteTreeHowCapNoAmount =>
      'Was Einladungen pro Tag bringen, hat eine Obergrenze.';

  @override
  String get premiumSourceInvite => 'Durch deine Einladungen';

  @override
  String quotaBonusIncluded(String amount) {
    return 'inklusive $amount Einladungsbonus';
  }

  @override
  String get updateTitle => 'Update verfügbar';

  @override
  String get updateRequiredTitle => 'Update erforderlich';

  @override
  String updateBody(String version) {
    return 'Fortiva $version ist da. Aktualisiere für die neuesten Korrekturen.';
  }

  @override
  String get updateRequiredBody =>
      'Diese Version wird nicht mehr unterstützt. Aktualisiere, um Fortiva weiter zu nutzen.';

  @override
  String get updateNow => 'Aktualisieren';

  @override
  String get updateLater => 'Später';

  @override
  String get updateFromPlay => 'Google Play';

  @override
  String get updateFromTelegram => 'Telegram-Kanal';

  @override
  String get updateConnect => 'Verbinden';

  @override
  String get updateConnectHint =>
      'Wenn Google Play oder Telegram nicht öffnet, tippe zuerst auf Verbinden.';

  @override
  String get updateConnected =>
      'Du bist verbunden. Lade jetzt das Update herunter.';

  @override
  String get updateReconnect => 'Klappt nicht? Neu verbinden';

  @override
  String get updateDisconnect => 'Trennen';

  @override
  String get updateDisconnectHint =>
      'Tippe auf Trennen, um das Update über deine normale Internetverbindung zu laden.';

  @override
  String get updateNotCarrying =>
      'Du bist verbunden, aber es kommt nichts durch. Versuche, neu zu verbinden, oder tippe auf Trennen, um dein normales Internet zu nutzen.';

  @override
  String get diagVerdictNoInternet =>
      'Dein Handy hat keine Internetverbindung. Fortiva kann sich erst verbinden, wenn sie wieder da ist.';

  @override
  String get diagVerdictCutOff =>
      'Dein Netz erreicht das internationale Internet gerade nicht. Versuche es in ein paar Minuten erneut.';

  @override
  String get diagVerdictNeedsPermission =>
      'Fortiva hat keine Berechtigung, ein VPN auszuführen, oder eine andere VPN-App ist als durchgehend aktiv eingestellt.';

  @override
  String get diagVerdictServerUnreachable =>
      'Dieser Server ist aus deinem Netzwerk nicht erreichbar. Er ist entweder hier blockiert oder ausgefallen.';

  @override
  String get diagVerdictBlockedTls =>
      'Die Verbindung zu diesem Server wird beim Aufbau unterbrochen. So sieht Filterung aus.';

  @override
  String get diagVerdictThrottled =>
      'Der Server hat auf jede Prüfung geantwortet, und trotzdem kam durch den Tunnel nichts an. Die Verbindung wird gedrosselt.';

  @override
  String get diagCheckInternet => 'Internetverbindung prüfen';

  @override
  String diagTryServer(String server) {
    return 'Neue Suche mit $server';
  }

  @override
  String get diagTryAnotherServer => 'Anderen Server versuchen';

  @override
  String get diagDetails => 'Einzelheiten';

  @override
  String get diagDetailsHide => 'Einzelheiten ausblenden';

  @override
  String privateDnsWarning(String host) {
    return 'Privates DNS ist aktiv ($host), deshalb öffnen sich manche Seiten nicht. Schalte privates DNS in den Einstellungen deines Handys aus.';
  }

  @override
  String get openNetworkSettings => 'Netzwerkeinstellungen öffnen';

  @override
  String testPointStatus(String time, int open, int total) {
    return 'Testpunkt · letzte Prüfung $time · $open von $total Wegen offen';
  }

  @override
  String get messagesTooltip => 'Nachrichten';

  @override
  String get inboxTitle => 'Nachrichten';

  @override
  String get inboxEmpty => 'Gerade keine Nachrichten.';

  @override
  String get messageClose => 'Schließen';

  @override
  String get supportTitle => 'Support';

  @override
  String get supportTooltip => 'Mit dem Support chatten';

  @override
  String get supportAskAction => 'Support fragen';

  @override
  String get supportContactSubtitle => 'Schreib uns direkt in der App';

  @override
  String get supportAutomaticNotice =>
      'Antworten werden automatisch geschrieben und können falsch sein.';

  @override
  String get supportStaffNotice =>
      'Automatische Antworten sind gerade aus. Deine Nachrichten gehen an unser Team.';

  @override
  String get supportInputHint => 'Schreib deine Frage';

  @override
  String get supportInputHintTeam => 'Schreib unserem Team';

  @override
  String get supportSend => 'Senden';

  @override
  String supportQuotaLeft(int remaining, int limit) {
    return 'Heute noch $remaining von $limit Fragen übrig';
  }

  @override
  String supportWaitIn(String time) {
    return 'Du kannst in $time wieder fragen.';
  }

  @override
  String supportDurationHours(int hours, int minutes) {
    return '$hours Std. $minutes Min.';
  }

  @override
  String supportDurationMinutes(int minutes) {
    return '$minutes Min.';
  }

  @override
  String get supportNewConversation => 'Neue Unterhaltung';

  @override
  String get supportSending => 'Wird gesendet';

  @override
  String get supportNotSent =>
      'Nicht gesendet. Tippe, um es erneut zu versuchen.';

  @override
  String get supportRateUp => 'Hilfreich';

  @override
  String get supportRateDown => 'Nicht hilfreich';

  @override
  String get supportRatedDown =>
      'Danke. Unser Team sieht sich diese Antwort an.';

  @override
  String get supportTeamLabel => 'Fortiva-Team';

  @override
  String get supportUnavailable => 'Der Chat ist gerade nicht verfügbar.';

  @override
  String get supportOpenTelegram => 'Schreib uns auf Telegram';

  @override
  String get supportGenericError =>
      'Etwas ist schiefgelaufen. Bitte versuch es noch einmal.';

  @override
  String supportCodeTooLong(int max) {
    return 'Deine Nachricht ist zu lang. Bitte bleib unter $max Zeichen.';
  }

  @override
  String get supportCodeEmpty => 'Deine Nachricht ist leer.';

  @override
  String get supportCodeWaitReply =>
      'Bitte warte auf die Antwort auf deine letzte Frage.';

  @override
  String get supportCodeSlowDown =>
      'Du sendest Nachrichten zu schnell. Bitte warte kurz.';

  @override
  String get supportCodeQuotaDay => 'Du hast alle Fragen für heute gestellt.';

  @override
  String get supportCodePaused =>
      'Automatische Antworten sind vorübergehend pausiert.';

  @override
  String get supportCodeBusy =>
      'Unser Assistent ist gerade ausgelastet. Versuch es in ein paar Minuten noch einmal.';

  @override
  String get supportCodeGreeting =>
      'Hallo! Wie kann ich dir mit Fortiva helfen?';

  @override
  String get supportCodeGibberish =>
      'Das habe ich leider nicht verstanden. Bitte schreib deine Frage noch einmal.';

  @override
  String get supportCodeRedacted =>
      'Wir haben persönliche Daten und Links aus deiner Nachricht entfernt.';

  @override
  String get supportCodeRedactedEmpty =>
      'Deine Nachricht enthielt nur persönliche Daten oder Links und wurde deshalb nicht gesendet. Bitte beschreib das Problem in Worten.';

  @override
  String get supportCodeOffTopic =>
      'Ich kann nur bei Fragen zur Nutzung von Fortiva helfen.';

  @override
  String get supportCodeAbuse =>
      'Bleiben wir respektvoll. Ich bin hier, um dir mit Fortiva zu helfen.';

  @override
  String get supportCodeAiUnavailable =>
      'Der Assistent konnte diesmal nicht antworten. Bitte versuch es gleich noch einmal.';

  @override
  String get supportCodeToStaff =>
      'An unser Team gesendet. Die Antwort erscheint hier.';

  @override
  String get supportCodeTicketOpened =>
      'Wir haben deine Frage an unser Team weitergegeben. Die Antwort erscheint hier.';

  @override
  String get supportCodeNotSent =>
      'Diese Nachricht konnte nicht gesendet werden. Schreib sie noch einmal, wenn du noch Hilfe brauchst.';

  @override
  String get supportAssistantSubtitle => 'KI-Assistent';

  @override
  String get supportThinkingReading => 'Ich lese deine Frage';

  @override
  String get supportThinkingSearching => 'Ich suche die Antwort';

  @override
  String get supportThinkingWriting => 'Ich schreibe die Antwort';

  @override
  String get supportThinkingStill => 'Bin noch dran, danke fürs Warten';

  @override
  String get supportSuggestConnect => 'Ich kann keine Verbindung herstellen';

  @override
  String get supportSuggestData => 'Wie viel Datenvolumen habe ich heute?';

  @override
  String get supportSuggestSlow => 'Meine Verbindung ist langsam';

  @override
  String get supportWithTeam => 'Dieses Gespräch liegt jetzt bei unserem Team.';

  @override
  String get supportTryAgainSoon =>
      'Versuch es in ein paar Minuten noch einmal.';

  @override
  String supportDurationWholeHours(int hours) {
    return '$hours Std.';
  }

  @override
  String get supportUnreadReply => 'Neue Antwort';

  @override
  String get premiumTitle => 'Premium';

  @override
  String get premiumTileSubtitle => 'Unbegrenztes Datenvolumen ohne Tageslimit';

  @override
  String get premiumTileActive => 'Premium ist aktiv';

  @override
  String get premiumGetUnlimited => 'Unbegrenzt holen';

  @override
  String get premiumHeadline => 'Unbegrenztes Datenvolumen holen';

  @override
  String get premiumPitch =>
      'Premium hebt das Tageslimit auf. Du nutzt so viele Daten, wie du willst, bis es endet.';

  @override
  String get premiumActiveTitle => 'Premium ist aktiv';

  @override
  String premiumActiveUntil(String date) {
    return 'Unbegrenztes Datenvolumen bis $date';
  }

  @override
  String get premiumActiveNoDate => 'Unbegrenztes Datenvolumen';

  @override
  String get premiumRenews => 'Verlängert sich automatisch über Google Play';

  @override
  String get premiumSourceKey => 'Mit einem Schlüssel aktiviert';

  @override
  String get premiumSourceCrypto => 'Mit Krypto bezahlt';

  @override
  String get premiumSourceStars => 'Mit Telegram Stars bezahlt';

  @override
  String get premiumSourceGooglePlay => 'Über Google Play bezahlt';

  @override
  String get premiumSourceManual => 'Ein Geschenk vom Fortiva-Team';

  @override
  String get premiumYourKey => 'Dein Schlüssel';

  @override
  String get premiumKeyHint =>
      'Bewahre diesen Schlüssel gut auf. Gib ihn auf einem anderen Handy ein, um Premium dorthin umzuziehen.';

  @override
  String premiumKeyMoves(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tagen',
      one: '$days Tag',
    );
    return 'Ein Schlüssel kann innerhalb von $_temp0 bis zu $count-mal auf ein anderes Handy umziehen.';
  }

  @override
  String get premiumKeyMovesNoNumber =>
      'Ein Schlüssel kann nur begrenzt oft auf ein anderes Handy umziehen.';

  @override
  String get premiumCopy => 'Kopieren';

  @override
  String get premiumCopied => 'Kopiert';

  @override
  String get premiumChoosePlan => 'Wähle einen Tarif';

  @override
  String premiumPlanDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage unbegrenztes Datenvolumen',
      one: '$days Tag unbegrenztes Datenvolumen',
    );
    return '$_temp0';
  }

  @override
  String get premiumPlanNoDays => 'Unbegrenztes Datenvolumen';

  @override
  String get premiumBuy => 'Kaufen';

  @override
  String get premiumPlayUnavailable =>
      'Google Play ist gerade nicht verfügbar. Versuche es später noch einmal.';

  @override
  String get premiumPlayPending =>
      'Deine Zahlung ist bei Google Play noch ausstehend. Premium startet, sobald sie durch ist.';

  @override
  String get premiumPlayConfirming => 'Dein Kauf wird bestätigt...';

  @override
  String get premiumPlayRetrying =>
      'Deine Zahlung ist durch, aber wir konnten sie noch nicht bestätigen. Wir versuchen es weiter, du musst nicht noch einmal zahlen.';

  @override
  String get premiumPlayRefused =>
      'Wir konnten diesen Kauf nicht bestätigen. Falls dir Geld abgebucht wurde, wende dich an den Support.';

  @override
  String get premiumPlayNotAvailable =>
      'Premium ist auf diesem Handy gerade nicht verfügbar. Falls dir Geld abgebucht wurde, wende dich an den Support.';

  @override
  String get premiumNotAvailable =>
      'Premium ist auf diesem Handy gerade nicht verfügbar.';

  @override
  String get premiumPlayFailed =>
      'Der Kauf hat nicht geklappt. Versuche es noch einmal.';

  @override
  String get premiumNowOn =>
      'Premium ist aktiv. Viel Spaß mit unbegrenztem Datenvolumen.';

  @override
  String get premiumRestore => 'Käufe wiederherstellen';

  @override
  String get premiumRestoreDone =>
      'Dein Kauf ist auf diesem Handy wiederhergestellt.';

  @override
  String get premiumRestoreNone =>
      'Google Play hat keinen Kauf zum Wiederherstellen.';

  @override
  String get premiumRestoreFailed =>
      'Der Kauf konnte nicht wiederhergestellt werden. Versuche es später noch einmal.';

  @override
  String premiumRenewsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Wird alle $count Tage abgerechnet. Verlängert sich automatisch, bis du kündigst.',
      one:
          'Wird jeden Tag abgerechnet. Verlängert sich automatisch, bis du kündigst.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Wird alle $count Wochen abgerechnet. Verlängert sich automatisch, bis du kündigst.',
      one:
          'Wird jede Woche abgerechnet. Verlängert sich automatisch, bis du kündigst.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Wird alle $count Monate abgerechnet. Verlängert sich automatisch, bis du kündigst.',
      one:
          'Wird jeden Monat abgerechnet. Verlängert sich automatisch, bis du kündigst.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Wird alle $count Jahre abgerechnet. Verlängert sich automatisch, bis du kündigst.',
      one:
          'Wird jedes Jahr abgerechnet. Verlängert sich automatisch, bis du kündigst.',
    );
    return '$_temp0';
  }

  @override
  String get premiumRenewsNoPeriod =>
      'Verlängert sich automatisch, bis du kündigst.';

  @override
  String get premiumPlayCancelNote =>
      'Du kannst jederzeit in Google Play kündigen. Premium bleibt bis zum Ende der bezahlten Zeit aktiv.';

  @override
  String get premiumManageSubscription => 'Abo verwalten oder kündigen';

  @override
  String get premiumCurrentPlan => 'Aktueller Tarif';

  @override
  String get premiumPlaySubscribed =>
      'Du hast bereits ein Google-Play-Abo. Verwalte oder kündige es in Google Play.';

  @override
  String get premiumEnterCode => 'Code eingeben';

  @override
  String get premiumNeedsPlayVersion =>
      'Um über Google Play zu kaufen, brauchst du die Google-Play-Version von Fortiva.';

  @override
  String get premiumOff => 'Premium ist gerade nicht im Verkauf.';

  @override
  String get premiumLoadFailed =>
      'Premium konnte nicht geladen werden. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get premiumRetry => 'Erneut versuchen';

  @override
  String premiumPriceUsdt(String price) {
    return '$price USDT';
  }

  @override
  String premiumPriceStars(String stars) {
    return '$stars Telegram Stars';
  }

  @override
  String get premiumPayCrypto => 'Mit Krypto zahlen';

  @override
  String get premiumTelegramTitle => 'In Telegram bezahlen';

  @override
  String get premiumTelegramBody =>
      'Bezahle mit Telegram Stars in unserem Bot. Du bekommst einen Schlüssel, und Premium startet sofort auf diesem Handy.';

  @override
  String get premiumTelegramButton => 'In Telegram kaufen';

  @override
  String get premiumTelegramFailed =>
      'Telegram ließ sich nicht öffnen. Versuche es noch einmal.';

  @override
  String get checkoutTitle => 'Mit Krypto zahlen';

  @override
  String get checkoutChooseNetwork => 'Wähle das Netzwerk, von dem du sendest';

  @override
  String get checkoutContinue => 'Weiter';

  @override
  String get checkoutSendExactly => 'Sende genau diesen Betrag';

  @override
  String get checkoutNetwork => 'Netzwerk';

  @override
  String get checkoutAddress => 'An diese Adresse';

  @override
  String get checkoutMemo => 'Mit diesem Memo';

  @override
  String get checkoutMemoWarning =>
      'Gib dieses Memo bei der Überweisung unbedingt an, sonst können wir die Zahlung dir nicht zuordnen.';

  @override
  String get checkoutExactWarning =>
      'Sende genau diesen Betrag und nur über dieses Netzwerk. Ein anderer Betrag oder ein anderes Netzwerk kommt eventuell nicht bei uns an.';

  @override
  String checkoutTimeLeft(String time) {
    return 'Verbleibende Zeit: $time';
  }

  @override
  String get checkoutWaiting =>
      'Wir warten auf deine Zahlung. Diese Seite aktualisiert sich von selbst.';

  @override
  String get checkoutPaidTitle => 'Zahlung erhalten';

  @override
  String get checkoutPaidKeyOnly =>
      'Dein Schlüssel ist bereit. Gib ihn auf dem Handy ein, das Premium bekommen soll.';

  @override
  String get checkoutDone => 'Fertig';

  @override
  String get checkoutExpired =>
      'Diese Bestellung ist abgelaufen. Falls du schon bezahlt hast, wende dich an den Support.';

  @override
  String get checkoutUnderpaid =>
      'Bei uns ist weniger als der volle Betrag angekommen. Wende dich an den Support und nenne diese Bestellnummer:';

  @override
  String get checkoutCanceled => 'Diese Bestellung wurde storniert.';

  @override
  String get checkoutStartAgain => 'Neu starten';

  @override
  String get checkoutUnavailable =>
      'Zahlungen mit Krypto sind gerade nicht verfügbar.';

  @override
  String get checkoutTooManyOpen =>
      'Du hast zu viele unbezahlte Bestellungen. Bezahle eine davon oder warte, bis sie ablaufen.';

  @override
  String get checkoutUnknownPlan =>
      'Dieser Tarif ist nicht mehr im Verkauf. Geh zurück und wähle einen anderen.';

  @override
  String get checkoutFailed =>
      'Die Zahlung konnte nicht gestartet werden. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get redeemTitle => 'Code eingeben';

  @override
  String get redeemSubtitle => 'Ein Premium-Schlüssel oder ein Geschenkcode';

  @override
  String get redeemHint => 'Code';

  @override
  String get redeemApply => 'Anwenden';

  @override
  String get redeemCancel => 'Abbrechen';

  @override
  String get redeemInvalid =>
      'Das sieht nicht wie ein Code aus. Prüfe ihn und versuche es erneut.';

  @override
  String get redeemUnknown =>
      'Diesen Code kennen wir nicht. Prüfe ihn und versuche es erneut.';

  @override
  String get redeemExpired => 'Dieser Code ist abgelaufen.';

  @override
  String get redeemRevoked => 'Dieser Code ist nicht mehr gültig.';

  @override
  String get redeemMovedTooOften =>
      'Dieser Schlüssel ist zuletzt zu oft zwischen Handys umgezogen. Versuche es später noch einmal.';

  @override
  String get redeemExhausted => 'Dieser Code ist aufgebraucht.';

  @override
  String get redeemAlreadyUsed => 'Dieses Handy hat diesen Code schon benutzt.';

  @override
  String get redeemUnmetered =>
      'Dieses Handy hat schon unbegrenztes Datenvolumen und braucht diesen Code nicht.';

  @override
  String get redeemRateLimited =>
      'Zu viele Versuche. Warte kurz und versuche es erneut.';

  @override
  String get redeemUnavailable =>
      'Das ist gerade nicht verfügbar. Versuche es später noch einmal.';

  @override
  String get redeemNetwork =>
      'Der Server ist nicht erreichbar. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get redeemFailed =>
      'Dieser Code hat nicht funktioniert. Prüfe ihn und versuche es erneut.';

  @override
  String get redeemMoved => 'Premium ist auf dieses Handy umgezogen.';

  @override
  String redeemPromo(String amount) {
    return 'Code angenommen. $amount zusätzliches Datenvolumen hinzugefügt.';
  }

  @override
  String get redeemPromoNoAmount =>
      'Code angenommen. Zusätzliches Datenvolumen hinzugefügt.';

  @override
  String get tvScanTitle => 'Auf dem Handy öffnen';

  @override
  String get tvScanBody => 'Richte die Kamera deines Handys auf diesen Code.';

  @override
  String get refresh => 'Aktualisieren';

  @override
  String get premiumNotNow => 'Nicht jetzt';

  @override
  String get premiumLimitSheetTitle =>
      'Das heutige Datenvolumen ist aufgebraucht';

  @override
  String get premiumLimitWait => 'Warten, bis es zurückgesetzt wird';

  @override
  String get premiumLimitInvite => 'Freunde einladen für mehr Datenvolumen';

  @override
  String get premiumNoDailyLimit => 'Premium hat kein Tageslimit.';

  @override
  String get premiumCalmTitle => 'Kein Tageslimit mehr?';

  @override
  String get premiumCalmBody =>
      'Mit Premium hast du unbegrenztes Datenvolumen. Dein kostenloser Tarif bleibt, wie er ist.';

  @override
  String get premiumNextStepTitle => 'Der nächste Schritt ist Premium';

  @override
  String get premiumNextStepBody =>
      'Du hast schon das meiste kostenlose Datenvolumen. Premium hat kein Tageslimit.';

  @override
  String get premiumLockedTag => 'Premium';

  @override
  String premiumLockedTitle(String place) {
    return '$place mit Premium freischalten';
  }

  @override
  String get premiumLockedBody =>
      'Dieser Standort ist für Premium. Deine kostenlosen Server bleiben gleich.';

  @override
  String get premiumHeadlineLimit => 'Kein Tageslimit';

  @override
  String premiumHeadlineLocked(String place) {
    return '$place mit Premium freischalten';
  }

  @override
  String get premiumFreeStays =>
      'Der kostenlose Tarif funktioniert auch ohne Premium weiter.';

  @override
  String premiumEndsOn(String date) {
    return 'Premium endet am $date';
  }

  @override
  String get premiumRenewBody =>
      'Verlängere, um unbegrenztes Datenvolumen zu behalten. Die Verlängerung wird an dein aktuelles Enddatum angehängt.';

  @override
  String premiumEndedOn(String date) {
    return 'Premium ist am $date abgelaufen. Dein kostenloser Tarif gilt wieder.';
  }

  @override
  String get premiumRenew => 'Verlängern';

  @override
  String get noticeChannelName => 'Nachrichten von Fortiva';

  @override
  String get noticeChannelDescription =>
      'Neuigkeiten und Nachrichten vom Fortiva-Team';

  @override
  String get noticesSettingTitle => 'Benachrichtigungen';

  @override
  String get noticesSettingOn =>
      'An. Nachrichten vom Fortiva-Team können dich auch erreichen, wenn die App geschlossen ist.';

  @override
  String get noticesSettingOff =>
      'Aus. Schalte sie ein, um Nachrichten vom Fortiva-Team auch bei geschlossener App zu bekommen.';

  @override
  String get noticesOffCard =>
      'Schalte Benachrichtigungen ein, um Nachrichten vom Fortiva-Team auch bei geschlossener App zu bekommen.';

  @override
  String get noticesTurnOn => 'Einschalten';

  @override
  String get backgroundCard =>
      'Dein Handy hält Nachrichten vom Fortiva-Team vielleicht zurück, solange die App geschlossen ist. Erlaube Fortiva, im Hintergrund zu laufen, damit sie dich erreichen.';

  @override
  String get backgroundHint =>
      'Wähle auf dem nächsten Bildschirm Fortiva (falls es fehlt, lass dir alle Apps anzeigen). Stelle dann die Akkunutzung auf Uneingeschränkt oder erlaube, dass es automatisch startet und im Hintergrund läuft.';

  @override
  String get backgroundAllow => 'Erlauben';

  @override
  String get backgroundNotNow => 'Nicht jetzt';

  @override
  String get backgroundSettingTitle => 'Nachrichten bei geschlossener App';

  @override
  String get backgroundSettingSubtitle =>
      'Erlaube Fortiva, im Hintergrund zu laufen, damit Nachrichten dich auch bei geschlossener App erreichen.';

  @override
  String get backgroundCardData =>
      'Der Datensparmodus deines Handys hält Nachrichten vom Fortiva-Team vielleicht zurück, solange die App geschlossen ist.';

  @override
  String get backgroundHintData =>
      'Schalte auf dem nächsten Bildschirm Uneingeschränkte Datennutzung ein.';

  @override
  String get apnGuideTitle => 'Stabilere Verbindung mit dieser SIM';

  @override
  String get apnGuideBody =>
      'Dein Handy nutzt auf dieser SIM kein IPv6. Wenn du es einschaltest, bleibt Fortiva besser verbunden.';

  @override
  String get apnGuideShowMe => 'Zeig mir, wie';

  @override
  String get apnGuideNotNow => 'Nicht jetzt';

  @override
  String get apnGuideSheetTitle => 'IPv6 für diese SIM einschalten';

  @override
  String apnGuideStepOpen(String button) {
    return 'Tippe auf \"$button\" (oder gehe zu Einstellungen > Verbindungen > Mobile Netzwerke > Zugangspunkte).';
  }

  @override
  String apnGuideStepAccessPoint(String apn) {
    return 'Tippe auf den verwendeten Zugangspunkt ($apn).';
  }

  @override
  String get apnGuideStepAccessPointAny =>
      'Tippe auf den verwendeten Zugangspunkt.';

  @override
  String get apnGuideStepProtocol =>
      'Tippe auf \"APN-Protokoll\" und wähle \"IPv4/IPv6\".';

  @override
  String get apnGuideStepSave =>
      'Speichere (bei Samsung: Drei-Punkte-Menü, dann \"Speichern\").';

  @override
  String get apnGuideStepRestart => 'Schalte mobile Daten aus und wieder ein.';

  @override
  String get apnGuideUndo =>
      'Wenn mobile Daten nicht mehr funktionieren, stelle das APN-Protokoll wieder auf IPv4.';

  @override
  String get apnGuideOpenSettings => 'APN-Einstellungen öffnen';

  @override
  String get homeStallSearching =>
      'Die Verbindung funktioniert nicht mehr. Ein anderer Weg wird gesucht.';

  @override
  String get homeStalled => 'Verbunden, aber es kommen keine Daten durch';

  @override
  String get peerShareTitle => 'Freunden beim Verbinden helfen';

  @override
  String get peerShareSubtitle =>
      'Gib weiter, was Fortiva auf dem Handy deines Freundes braucht';

  @override
  String get peerShareBody =>
      'Wenn sich Fortiva bei deinem Freund nicht verbinden kann, holt sich sein Handy das Nötige von deinem. Das geht auch ohne Internet.';

  @override
  String peerShareSteps(String action) {
    return 'Öffne auf seinem Handy in Fortiva die Einstellungen und tippe auf \"$action\". Zeig ihm dann diese Codes nacheinander oder schick ihm alles zusammen.';
  }

  @override
  String get peerShareLoading => 'Neueste Kopie wird geladen';

  @override
  String get peerShareNothing =>
      'Auf diesem Handy gibt es gerade nichts Aktuelles zum Weitergeben. Versuche es später noch einmal.';

  @override
  String peerShareCodeOf(int current, int total) {
    return 'Code $current von $total';
  }

  @override
  String get peerSharePrevious => 'Zurück';

  @override
  String get peerShareNext => 'Weiter';

  @override
  String get peerShareCopy => 'Kopieren';

  @override
  String get peerShareSend => 'Senden';

  @override
  String get peerShareCopied =>
      'Kopiert. Füge es in den Chat mit deinem Freund ein.';

  @override
  String get peerReceiveTitle => 'Hilfe von Freunden holen';

  @override
  String get peerReceiveSubtitle => 'Wenn sonst keine Verbindung klappt';

  @override
  String peerReceiveBody(String action) {
    return 'Bitte jemanden aus deinem Freundeskreis, bei dem sich Fortiva verbinden kann, die Einstellungen in Fortiva zu öffnen und auf \"$action\" zu tippen. Hol dir dann auf einem dieser Wege das Nötige von seinem Handy.';
  }

  @override
  String get peerReceivePhotograph => 'Codes deines Freundes fotografieren';

  @override
  String get peerReceivePhotographNext => 'Nächsten Code fotografieren';

  @override
  String peerReceiveProgress(int have, int total) {
    return '$have von $total Codes erkannt';
  }

  @override
  String get peerReceiveFile => 'Datei von deinem Freund öffnen';

  @override
  String get peerReceivePaste => 'Einfügen, was dein Freund geschickt hat';

  @override
  String get peerReceiveNoCode =>
      'Auf diesem Foto ist kein Code zu finden. Halte das Handy näher heran, sodass der ganze Code zu sehen ist.';

  @override
  String get peerReceiveRefused =>
      'Damit kann Fortiva nichts anfangen. Bitte deinen Freund, es erneut zu senden.';

  @override
  String get peerReceiveNotNewer =>
      'Das hast du schon, oder sogar etwas Neueres. Versuche noch einmal, dich zu verbinden, oder frag jemand anderen aus deinem Freundeskreis.';

  @override
  String get peerReceiveTaken => 'Fertig. Tippe jetzt auf Verbinden.';

  @override
  String get peerReceiveUnavailable =>
      'Das geht auf diesem Handy nicht. Versuch es anders.';

  @override
  String get peerReceiveNothingToPaste =>
      'Noch nichts kopiert. Kopiere, was dein Freund geschickt hat, und tippe dann erneut hier.';

  @override
  String get peerOfferBody =>
      'Immer noch keine Verbindung? Freunde, bei denen Fortiva funktioniert, können dir von ihrem Handy aus helfen.';

  @override
  String get peerReceiveAgain =>
      'Diesen Code hast du schon. Bitte deinen Freund, dir den nächsten zu zeigen.';

  @override
  String get peerReceivePasteNotOurs =>
      'Was du kopiert hast, stammt nicht aus Fortiva. Kopiere die ganze Nachricht deines Freundes und versuche es dann noch einmal.';

  @override
  String peerReceiveNoPhoto(String action) {
    return 'Die Kamera hat das Foto nicht zurückgegeben. Mach das Foto mit der Kamera-App und tippe dann auf \"$action\".';
  }

  @override
  String get peerReceiveFileHint =>
      'Dateien aus Messengern musst du eventuell zuerst unter Downloads speichern.';

  @override
  String get homeTryingBackup =>
      'Keine andere Verbindung hat geklappt. Wir versuchen jetzt ein Ersatznetzwerk.';

  @override
  String get homeConnectedBackup => 'Über ein Ersatznetzwerk verbunden';

  @override
  String get backupNetwork => 'ERSATZNETZWERK';

  @override
  String get backupNetworkTitle => 'Ersatznetzwerk';

  @override
  String get backupNetworkCaption =>
      'Wird genutzt, wenn sonst nichts verbindet. Es kann langsamer sein als unsere Server.';

  @override
  String get backupNetworkPlace => 'Standort wird automatisch gewählt';

  @override
  String get speedTestStart => 'Test starten';

  @override
  String get speedTestAgain => 'Erneut testen';

  @override
  String get speedTestRunning => 'Test läuft';

  @override
  String get speedTestIdle =>
      'Sieh nach, wie schnell deine Verbindung gerade ist.';

  @override
  String get speedTestPhasePing => 'Antwortzeit wird geprüft';

  @override
  String get speedTestPhaseDownload => 'Download-Geschwindigkeit wird gemessen';

  @override
  String get speedTestPhaseUpload => 'Upload-Geschwindigkeit wird gemessen';

  @override
  String get speedTestDone => 'Test abgeschlossen';

  @override
  String get speedTestFailed =>
      'Der Test wurde nicht abgeschlossen. Prüfe deine Internetverbindung und versuche es erneut.';

  @override
  String get speedTestUnit => 'Mbit/s';

  @override
  String get ipAddressLabel => 'IP-Adresse';

  @override
  String get ipCopied => 'Adresse kopiert';

  @override
  String get ipLocation => 'Standort';

  @override
  String get ipProvider => 'Internetanbieter';

  @override
  String get ipOrganization => 'Organisation';

  @override
  String get ipTimeZone => 'Zeitzone';

  @override
  String get ipCoordinates => 'Koordinaten';

  @override
  String get ipCheckFailed => 'Deine Adresse konnte nicht geprüft werden';

  @override
  String get historyAverage => 'Durchschnitt';

  @override
  String get historyRecentDays => 'Die letzten Tage';

  @override
  String yesterdayAt(String time) {
    return 'Gestern um $time';
  }

  @override
  String dateAt(String date, String time) {
    return '$date um $time';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds Sek.';
  }

  @override
  String get stageOwn => 'Fortiva-Server';

  @override
  String get stageCommunity => 'Community-Server';

  @override
  String stageProgress(int n, int total) {
    return 'Schritt $n von $total';
  }

  @override
  String get stageTryingOwn => 'Fortiva-Server werden versucht';

  @override
  String get stageTryingCommunity => 'Community-Server werden versucht';

  @override
  String get stageOwnFailedTryingCommunity =>
      'Die Fortiva-Server haben sich hier nicht verbunden. Jetzt werden Community-Server versucht.';

  @override
  String stageLastWorked(String server) {
    return 'Zuletzt funktionierender Server: $server';
  }

  @override
  String stageTriedBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wege versucht, hier blockiert',
      one: '$count Weg versucht, hier blockiert',
    );
    return '$_temp0';
  }

  @override
  String stageTriedFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wege versucht, keine Verbindung',
      one: '$count Weg versucht, keine Verbindung',
    );
    return '$_temp0';
  }

  @override
  String get stageNotConnected => 'Keine Verbindung';

  @override
  String get stageConnected => 'Hier verbunden';

  @override
  String get stageSkipped => 'Diesmal übersprungen';

  @override
  String stageMoreToCheck(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Noch $count Wege zu prüfen',
      one: 'Noch $count Weg zu prüfen',
    );
    return '$_temp0';
  }

  @override
  String stageNextTry(String stage, String time) {
    return 'Nächster Versuch in $time, beginnt mit $stage';
  }

  @override
  String get searchSlowHint =>
      'Das kann ein, zwei Minuten dauern. Tippe auf den Knopf, um die Suche zu beenden.';

  @override
  String get searchStopped => 'Suche beendet';

  @override
  String get homeConnectedCommunity => 'Über einen Community-Server verbunden';

  @override
  String get stageGettingServers => 'Deine Server werden abgerufen';

  @override
  String stageNextTryStarting(String stage) {
    return 'Nächster Versuch beginnt jetzt mit $stage';
  }
}
