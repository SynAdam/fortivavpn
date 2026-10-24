// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class SEs extends S {
  SEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Fortiva';

  @override
  String get statusDisconnected => 'No conectado';

  @override
  String get statusConnecting => 'Conectando';

  @override
  String get statusConnected => 'Conectado';

  @override
  String get statusDisconnecting => 'Finalizando...';

  @override
  String get statusError => 'Falló';

  @override
  String get statusVerifying => 'Verificando...';

  @override
  String get disconnect => 'Finalizar';

  @override
  String get connectBtn => 'Conectar';

  @override
  String get disconnectBtn => 'Desconectar';

  @override
  String get pleaseWait => 'ESPERA UN MOMENTO';

  @override
  String get locationLabel => 'Ubicación';

  @override
  String get selectServer => 'Elige una ubicación';

  @override
  String get serverLocation => 'Ubicación';

  @override
  String get searchServers => 'Buscar servidores';

  @override
  String get locationsTitle => 'Ubicaciones';

  @override
  String get sortLatency => 'Ordenar: Latencia';

  @override
  String get sortAZ => 'Ordenar: A-Z';

  @override
  String get sortedByLatency => 'Ordenado por latencia';

  @override
  String get sortedAZ => 'Ordenado de A a Z';

  @override
  String get pingAll => 'Probar todos';

  @override
  String get pinging => 'Haciendo ping...';

  @override
  String get ping => 'Ping';

  @override
  String get stop => 'Detener';

  @override
  String get fastestServer => 'Más rápido';

  @override
  String get timeout => 'sin respuesta';

  @override
  String get tabCommunity => 'Comunidad';

  @override
  String get tabFree => 'Gratis';

  @override
  String get tabPremium => 'Premium';

  @override
  String get noCommunityServers => 'Aún no hay servidores de la comunidad';

  @override
  String get communityLoadFailed => 'No se pudo cargar esta lista';

  @override
  String get communityRetry => 'Intentar de nuevo';

  @override
  String get officialTabExplainer =>
      'Operados por Fortiva y mantenidos en línea por nosotros. Los comparten todos los que usan la app. Empieza aquí.';

  @override
  String get communityTabExplainer =>
      'Opciones de conexión adicionales. La velocidad y la disponibilidad varían.';

  @override
  String get noFreeServers => 'Aún no hay servidores gratis';

  @override
  String get noPremiumServers => 'Aún no hay servidores Premium';

  @override
  String noResultsFor(String query) {
    return 'Sin resultados para «$query»';
  }

  @override
  String get proBadge => 'PREMIUM';

  @override
  String get freeBadge => 'GRATIS';

  @override
  String get settings => 'Configuración';

  @override
  String get connection => 'Red';

  @override
  String get dnsConfiguration => 'DNS';

  @override
  String get customDns => 'Usar tus propios servidores DNS';

  @override
  String get about => 'Acerca de';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get contactUs => 'Contáctanos';

  @override
  String get rateOnGooglePlay => 'Califica Fortiva en Google Play';

  @override
  String get website => 'Sitio web';

  @override
  String get copyright => '© 2026 NimusAI';

  @override
  String get version => 'Versión';

  @override
  String get language => 'Idioma';

  @override
  String get languageSubtitle => 'Idioma de la interfaz';

  @override
  String get whatIsDns => '¿Qué es el DNS?';

  @override
  String get dnsExplanation =>
      'El DNS convierte los nombres de los sitios web en direcciones a las que tu teléfono puede llegar. Usar otro DNS puede hacer que los sitios carguen más rápido y ayudarte a entrar a sitios que tu proveedor bloquea.';

  @override
  String get configuration => 'Configuración';

  @override
  String get primaryDns => 'DNS primario';

  @override
  String get primaryDnsHint => 'Predeterminado: 1.1.1.1';

  @override
  String get secondaryDns => 'DNS secundario (opcional)';

  @override
  String get secondaryDnsHint => 'Predeterminado: 8.8.8.8';

  @override
  String get saveConfiguration => 'Guardar';

  @override
  String get dnsSaved => 'Configuración de DNS guardada';

  @override
  String get invalidPrimaryDns => 'Esa dirección de DNS primario no es válida';

  @override
  String get invalidSecondaryDns =>
      'Esa dirección de DNS secundario no es válida';

  @override
  String get statistics => 'Historial';

  @override
  String get overview => 'RESUMEN';

  @override
  String get connectionsLabel => 'Sesiones';

  @override
  String get totalTime => 'Tiempo conectado';

  @override
  String get dataUsage => 'Datos usados';

  @override
  String get uploaded => 'Subidos';

  @override
  String get downloaded => 'Descargados';

  @override
  String get total => 'En total';

  @override
  String lastUpdated(String date) {
    return 'Última actualización: $date';
  }

  @override
  String today(String time) {
    return 'Hoy a las $time';
  }

  @override
  String get yesterday => 'Ayer';

  @override
  String daysAgo(int count) {
    return 'Hace $count días';
  }

  @override
  String get noDataYet => 'Sin datos de sesiones';

  @override
  String get connectToStart => 'Conéctate para empezar el registro';

  @override
  String get errorConnectionFailed => 'No se pudo conectar';

  @override
  String get errorServerNotWorking =>
      'Esta ubicación no funciona. Prueba otra.';

  @override
  String get errorServerNotForwarding =>
      'Esta ubicación no está pasando tráfico. Prueba otra.';

  @override
  String get errorUnexpected => 'Error inesperado';

  @override
  String get errorDisconnectionFailed => 'No se pudo desconectar';

  @override
  String get errorFailedToRegister => 'No se pudo registrar el dispositivo';

  @override
  String get ipInformation => 'Ver mi IP';

  @override
  String get connectionAnalytics => 'Historial';

  @override
  String get recentSessions => 'Conexiones recientes';

  @override
  String get speedTest => 'Prueba de velocidad';

  @override
  String get startTest => 'EJECUTAR DIAGNÓSTICO';

  @override
  String get download => 'Descarga';

  @override
  String get upload => 'Subida';

  @override
  String get testingViaVpn => 'Probando a través del túnel';

  @override
  String get testingDirect => 'Probando la conexión directa';

  @override
  String get splitTunneling => 'Configuración de rutas';

  @override
  String get splitTunnelingDescription =>
      'Elige qué categorías de apps evitan el túnel. Las apps excluidas usan tu conexión de red directa.';

  @override
  String get enableSplitTunneling => 'Activar división de rutas';

  @override
  String get splitTunnelActive => 'Las apps seleccionadas evitan el túnel';

  @override
  String get splitTunnelInactive => 'Todo el tráfico pasa por el túnel';

  @override
  String get bypassVpnFor => 'Evitar el túnel para';

  @override
  String get tools => 'Diagnóstico';

  @override
  String get settingsGeneral => 'Generales';

  @override
  String get shareDiagnosticsTitle => 'Compartir diagnósticos de conexión';

  @override
  String get shareDiagnosticsBody =>
      'Envía informes de conexión, tu operador y tu país, el modelo del teléfono y la versión de Android, los nombres de los sitios que visitas a través de la VPN, con un recuento diario, y si viste o tocaste nuestros mensajes, nuestras ofertas de Premium y nuestra tarjeta de invitación. Nunca vemos las páginas que abres ni lo que envías.';

  @override
  String get security => 'Cumplimiento';

  @override
  String get privacyDashboard => 'Análisis del punto de conexión';

  @override
  String get privacyDashboardSubtitle =>
      'Transparencia de IP y monitoreo de fugas';

  @override
  String get connectionAnalyticsSubtitle => 'Historial de sesiones y reportes';

  @override
  String get speedTestSubtitle => 'Medición de rendimiento';

  @override
  String get splitTunnelingSubtitle => 'Configurar políticas de rutas';

  @override
  String get splashTagline => 'Acceso privado, estés donde estés';

  @override
  String get openSourceLicence => 'Licencia de código abierto';

  @override
  String get sourceOfferTitle => 'Licencia de código abierto';

  @override
  String get sourceOfferBody =>
      'Fortiva VPN es software libre bajo la GNU General Public License v3. Se basa en Xray-core y otros proyectos de código abierto.\n\nTienes derecho al código fuente completo de la versión que tienes instalada. Para solicitarlo, escribe a admin@fortivavpn.com indicando la versión de tu app. Esta oferta es válida durante tres años a partir de la fecha en que recibiste esta versión.';

  @override
  String get close => 'Cerrar';

  @override
  String get account => 'Cuenta';

  @override
  String get deleteAccount => 'Eliminar cuenta';

  @override
  String get deleteAccountSubtitle =>
      'Eliminar este dispositivo y tus datos de forma permanente';

  @override
  String get deleteAccountConfirmTitle => '¿Eliminar tu cuenta?';

  @override
  String get deleteAccountConfirmBody =>
      'Esto elimina el registro de tu dispositivo, cualquier cuenta de Google vinculada, los servidores personales creados para ti y tus mensajes del chat de soporte. Tu historial de conexiones en este teléfono también se borra.\n\nEsto no se puede deshacer. Puedes empezar de nuevo en cualquier momento volviendo a abrir la app.';

  @override
  String deleteAccountConfirmRetention(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días',
      one: '$days día',
    );
    return 'El registro de tu cuenta se elimina de inmediato. Las copias en los respaldos y los registros anónimos del servidor se borran en un plazo de $_temp0.';
  }

  @override
  String get deleteAccountConfirmRetentionNoDays =>
      'El registro de tu cuenta se elimina de inmediato. Las copias en los respaldos y los registros anónimos del servidor se borran más adelante, según los plazos de nuestra política de privacidad.';

  @override
  String get deleteAccountCancel => 'Conservar mi cuenta';

  @override
  String get deleteAccountConfirm => 'Eliminar';

  @override
  String get deleteAccountInProgress => 'Eliminando tu cuenta';

  @override
  String get deleteAccountDone => 'Tu cuenta fue eliminada.';

  @override
  String get deleteAccountFailed =>
      'No se pudo eliminar tu cuenta. Revisa tu conexión e intenta de nuevo.';

  @override
  String get homeTapToConnect => 'Toca para conectar';

  @override
  String get homeChecking => 'Revisando la conexión';

  @override
  String get homePreparing => 'Preparando tu servidor';

  @override
  String get homeDisconnecting => 'Desconectando';

  @override
  String get homeFindingPath => 'Buscando una ruta';

  @override
  String get diagCheckingInternet => 'Revisando tu internet';

  @override
  String get diagInternationalCut =>
      'El internet internacional está cortado en esta red';

  @override
  String diagPathRow(String city, int n) {
    return '$city, ruta $n';
  }

  @override
  String get diagOpen => 'abierta';

  @override
  String get diagBlocked => 'bloqueada';

  @override
  String get diagSkipped => 'omitida hoy';

  @override
  String diagConnectingThrough(String city) {
    return 'Conectando a través de $city';
  }

  @override
  String get diagVerifying => 'Verificando el tráfico';

  @override
  String get diagNoInternet => 'Tu teléfono no tiene internet en este momento.';

  @override
  String get diagCutOff =>
      'Tu red no llega al internet internacional en este momento. Toca para intentar de nuevo.';

  @override
  String get diagNothingOpen =>
      'Todas las rutas están bloqueadas en este momento. Toca para intentar de nuevo.';

  @override
  String get homeTryingAgain =>
      'Todas las rutas están bloqueadas en este momento. Lo intentaremos de nuevo en breve.';

  @override
  String get homeCutOffTryingAgain =>
      'Tu red no llega al internet internacional en este momento. Lo intentaremos de nuevo en breve.';

  @override
  String get homeOfflineTryingAgain =>
      'Tu teléfono no tiene internet en este momento. Lo intentaremos de nuevo en breve.';

  @override
  String get diagPathFailed =>
      'La ruta estaba abierta, pero el túnel no se estableció. Toca para intentar de nuevo.';

  @override
  String get openVpnSettings => 'Abrir configuración de VPN';

  @override
  String get yourServer => 'TU SERVIDOR';

  @override
  String get yourServerCaption =>
      'Solo tuyo. Nadie más se conecta a través de él.';

  @override
  String get ourServer => 'NUESTRO SERVIDOR';

  @override
  String get ourServerCaption =>
      'Operado por Fortiva y compartido con todos. Se usa hasta que tu propio servidor esté listo.';

  @override
  String get communityServer => 'SERVIDOR DE LA COMUNIDAD';

  @override
  String get communityServerCaption =>
      'Una opción de conexión adicional. Puede dejar de funcionar en cualquier momento.';

  @override
  String communityServerNumber(String n) {
    return 'Servidor de la comunidad $n';
  }

  @override
  String get myServersTitle => 'Tus servidores';

  @override
  String get myServersExplainer =>
      'Cada dispositivo con Fortiva recibe su propio servidor en cada ubicación, con credenciales que pertenecen solo a esta instalación. No se necesita cuenta.';

  @override
  String get myServersInUse => 'En uso';

  @override
  String get myServersEmpty => 'Aún no hay servidores asignados';

  @override
  String get myServersRetry => 'Intentar de nuevo';

  @override
  String get myServersBlockedTitle => 'Ya usaste los datos de hoy';

  @override
  String get myServersBlockedWait =>
      'Tus datos diarios se reinician automáticamente. Vuelve pronto.';

  @override
  String myServersMoved(String place) {
    return 'Ahora usando $place';
  }

  @override
  String get copyLink => 'Copiar enlace';

  @override
  String get linkCopied => 'Enlace copiado';

  @override
  String quotaUsedToday(String used, String limit) {
    return '$used de $limit usados hoy';
  }

  @override
  String get quotaUsedUp => 'Datos diarios agotados';

  @override
  String get quotaUnlimited => 'Datos ilimitados';

  @override
  String get quotaDaily => 'Datos diarios';

  @override
  String get quotaLimitReached => 'Límite diario alcanzado';

  @override
  String quotaLeftOf(String left, String limit) {
    return 'Quedan $left de $limit';
  }

  @override
  String get quotaResetsShortly => 'Se reinicia en breve';

  @override
  String quotaResetsInHours(int hours) {
    return 'Se reinicia en $hours h';
  }

  @override
  String quotaResetsInMinutes(int minutes) {
    return 'Se reinicia en $minutes min';
  }

  @override
  String get myServersSubtitle => 'Los servidores asignados a este dispositivo';

  @override
  String get sharedServersTitle => 'Servidores compartidos';

  @override
  String get sharedServersSubtitle =>
      'Ubicaciones públicas, usadas como respaldo';

  @override
  String get tabOfficial => 'Nuestros servidores';

  @override
  String get noOfficialServers =>
      'No hay servidores de Fortiva en este momento';

  @override
  String get inviteTitle => 'Invitar amigos';

  @override
  String get inviteSubtitle => 'Gana datos diarios extra';

  @override
  String get inviteYourCode => 'Tu código de invitación';

  @override
  String get inviteShareAction => 'Compartir invitación';

  @override
  String get inviteCopyAction => 'Copiar código';

  @override
  String get inviteCodeCopied => 'Código copiado';

  @override
  String inviteShareMessage(String code, String url) {
    return 'Una VPN gratis que me funciona bien: Fortiva. Sin registro.\nInstálala desde este enlace:\n$url\nMi código de invitación: $code';
  }

  @override
  String get inviteHowItWorks => 'Cómo funciona';

  @override
  String inviteHowItWorksBody(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días distintos',
      one: '$days día',
    );
    return 'Comparte tu código. Cuando alguien instala la app, lo ingresa y usa la VPN durante $_temp0, se suman $amount a tus datos diarios. Se quedan en tu cuenta.';
  }

  @override
  String inviteHowItWorksBodyNoAmount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días distintos',
      one: '$days día',
    );
    return 'Comparte tu código. Cuando alguien instala la app, lo ingresa y usa la VPN durante $_temp0, recibes más datos cada día. Se quedan en tu cuenta.';
  }

  @override
  String inviteHowItWorksBodyNoDays(String amount) {
    return 'Comparte tu código. Cuando alguien instala la app, lo ingresa y usa la VPN por un tiempo, se suman $amount a tus datos diarios. Se quedan en tu cuenta.';
  }

  @override
  String get inviteHowItWorksBodyNoAmountNoDays =>
      'Comparte tu código. Cuando alguien instala la app, lo ingresa y usa la VPN por un tiempo, recibes más datos cada día. Se quedan en tu cuenta.';

  @override
  String inviteHowItWorksCap(String max) {
    return 'Puedes ganar hasta $max al día con invitaciones.';
  }

  @override
  String get inviteStatInvited => 'Invitados';

  @override
  String get inviteStatEarning => 'Confirmados';

  @override
  String get inviteStatBonus => 'Bono de datos';

  @override
  String inviteBonusPerDay(String amount) {
    return '+$amount cada día';
  }

  @override
  String get inviteNoBonusYet => 'Aún sin bono';

  @override
  String invitePendingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitaciones aún no están confirmadas',
      one: '1 invitación aún no está confirmada',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String inviteJoinedWith(String code) {
    return 'Te uniste con el código $code';
  }

  @override
  String get inviteLoadFailed => 'No se pudo cargar tu código de invitación';

  @override
  String get inviteRetry => 'Intentar de nuevo';

  @override
  String get inviteHaveCodeTitle => '¿Tienes un código de invitación?';

  @override
  String inviteHaveCodeSubtitle(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Ingrésalo en tus primeras $hours horas',
      one: 'Ingrésalo en tu primera hora',
    );
    return '$_temp0';
  }

  @override
  String get inviteHaveCodeSubtitleNoHours =>
      'Ingrésalo poco después de instalar';

  @override
  String get inviteEnterCodeHint => 'Código de invitación';

  @override
  String get inviteApplyAction => 'Aplicar';

  @override
  String get inviteNotNowAction => 'Ahora no';

  @override
  String inviteClaimAccepted(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días distintos',
      one: '$days día',
    );
    return 'Invitación aceptada. Tu amigo gana un bono de datos cuando hayas usado la VPN durante $_temp0.';
  }

  @override
  String get inviteClaimAcceptedNoDays =>
      'Invitación aceptada. Tu amigo gana un bono de datos cuando hayas usado la VPN por un tiempo.';

  @override
  String get inviteClaimAlready =>
      'Este dispositivo ya usó un código de invitación';

  @override
  String get inviteClaimRejected =>
      'Ese código no funcionó. Revísalo e intenta de nuevo';

  @override
  String get inviteClaimNetwork =>
      'No se pudo contactar al servidor. Intenta de nuevo';

  @override
  String get inviteCardTitle =>
      '¿Fortiva te funciona bien? Compártelo con tus amigos';

  @override
  String get inviteCardBody =>
      'Envíale a tu amigo el enlace de instalación para que también se conecte gratis.';

  @override
  String inviteCardReward(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Cuando tu amigo empiece a usar Fortiva, recibirás $days días de Premium.',
      one:
          'Cuando tu amigo empiece a usar Fortiva, recibirás $days día de Premium.',
    );
    return '$_temp0';
  }

  @override
  String get inviteCardRewardNoAmount =>
      'Cuando tu amigo empiece a usar Fortiva, recibirás Premium de regalo.';

  @override
  String get inviteSendTelegram => 'Telegram';

  @override
  String get inviteSendWhatsApp => 'WhatsApp';

  @override
  String get inviteCopyLink => 'Copiar enlace';

  @override
  String get inviteOtherApps => 'Otras apps';

  @override
  String get inviteLinkCopied => 'Mensaje de invitación copiado';

  @override
  String get invitePasteBody =>
      'Copia el código del mensaje de tu amigo y pégalo aquí.';

  @override
  String get invitePasteAction => 'Pegar';

  @override
  String get inviteErrorTooLate =>
      'Ya pasó el tiempo para ingresar un código de invitación en este teléfono.';

  @override
  String get inviteErrorUnknown =>
      'No encontramos este código. Cópialo otra vez del mensaje de tu amigo.';

  @override
  String get inviteErrorOwnCode =>
      'Este es tu propio código. Ingresa el código de tu amigo.';

  @override
  String get inviteErrorMutual => 'Tú y tu amigo no pueden invitarse entre sí.';

  @override
  String inviteHowItWorksPremium(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Cada amigo que empiece a usar Fortiva también te da $days días de Premium.',
      one:
          'Cada amigo que empiece a usar Fortiva también te da $days día de Premium.',
    );
    return '$_temp0';
  }

  @override
  String inviteHowItWorksPremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Puedes ganar hasta $max días de Premium con invitaciones.',
      one: 'Puedes ganar hasta $max día de Premium con invitaciones.',
    );
    return '$_temp0';
  }

  @override
  String get premiumSourceInvite => 'Gracias a tus invitaciones';

  @override
  String quotaBonusIncluded(String amount) {
    return 'incluye $amount de bono por invitaciones';
  }

  @override
  String get updateTitle => 'Actualización disponible';

  @override
  String get updateRequiredTitle => 'Actualización necesaria';

  @override
  String updateBody(String version) {
    return 'Ya salió Fortiva $version. Actualiza para tener las correcciones más recientes.';
  }

  @override
  String get updateRequiredBody =>
      'Esta versión ya no es compatible. Actualiza para seguir usando Fortiva.';

  @override
  String get updateNow => 'Actualizar';

  @override
  String get updateLater => 'Después';

  @override
  String get updateFromPlay => 'Google Play';

  @override
  String get updateFromTelegram => 'Canal de Telegram';

  @override
  String get updateConnect => 'Conectar';

  @override
  String get updateConnectHint =>
      'Si Google Play o Telegram no se abre, toca Conectar primero.';

  @override
  String get updateConnected =>
      'Estás conectado. Descarga la actualización ahora.';

  @override
  String get updateReconnect => '¿No funciona? Reconectar';

  @override
  String get updateDisconnect => 'Desconectar';

  @override
  String get updateDisconnectHint =>
      'Toca Desconectar para descargar la actualización con tu internet normal.';

  @override
  String get updateNotCarrying =>
      'Estás conectado, pero el tráfico no está pasando. Prueba Reconectar, o toca Desconectar para usar tu internet normal.';

  @override
  String get diagVerdictNoInternet =>
      'Tu teléfono no tiene conexión a internet. Fortiva no puede conectarse hasta que vuelva.';

  @override
  String get diagVerdictCutOff =>
      'Tu red no llega al internet internacional en este momento. Inténtalo de nuevo en unos minutos.';

  @override
  String get diagVerdictNeedsPermission =>
      'Fortiva no tiene permiso para ejecutar una VPN, u otra app de VPN está configurada como siempre activa.';

  @override
  String get diagVerdictServerUnreachable =>
      'No se puede llegar a este servidor desde tu red. Está bloqueado aquí o está caído.';

  @override
  String get diagVerdictBlockedTls =>
      'La conexión con este servidor se corta mientras se está estableciendo. Así se ve el filtrado.';

  @override
  String get diagVerdictThrottled =>
      'El servidor respondió a todas las pruebas y aun así el túnel no transportó nada. La conexión está siendo frenada.';

  @override
  String get diagCheckInternet => 'Revisa tu internet';

  @override
  String diagTryServer(String server) {
    return 'Nueva búsqueda con $server';
  }

  @override
  String get diagTryAnotherServer => 'Probar otro servidor';

  @override
  String get diagDetails => 'Detalles';

  @override
  String get diagDetailsHide => 'Ocultar detalles';

  @override
  String privateDnsWarning(String host) {
    return 'El DNS privado está activado ($host), por eso algunos sitios pueden no abrir. Desactiva el DNS privado en la configuración de tu teléfono.';
  }

  @override
  String get openNetworkSettings => 'Abrir configuración de red';

  @override
  String testPointStatus(String time, int open, int total) {
    return 'Punto de prueba · última revisión $time · $open de $total puertas abiertas';
  }

  @override
  String get messagesTooltip => 'Mensajes';

  @override
  String get inboxTitle => 'Mensajes';

  @override
  String get inboxEmpty => 'No hay mensajes por ahora.';

  @override
  String get messageClose => 'Cerrar';

  @override
  String get supportTitle => 'Soporte';

  @override
  String get supportTooltip => 'Chatear con soporte';

  @override
  String get supportAskAction => 'Preguntar a soporte';

  @override
  String get supportContactSubtitle => 'Chatea con nosotros en la app';

  @override
  String get supportAutomaticNotice =>
      'Las respuestas se escriben automáticamente y pueden estar equivocadas.';

  @override
  String get supportStaffNotice =>
      'Las respuestas automáticas están desactivadas por ahora. Tus mensajes van a nuestro equipo.';

  @override
  String get supportInputHint => 'Escribe tu pregunta';

  @override
  String get supportInputHintTeam => 'Escribe a nuestro equipo';

  @override
  String get supportSend => 'Enviar';

  @override
  String supportQuotaLeft(int remaining, int limit) {
    return 'Te quedan $remaining de $limit preguntas hoy';
  }

  @override
  String supportWaitIn(String time) {
    return 'Puedes volver a preguntar en $time.';
  }

  @override
  String supportDurationHours(int hours, int minutes) {
    return '$hours h y $minutes min';
  }

  @override
  String supportDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get supportNewConversation => 'Nueva conversación';

  @override
  String get supportSending => 'Enviando';

  @override
  String get supportNotSent => 'No se envió. Toca para intentar de nuevo.';

  @override
  String get supportRateUp => 'Útil';

  @override
  String get supportRateDown => 'No fue útil';

  @override
  String get supportRatedDown =>
      'Gracias. Nuestro equipo revisará esta respuesta.';

  @override
  String get supportTeamLabel => 'Equipo de Fortiva';

  @override
  String get supportUnavailable =>
      'El chat no está disponible en este momento.';

  @override
  String get supportOpenTelegram => 'Escríbenos por Telegram';

  @override
  String get supportGenericError => 'Algo salió mal. Intenta de nuevo.';

  @override
  String supportCodeTooLong(int max) {
    return 'Tu mensaje es demasiado largo. Usa menos de $max caracteres.';
  }

  @override
  String get supportCodeEmpty => 'Tu mensaje está vacío.';

  @override
  String get supportCodeWaitReply =>
      'Espera la respuesta a tu última pregunta.';

  @override
  String get supportCodeSlowDown =>
      'Estás enviando mensajes demasiado rápido. Espera un poco.';

  @override
  String get supportCodeQuotaDay => 'Ya usaste todas las preguntas de hoy.';

  @override
  String get supportCodePaused =>
      'Las respuestas automáticas están en pausa por ahora.';

  @override
  String get supportCodeBusy =>
      'Nuestro asistente está ocupado en este momento. Intenta de nuevo en unos minutos.';

  @override
  String get supportCodeGreeting =>
      '¡Hola! ¿En qué puedo ayudarte con Fortiva?';

  @override
  String get supportCodeGibberish =>
      'Perdón, no entendí eso. Escribe tu pregunta de nuevo.';

  @override
  String get supportCodeRedacted =>
      'Quitamos los datos personales y los enlaces de tu mensaje.';

  @override
  String get supportCodeRedactedEmpty =>
      'Tu mensaje solo tenía datos personales o enlaces, así que no se envió. Describe el problema con palabras.';

  @override
  String get supportCodeOffTopic =>
      'Solo puedo ayudar con preguntas sobre cómo usar Fortiva.';

  @override
  String get supportCodeAbuse =>
      'Mantengamos el respeto. Estoy aquí para ayudarte con Fortiva.';

  @override
  String get supportCodeAiUnavailable =>
      'El asistente no pudo responder esta vez. Intenta de nuevo en un rato.';

  @override
  String get supportCodeToStaff =>
      'Enviado a nuestro equipo. Su respuesta aparecerá aquí.';

  @override
  String get supportCodeTicketOpened =>
      'Pasamos tu pregunta a nuestro equipo. Su respuesta aparecerá aquí.';

  @override
  String get supportCodeNotSent =>
      'No se pudo enviar este mensaje. Escríbelo de nuevo si aún necesitas ayuda.';

  @override
  String get supportAssistantSubtitle => 'Asistente de IA';

  @override
  String get supportThinkingReading => 'Leyendo tu pregunta';

  @override
  String get supportThinkingSearching => 'Buscando la respuesta';

  @override
  String get supportThinkingWriting => 'Escribiendo la respuesta';

  @override
  String get supportThinkingStill =>
      'Sigo trabajando en esto, gracias por esperar';

  @override
  String get supportSuggestConnect => 'No puedo conectarme';

  @override
  String get supportSuggestData => '¿Cuántos datos tengo hoy?';

  @override
  String get supportSuggestSlow => 'Mi conexión está lenta';

  @override
  String get supportWithTeam =>
      'Esta conversación ahora está con nuestro equipo.';

  @override
  String get supportTryAgainSoon => 'Intenta de nuevo en unos minutos.';

  @override
  String supportDurationWholeHours(int hours) {
    return '$hours h';
  }

  @override
  String get supportUnreadReply => 'Nueva respuesta';

  @override
  String get premiumTitle => 'Premium';

  @override
  String get premiumTileSubtitle => 'Datos ilimitados, sin límite diario';

  @override
  String get premiumTileActive => 'Premium está activo';

  @override
  String get premiumGetUnlimited => 'Obtener ilimitado';

  @override
  String get premiumHeadline => 'Obtén datos ilimitados';

  @override
  String get premiumPitch =>
      'Premium quita el límite diario, así que puedes usar todos los datos que quieras hasta que termine.';

  @override
  String get premiumActiveTitle => 'Premium está activo';

  @override
  String premiumActiveUntil(String date) {
    return 'Datos ilimitados hasta el $date';
  }

  @override
  String get premiumActiveNoDate => 'Datos ilimitados';

  @override
  String get premiumRenews =>
      'Se renueva automáticamente a través de Google Play';

  @override
  String get premiumSourceKey => 'Activado con una clave';

  @override
  String get premiumSourceCrypto => 'Pagado con cripto';

  @override
  String get premiumSourceStars => 'Pagado con Estrellas de Telegram';

  @override
  String get premiumSourceGooglePlay => 'Pagado a través de Google Play';

  @override
  String get premiumSourceManual => 'Un regalo del equipo de Fortiva';

  @override
  String get premiumYourKey => 'Tu clave';

  @override
  String get premiumKeyHint =>
      'Guarda bien esta clave. Ingrésala en otro teléfono para pasar Premium allí.';

  @override
  String premiumKeyMoves(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hasta $count veces',
      one: 'una vez',
    );
    String _temp1 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días',
      one: '$days día',
    );
    return 'Una clave puede pasar a otro teléfono $_temp0 en $_temp1.';
  }

  @override
  String get premiumKeyMovesNoNumber =>
      'Una clave solo puede pasar a otro teléfono un número limitado de veces.';

  @override
  String get premiumCopy => 'Copiar';

  @override
  String get premiumCopied => 'Copiado';

  @override
  String get premiumChoosePlan => 'Elige un plan';

  @override
  String premiumPlanDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días de datos ilimitados',
      one: '$days día de datos ilimitados',
    );
    return '$_temp0';
  }

  @override
  String get premiumPlanNoDays => 'Datos ilimitados';

  @override
  String get premiumBuy => 'Comprar';

  @override
  String get premiumPlayUnavailable =>
      'Google Play no está disponible en este momento. Intenta de nuevo más tarde.';

  @override
  String get premiumPlayPending =>
      'Tu pago está pendiente en Google Play. Premium empieza en cuanto se apruebe.';

  @override
  String get premiumPlayConfirming => 'Confirmando tu compra...';

  @override
  String get premiumPlayRetrying =>
      'Tu pago se realizó, pero aún no pudimos confirmarlo. Seguiremos intentando, así que no necesitas pagar de nuevo.';

  @override
  String get premiumPlayRefused =>
      'No pudimos confirmar esta compra. Si se te cobró, contacta a soporte.';

  @override
  String get premiumPlayNotAvailable =>
      'Premium no está disponible en este teléfono en este momento. Si se te cobró, contacta a soporte.';

  @override
  String get premiumNotAvailable =>
      'Premium no está disponible en este teléfono en este momento.';

  @override
  String get premiumPlayFailed => 'La compra no se completó. Intenta de nuevo.';

  @override
  String get premiumNowOn =>
      'Premium está activo. Disfruta los datos ilimitados.';

  @override
  String get premiumRestore => 'Restaurar compras';

  @override
  String get premiumRestoreDone => 'Tu compra se restauró en este teléfono.';

  @override
  String get premiumRestoreNone =>
      'Esta cuenta de Google no tiene compras que restaurar.';

  @override
  String get premiumRestoreFailed =>
      'No se pudo restaurar tu compra. Intenta de nuevo más tarde.';

  @override
  String premiumRenewsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Se cobra cada $count días. Se renueva automáticamente hasta que canceles.',
      one: 'Se cobra cada día. Se renueva automáticamente hasta que canceles.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Se cobra cada $count semanas. Se renueva automáticamente hasta que canceles.',
      one:
          'Se cobra cada semana. Se renueva automáticamente hasta que canceles.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Se cobra cada $count meses. Se renueva automáticamente hasta que canceles.',
      one: 'Se cobra cada mes. Se renueva automáticamente hasta que canceles.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Se cobra cada $count años. Se renueva automáticamente hasta que canceles.',
      one: 'Se cobra cada año. Se renueva automáticamente hasta que canceles.',
    );
    return '$_temp0';
  }

  @override
  String get premiumRenewsNoPeriod =>
      'Se renueva automáticamente hasta que canceles.';

  @override
  String get premiumPlayCancelNote =>
      'Puedes cancelar cuando quieras en Google Play. Premium sigue activo hasta el final del periodo que pagaste.';

  @override
  String get premiumManageSubscription =>
      'Administrar o cancelar la suscripción';

  @override
  String get premiumCurrentPlan => 'Plan actual';

  @override
  String get premiumPlaySubscribed =>
      'Ya tienes una suscripción de Google Play. Adminístrala o cancélala en Google Play.';

  @override
  String get premiumEnterCode => 'Ingresar un código';

  @override
  String get premiumNeedsPlayVersion =>
      'Para comprar a través de Google Play, necesitas la versión de Fortiva de Google Play.';

  @override
  String get premiumOff => 'Premium no está a la venta en este momento.';

  @override
  String get premiumLoadFailed =>
      'No se pudo cargar Premium. Revisa tu conexión e intenta de nuevo.';

  @override
  String get premiumRetry => 'Intentar de nuevo';

  @override
  String premiumPriceUsdt(String price) {
    return '$price USDT';
  }

  @override
  String premiumPriceStars(String stars) {
    return '$stars Estrellas de Telegram';
  }

  @override
  String get premiumPayCrypto => 'Pagar con cripto';

  @override
  String get premiumTelegramTitle => 'Pagar en Telegram';

  @override
  String get premiumTelegramBody =>
      'Paga con Estrellas de Telegram en nuestro bot. Recibes una clave y Premium empieza en este teléfono de inmediato.';

  @override
  String get premiumTelegramButton => 'Comprar en Telegram';

  @override
  String get premiumTelegramFailed =>
      'No se pudo abrir Telegram. Intenta de nuevo.';

  @override
  String get checkoutTitle => 'Pagar con cripto';

  @override
  String get checkoutChooseNetwork => 'Elige la red desde la que vas a enviar';

  @override
  String get checkoutContinue => 'Continuar';

  @override
  String get checkoutSendExactly => 'Envía exactamente';

  @override
  String get checkoutNetwork => 'Red';

  @override
  String get checkoutAddress => 'A esta dirección';

  @override
  String get checkoutMemo => 'Con este memo';

  @override
  String get checkoutMemoWarning =>
      'Pon este memo en tu transferencia, o no podremos vincular el pago contigo.';

  @override
  String get checkoutExactWarning =>
      'Envía el monto exacto y solo por esta red. Un monto o una red distintos podrían no llegarnos.';

  @override
  String checkoutTimeLeft(String time) {
    return 'Tiempo restante: $time';
  }

  @override
  String get checkoutWaiting =>
      'Esperando tu pago. Esta página se actualiza sola.';

  @override
  String get checkoutPaidTitle => 'Pago recibido';

  @override
  String get checkoutPaidKeyOnly =>
      'Tu clave está lista. Ingrésala en el teléfono que debe recibir Premium.';

  @override
  String get checkoutDone => 'Listo';

  @override
  String get checkoutExpired =>
      'Este pedido expiró. Si ya pagaste, contacta a soporte.';

  @override
  String get checkoutUnderpaid =>
      'Recibimos menos del monto total. Contacta a soporte y dales este número de pedido:';

  @override
  String get checkoutCanceled => 'Este pedido fue cancelado.';

  @override
  String get checkoutStartAgain => 'Empezar de nuevo';

  @override
  String get checkoutUnavailable =>
      'Los pagos con cripto no están disponibles en este momento.';

  @override
  String get checkoutTooManyOpen =>
      'Tienes demasiados pedidos sin pagar. Paga uno de ellos o espera a que expiren.';

  @override
  String get checkoutUnknownPlan =>
      'Este plan ya no está a la venta. Regresa y elige otro.';

  @override
  String get checkoutFailed =>
      'No se pudo iniciar el pago. Revisa tu conexión e intenta de nuevo.';

  @override
  String get redeemTitle => 'Ingresar un código';

  @override
  String get redeemSubtitle => 'Una clave Premium o un código de regalo';

  @override
  String get redeemHint => 'Código';

  @override
  String get redeemApply => 'Aplicar';

  @override
  String get redeemCancel => 'Cancelar';

  @override
  String get redeemInvalid =>
      'Eso no parece un código. Revísalo e intenta de nuevo.';

  @override
  String get redeemUnknown =>
      'No reconocemos este código. Revísalo e intenta de nuevo.';

  @override
  String get redeemExpired => 'Este código expiró.';

  @override
  String get redeemRevoked => 'Este código ya no es válido.';

  @override
  String get redeemMovedTooOften =>
      'Esta clave ha cambiado de teléfono demasiadas veces últimamente. Intenta de nuevo más tarde.';

  @override
  String get redeemExhausted => 'Este código ya se agotó.';

  @override
  String get redeemAlreadyUsed => 'Este teléfono ya usó este código.';

  @override
  String get redeemUnmetered =>
      'Este teléfono ya tiene datos ilimitados, así que no necesita este código.';

  @override
  String get redeemRateLimited =>
      'Demasiados intentos. Espera un poco e intenta de nuevo.';

  @override
  String get redeemUnavailable =>
      'Esto no está disponible en este momento. Intenta de nuevo más tarde.';

  @override
  String get redeemNetwork =>
      'No se pudo contactar al servidor. Revisa tu conexión e intenta de nuevo.';

  @override
  String get redeemFailed =>
      'Ese código no funcionó. Revísalo e intenta de nuevo.';

  @override
  String get redeemMoved => 'Premium pasó a este teléfono.';

  @override
  String redeemPromo(String amount) {
    return 'Código aceptado. Se agregaron $amount de datos extra.';
  }

  @override
  String get redeemPromoNoAmount =>
      'Código aceptado. Se agregaron datos extra.';

  @override
  String get tvScanTitle => 'Abrir en tu teléfono';

  @override
  String get tvScanBody => 'Apunta la cámara de tu teléfono a este código.';

  @override
  String get refresh => 'Actualizar';

  @override
  String get premiumNotNow => 'Ahora no';

  @override
  String get premiumLimitSheetTitle => 'Los datos de hoy se agotaron';

  @override
  String get premiumLimitWait => 'Esperar el reinicio';

  @override
  String get premiumLimitInvite => 'Invita amigos para tener más datos';

  @override
  String get premiumNoDailyLimit => 'Premium no tiene límite diario.';

  @override
  String get premiumCalmTitle => '¿Te gustaría no tener límite diario?';

  @override
  String get premiumCalmBody =>
      'Premium te da datos ilimitados. Tu plan gratis se queda como está.';

  @override
  String get premiumNextStepTitle => 'El siguiente paso es Premium';

  @override
  String get premiumNextStepBody =>
      'Ya tienes el máximo de datos gratis. Premium no tiene límite diario.';

  @override
  String get premiumLockedTag => 'Premium';

  @override
  String premiumLockedTitle(String place) {
    return 'Desbloquea $place con Premium';
  }

  @override
  String get premiumLockedBody =>
      'Esta ubicación es para Premium. Tus servidores gratis siguen igual.';

  @override
  String get premiumHeadlineLimit => 'Sin límite diario';

  @override
  String premiumHeadlineLocked(String place) {
    return 'Desbloquea $place con Premium';
  }

  @override
  String get premiumFreeStays =>
      'El plan gratis sigue funcionando sin Premium.';

  @override
  String premiumEndsOn(String date) {
    return 'Premium termina el $date';
  }

  @override
  String get premiumRenewBody =>
      'Renueva para conservar los datos ilimitados. Renovar suma tiempo a tu fecha de término actual.';

  @override
  String premiumEndedOn(String date) {
    return 'Premium terminó el $date. Tu plan gratis está de vuelta.';
  }

  @override
  String get premiumRenew => 'Renovar';

  @override
  String get noticeChannelName => 'Mensajes de Fortiva';

  @override
  String get noticeChannelDescription =>
      'Novedades y mensajes del equipo de Fortiva';

  @override
  String get noticesSettingTitle => 'Notificaciones';

  @override
  String get noticesSettingOn =>
      'Activadas. Los mensajes del equipo de Fortiva pueden llegarte aunque la app esté cerrada.';

  @override
  String get noticesSettingOff =>
      'Desactivadas. Actívalas para recibir los mensajes del equipo de Fortiva aunque la app esté cerrada.';

  @override
  String get noticesOffCard =>
      'Activa las notificaciones para recibir los mensajes del equipo de Fortiva aunque la app esté cerrada.';

  @override
  String get noticesTurnOn => 'Activar';

  @override
  String get backgroundCard =>
      'Es posible que tu teléfono retenga los mensajes del equipo de Fortiva mientras la app está cerrada. Permite que Fortiva funcione en segundo plano para que te lleguen.';

  @override
  String get backgroundHint =>
      'En la siguiente pantalla, elige Fortiva (si no aparece, muestra todas las apps). Luego pon el uso de batería en Sin restricciones, o permite que se inicie y funcione en segundo plano.';

  @override
  String get backgroundAllow => 'Permitir';

  @override
  String get backgroundNotNow => 'Ahora no';

  @override
  String get backgroundSettingTitle => 'Mensajes con la app cerrada';

  @override
  String get backgroundSettingSubtitle =>
      'Permite que Fortiva funcione en segundo plano para que los mensajes te lleguen aunque la app esté cerrada.';

  @override
  String get backgroundCardData =>
      'Es posible que el Ahorro de datos de tu teléfono detenga los mensajes del equipo de Fortiva mientras la app está cerrada.';

  @override
  String get backgroundHintData =>
      'En la siguiente pantalla, activa Datos sin restricciones.';

  @override
  String get apnGuideTitle => 'Una conexión más estable con esta SIM';

  @override
  String get apnGuideBody =>
      'Tu teléfono no usa IPv6 en esta SIM. Activarlo ayuda a que Fortiva siga conectado.';

  @override
  String get apnGuideShowMe => 'Muéstrame cómo';

  @override
  String get apnGuideNotNow => 'Ahora no';

  @override
  String get apnGuideSheetTitle => 'Activa IPv6 para esta SIM';

  @override
  String apnGuideStepOpen(String button) {
    return 'Toca «$button» (o ve a Ajustes > Conexiones > Redes móviles > Nombres de punto de acceso).';
  }

  @override
  String apnGuideStepAccessPoint(String apn) {
    return 'Toca el punto de acceso en uso ($apn).';
  }

  @override
  String get apnGuideStepAccessPointAny => 'Toca el punto de acceso en uso.';

  @override
  String get apnGuideStepProtocol =>
      'Toca «Protocolo APN» y elige «IPv4/IPv6».';

  @override
  String get apnGuideStepSave =>
      'Guarda (en Samsung: el menú de tres puntos y luego «Guardar»).';

  @override
  String get apnGuideStepRestart =>
      'Desactiva los datos móviles y vuelve a activarlos.';

  @override
  String get apnGuideUndo =>
      'Si los datos móviles dejan de funcionar, vuelve a poner el protocolo APN en IPv4.';

  @override
  String get apnGuideOpenSettings => 'Abrir ajustes de APN';

  @override
  String get homeStallSearching =>
      'La conexión dejó de funcionar. Buscando otra ruta.';

  @override
  String get homeStalled => 'Conectado, pero no pasan datos';

  @override
  String get peerShareTitle => 'Ayudar a tus amigos a conectarse';

  @override
  String get peerShareSubtitle =>
      'Pasa al teléfono de tu amigo lo que Fortiva necesita';

  @override
  String get peerShareBody =>
      'Si a tu amigo no se le conecta Fortiva, su teléfono puede obtener lo que necesita del tuyo. Funciona sin internet.';

  @override
  String peerShareSteps(String action) {
    return 'En su teléfono, abre Configuración en Fortiva y toca «$action». Luego muéstrale estos códigos uno por uno, o envíaselo todo.';
  }

  @override
  String get peerShareLoading => 'Obteniendo la copia más reciente';

  @override
  String get peerShareNothing =>
      'Este teléfono no tiene nada reciente que pasar. Intenta de nuevo más tarde.';

  @override
  String peerShareCodeOf(int current, int total) {
    return 'Código $current de $total';
  }

  @override
  String get peerSharePrevious => 'Atrás';

  @override
  String get peerShareNext => 'Siguiente';

  @override
  String get peerShareCopy => 'Copiar';

  @override
  String get peerShareSend => 'Enviar';

  @override
  String get peerShareCopied => 'Copiado. Pégalo en el chat con tu amigo.';

  @override
  String get peerReceiveTitle => 'Pedir ayuda a tus amigos';

  @override
  String get peerReceiveSubtitle => 'Si no puedes conectarte de otra forma';

  @override
  String peerReceiveBody(String action) {
    return 'Pídele a algún amigo al que le funcione Fortiva que abra Configuración en Fortiva y toque «$action». Luego recibe lo que necesitas desde su teléfono de cualquiera de estas formas.';
  }

  @override
  String get peerReceivePhotograph => 'Fotografiar los códigos de tu amigo';

  @override
  String get peerReceivePhotographNext => 'Fotografiar el siguiente código';

  @override
  String peerReceiveProgress(int have, int total) {
    return '$have de $total códigos leídos';
  }

  @override
  String get peerReceiveFile => 'Abrir el archivo que te envió tu amigo';

  @override
  String get peerReceivePaste => 'Pegar lo que te envió tu amigo';

  @override
  String get peerReceiveNoCode =>
      'No se encontró ningún código en esa foto. Acerca más el teléfono, con todo el código a la vista.';

  @override
  String get peerReceiveRefused =>
      'Fortiva no puede usar eso. Pide a tu amigo que lo envíe de nuevo.';

  @override
  String get peerReceiveNotNewer =>
      'Ya tienes esto, o algo más reciente. Intenta conectarte de nuevo o pídele ayuda a otro amigo.';

  @override
  String get peerReceiveTaken => 'Listo. Toca el botón para conectarte.';

  @override
  String get peerReceiveUnavailable =>
      'Este teléfono no puede hacer eso. Prueba de otra forma.';

  @override
  String get peerReceiveNothingToPaste =>
      'Aún no has copiado nada. Copia lo que te envió tu amigo y vuelve a tocar aquí.';

  @override
  String get peerOfferBody =>
      '¿Sigues sin poder conectarte? Si Fortiva le funciona a algún amigo, puede ayudarte desde su teléfono.';

  @override
  String get peerReceiveAgain =>
      'Ya tienes este código. Pídele a tu amigo que te muestre el siguiente.';

  @override
  String get peerReceivePasteNotOurs =>
      'Lo que copiaste no es de Fortiva. Copia el mensaje completo de tu amigo y vuelve a intentarlo.';

  @override
  String peerReceiveNoPhoto(String action) {
    return 'La cámara no devolvió la foto. Toma la foto con la app de cámara y luego toca «$action».';
  }

  @override
  String get peerReceiveFileHint =>
      'Los archivos de apps de mensajería a veces deben guardarse primero en Descargas.';

  @override
  String get homeTryingBackup =>
      'Ninguna otra opción se conectó. Ahora probamos una red de respaldo.';

  @override
  String get homeConnectedBackup => 'Conectado a través de una red de respaldo';

  @override
  String get backupNetwork => 'RED DE RESPALDO';

  @override
  String get backupNetworkTitle => 'Red de respaldo';

  @override
  String get backupNetworkCaption =>
      'Se usa cuando nada más se conecta. Puede ser más lenta que nuestros servidores.';

  @override
  String get backupNetworkPlace => 'Ubicación elegida automáticamente';

  @override
  String get speedTestStart => 'Iniciar prueba';

  @override
  String get speedTestAgain => 'Probar de nuevo';

  @override
  String get speedTestRunning => 'Probando';

  @override
  String get speedTestIdle => 'Mira qué tan rápida es tu conexión ahora mismo.';

  @override
  String get speedTestPhasePing => 'Comprobando el tiempo de respuesta';

  @override
  String get speedTestPhaseDownload => 'Midiendo la velocidad de descarga';

  @override
  String get speedTestPhaseUpload => 'Midiendo la velocidad de subida';

  @override
  String get speedTestDone => 'Prueba terminada';

  @override
  String get speedTestFailed =>
      'La prueba no pudo terminar. Revisa tu conexión a internet e inténtalo de nuevo.';

  @override
  String get speedTestUnit => 'Mbps';

  @override
  String get ipAddressLabel => 'Dirección IP';

  @override
  String get ipCopied => 'Dirección copiada';

  @override
  String get ipLocation => 'Ubicación';

  @override
  String get ipProvider => 'Proveedor de internet';

  @override
  String get ipOrganization => 'Organización';

  @override
  String get ipTimeZone => 'Zona horaria';

  @override
  String get ipCoordinates => 'Coordenadas';

  @override
  String get ipCheckFailed => 'No se pudo comprobar tu dirección';

  @override
  String get historyAverage => 'Promedio';

  @override
  String get historyRecentDays => 'Últimos días';

  @override
  String yesterdayAt(String time) {
    return 'Ayer a las $time';
  }

  @override
  String dateAt(String date, String time) {
    return '$date a las $time';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String get stageOwn => 'Servidores de Fortiva';

  @override
  String get stageCommunity => 'Servidores de la comunidad';

  @override
  String stageProgress(int n, int total) {
    return 'Etapa $n de $total';
  }

  @override
  String get stageTryingOwn => 'Probando los servidores de Fortiva';

  @override
  String get stageTryingCommunity => 'Probando servidores de la comunidad';

  @override
  String get stageOwnFailedTryingCommunity =>
      'Los servidores de Fortiva no se conectaron aquí. Ahora probamos servidores de la comunidad.';

  @override
  String stageLastWorked(String server) {
    return 'Último servidor que funcionó: $server';
  }

  @override
  String stageTriedBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rutas probadas, bloqueadas aquí',
      one: '$count ruta probada, bloqueada aquí',
    );
    return '$_temp0';
  }

  @override
  String stageTriedFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rutas probadas, ninguna se conectó',
      one: '$count ruta probada, no se conectó',
    );
    return '$_temp0';
  }

  @override
  String get stageNotConnected => 'No se conectó';

  @override
  String get stageConnected => 'Conectado aquí';

  @override
  String get stageSkipped => 'Omitida esta vez';

  @override
  String stageMoreToCheck(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltan $count rutas por probar',
      one: 'Falta $count ruta por probar',
    );
    return '$_temp0';
  }

  @override
  String stageNextTry(String stage, String time) {
    return 'Próximo intento en $time, empezando por $stage';
  }

  @override
  String get searchSlowHint =>
      'Esto puede tardar un minuto o dos. Toca el botón para detener la búsqueda.';

  @override
  String get searchStopped => 'Búsqueda detenida';

  @override
  String get homeConnectedCommunity =>
      'Conectado a través de un servidor de la comunidad';

  @override
  String get stageGettingServers => 'Obteniendo tus servidores';

  @override
  String stageNextTryStarting(String stage) {
    return 'El próximo intento empieza ahora por $stage';
  }
}
