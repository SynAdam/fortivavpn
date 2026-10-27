// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class SFr extends S {
  SFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'FortivaVPN';

  @override
  String get statusDisconnected => 'Déconnecté';

  @override
  String get statusConnecting => 'Connexion...';

  @override
  String get statusConnected => 'Connecté';

  @override
  String get statusDisconnecting => 'Déconnexion...';

  @override
  String get statusError => 'Erreur';

  @override
  String get statusVerifying => 'Vérification...';

  @override
  String get disconnect => 'Déconnecter';

  @override
  String get connectBtn => 'CONNEXION';

  @override
  String get disconnectBtn => 'DÉCONNECTER';

  @override
  String get pleaseWait => 'VEUILLEZ PATIENTER';

  @override
  String get locationLabel => 'Emplacement :';

  @override
  String get selectServer => 'Choisir un serveur';

  @override
  String get serverLocation => 'Emplacement du serveur';

  @override
  String get searchServers => 'Rechercher un serveur';

  @override
  String get locationsTitle => 'Emplacements';

  @override
  String get sortLatency => 'Tri : Latence';

  @override
  String get sortAZ => 'Tri : A-Z';

  @override
  String get sortedByLatency => 'Trié par latence';

  @override
  String get sortedAZ => 'Trié A–Z';

  @override
  String get pingAll => 'Ping tous';

  @override
  String get pinging => 'Ping en cours...';

  @override
  String get ping => 'Ping';

  @override
  String get stop => 'Arrêter';

  @override
  String get fastestServer => 'SERVEUR LE PLUS RAPIDE';

  @override
  String get timeout => 'expiration';

  @override
  String get tabCommunity => 'Communauté';

  @override
  String get tabFree => 'Gratuit';

  @override
  String get tabPremium => 'Premium';

  @override
  String get noCommunityServers => 'Aucun serveur communautaire';

  @override
  String get communityLoadFailed => 'Impossible de charger cette liste';

  @override
  String get communityRetry => 'Réessayer';

  @override
  String get officialTabExplainer =>
      'Gérés par Fortiva et maintenus en ligne par nos soins. Partagés par tous ceux qui utilisent l\'application. Commencez ici.';

  @override
  String get communityTabExplainer =>
      'Options de connexion supplémentaires. La vitesse et la disponibilité varient.';

  @override
  String get noFreeServers => 'Aucun serveur gratuit';

  @override
  String get noPremiumServers => 'Aucun serveur premium';

  @override
  String noResultsFor(String query) {
    return 'Aucun résultat pour « $query »';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get freeBadge => 'GRATUIT';

  @override
  String get settings => 'Paramètres';

  @override
  String get connection => 'Connexion';

  @override
  String get dnsConfiguration => 'Configuration DNS';

  @override
  String get customDns => 'Serveurs DNS personnalisés';

  @override
  String get about => 'À propos';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get contactUs => 'Nous contacter';

  @override
  String get rateOnGooglePlay => 'Noter Fortiva sur Google Play';

  @override
  String get website => 'Site web';

  @override
  String get copyright => '© 2026 NimusAI';

  @override
  String get version => 'Version';

  @override
  String get language => 'Langue';

  @override
  String get languageSubtitle => 'Langue d\'affichage de l\'app';

  @override
  String get whatIsDns => 'Qu\'est-ce que le DNS ?';

  @override
  String get dnsExplanation =>
      'Le DNS (Domain Name System) est l\'annuaire d\'Internet. Il traduit les noms de sites web en adresses IP.\n\nPersonnaliser votre DNS peut :\n• Améliorer la vitesse de connexion ⚡\n• Renforcer la confidentialité 🔒\n• Contourner les blocages de censure 🌍';

  @override
  String get configuration => 'Configuration';

  @override
  String get primaryDns => 'DNS primaire';

  @override
  String get primaryDnsHint => 'Par défaut : 1.1.1.1';

  @override
  String get secondaryDns => 'DNS secondaire (Optionnel)';

  @override
  String get secondaryDnsHint => 'Par défaut : 8.8.8.8';

  @override
  String get saveConfiguration => 'Enregistrer la configuration';

  @override
  String get dnsSaved => 'Configuration DNS enregistrée';

  @override
  String get invalidPrimaryDns => 'Adresse IP DNS primaire invalide';

  @override
  String get invalidSecondaryDns => 'Adresse IP DNS secondaire invalide';

  @override
  String get statistics => 'Statistiques';

  @override
  String get overview => 'APERÇU';

  @override
  String get connectionsLabel => 'Connexions';

  @override
  String get totalTime => 'Temps total';

  @override
  String get dataUsage => 'UTILISATION DES DONNÉES';

  @override
  String get uploaded => 'Envoyé';

  @override
  String get downloaded => 'Téléchargé';

  @override
  String get total => 'Total';

  @override
  String lastUpdated(String date) {
    return 'Dernière mise à jour : $date';
  }

  @override
  String today(String time) {
    return 'Aujourd\'hui à $time';
  }

  @override
  String get yesterday => 'Hier';

  @override
  String daysAgo(int count) {
    return 'Il y a $count jours';
  }

  @override
  String get noDataYet => 'Pas encore de données';

  @override
  String get connectToStart =>
      'Connectez-vous à un VPN pour commencer le suivi';

  @override
  String get errorConnectionFailed => 'Échec de la connexion';

  @override
  String get errorServerNotWorking =>
      'Le serveur ne fonctionne pas — essayez-en un autre';

  @override
  String get errorServerNotForwarding => 'Le serveur ne transmet pas le trafic';

  @override
  String get errorUnexpected => 'Erreur inattendue';

  @override
  String get errorDisconnectionFailed => 'Échec de la déconnexion';

  @override
  String get errorFailedToRegister =>
      'Échec de l\'enregistrement de l\'appareil';

  @override
  String get ipInformation => 'Informations IP';

  @override
  String get connectionAnalytics => 'Analyse de connexion';

  @override
  String get recentSessions => 'Sessions récentes';

  @override
  String get speedTest => 'Test de vitesse';

  @override
  String get startTest => 'Démarrer le test';

  @override
  String get download => 'Téléchargement';

  @override
  String get upload => 'Envoi';

  @override
  String get testingViaVpn => 'Test via VPN';

  @override
  String get testingDirect => 'Test de connexion directe';

  @override
  String get splitTunneling => 'Tunneling fractionné';

  @override
  String get splitTunnelingDescription =>
      'Choisissez les catégories qui contournent le tunnel VPN. Les applications exclues utiliseront votre connexion Internet normale.';

  @override
  String get enableSplitTunneling => 'Activer le tunneling fractionné';

  @override
  String get splitTunnelActive =>
      'Les applications sélectionnées contournent le VPN';

  @override
  String get splitTunnelInactive => 'Tout le trafic passe par le VPN';

  @override
  String get bypassVpnFor => 'Contourner le VPN pour';

  @override
  String get tools => 'Outils';

  @override
  String get settingsGeneral => 'Général';

  @override
  String get shareDiagnosticsTitle => 'Partager les diagnostics de connexion';

  @override
  String get shareDiagnosticsBody =>
      'Envoie les rapports de connexion, votre opérateur et votre pays, le modèle du téléphone et la version d\'Android, les noms des sites auxquels vous accédez via le VPN avec leur nombre par jour, et si vous avez vu ou touché nos messages, nos offres Premium et notre carte d\'invitation. Nous ne voyons jamais les pages que vous ouvrez ni ce que vous envoyez.';

  @override
  String get security => 'Sécurité';

  @override
  String get privacyDashboard => 'Tableau de bord de confidentialité';

  @override
  String get privacyDashboardSubtitle =>
      'Info IP et protection contre les fuites';

  @override
  String get connectionAnalyticsSubtitle =>
      'Historique des sessions et graphiques';

  @override
  String get speedTestSubtitle => 'Testez votre vitesse de connexion';

  @override
  String get splitTunnelingSubtitle => 'Routage VPN des applications';

  @override
  String get splashTagline => 'Un accès privé, où que vous soyez';

  @override
  String get openSourceLicence => 'Licence open source';

  @override
  String get sourceOfferTitle => 'Licence open source';

  @override
  String get sourceOfferBody =>
      'Fortiva VPN est un logiciel libre sous GNU General Public License v3. Il s\'appuie sur Xray-core et d\'autres projets open source.\n\nVous avez droit au code source complet de la version que vous avez installée. Pour le demander, écrivez à admin@fortivavpn.com en indiquant la version de votre application. Cette offre est valable trois ans à compter de la date à laquelle vous avez reçu cette version.';

  @override
  String get close => 'Fermer';

  @override
  String get account => 'Compte';

  @override
  String get deleteAccount => 'Supprimer le compte';

  @override
  String get deleteAccountSubtitle =>
      'Supprimer définitivement cet appareil et vos données';

  @override
  String get deleteAccountConfirmTitle => 'Supprimer votre compte ?';

  @override
  String get deleteAccountConfirmBody =>
      'Cela supprime l\'enregistrement de votre appareil, les serveurs personnels créés pour vous et vos échanges avec l\'assistance. L\'historique de connexion sur ce téléphone est également effacé.\n\nCette action est irréversible. Vous pouvez recommencer à tout moment en rouvrant l\'application.';

  @override
  String deleteAccountConfirmRetention(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '$days jour',
    );
    return 'Votre fiche de compte est supprimée immédiatement. Les copies présentes dans les sauvegardes et les journaux serveur anonymes sont effacées sous $_temp0.';
  }

  @override
  String get deleteAccountConfirmRetentionNoDays =>
      'Votre fiche de compte est supprimée immédiatement. Les copies présentes dans les sauvegardes et les journaux serveur anonymes sont effacées plus tard, dans les délais indiqués par notre politique de confidentialité.';

  @override
  String get deleteAccountCancel => 'Garder mon compte';

  @override
  String get deleteAccountConfirm => 'Supprimer';

  @override
  String get deleteAccountInProgress => 'Suppression de votre compte';

  @override
  String get deleteAccountDone => 'Votre compte a été supprimé.';

  @override
  String get deleteAccountFailed =>
      'Impossible de supprimer votre compte. Vérifiez votre connexion et réessayez.';

  @override
  String get homeTapToConnect => 'Touchez pour vous connecter';

  @override
  String get homeChecking => 'Vérification de la connexion';

  @override
  String get homePreparing => 'Configuration de votre serveur';

  @override
  String get homeDisconnecting => 'Déconnexion';

  @override
  String get homeFindingPath => 'Recherche d\'un chemin';

  @override
  String get diagCheckingInternet => 'Vérification de votre connexion Internet';

  @override
  String get diagInternationalCut =>
      'L\'Internet international est coupé sur ce réseau';

  @override
  String diagPathRow(String city, int n) {
    return '$city, chemin $n';
  }

  @override
  String get diagOpen => 'ouvert';

  @override
  String get diagBlocked => 'bloqué';

  @override
  String get diagSkipped => 'ignoré aujourd\'hui';

  @override
  String diagConnectingThrough(String city) {
    return 'Connexion via $city';
  }

  @override
  String get diagVerifying => 'Vérification du trafic';

  @override
  String get diagNoInternet =>
      'Votre téléphone n\'a pas d\'accès Internet pour le moment.';

  @override
  String get diagCutOff =>
      'Votre réseau n\'accède pas à l\'Internet international pour le moment. Touchez pour réessayer.';

  @override
  String get diagNothingOpen =>
      'Tous les chemins sont bloqués pour le moment. Touchez pour réessayer.';

  @override
  String get homeTryingAgain =>
      'Tous les chemins sont bloqués pour le moment. Nouvel essai dans un instant.';

  @override
  String get homeCutOffTryingAgain =>
      'Votre réseau n\'accède pas à l\'Internet international pour le moment. Nouvel essai dans un instant.';

  @override
  String get homeOfflineTryingAgain =>
      'Votre téléphone n\'a pas d\'accès Internet pour le moment. Nouvel essai dans un instant.';

  @override
  String get diagPathFailed =>
      'Le chemin était ouvert, mais le tunnel ne s\'est pas établi. Touchez pour réessayer.';

  @override
  String get openVpnSettings => 'Ouvrir les réglages VPN';

  @override
  String get yourServer => 'VOTRE SERVEUR';

  @override
  String get yourServerCaption =>
      'Rien qu\'à vous. Personne d\'autre ne s\'y connecte.';

  @override
  String get ourServer => 'NOTRE SERVEUR';

  @override
  String get ourServerCaption =>
      'Géré par Fortiva et partagé avec tous. Utilisé jusqu\'à ce que votre serveur soit prêt.';

  @override
  String get communityServer => 'SERVEUR COMMUNAUTAIRE';

  @override
  String get communityServerCaption =>
      'Une option de connexion supplémentaire. Elle peut cesser de fonctionner à tout moment.';

  @override
  String communityServerNumber(String n) {
    return 'Serveur communautaire $n';
  }

  @override
  String get myServersTitle => 'Vos serveurs';

  @override
  String get myServersExplainer =>
      'Chaque appareil Fortiva reçoit son propre serveur dans chaque emplacement, avec des identifiants qui n\'appartiennent qu\'à cette installation. Aucun compte n\'est nécessaire.';

  @override
  String get myServersInUse => 'Utilisé';

  @override
  String get myServersEmpty => 'Aucun serveur attribué pour l\'instant';

  @override
  String get myServersRetry => 'Réessayer';

  @override
  String get myServersBlockedTitle => 'Vous avez épuisé les données du jour';

  @override
  String get myServersBlockedWait =>
      'Votre quota se réinitialise automatiquement. Revenez bientôt.';

  @override
  String myServersMoved(String place) {
    return 'Utilise maintenant $place';
  }

  @override
  String get copyLink => 'Copier le lien';

  @override
  String get linkCopied => 'Lien copié';

  @override
  String quotaUsedToday(String used, String limit) {
    return '$used sur $limit utilisés aujourd\'hui';
  }

  @override
  String get quotaUsedUp => 'Données du jour épuisées';

  @override
  String get quotaUnlimited => 'Données illimitées';

  @override
  String get quotaDaily => 'Données du jour';

  @override
  String get quotaLimitReached => 'Limite quotidienne atteinte';

  @override
  String quotaLeftOf(String left, String limit) {
    return '$left sur $limit restants';
  }

  @override
  String get quotaResetsShortly => 'Réinitialisation imminente';

  @override
  String quotaResetsInHours(int hours) {
    return 'Réinitialisation dans $hours h';
  }

  @override
  String quotaResetsInMinutes(int minutes) {
    return 'Réinitialisation dans $minutes min';
  }

  @override
  String get myServersSubtitle => 'Les serveurs attribués à cet appareil';

  @override
  String get sharedServersTitle => 'Serveurs partagés';

  @override
  String get sharedServersSubtitle =>
      'Emplacements publics, en solution de repli';

  @override
  String get tabOfficial => 'Nos serveurs';

  @override
  String get noOfficialServers => 'Aucun serveur Fortiva pour le moment';

  @override
  String get inviteTitle => 'Inviter des amis';

  @override
  String get inviteSubtitle => 'Gagnez plus de données par jour';

  @override
  String get inviteYourCode => 'Votre code d\'invitation';

  @override
  String get inviteShareAction => 'Partager l\'invitation';

  @override
  String get inviteCopyAction => 'Copier le code';

  @override
  String get inviteCodeCopied => 'Code copié';

  @override
  String inviteShareMessage(String code, String url) {
    return 'Un VPN gratuit qui marche bien chez moi : Fortiva. Sans inscription.\nInstalle-le avec ce lien :\n$url\nMon code d\'invitation : $code';
  }

  @override
  String get inviteHowItWorks => 'Comment ça marche';

  @override
  String inviteHowItWorksBody(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours différents',
      one: '$days jour',
    );
    return 'Partagez votre code. Quand quelqu\'un installe l\'application, saisit le code et utilise le VPN sur $_temp0, $amount s\'ajoutent à vos données quotidiennes, définitivement.';
  }

  @override
  String inviteHowItWorksBodyNoAmount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours différents',
      one: '$days jour',
    );
    return 'Partagez votre code. Quand quelqu\'un installe l\'application, saisit le code et utilise le VPN sur $_temp0, vous obtenez plus de données chaque jour, définitivement.';
  }

  @override
  String inviteHowItWorksBodyNoDays(String amount) {
    return 'Partagez votre code. Quand quelqu\'un installe l\'application, saisit le code et utilise le VPN pendant quelque temps, $amount s\'ajoutent à vos données quotidiennes, définitivement.';
  }

  @override
  String get inviteHowItWorksBodyNoAmountNoDays =>
      'Partagez votre code. Quand quelqu\'un installe l\'application, saisit le code et utilise le VPN pendant quelque temps, vous obtenez plus de données chaque jour, définitivement.';

  @override
  String inviteHowItWorksCap(String max) {
    return 'Vos invitations peuvent vous rapporter jusqu\'à $max par jour.';
  }

  @override
  String get inviteStatInvited => 'Invités';

  @override
  String get inviteStatEarning => 'Qualifiés';

  @override
  String get inviteStatBonus => 'Données bonus';

  @override
  String inviteBonusPerDay(String amount) {
    return '+$amount par jour';
  }

  @override
  String get inviteNoBonusYet => 'Pas encore de bonus';

  @override
  String invitePendingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations ne sont pas encore qualifiées',
      one: '1 invitation n\'est pas encore qualifiée',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String inviteJoinedWith(String code) {
    return 'Vous avez rejoint avec le code $code';
  }

  @override
  String get inviteLoadFailed =>
      'Impossible de charger votre code d\'invitation';

  @override
  String get inviteRetry => 'Réessayer';

  @override
  String get inviteHaveCodeTitle => 'Vous avez un code d\'invitation ?';

  @override
  String inviteHaveCodeSubtitle(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Saisissez-le dans les $hours premières heures',
      one: 'Saisissez-le dans la première heure',
    );
    return '$_temp0';
  }

  @override
  String get inviteHaveCodeSubtitleNoHours =>
      'Saisissez-le peu après l\'installation';

  @override
  String get inviteEnterCodeHint => 'Code d\'invitation';

  @override
  String get inviteApplyAction => 'Appliquer';

  @override
  String get inviteNotNowAction => 'Plus tard';

  @override
  String inviteClaimAccepted(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours différents',
      one: '$days jour',
    );
    return 'Invitation acceptée. Elle compte une fois que vous aurez utilisé le VPN sur $_temp0, à partir d\'aujourd\'hui.';
  }

  @override
  String get inviteClaimAcceptedNoDays =>
      'Invitation acceptée. Elle compte une fois que vous aurez utilisé le VPN pendant un certain temps, à partir d\'aujourd\'hui.';

  @override
  String get inviteClaimAlready =>
      'Cet appareil a déjà utilisé un code d\'invitation';

  @override
  String get inviteClaimRejected =>
      'Ce code n\'a pas fonctionné. Vérifiez-le et réessayez';

  @override
  String get inviteClaimNetwork => 'Serveur injoignable. Réessayez';

  @override
  String get inviteCardTitle =>
      'Fortiva marche bien pour toi ? Envoie-le à tes amis';

  @override
  String get inviteCardBody =>
      'Envoie le lien d\'installation à ton ami pour qu\'il se connecte gratuitement lui aussi.';

  @override
  String inviteCardReward(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Quand ton ami commencera à utiliser Fortiva, tu recevras $days jours de Premium.',
      one:
          'Quand ton ami commencera à utiliser Fortiva, tu recevras $days jour de Premium.',
    );
    return '$_temp0';
  }

  @override
  String get inviteCardRewardNoAmount =>
      'Quand ton ami commencera à utiliser Fortiva, tu recevras du Premium en cadeau.';

  @override
  String get inviteSendTelegram => 'Telegram';

  @override
  String get inviteSendWhatsApp => 'WhatsApp';

  @override
  String get inviteCopyLink => 'Copier le lien';

  @override
  String get inviteOtherApps => 'Autres applis';

  @override
  String get inviteLinkCopied => 'Message d\'invitation copié';

  @override
  String get invitePasteBody =>
      'Copiez le code dans le message de votre ami et collez-le ici.';

  @override
  String get invitePasteAction => 'Coller';

  @override
  String get inviteErrorTooLate =>
      'Le délai pour saisir un code d\'invitation sur ce téléphone est dépassé.';

  @override
  String get inviteErrorUnknown =>
      'Ce code est introuvable. Copiez-le à nouveau depuis le message de votre ami.';

  @override
  String get inviteErrorOwnCode =>
      'C\'est votre propre code. Saisissez le code de votre ami.';

  @override
  String get inviteErrorMutual =>
      'Votre ami et vous ne pouvez pas vous inviter mutuellement.';

  @override
  String inviteHowItWorksPremium(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Chaque ami qui commence à utiliser Fortiva vous offre aussi $days jours de Premium.',
      one:
          'Chaque ami qui commence à utiliser Fortiva vous offre aussi $days jour de Premium.',
    );
    return '$_temp0';
  }

  @override
  String inviteHowItWorksPremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other:
          'Vos invitations peuvent vous rapporter jusqu\'à $max jours de Premium.',
      one:
          'Vos invitations peuvent vous rapporter jusqu\'à $max jour de Premium.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeLive =>
      'Votre bonus dure tant que vos amis continuent d\'utiliser Fortiva. Si un ami arrête, votre bonus peut baisser.';

  @override
  String inviteTreeNext(String amount) {
    return 'Votre prochain ami ajoute $amount par jour une fois qualifié et actif.';
  }

  @override
  String inviteTreeKept(String amount) {
    return 'Votre bonus ne descend pas sous $amount par jour, le bonus que vous aviez grâce à vos invitations précédentes. Ce montant ne peut baisser que si l\'une de vos invitations est supprimée.';
  }

  @override
  String get inviteTreeSlotsTitle => 'Vos places';

  @override
  String get inviteTreeSlotActive => 'Actif';

  @override
  String get inviteTreeSlotNotActive => 'Inactif pour l\'instant';

  @override
  String get inviteTreeSlotEmpty => 'Place libre';

  @override
  String inviteTreePaysNow(String amount) {
    return '+$amount par jour maintenant';
  }

  @override
  String inviteTreePairFull(String amount) {
    return '+$amount par jour quand tous les deux sont actifs';
  }

  @override
  String get inviteTreeNothingYet => 'Rien pour l\'instant';

  @override
  String get inviteTreeFriendsTitle => 'Grâce à vos places';

  @override
  String get inviteTreeRowFriends => 'Dans vos places';

  @override
  String inviteTreeRowSteps(int steps) {
    String _temp0 = intl.Intl.pluralLogic(
      steps,
      locale: localeName,
      other: 'À $steps étapes de vous',
      one: 'À $steps étape de vous',
    );
    return '$_temp0';
  }

  @override
  String inviteTreeRowPeople(int people, int active) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people personnes',
      one: '$people personne',
    );
    return '$_temp0, $active actifs';
  }

  @override
  String inviteTreeHowSlots(int slots) {
    String _temp0 = intl.Intl.pluralLogic(
      slots,
      locale: localeName,
      other:
          'Partagez votre code. Les $slots premiers amis qui se qualifient remplissent vos places, par paires.',
      one:
          'Partagez votre code. Le premier ami qui se qualifie remplit votre place.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeHowSlotsNoNumber =>
      'Partagez votre code. Les premiers amis qui se qualifient remplissent vos places, par paires.';

  @override
  String get inviteTreeHowPair =>
      'Une paire ajoute plus de données quand tous les deux y sont actifs.';

  @override
  String get inviteTreeHowFriendsSlots =>
      'Quand vos places sont pleines, vos amis suivants qui se qualifient prennent les places libres suivantes, plus loin de vous. Eux aussi vous ajoutent des données, d\'autant moins qu\'ils sont éloignés.';

  @override
  String get inviteTreeHowOthers =>
      'Votre première paire peut aussi accueillir des personnes que vous n\'avez pas invitées. Elles vous ajoutent des données de la même façon.';

  @override
  String inviteTreeHowActive(int days, int window) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '$days jour',
    );
    String _temp1 = intl.Intl.pluralLogic(
      window,
      locale: localeName,
      other: '$window derniers jours',
      one: '$window dernier jour',
    );
    return 'Un ami est actif tant qu\'il a utilisé le VPN au moins $_temp0 sur les $_temp1.';
  }

  @override
  String get inviteTreeHowActiveNoNumber =>
      'Un ami est actif tant qu\'il continue d\'utiliser le VPN.';

  @override
  String inviteTreeHowCap(String max) {
    return 'Les invitations peuvent ajouter jusqu\'à $max par jour.';
  }

  @override
  String get inviteTreeHowCapNoAmount =>
      'Ce que les invitations ajoutent est limité chaque jour.';

  @override
  String get inviteTreeIntroTitle => 'Comment vos amis ajoutent des données';

  @override
  String get inviteTreeIntroOpen => 'Voir étape par étape';

  @override
  String inviteTreeIntroStep(int current, int total) {
    return 'Étape $current sur $total';
  }

  @override
  String get inviteTreeIntroSkip => 'Passer';

  @override
  String get inviteTreeIntroNext => 'Suivant';

  @override
  String get inviteTreeIntroBack => 'Retour';

  @override
  String get inviteTreeIntroDone => 'Terminé';

  @override
  String get inviteTreeIntroYou => 'Vous';

  @override
  String get inviteTreeIntroSlotsTitle =>
      'Vos amis remplissent vos places par paires';

  @override
  String get inviteTreeIntroSlotsArt =>
      'Vous, votre code d\'invitation et vos places par paires. Chaque place indique si elle est libre, ou si la personne qui l\'occupe est active ou inactive pour l\'instant.';

  @override
  String get inviteTreeIntroPairTitle =>
      'Une paire ajoute le plus quand les deux sont actifs';

  @override
  String inviteTreeIntroPairBoth(String full, String one) {
    return 'Quand les amis de votre première paire sont tous les deux actifs, elle ajoute $full par jour. Quand un seul d\'entre eux est actif, elle ajoute $one par jour.';
  }

  @override
  String inviteTreeIntroPairBothOnly(String full) {
    return 'Quand les amis de votre première paire sont tous les deux actifs, elle ajoute $full par jour. Quand un seul d\'entre eux est actif, elle n\'ajoute rien.';
  }

  @override
  String inviteTreeIntroPairNoOne(String full) {
    return 'Quand les amis de votre première paire sont tous les deux actifs, elle ajoute $full par jour. Quand un seul d\'entre eux est actif, elle ajoute moins.';
  }

  @override
  String get inviteTreeIntroPairOthersLess =>
      'Vos autres paires ajoutent moins.';

  @override
  String inviteTreeIntroAdds(String amount) {
    return '+$amount par jour';
  }

  @override
  String get inviteTreeIntroYourFriend => 'Votre ami';

  @override
  String get inviteTreeIntroTotalTitle => 'Vos données venant d\'amis';

  @override
  String get inviteTreeIntroTotalNow => 'Venant d\'amis, maintenant';

  @override
  String get inviteTreeIntroTotalMost =>
      'Le maximum que les invitations peuvent ajouter';

  @override
  String get inviteTreeIntroTotalKept =>
      'Conservé de vos invitations précédentes';

  @override
  String inviteTreeIntroTotalReach(String max) {
    return 'Les données gratuites et celles de vos amis peuvent atteindre $max par jour.';
  }

  @override
  String inviteTreeIntroPerDay(String amount) {
    return '$amount par jour';
  }

  @override
  String inviteTreeSheetNext(String amount) {
    return 'Votre prochain ami ajoute $amount par jour une fois qualifié et actif. Cela ne s\'ajoute pas aux données d\'aujourd\'hui.';
  }

  @override
  String get inviteTreeHero => 'Vos amis augmentent vos données quotidiennes';

  @override
  String inviteTreePremiumEach(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Chaque ami qui se qualifie avec votre code ajoute aussi $days jours de Premium pour vous.',
      one:
          'Chaque ami qui se qualifie avec votre code ajoute aussi $days jour de Premium pour vous.',
    );
    return '$_temp0';
  }

  @override
  String inviteTreePremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Les invitations peuvent ajouter jusqu\'à $max jours de Premium.',
      one: 'Les invitations peuvent ajouter jusqu\'à $max jour de Premium.',
    );
    return '$_temp0';
  }

  @override
  String inviteTreeIntroSlotsBody(int slots) {
    String _temp0 = intl.Intl.pluralLogic(
      slots,
      locale: localeName,
      other:
          'Les amis qui vous rejoignent avec votre code peuvent ajouter à vos données quotidiennes. Vous avez $slots places pour eux. Chaque place accueille un ami, et les places vont par paires. Votre première paire se remplit en premier. D\'autres amis peuvent encore vous rejoindre quand vos places sont pleines.',
      one:
          'Les amis qui vous rejoignent avec votre code peuvent ajouter à vos données quotidiennes. Vous avez $slots place pour eux. Chaque place accueille un ami, et les places vont par paires. Votre première paire se remplit en premier. D\'autres amis peuvent encore vous rejoindre quand vos places sont pleines.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeIntroSlotsBodyNoNumber =>
      'Les amis qui vous rejoignent avec votre code peuvent ajouter à vos données quotidiennes. Vous avez des places pour eux. Chaque place accueille un ami, et les places vont par paires. Votre première paire se remplit en premier. D\'autres amis peuvent encore vous rejoindre quand vos places sont pleines.';

  @override
  String get inviteTreeIntroJoinTitle => 'Comment un ami prend une place';

  @override
  String inviteTreeIntroJoinCode(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other:
          'Votre ami doit saisir votre code sur son écran d\'invitation dans un délai de $hours heures après avoir installé Fortiva.',
      one:
          'Votre ami doit saisir votre code sur son écran d\'invitation dans un délai de $hours heure après avoir installé Fortiva.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeIntroJoinCodeNoNumber =>
      'Votre ami doit saisir votre code sur son écran d\'invitation peu après avoir installé Fortiva.';

  @override
  String inviteTreeIntroJoinQualify(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Ensuite, il doit utiliser le VPN sur $days jours différents. Il est alors qualifié et prend la place libre suivante.',
      one:
          'Ensuite, il doit utiliser le VPN sur $days jour. Il est alors qualifié et prend la place libre suivante.',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeIntroJoinQualifyNoNumber =>
      'Ensuite, il doit utiliser le VPN pendant un certain temps. Il est alors qualifié et prend la place libre suivante.';

  @override
  String get inviteTreeIntroJoinPlay =>
      'S\'il installe Fortiva depuis Google Play avec votre lien, le code est saisi pour lui.';

  @override
  String get inviteTreeIntroJoinWaiting =>
      'Tant qu\'il n\'est pas qualifié, votre écran d\'invitation le compte dans « Invités », mais pas encore dans « Qualifiés ».';

  @override
  String get inviteTreeIntroJoinStepCode => 'Saisit votre code';

  @override
  String get inviteTreeIntroJoinStepUse => 'Utilise le VPN';

  @override
  String get inviteTreeIntroJoinStepSlot => 'Prend une place';

  @override
  String get inviteTreeIntroJoinArt =>
      'Un ami saisit votre code, utilise le VPN sur des jours différents, puis prend la place libre suivante.';

  @override
  String get inviteTreeIntroPairsBody =>
      'Chaque paire peut ajouter des données pour vous. Elle en ajoute le plus quand les personnes qui la forment sont toutes les deux actives.';

  @override
  String get inviteTreeIntroPairsCaption =>
      'Ce que chaque paire ajoute à vos données par jour';

  @override
  String get inviteTreeIntroBothActive => 'Tous les deux actifs';

  @override
  String get inviteTreeIntroOneActive => 'Un actif';

  @override
  String inviteTreeIntroPlus(String amount) {
    return '+$amount';
  }

  @override
  String get inviteTreeIntroNothing => 'Rien';

  @override
  String get inviteTreeIntroPairNow =>
      'Les montants mis en avant sont ce que vos paires ajoutent maintenant.';

  @override
  String get inviteTreeIntroPairsArt =>
      'Vos paires, et ce que chacune ajoute par jour quand les personnes qui la forment sont toutes les deux actives, et quand l\'une l\'est.';

  @override
  String get inviteTreeIntroActiveTitle =>
      'Un ami ajoute des données tant qu\'il est actif';

  @override
  String get inviteTreeIntroActiveStops =>
      'Si un ami arrête d\'utiliser Fortiva, sa paire ajoute moins et votre bonus peut baisser. Il garde sa place. Quand il utilise de nouveau Fortiva, sa paire ajoute de nouveau plus.';

  @override
  String get inviteTreeIntroActiveFar =>
      'Les personnes plus éloignées qui ajoutent des données pour vous ne comptent elles aussi que tant qu\'elles sont actives.';

  @override
  String get inviteTreeIntroActiveArt =>
      'Une paire dans laquelle un ami a arrêté d\'utiliser Fortiva. La paire ajoute maintenant moins.';

  @override
  String get inviteTreeIntroFullTitle => 'Quand vos places sont pleines';

  @override
  String get inviteTreeIntroFullBody =>
      'Quand toutes vos places sont prises, votre prochain ami va dans la première paire de quelqu\'un qui est dans vos places, dans l\'ordre à partir de votre première place. Cette paire ajoute des données pour cette personne, et moins pour vous.';

  @override
  String get inviteTreeIntroFullLess =>
      'Plus une place est éloignée, moins elle ajoute pour vous. Les places très éloignées n\'ajoutent rien.';

  @override
  String get inviteTreeIntroNextFriend => 'Votre prochain ami';

  @override
  String get inviteTreeIntroLaterFriend => 'Un ami qui arrive plus tard';

  @override
  String get inviteTreeIntroFullArt =>
      'Plus tard, un ami prend une place libre dans la première paire de quelqu\'un qui est dans vos places. Cette paire ajoute des données pour cette personne, et moins pour vous.';

  @override
  String get inviteTreeIntroOthersTitle =>
      'Votre première paire peut accueillir des personnes que vous n\'avez pas invitées';

  @override
  String get inviteTreeIntroOthersWhy =>
      'Vous nous avez rejoints avec le code d\'un ami. Quand ses places sont pleines, ses amis suivants peuvent prendre une place libre dans votre première paire. Les amis d\'autres personnes aussi. Qui que ce soit, cette personne ajoute des données pour vous de la même façon que vos propres amis.';

  @override
  String get inviteTreeIntroOthersYours =>
      'Vos propres amis remplissent vos autres places libres, puis des places libres plus éloignées.';

  @override
  String get inviteTreeIntroNotInvited => 'Pas invité par vous';

  @override
  String get inviteTreeIntroOthersArt =>
      'Un exemple de votre première paire, avec un ami que vous avez invité et une personne que vous n\'avez pas invitée. Tous les deux ajoutent des données pour vous tant qu\'ils sont actifs.';

  @override
  String get inviteTreeIntroShareTitle =>
      'Invitez des amis qui utiliseront Fortiva';

  @override
  String get inviteTreeIntroShareBody =>
      'Un ami ajoute des données pour vous uniquement tant qu\'il est actif. Envoyez votre invitation à des amis qui ont besoin d\'un VPN.';

  @override
  String get inviteTreeQaTitle => 'Questions et réponses';

  @override
  String get inviteTreeQaCountQ =>
      'Mon ami a saisi mon code. Quand prend-il une place ?';

  @override
  String get inviteTreeQaCountDay =>
      'Seuls comptent les jours où il utilise un peu de données via le VPN. Ouvrir l\'application ne suffit pas. Il n\'y a pas de date limite pour ces jours.';

  @override
  String get inviteTreeQaCountOther =>
      'Un téléphone qui a déjà saisi un code ne peut pas en saisir un autre. Un ami et vous ne pouvez pas saisir le code l\'un de l\'autre.';

  @override
  String get inviteTreeQaDownQ => 'Pourquoi mon bonus a-t-il baissé ?';

  @override
  String get inviteTreeQaDownA =>
      'Quelqu\'un qui ajoute des données pour vous n\'est pas actif en ce moment. Ce peut être un ami dans vos places ou quelqu\'un de plus éloigné. Quand il utilisera de nouveau Fortiva, il ajoutera de nouveau des données.';

  @override
  String get inviteTreeQaDownLater =>
      'Un ami qui arrête compte encore comme actif pendant un certain temps. Votre bonus peut donc baisser un certain temps après son arrêt.';

  @override
  String get inviteTreeQaDownRemoved =>
      'Votre bonus peut aussi baisser quand une invitation est supprimée, par exemple quand cet ami supprime son compte Fortiva.';

  @override
  String get inviteTreeQaFullQ =>
      'Que se passe-t-il quand mes places sont pleines ?';

  @override
  String get inviteTreeQaFullFurther =>
      'Quand ces premières paires sont pleines elles aussi, votre prochain ami va plus loin, dans la première paire de quelqu\'un qui est dans ces paires. Cette paire ajoute des données pour cette personne, et des montants plus petits pour vous et pour chaque personne entre vous.';

  @override
  String get inviteTreeQaFriendsQ =>
      'Les amis de mes amis ajoutent-ils des données pour moi ?';

  @override
  String get inviteTreeQaFriendsA =>
      'Certains, oui. La première paire de chaque personne qui est dans vos places ajoute des données pour cette personne, et un montant plus petit pour vous. Leurs autres paires ajoutent des données seulement pour eux. Plus loin, seules les premières paires ajoutent des données pour vous, et plus elles sont éloignées, moins elles ajoutent, jusqu\'à ne plus rien ajouter.';

  @override
  String get inviteTreeQaOthersQ =>
      'Qui sont les personnes dans mes places que je n\'ai pas invitées ?';

  @override
  String get inviteTreeQaOthersA =>
      'Ce sont des amis de quelqu\'un dont les places sont pleines, par exemple la personne qui vous a invité. Elles ont pris une place libre dans votre première paire, et vous ne pouvez ni les choisir ni les retirer. Elles ajoutent des données pour vous de la même façon que vos propres amis.';

  @override
  String get inviteTreeQaSumQ =>
      'Pourquoi mon bonus diffère-t-il des montants de l\'écran d\'invitation ?';

  @override
  String get inviteTreeQaSumA =>
      'Chaque ligne de « Grâce à vos places » montre ce que les personnes de cette ligne ajoutent maintenant. Votre bonus est leur total, dans la limite prévue.';

  @override
  String get inviteTreeQaSlotQ =>
      'Puis-je libérer une place ou choisir qui la prend ?';

  @override
  String get inviteTreeQaSlotA =>
      'Non. Un ami garde sa place même s\'il arrête d\'utiliser Fortiva. Sa place ne se libère que si son invitation est supprimée, par exemple quand il supprime son compte Fortiva. Les places libres se remplissent dans l\'ordre, et personne ne peut choisir qui les prend.';

  @override
  String get inviteTreeQaPrivacyQ =>
      'Mes amis peuvent-ils voir si j\'utilise Fortiva ?';

  @override
  String get inviteTreeQaPrivacyA =>
      'Si vous nous avez rejoints avec le code d\'un ami, la personne dans les places de laquelle vous êtes peut voir si vous êtes actif ou inactif pour l\'instant. Les autres voient seulement combien de personnes sont actives, pas lesquelles. L\'écran d\'invitation n\'affiche jamais le nom, le téléphone ni la consommation de qui que ce soit.';

  @override
  String get inviteTreeQaLimitQ => 'Y a-t-il une limite ?';

  @override
  String get inviteTreeQaLimitMore =>
      'Une fois que vos invitations ajoutent ce montant, d\'autres amis n\'ajoutent pas plus de données.';

  @override
  String get inviteTreeQaKeptQ => 'Que devient le bonus que j\'ai déjà ?';

  @override
  String get inviteTreeQaKeptMore =>
      'Quand le bonus de vos invitations précédentes est supérieur à ce que vos amis ajoutent maintenant, vous recevez ce bonus à la place. Les deux ne s\'additionnent pas.';

  @override
  String get inviteTreeQaKeptRemoved =>
      'Une invitation est supprimée quand cet ami supprime son compte Fortiva, ou quand Fortiva l\'annule pour usage abusif.';

  @override
  String get inviteTreeQaChangedQ =>
      'Qu\'est-ce qui a changé pour les invitations ?';

  @override
  String get inviteTreeQaChangedA =>
      'Avant, chaque ami qualifié ajoutait un montant fixe de données. Maintenant, les amis ajoutent des données tant qu\'ils sont actifs, grâce à vos places et à vos paires, et votre bonus peut baisser.';

  @override
  String get inviteTreeQaPremiumQ =>
      'Les invitations ajoutent-elles des jours de Premium ?';

  @override
  String get inviteTreeQaPremiumOwn =>
      'Peu importe la place que prend votre ami. Les personnes que vous n\'avez pas invitées n\'ajoutent pas de jours de Premium.';

  @override
  String get inviteTreeQaGetsQ => 'Mon ami reçoit-il quelque chose ?';

  @override
  String get inviteTreeQaGetsA =>
      'Pas pour avoir saisi votre code. Comme tout le monde, il a son propre code et ses places, et les amis qui le rejoignent avec son code ajoutent des données pour lui. Une fois qualifié, sa première paire peut aussi accueillir des personnes qu\'il n\'a pas invitées, et ces personnes ajoutent elles aussi des données pour lui.';

  @override
  String get inviteTreeQaGetsSee =>
      'S\'il est dans vos places, vous pouvez voir s\'il est actif ou inactif pour l\'instant. Vous ne voyez jamais son nom ni sa consommation.';

  @override
  String get inviteTreeKeptFloor =>
      'Votre bonus est pour l\'instant le montant conservé de vos invitations précédentes. Il augmente dès que vos amis ajoutent ensemble plus que ce montant.';

  @override
  String inviteTreeIntroTotalUpTo(String most, String total) {
    return 'Vos amis peuvent ajouter jusqu\'à $most par jour. Vos données gratuites et celles de vos amis peuvent atteindre ensemble $total par jour.';
  }

  @override
  String get inviteTreeIntroPairsOrder =>
      'Votre première paire ajoute le plus. Chaque paire suivante ajoute moins.';

  @override
  String get inviteTreeIntroInvitedYou => 'Vous a invité';

  @override
  String get inviteTreeIntroGuide => 'Guide étape par étape';

  @override
  String get inviteTreeQaCostQ =>
      'Mon ami perd-il des données à cause de moi ?';

  @override
  String get inviteTreeQaCostA =>
      'Non. Ce qu\'un ami ajoute pour vous n\'est pas pris sur ses propres données. Ses données quotidiennes ne changent pas à cause de vous.';

  @override
  String get inviteTreeQaStartQ =>
      'Quand les données d\'un ami commencent-elles à s\'ajouter ?';

  @override
  String get inviteTreeQaStartA =>
      'Dès que votre ami a une place et qu\'il est actif. Votre bonus est mis à jour au fil de la journée, il augmente donc peu après, le jour même. Tant que votre ami n\'est pas qualifié, il n\'ajoute rien.';

  @override
  String get inviteTreeQaPhoneQ =>
      'Que se passe-t-il si mon ami réinstalle Fortiva ou change de téléphone ?';

  @override
  String get inviteTreeQaPhoneA =>
      'Après une réinstallation sur le même téléphone, Fortiva reconnaît en général le téléphone, et rien ne change. Un nouveau téléphone est nouveau pour Fortiva. La place est toujours celle de l\'ancien téléphone, et elle compte comme inactive dès que l\'ancien téléphone n\'est plus utilisé.';

  @override
  String get premiumSourceInvite => 'Grâce à vos invitations';

  @override
  String quotaBonusIncluded(String amount) {
    return 'inclut $amount de bonus d\'invitation';
  }

  @override
  String get updateTitle => 'Mise à jour disponible';

  @override
  String get updateRequiredTitle => 'Mise à jour requise';

  @override
  String updateBody(String version) {
    return 'Fortiva $version est disponible. Mettez à jour pour les derniers correctifs.';
  }

  @override
  String get updateRequiredBody =>
      'Cette version n\'est plus prise en charge. Mettez à jour pour continuer à utiliser Fortiva.';

  @override
  String get updateNow => 'Mettre à jour';

  @override
  String get updateLater => 'Plus tard';

  @override
  String get updateFromPlay => 'Google Play';

  @override
  String get updateFromTelegram => 'Canal Telegram';

  @override
  String get updateConnect => 'Se connecter';

  @override
  String get updateConnectHint =>
      'Si Google Play ou Telegram ne s\'ouvre pas, touchez d\'abord Se connecter.';

  @override
  String get updateConnected =>
      'Vous êtes connecté. Téléchargez la mise à jour maintenant.';

  @override
  String get updateReconnect => 'Ça ne marche pas ? Se reconnecter';

  @override
  String get updateDisconnect => 'Se déconnecter';

  @override
  String get updateDisconnectHint =>
      'Touchez Se déconnecter pour télécharger la mise à jour avec votre connexion habituelle.';

  @override
  String get updateNotCarrying =>
      'Vous êtes connecté, mais rien ne passe. Essayez de vous reconnecter, ou touchez Se déconnecter pour utiliser votre connexion habituelle.';

  @override
  String get diagVerdictNoInternet =>
      'Votre téléphone n\'a pas de connexion Internet. Fortiva ne peut pas se connecter tant qu\'elle n\'est pas revenue.';

  @override
  String get diagVerdictCutOff =>
      'Votre réseau n\'accède pas à l\'Internet international pour le moment. Réessayez dans quelques minutes.';

  @override
  String get diagVerdictNeedsPermission =>
      'Fortiva n\'a pas l\'autorisation d\'exécuter un VPN, ou une autre application VPN est réglée sur le mode toujours actif.';

  @override
  String get diagVerdictServerUnreachable =>
      'Ce serveur est injoignable depuis votre réseau. Il est soit bloqué ici, soit hors service.';

  @override
  String get diagVerdictBlockedTls =>
      'La connexion à ce serveur est coupée pendant son établissement. C\'est à cela que ressemble le filtrage.';

  @override
  String get diagVerdictThrottled =>
      'Le serveur a répondu à chaque contrôle et pourtant rien n\'est passé par le tunnel. La connexion est ralentie.';

  @override
  String get diagCheckInternet => 'Vérifier votre connexion Internet';

  @override
  String diagTryServer(String server) {
    return 'Nouvelle recherche avec $server';
  }

  @override
  String get diagTryAnotherServer => 'Essayer un autre serveur';

  @override
  String get diagDetails => 'Détails';

  @override
  String get diagDetailsHide => 'Masquer les détails';

  @override
  String privateDnsWarning(String host) {
    return 'Le DNS privé est activé ($host), certains sites peuvent donc ne pas s\'ouvrir. Désactivez le DNS privé dans les réglages du téléphone.';
  }

  @override
  String get openNetworkSettings => 'Ouvrir les réglages réseau';

  @override
  String testPointStatus(String time, int open, int total) {
    return 'Point de test · dernier contrôle $time · $open sur $total accès ouverts';
  }

  @override
  String get messagesTooltip => 'Messages';

  @override
  String get inboxTitle => 'Messages';

  @override
  String get inboxEmpty => 'Aucun message pour le moment.';

  @override
  String get messageClose => 'Fermer';

  @override
  String get supportTitle => 'Assistance';

  @override
  String get supportTooltip => 'Discuter avec l\'assistance';

  @override
  String get supportAskAction => 'Demander à l\'assistance';

  @override
  String get supportContactSubtitle => 'Discutez avec nous dans l\'application';

  @override
  String get supportAutomaticNotice =>
      'Les réponses sont rédigées automatiquement et peuvent être fausses.';

  @override
  String get supportStaffNotice =>
      'Les réponses automatiques sont désactivées pour le moment. Vos messages vont à notre équipe.';

  @override
  String get supportInputHint => 'Écrivez votre question';

  @override
  String get supportInputHintTeam => 'Écrivez à notre équipe';

  @override
  String get supportSend => 'Envoyer';

  @override
  String supportQuotaLeft(int remaining, int limit) {
    return 'Questions restantes aujourd\'hui : $remaining sur $limit';
  }

  @override
  String supportWaitIn(String time) {
    return 'Vous pourrez reposer une question dans $time.';
  }

  @override
  String supportDurationHours(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String supportDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get supportNewConversation => 'Nouvelle conversation';

  @override
  String get supportSending => 'Envoi en cours';

  @override
  String get supportNotSent => 'Non envoyé. Touchez pour réessayer.';

  @override
  String get supportRateUp => 'Utile';

  @override
  String get supportRateDown => 'Pas utile';

  @override
  String get supportRatedDown =>
      'Merci. Notre équipe va examiner cette réponse.';

  @override
  String get supportTeamLabel => 'Équipe Fortiva';

  @override
  String get supportUnavailable =>
      'Le chat n\'est pas disponible pour le moment.';

  @override
  String get supportOpenTelegram => 'Écrivez-nous sur Telegram';

  @override
  String get supportGenericError =>
      'Un problème est survenu. Veuillez réessayer.';

  @override
  String supportCodeTooLong(int max) {
    return 'Votre message est trop long. Restez sous $max caractères.';
  }

  @override
  String get supportCodeEmpty => 'Votre message est vide.';

  @override
  String get supportCodeWaitReply =>
      'Veuillez attendre la réponse à votre dernière question.';

  @override
  String get supportCodeSlowDown =>
      'Vous envoyez des messages trop vite. Patientez un peu.';

  @override
  String get supportCodeQuotaDay =>
      'Vous avez utilisé toutes vos questions du jour.';

  @override
  String get supportCodePaused =>
      'Les réponses automatiques sont en pause pour le moment.';

  @override
  String get supportCodeBusy =>
      'Notre assistant est occupé. Réessayez dans quelques minutes.';

  @override
  String get supportCodeGreeting =>
      'Bonjour ! Comment puis-je vous aider avec Fortiva ?';

  @override
  String get supportCodeGibberish =>
      'Désolé, je n\'ai pas compris. Pouvez-vous réécrire votre question ?';

  @override
  String get supportCodeRedacted =>
      'Nous avons retiré les données personnelles et les liens de votre message.';

  @override
  String get supportCodeRedactedEmpty =>
      'Votre message ne contenait que des données personnelles ou des liens, il n\'a donc pas été envoyé. Décrivez le problème avec des mots.';

  @override
  String get supportCodeOffTopic =>
      'Je ne peux répondre qu\'aux questions sur l\'utilisation de Fortiva.';

  @override
  String get supportCodeAbuse =>
      'Restons respectueux. Je suis là pour vous aider avec Fortiva.';

  @override
  String get supportCodeAiUnavailable =>
      'L\'assistant n\'a pas pu répondre cette fois. Réessayez dans un moment.';

  @override
  String get supportCodeToStaff =>
      'Envoyé à notre équipe. Sa réponse s\'affichera ici.';

  @override
  String get supportCodeTicketOpened =>
      'Nous avons transmis votre question à notre équipe. Sa réponse s\'affichera ici.';

  @override
  String get supportCodeNotSent =>
      'Ce message n\'a pas pu être envoyé. Écrivez-le à nouveau si vous avez encore besoin d\'aide.';

  @override
  String get supportAssistantSubtitle => 'Assistant IA';

  @override
  String get supportThinkingReading => 'Je lis votre question';

  @override
  String get supportThinkingSearching => 'Je cherche la réponse';

  @override
  String get supportThinkingWriting => 'J\'écris la réponse';

  @override
  String get supportThinkingStill =>
      'J\'y travaille encore, merci de votre patience';

  @override
  String get supportSuggestConnect => 'Je n\'arrive pas à me connecter';

  @override
  String get supportSuggestData =>
      'Combien de données me reste-t-il aujourd\'hui ?';

  @override
  String get supportSuggestSlow => 'Ma connexion est lente';

  @override
  String get supportWithTeam =>
      'Cette conversation est maintenant entre les mains de notre équipe.';

  @override
  String get supportTryAgainSoon => 'Réessayez dans quelques minutes.';

  @override
  String supportDurationWholeHours(int hours) {
    return '$hours h';
  }

  @override
  String get supportUnreadReply => 'Nouvelle réponse';

  @override
  String get premiumTitle => 'Premium';

  @override
  String get premiumTileSubtitle =>
      'Données illimitées, sans limite quotidienne';

  @override
  String get premiumTileActive => 'Premium est actif';

  @override
  String get premiumGetUnlimited => 'Passer à l\'illimité';

  @override
  String get premiumHeadline => 'Passez à l\'illimité';

  @override
  String get premiumPitch =>
      'Premium supprime la limite quotidienne : utilisez autant de données que vous voulez jusqu\'à la fin de la période.';

  @override
  String get premiumActiveTitle => 'Premium est actif';

  @override
  String premiumActiveUntil(String date) {
    return 'Données illimitées jusqu\'au $date';
  }

  @override
  String get premiumActiveNoDate => 'Données illimitées';

  @override
  String get premiumRenews => 'Renouvelé automatiquement via Google Play';

  @override
  String get premiumSourceKey => 'Activé avec une clé';

  @override
  String get premiumSourceCrypto => 'Payé en crypto';

  @override
  String get premiumSourceStars => 'Payé en étoiles Telegram';

  @override
  String get premiumSourceGooglePlay => 'Payé via Google Play';

  @override
  String get premiumSourceManual => 'Un cadeau de l\'équipe Fortiva';

  @override
  String get premiumYourKey => 'Votre clé';

  @override
  String get premiumKeyHint =>
      'Gardez cette clé en lieu sûr. Saisissez-la sur un autre téléphone pour y transférer Premium.';

  @override
  String premiumKeyMoves(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '$days jour',
    );
    return 'Une clé peut passer sur un autre téléphone jusqu\'à $count fois en $_temp0.';
  }

  @override
  String get premiumKeyMovesNoNumber =>
      'Une clé ne peut passer sur un autre téléphone qu\'un nombre limité de fois.';

  @override
  String get premiumCopy => 'Copier';

  @override
  String get premiumCopied => 'Copié';

  @override
  String get premiumChoosePlan => 'Choisissez une offre';

  @override
  String premiumPlanDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours de données illimitées',
      one: '$days jour de données illimitées',
    );
    return '$_temp0';
  }

  @override
  String get premiumPlanNoDays => 'Données illimitées';

  @override
  String get premiumBuy => 'Acheter';

  @override
  String get premiumPlayUnavailable =>
      'Google Play n\'est pas disponible pour le moment. Réessayez plus tard.';

  @override
  String get premiumPlayPending =>
      'Votre paiement est en attente sur Google Play. Premium démarre dès qu\'il est validé.';

  @override
  String get premiumPlayConfirming => 'Confirmation de votre achat...';

  @override
  String get premiumPlayRetrying =>
      'Votre paiement est passé, mais nous n\'avons pas encore pu le confirmer. Nous réessayons, inutile de payer à nouveau.';

  @override
  String get premiumPlayRefused =>
      'Nous n\'avons pas pu confirmer cet achat. Si vous avez été débité, contactez le support.';

  @override
  String get premiumPlayNotAvailable =>
      'Premium n\'est pas disponible sur ce téléphone pour le moment. Si vous avez été débité, contactez le support.';

  @override
  String get premiumNotAvailable =>
      'Premium n\'est pas disponible sur ce téléphone pour le moment.';

  @override
  String get premiumPlayFailed => 'L\'achat n\'a pas abouti. Réessayez.';

  @override
  String get premiumNowOn =>
      'Premium est actif. Profitez de données illimitées.';

  @override
  String get premiumRestore => 'Restaurer les achats';

  @override
  String get premiumRestoreDone => 'Votre achat est restauré sur ce téléphone.';

  @override
  String get premiumRestoreNone => 'Google Play n\'a aucun achat à restaurer.';

  @override
  String get premiumRestoreFailed =>
      'Impossible de restaurer votre achat. Réessayez plus tard.';

  @override
  String premiumRenewsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Facturé tous les $count jours. Renouvelé automatiquement jusqu\'à résiliation.',
      one:
          'Facturé chaque jour. Renouvelé automatiquement jusqu\'à résiliation.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Facturé toutes les $count semaines. Renouvelé automatiquement jusqu\'à résiliation.',
      one:
          'Facturé chaque semaine. Renouvelé automatiquement jusqu\'à résiliation.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Facturé tous les $count mois. Renouvelé automatiquement jusqu\'à résiliation.',
      one:
          'Facturé chaque mois. Renouvelé automatiquement jusqu\'à résiliation.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Facturé tous les $count ans. Renouvelé automatiquement jusqu\'à résiliation.',
      one:
          'Facturé chaque année. Renouvelé automatiquement jusqu\'à résiliation.',
    );
    return '$_temp0';
  }

  @override
  String get premiumRenewsNoPeriod =>
      'Renouvelé automatiquement jusqu\'à résiliation.';

  @override
  String get premiumPlayCancelNote =>
      'Vous pouvez résilier à tout moment dans Google Play. Premium reste actif jusqu\'à la fin de la période payée.';

  @override
  String get premiumManageSubscription => 'Gérer ou résilier l\'abonnement';

  @override
  String get premiumCurrentPlan => 'Offre actuelle';

  @override
  String get premiumPlaySubscribed =>
      'Vous avez déjà un abonnement Google Play. Gérez-le ou résiliez-le dans Google Play.';

  @override
  String get premiumEnterCode => 'Saisir un code';

  @override
  String get premiumNeedsPlayVersion =>
      'Pour acheter via Google Play, il vous faut la version Google Play de Fortiva.';

  @override
  String get premiumOff => 'Premium n\'est pas en vente pour le moment.';

  @override
  String get premiumLoadFailed =>
      'Impossible de charger Premium. Vérifiez votre connexion et réessayez.';

  @override
  String get premiumRetry => 'Réessayer';

  @override
  String premiumPriceUsdt(String price) {
    return '$price USDT';
  }

  @override
  String premiumPriceStars(String stars) {
    return '$stars étoiles Telegram';
  }

  @override
  String get premiumPayCrypto => 'Payer en crypto';

  @override
  String get premiumTelegramTitle => 'Payer dans Telegram';

  @override
  String get premiumTelegramBody =>
      'Payez en étoiles Telegram dans notre bot. Vous recevez une clé, et Premium démarre tout de suite sur ce téléphone.';

  @override
  String get premiumTelegramButton => 'Acheter dans Telegram';

  @override
  String get premiumTelegramFailed =>
      'Impossible d\'ouvrir Telegram. Réessayez.';

  @override
  String get checkoutTitle => 'Payer en crypto';

  @override
  String get checkoutChooseNetwork =>
      'Choisissez le réseau depuis lequel vous allez envoyer';

  @override
  String get checkoutContinue => 'Continuer';

  @override
  String get checkoutSendExactly => 'Envoyez exactement ce montant';

  @override
  String get checkoutNetwork => 'Réseau';

  @override
  String get checkoutAddress => 'À cette adresse';

  @override
  String get checkoutMemo => 'Avec ce mémo';

  @override
  String get checkoutMemoWarning =>
      'Ajoutez bien ce mémo à votre transfert, sinon nous ne pourrons pas vous attribuer le paiement.';

  @override
  String get checkoutExactWarning =>
      'Envoyez le montant exact, sur ce réseau uniquement. Un autre montant ou un autre réseau risque de ne pas nous parvenir.';

  @override
  String checkoutTimeLeft(String time) {
    return 'Temps restant : $time';
  }

  @override
  String get checkoutWaiting =>
      'En attente de votre paiement. Cette page se met à jour d\'elle-même.';

  @override
  String get checkoutPaidTitle => 'Paiement reçu';

  @override
  String get checkoutPaidKeyOnly =>
      'Votre clé est prête. Saisissez-la sur le téléphone qui doit recevoir Premium.';

  @override
  String get checkoutDone => 'Terminé';

  @override
  String get checkoutExpired =>
      'Cette commande a expiré. Si vous avez déjà payé, contactez le support.';

  @override
  String get checkoutUnderpaid =>
      'Nous avons reçu moins que le montant total. Contactez le support en indiquant ce numéro de commande :';

  @override
  String get checkoutCanceled => 'Cette commande a été annulée.';

  @override
  String get checkoutStartAgain => 'Recommencer';

  @override
  String get checkoutUnavailable =>
      'Le paiement en crypto n\'est pas disponible pour le moment.';

  @override
  String get checkoutTooManyOpen =>
      'Vous avez trop de commandes impayées. Payez-en une ou attendez qu\'elles expirent.';

  @override
  String get checkoutUnknownPlan =>
      'Cette offre n\'est plus en vente. Revenez en arrière et choisissez-en une autre.';

  @override
  String get checkoutFailed =>
      'Impossible de démarrer le paiement. Vérifiez votre connexion et réessayez.';

  @override
  String get redeemTitle => 'Saisir un code';

  @override
  String get redeemSubtitle => 'Une clé Premium ou un code cadeau';

  @override
  String get redeemHint => 'Code';

  @override
  String get redeemApply => 'Appliquer';

  @override
  String get redeemCancel => 'Annuler';

  @override
  String get redeemInvalid =>
      'Cela ne ressemble pas à un code. Vérifiez-le et réessayez.';

  @override
  String get redeemUnknown =>
      'Nous ne connaissons pas ce code. Vérifiez-le et réessayez.';

  @override
  String get redeemExpired => 'Ce code a expiré.';

  @override
  String get redeemRevoked => 'Ce code n\'est plus valide.';

  @override
  String get redeemMovedTooOften =>
      'Cette clé a changé de téléphone trop souvent ces derniers temps. Réessayez plus tard.';

  @override
  String get redeemExhausted => 'Ce code a été épuisé.';

  @override
  String get redeemAlreadyUsed => 'Ce téléphone a déjà utilisé ce code.';

  @override
  String get redeemUnmetered =>
      'Ce téléphone a déjà des données illimitées, il n\'a pas besoin de ce code.';

  @override
  String get redeemRateLimited =>
      'Trop de tentatives. Patientez un peu et réessayez.';

  @override
  String get redeemUnavailable =>
      'Ce service n\'est pas disponible pour le moment. Réessayez plus tard.';

  @override
  String get redeemNetwork =>
      'Impossible de joindre le serveur. Vérifiez votre connexion et réessayez.';

  @override
  String get redeemFailed =>
      'Ce code n\'a pas fonctionné. Vérifiez-le et réessayez.';

  @override
  String get redeemMoved => 'Premium est passé sur ce téléphone.';

  @override
  String redeemPromo(String amount) {
    return 'Code accepté. $amount de données en plus ont été ajoutés.';
  }

  @override
  String get redeemPromoNoAmount =>
      'Code accepté. Des données en plus ont été ajoutées.';

  @override
  String get tvScanTitle => 'Ouvrir sur votre téléphone';

  @override
  String get tvScanBody =>
      'Pointez l\'appareil photo de votre téléphone vers ce code.';

  @override
  String get refresh => 'Actualiser';

  @override
  String get premiumNotNow => 'Pas maintenant';

  @override
  String get premiumLimitSheetTitle => 'Les données du jour sont épuisées';

  @override
  String get premiumLimitWait => 'Attendre la réinitialisation';

  @override
  String get premiumLimitInvite => 'Inviter des amis pour plus de données';

  @override
  String premiumLimitInviteNext(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'sur $days jours différents',
      one: 'pendant $days jour',
    );
    return 'Votre prochain ami ajoute $amount par jour dès qu\'il a utilisé Fortiva $_temp0. Cela ne s\'ajoute pas aux données d\'aujourd\'hui.';
  }

  @override
  String premiumLimitInviteNextNoDays(String amount) {
    return 'Votre prochain ami ajoute $amount par jour dès qu\'il a utilisé Fortiva pendant un certain temps. Cela ne s\'ajoute pas aux données d\'aujourd\'hui.';
  }

  @override
  String get premiumLimitInviteNoAmount =>
      'Les amis que vous invitez augmentent vos données quotidiennes dès qu\'ils commencent à utiliser Fortiva. Cela ne s\'ajoute pas aux données d\'aujourd\'hui.';

  @override
  String get premiumLimitInvitesFull =>
      'Vos invitations ajoutent déjà le maximum de données possible.';

  @override
  String get premiumLimitSeeInvites => 'Voir vos invitations';

  @override
  String get premiumLimitShareAgain => 'Partager avec un autre ami';

  @override
  String get premiumNoDailyLimit => 'Premium n\'a pas de limite quotidienne.';

  @override
  String get premiumCalmTitle =>
      'Envie de ne plus avoir de limite quotidienne ?';

  @override
  String get premiumCalmBody =>
      'Premium vous donne des données illimitées. Votre forfait gratuit reste tel quel.';

  @override
  String get premiumNextStepTitle => 'La prochaine étape : Premium';

  @override
  String get premiumNextStepBody =>
      'Vous avez déjà le maximum de données gratuites. Premium n\'a pas de limite quotidienne.';

  @override
  String get premiumLockedTag => 'Premium';

  @override
  String premiumLockedTitle(String place) {
    return 'Débloquez $place avec Premium';
  }

  @override
  String get premiumLockedBody =>
      'Ce lieu est réservé à Premium. Vos serveurs gratuits restent les mêmes.';

  @override
  String get premiumHeadlineLimit => 'Aucune limite quotidienne';

  @override
  String premiumHeadlineLocked(String place) {
    return 'Débloquez $place avec Premium';
  }

  @override
  String get premiumFreeStays =>
      'Le forfait gratuit continue de fonctionner sans Premium.';

  @override
  String premiumEndsOn(String date) {
    return 'Premium se termine le $date';
  }

  @override
  String get premiumRenewBody =>
      'Renouvelez pour garder les données illimitées. Le renouvellement s\'ajoute à votre date de fin actuelle.';

  @override
  String premiumEndedOn(String date) {
    return 'Premium a pris fin le $date. Votre forfait gratuit est de retour.';
  }

  @override
  String get premiumRenew => 'Renouveler';

  @override
  String get noticeChannelName => 'Messages de Fortiva';

  @override
  String get noticeChannelDescription =>
      'Actualités et messages de l\'équipe Fortiva';

  @override
  String get noticesSettingTitle => 'Notifications';

  @override
  String get noticesSettingOn =>
      'Activées. Les messages de l\'équipe Fortiva peuvent vous parvenir même quand l\'app est fermée.';

  @override
  String get noticesSettingOff =>
      'Désactivées. Activez-les pour recevoir les messages de l\'équipe Fortiva même quand l\'app est fermée.';

  @override
  String get noticesOffCard =>
      'Activez les notifications pour recevoir les messages de l\'équipe Fortiva même quand l\'app est fermée.';

  @override
  String get noticesTurnOn => 'Activer';

  @override
  String get backgroundCard =>
      'Votre téléphone peut retenir les messages de l\'équipe Fortiva quand l\'app est fermée. Autorisez Fortiva à fonctionner en arrière-plan pour les recevoir.';

  @override
  String get backgroundHint =>
      'Sur l\'écran suivant, choisissez Fortiva (s\'il n\'apparaît pas, affichez toutes les apps). Réglez ensuite l\'utilisation de la batterie sur Sans restriction, ou autorisez-le à démarrer et à fonctionner en arrière-plan.';

  @override
  String get backgroundAllow => 'Autoriser';

  @override
  String get backgroundNotNow => 'Pas maintenant';

  @override
  String get backgroundSettingTitle => 'Messages quand l\'app est fermée';

  @override
  String get backgroundSettingSubtitle =>
      'Autorisez Fortiva à fonctionner en arrière-plan pour recevoir les messages même quand l\'app est fermée.';

  @override
  String get backgroundCardData =>
      'L\'économiseur de données de votre téléphone peut bloquer les messages de l\'équipe Fortiva quand l\'app est fermée.';

  @override
  String get backgroundHintData =>
      'Sur l\'écran suivant, activez Données sans restriction.';

  @override
  String get apnGuideTitle => 'Une connexion plus stable avec cette SIM';

  @override
  String get apnGuideBody =>
      'Votre téléphone n\'utilise pas IPv6 sur cette SIM. L\'activer aide Fortiva à rester connecté.';

  @override
  String get apnGuideShowMe => 'Me montrer comment';

  @override
  String get apnGuideNotNow => 'Pas maintenant';

  @override
  String get apnGuideSheetTitle => 'Activer IPv6 pour cette SIM';

  @override
  String apnGuideStepOpen(String button) {
    return 'Appuyez sur « $button » (ou allez dans Paramètres > Connexions > Réseaux mobiles > Noms des points d\'accès).';
  }

  @override
  String apnGuideStepAccessPoint(String apn) {
    return 'Appuyez sur le point d\'accès utilisé ($apn).';
  }

  @override
  String get apnGuideStepAccessPointAny =>
      'Appuyez sur le point d\'accès utilisé.';

  @override
  String get apnGuideStepProtocol =>
      'Appuyez sur « Protocole APN » et choisissez « IPv4/IPv6 ».';

  @override
  String get apnGuideStepSave =>
      'Enregistrez (sur Samsung : le menu à trois points, puis « Enregistrer »).';

  @override
  String get apnGuideStepRestart =>
      'Désactivez les données mobiles, puis réactivez-les.';

  @override
  String get apnGuideUndo =>
      'Si les données mobiles ne fonctionnent plus, remettez le protocole APN sur IPv4.';

  @override
  String get apnGuideOpenSettings => 'Ouvrir les paramètres APN';

  @override
  String get homeStallSearching =>
      'La connexion ne fonctionne plus. Recherche d\'un autre chemin.';

  @override
  String get homeStalled => 'Connecté, mais aucune donnée ne passe';

  @override
  String get peerShareTitle => 'Aider vos amis à se connecter';

  @override
  String get peerShareSubtitle =>
      'Transmettez au téléphone de votre ami ce dont Fortiva a besoin';

  @override
  String get peerShareBody =>
      'Si Fortiva ne se connecte pas chez votre ami, son téléphone peut récupérer ce qu\'il lui faut sur le vôtre. Cela fonctionne sans Internet.';

  @override
  String peerShareSteps(String action) {
    return 'Sur son téléphone, dans Fortiva, ouvrez les Paramètres et touchez « $action ». Montrez-lui ensuite ces codes un par un, ou envoyez-lui le tout.';
  }

  @override
  String get peerShareLoading => 'Récupération de la copie la plus récente';

  @override
  String get peerShareNothing =>
      'Ce téléphone n\'a rien de récent à transmettre. Réessayez plus tard.';

  @override
  String peerShareCodeOf(int current, int total) {
    return 'Code $current sur $total';
  }

  @override
  String get peerSharePrevious => 'Précédent';

  @override
  String get peerShareNext => 'Suivant';

  @override
  String get peerShareCopy => 'Copier';

  @override
  String get peerShareSend => 'Envoyer';

  @override
  String get peerShareCopied => 'Copié. Collez-le dans un message à votre ami.';

  @override
  String get peerReceiveTitle => 'Demander de l\'aide à vos amis';

  @override
  String get peerReceiveSubtitle =>
      'Si vous ne pouvez pas vous connecter autrement';

  @override
  String peerReceiveBody(String action) {
    return 'Demandez à des amis chez qui Fortiva se connecte d\'ouvrir les Paramètres dans Fortiva et de toucher « $action ». Récupérez ensuite le tout depuis leur téléphone, par l\'un des moyens ci-dessous.';
  }

  @override
  String get peerReceivePhotograph => 'Photographier les codes de votre ami';

  @override
  String get peerReceivePhotographNext => 'Photographier le code suivant';

  @override
  String peerReceiveProgress(int have, int total) {
    return 'Codes lus : $have sur $total';
  }

  @override
  String get peerReceiveFile => 'Ouvrir le fichier envoyé par votre ami';

  @override
  String get peerReceivePaste => 'Coller ce que votre ami a envoyé';

  @override
  String get peerReceiveNoCode =>
      'Aucun code trouvé sur cette photo. Approchez le téléphone pour que tout le code soit visible.';

  @override
  String get peerReceiveRefused =>
      'Fortiva ne peut pas utiliser cela. Demandez à votre ami de le renvoyer.';

  @override
  String get peerReceiveNotNewer =>
      'Vous l\'avez déjà, ou quelque chose de plus récent. Réessayez de vous connecter, ou demandez à d\'autres amis.';

  @override
  String get peerReceiveTaken =>
      'C\'est fait. Touchez le bouton pour vous connecter.';

  @override
  String get peerReceiveUnavailable =>
      'Ce téléphone ne peut pas faire cela. Essayez autrement.';

  @override
  String get peerReceiveNothingToPaste =>
      'Rien n\'a encore été copié. Copiez ce que votre ami a envoyé, puis touchez ici à nouveau.';

  @override
  String get peerOfferBody =>
      'Toujours pas de connexion ? Si Fortiva fonctionne chez vos amis, ils peuvent vous aider depuis leur téléphone.';

  @override
  String get peerReceiveAgain =>
      'Vous avez déjà ce code. Demandez à votre ami de vous montrer le suivant.';

  @override
  String get peerReceivePasteNotOurs =>
      'Ce que vous avez copié ne vient pas de Fortiva. Copiez le message entier de votre ami, puis réessayez.';

  @override
  String peerReceiveNoPhoto(String action) {
    return 'L\'appareil photo n\'a pas renvoyé la photo. Prenez la photo avec l\'application Appareil photo, puis touchez « $action ».';
  }

  @override
  String get peerReceiveFileHint =>
      'Les fichiers reçus par messagerie doivent parfois d\'abord être enregistrés dans Téléchargements.';

  @override
  String get homeTryingBackup =>
      'Rien d\'autre ne s\'est connecté. Nous essayons maintenant un réseau de secours.';

  @override
  String get homeConnectedBackup => 'Connecté via un réseau de secours';

  @override
  String get backupNetwork => 'RÉSEAU DE SECOURS';

  @override
  String get backupNetworkTitle => 'Réseau de secours';

  @override
  String get backupNetworkCaption =>
      'Utilisé quand rien d\'autre ne se connecte. Il peut être plus lent que nos serveurs.';

  @override
  String get backupNetworkPlace => 'Emplacement choisi automatiquement';

  @override
  String get speedTestStart => 'Lancer le test';

  @override
  String get speedTestAgain => 'Refaire le test';

  @override
  String get speedTestRunning => 'Test en cours';

  @override
  String get speedTestIdle =>
      'Découvrez la vitesse de votre connexion en ce moment.';

  @override
  String get speedTestPhasePing => 'Mesure du temps de réponse';

  @override
  String get speedTestPhaseDownload => 'Mesure de la vitesse de téléchargement';

  @override
  String get speedTestPhaseUpload => 'Mesure de la vitesse d\'envoi';

  @override
  String get speedTestDone => 'Test terminé';

  @override
  String get speedTestFailed =>
      'Le test n\'a pas pu aboutir. Vérifiez votre connexion internet et réessayez.';

  @override
  String get speedTestUnit => 'Mbit/s';

  @override
  String get ipAddressLabel => 'Adresse IP';

  @override
  String get ipCopied => 'Adresse copiée';

  @override
  String get ipLocation => 'Emplacement';

  @override
  String get ipProvider => 'Fournisseur d\'accès';

  @override
  String get ipOrganization => 'Organisation';

  @override
  String get ipTimeZone => 'Fuseau horaire';

  @override
  String get ipCoordinates => 'Coordonnées';

  @override
  String get ipCheckFailed => 'Impossible de vérifier votre adresse';

  @override
  String get historyAverage => 'Moyenne';

  @override
  String get historyRecentDays => 'Derniers jours';

  @override
  String yesterdayAt(String time) {
    return 'Hier à $time';
  }

  @override
  String dateAt(String date, String time) {
    return '$date à $time';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String get stageOwn => 'Serveurs Fortiva';

  @override
  String get stageCommunity => 'Serveurs communautaires';

  @override
  String stageProgress(int n, int total) {
    return 'Étape $n sur $total';
  }

  @override
  String get stageTryingOwn => 'Essai des serveurs Fortiva';

  @override
  String get stageTryingCommunity => 'Essai des serveurs communautaires';

  @override
  String get stageOwnFailedTryingCommunity =>
      'Les serveurs Fortiva ne se sont pas connectés ici. Nous essayons maintenant les serveurs communautaires.';

  @override
  String stageLastWorked(String server) {
    return 'Dernier serveur qui a fonctionné : $server';
  }

  @override
  String stageTriedBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chemins essayés, bloqués ici',
      one: '$count chemin essayé, bloqué ici',
    );
    return '$_temp0';
  }

  @override
  String stageTriedFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chemins essayés, aucun connecté',
      one: '$count chemin essayé, sans connexion',
    );
    return '$_temp0';
  }

  @override
  String get stageNotConnected => 'Pas de connexion';

  @override
  String get stageConnected => 'Connecté ici';

  @override
  String get stageSkipped => 'Ignorée cette fois';

  @override
  String stageMoreToCheck(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Encore $count chemins à vérifier',
      one: 'Encore $count chemin à vérifier',
    );
    return '$_temp0';
  }

  @override
  String stageNextTry(String stage, String time) {
    return 'Prochain essai dans $time, en commençant par $stage';
  }

  @override
  String get searchSlowHint =>
      'Cela peut prendre une minute ou deux. Touchez le bouton pour arrêter la recherche.';

  @override
  String get searchStopped => 'Recherche arrêtée';

  @override
  String get homeConnectedCommunity => 'Connecté via un serveur communautaire';

  @override
  String get stageGettingServers => 'Récupération de vos serveurs';

  @override
  String stageNextTryStarting(String stage) {
    return 'Le prochain essai commence maintenant par $stage';
  }
}
