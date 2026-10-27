// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class SHi extends S {
  SHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'FortivaVPN';

  @override
  String get statusDisconnected => 'डिस्कनेक्ट';

  @override
  String get statusConnecting => 'कनेक्ट हो रहा है';

  @override
  String get statusConnected => 'कनेक्ट';

  @override
  String get statusDisconnecting => 'डिस्कनेक्ट हो रहा है';

  @override
  String get statusError => 'त्रुटि';

  @override
  String get statusVerifying => 'सत्यापन हो रहा है...';

  @override
  String get disconnect => 'डिस्कनेक्ट करें';

  @override
  String get connectBtn => 'कनेक्ट करें';

  @override
  String get disconnectBtn => 'डिस्कनेक्ट करें';

  @override
  String get pleaseWait => 'कृपया प्रतीक्षा करें';

  @override
  String get locationLabel => 'स्थान:';

  @override
  String get selectServer => 'सर्वर चुनें';

  @override
  String get serverLocation => 'सर्वर स्थान';

  @override
  String get searchServers => 'सर्वर खोजें';

  @override
  String get locationsTitle => 'स्थान';

  @override
  String get sortLatency => 'क्रम: विलंबता';

  @override
  String get sortAZ => 'क्रम: A-Z';

  @override
  String get sortedByLatency => 'विलंबता के अनुसार क्रमित';

  @override
  String get sortedAZ => 'A–Z क्रमित';

  @override
  String get pingAll => 'सभी पिंग करें';

  @override
  String get pinging => 'पिंग हो रहा है...';

  @override
  String get ping => 'पिंग';

  @override
  String get stop => 'रोकें';

  @override
  String get fastestServer => 'सबसे तेज़ सर्वर';

  @override
  String get timeout => 'टाइमआउट';

  @override
  String get tabCommunity => 'समुदाय';

  @override
  String get tabFree => 'मुफ़्त';

  @override
  String get tabPremium => 'प्रीमियम';

  @override
  String get noCommunityServers => 'कोई सामुदायिक सर्वर नहीं';

  @override
  String get communityLoadFailed => 'यह सूची लोड नहीं हो सकी';

  @override
  String get communityRetry => 'फिर से कोशिश करें';

  @override
  String get officialTabExplainer =>
      'Fortiva द्वारा संचालित और हमारे द्वारा ऑनलाइन रखे गए। ऐप के सभी उपयोगकर्ताओं के बीच साझा। यहीं से शुरू करें।';

  @override
  String get communityTabExplainer =>
      'अतिरिक्त कनेक्शन विकल्प। गति और उपलब्धता बदलती रहती है।';

  @override
  String get noFreeServers => 'कोई मुफ़्त सर्वर नहीं';

  @override
  String get noPremiumServers => 'कोई प्रीमियम सर्वर नहीं';

  @override
  String noResultsFor(String query) {
    return '\"$query\" के लिए कोई परिणाम नहीं';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get freeBadge => 'मुफ़्त';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get connection => 'कनेक्शन';

  @override
  String get dnsConfiguration => 'DNS कॉन्फ़िगरेशन';

  @override
  String get customDns => 'कस्टम DNS सर्वर';

  @override
  String get about => 'जानकारी';

  @override
  String get privacyPolicy => 'गोपनीयता नीति';

  @override
  String get contactUs => 'संपर्क करें';

  @override
  String get rateOnGooglePlay => 'Google Play पर Fortiva को रेटिंग दें';

  @override
  String get website => 'वेबसाइट';

  @override
  String get copyright => '© 2026 NimusAI';

  @override
  String get version => 'संस्करण';

  @override
  String get language => 'भाषा';

  @override
  String get languageSubtitle => 'ऐप प्रदर्शन भाषा';

  @override
  String get whatIsDns => 'DNS क्या है?';

  @override
  String get dnsExplanation =>
      'DNS (डोमेन नाम प्रणाली) इंटरनेट की फोनबुक है। यह वेबसाइट नामों को IP पतों में बदलता है।\n\nअपना DNS कस्टमाइज़ करने से:\n• कनेक्शन गति में सुधार हो सकता है ⚡\n• गोपनीयता बढ़ सकती है 🔒\n• सेंसरशिप ब्लॉक को बायपास कर सकता है 🌍';

  @override
  String get configuration => 'कॉन्फ़िगरेशन';

  @override
  String get primaryDns => 'प्राथमिक DNS';

  @override
  String get primaryDnsHint => 'डिफ़ॉल्ट: 1.1.1.1';

  @override
  String get secondaryDns => 'द्वितीयक DNS (वैकल्पिक)';

  @override
  String get secondaryDnsHint => 'डिफ़ॉल्ट: 8.8.8.8';

  @override
  String get saveConfiguration => 'कॉन्फ़िगरेशन सहेजें';

  @override
  String get dnsSaved => 'DNS कॉन्फ़िगरेशन सहेजा गया';

  @override
  String get invalidPrimaryDns => 'अमान्य प्राथमिक DNS IP पता';

  @override
  String get invalidSecondaryDns => 'अमान्य द्वितीयक DNS IP पता';

  @override
  String get statistics => 'आँकड़े';

  @override
  String get overview => 'अवलोकन';

  @override
  String get connectionsLabel => 'कनेक्शन';

  @override
  String get totalTime => 'कुल समय';

  @override
  String get dataUsage => 'डेटा उपयोग';

  @override
  String get uploaded => 'अपलोड किया गया';

  @override
  String get downloaded => 'डाउनलोड किया गया';

  @override
  String get total => 'कुल';

  @override
  String lastUpdated(String date) {
    return 'अंतिम अपडेट: $date';
  }

  @override
  String today(String time) {
    return 'आज $time बजे';
  }

  @override
  String get yesterday => 'कल';

  @override
  String daysAgo(int count) {
    return '$count दिन पहले';
  }

  @override
  String get noDataYet => 'अभी तक कोई डेटा नहीं';

  @override
  String get connectToStart => 'ट्रैकिंग शुरू करने के लिए VPN से कनेक्ट करें';

  @override
  String get errorConnectionFailed => 'कनेक्शन विफल';

  @override
  String get errorServerNotWorking => 'सर्वर काम नहीं कर रहा — दूसरा आज़माएँ';

  @override
  String get errorServerNotForwarding => 'सर्वर ट्रैफ़िक फ़ॉरवर्ड नहीं कर रहा';

  @override
  String get errorUnexpected => 'अप्रत्याशित त्रुटि';

  @override
  String get errorDisconnectionFailed => 'डिस्कनेक्शन विफल';

  @override
  String get errorFailedToRegister => 'डिवाइस पंजीकरण विफल';

  @override
  String get ipInformation => 'IP जानकारी';

  @override
  String get connectionAnalytics => 'कनेक्शन एनालिटिक्स';

  @override
  String get recentSessions => 'हाल के सत्र';

  @override
  String get speedTest => 'स्पीड टेस्ट';

  @override
  String get startTest => 'टेस्ट शुरू करें';

  @override
  String get download => 'डाउनलोड';

  @override
  String get upload => 'अपलोड';

  @override
  String get testingViaVpn => 'VPN के माध्यम से परीक्षण';

  @override
  String get testingDirect => 'सीधा कनेक्शन परीक्षण';

  @override
  String get splitTunneling => 'स्प्लिट टनलिंग';

  @override
  String get splitTunnelingDescription =>
      'VPN टनल को बायपास करने वाली ऐप श्रेणियां चुनें।';

  @override
  String get enableSplitTunneling => 'स्प्लिट टनलिंग सक्षम करें';

  @override
  String get splitTunnelActive => 'चयनित ऐप्स VPN को बायपास करते हैं';

  @override
  String get splitTunnelInactive => 'सारा ट्रैफिक VPN से होकर जाता है';

  @override
  String get bypassVpnFor => 'VPN बायपास करें';

  @override
  String get tools => 'उपकरण';

  @override
  String get settingsGeneral => 'सामान्य';

  @override
  String get shareDiagnosticsTitle => 'कनेक्शन डायग्नोस्टिक्स साझा करें';

  @override
  String get shareDiagnosticsBody =>
      'कनेक्शन रिपोर्ट, आपका ऑपरेटर और देश, फ़ोन का मॉडल और Android संस्करण, VPN से खोली गई साइटों के नाम और उनकी रोज़ की गिनती, और यह कि आपने हमारे संदेश, प्रीमियम ऑफ़र और आमंत्रण कार्ड देखे या उन पर टैप किया, भेजे जाते हैं। आप जो पेज खोलते हैं या जो कुछ भेजते हैं, उसे हम कभी नहीं देखते।';

  @override
  String get security => 'सुरक्षा';

  @override
  String get privacyDashboard => 'गोपनीयता डैशबोर्ड';

  @override
  String get privacyDashboardSubtitle => 'IP जानकारी और लीक सुरक्षा';

  @override
  String get connectionAnalyticsSubtitle => 'सत्र इतिहास और चार्ट';

  @override
  String get speedTestSubtitle => 'अपनी कनेक्शन स्पीड टेस्ट करें';

  @override
  String get splitTunnelingSubtitle => 'ऐप VPN रूटिंग चुनें';

  @override
  String get splashTagline => 'निजी पहुँच, आप जहाँ भी हों';

  @override
  String get openSourceLicence => 'ओपन सोर्स लाइसेंस';

  @override
  String get sourceOfferTitle => 'ओपन सोर्स लाइसेंस';

  @override
  String get sourceOfferBody =>
      'Fortiva VPN एक स्वतंत्र सॉफ़्टवेयर है, जो GNU General Public License v3 के तहत आता है। यह Xray-core और अन्य ओपन सोर्स प्रोजेक्ट पर आधारित है।\n\nआपने जो संस्करण इंस्टॉल किया है, उसका पूरा सोर्स कोड पाने का आपको अधिकार है। इसे माँगने के लिए अपने ऐप का संस्करण लिखकर admin@fortivavpn.com पर ईमेल करें। यह पेशकश इस संस्करण के मिलने की तारीख से तीन साल तक मान्य है।';

  @override
  String get close => 'बंद करें';

  @override
  String get account => 'खाता';

  @override
  String get deleteAccount => 'खाता हटाएँ';

  @override
  String get deleteAccountSubtitle =>
      'इस डिवाइस और आपके डेटा को हमेशा के लिए हटाएँ';

  @override
  String get deleteAccountConfirmTitle => 'क्या आप अपना खाता हटाना चाहते हैं?';

  @override
  String get deleteAccountConfirmBody =>
      'इससे आपके डिवाइस का पंजीकरण, जुड़ा हुआ कोई भी Google खाता, आपके लिए बनाए गए निजी सर्वर, और सहायता चैट में आपके संदेश हट जाएँगे। इस फ़ोन का कनेक्शन इतिहास भी मिट जाएगा।\n\nयह वापस नहीं किया जा सकता। आप कभी भी ऐप दोबारा खोलकर नए सिरे से शुरू कर सकते हैं।';

  @override
  String deleteAccountConfirmRetention(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days दिनों',
      one: '$days दिन',
    );
    return 'आपका खाता रिकॉर्ड तुरंत हटा दिया जाता है। बैकअप में मौजूद प्रतियाँ और गुमनाम सर्वर लॉग $_temp0 के भीतर मिटा दिए जाते हैं।';
  }

  @override
  String get deleteAccountConfirmRetentionNoDays =>
      'आपका खाता रिकॉर्ड तुरंत हटा दिया जाता है। बैकअप में मौजूद प्रतियाँ और गुमनाम सर्वर लॉग बाद में, हमारी निजता नीति में बताई गई अवधि के भीतर, मिटा दिए जाते हैं।';

  @override
  String get deleteAccountCancel => 'मेरा खाता रहने दें';

  @override
  String get deleteAccountConfirm => 'हटाएँ';

  @override
  String get deleteAccountInProgress => 'आपका खाता हटाया जा रहा है';

  @override
  String get deleteAccountDone => 'आपका खाता हटा दिया गया है।';

  @override
  String get deleteAccountFailed =>
      'खाता नहीं हटाया जा सका। अपना कनेक्शन जाँचें और दोबारा कोशिश करें।';

  @override
  String get homeTapToConnect => 'कनेक्ट करने के लिए टैप करें';

  @override
  String get homeChecking => 'कनेक्शन जाँचा जा रहा है';

  @override
  String get homePreparing => 'आपका सर्वर तैयार किया जा रहा है';

  @override
  String get homeDisconnecting => 'डिस्कनेक्ट हो रहा है';

  @override
  String get homeFindingPath => 'रास्ता खोजा जा रहा है';

  @override
  String get diagCheckingInternet => 'आपका इंटरनेट जाँचा जा रहा है';

  @override
  String get diagInternationalCut =>
      'इस नेटवर्क पर अंतरराष्ट्रीय इंटरनेट बंद है';

  @override
  String diagPathRow(String city, int n) {
    return '$city, रास्ता $n';
  }

  @override
  String get diagOpen => 'खुला';

  @override
  String get diagBlocked => 'ब्लॉक';

  @override
  String get diagSkipped => 'आज छोड़ा गया';

  @override
  String diagConnectingThrough(String city) {
    return '$city के ज़रिए कनेक्ट हो रहा है';
  }

  @override
  String get diagVerifying => 'ट्रैफ़िक जाँचा जा रहा है';

  @override
  String get diagNoInternet => 'आपके फ़ोन पर अभी इंटरनेट नहीं है।';

  @override
  String get diagCutOff =>
      'आपका नेटवर्क अभी अंतरराष्ट्रीय इंटरनेट तक नहीं पहुँच पा रहा है। फिर से कोशिश करने के लिए टैप करें।';

  @override
  String get diagNothingOpen =>
      'अभी हर रास्ता ब्लॉक है। फिर से कोशिश करने के लिए टैप करें।';

  @override
  String get homeTryingAgain =>
      'अभी हर रास्ता ब्लॉक है। थोड़ी देर में फिर से कोशिश करेंगे।';

  @override
  String get homeCutOffTryingAgain =>
      'आपका नेटवर्क अभी अंतरराष्ट्रीय इंटरनेट तक नहीं पहुँच पा रहा है। थोड़ी देर में फिर से कोशिश करेंगे।';

  @override
  String get homeOfflineTryingAgain =>
      'आपके फ़ोन पर अभी इंटरनेट नहीं है। थोड़ी देर में फिर से कोशिश करेंगे।';

  @override
  String get diagPathFailed =>
      'रास्ता खुला था, लेकिन टनल नहीं बन पाई। फिर से कोशिश करने के लिए टैप करें।';

  @override
  String get openVpnSettings => 'VPN सेटिंग खोलें';

  @override
  String get yourServer => 'आपका सर्वर';

  @override
  String get yourServerCaption => 'सिर्फ़ आपका। इससे कोई और कनेक्ट नहीं होता।';

  @override
  String get ourServer => 'हमारा सर्वर';

  @override
  String get ourServerCaption =>
      'Fortiva द्वारा संचालित और सबके साथ साझा। आपका अपना सर्वर तैयार होने तक इस्तेमाल होता है।';

  @override
  String get communityServer => 'समुदाय सर्वर';

  @override
  String get communityServerCaption =>
      'एक अतिरिक्त कनेक्शन विकल्प। यह किसी भी समय काम करना बंद कर सकता है।';

  @override
  String communityServerNumber(String n) {
    return 'समुदाय सर्वर $n';
  }

  @override
  String get myServersTitle => 'आपके सर्वर';

  @override
  String get myServersExplainer =>
      'हर Fortiva डिवाइस को हर लोकेशन में अपना सर्वर मिलता है, जिसके क्रेडेंशियल सिर्फ़ इसी इंस्टॉल के होते हैं। किसी खाते की ज़रूरत नहीं।';

  @override
  String get myServersInUse => 'उपयोग में';

  @override
  String get myServersEmpty => 'अभी तक कोई सर्वर असाइन नहीं हुआ';

  @override
  String get myServersRetry => 'फिर से कोशिश करें';

  @override
  String get myServersBlockedTitle => 'आपने आज का डेटा इस्तेमाल कर लिया है';

  @override
  String get myServersBlockedWait =>
      'आपका कोटा अपने आप रीसेट हो जाता है। थोड़ी देर बाद देखें।';

  @override
  String myServersMoved(String place) {
    return 'अब $place का उपयोग हो रहा है';
  }

  @override
  String get copyLink => 'लिंक कॉपी करें';

  @override
  String get linkCopied => 'लिंक कॉपी हो गया';

  @override
  String quotaUsedToday(String used, String limit) {
    return 'आज $limit में से $used इस्तेमाल हुआ';
  }

  @override
  String get quotaUsedUp => 'आज का डेटा खत्म';

  @override
  String get quotaUnlimited => 'असीमित डेटा';

  @override
  String get quotaDaily => 'दैनिक डेटा';

  @override
  String get quotaLimitReached => 'दैनिक सीमा पूरी';

  @override
  String quotaLeftOf(String left, String limit) {
    return '$limit में से $left बाकी';
  }

  @override
  String get quotaResetsShortly => 'जल्द ही रीसेट होगा';

  @override
  String quotaResetsInHours(int hours) {
    return '$hours घंटे में रीसेट होगा';
  }

  @override
  String quotaResetsInMinutes(int minutes) {
    return '$minutes मिनट में रीसेट होगा';
  }

  @override
  String get myServersSubtitle => 'इस डिवाइस के लिए दिए गए सर्वर';

  @override
  String get sharedServersTitle => 'साझा सर्वर';

  @override
  String get sharedServersSubtitle => 'सार्वजनिक लोकेशन, बैकअप के तौर पर';

  @override
  String get tabOfficial => 'हमारे सर्वर';

  @override
  String get noOfficialServers => 'अभी कोई Fortiva सर्वर नहीं';

  @override
  String get inviteTitle => 'दोस्तों को आमंत्रित करें';

  @override
  String get inviteSubtitle => 'हर दिन ज़्यादा डेटा पाएँ';

  @override
  String get inviteYourCode => 'आपका आमंत्रण कोड';

  @override
  String get inviteShareAction => 'आमंत्रण साझा करें';

  @override
  String get inviteCopyAction => 'कोड कॉपी करें';

  @override
  String get inviteCodeCopied => 'कोड कॉपी हो गया';

  @override
  String inviteShareMessage(String code, String url) {
    return 'एक मुफ़्त VPN जो मेरे लिए अच्छा चलता है: Fortiva। साइन-अप की ज़रूरत नहीं।\nइस लिंक से इंस्टॉल करें:\n$url\nमेरा इनवाइट कोड: $code';
  }

  @override
  String get inviteHowItWorks => 'यह कैसे काम करता है';

  @override
  String inviteHowItWorksBody(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days अलग-अलग दिनों में',
      one: '$days दिन',
    );
    return 'अपना कोड साझा करें। जब कोई ऐप इंस्टॉल करके कोड डाले और $_temp0 VPN इस्तेमाल करे, तो आपके रोज़ के डेटा में $amount जुड़ जाएगा और हमेशा बना रहेगा।';
  }

  @override
  String inviteHowItWorksBodyNoAmount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days अलग-अलग दिनों में',
      one: '$days दिन',
    );
    return 'अपना कोड साझा करें। जब कोई ऐप इंस्टॉल करके कोड डाले और $_temp0 VPN इस्तेमाल करे, तो आपका रोज़ का डेटा बढ़ जाएगा और यह बढ़त हमेशा बनी रहेगी।';
  }

  @override
  String inviteHowItWorksBodyNoDays(String amount) {
    return 'अपना कोड साझा करें। जब कोई ऐप इंस्टॉल करके कोड डाले और कुछ समय VPN इस्तेमाल करे, तो आपके रोज़ के डेटा में $amount जुड़ जाएगा और हमेशा बना रहेगा।';
  }

  @override
  String get inviteHowItWorksBodyNoAmountNoDays =>
      'अपना कोड साझा करें। जब कोई ऐप इंस्टॉल करके कोड डाले और कुछ समय VPN इस्तेमाल करे, तो आपका रोज़ का डेटा बढ़ जाएगा और यह बढ़त हमेशा बनी रहेगी।';

  @override
  String inviteHowItWorksCap(String max) {
    return 'आमंत्रणों से आप हर दिन ज़्यादा से ज़्यादा $max पा सकते हैं।';
  }

  @override
  String get inviteStatInvited => 'आमंत्रित';

  @override
  String get inviteStatEarning => 'योग्य';

  @override
  String get inviteStatBonus => 'बोनस डेटा';

  @override
  String inviteBonusPerDay(String amount) {
    return 'हर दिन +$amount';
  }

  @override
  String get inviteNoBonusYet => 'अभी कोई बोनस नहीं';

  @override
  String invitePendingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count आमंत्रण अभी योग्य नहीं हुए',
      one: '1 आमंत्रण अभी योग्य नहीं हुआ',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String inviteJoinedWith(String code) {
    return 'आप कोड $code से जुड़े';
  }

  @override
  String get inviteLoadFailed => 'आपका आमंत्रण कोड लोड नहीं हो सका';

  @override
  String get inviteRetry => 'फिर कोशिश करें';

  @override
  String get inviteHaveCodeTitle => 'क्या आपके पास आमंत्रण कोड है?';

  @override
  String inviteHaveCodeSubtitle(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'इसे पहले $hours घंटों में डालें',
      one: 'इसे पहले घंटे में डालें',
    );
    return '$_temp0';
  }

  @override
  String get inviteHaveCodeSubtitleNoHours =>
      'इसे इंस्टॉल करने के कुछ ही देर बाद डालें';

  @override
  String get inviteEnterCodeHint => 'आमंत्रण कोड';

  @override
  String get inviteApplyAction => 'लागू करें';

  @override
  String get inviteNotNowAction => 'अभी नहीं';

  @override
  String inviteClaimAccepted(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days अलग-अलग दिनों में',
      one: '$days दिन',
    );
    return 'आमंत्रण स्वीकार हुआ। जब आप $_temp0 VPN इस्तेमाल करेंगे, तब आपके दोस्त को बोनस डेटा मिलेगा।';
  }

  @override
  String get inviteClaimAcceptedNoDays =>
      'आमंत्रण स्वीकार हुआ। जब आप कुछ समय VPN इस्तेमाल करेंगे, तब आपके दोस्त को बोनस डेटा मिलेगा।';

  @override
  String get inviteClaimAlready =>
      'इस डिवाइस ने पहले ही एक आमंत्रण कोड इस्तेमाल किया है';

  @override
  String get inviteClaimRejected =>
      'यह कोड काम नहीं आया। इसे जाँचें और फिर कोशिश करें';

  @override
  String get inviteClaimNetwork => 'सर्वर तक नहीं पहुँच सके। फिर कोशिश करें';

  @override
  String get inviteCardTitle =>
      'क्या Fortiva आपके लिए अच्छा चल रहा है? इसे अपने दोस्तों को भेजें';

  @override
  String get inviteCardBody =>
      'अपने दोस्त को इंस्टॉल का लिंक भेजें, ताकि वे भी मुफ़्त में कनेक्ट कर सकें।';

  @override
  String inviteCardReward(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'जब आपका दोस्त Fortiva इस्तेमाल करना शुरू करेगा, तो आपको $days दिन का प्रीमियम मिलेगा।',
      one:
          'जब आपका दोस्त Fortiva इस्तेमाल करना शुरू करेगा, तो आपको $days दिन का प्रीमियम मिलेगा।',
    );
    return '$_temp0';
  }

  @override
  String get inviteCardRewardNoAmount =>
      'जब आपका दोस्त Fortiva इस्तेमाल करना शुरू करेगा, तो आपको उपहार में प्रीमियम मिलेगा।';

  @override
  String get inviteSendTelegram => 'Telegram';

  @override
  String get inviteSendWhatsApp => 'WhatsApp';

  @override
  String get inviteCopyLink => 'लिंक कॉपी करें';

  @override
  String get inviteOtherApps => 'दूसरे ऐप';

  @override
  String get inviteLinkCopied => 'आमंत्रण संदेश कॉपी हो गया';

  @override
  String get invitePasteBody =>
      'अपने दोस्त के संदेश से कोड कॉपी करें और यहाँ पेस्ट करें।';

  @override
  String get invitePasteAction => 'पेस्ट करें';

  @override
  String get inviteErrorTooLate =>
      'इस फ़ोन पर आमंत्रण कोड डालने का समय निकल चुका है।';

  @override
  String get inviteErrorUnknown =>
      'हमें यह कोड नहीं मिला। इसे अपने दोस्त के संदेश से फिर से कॉपी करें।';

  @override
  String get inviteErrorOwnCode =>
      'यह आपका अपना कोड है। अपने दोस्त का कोड डालें।';

  @override
  String get inviteErrorMutual =>
      'आप और आपका दोस्त एक-दूसरे को आमंत्रित नहीं कर सकते।';

  @override
  String inviteHowItWorksPremium(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Fortiva इस्तेमाल करना शुरू करने वाला हर दोस्त आपको $days दिन का प्रीमियम भी दिलाता है।',
      one:
          'Fortiva इस्तेमाल करना शुरू करने वाला हर दोस्त आपको $days दिन का प्रीमियम भी दिलाता है।',
    );
    return '$_temp0';
  }

  @override
  String inviteHowItWorksPremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other:
          'आमंत्रणों से आप ज़्यादा से ज़्यादा $max दिन का प्रीमियम पा सकते हैं।',
      one:
          'आमंत्रणों से आप ज़्यादा से ज़्यादा $max दिन का प्रीमियम पा सकते हैं।',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeLive =>
      'आपका बोनस तब तक चलता है जब तक आपके दोस्त Fortiva इस्तेमाल करते रहें। अगर कोई दोस्त रुक जाए, तो बोनस घट जाता है।';

  @override
  String inviteTreeNext(String amount) {
    return 'आपका अगला दोस्त Fortiva इस्तेमाल करना शुरू करेगा, तो हर दिन $amount जोड़ेगा।';
  }

  @override
  String inviteTreeKept(String amount) {
    return 'पहले बुलाए गए दोस्तों की वजह से आपका बोनस कभी भी हर दिन $amount से कम नहीं होता।';
  }

  @override
  String get inviteTreeSlotsTitle => 'आपके स्लॉट';

  @override
  String get inviteTreeSlotActive => 'सक्रिय';

  @override
  String get inviteTreeSlotNotActive => 'अभी सक्रिय नहीं';

  @override
  String get inviteTreeSlotEmpty => 'खाली स्लॉट';

  @override
  String inviteTreePaysNow(String amount) {
    return '+$amount हर दिन, अभी';
  }

  @override
  String inviteTreePairFull(String amount) {
    return '+$amount हर दिन, जब दोनों सक्रिय हों';
  }

  @override
  String get inviteTreeNothingYet => 'अभी कुछ नहीं';

  @override
  String get inviteTreeFriendsTitle => 'आपके स्लॉट के ज़रिए';

  @override
  String get inviteTreeRowFriends => 'आपके स्लॉट में';

  @override
  String get inviteTreeRowFriendsSlots => 'उनके स्लॉट में';

  @override
  String inviteTreeRowSteps(int steps) {
    String _temp0 = intl.Intl.pluralLogic(
      steps,
      locale: localeName,
      other: '$steps कदम दूर',
    );
    return '$_temp0';
  }

  @override
  String inviteTreeRowPeople(int people, int active) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people लोग',
      one: '$people व्यक्ति',
    );
    return '$_temp0, $active सक्रिय';
  }

  @override
  String inviteTreeHowSlots(int slots) {
    String _temp0 = intl.Intl.pluralLogic(
      slots,
      locale: localeName,
      other:
          'अपना कोड साझा करें। योग्य होने वाले पहले $slots दोस्त आपके स्लॉट जोड़ियों में भरते हैं।',
    );
    return '$_temp0';
  }

  @override
  String get inviteTreeHowSlotsNoNumber =>
      'अपना कोड साझा करें। योग्य होने वाले पहले दोस्त आपके स्लॉट जोड़ियों में भरते हैं।';

  @override
  String get inviteTreeHowPair =>
      'जब किसी जोड़ी के दोनों लोग सक्रिय हों, तो वह ज़्यादा देती है।';

  @override
  String get inviteTreeHowFriendsSlots =>
      'जब आपके स्लॉट भर जाते हैं, तो उसके बाद योग्य होने वाले आपके दोस्त अगले खाली स्लॉट लेते हैं, जो आपसे और दूर होते हैं। वे भी आपके लिए डेटा जोड़ते हैं, जितने दूर, उतना कम।';

  @override
  String get inviteTreeHowOthers =>
      'आपकी पहली जोड़ी में ऐसे लोग भी आ सकते हैं जिन्हें आपने आमंत्रित नहीं किया। वे भी उसी तरह आपके लिए डेटा जोड़ते हैं।';

  @override
  String inviteTreeHowActive(int days, int window) {
    return 'कोई दोस्त तब तक सक्रिय गिना जाता है जब तक उसने पिछले $window दिनों में कम से कम $days दिन Fortiva इस्तेमाल किया हो।';
  }

  @override
  String get inviteTreeHowActiveNoNumber =>
      'कोई दोस्त तब तक सक्रिय गिना जाता है जब तक वह Fortiva इस्तेमाल करता रहे।';

  @override
  String inviteTreeHowCap(String max) {
    return 'आमंत्रण हर दिन ज़्यादा से ज़्यादा $max जोड़ सकते हैं।';
  }

  @override
  String get inviteTreeHowCapNoAmount =>
      'आमंत्रणों से मिलने वाले डेटा की एक रोज़ की सीमा है।';

  @override
  String get premiumSourceInvite => 'आपके आमंत्रणों से';

  @override
  String quotaBonusIncluded(String amount) {
    return '$amount आमंत्रण बोनस शामिल है';
  }

  @override
  String get updateTitle => 'अपडेट उपलब्ध है';

  @override
  String get updateRequiredTitle => 'अपडेट ज़रूरी है';

  @override
  String updateBody(String version) {
    return 'Fortiva $version आ गया है। नए सुधारों के लिए अपडेट करें।';
  }

  @override
  String get updateRequiredBody =>
      'यह वर्शन अब समर्थित नहीं है। Fortiva इस्तेमाल करते रहने के लिए अपडेट करें।';

  @override
  String get updateNow => 'अपडेट करें';

  @override
  String get updateLater => 'बाद में';

  @override
  String get updateFromPlay => 'Google Play';

  @override
  String get updateFromTelegram => 'Telegram चैनल';

  @override
  String get updateConnect => 'कनेक्ट करें';

  @override
  String get updateConnectHint =>
      'अगर Google Play या Telegram नहीं खुलता, तो पहले कनेक्ट करें पर टैप करें।';

  @override
  String get updateConnected => 'आप कनेक्ट हैं। अब अपडेट डाउनलोड करें।';

  @override
  String get updateReconnect => 'काम नहीं कर रहा? फिर से कनेक्ट करें';

  @override
  String get updateDisconnect => 'डिस्कनेक्ट करें';

  @override
  String get updateDisconnectHint =>
      'अपने सामान्य इंटरनेट से अपडेट डाउनलोड करने के लिए डिस्कनेक्ट करें पर टैप करें।';

  @override
  String get updateNotCarrying =>
      'आप कनेक्ट हैं, लेकिन कुछ भी नहीं खुल रहा। फिर से कनेक्ट करके देखें, या अपना सामान्य इंटरनेट इस्तेमाल करने के लिए डिस्कनेक्ट करें पर टैप करें।';

  @override
  String get diagVerdictNoInternet =>
      'आपके फ़ोन पर इंटरनेट कनेक्शन नहीं है। जब तक वह वापस नहीं आता, Fortiva कनेक्ट नहीं हो सकता।';

  @override
  String get diagVerdictCutOff =>
      'आपका नेटवर्क अभी अंतरराष्ट्रीय इंटरनेट तक नहीं पहुँच पा रहा है। कुछ मिनट बाद फिर से कोशिश करें।';

  @override
  String get diagVerdictNeedsPermission =>
      'Fortiva को VPN चलाने की अनुमति नहीं है, या कोई दूसरा VPN ऐप हमेशा चालू पर सेट है।';

  @override
  String get diagVerdictServerUnreachable =>
      'आपके नेटवर्क से इस सर्वर तक नहीं पहुँचा जा सकता। या तो यह यहाँ ब्लॉक है या बंद है।';

  @override
  String get diagVerdictBlockedTls =>
      'इस सर्वर से कनेक्शन बनते-बनते काट दिया जाता है। फ़िल्टरिंग ऐसी ही दिखती है।';

  @override
  String get diagVerdictThrottled =>
      'सर्वर ने हर जाँच का जवाब दिया, फिर भी टनल से कुछ नहीं गुज़रा। कनेक्शन को धीमा किया जा रहा है।';

  @override
  String get diagCheckInternet => 'अपना इंटरनेट जाँचें';

  @override
  String diagTryServer(String server) {
    return '$server पर नई खोज';
  }

  @override
  String get diagTryAnotherServer => 'दूसरा सर्वर आज़माएँ';

  @override
  String get diagDetails => 'विवरण';

  @override
  String get diagDetailsHide => 'विवरण छिपाएँ';

  @override
  String privateDnsWarning(String host) {
    return 'प्राइवेट DNS चालू है ($host), इसलिए कुछ साइटें नहीं खुल सकतीं। अपने फ़ोन की सेटिंग में प्राइवेट DNS बंद करें।';
  }

  @override
  String get openNetworkSettings => 'नेटवर्क सेटिंग खोलें';

  @override
  String testPointStatus(String time, int open, int total) {
    return 'टेस्ट पॉइंट · आखिरी जांच $time · $total में से $open रास्ते खुले';
  }

  @override
  String get messagesTooltip => 'संदेश';

  @override
  String get inboxTitle => 'संदेश';

  @override
  String get inboxEmpty => 'अभी कोई संदेश नहीं है।';

  @override
  String get messageClose => 'बंद करें';

  @override
  String get supportTitle => 'सहायता';

  @override
  String get supportTooltip => 'सहायता से चैट करें';

  @override
  String get supportAskAction => 'सहायता से पूछें';

  @override
  String get supportContactSubtitle => 'ऐप में ही हमसे बात करें';

  @override
  String get supportAutomaticNotice =>
      'जवाब अपने-आप लिखे जाते हैं और गलत हो सकते हैं।';

  @override
  String get supportStaffNotice =>
      'अपने-आप मिलने वाले जवाब अभी बंद हैं। आपके संदेश हमारी टीम को जाते हैं।';

  @override
  String get supportInputHint => 'अपना सवाल लिखें';

  @override
  String get supportInputHintTeam => 'हमारी टीम को लिखें';

  @override
  String get supportSend => 'भेजें';

  @override
  String supportQuotaLeft(int remaining, int limit) {
    return 'आज $limit में से $remaining सवाल बाकी हैं';
  }

  @override
  String supportWaitIn(String time) {
    return 'आप $time बाद फिर से पूछ सकते हैं।';
  }

  @override
  String supportDurationHours(int hours, int minutes) {
    return '$hours घंटे $minutes मिनट';
  }

  @override
  String supportDurationMinutes(int minutes) {
    return '$minutes मिनट';
  }

  @override
  String get supportNewConversation => 'नई बातचीत';

  @override
  String get supportSending => 'भेजा जा रहा है';

  @override
  String get supportNotSent =>
      'नहीं भेजा गया। फिर से कोशिश करने के लिए टैप करें।';

  @override
  String get supportRateUp => 'मददगार';

  @override
  String get supportRateDown => 'मददगार नहीं';

  @override
  String get supportRatedDown => 'धन्यवाद। हमारी टीम इस जवाब को देखेगी।';

  @override
  String get supportTeamLabel => 'Fortiva टीम';

  @override
  String get supportUnavailable => 'चैट अभी उपलब्ध नहीं है।';

  @override
  String get supportOpenTelegram => 'हमें Telegram पर संदेश भेजें';

  @override
  String get supportGenericError => 'कुछ गलत हो गया। कृपया फिर से कोशिश करें।';

  @override
  String supportCodeTooLong(int max) {
    return 'आपका संदेश बहुत लंबा है। इसे $max अक्षरों से कम रखें।';
  }

  @override
  String get supportCodeEmpty => 'आपका संदेश खाली है।';

  @override
  String get supportCodeWaitReply =>
      'कृपया अपने पिछले सवाल के जवाब का इंतज़ार करें।';

  @override
  String get supportCodeSlowDown =>
      'आप बहुत तेज़ी से संदेश भेज रहे हैं। थोड़ा रुकें।';

  @override
  String get supportCodeQuotaDay => 'आपने आज के सभी सवाल पूछ लिए हैं।';

  @override
  String get supportCodePaused => 'अपने-आप मिलने वाले जवाब अभी रुके हुए हैं।';

  @override
  String get supportCodeBusy =>
      'हमारा सहायक अभी व्यस्त है। कुछ मिनट बाद फिर से कोशिश करें।';

  @override
  String get supportCodeGreeting =>
      'नमस्ते! Fortiva में मैं आपकी क्या मदद कर सकता हूँ?';

  @override
  String get supportCodeGibberish =>
      'माफ़ कीजिए, मैं समझ नहीं पाया। कृपया अपना सवाल फिर से लिखें।';

  @override
  String get supportCodeRedacted =>
      'हमने आपके संदेश से निजी जानकारी और लिंक हटा दिए हैं।';

  @override
  String get supportCodeRedactedEmpty =>
      'आपके संदेश में सिर्फ़ निजी जानकारी या लिंक थे, इसलिए उसे नहीं भेजा गया। कृपया समस्या शब्दों में बताएँ।';

  @override
  String get supportCodeOffTopic =>
      'मैं सिर्फ़ Fortiva के इस्तेमाल से जुड़े सवालों में मदद कर सकता हूँ।';

  @override
  String get supportCodeAbuse =>
      'आइए सम्मान से बात करें। मैं Fortiva में आपकी मदद के लिए यहाँ हूँ।';

  @override
  String get supportCodeAiUnavailable =>
      'सहायक इस बार जवाब नहीं दे सका। थोड़ी देर बाद फिर से कोशिश करें।';

  @override
  String get supportCodeToStaff =>
      'हमारी टीम को भेज दिया गया। उनका जवाब यहीं दिखेगा।';

  @override
  String get supportCodeTicketOpened =>
      'हमने आपका सवाल अपनी टीम को दे दिया है। उनका जवाब यहीं दिखेगा।';

  @override
  String get supportCodeNotSent =>
      'यह संदेश नहीं भेजा जा सका। अगर आपको अब भी मदद चाहिए, तो इसे फिर से लिखें।';

  @override
  String get supportAssistantSubtitle => 'एआई सहायक';

  @override
  String get supportThinkingReading => 'आपका सवाल पढ़ रहा हूँ';

  @override
  String get supportThinkingSearching => 'जवाब ढूँढ रहा हूँ';

  @override
  String get supportThinkingWriting => 'जवाब लिख रहा हूँ';

  @override
  String get supportThinkingStill =>
      'अभी भी इस पर काम कर रहा हूँ, इंतज़ार के लिए धन्यवाद';

  @override
  String get supportSuggestConnect => 'मैं कनेक्ट नहीं हो पा रहा';

  @override
  String get supportSuggestData => 'आज मेरे पास कितना डेटा है?';

  @override
  String get supportSuggestSlow => 'मेरा कनेक्शन धीमा है';

  @override
  String get supportWithTeam => 'यह बातचीत अब हमारी टीम के पास है।';

  @override
  String get supportTryAgainSoon => 'कुछ मिनट बाद फिर से कोशिश करें।';

  @override
  String supportDurationWholeHours(int hours) {
    return '$hours घंटे';
  }

  @override
  String get supportUnreadReply => 'नया जवाब आया है';

  @override
  String get premiumTitle => 'प्रीमियम';

  @override
  String get premiumTileSubtitle => 'असीमित डेटा, कोई दैनिक सीमा नहीं';

  @override
  String get premiumTileActive => 'प्रीमियम चालू है';

  @override
  String get premiumGetUnlimited => 'असीमित पाएँ';

  @override
  String get premiumHeadline => 'असीमित डेटा पाएँ';

  @override
  String get premiumPitch =>
      'प्रीमियम दैनिक सीमा हटा देता है, इसलिए जब तक यह चालू है, आप जितना चाहें डेटा इस्तेमाल कर सकते हैं।';

  @override
  String get premiumActiveTitle => 'प्रीमियम चालू है';

  @override
  String premiumActiveUntil(String date) {
    return '$date तक असीमित डेटा';
  }

  @override
  String get premiumActiveNoDate => 'असीमित डेटा';

  @override
  String get premiumRenews => 'Google Play से अपने आप रिन्यू होता है';

  @override
  String get premiumSourceKey => 'कुंजी से चालू किया गया';

  @override
  String get premiumSourceCrypto => 'क्रिप्टो से भुगतान किया गया';

  @override
  String get premiumSourceStars => 'Telegram Stars से भुगतान किया गया';

  @override
  String get premiumSourceGooglePlay => 'Google Play से भुगतान किया गया';

  @override
  String get premiumSourceManual => 'Fortiva टीम की ओर से उपहार';

  @override
  String get premiumYourKey => 'आपकी कुंजी';

  @override
  String get premiumKeyHint =>
      'इस कुंजी को संभालकर रखें। प्रीमियम को किसी दूसरे फ़ोन पर ले जाने के लिए इसे वहाँ डालें।';

  @override
  String premiumKeyMoves(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days दिनों',
      one: '$days दिन',
    );
    return 'कुंजी $_temp0 में ज़्यादा से ज़्यादा $count बार दूसरे फ़ोन पर जा सकती है।';
  }

  @override
  String get premiumKeyMovesNoNumber =>
      'कुंजी सीमित बार ही दूसरे फ़ोन पर जा सकती है।';

  @override
  String get premiumCopy => 'कॉपी करें';

  @override
  String get premiumCopied => 'कॉपी हो गया';

  @override
  String get premiumChoosePlan => 'प्लान चुनें';

  @override
  String premiumPlanDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days दिनों का असीमित डेटा',
      one: '$days दिन का असीमित डेटा',
    );
    return '$_temp0';
  }

  @override
  String get premiumPlanNoDays => 'असीमित डेटा';

  @override
  String get premiumBuy => 'खरीदें';

  @override
  String get premiumPlayUnavailable =>
      'Google Play अभी उपलब्ध नहीं है। बाद में फिर कोशिश करें।';

  @override
  String get premiumPlayPending =>
      'आपका भुगतान Google Play में लंबित है। पूरा होते ही प्रीमियम शुरू हो जाएगा।';

  @override
  String get premiumPlayConfirming => 'आपकी खरीद की पुष्टि हो रही है...';

  @override
  String get premiumPlayRetrying =>
      'भुगतान हो गया, लेकिन हम अभी इसकी पुष्टि नहीं कर पाए। हम कोशिश करते रहेंगे, दोबारा भुगतान करने की ज़रूरत नहीं है।';

  @override
  String get premiumPlayRefused =>
      'हम इस खरीद की पुष्टि नहीं कर पाए। अगर आपसे पैसे कटे हैं, तो सपोर्ट से संपर्क करें।';

  @override
  String get premiumPlayNotAvailable =>
      'प्रीमियम इस फ़ोन पर अभी उपलब्ध नहीं है। अगर आपसे पैसे कटे हैं, तो सपोर्ट से संपर्क करें।';

  @override
  String get premiumNotAvailable => 'प्रीमियम इस फ़ोन पर अभी उपलब्ध नहीं है।';

  @override
  String get premiumPlayFailed => 'खरीद पूरी नहीं हुई। फिर कोशिश करें।';

  @override
  String get premiumNowOn => 'प्रीमियम चालू हो गया। असीमित डेटा का आनंद लें।';

  @override
  String get premiumRestore => 'खरीदारी बहाल करें';

  @override
  String get premiumRestoreDone => 'आपकी खरीद इस फ़ोन पर बहाल हो गई।';

  @override
  String get premiumRestoreNone =>
      'इस Google खाते में बहाल करने के लिए कोई खरीद नहीं है।';

  @override
  String get premiumRestoreFailed =>
      'खरीद बहाल नहीं हो सकी। बाद में फिर कोशिश करें।';

  @override
  String premiumRenewsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'हर $count दिन में बिल किया जाता है। रद्द करने तक अपने आप रिन्यू होता है।',
      one: 'हर दिन बिल किया जाता है। रद्द करने तक अपने आप रिन्यू होता है।',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'हर $count हफ़्ते में बिल किया जाता है। रद्द करने तक अपने आप रिन्यू होता है।',
      one: 'हर हफ़्ते बिल किया जाता है। रद्द करने तक अपने आप रिन्यू होता है।',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'हर $count महीने में बिल किया जाता है। रद्द करने तक अपने आप रिन्यू होता है।',
      one: 'हर महीने बिल किया जाता है। रद्द करने तक अपने आप रिन्यू होता है।',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'हर $count साल में बिल किया जाता है। रद्द करने तक अपने आप रिन्यू होता है।',
      one: 'हर साल बिल किया जाता है। रद्द करने तक अपने आप रिन्यू होता है।',
    );
    return '$_temp0';
  }

  @override
  String get premiumRenewsNoPeriod => 'रद्द करने तक अपने आप रिन्यू होता है।';

  @override
  String get premiumPlayCancelNote =>
      'आप Google Play में कभी भी रद्द कर सकते हैं। प्रीमियम आपके भुगतान किए गए समय के अंत तक चालू रहता है।';

  @override
  String get premiumManageSubscription =>
      'सब्सक्रिप्शन मैनेज करें या रद्द करें';

  @override
  String get premiumCurrentPlan => 'मौजूदा प्लान';

  @override
  String get premiumPlaySubscribed =>
      'आपके पास पहले से Google Play सब्सक्रिप्शन है। उसे Google Play में मैनेज या रद्द करें।';

  @override
  String get premiumEnterCode => 'कोड डालें';

  @override
  String get premiumNeedsPlayVersion =>
      'Google Play से खरीदने के लिए आपको Fortiva का Google Play संस्करण चाहिए।';

  @override
  String get premiumOff => 'प्रीमियम अभी बिक्री पर नहीं है।';

  @override
  String get premiumLoadFailed =>
      'प्रीमियम लोड नहीं हो सका। अपना कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get premiumRetry => 'फिर से कोशिश करें';

  @override
  String premiumPriceUsdt(String price) {
    return '$price USDT';
  }

  @override
  String premiumPriceStars(String stars) {
    return '$stars Telegram Stars';
  }

  @override
  String get premiumPayCrypto => 'क्रिप्टो से भुगतान करें';

  @override
  String get premiumTelegramTitle => 'Telegram में भुगतान करें';

  @override
  String get premiumTelegramBody =>
      'हमारे बॉट में Telegram Stars से भुगतान करें। आपको कुंजी मिलेगी और प्रीमियम इस फ़ोन पर तुरंत शुरू हो जाएगा।';

  @override
  String get premiumTelegramButton => 'Telegram में खरीदें';

  @override
  String get premiumTelegramFailed => 'Telegram नहीं खुल सका। फिर कोशिश करें।';

  @override
  String get checkoutTitle => 'क्रिप्टो से भुगतान';

  @override
  String get checkoutChooseNetwork => 'वह नेटवर्क चुनें जिससे आप भेजेंगे';

  @override
  String get checkoutContinue => 'जारी रखें';

  @override
  String get checkoutSendExactly => 'ठीक यही राशि भेजें';

  @override
  String get checkoutNetwork => 'नेटवर्क';

  @override
  String get checkoutAddress => 'इस पते पर';

  @override
  String get checkoutMemo => 'इस मेमो के साथ';

  @override
  String get checkoutMemoWarning =>
      'यह मेमो अपने ट्रांसफ़र में ज़रूर डालें, वरना हम भुगतान को आपसे नहीं जोड़ पाएँगे।';

  @override
  String get checkoutExactWarning =>
      'ठीक यही राशि और केवल इसी नेटवर्क पर भेजें। अलग राशि या अलग नेटवर्क हम तक शायद न पहुँचे।';

  @override
  String checkoutTimeLeft(String time) {
    return 'बचा समय: $time';
  }

  @override
  String get checkoutWaiting =>
      'आपके भुगतान का इंतज़ार है। यह पेज अपने आप अपडेट होता है।';

  @override
  String get checkoutPaidTitle => 'भुगतान मिल गया';

  @override
  String get checkoutPaidKeyOnly =>
      'आपकी कुंजी तैयार है। इसे उस फ़ोन पर डालें जिसे प्रीमियम मिलना चाहिए।';

  @override
  String get checkoutDone => 'हो गया';

  @override
  String get checkoutExpired =>
      'इस ऑर्डर का समय खत्म हो गया। अगर आप भुगतान कर चुके हैं, तो सपोर्ट से संपर्क करें।';

  @override
  String get checkoutUnderpaid =>
      'हमें पूरी राशि से कम मिला। सपोर्ट से संपर्क करें और यह ऑर्डर नंबर बताएँ:';

  @override
  String get checkoutCanceled => 'यह ऑर्डर रद्द कर दिया गया।';

  @override
  String get checkoutStartAgain => 'फिर से शुरू करें';

  @override
  String get checkoutUnavailable => 'क्रिप्टो भुगतान अभी उपलब्ध नहीं है।';

  @override
  String get checkoutTooManyOpen =>
      'आपके बहुत सारे ऑर्डर बिना भुगतान के हैं। उनमें से किसी का भुगतान करें या उनके खत्म होने तक रुकें।';

  @override
  String get checkoutUnknownPlan =>
      'यह प्लान अब बिक्री पर नहीं है। वापस जाकर कोई दूसरा प्लान चुनें।';

  @override
  String get checkoutFailed =>
      'भुगतान शुरू नहीं हो सका। अपना कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get redeemTitle => 'कोड डालें';

  @override
  String get redeemSubtitle => 'प्रीमियम कुंजी या गिफ़्ट कोड';

  @override
  String get redeemHint => 'कोड';

  @override
  String get redeemApply => 'लागू करें';

  @override
  String get redeemCancel => 'रद्द करें';

  @override
  String get redeemInvalid =>
      'यह कोड जैसा नहीं लगता। इसे जाँचें और फिर कोशिश करें।';

  @override
  String get redeemUnknown =>
      'हम इस कोड को नहीं पहचानते। इसे जाँचें और फिर कोशिश करें।';

  @override
  String get redeemExpired => 'इस कोड की अवधि खत्म हो गई है।';

  @override
  String get redeemRevoked => 'यह कोड अब मान्य नहीं है।';

  @override
  String get redeemMovedTooOften =>
      'यह कुंजी हाल में बहुत बार फ़ोन बदल चुकी है। बाद में फिर कोशिश करें।';

  @override
  String get redeemExhausted => 'यह कोड पूरा इस्तेमाल हो चुका है।';

  @override
  String get redeemAlreadyUsed => 'यह फ़ोन पहले ही यह कोड इस्तेमाल कर चुका है।';

  @override
  String get redeemUnmetered =>
      'इस फ़ोन पर पहले से असीमित डेटा है, इसे इस कोड की ज़रूरत नहीं।';

  @override
  String get redeemRateLimited =>
      'बहुत ज़्यादा कोशिशें। थोड़ा रुककर फिर कोशिश करें।';

  @override
  String get redeemUnavailable =>
      'यह अभी उपलब्ध नहीं है। बाद में फिर कोशिश करें।';

  @override
  String get redeemNetwork =>
      'सर्वर तक नहीं पहुँच सके। अपना कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get redeemFailed =>
      'यह कोड काम नहीं आया। इसे जाँचें और फिर कोशिश करें।';

  @override
  String get redeemMoved => 'प्रीमियम इस फ़ोन पर आ गया।';

  @override
  String redeemPromo(String amount) {
    return 'कोड स्वीकार हुआ। $amount अतिरिक्त डेटा जोड़ा गया।';
  }

  @override
  String get redeemPromoNoAmount => 'कोड स्वीकार हुआ। अतिरिक्त डेटा जोड़ा गया।';

  @override
  String get tvScanTitle => 'अपने फ़ोन पर खोलें';

  @override
  String get tvScanBody => 'अपने फ़ोन का कैमरा इस कोड की ओर करें।';

  @override
  String get refresh => 'रीफ़्रेश करें';

  @override
  String get premiumNotNow => 'अभी नहीं';

  @override
  String get premiumLimitSheetTitle => 'आज का डेटा खत्म हो गया';

  @override
  String get premiumLimitWait => 'रीसेट होने का इंतज़ार करें';

  @override
  String get premiumLimitInvite =>
      'ज़्यादा डेटा के लिए दोस्तों को आमंत्रित करें';

  @override
  String get premiumNoDailyLimit => 'प्रीमियम में कोई दैनिक सीमा नहीं है।';

  @override
  String get premiumCalmTitle => 'दैनिक सीमा से छुटकारा चाहिए?';

  @override
  String get premiumCalmBody =>
      'प्रीमियम आपको असीमित डेटा देता है। आपका मुफ़्त प्लान जैसा है वैसा ही रहेगा।';

  @override
  String get premiumNextStepTitle => 'अगला कदम प्रीमियम है';

  @override
  String get premiumNextStepBody =>
      'आपके पास पहले से सबसे ज़्यादा मुफ़्त डेटा है। प्रीमियम में कोई दैनिक सीमा नहीं है।';

  @override
  String get premiumLockedTag => 'प्रीमियम';

  @override
  String premiumLockedTitle(String place) {
    return 'प्रीमियम के साथ $place अनलॉक करें';
  }

  @override
  String get premiumLockedBody =>
      'यह जगह प्रीमियम के लिए है। आपके मुफ़्त सर्वर वैसे ही रहेंगे।';

  @override
  String get premiumHeadlineLimit => 'कोई दैनिक सीमा नहीं';

  @override
  String premiumHeadlineLocked(String place) {
    return 'प्रीमियम के साथ $place अनलॉक करें';
  }

  @override
  String get premiumFreeStays =>
      'प्रीमियम के बिना भी मुफ़्त प्लान चलता रहता है।';

  @override
  String premiumEndsOn(String date) {
    return 'प्रीमियम $date को खत्म होगा';
  }

  @override
  String get premiumRenewBody =>
      'असीमित डेटा बनाए रखने के लिए रिन्यू करें। रिन्यू करने पर समय आपकी मौजूदा समाप्ति तिथि में जुड़ जाता है।';

  @override
  String premiumEndedOn(String date) {
    return 'प्रीमियम $date को खत्म हो गया। आपका मुफ़्त प्लान वापस आ गया है।';
  }

  @override
  String get premiumRenew => 'रिन्यू करें';

  @override
  String get noticeChannelName => 'Fortiva के संदेश';

  @override
  String get noticeChannelDescription => 'Fortiva टीम की ख़बरें और संदेश';

  @override
  String get noticesSettingTitle => 'सूचनाएँ';

  @override
  String get noticesSettingOn =>
      'चालू। ऐप बंद होने पर भी Fortiva टीम के संदेश आप तक पहुँच सकते हैं।';

  @override
  String get noticesSettingOff =>
      'बंद। ऐप बंद होने पर भी Fortiva टीम के संदेश पाने के लिए इन्हें चालू करें।';

  @override
  String get noticesOffCard =>
      'ऐप बंद होने पर भी Fortiva टीम के संदेश पाने के लिए सूचनाएँ चालू करें।';

  @override
  String get noticesTurnOn => 'चालू करें';

  @override
  String get backgroundCard =>
      'ऐप बंद होने पर आपका फ़ोन Fortiva टीम के संदेश रोक सकता है। उन्हें पाने के लिए Fortiva को बैकग्राउंड में चलने दें।';

  @override
  String get backgroundHint =>
      'अगली स्क्रीन पर Fortiva चुनें (अगर सूची में न हो, तो सभी ऐप दिखाएँ)। फिर बैटरी उपयोग को अप्रतिबंधित पर सेट करें, या उसे अपने आप शुरू होने और बैकग्राउंड में चलने की अनुमति दें।';

  @override
  String get backgroundAllow => 'अनुमति दें';

  @override
  String get backgroundNotNow => 'अभी नहीं';

  @override
  String get backgroundSettingTitle => 'ऐप बंद होने पर संदेश';

  @override
  String get backgroundSettingSubtitle =>
      'Fortiva को बैकग्राउंड में चलने दें, ताकि ऐप बंद होने पर भी संदेश आप तक पहुँचें।';

  @override
  String get backgroundCardData =>
      'ऐप बंद होने पर आपके फ़ोन का डेटा सेवर Fortiva टीम के संदेश रोक सकता है।';

  @override
  String get backgroundHintData =>
      'अगली स्क्रीन पर अप्रतिबंधित डेटा चालू करें।';

  @override
  String get apnGuideTitle => 'इस सिम पर ज़्यादा स्थिर कनेक्शन';

  @override
  String get apnGuideBody =>
      'आपका फ़ोन इस सिम पर IPv6 का इस्तेमाल नहीं कर रहा है। इसे चालू करने से Fortiva को जुड़े रहने में मदद मिलती है।';

  @override
  String get apnGuideShowMe => 'मुझे तरीका दिखाएँ';

  @override
  String get apnGuideNotNow => 'अभी नहीं';

  @override
  String get apnGuideSheetTitle => 'इस सिम के लिए IPv6 चालू करें';

  @override
  String apnGuideStepOpen(String button) {
    return '\"$button\" पर टैप करें (या सेटिंग > कनेक्शन > मोबाइल नेटवर्क > एक्सेस पॉइंट नाम पर जाएँ)।';
  }

  @override
  String apnGuideStepAccessPoint(String apn) {
    return 'इस्तेमाल हो रहे एक्सेस पॉइंट ($apn) पर टैप करें।';
  }

  @override
  String get apnGuideStepAccessPointAny =>
      'इस्तेमाल हो रहे एक्सेस पॉइंट पर टैप करें।';

  @override
  String get apnGuideStepProtocol =>
      '\"APN प्रोटोकॉल\" पर टैप करें और \"IPv4/IPv6\" चुनें।';

  @override
  String get apnGuideStepSave =>
      'सेव करें (Samsung पर: तीन बिंदु वाला मेनू, फिर \"सेव करें\")।';

  @override
  String get apnGuideStepRestart => 'मोबाइल डेटा बंद करके फिर से चालू करें।';

  @override
  String get apnGuideUndo =>
      'अगर मोबाइल डेटा काम करना बंद कर दे, तो APN प्रोटोकॉल को वापस IPv4 पर कर दें।';

  @override
  String get apnGuideOpenSettings => 'APN सेटिंग खोलें';

  @override
  String get homeStallSearching =>
      'कनेक्शन ने काम करना बंद कर दिया। दूसरा रास्ता खोजा जा रहा है।';

  @override
  String get homeStalled => 'कनेक्ट है, पर कोई डेटा नहीं आ रहा';

  @override
  String get peerShareTitle => 'दोस्त को कनेक्ट करने में मदद करें';

  @override
  String get peerShareSubtitle =>
      'अपने दोस्त के फ़ोन तक वह सब पहुँचाएँ जिसकी उनके Fortiva को ज़रूरत है';

  @override
  String get peerShareBody =>
      'अगर किसी दोस्त का Fortiva कनेक्ट नहीं हो पा रहा, तो उनका फ़ोन आपके फ़ोन से वह ले सकता है जो उसे चाहिए। यह बिना इंटरनेट के भी काम करता है।';

  @override
  String peerShareSteps(String action) {
    return 'उनके फ़ोन पर Fortiva में सेटिंग्स खोलें और \"$action\" पर टैप करें। फिर उन्हें ये कोड बारी-बारी से दिखाएँ, या यह उन्हें भेज दें।';
  }

  @override
  String get peerShareLoading => 'सबसे नई कॉपी ली जा रही है';

  @override
  String get peerShareNothing =>
      'इस फ़ोन के पास अभी देने के लिए कुछ नया नहीं है। थोड़ी देर बाद फिर से कोशिश करें।';

  @override
  String peerShareCodeOf(int current, int total) {
    return '$total में से कोड $current';
  }

  @override
  String get peerSharePrevious => 'पिछला';

  @override
  String get peerShareNext => 'अगला';

  @override
  String get peerShareCopy => 'कॉपी करें';

  @override
  String get peerShareSend => 'भेजें';

  @override
  String get peerShareCopied =>
      'कॉपी हो गया। इसे अपने दोस्त को किसी मैसेज में पेस्ट करें।';

  @override
  String get peerReceiveTitle => 'दोस्त से मदद लें';

  @override
  String get peerReceiveSubtitle => 'जब किसी और तरह से कनेक्ट न हो';

  @override
  String peerReceiveBody(String action) {
    return 'किसी ऐसे दोस्त से कहें जिसका Fortiva कनेक्ट होता हो कि वे Fortiva में सेटिंग्स खोलकर \"$action\" पर टैप करें। फिर इनमें से किसी भी तरीके से उनके फ़ोन से ले लें।';
  }

  @override
  String get peerReceivePhotograph => 'दोस्त के कोड की फ़ोटो लें';

  @override
  String get peerReceivePhotographNext => 'अगले कोड की फ़ोटो लें';

  @override
  String peerReceiveProgress(int have, int total) {
    return '$total में से $have कोड पढ़े गए';
  }

  @override
  String get peerReceiveFile => 'दोस्त की भेजी फ़ाइल खोलें';

  @override
  String get peerReceivePaste => 'दोस्त का भेजा हुआ पेस्ट करें';

  @override
  String get peerReceiveNoCode =>
      'इस फ़ोटो में कोई कोड नहीं मिला। फ़ोन को पास लाएँ और ध्यान रखें कि पूरा कोड दिखे।';

  @override
  String get peerReceiveRefused =>
      'Fortiva इसका इस्तेमाल नहीं कर सकता। अपने दोस्त से इसे फिर से भेजने को कहें।';

  @override
  String get peerReceiveNotNewer =>
      'यह आपके पास पहले से है, या इससे नया। फिर से कनेक्ट करके देखें, या किसी और दोस्त से मदद लें।';

  @override
  String get peerReceiveTaken => 'हो गया। कनेक्ट करने के लिए बटन पर टैप करें।';

  @override
  String get peerReceiveUnavailable =>
      'यह फ़ोन ऐसा नहीं कर सकता। कोई और तरीका आज़माएँ।';

  @override
  String get peerReceiveNothingToPaste =>
      'अभी कुछ कॉपी नहीं हुआ। दोस्त का भेजा हुआ कॉपी करें, फिर यहाँ दोबारा टैप करें।';

  @override
  String get peerOfferBody =>
      'अब भी कनेक्ट नहीं हो रहा? जिस दोस्त का Fortiva चल रहा है, वे अपने फ़ोन से मदद कर सकते हैं।';

  @override
  String get peerReceiveAgain =>
      'यह कोड आपके पास पहले से है। अपने दोस्त से अगला कोड दिखाने को कहें।';

  @override
  String get peerReceivePasteNotOurs =>
      'आपने जो कॉपी किया, वह Fortiva का नहीं है। अपने दोस्त का पूरा मैसेज कॉपी करें, फिर दोबारा कोशिश करें।';

  @override
  String peerReceiveNoPhoto(String action) {
    return 'कैमरे से फ़ोटो वापस नहीं मिली। कैमरा ऐप से फ़ोटो लें, फिर \"$action\" पर टैप करें।';
  }

  @override
  String get peerReceiveFileHint =>
      'मैसेजिंग ऐप से आई फ़ाइल को शायद पहले डाउनलोड फ़ोल्डर में सेव करना पड़े।';

  @override
  String get homeTryingBackup =>
      'और कुछ कनेक्ट नहीं हुआ। अब एक बैकअप नेटवर्क आज़मा रहे हैं।';

  @override
  String get homeConnectedBackup => 'बैकअप नेटवर्क से कनेक्ट';

  @override
  String get backupNetwork => 'बैकअप नेटवर्क';

  @override
  String get backupNetworkTitle => 'बैकअप नेटवर्क';

  @override
  String get backupNetworkCaption =>
      'जब और कुछ कनेक्ट नहीं होता, तब इसका इस्तेमाल होता है। यह हमारे सर्वरों से धीमा हो सकता है।';

  @override
  String get backupNetworkPlace => 'लोकेशन अपने आप चुनी जाती है';

  @override
  String get speedTestStart => 'टेस्ट शुरू करें';

  @override
  String get speedTestAgain => 'फिर से टेस्ट करें';

  @override
  String get speedTestRunning => 'टेस्ट चल रहा है';

  @override
  String get speedTestIdle => 'देखें कि आपका कनेक्शन अभी कितना तेज़ है।';

  @override
  String get speedTestPhasePing => 'जवाब का समय जाँचा जा रहा है';

  @override
  String get speedTestPhaseDownload => 'डाउनलोड स्पीड मापी जा रही है';

  @override
  String get speedTestPhaseUpload => 'अपलोड स्पीड मापी जा रही है';

  @override
  String get speedTestDone => 'टेस्ट पूरा हुआ';

  @override
  String get speedTestFailed =>
      'टेस्ट पूरा नहीं हो सका। अपना इंटरनेट जाँचें और फिर से कोशिश करें।';

  @override
  String get speedTestUnit => 'Mbps';

  @override
  String get ipAddressLabel => 'IP पता';

  @override
  String get ipCopied => 'पता कॉपी हो गया';

  @override
  String get ipLocation => 'जगह';

  @override
  String get ipProvider => 'इंटरनेट प्रदाता';

  @override
  String get ipOrganization => 'संगठन';

  @override
  String get ipTimeZone => 'समय क्षेत्र';

  @override
  String get ipCoordinates => 'निर्देशांक';

  @override
  String get ipCheckFailed => 'आपका पता जाँचा नहीं जा सका';

  @override
  String get historyAverage => 'औसत कनेक्शन';

  @override
  String get historyRecentDays => 'हाल के दिन';

  @override
  String yesterdayAt(String time) {
    return 'कल $time बजे';
  }

  @override
  String dateAt(String date, String time) {
    return '$date, $time बजे';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds सेकंड';
  }

  @override
  String get stageOwn => 'Fortiva सर्वर';

  @override
  String get stageCommunity => 'समुदाय सर्वर';

  @override
  String stageProgress(int n, int total) {
    return '$total में से चरण $n';
  }

  @override
  String get stageTryingOwn => 'Fortiva सर्वर आज़मा रहे हैं';

  @override
  String get stageTryingCommunity => 'समुदाय सर्वर आज़मा रहे हैं';

  @override
  String get stageOwnFailedTryingCommunity =>
      'Fortiva सर्वर यहाँ से कनेक्ट नहीं हुए। अब समुदाय सर्वर आज़मा रहे हैं।';

  @override
  String stageLastWorked(String server) {
    return 'पिछली बार चला सर्वर: $server';
  }

  @override
  String stageTriedBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count रास्ते आज़माए, यहाँ ब्लॉक हैं',
      one: '$count रास्ता आज़माया, यहाँ ब्लॉक है',
    );
    return '$_temp0';
  }

  @override
  String stageTriedFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count रास्ते आज़माए, कोई कनेक्ट नहीं हुआ',
      one: '$count रास्ता आज़माया, कनेक्ट नहीं हुआ',
    );
    return '$_temp0';
  }

  @override
  String get stageNotConnected => 'कनेक्ट नहीं हुआ';

  @override
  String get stageConnected => 'यहाँ से कनेक्ट';

  @override
  String get stageSkipped => 'इस बार छोड़ा गया';

  @override
  String stageMoreToCheck(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count और रास्ते जाँचने बाकी',
      one: '$count और रास्ता जाँचना बाकी',
    );
    return '$_temp0';
  }

  @override
  String stageNextTry(String stage, String time) {
    return 'अगली कोशिश $time में, $stage से शुरू';
  }

  @override
  String get searchSlowHint =>
      'इसमें एक-दो मिनट लग सकते हैं। खोज रोकने के लिए बटन पर टैप करें।';

  @override
  String get searchStopped => 'खोज रोकी गई';

  @override
  String get homeConnectedCommunity => 'समुदाय सर्वर से कनेक्ट';

  @override
  String get stageGettingServers => 'आपके सर्वर लाए जा रहे हैं';

  @override
  String stageNextTryStarting(String stage) {
    return 'अगली कोशिश अब $stage से शुरू हो रही है';
  }
}
