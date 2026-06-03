import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'agents_config_service.dart';
import 'valorant_api.dart';
import 'submission_guide_screen.dart';
import 'auth_service.dart';
import 'app_theme.dart';
import 'app_snack_bar.dart';
import 'patches_service.dart';

class SubmitLineupScreen extends StatefulWidget {
  const SubmitLineupScreen({super.key});

  @override
  State<SubmitLineupScreen> createState() => _SubmitLineupScreenState();
}

class _SubmitLineupScreenState extends State<SubmitLineupScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  // YouTube ссылка
  final _videoUrlController = TextEditingController();
  String? _videoUrlError;

  // TODO: костыль — временная загрузка видео с устройства напрямую в Storage
  File? _pickedVideoFile;
  double? _videoUploadProgress;
  bool _videoUploading = false;

  // Скриншоты (файлы с устройства)
  final List<File> _pickedScreenshots = [];

  List<Map<String, dynamic>> agents = [];
  List<Map<String, dynamic>> abilities = [];
  List<Map<String, dynamic>> _rawAbilities = [];
  String? selectedMap;
  String? selectedAgent;
  String? selectedAbility;
  String? selectedCategory;
  String? _difficulty; // 'easy', 'medium', 'hard'
  bool loading = false;
  bool submitted = false;
  bool checkingCooldown = false;
  double? markerX;
  double? markerY;
  String? username;

  final List<Map<String, String>> mapAssets = [
    {'name': 'Haven',    'file': 'assets/maps/Haven_minimap.png'},
    {'name': 'Bind',     'file': 'assets/maps/Bind_minimap.png'},
    {'name': 'Ascent',   'file': 'assets/maps/Ascent_minimap.png'},
    {'name': 'Split',    'file': 'assets/maps/Split_minimap.png'},
    {'name': 'Icebox',   'file': 'assets/maps/Icebox_minimap.png'},
    {'name': 'Breeze',   'file': 'assets/maps/Breeze_minimap.png'},
    {'name': 'Fracture', 'file': 'assets/maps/Fracture_minimap.png'},
    {'name': 'Pearl',    'file': 'assets/maps/Pearl_minimap.png'},
    {'name': 'Lotus',    'file': 'assets/maps/Lotus_minimap.png'},
    {'name': 'Sunset',   'file': 'assets/maps/Sunset_minimap.png'},
    {'name': 'Abyss',    'file': 'assets/maps/Abyss_minimap.png'},
    {'name': 'Corrode',  'file': 'assets/maps/Corrode_minimap.png'},
  ];

  List<String> get maps => mapAssets.map((m) => m['name']!).toList();

  String? get selectedMapAsset => selectedMap == null
      ? null
      : mapAssets.firstWhere((m) => m['name'] == selectedMap,
          orElse: () => {})['file'];

  String get _selectedAbilityIcon {
    if (selectedAbility == null) return '';
    final ability = abilities.firstWhere(
        (a) => a['displayName'] == selectedAbility, orElse: () => {});
    return ability['displayIcon'] as String? ?? '';
  }

  @override
  void initState() {
    super.initState();
    loadAgents();
    _loadUsername();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  // TODO: костыль — загрузка видео с устройства в Firebase Storage
  Future<void> _pickVideo() async {
    final xfile = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (xfile == null) return;
    setState(() {
      _pickedVideoFile = File(xfile.path);
      _videoUrlController.clear();
      _videoUrlError = null;
    });
  }

  Future<String?> _uploadPickedVideo() async {
    if (_pickedVideoFile == null) return null;
    final uid = AuthService.userId ?? 'anon';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseStorage.instance.ref().child('videos/$uid/$ts.mp4');
    setState(() { _videoUploading = true; _videoUploadProgress = 0; });
    try {
      final task = ref.putFile(
        _pickedVideoFile!,
        SettableMetadata(contentType: 'video/mp4'),
      );
      task.snapshotEvents.listen((snap) {
        if (!mounted) return;
        final progress = snap.bytesTransferred / snap.totalBytes;
        setState(() => _videoUploadProgress = progress);
      });
      final snapshot = await task;
      return await snapshot.ref.getDownloadURL();
    } catch (_) {
      return null;
    } finally {
      if (mounted) setState(() { _videoUploading = false; _videoUploadProgress = null; });
    }
  }

  Future<void> _loadUsername() async {
    final name = await AuthService.getUsername();
    if (mounted) setState(() => username = name);
  }

  Future<void> loadAgents() async {
    final results = await Future.wait<dynamic>(
        [ValorantApi.getAgents(), AgentsConfigService.getDisabledAgents()]);
    final all     = results[0] as List<Map<String, dynamic>>;
    final hidden  = results[1] as Set<String>;
    if (mounted) setState(() => agents = AgentsConfigService.applyDisabled(all, hidden));
  }

  void onAgentSelected(String agentName) {
    final agent = agents.firstWhere(
        (a) => a['displayName'] == agentName, orElse: () => {});
    final raw = List<Map<String, dynamic>>.from(agent['abilities'] ?? [])
        .where((a) => (a['displayIcon'] ?? '').isNotEmpty)
        .toList();
    setState(() {
      selectedAgent = agentName;
      selectedAbility = null;
      abilities = raw;
      _rawAbilities = raw;
    });
    _refilterAbilities(agentName, raw);
  }

  void _refilterAbilities([String? agent, List<Map<String, dynamic>>? raw]) {
    final agentName = agent ?? selectedAgent;
    final src = raw ?? _rawAbilities;
    final cat = selectedCategory;
    if (agentName == null || cat == null) return;
    AgentsConfigService.filterAbilities(agentName, cat, src).then((filtered) {
      if (mounted) setState(() => abilities = filtered);
    });
  }

  Future<List<String>> _uploadScreenshots() async {
    final urls = <String>[];
    for (int i = 0; i < _pickedScreenshots.length; i++) {
      try {
        final ts = DateTime.now().millisecondsSinceEpoch;
        final ref = FirebaseStorage.instance
            .ref()
            .child('lineups_screenshots')
            .child('${ts}_$i.jpg');
        final task = await ref.putFile(
          _pickedScreenshots[i],
          SettableMetadata(contentType: 'image/jpeg'),
        );
        urls.add(await task.ref.getDownloadURL());
      } catch (_) {}
    }
    return urls;
  }

  static bool _isValidYoutubeUrl(String url) {
    if (url.isEmpty) return true;
    try {
      final uri = Uri.parse(url.trim());
      final host = uri.host.toLowerCase();
      if (host == 'youtu.be' || host == 'www.youtu.be') {
        return uri.pathSegments.isNotEmpty && uri.pathSegments.first.length >= 5;
      }
      if (host == 'youtube.com' || host == 'www.youtube.com') {
        final v = uri.queryParameters['v'];
        if (v != null && v.length >= 5) return true;
        final segs = uri.pathSegments;
        if (segs.length >= 2 && segs.first == 'shorts') return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> submit() async {
    if (selectedMap == null || selectedAgent == null ||
        selectedAbility == null || selectedCategory == null ||
        _titleController.text.isEmpty || _descController.text.isEmpty) {
      _snack('Заполни все поля!', Colors.orange);
      return;
    }
    if (markerX == null || markerY == null) {
      _snack('Поставь метку на карте!', Colors.orange);
      return;
    }

    final videoUrl = _videoUrlController.text.trim();
    if (!_isValidYoutubeUrl(videoUrl)) {
      setState(() => _videoUrlError = 'Некорректная YouTube ссылка');
      _snack('Некорректная YouTube ссылка', Colors.orange);
      return;
    }

    final banned = await AuthService.isBanned();
    if (!mounted) return;
    if (banned) { _snack('Ты заблокирован.', Colors.red); return; }

    setState(() => checkingCooldown = true);
    final canSubmit = await AuthService.canSubmitLineup();
    if (!mounted) return;
    setState(() => checkingCooldown = false);

    if (!canSubmit) {
      _snack('Подожди перед следующей отправкой!', Colors.orange);
      return;
    }

    setState(() => loading = true);

    try {
      String? uploadedVideoUrl;
      if (_pickedVideoFile != null) {
        uploadedVideoUrl = await _uploadPickedVideo();
        if (uploadedVideoUrl == null && mounted) {
          setState(() => loading = false);
          _snack('Ошибка загрузки видео. Попробуй ещё раз.', Colors.red);
          return;
        }
      }

      final results = await Future.wait([
        _uploadScreenshots(),
        PatchesService.getCurrentPatch(),
      ]);
      final screenshotUrls = results[0] as List<String>;
      final currentPatch = results[1] as String?;

      final finalVideoUrl = uploadedVideoUrl ?? videoUrl;

      await FirebaseFirestore.instance.collection('lineups').add({
        'map': selectedMap,
        'agent': selectedAgent,
        'ability': selectedAbility,
        'title': _titleController.text,
        'description': _descController.text,
        'video_url': finalVideoUrl,
        'screenshots': screenshotUrls,
        'position_x': markerX,
        'position_y': markerY,
        'category': selectedCategory,
        'difficulty': _difficulty,
        'status': 'pending',
        'submitted_at': FieldValue.serverTimestamp(),
        'user_id': AuthService.userId,
        'submitted_by': username ?? 'Аноним',
        'patch_version': currentPatch,
        'reputation_up': 0,
        'reputation_down': 0,
        'is_outdated': false,
      });

      if (!mounted) return;
      setState(() { loading = false; submitted = true; });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        _snack('Ошибка отправки. Проверь соединение.', Colors.red);
      }
    }
  }

  void _snack(String msg, Color color) {
    SnackBarType type = SnackBarType.info;
    if (color == Colors.green) { type = SnackBarType.success; }
    else if (color == Colors.red) { type = SnackBarType.error; }
    else if (color == Colors.orange) { type = SnackBarType.warning; }
    AppSnackBar.show(context, msg, type: type);
  }

  Future<void> _openMapPicker() async {
    if (selectedMapAsset == null) return;
    final result = await Navigator.push<Map<String, double>>(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenMapPicker(
          mapAsset: selectedMapAsset!,
          initialX: markerX,
          initialY: markerY,
          abilityIconUrl: _selectedAbilityIcon,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() { markerX = result['x']; markerY = result['y']; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.of(context);

    if (submitted) {
      return Scaffold(
        backgroundColor: theme.background,
        appBar: AppBar(backgroundColor: theme.surface),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 16),
              Text('Лайнап отправлен!',
                  style: TextStyle(color: theme.textPrimary, fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Появится после проверки',
                  style: TextStyle(color: theme.textSecondary, fontSize: 14)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: theme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
                child: const Text('Назад', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        title: Text('ПРЕДЛОЖИТЬ ЛАЙНАП',
            style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold,
                letterSpacing: 1, fontSize: 14)),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.primary),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SubmissionGuideScreen())),
            icon: Icon(Icons.help_outline, color: theme.primary, size: 18),
            label: Text('Гайд', style: TextStyle(color: theme.primary, fontSize: 13)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Карта ───────────────────────────────────────────────────
            _label('Карта', theme),
            _dropdown(
              value: selectedMap,
              items: maps,
              hint: 'Выбери карту',
              onChanged: (val) => setState(() {
                selectedMap = val;
                markerX = null;
                markerY = null;
              }),
              theme: theme,
            ),
            const SizedBox(height: 16),

            // ─── Агент ───────────────────────────────────────────────────
            _label('Агент', theme),
            agents.isEmpty
                ? Center(child: CircularProgressIndicator(color: theme.primary))
                : _dropdown(
                    value: selectedAgent,
                    items: agents.map((a) => a['displayName'] as String).toList(),
                    hint: 'Выбери агента',
                    onChanged: (val) { if (val != null) onAgentSelected(val); },
                    theme: theme,
                  ),
            const SizedBox(height: 16),

            // ─── Абилки (иконки) ─────────────────────────────────────────
            if (selectedAgent != null) ...[
              _label('Абилка', theme),
              abilities.isEmpty
                  ? Text('Нет абилок', style: TextStyle(color: theme.textSecondary))
                  : Row(
                      children: abilities.map((ability) {
                        final name = ability['displayName'] as String? ?? '';
                        final icon = ability['displayIcon'] as String? ?? '';
                        final isSelected = selectedAbility == name;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => selectedAbility = name),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.primary.withValues(alpha: 0.15)
                                    : theme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? theme.primary : theme.border,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  icon.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: icon, width: 32, height: 32,
                                          placeholder: (_, _) => Container(color: Colors.transparent),
                                          errorWidget: (_, _, _) => Icon(
                                              Icons.flash_on,
                                              color: theme.primary, size: 28))
                                      : Icon(Icons.flash_on,
                                          color: theme.primary, size: 28),
                                  const SizedBox(height: 4),
                                  Text(
                                    name,
                                    style: TextStyle(
                                      color: isSelected ? theme.primary : theme.textSecondary,
                                      fontSize: 9,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 16),
            ],

            // ─── Категория ────────────────────────────────────────────────
            _label('Категория', theme),
            _categoryPicker(theme),
            const SizedBox(height: 16),

            // ─── Сложность ────────────────────────────────────────────────
            _label('Сложность', theme),
            _difficultyPicker(theme),
            const SizedBox(height: 16),

            // ─── Название ─────────────────────────────────────────────────
            _label('Название лайнапа', theme),
            _field(_titleController, 'Например: А-сайт с пикка', theme: theme),
            const SizedBox(height: 16),

            // ─── Описание ─────────────────────────────────────────────────
            _label('Описание', theme),
            _field(_descController, 'Опиши позицию и как целиться...',
                maxLines: 4, theme: theme),
            const SizedBox(height: 16),

            // ─── Видео ────────────────────────────────────────────────────
            _label('Видео лайнапа', theme),
            _videoUploadBlock(theme),
            const SizedBox(height: 16),

            // ─── Скриншоты ────────────────────────────────────────────────
            _label('Скриншоты (с устройства)', theme),
            _screenshotsBlock(theme),
            const SizedBox(height: 16),

            // ─── Метка на карте ───────────────────────────────────────────
            _label('Поставь метку на карте', theme),
            if (selectedMap == null || selectedAgent == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.border),
                ),
                child: Text('Сначала выбери карту и агента',
                    style: TextStyle(color: theme.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    markerX == null
                        ? '👆 Нажми «На весь экран» и поставь метку'
                        : '✅ Метка поставлена! Нажми чтобы изменить',
                    style: TextStyle(
                        color: markerX == null ? Colors.orange : Colors.green,
                        fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _openMapPicker,
                    child: Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.primary, width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(selectedMapAsset!, fit: BoxFit.contain),
                            if (markerX != null && markerY != null)
                              Align(
                                alignment: FractionalOffset(markerX!, markerY!),
                                child: _markerDot(theme, size: 16),
                              ),
                            Positioned(
                              bottom: 8, right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.open_in_full,
                                        color: theme.primary, size: 14),
                                    const SizedBox(width: 4),
                                    Text('На весь экран',
                                        style: TextStyle(
                                            color: theme.primary, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // ─── Кнопка отправки ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (loading || checkingCooldown) ? null : submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: (loading || checkingCooldown)
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('ОТПРАВИТЬ НА ПРОВЕРКУ',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('⏱ Можно отправлять 1 лайнап в час',
                  style: TextStyle(color: theme.textSecondary, fontSize: 11)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─── Маркер с иконкой абилки ──────────────────────────────────────────────

  Widget _markerDot(AppThemeData theme, {double size = 20}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: theme.primary, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
      ),
      child: ClipOval(
        child: _selectedAbilityIcon.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: _selectedAbilityIcon,
                width: size, height: size, fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: Colors.transparent),
                errorWidget: (_, _, _) =>
                    Icon(Icons.place, color: theme.primary, size: size * 0.55))
            : Icon(Icons.place, color: theme.primary, size: size * 0.55),
      ),
    );
  }

  // ─── Блок YouTube ссылки или загрузки видео с устройства ────────────────

  Widget _videoUploadBlock(AppThemeData theme) {
    final url = _videoUrlController.text.trim();
    final urlEmpty = url.isEmpty;
    final urlValid = _isValidYoutubeUrl(url);
    final hasVideoFile = _pickedVideoFile != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.border),
          ),
          child: Text(
            '🎬 Необязательно. Добавь YouTube ссылку ИЛИ загрузи видео с устройства.',
            style: TextStyle(color: theme.textSecondary, fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        // YouTube поле — скрыто если выбрано видео с устройства
        if (!hasVideoFile) ...[
          TextField(
            controller: _videoUrlController,
            style: TextStyle(color: theme.textPrimary),
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() => _videoUrlError = null),
            decoration: InputDecoration(
              hintText: 'https://youtu.be/...',
              hintStyle: TextStyle(color: theme.textSecondary),
              filled: true,
              fillColor: theme.surface,
              prefixIcon: Icon(Icons.link, color: theme.primary),
              suffixIcon: !urlEmpty
                  ? Icon(
                      urlValid ? Icons.check_circle : Icons.error_outline,
                      color: urlValid ? Colors.green : Colors.red,
                      size: 20,
                    )
                  : null,
              errorText: _videoUrlError,
              errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: !urlEmpty
                      ? (urlValid ? Colors.green : Colors.red)
                      : theme.border,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: theme.primary, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(child: Divider(color: theme.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('или', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                ),
                Expanded(child: Divider(color: theme.border)),
              ],
            ),
          ),
        ],
        // Кнопка загрузки видео с устройства
        if (!hasVideoFile)
          GestureDetector(
            onTap: _videoUploading ? null : _pickVideo,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library_outlined, color: theme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Загрузить видео с устройства',
                      style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ),
        // Превью выбранного видео
        if (hasVideoFile) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.videocam, color: Colors.green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _pickedVideoFile!.path.split('/').last,
                    style: TextStyle(color: theme.textPrimary, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _pickedVideoFile = null;
                    _videoUploadProgress = null;
                  }),
                  child: const Icon(Icons.close, color: Colors.red, size: 18),
                ),
              ],
            ),
          ),
          if (_videoUploading && _videoUploadProgress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _videoUploadProgress,
                backgroundColor: theme.border,
                valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Загрузка ${((_videoUploadProgress ?? 0) * 100).toStringAsFixed(0)}%...',
              style: TextStyle(color: theme.textSecondary, fontSize: 11),
            ),
          ],
        ],
      ],
    );
  }

  // ─── Блок скриншотов ──────────────────────────────────────────────────────

  Widget _screenshotsBlock(AppThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pickScreenshots,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: theme.surface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined, color: theme.primary, size: 22),
                const SizedBox(width: 10),
                Text('Добавить фото (можно несколько)',
                    style: TextStyle(color: theme.primary,
                        fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ),
        if (_pickedScreenshots.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _pickedScreenshots.length,
              itemBuilder: (_, i) => Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: FileImage(_pickedScreenshots[i]),
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(color: theme.border),
                    ),
                  ),
                  Positioned(
                    top: -4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _pickedScreenshots.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickScreenshots() async {
    final xfiles = await ImagePicker().pickMultiImage();
    if (xfiles.isNotEmpty) {
      setState(() =>
          _pickedScreenshots.addAll(xfiles.map((x) => File(x.path))));
    }
  }

  // ─── Пикер категорий ─────────────────────────────────────────────────────

  static const _submitCategories = <Map<String, String>>[
    {'key': 'lineup',  'emoji': '🎯', 'name': 'Лайнапы'},
    {'key': 'combo',   'emoji': '⚡', 'name': 'Комбо'},
    {'key': 'meta',    'emoji': '👑', 'name': 'Мета'},
    {'key': 'smoke',   'emoji': '💨', 'name': 'Смоки'},
    {'key': 'defense', 'emoji': '🛡', 'name': 'Защита'},
  ];

  Widget _categoryPicker(AppThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _submitCategories.map((cat) {
        final isSelected = selectedCategory == cat['key'];
        return GestureDetector(
          onTap: () {
            setState(() => selectedCategory = cat['key']);
            _refilterAbilities();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.primary.withValues(alpha: 0.15)
                  : theme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? theme.primary : theme.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cat['emoji']!,
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(
                  cat['name']!,
                  style: TextStyle(
                    color: isSelected
                        ? theme.primary
                        : theme.textSecondary,
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _difficultyPicker(AppThemeData theme) {
    const options = [
      {'key': 'easy',   'label': '🟢 Легко',  'color': 0xFF22c55e},
      {'key': 'medium', 'label': '🟡 Средне', 'color': 0xFFf59e0b},
      {'key': 'hard',   'label': '🔴 Сложно', 'color': 0xFFef4444},
    ];
    return Row(
      children: options.asMap().entries.map((entry) {
        final i = entry.key;
        final opt = entry.value;
        final isSelected = _difficulty == opt['key'];
        final color = Color(opt['color'] as int);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < options.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _difficulty = opt['key'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.15) : theme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? color : theme.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    opt['label'] as String,
                    style: TextStyle(
                      color: isSelected ? color : theme.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Хелперы ──────────────────────────────────────────────────────────────

  Widget _label(String text, AppThemeData theme) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(color: theme.primary,
                fontWeight: FontWeight.bold, fontSize: 13)),
      );

  Widget _field(TextEditingController controller, String hint,
      {int maxLines = 1, required AppThemeData theme}) {
    return TextField(
      controller: controller,
      style: TextStyle(color: theme.textPrimary),
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.textSecondary),
        filled: true,
        fillColor: theme.surface,
        enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: theme.border),
            borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: theme.primary),
            borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _dropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required void Function(String?) onChanged,
    required AppThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.border),
      ),
      child: DropdownButton<String>(
        value: value,
        hint: Text(hint, style: TextStyle(color: theme.textSecondary)),
        isExpanded: true,
        dropdownColor: theme.surface,
        underline: const SizedBox(),
        style: TextStyle(color: theme.textPrimary),
        onChanged: onChanged,
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
      ),
    );
  }
}

// ─── Полноэкранный выбор метки ───────────────────────────────────────────────

class _FullscreenMapPicker extends StatefulWidget {
  final String mapAsset;
  final double? initialX;
  final double? initialY;
  final String abilityIconUrl;

  const _FullscreenMapPicker({
    required this.mapAsset,
    this.initialX,
    this.initialY,
    required this.abilityIconUrl,
  });

  @override
  State<_FullscreenMapPicker> createState() => _FullscreenMapPickerState();
}

class _FullscreenMapPickerState extends State<_FullscreenMapPicker> {
  double? _markerX;
  double? _markerY;
  bool _zoomMode = false;
  final TransformationController _transformController = TransformationController();

  @override
  void initState() {
    super.initState();
    _markerX = widget.initialX;
    _markerY = widget.initialY;
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Offset _localToImageOffset(Offset tapOffset, Size containerSize) {
    final matrix = _transformController.value;
    final inverted = Matrix4.inverted(matrix);
    final transformed = MatrixUtils.transformPoint(inverted, tapOffset);
    return Offset(
      (transformed.dx / containerSize.width).clamp(0.0, 1.0),
      (transformed.dy / containerSize.height).clamp(0.0, 1.0),
    );
  }

  Widget _markerWidget(AppThemeData theme) {
    const size = 22.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: theme.primary, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 6)],
      ),
      child: ClipOval(
        child: widget.abilityIconUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: widget.abilityIconUrl,
                width: size, height: size, fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: Colors.transparent),
                errorWidget: (_, _, _) =>
                    Icon(Icons.place, color: theme.primary, size: size * 0.55))
            : Icon(Icons.place, color: theme.primary, size: size * 0.55),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Поставь метку',
            style: TextStyle(color: theme.primary, fontSize: 15)),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.primary),
        actions: [
          if (_markerX != null)
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, {'x': _markerX!, 'y': _markerY!}),
              child: Text('ГОТОВО',
                  style: TextStyle(color: theme.primary,
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ─── Переключатель режима ────────────────────────────────────
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _zoomMode = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_zoomMode ? theme.primary : Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.place,
                              color: !_zoomMode ? Colors.white : Colors.white54,
                              size: 16),
                          const SizedBox(width: 6),
                          Text('Ставить метку',
                              style: TextStyle(
                                  color: !_zoomMode ? Colors.white : Colors.white54,
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _zoomMode = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _zoomMode ? theme.primary : Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.zoom_in,
                              color: _zoomMode ? Colors.white : Colors.white54,
                              size: 16),
                          const SizedBox(width: 6),
                          Text('Зум карты',
                              style: TextStyle(
                                  color: _zoomMode ? Colors.white : Colors.white54,
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Подсказка ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _zoomMode
                  ? '🔍 Режим зума — двигай и масштабируй карту'
                  : _markerX == null
                      ? '📍 Нажми на карту чтобы поставить метку'
                      : '✅ Метка поставлена — нажми ещё раз чтобы переставить',
              style: TextStyle(
                color: _zoomMode
                    ? Colors.white54
                    : _markerX == null ? Colors.orange : Colors.green,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // ─── Карта ──────────────────────────────────────────────────
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                const markerSize = 22.0;

                return GestureDetector(
                  onTapUp: _zoomMode
                      ? null
                      : (details) {
                          final offset =
                              _localToImageOffset(details.localPosition, size);
                          setState(() {
                            _markerX = offset.dx;
                            _markerY = offset.dy;
                          });
                        },
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 1.0,
                    maxScale: 5.0,
                    panEnabled: _zoomMode,
                    scaleEnabled: _zoomMode,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: Stack(
                        children: [
                          Image.asset(
                            widget.mapAsset,
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            fit: BoxFit.contain,
                          ),
                          if (_markerX != null && _markerY != null)
                            Positioned(
                              left: _markerX! * constraints.maxWidth -
                                  markerSize / 2,
                              top: _markerY! * constraints.maxHeight -
                                  markerSize / 2,
                              child: _markerWidget(theme),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ─── Кнопка подтверждения ────────────────────────────────────
          if (_markerX != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(
                        context, {'x': _markerX!, 'y': _markerY!}),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('ПОДТВЕРДИТЬ МЕТКУ',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
