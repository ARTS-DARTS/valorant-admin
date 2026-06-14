// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appSubtitle => 'Lineups interativos para todos';

  @override
  String get tabMaps => 'Mapas';

  @override
  String get tabFavorites => 'Favoritos';

  @override
  String get tabCollections => 'Coleções';

  @override
  String get tabProfile => 'Perfil';

  @override
  String get cancel => 'Cancelar';

  @override
  String get ok => 'OK';

  @override
  String get or => 'ou';

  @override
  String get back => '← Voltar';

  @override
  String get continueBtn => 'CONTINUAR';

  @override
  String get start => 'COMEÇAR';

  @override
  String get comingSoon => 'Em breve';

  @override
  String get noInternet => 'Sem conexão com a internet';

  @override
  String get errorOccurred => 'Ocorreu um erro. Tente novamente mais tarde';

  @override
  String get connectionError => 'Erro de conexão. Verifique sua internet.';

  @override
  String get welcome => 'Bem-vindo!';

  @override
  String get loginToAccount => 'Entrar na conta';

  @override
  String get signIn => 'ENTRAR';

  @override
  String get register => 'REGISTRAR';

  @override
  String get nickname => 'Apelido';

  @override
  String get password => 'Senha';

  @override
  String get email => 'E-mail';

  @override
  String get signInWithGoogle => 'Entrar com Google';

  @override
  String get enterNickname => 'Insira seu apelido';

  @override
  String get enterPassword => 'Insira sua senha';

  @override
  String get userNotFound => 'Usuário com este apelido não encontrado';

  @override
  String get wrongPassword => 'Senha incorreta';

  @override
  String get loginFailed => 'Não foi possível entrar. Tente mais tarde';

  @override
  String get googleLoginFailed =>
      'Não foi possível entrar com Google. Tente novamente';

  @override
  String get chooseAppTheme => 'Escolha o tema do app';

  @override
  String get canChangeInProfile => 'Pode ser alterado no perfil depois';

  @override
  String get createNicknameDesc => 'Crie um apelido único para começar';

  @override
  String get checkingNickname => 'Verificando apelido...';

  @override
  String get nicknameFree => 'Apelido disponível!';

  @override
  String get nicknameTaken => 'Apelido já em uso';

  @override
  String get mustAcceptTerms => 'Você deve aceitar os Termos de Serviço';

  @override
  String get nameRules =>
      'O nome deve ter 2–20 caracteres.\nApenas letras, números, _ e -';

  @override
  String get nameTaken => 'Este nome já está em uso. Tente outro!';

  @override
  String get nameCheckError => 'Erro ao verificar nome. Sem conexão?';

  @override
  String get nameHint =>
      '• De 2 a 20 caracteres\n• Letras, números, _ e -\n• Único — ninguém pode pegar';

  @override
  String get iAgreePrefix => 'Li e aceito os ';

  @override
  String get termsOfService => 'Termos de Serviço';

  @override
  String get changeTheme => '← Mudar tema';

  @override
  String get createPassword => 'Criar senha';

  @override
  String get passwordNeeded => 'Você precisará dela para entrar';

  @override
  String get passwordHint => 'Senha (mínimo 6 caracteres)';

  @override
  String get repeatPassword => 'Repita a senha';

  @override
  String get passwordMinSix => 'A senha deve ter pelo menos 6 caracteres';

  @override
  String get passwordsMismatch => 'As senhas não coincidem';

  @override
  String get accountCreationFailed =>
      'Não foi possível criar a conta. Tente mais tarde';

  @override
  String get passwordTooSimple => 'Senha muito simples. Mínimo 6 caracteres';

  @override
  String get emailAlreadyInUse => 'Este e-mail já está em uso';

  @override
  String get suggestLineup => 'Sugerir lineup';

  @override
  String get newsTooltip => 'Notícias';

  @override
  String get ratingMapPool => 'POOL DE MAPAS RANKED';

  @override
  String get otherMaps => 'OUTROS MAPAS';

  @override
  String get categoryLineups => 'Lineups';

  @override
  String get categoryLineupsDesc => 'Surpreenda o inimigo!';

  @override
  String get categoryCombo => 'Combo';

  @override
  String get categoryComboDesc => 'Ótimos combos de agentes!';

  @override
  String get categorySmoky => 'Fumaças';

  @override
  String get categorySmokyDesc =>
      'Aprenda as melhores fumaças para seus agentes!';

  @override
  String get categoryDefense => 'Defesa';

  @override
  String get categoryDefenseDesc =>
      'Não deixe o inimigo tomar o site facilmente!';

  @override
  String get noLineupsYet =>
      'Ainda não há lineups, mas serão adicionados em breve!';

  @override
  String lineupCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lineups',
      one: '$count lineup',
      zero: 'Sem lineups',
    );
    return '$_temp0';
  }

  @override
  String get exclusiveAccessActive => 'Acesso exclusivo ativo por 1 hora';

  @override
  String patchLabel(String patch) {
    return 'Patch $patch';
  }

  @override
  String get accountDeleted => 'Conta excluída';

  @override
  String get accountDeletedDesc =>
      'Todos os dados excluídos. Você pode criar uma nova conta.';

  @override
  String get mainMenu => 'MENU PRINCIPAL';

  @override
  String get profileTitle => 'PERFIL';

  @override
  String get topAuthors => 'Melhores autores';

  @override
  String get signOutDialogTitle => 'Sair?';

  @override
  String get signOutDialogMessage =>
      'Você precisará do apelido e senha para entrar novamente.';

  @override
  String get signOutBtn => 'Sair';

  @override
  String get deleteAccountTitle => 'Excluir conta?';

  @override
  String get deleteAccountIrreversible => 'Esta ação é irreversível!';

  @override
  String get deleteAccountContent =>
      'Serão excluídos:\n• Seu apelido\n• Nível e progresso\n• Todos os lineups pendentes\n\nLineups aprovados permanecerão.';

  @override
  String get deleteForever => 'Excluir definitivamente';

  @override
  String get linkEmailPassword => 'Vincular e-mail e senha';

  @override
  String get linkEmailDesc =>
      'Vincule e-mail e senha à sua conta Google para entrar de qualquer forma.';

  @override
  String get newPassword => 'Nova senha';

  @override
  String get fillAllFields => 'Preencha todos os campos';

  @override
  String get enterValidEmail => 'Insira um e-mail válido';

  @override
  String get passwordMinSixSymbols => 'Senha — mínimo 6 caracteres';

  @override
  String get emailPasswordLinked => 'E-mail e senha vinculados ✅';

  @override
  String get emailAlreadyUsedByOther =>
      'Este e-mail já é usado por outra conta';

  @override
  String get emailAlreadyLinked =>
      'Este e-mail já está vinculado a outra conta';

  @override
  String get changePassword => 'Alterar senha';

  @override
  String get currentPassword => 'Senha atual';

  @override
  String get repeatNewPassword => 'Repita a nova senha';

  @override
  String get newPasswordMinSix =>
      'A nova senha deve ter pelo menos 6 caracteres';

  @override
  String get passwordChanged => 'Senha alterada ✅';

  @override
  String get currentPasswordWrong => 'Senha atual incorreta';

  @override
  String get appTheme => 'Tema do app';

  @override
  String approvedCount(int count) {
    return 'Aprovados: $count';
  }

  @override
  String toNextLevel(String name, int count) {
    return 'Para $name: $count';
  }

  @override
  String get maximum => 'MÁXIMO';

  @override
  String get levelPrivileges => 'Privilégios de nível';

  @override
  String cooldownMinutes(int minutes) {
    return 'Espera: $minutes min';
  }

  @override
  String borderColor(String name) {
    return 'Cor da borda: $name';
  }

  @override
  String get animatedProfile => 'Perfil animado';

  @override
  String get topAuthorPosition => 'Posição nos melhores autores';

  @override
  String get allLevels => 'Todos os níveis';

  @override
  String get currentLevel => 'Atual';

  @override
  String levelRequirements(int lineups, int cd) {
    return '$lineups lineups • CD ${cd}m';
  }

  @override
  String get aboutApp => 'Sobre o app';

  @override
  String get aboutAppContent =>
      'App gratuito com lineups interativos para Valorant.\n\nNão é afiliado à Riot Games.';

  @override
  String get feedback => 'Feedback';

  @override
  String get viewTutorial => 'Ver tutorial';

  @override
  String get signOutMenuTitle => 'Sair da conta';

  @override
  String get dangerZone => 'Zona de perigo';

  @override
  String get dangerZoneDesc =>
      'Excluir conta é irreversível. Todo o progresso e nível serão perdidos.';

  @override
  String get deleteMyAccount => 'EXCLUIR MINHA CONTA';

  @override
  String get notifications => 'Notificações';

  @override
  String get noNotifications => 'Sem notificações';

  @override
  String nextLineupIn(int minutes) {
    return 'Próximo lineup em $minutes min.';
  }

  @override
  String get approvedStat => 'Aprovado';

  @override
  String get totalStat => 'Total';

  @override
  String get cooldownStat => 'CD';

  @override
  String newCount(int count) {
    return '$count novos';
  }

  @override
  String get link => 'Vincular';

  @override
  String get change => 'Alterar';

  @override
  String get defaultPlayer => 'Jogador';

  @override
  String get favorites => 'Favoritos';

  @override
  String get addToCollection => 'Adicionar à coleção';

  @override
  String get removeFromFavorites => 'Remover dos favoritos';

  @override
  String get addToFavorites => 'Adicionar aos favoritos';

  @override
  String get lineupFrom => 'Lineup de:';

  @override
  String get description => 'Descrição';

  @override
  String get screenshots => 'Capturas de tela';

  @override
  String get possiblyOutdated =>
      'Possivelmente desatualizado — usuários relatam imprecisões';

  @override
  String get isRelevant => 'Relevante?';

  @override
  String get needLevel2 => 'Nível 2 necessário';

  @override
  String get loginRequired => 'Entre na conta';

  @override
  String get votingFromLevel2 =>
      'Votar está disponível a partir do nível 2.\n\nMas você pode assistir um anúncio — e seu voto contará!';

  @override
  String get howToGetLevel2 => 'Como obter nível 2? →';

  @override
  String get loginToVote => 'Entre para votar.';

  @override
  String get watchAd => '📺 Assistir anúncio';

  @override
  String get yourVote => 'Seu voto';

  @override
  String get isLineupRelevant => 'O lineup é relevante?';

  @override
  String get outdated => 'Desatualizado';

  @override
  String get relevant => 'Relevante';

  @override
  String get authorProfileUnavailable => 'Perfil do autor indisponível';

  @override
  String get alreadyVoted => 'Você já votou neste lineup';

  @override
  String get adLoading => 'Anúncio carregando, tente em um segundo...';

  @override
  String get voteAccepted => '✅ Voto registrado!';

  @override
  String get voteSaveError => 'Erro ao salvar voto';

  @override
  String get watchAdFull => 'Assista o anúncio até o fim';

  @override
  String get adUnavailable => 'Anúncio indisponível, tente mais tarde';

  @override
  String get watchAdForAccess =>
      'Assista o anúncio até o fim para obter acesso';

  @override
  String get adLabel => '📺 anúncio';

  @override
  String downloadingPercent(String percent) {
    return 'Carregando $percent%...';
  }

  @override
  String get loadingAd => 'Carregando anúncio...';

  @override
  String get savingVideo => 'Salvando vídeo...';

  @override
  String get savedOffline => 'Salvo — disponível offline';

  @override
  String get onlineOnly => 'Somente online';

  @override
  String get saveOffline => 'Salvar offline';

  @override
  String get videoSaved => 'Vídeo salvo';

  @override
  String get videoLoadError => 'Não foi possível carregar o vídeo';

  @override
  String get videoComingSoon => 'Vídeo em breve';

  @override
  String get videoSavedSuccess => '✅ Vídeo salvo — disponível offline!';

  @override
  String get downloadError => 'Erro de download, tente novamente';

  @override
  String get needExclusiveForLike => 'Acesso exclusivo necessário para curtir';

  @override
  String get exclusiveLineup => 'Lineup exclusivo';

  @override
  String get watchAdForExclusive =>
      'Assista um anúncio para desbloquear todos os lineups exclusivos por 1 hora';

  @override
  String get watchAdAccessBtn => '▶ Assistir anúncio → acesso por 1 hora';

  @override
  String get watchAdForSave =>
      'Assista o anúncio até o fim para salvar o vídeo';

  @override
  String get thanksForAd => 'Obrigado por assistir o anúncio!';

  @override
  String get adHelpsUs => 'Isso nos ajuda a desenvolver o app 💪';

  @override
  String patchVersion(String version) {
    return 'Patch $version';
  }

  @override
  String get difficultyEasy => 'Fácil';

  @override
  String get difficultyMedium => 'Médio';

  @override
  String get difficultyHard => 'Difícil';

  @override
  String screenshotN(int n) {
    return 'Captura $n';
  }

  @override
  String get exclusiveTag => '⭐ EXCLUSIVO';

  @override
  String get howToGetLevel2Title => 'Como obter nível 2?';

  @override
  String get xpDesc =>
      'Publique lineups no app — você ganha XP por cada um. Acumule XP suficiente e seu nível aumentará.';

  @override
  String get lineupRequirementsTitle => '📋 Requisitos de lineup';

  @override
  String get gotItWillPost => 'Entendi, vou publicar!';

  @override
  String get tabMolly => 'Mollies';

  @override
  String get tabReveal => 'Reveal';

  @override
  String get tabSmoky => 'Fumaças';

  @override
  String get timingsSectionTitle => '⏱ Timings';

  @override
  String get searchLineups => 'Buscar lineups...';

  @override
  String get nothingFound => 'Nada encontrado 🔍';

  @override
  String get language => 'Idioma';

  @override
  String get languageTitle => 'Language / Язык';

  @override
  String get favoritesLoadError =>
      'Não foi possível carregar os dados. Verifique sua internet e tente novamente';

  @override
  String get favoritesEmpty => 'Sem lineups salvos';

  @override
  String get favoritesEmptyDesc =>
      'Toque no ícone de favorito em qualquer lineup para salvar';

  @override
  String get feedbackTitle => 'FEEDBACK';

  @override
  String get feedbackSendTab => 'Enviar';

  @override
  String get feedbackMyMessages => 'Minhas mensagens';
}
