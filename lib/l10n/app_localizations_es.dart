// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appSubtitle => 'Lineups interactivos para todos';

  @override
  String get tabMaps => 'Mapas';

  @override
  String get tabFavorites => 'Favoritos';

  @override
  String get tabCollections => 'Colecciones';

  @override
  String get tabProfile => 'Perfil';

  @override
  String get cancel => 'Cancelar';

  @override
  String get ok => 'Aceptar';

  @override
  String get or => 'o';

  @override
  String get back => '← Atrás';

  @override
  String get continueBtn => 'CONTINUAR';

  @override
  String get start => 'COMENZAR';

  @override
  String get comingSoon => 'Próximamente';

  @override
  String get noInternet => 'Sin conexión a internet';

  @override
  String get errorOccurred => 'Ocurrió un error. Inténtalo más tarde';

  @override
  String get connectionError => 'Error de conexión. Verifica tu internet.';

  @override
  String get welcome => '¡Bienvenido!';

  @override
  String get loginToAccount => 'Inicia sesión';

  @override
  String get signIn => 'INICIAR SESIÓN';

  @override
  String get register => 'REGISTRO';

  @override
  String get nickname => 'Apodo';

  @override
  String get password => 'Contraseña';

  @override
  String get email => 'Correo';

  @override
  String get signInWithGoogle => 'Iniciar sesión con Google';

  @override
  String get enterNickname => 'Introduce tu apodo';

  @override
  String get enterPassword => 'Introduce tu contraseña';

  @override
  String get userNotFound => 'Usuario con este apodo no encontrado';

  @override
  String get wrongPassword => 'Contraseña incorrecta';

  @override
  String get loginFailed => 'No se pudo iniciar sesión. Inténtalo más tarde';

  @override
  String get googleLoginFailed =>
      'No se pudo iniciar sesión con Google. Inténtalo de nuevo';

  @override
  String get chooseAppTheme => 'Elige el tema de la app';

  @override
  String get canChangeInProfile => 'Se puede cambiar en el perfil después';

  @override
  String get createNicknameDesc => 'Crea un apodo único para comenzar';

  @override
  String get checkingNickname => 'Comprobando apodo...';

  @override
  String get nicknameFree => '¡Apodo disponible!';

  @override
  String get nicknameTaken => 'Apodo ya en uso';

  @override
  String get mustAcceptTerms => 'Debes aceptar los Términos de Servicio';

  @override
  String get nameRules =>
      'El nombre debe tener 2–20 caracteres.\nSolo letras, números, _ y -';

  @override
  String get nameTaken => '¡Este nombre ya está en uso. Prueba otro!';

  @override
  String get nameCheckError => 'Error al verificar el nombre. ¿Sin conexión?';

  @override
  String get nameHint =>
      '• De 2 a 20 caracteres\n• Letras, números, _ y -\n• Único — nadie más puede tomarlo';

  @override
  String get iAgreePrefix => 'He leído y acepto los ';

  @override
  String get termsOfService => 'Términos de Servicio';

  @override
  String get changeTheme => '← Cambiar tema';

  @override
  String get createPassword => 'Crear contraseña';

  @override
  String get passwordNeeded => 'La necesitarás para iniciar sesión';

  @override
  String get passwordHint => 'Contraseña (mínimo 6 caracteres)';

  @override
  String get repeatPassword => 'Repite la contraseña';

  @override
  String get passwordMinSix => 'La contraseña debe tener al menos 6 caracteres';

  @override
  String get passwordsMismatch => 'Las contraseñas no coinciden';

  @override
  String get accountCreationFailed =>
      'No se pudo crear la cuenta. Inténtalo más tarde';

  @override
  String get passwordTooSimple =>
      'Contraseña demasiado simple. Mínimo 6 caracteres';

  @override
  String get emailAlreadyInUse => 'Este correo ya está en uso';

  @override
  String get suggestLineup => 'Proponer lineup';

  @override
  String get newsTooltip => 'Noticias';

  @override
  String get ratingMapPool => 'POOL DE MAPAS RANKED';

  @override
  String get otherMaps => 'OTROS MAPAS';

  @override
  String get categoryLineups => 'Lineups';

  @override
  String get categoryLineupsDesc => '¡Sorprende al enemigo!';

  @override
  String get categoryCombo => 'Combo';

  @override
  String get categoryComboDesc => '¡Combos geniales de agentes!';

  @override
  String get categorySmoky => 'Humos';

  @override
  String get categorySmokyDesc =>
      '¡Aprende los mejores humos para tus agentes!';

  @override
  String get categoryDefense => 'Defensa';

  @override
  String get categoryDefenseDesc =>
      '¡No dejes que el enemigo tome el sitio fácilmente!';

  @override
  String get noLineupsYet => 'Aún no hay lineups, ¡pero se añadirán pronto!';

  @override
  String lineupCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lineups',
      one: '$count lineup',
      zero: 'Sin lineups',
    );
    return '$_temp0';
  }

  @override
  String get exclusiveAccessActive => 'Acceso exclusivo activo por 1 hora';

  @override
  String patchLabel(String patch) {
    return 'Parche $patch';
  }

  @override
  String get accountDeleted => 'Cuenta eliminada';

  @override
  String get accountDeletedDesc =>
      'Todos los datos eliminados. Puedes crear una cuenta nueva.';

  @override
  String get mainMenu => 'MENÚ PRINCIPAL';

  @override
  String get profileTitle => 'PERFIL';

  @override
  String get topAuthors => 'Mejores autores';

  @override
  String get signOutDialogTitle => '¿Cerrar sesión?';

  @override
  String get signOutDialogMessage =>
      'Necesitarás tu apodo y contraseña para volver a iniciar sesión.';

  @override
  String get signOutBtn => 'Cerrar sesión';

  @override
  String get deleteAccountTitle => '¿Eliminar cuenta?';

  @override
  String get deleteAccountIrreversible => '¡Esta acción es irreversible!';

  @override
  String get deleteAccountContent =>
      'Se eliminarán:\n• Tu apodo\n• Nivel y progreso\n• Todos los lineups pendientes\n\nLos lineups aprobados permanecerán.';

  @override
  String get deleteForever => 'Eliminar definitivamente';

  @override
  String get linkEmailPassword => 'Vincular correo y contraseña';

  @override
  String get linkEmailDesc =>
      'Vincula correo y contraseña a tu cuenta de Google para iniciar sesión de cualquier forma.';

  @override
  String get newPassword => 'Nueva contraseña';

  @override
  String get fillAllFields => 'Rellena todos los campos';

  @override
  String get enterValidEmail => 'Introduce un correo válido';

  @override
  String get passwordMinSixSymbols => 'Contraseña — mínimo 6 caracteres';

  @override
  String get emailPasswordLinked => 'Correo y contraseña vinculados ✅';

  @override
  String get emailAlreadyUsedByOther => 'Este correo ya lo usa otra cuenta';

  @override
  String get emailAlreadyLinked =>
      'Este correo ya está vinculado a otra cuenta';

  @override
  String get changePassword => 'Cambiar contraseña';

  @override
  String get currentPassword => 'Contraseña actual';

  @override
  String get repeatNewPassword => 'Repite la nueva contraseña';

  @override
  String get newPasswordMinSix =>
      'La nueva contraseña debe tener al menos 6 caracteres';

  @override
  String get passwordChanged => 'Contraseña cambiada ✅';

  @override
  String get currentPasswordWrong => 'La contraseña actual es incorrecta';

  @override
  String get appTheme => 'Tema de la app';

  @override
  String approvedCount(int count) {
    return 'Aprobados: $count';
  }

  @override
  String toNextLevel(String name, int count) {
    return 'Para $name: $count';
  }

  @override
  String get maximum => 'MÁXIMO';

  @override
  String get levelPrivileges => 'Privilegios de nivel';

  @override
  String cooldownMinutes(int minutes) {
    return 'Espera: $minutes min';
  }

  @override
  String borderColor(String name) {
    return 'Color de borde: $name';
  }

  @override
  String get animatedProfile => 'Perfil animado';

  @override
  String get topAuthorPosition => 'Posición en mejores autores';

  @override
  String get allLevels => 'Todos los niveles';

  @override
  String get currentLevel => 'Actual';

  @override
  String levelRequirements(int lineups, int cd) {
    return '$lineups lineups • CD ${cd}m';
  }

  @override
  String get aboutApp => 'Acerca de la app';

  @override
  String get aboutAppContent =>
      'App gratuita con lineups interactivos para Valorant.\n\nNo afiliada con Riot Games.';

  @override
  String get feedback => 'Comentarios';

  @override
  String get viewTutorial => 'Ver tutorial';

  @override
  String get signOutMenuTitle => 'Cerrar sesión';

  @override
  String get dangerZone => 'Zona de peligro';

  @override
  String get dangerZoneDesc =>
      'Eliminar la cuenta es irreversible. Todo el progreso y nivel se perderán.';

  @override
  String get deleteMyAccount => 'ELIMINAR MI CUENTA';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get noNotifications => 'Sin notificaciones';

  @override
  String nextLineupIn(int minutes) {
    return 'Próximo lineup en $minutes min.';
  }

  @override
  String get approvedStat => 'Aprobado';

  @override
  String get totalStat => 'Total';

  @override
  String get cooldownStat => 'CD';

  @override
  String newCount(int count) {
    return '$count nuevos';
  }

  @override
  String get link => 'Vincular';

  @override
  String get change => 'Cambiar';

  @override
  String get defaultPlayer => 'Jugador';

  @override
  String get favorites => 'Favoritos';

  @override
  String get addToCollection => 'Añadir a colección';

  @override
  String get removeFromFavorites => 'Quitar de favoritos';

  @override
  String get addToFavorites => 'Añadir a favoritos';

  @override
  String get lineupFrom => 'Lineup de:';

  @override
  String get description => 'Descripción';

  @override
  String get screenshots => 'Capturas';

  @override
  String get possiblyOutdated =>
      'Posiblemente desactualizado — usuarios reportan imprecisiones';

  @override
  String get isRelevant => '¿Relevante?';

  @override
  String get needLevel2 => 'Se necesita nivel 2';

  @override
  String get loginRequired => 'Inicia sesión';

  @override
  String get votingFromLevel2 =>
      'Votar está disponible desde el nivel 2.\n\n¡Pero puedes ver un anuncio y tu voto contará!';

  @override
  String get howToGetLevel2 => '¿Cómo obtener nivel 2? →';

  @override
  String get loginToVote => 'Inicia sesión para votar.';

  @override
  String get watchAd => '📺 Ver anuncio';

  @override
  String get yourVote => 'Tu voto';

  @override
  String get isLineupRelevant => '¿El lineup es relevante?';

  @override
  String get outdated => 'Desactualizado';

  @override
  String get relevant => 'Relevante';

  @override
  String get authorProfileUnavailable => 'Perfil del autor no disponible';

  @override
  String get alreadyVoted => 'Ya votaste en este lineup';

  @override
  String get adLoading => 'El anuncio está cargando, prueba en un segundo...';

  @override
  String get voteAccepted => '✅ ¡Voto registrado!';

  @override
  String get voteSaveError => 'Error al guardar el voto';

  @override
  String get watchAdFull => 'Mira el anuncio hasta el final';

  @override
  String get adUnavailable => 'Anuncio no disponible, inténtalo más tarde';

  @override
  String get watchAdForAccess =>
      'Mira el anuncio hasta el final para obtener acceso';

  @override
  String get adLabel => '📺 anuncio';

  @override
  String downloadingPercent(String percent) {
    return 'Cargando $percent%...';
  }

  @override
  String get loadingAd => 'Cargando anuncio...';

  @override
  String get savingVideo => 'Guardando vídeo...';

  @override
  String get savedOffline => 'Guardado — disponible sin internet';

  @override
  String get onlineOnly => 'Solo en línea';

  @override
  String get saveOffline => 'Guardar sin conexión';

  @override
  String get videoSaved => 'Vídeo guardado';

  @override
  String get videoLoadError => 'No se pudo cargar el vídeo';

  @override
  String get videoComingSoon => 'Vídeo próximamente';

  @override
  String get videoSavedSuccess =>
      '✅ ¡Vídeo guardado — disponible sin internet!';

  @override
  String get downloadError => 'Error de descarga, inténtalo de nuevo';

  @override
  String get needExclusiveForLike =>
      'Se necesita acceso exclusivo para dar me gusta';

  @override
  String get exclusiveLineup => 'Lineup exclusivo';

  @override
  String get watchAdForExclusive =>
      'Mira un anuncio para desbloquear todos los lineups exclusivos por 1 hora';

  @override
  String get watchAdAccessBtn => '▶ Ver anuncio → acceso por 1 hora';

  @override
  String get watchAdForSave =>
      'Mira el anuncio hasta el final para guardar el vídeo';

  @override
  String get thanksForAd => '¡Gracias por ver el anuncio!';

  @override
  String get adHelpsUs => 'Nos ayuda a desarrollar la app 💪';

  @override
  String patchVersion(String version) {
    return 'Parche $version';
  }

  @override
  String get difficultyEasy => 'Fácil';

  @override
  String get difficultyMedium => 'Medio';

  @override
  String get difficultyHard => 'Difícil';

  @override
  String screenshotN(int n) {
    return 'Captura $n';
  }

  @override
  String get exclusiveTag => '⭐ EXCLUSIVO';

  @override
  String get howToGetLevel2Title => '¿Cómo obtener nivel 2?';

  @override
  String get xpDesc =>
      'Publica lineups en la app — ganas XP por cada uno. Acumula suficiente XP y subirás de nivel.';

  @override
  String get lineupRequirementsTitle => '📋 Requisitos de lineup';

  @override
  String get gotItWillPost => '¡Entendido, publicaré!';

  @override
  String get tabMolly => 'Mollies';

  @override
  String get tabReveal => 'Reveal';

  @override
  String get tabSmoky => 'Humos';

  @override
  String get timingsSectionTitle => '⏱ Tiempos';

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
      'No se pudieron cargar los datos. Verifica tu internet e inténtalo de nuevo';

  @override
  String get favoritesEmpty => 'No hay lineups guardados';

  @override
  String get favoritesEmptyDesc =>
      'Toca el ícono de marcador en cualquier lineup para guardarlo';

  @override
  String get feedbackTitle => 'COMENTARIOS';

  @override
  String get feedbackSendTab => 'Enviar';

  @override
  String get feedbackMyMessages => 'Mis mensajes';
}
