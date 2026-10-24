// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class SPt extends S {
  SPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'FortivaVPN';

  @override
  String get statusDisconnected => 'Desconectado';

  @override
  String get statusConnecting => 'Conectando';

  @override
  String get statusConnected => 'Conectado';

  @override
  String get statusDisconnecting => 'Desconectando';

  @override
  String get statusError => 'Erro';

  @override
  String get statusVerifying => 'Verificando...';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get connectBtn => 'CONECTAR';

  @override
  String get disconnectBtn => 'DESCONECTAR';

  @override
  String get pleaseWait => 'POR FAVOR AGUARDE';

  @override
  String get locationLabel => 'Localização:';

  @override
  String get selectServer => 'Selecionar servidor';

  @override
  String get serverLocation => 'Localização do servidor';

  @override
  String get searchServers => 'Buscar servidores';

  @override
  String get locationsTitle => 'Localizações';

  @override
  String get sortLatency => 'Ordenar: Latência';

  @override
  String get sortAZ => 'Ordenar: A-Z';

  @override
  String get sortedByLatency => 'Ordenado por latência';

  @override
  String get sortedAZ => 'Ordenado A–Z';

  @override
  String get pingAll => 'Pingar todos';

  @override
  String get pinging => 'Pingando...';

  @override
  String get ping => 'Ping';

  @override
  String get stop => 'Parar';

  @override
  String get fastestServer => 'SERVIDOR MAIS RÁPIDO';

  @override
  String get timeout => 'tempo esgotado';

  @override
  String get tabCommunity => 'Comunidade';

  @override
  String get tabFree => 'Grátis';

  @override
  String get tabPremium => 'Premium';

  @override
  String get noCommunityServers => 'Sem servidores comunitários';

  @override
  String get communityLoadFailed => 'Não foi possível carregar esta lista';

  @override
  String get communityRetry => 'Tentar de novo';

  @override
  String get officialTabExplainer =>
      'Mantidos pela Fortiva e sempre online por nossa conta. Compartilhados por todos que usam o app. Comece por aqui.';

  @override
  String get communityTabExplainer =>
      'Opções extras de conexão. A velocidade e a disponibilidade variam.';

  @override
  String get noFreeServers => 'Sem servidores gratuitos';

  @override
  String get noPremiumServers => 'Sem servidores premium';

  @override
  String noResultsFor(String query) {
    return 'Sem resultados para \"$query\"';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get freeBadge => 'GRÁTIS';

  @override
  String get settings => 'Configurações';

  @override
  String get connection => 'Conexão';

  @override
  String get dnsConfiguration => 'Configuração DNS';

  @override
  String get customDns => 'Servidores DNS personalizados';

  @override
  String get about => 'Sobre';

  @override
  String get privacyPolicy => 'Política de Privacidade';

  @override
  String get contactUs => 'Fale Conosco';

  @override
  String get rateOnGooglePlay => 'Avaliar o Fortiva no Google Play';

  @override
  String get website => 'Site';

  @override
  String get copyright => '© 2026 NimusAI';

  @override
  String get version => 'Versão';

  @override
  String get language => 'Idioma';

  @override
  String get languageSubtitle => 'Idioma de exibição do app';

  @override
  String get whatIsDns => 'O que é DNS?';

  @override
  String get dnsExplanation =>
      'DNS (Sistema de Nomes de Domínio) é a lista telefônica da internet. Ele traduz nomes de sites em endereços IP.\n\nPersonalizar seu DNS pode:\n• Melhorar a velocidade de conexão ⚡\n• Aumentar a privacidade 🔒\n• Contornar bloqueios de censura 🌍';

  @override
  String get configuration => 'Configuração';

  @override
  String get primaryDns => 'DNS Primário';

  @override
  String get primaryDnsHint => 'Padrão: 1.1.1.1';

  @override
  String get secondaryDns => 'DNS Secundário (Opcional)';

  @override
  String get secondaryDnsHint => 'Padrão: 8.8.8.8';

  @override
  String get saveConfiguration => 'Salvar Configuração';

  @override
  String get dnsSaved => 'Configuração DNS Salva';

  @override
  String get invalidPrimaryDns => 'Endereço IP do DNS Primário inválido';

  @override
  String get invalidSecondaryDns => 'Endereço IP do DNS Secundário inválido';

  @override
  String get statistics => 'Estatísticas';

  @override
  String get overview => 'VISÃO GERAL';

  @override
  String get connectionsLabel => 'Conexões';

  @override
  String get totalTime => 'Tempo Total';

  @override
  String get dataUsage => 'USO DE DADOS';

  @override
  String get uploaded => 'Enviado';

  @override
  String get downloaded => 'Baixado';

  @override
  String get total => 'Total';

  @override
  String lastUpdated(String date) {
    return 'Última atualização: $date';
  }

  @override
  String today(String time) {
    return 'Hoje às $time';
  }

  @override
  String get yesterday => 'Ontem';

  @override
  String daysAgo(int count) {
    return '$count dias atrás';
  }

  @override
  String get noDataYet => 'Sem dados ainda';

  @override
  String get connectToStart => 'Conecte-se a uma VPN para começar a rastrear';

  @override
  String get errorConnectionFailed => 'Falha na conexão';

  @override
  String get errorServerNotWorking =>
      'Servidor não está funcionando — tente outro';

  @override
  String get errorServerNotForwarding =>
      'Servidor não está encaminhando tráfego';

  @override
  String get errorUnexpected => 'Erro inesperado';

  @override
  String get errorDisconnectionFailed => 'Falha na desconexão';

  @override
  String get errorFailedToRegister => 'Falha no registro do dispositivo';

  @override
  String get ipInformation => 'Informações de IP';

  @override
  String get connectionAnalytics => 'Análise de Conexão';

  @override
  String get recentSessions => 'Sessões Recentes';

  @override
  String get speedTest => 'Teste de Velocidade';

  @override
  String get startTest => 'Iniciar Teste';

  @override
  String get download => 'Download';

  @override
  String get upload => 'Upload';

  @override
  String get testingViaVpn => 'Testando via VPN';

  @override
  String get testingDirect => 'Teste de conexão direta';

  @override
  String get splitTunneling => 'Tunelamento Dividido';

  @override
  String get splitTunnelingDescription =>
      'Escolha categorias de aplicativos que ignoram o túnel VPN.';

  @override
  String get enableSplitTunneling => 'Ativar Tunelamento Dividido';

  @override
  String get splitTunnelActive => 'Apps selecionados ignoram VPN';

  @override
  String get splitTunnelInactive => 'Todo tráfego passa pelo VPN';

  @override
  String get bypassVpnFor => 'Ignorar VPN para';

  @override
  String get tools => 'Ferramentas';

  @override
  String get settingsGeneral => 'Geral';

  @override
  String get shareDiagnosticsTitle => 'Compartilhar diagnósticos de conexão';

  @override
  String get shareDiagnosticsBody =>
      'Envia relatórios de conexão, sua operadora e seu país, o modelo do celular e a versão do Android, os nomes dos sites que você acessa pela VPN com a contagem diária, e se você viu ou tocou nas nossas mensagens, nas ofertas do Premium e no cartão de convite. Nunca vemos as páginas que você abre nem o que você envia.';

  @override
  String get security => 'Segurança';

  @override
  String get privacyDashboard => 'Painel de Privacidade';

  @override
  String get privacyDashboardSubtitle => 'Info IP e proteção contra vazamentos';

  @override
  String get connectionAnalyticsSubtitle => 'Histórico de sessões e gráficos';

  @override
  String get speedTestSubtitle => 'Teste sua velocidade de conexão';

  @override
  String get splitTunnelingSubtitle => 'Roteamento VPN de apps';

  @override
  String get splashTagline => 'Acesso privado, onde você estiver';

  @override
  String get openSourceLicence => 'Licença de código aberto';

  @override
  String get sourceOfferTitle => 'Licença de código aberto';

  @override
  String get sourceOfferBody =>
      'O Fortiva VPN é software livre sob a GNU General Public License v3. Ele é construído sobre o Xray-core e outros projetos de código aberto.\n\nVocê tem direito ao código-fonte completo da versão que instalou. Para pedi-lo, envie um e-mail para admin@fortivavpn.com com a versão do seu aplicativo. Esta oferta vale por três anos a partir da data em que você recebeu esta versão.';

  @override
  String get close => 'Fechar';

  @override
  String get account => 'Conta';

  @override
  String get deleteAccount => 'Excluir conta';

  @override
  String get deleteAccountSubtitle =>
      'Remover este dispositivo e seus dados definitivamente';

  @override
  String get deleteAccountConfirmTitle => 'Excluir sua conta?';

  @override
  String get deleteAccountConfirmBody =>
      'Isso remove o registro do seu dispositivo, qualquer conta Google vinculada, os servidores pessoais criados para você e suas mensagens no chat de suporte. O histórico de conexão neste telefone também é apagado.\n\nNão é possível desfazer. Você pode recomeçar a qualquer momento reabrindo o aplicativo.';

  @override
  String deleteAccountConfirmRetention(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dias',
      one: '$days dia',
    );
    return 'O registro da sua conta é removido imediatamente. Cópias em backups e registros anônimos do servidor são apagados em até $_temp0.';
  }

  @override
  String get deleteAccountConfirmRetentionNoDays =>
      'O registro da sua conta é removido imediatamente. Cópias em backups e registros anônimos do servidor são apagados depois, nos prazos da nossa política de privacidade.';

  @override
  String get deleteAccountCancel => 'Manter minha conta';

  @override
  String get deleteAccountConfirm => 'Excluir';

  @override
  String get deleteAccountInProgress => 'Excluindo sua conta';

  @override
  String get deleteAccountDone => 'Sua conta foi excluída.';

  @override
  String get deleteAccountFailed =>
      'Não foi possível excluir sua conta. Verifique sua conexão e tente novamente.';

  @override
  String get homeTapToConnect => 'Toque para conectar';

  @override
  String get homeChecking => 'Verificando a conexão';

  @override
  String get homePreparing => 'Preparando o seu servidor';

  @override
  String get homeDisconnecting => 'Desconectando';

  @override
  String get homeFindingPath => 'Procurando uma rota';

  @override
  String get diagCheckingInternet => 'Verificando sua internet';

  @override
  String get diagInternationalCut =>
      'A internet internacional está cortada nesta rede';

  @override
  String diagPathRow(String city, int n) {
    return '$city, rota $n';
  }

  @override
  String get diagOpen => 'aberta';

  @override
  String get diagBlocked => 'bloqueada';

  @override
  String get diagSkipped => 'pulada hoje';

  @override
  String diagConnectingThrough(String city) {
    return 'Conectando por $city';
  }

  @override
  String get diagVerifying => 'Verificando o tráfego';

  @override
  String get diagNoInternet => 'Seu celular está sem internet agora.';

  @override
  String get diagCutOff =>
      'Sua rede não alcança a internet internacional agora. Toque para tentar de novo.';

  @override
  String get diagNothingOpen =>
      'Todas as rotas estão bloqueadas agora. Toque para tentar de novo.';

  @override
  String get homeTryingAgain =>
      'Todas as rotas estão bloqueadas agora. Vamos tentar de novo em instantes.';

  @override
  String get homeCutOffTryingAgain =>
      'Sua rede não alcança a internet internacional agora. Vamos tentar de novo em instantes.';

  @override
  String get homeOfflineTryingAgain =>
      'Seu celular está sem internet agora. Vamos tentar de novo em instantes.';

  @override
  String get diagPathFailed =>
      'A rota estava aberta, mas o túnel não foi estabelecido. Toque para tentar de novo.';

  @override
  String get openVpnSettings => 'Abrir configurações de VPN';

  @override
  String get yourServer => 'SEU SERVIDOR';

  @override
  String get yourServerCaption => 'Só seu. Mais ninguém se conecta por ele.';

  @override
  String get ourServer => 'NOSSO SERVIDOR';

  @override
  String get ourServerCaption =>
      'Mantido pela Fortiva e compartilhado com todos. Usado até o seu servidor ficar pronto.';

  @override
  String get communityServer => 'SERVIDOR DA COMUNIDADE';

  @override
  String get communityServerCaption =>
      'Uma opção extra de conexão. Pode parar de funcionar a qualquer momento.';

  @override
  String communityServerNumber(String n) {
    return 'Servidor da comunidade $n';
  }

  @override
  String get myServersTitle => 'Seus servidores';

  @override
  String get myServersExplainer =>
      'Cada aparelho Fortiva recebe o seu próprio servidor em cada local, com credenciais que pertencem apenas a esta instalação. Não é preciso conta.';

  @override
  String get myServersInUse => 'Em uso';

  @override
  String get myServersEmpty => 'Nenhum servidor atribuído ainda';

  @override
  String get myServersRetry => 'Tentar de novo';

  @override
  String get myServersBlockedTitle => 'Você usou os dados de hoje';

  @override
  String get myServersBlockedWait =>
      'A sua franquia renova sozinha. Volte em breve.';

  @override
  String myServersMoved(String place) {
    return 'Agora usando $place';
  }

  @override
  String get copyLink => 'Copiar link';

  @override
  String get linkCopied => 'Link copiado';

  @override
  String quotaUsedToday(String used, String limit) {
    return '$used de $limit usados hoje';
  }

  @override
  String get quotaUsedUp => 'Dados do dia esgotados';

  @override
  String get quotaUnlimited => 'Dados ilimitados';

  @override
  String get quotaDaily => 'Dados diários';

  @override
  String get quotaLimitReached => 'Limite diário atingido';

  @override
  String quotaLeftOf(String left, String limit) {
    return '$left de $limit restantes';
  }

  @override
  String get quotaResetsShortly => 'Renova em breve';

  @override
  String quotaResetsInHours(int hours) {
    return 'Renova em $hours h';
  }

  @override
  String quotaResetsInMinutes(int minutes) {
    return 'Renova em $minutes min';
  }

  @override
  String get myServersSubtitle => 'Os servidores atribuídos a este aparelho';

  @override
  String get sharedServersTitle => 'Servidores compartilhados';

  @override
  String get sharedServersSubtitle => 'Locais públicos, usados como reserva';

  @override
  String get tabOfficial => 'Nossos servidores';

  @override
  String get noOfficialServers => 'Nenhum servidor Fortiva no momento';

  @override
  String get inviteTitle => 'Convidar amigos';

  @override
  String get inviteSubtitle => 'Ganhe mais dados por dia';

  @override
  String get inviteYourCode => 'Seu código de convite';

  @override
  String get inviteShareAction => 'Compartilhar convite';

  @override
  String get inviteCopyAction => 'Copiar código';

  @override
  String get inviteCodeCopied => 'Código copiado';

  @override
  String inviteShareMessage(String code, String url) {
    return 'Uma VPN grátis que funciona bem para mim: Fortiva. Sem cadastro.\nInstale por este link:\n$url\nMeu código de convite: $code';
  }

  @override
  String get inviteHowItWorks => 'Como funciona';

  @override
  String inviteHowItWorksBody(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dias diferentes',
      one: '$days dia',
    );
    return 'Compartilhe seu código. Quando alguém instalar o app, digitar o código e usar a VPN em $_temp0, você ganha $amount nos seus dados diários, para sempre.';
  }

  @override
  String inviteHowItWorksBodyNoAmount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dias diferentes',
      one: '$days dia',
    );
    return 'Compartilhe seu código. Quando alguém instalar o app, digitar o código e usar a VPN em $_temp0, você ganha mais dados por dia, para sempre.';
  }

  @override
  String inviteHowItWorksBodyNoDays(String amount) {
    return 'Compartilhe seu código. Quando alguém instalar o app, digitar o código e usar a VPN por um tempo, você ganha $amount nos seus dados diários, para sempre.';
  }

  @override
  String get inviteHowItWorksBodyNoAmountNoDays =>
      'Compartilhe seu código. Quando alguém instalar o app, digitar o código e usar a VPN por um tempo, você ganha mais dados por dia, para sempre.';

  @override
  String inviteHowItWorksCap(String max) {
    return 'Com convites, você ganha até $max por dia.';
  }

  @override
  String get inviteStatInvited => 'Convidados';

  @override
  String get inviteStatEarning => 'Qualificados';

  @override
  String get inviteStatBonus => 'Dados bônus';

  @override
  String inviteBonusPerDay(String amount) {
    return '+$amount por dia';
  }

  @override
  String get inviteNoBonusYet => 'Ainda sem bônus';

  @override
  String invitePendingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count convites ainda não se qualificaram',
      one: '1 convite ainda não se qualificou',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String inviteJoinedWith(String code) {
    return 'Você entrou com o código $code';
  }

  @override
  String get inviteLoadFailed =>
      'Não foi possível carregar seu código de convite';

  @override
  String get inviteRetry => 'Tentar novamente';

  @override
  String get inviteHaveCodeTitle => 'Tem um código de convite?';

  @override
  String inviteHaveCodeSubtitle(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Digite nas primeiras $hours horas',
      one: 'Digite na primeira hora',
    );
    return '$_temp0';
  }

  @override
  String get inviteHaveCodeSubtitleNoHours => 'Digite logo depois de instalar';

  @override
  String get inviteEnterCodeHint => 'Código de convite';

  @override
  String get inviteApplyAction => 'Aplicar';

  @override
  String get inviteNotNowAction => 'Agora não';

  @override
  String inviteClaimAccepted(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dias diferentes',
      one: '$days dia',
    );
    return 'Convite aceito. Seu amigo ganha dados bônus depois que você usar a VPN em $_temp0.';
  }

  @override
  String get inviteClaimAcceptedNoDays =>
      'Convite aceito. Seu amigo ganha dados bônus depois que você usar a VPN por um tempo.';

  @override
  String get inviteClaimAlready =>
      'Este dispositivo já usou um código de convite';

  @override
  String get inviteClaimRejected =>
      'Esse código não funcionou. Verifique e tente novamente';

  @override
  String get inviteClaimNetwork =>
      'Não foi possível acessar o servidor. Tente novamente';

  @override
  String get inviteCardTitle =>
      'O Fortiva está funcionando bem para você? Envie para seus amigos';

  @override
  String get inviteCardBody =>
      'Envie o link de instalação para seu amigo poder se conectar de graça também.';

  @override
  String inviteCardReward(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Quando seu amigo começar a usar o Fortiva, você ganha $days dias de Premium.',
      one:
          'Quando seu amigo começar a usar o Fortiva, você ganha $days dia de Premium.',
    );
    return '$_temp0';
  }

  @override
  String get inviteCardRewardNoAmount =>
      'Quando seu amigo começar a usar o Fortiva, você ganha Premium de presente.';

  @override
  String get inviteSendTelegram => 'Telegram';

  @override
  String get inviteSendWhatsApp => 'WhatsApp';

  @override
  String get inviteCopyLink => 'Copiar link';

  @override
  String get inviteOtherApps => 'Outros apps';

  @override
  String get inviteLinkCopied => 'Mensagem de convite copiada';

  @override
  String get invitePasteBody =>
      'Copie o código da mensagem do seu amigo e cole aqui.';

  @override
  String get invitePasteAction => 'Colar';

  @override
  String get inviteErrorTooLate =>
      'O prazo para digitar um código de convite neste celular já acabou.';

  @override
  String get inviteErrorUnknown =>
      'Não encontramos esse código. Copie de novo da mensagem do seu amigo.';

  @override
  String get inviteErrorOwnCode =>
      'Este é o seu próprio código. Digite o código do seu amigo.';

  @override
  String get inviteErrorMutual =>
      'Você e seu amigo não podem convidar um ao outro.';

  @override
  String inviteHowItWorksPremium(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Para cada amigo que começar a usar o Fortiva, você também ganha $days dias de Premium.',
      one:
          'Para cada amigo que começar a usar o Fortiva, você também ganha $days dia de Premium.',
    );
    return '$_temp0';
  }

  @override
  String inviteHowItWorksPremiumCap(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Com convites, você pode ganhar até $max dias de Premium.',
      one: 'Com convites, você pode ganhar até $max dia de Premium.',
    );
    return '$_temp0';
  }

  @override
  String get premiumSourceInvite => 'Ganho com seus convites';

  @override
  String quotaBonusIncluded(String amount) {
    return 'inclui $amount de bônus de convite';
  }

  @override
  String get updateTitle => 'Atualização disponível';

  @override
  String get updateRequiredTitle => 'Atualização necessária';

  @override
  String updateBody(String version) {
    return 'O Fortiva $version foi lançado. Atualize para as correções mais recentes.';
  }

  @override
  String get updateRequiredBody =>
      'Esta versão não é mais suportada. Atualize para continuar usando o Fortiva.';

  @override
  String get updateNow => 'Atualizar';

  @override
  String get updateLater => 'Depois';

  @override
  String get updateFromPlay => 'Google Play';

  @override
  String get updateFromTelegram => 'Canal do Telegram';

  @override
  String get updateConnect => 'Conectar';

  @override
  String get updateConnectHint =>
      'Se o Google Play ou o Telegram não abrir, toque primeiro em Conectar.';

  @override
  String get updateConnected =>
      'Você está conectado. Baixe a atualização agora.';

  @override
  String get updateReconnect => 'Não funciona? Reconectar';

  @override
  String get updateDisconnect => 'Desconectar';

  @override
  String get updateDisconnectHint =>
      'Toque em Desconectar para baixar a atualização pela sua internet normal.';

  @override
  String get updateNotCarrying =>
      'Você está conectado, mas nada passa. Tente reconectar, ou toque em Desconectar para usar sua internet normal.';

  @override
  String get diagVerdictNoInternet =>
      'Seu celular está sem conexão com a internet. O Fortiva não consegue conectar até ela voltar.';

  @override
  String get diagVerdictCutOff =>
      'Sua rede não alcança a internet internacional agora. Tente de novo em alguns minutos.';

  @override
  String get diagVerdictNeedsPermission =>
      'O Fortiva não tem permissão para executar uma VPN, ou outro aplicativo de VPN está definido como sempre ativo.';

  @override
  String get diagVerdictServerUnreachable =>
      'Este servidor não pode ser alcançado da sua rede. Ou ele está bloqueado aqui, ou está fora do ar.';

  @override
  String get diagVerdictBlockedTls =>
      'A conexão com este servidor é cortada enquanto está sendo estabelecida. Esse é o comportamento típico de filtragem.';

  @override
  String get diagVerdictThrottled =>
      'O servidor respondeu a todas as verificações e, mesmo assim, o túnel não transportou nada. A conexão está sendo desacelerada.';

  @override
  String get diagCheckInternet => 'Verifique sua internet';

  @override
  String diagTryServer(String server) {
    return 'Nova busca com $server';
  }

  @override
  String get diagTryAnotherServer => 'Tentar outro servidor';

  @override
  String get diagDetails => 'Detalhes';

  @override
  String get diagDetailsHide => 'Ocultar detalhes';

  @override
  String privateDnsWarning(String host) {
    return 'O DNS privado está ativado ($host), por isso alguns sites podem não abrir. Desative o DNS privado nas configurações do telefone.';
  }

  @override
  String get openNetworkSettings => 'Abrir configurações de rede';

  @override
  String testPointStatus(String time, int open, int total) {
    return 'Ponto de teste · última verificação $time · $open de $total rotas abertas';
  }

  @override
  String get messagesTooltip => 'Mensagens';

  @override
  String get inboxTitle => 'Mensagens';

  @override
  String get inboxEmpty => 'Nenhuma mensagem no momento.';

  @override
  String get messageClose => 'Fechar';

  @override
  String get supportTitle => 'Suporte';

  @override
  String get supportTooltip => 'Conversar com o suporte';

  @override
  String get supportAskAction => 'Perguntar ao suporte';

  @override
  String get supportContactSubtitle => 'Converse com a gente no app';

  @override
  String get supportAutomaticNotice =>
      'As respostas são escritas automaticamente e podem estar erradas.';

  @override
  String get supportStaffNotice =>
      'As respostas automáticas estão desligadas no momento. Suas mensagens vão para nossa equipe.';

  @override
  String get supportInputHint => 'Escreva sua pergunta';

  @override
  String get supportInputHintTeam => 'Escreva para nossa equipe';

  @override
  String get supportSend => 'Enviar';

  @override
  String supportQuotaLeft(int remaining, int limit) {
    return 'Perguntas restantes hoje: $remaining de $limit';
  }

  @override
  String supportWaitIn(String time) {
    return 'Você poderá perguntar de novo em $time.';
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
  String get supportNewConversation => 'Nova conversa';

  @override
  String get supportSending => 'Enviando';

  @override
  String get supportNotSent => 'Não enviada. Toque para tentar de novo.';

  @override
  String get supportRateUp => 'Útil';

  @override
  String get supportRateDown => 'Não foi útil';

  @override
  String get supportRatedDown =>
      'Obrigado. Nossa equipe vai analisar esta resposta.';

  @override
  String get supportTeamLabel => 'Equipe Fortiva';

  @override
  String get supportUnavailable => 'O chat não está disponível agora.';

  @override
  String get supportOpenTelegram => 'Fale com a gente no Telegram';

  @override
  String get supportGenericError => 'Algo deu errado. Tente novamente.';

  @override
  String supportCodeTooLong(int max) {
    return 'Sua mensagem é longa demais. Use menos de $max caracteres.';
  }

  @override
  String get supportCodeEmpty => 'Sua mensagem está vazia.';

  @override
  String get supportCodeWaitReply =>
      'Aguarde a resposta da sua última pergunta.';

  @override
  String get supportCodeSlowDown =>
      'Você está enviando mensagens rápido demais. Aguarde um pouco.';

  @override
  String get supportCodeQuotaDay => 'Você já usou todas as perguntas de hoje.';

  @override
  String get supportCodePaused =>
      'As respostas automáticas estão pausadas no momento.';

  @override
  String get supportCodeBusy =>
      'Nosso assistente está ocupado agora. Tente de novo em alguns minutos.';

  @override
  String get supportCodeGreeting =>
      'Olá! Como posso ajudar você com o Fortiva?';

  @override
  String get supportCodeGibberish =>
      'Desculpe, não entendi. Escreva sua pergunta de novo.';

  @override
  String get supportCodeRedacted =>
      'Removemos dados pessoais e links da sua mensagem.';

  @override
  String get supportCodeRedactedEmpty =>
      'Sua mensagem tinha apenas dados pessoais ou links, por isso não foi enviada. Descreva o problema com palavras.';

  @override
  String get supportCodeOffTopic =>
      'Só posso ajudar com perguntas sobre como usar o Fortiva.';

  @override
  String get supportCodeAbuse =>
      'Vamos manter o respeito. Estou aqui para ajudar você com o Fortiva.';

  @override
  String get supportCodeAiUnavailable =>
      'O assistente não conseguiu responder desta vez. Tente de novo daqui a pouco.';

  @override
  String get supportCodeToStaff =>
      'Enviado para nossa equipe. A resposta aparecerá aqui.';

  @override
  String get supportCodeTicketOpened =>
      'Passamos sua pergunta para nossa equipe. A resposta aparecerá aqui.';

  @override
  String get supportCodeNotSent =>
      'Não foi possível enviar esta mensagem. Escreva de novo se ainda precisar de ajuda.';

  @override
  String get supportAssistantSubtitle => 'Assistente de IA';

  @override
  String get supportThinkingReading => 'Lendo sua pergunta';

  @override
  String get supportThinkingSearching => 'Procurando a resposta';

  @override
  String get supportThinkingWriting => 'Escrevendo a resposta';

  @override
  String get supportThinkingStill =>
      'Ainda trabalhando nisso, obrigado por esperar';

  @override
  String get supportSuggestConnect => 'Não consigo conectar';

  @override
  String get supportSuggestData => 'Quanto de dados eu tenho hoje?';

  @override
  String get supportSuggestSlow => 'Minha conexão está lenta';

  @override
  String get supportWithTeam => 'Esta conversa agora está com a nossa equipe.';

  @override
  String get supportTryAgainSoon => 'Tente de novo em alguns minutos.';

  @override
  String supportDurationWholeHours(int hours) {
    return '$hours h';
  }

  @override
  String get supportUnreadReply => 'Nova resposta';

  @override
  String get premiumTitle => 'Premium';

  @override
  String get premiumTileSubtitle => 'Dados ilimitados, sem limite diário';

  @override
  String get premiumTileActive => 'Premium ativo';

  @override
  String get premiumGetUnlimited => 'Ter ilimitado';

  @override
  String get premiumHeadline => 'Tenha dados ilimitados';

  @override
  String get premiumPitch =>
      'O Premium tira o limite diário, então você usa quantos dados quiser até ele acabar.';

  @override
  String get premiumActiveTitle => 'Premium ativo';

  @override
  String premiumActiveUntil(String date) {
    return 'Dados ilimitados até $date';
  }

  @override
  String get premiumActiveNoDate => 'Dados ilimitados';

  @override
  String get premiumRenews => 'Renova automaticamente pelo Google Play';

  @override
  String get premiumSourceKey => 'Ativado com uma chave';

  @override
  String get premiumSourceCrypto => 'Pago com cripto';

  @override
  String get premiumSourceStars => 'Pago com Estrelas do Telegram';

  @override
  String get premiumSourceGooglePlay => 'Pago pelo Google Play';

  @override
  String get premiumSourceManual => 'Um presente da equipe Fortiva';

  @override
  String get premiumYourKey => 'Sua chave';

  @override
  String get premiumKeyHint =>
      'Guarde esta chave. Digite-a em outro celular para levar o Premium para lá.';

  @override
  String premiumKeyMoves(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dias',
      one: '$days dia',
    );
    return 'Uma chave pode passar para outro celular até $count vezes em $_temp0.';
  }

  @override
  String get premiumKeyMovesNoNumber =>
      'Uma chave só pode passar para outro celular um número limitado de vezes.';

  @override
  String get premiumCopy => 'Copiar';

  @override
  String get premiumCopied => 'Copiado';

  @override
  String get premiumChoosePlan => 'Escolha um plano';

  @override
  String premiumPlanDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dias de dados ilimitados',
      one: '$days dia de dados ilimitados',
    );
    return '$_temp0';
  }

  @override
  String get premiumPlanNoDays => 'Dados ilimitados';

  @override
  String get premiumBuy => 'Comprar';

  @override
  String get premiumPlayUnavailable =>
      'O Google Play não está disponível agora. Tente de novo mais tarde.';

  @override
  String get premiumPlayPending =>
      'Seu pagamento está pendente no Google Play. O Premium começa assim que ele for aprovado.';

  @override
  String get premiumPlayConfirming => 'Confirmando sua compra...';

  @override
  String get premiumPlayRetrying =>
      'Seu pagamento foi feito, mas ainda não conseguimos confirmá-lo. Vamos continuar tentando, não precisa pagar de novo.';

  @override
  String get premiumPlayRefused =>
      'Não conseguimos confirmar esta compra. Se você foi cobrado, fale com o suporte.';

  @override
  String get premiumPlayNotAvailable =>
      'O Premium não está disponível neste celular agora. Se você foi cobrado, fale com o suporte.';

  @override
  String get premiumNotAvailable =>
      'O Premium não está disponível neste celular agora.';

  @override
  String get premiumPlayFailed => 'A compra não foi concluída. Tente de novo.';

  @override
  String get premiumNowOn =>
      'O Premium está ativo. Aproveite os dados ilimitados.';

  @override
  String get premiumRestore => 'Restaurar compras';

  @override
  String get premiumRestoreDone => 'Sua compra foi restaurada neste celular.';

  @override
  String get premiumRestoreNone =>
      'Esta conta do Google não tem compras para restaurar.';

  @override
  String get premiumRestoreFailed =>
      'Não foi possível restaurar sua compra. Tente de novo mais tarde.';

  @override
  String premiumRenewsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Cobrado a cada $count dias. Renova automaticamente até você cancelar.',
      one: 'Cobrado todo dia. Renova automaticamente até você cancelar.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Cobrado a cada $count semanas. Renova automaticamente até você cancelar.',
      one: 'Cobrado toda semana. Renova automaticamente até você cancelar.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Cobrado a cada $count meses. Renova automaticamente até você cancelar.',
      one: 'Cobrado todo mês. Renova automaticamente até você cancelar.',
    );
    return '$_temp0';
  }

  @override
  String premiumRenewsYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Cobrado a cada $count anos. Renova automaticamente até você cancelar.',
      one: 'Cobrado todo ano. Renova automaticamente até você cancelar.',
    );
    return '$_temp0';
  }

  @override
  String get premiumRenewsNoPeriod =>
      'Renova automaticamente até você cancelar.';

  @override
  String get premiumPlayCancelNote =>
      'Você pode cancelar quando quiser no Google Play. O Premium continua ativo até o fim do período pago.';

  @override
  String get premiumManageSubscription => 'Gerenciar ou cancelar assinatura';

  @override
  String get premiumCurrentPlan => 'Plano atual';

  @override
  String get premiumPlaySubscribed =>
      'Você já tem uma assinatura do Google Play. Gerencie ou cancele no Google Play.';

  @override
  String get premiumEnterCode => 'Inserir um código';

  @override
  String get premiumNeedsPlayVersion =>
      'Para comprar pelo Google Play, você precisa da versão do Fortiva do Google Play.';

  @override
  String get premiumOff => 'O Premium não está à venda agora.';

  @override
  String get premiumLoadFailed =>
      'Não foi possível carregar o Premium. Verifique sua conexão e tente de novo.';

  @override
  String get premiumRetry => 'Tentar de novo';

  @override
  String premiumPriceUsdt(String price) {
    return '$price USDT';
  }

  @override
  String premiumPriceStars(String stars) {
    return '$stars Estrelas do Telegram';
  }

  @override
  String get premiumPayCrypto => 'Pagar com cripto';

  @override
  String get premiumTelegramTitle => 'Pagar no Telegram';

  @override
  String get premiumTelegramBody =>
      'Pague com Estrelas do Telegram no nosso bot. Você recebe uma chave, e o Premium começa na hora neste celular.';

  @override
  String get premiumTelegramButton => 'Comprar no Telegram';

  @override
  String get premiumTelegramFailed =>
      'Não foi possível abrir o Telegram. Tente de novo.';

  @override
  String get checkoutTitle => 'Pagar com cripto';

  @override
  String get checkoutChooseNetwork => 'Escolha a rede de onde você vai enviar';

  @override
  String get checkoutContinue => 'Continuar';

  @override
  String get checkoutSendExactly => 'Envie exatamente este valor';

  @override
  String get checkoutNetwork => 'Rede';

  @override
  String get checkoutAddress => 'Para este endereço';

  @override
  String get checkoutMemo => 'Com este memo';

  @override
  String get checkoutMemoWarning =>
      'Coloque este memo na transferência, senão não conseguimos ligar o pagamento a você.';

  @override
  String get checkoutExactWarning =>
      'Envie o valor exato e só nesta rede. Um valor ou uma rede diferente pode não chegar até nós.';

  @override
  String checkoutTimeLeft(String time) {
    return 'Tempo restante: $time';
  }

  @override
  String get checkoutWaiting =>
      'Aguardando seu pagamento. Esta página se atualiza sozinha.';

  @override
  String get checkoutPaidTitle => 'Pagamento recebido';

  @override
  String get checkoutPaidKeyOnly =>
      'Sua chave está pronta. Digite-a no celular que deve receber o Premium.';

  @override
  String get checkoutDone => 'Concluir';

  @override
  String get checkoutExpired =>
      'Este pedido expirou. Se você já pagou, fale com o suporte.';

  @override
  String get checkoutUnderpaid =>
      'Recebemos menos que o valor total. Fale com o suporte e informe este número de pedido:';

  @override
  String get checkoutCanceled => 'Este pedido foi cancelado.';

  @override
  String get checkoutStartAgain => 'Começar de novo';

  @override
  String get checkoutUnavailable =>
      'O pagamento com cripto não está disponível agora.';

  @override
  String get checkoutTooManyOpen =>
      'Você tem muitos pedidos sem pagamento. Pague um deles ou espere que expirem.';

  @override
  String get checkoutUnknownPlan =>
      'Este plano não está mais à venda. Volte e escolha outro.';

  @override
  String get checkoutFailed =>
      'Não foi possível iniciar o pagamento. Verifique sua conexão e tente de novo.';

  @override
  String get redeemTitle => 'Inserir um código';

  @override
  String get redeemSubtitle => 'Uma chave Premium ou um código de presente';

  @override
  String get redeemHint => 'Código';

  @override
  String get redeemApply => 'Aplicar';

  @override
  String get redeemCancel => 'Cancelar';

  @override
  String get redeemInvalid =>
      'Isso não parece um código. Verifique e tente de novo.';

  @override
  String get redeemUnknown =>
      'Não conhecemos este código. Verifique e tente de novo.';

  @override
  String get redeemExpired => 'Este código expirou.';

  @override
  String get redeemRevoked => 'Este código não é mais válido.';

  @override
  String get redeemMovedTooOften =>
      'Esta chave mudou de celular vezes demais nos últimos tempos. Tente de novo mais tarde.';

  @override
  String get redeemExhausted => 'Este código já foi todo usado.';

  @override
  String get redeemAlreadyUsed => 'Este celular já usou este código.';

  @override
  String get redeemUnmetered =>
      'Este celular já tem dados ilimitados e não precisa deste código.';

  @override
  String get redeemRateLimited =>
      'Muitas tentativas. Espere um pouco e tente de novo.';

  @override
  String get redeemUnavailable =>
      'Isso não está disponível agora. Tente de novo mais tarde.';

  @override
  String get redeemNetwork =>
      'Não foi possível falar com o servidor. Verifique sua conexão e tente de novo.';

  @override
  String get redeemFailed =>
      'Esse código não funcionou. Verifique e tente de novo.';

  @override
  String get redeemMoved => 'O Premium passou para este celular.';

  @override
  String redeemPromo(String amount) {
    return 'Código aceito. $amount de dados extras adicionados.';
  }

  @override
  String get redeemPromoNoAmount => 'Código aceito. Dados extras adicionados.';

  @override
  String get tvScanTitle => 'Abrir no celular';

  @override
  String get tvScanBody => 'Aponte a câmera do celular para este código.';

  @override
  String get refresh => 'Atualizar';

  @override
  String get premiumNotNow => 'Agora não';

  @override
  String get premiumLimitSheetTitle => 'Os dados de hoje acabaram';

  @override
  String get premiumLimitWait => 'Esperar a renovação';

  @override
  String get premiumLimitInvite => 'Convide amigos para ter mais dados';

  @override
  String get premiumNoDailyLimit => 'O Premium não tem limite diário.';

  @override
  String get premiumCalmTitle => 'Quer ficar sem limite diário?';

  @override
  String get premiumCalmBody =>
      'O Premium dá a você dados ilimitados. Seu plano gratuito continua como está.';

  @override
  String get premiumNextStepTitle => 'O próximo passo é o Premium';

  @override
  String get premiumNextStepBody =>
      'Você já tem o máximo de dados grátis. O Premium não tem limite diário.';

  @override
  String get premiumLockedTag => 'Premium';

  @override
  String premiumLockedTitle(String place) {
    return 'Desbloqueie $place com o Premium';
  }

  @override
  String get premiumLockedBody =>
      'Este local é do Premium. Seus servidores gratuitos continuam os mesmos.';

  @override
  String get premiumHeadlineLimit => 'Sem limite diário';

  @override
  String premiumHeadlineLocked(String place) {
    return 'Desbloqueie $place com o Premium';
  }

  @override
  String get premiumFreeStays =>
      'O plano gratuito continua funcionando sem o Premium.';

  @override
  String premiumEndsOn(String date) {
    return 'O Premium termina em $date';
  }

  @override
  String get premiumRenewBody =>
      'Renove para manter os dados ilimitados. A renovação soma tempo à sua data de término atual.';

  @override
  String premiumEndedOn(String date) {
    return 'O Premium terminou em $date. Seu plano gratuito voltou.';
  }

  @override
  String get premiumRenew => 'Renovar';

  @override
  String get noticeChannelName => 'Mensagens da Fortiva';

  @override
  String get noticeChannelDescription =>
      'Novidades e mensagens da equipe Fortiva';

  @override
  String get noticesSettingTitle => 'Notificações';

  @override
  String get noticesSettingOn =>
      'Ativadas. As mensagens da equipe Fortiva podem chegar mesmo com o app fechado.';

  @override
  String get noticesSettingOff =>
      'Desativadas. Ative-as para receber as mensagens da equipe Fortiva mesmo com o app fechado.';

  @override
  String get noticesOffCard =>
      'Ative as notificações para receber as mensagens da equipe Fortiva mesmo com o app fechado.';

  @override
  String get noticesTurnOn => 'Ativar';

  @override
  String get backgroundCard =>
      'Seu celular pode segurar as mensagens da equipe Fortiva enquanto o app está fechado. Permita que o Fortiva funcione em segundo plano para recebê-las.';

  @override
  String get backgroundHint =>
      'Na próxima tela, escolha o Fortiva (se não aparecer, mostre todos os apps). Depois defina o uso da bateria como Sem restrições, ou permita que ele inicie e funcione em segundo plano.';

  @override
  String get backgroundAllow => 'Permitir';

  @override
  String get backgroundNotNow => 'Agora não';

  @override
  String get backgroundSettingTitle => 'Mensagens com o app fechado';

  @override
  String get backgroundSettingSubtitle =>
      'Permita que o Fortiva funcione em segundo plano para receber as mensagens mesmo com o app fechado.';

  @override
  String get backgroundCardData =>
      'A Economia de dados do seu celular pode bloquear as mensagens da equipe Fortiva enquanto o app está fechado.';

  @override
  String get backgroundHintData => 'Na próxima tela, ative Dados irrestritos.';

  @override
  String get apnGuideTitle => 'Uma conexão mais estável neste chip';

  @override
  String get apnGuideBody =>
      'Seu telefone não está usando IPv6 neste chip. Ativar ajuda o Fortiva a continuar conectado.';

  @override
  String get apnGuideShowMe => 'Mostre como';

  @override
  String get apnGuideNotNow => 'Agora não';

  @override
  String get apnGuideSheetTitle => 'Ative o IPv6 neste chip';

  @override
  String apnGuideStepOpen(String button) {
    return 'Toque em \"$button\" (ou vá em Configurações > Conexões > Redes móveis > Nomes de ponto de acesso).';
  }

  @override
  String apnGuideStepAccessPoint(String apn) {
    return 'Toque no ponto de acesso em uso ($apn).';
  }

  @override
  String get apnGuideStepAccessPointAny => 'Toque no ponto de acesso em uso.';

  @override
  String get apnGuideStepProtocol =>
      'Toque em \"Protocolo APN\" e escolha \"IPv4/IPv6\".';

  @override
  String get apnGuideStepSave =>
      'Salve (no Samsung: menu de três pontos e depois \"Salvar\").';

  @override
  String get apnGuideStepRestart => 'Desative os dados móveis e ative de novo.';

  @override
  String get apnGuideUndo =>
      'Se os dados móveis pararem de funcionar, volte o protocolo APN para IPv4.';

  @override
  String get apnGuideOpenSettings => 'Abrir configurações de APN';

  @override
  String get homeStallSearching =>
      'A conexão parou de funcionar. Procurando outra rota.';

  @override
  String get homeStalled => 'Conectado, mas nenhum dado está passando';

  @override
  String get peerShareTitle => 'Ajudar amigos a se conectar';

  @override
  String get peerShareSubtitle =>
      'Passe ao celular do seu amigo o que o Fortiva precisa';

  @override
  String get peerShareBody =>
      'Se o Fortiva do seu amigo não conectar, o celular dele pode pegar do seu o que precisa. Isso funciona sem internet.';

  @override
  String peerShareSteps(String action) {
    return 'No celular dele, abra Configurações no Fortiva e toque em \"$action\". Depois mostre estes códigos um por um ou envie tudo para ele.';
  }

  @override
  String get peerShareLoading => 'Buscando a cópia mais recente';

  @override
  String get peerShareNothing =>
      'Este celular não tem nada recente para passar. Tente de novo mais tarde.';

  @override
  String peerShareCodeOf(int current, int total) {
    return 'Código $current de $total';
  }

  @override
  String get peerSharePrevious => 'Voltar';

  @override
  String get peerShareNext => 'Próximo';

  @override
  String get peerShareCopy => 'Copiar';

  @override
  String get peerShareSend => 'Enviar';

  @override
  String get peerShareCopied => 'Copiado. Cole na conversa com seu amigo.';

  @override
  String get peerReceiveTitle => 'Pedir ajuda a amigos';

  @override
  String get peerReceiveSubtitle => 'Se não der para conectar de outro jeito';

  @override
  String peerReceiveBody(String action) {
    return 'Peça a algum amigo com o Fortiva funcionando para abrir Configurações no Fortiva e tocar em \"$action\". Depois receba tudo do celular dele por qualquer uma destas formas.';
  }

  @override
  String get peerReceivePhotograph => 'Fotografar os códigos do seu amigo';

  @override
  String get peerReceivePhotographNext => 'Fotografar o próximo código';

  @override
  String peerReceiveProgress(int have, int total) {
    return '$have de $total códigos lidos';
  }

  @override
  String get peerReceiveFile => 'Abrir o arquivo que seu amigo enviou';

  @override
  String get peerReceivePaste => 'Colar o que seu amigo enviou';

  @override
  String get peerReceiveNoCode =>
      'Nenhum código encontrado nessa foto. Aproxime o celular, com o código inteiro visível.';

  @override
  String get peerReceiveRefused =>
      'O Fortiva não consegue usar isso. Peça ao seu amigo para enviar de novo.';

  @override
  String get peerReceiveNotNewer =>
      'Você já tem isso, ou algo mais recente. Tente conectar de novo ou peça ajuda a outro amigo.';

  @override
  String get peerReceiveTaken => 'Pronto. Toque no botão para conectar.';

  @override
  String get peerReceiveUnavailable =>
      'Este celular não consegue fazer isso. Tente de outro jeito.';

  @override
  String get peerReceiveNothingToPaste =>
      'Nada copiado ainda. Copie o que seu amigo enviou e toque aqui de novo.';

  @override
  String get peerOfferBody =>
      'Ainda não conecta? Algum amigo com o Fortiva funcionando pode ajudar pelo celular dele.';

  @override
  String get peerReceiveAgain =>
      'Você já tem este código. Peça ao seu amigo para mostrar o próximo.';

  @override
  String get peerReceivePasteNotOurs =>
      'O que você copiou não é do Fortiva. Copie a mensagem inteira do seu amigo e tente de novo.';

  @override
  String peerReceiveNoPhoto(String action) {
    return 'A câmera não devolveu a foto. Tire a foto com o app de câmera e depois toque em \"$action\".';
  }

  @override
  String get peerReceiveFileHint =>
      'Arquivos de apps de mensagem podem precisar ser salvos primeiro em Downloads.';

  @override
  String get homeTryingBackup =>
      'Nenhuma outra opção conectou. Agora vamos tentar uma rede reserva.';

  @override
  String get homeConnectedBackup => 'Conectado por uma rede reserva';

  @override
  String get backupNetwork => 'REDE RESERVA';

  @override
  String get backupNetworkTitle => 'Rede reserva';

  @override
  String get backupNetworkCaption =>
      'Usada quando nada mais conecta. Pode ser mais lenta que nossos servidores.';

  @override
  String get backupNetworkPlace => 'Local escolhido automaticamente';

  @override
  String get speedTestStart => 'Iniciar teste';

  @override
  String get speedTestAgain => 'Testar de novo';

  @override
  String get speedTestRunning => 'Testando';

  @override
  String get speedTestIdle => 'Veja a velocidade da sua conexão agora.';

  @override
  String get speedTestPhasePing => 'Verificando o tempo de resposta';

  @override
  String get speedTestPhaseDownload => 'Medindo a velocidade de download';

  @override
  String get speedTestPhaseUpload => 'Medindo a velocidade de upload';

  @override
  String get speedTestDone => 'Teste concluído';

  @override
  String get speedTestFailed =>
      'O teste não terminou. Verifique sua internet e tente de novo.';

  @override
  String get speedTestUnit => 'Mbps';

  @override
  String get ipAddressLabel => 'Endereço IP';

  @override
  String get ipCopied => 'Endereço copiado';

  @override
  String get ipLocation => 'Local';

  @override
  String get ipProvider => 'Provedor de internet';

  @override
  String get ipOrganization => 'Organização';

  @override
  String get ipTimeZone => 'Fuso horário';

  @override
  String get ipCoordinates => 'Coordenadas';

  @override
  String get ipCheckFailed => 'Não foi possível verificar seu endereço';

  @override
  String get historyAverage => 'Média';

  @override
  String get historyRecentDays => 'Últimos dias';

  @override
  String yesterdayAt(String time) {
    return 'Ontem às $time';
  }

  @override
  String dateAt(String date, String time) {
    return '$date às $time';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String get stageOwn => 'Servidores da Fortiva';

  @override
  String get stageCommunity => 'Servidores da comunidade';

  @override
  String stageProgress(int n, int total) {
    return 'Etapa $n de $total';
  }

  @override
  String get stageTryingOwn => 'Tentando os servidores da Fortiva';

  @override
  String get stageTryingCommunity => 'Tentando servidores da comunidade';

  @override
  String get stageOwnFailedTryingCommunity =>
      'Os servidores da Fortiva não conectaram aqui. Agora vamos tentar servidores da comunidade.';

  @override
  String stageLastWorked(String server) {
    return 'Último servidor que funcionou: $server';
  }

  @override
  String stageTriedBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rotas testadas, bloqueadas aqui',
      one: '$count rota testada, bloqueada aqui',
    );
    return '$_temp0';
  }

  @override
  String stageTriedFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rotas testadas, nenhuma conectou',
      one: '$count rota testada, não conectou',
    );
    return '$_temp0';
  }

  @override
  String get stageNotConnected => 'Não conectou';

  @override
  String get stageConnected => 'Conectado aqui';

  @override
  String get stageSkipped => 'Pulada desta vez';

  @override
  String stageMoreToCheck(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltam verificar $count rotas',
      one: 'Falta verificar $count rota',
    );
    return '$_temp0';
  }

  @override
  String stageNextTry(String stage, String time) {
    return 'Próxima tentativa em $time, começando por $stage';
  }

  @override
  String get searchSlowHint =>
      'Isso pode levar um ou dois minutos. Toque no botão para parar a busca.';

  @override
  String get searchStopped => 'Busca interrompida';

  @override
  String get homeConnectedCommunity =>
      'Conectado por um servidor da comunidade';

  @override
  String get stageGettingServers => 'Obtendo os seus servidores';

  @override
  String stageNextTryStarting(String stage) {
    return 'A próxima tentativa começa agora por $stage';
  }
}
