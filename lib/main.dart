// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use, unused_local_variable

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';

// ═══════════════════════════════════════════
//  MAIN
// ═══════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF07070D),
  ));
  runApp(const AuraApp());
}

// ═══════════════════════════════════════════
//  THEME
// ═══════════════════════════════════════════
class C {
  static const bg = Color(0xFF07070D);
  static const surface = Color(0xFF0F0F1A);
  static const card = Color(0xFF141422);
  static const accent = Color(0xFF7C3AED);
  static const cyan = Color(0xFF00D4FF);
  static const pink = Color(0xFFFF2D78);
  static const text = Color(0xFFF0F0FF);
  static const sub = Color(0xFF8888AA);
  static const div = Color(0xFF1E1E35);
}

// ═══════════════════════════════════════════
//  STATE
// ═══════════════════════════════════════════
enum RepMode { none, one, all }

class MusicState extends ChangeNotifier {
  final AudioPlayer player = AudioPlayer();
  final OnAudioQuery _query = OnAudioQuery();

  List<SongModel> songs = [];
  SongModel? current;
  int index = 0;
  bool playing = false;
  bool loading = false;
  bool hasPermission = false;
  bool shuffled = false;
  RepMode repMode = RepMode.none;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  int navIndex = 0;

  double get progress => duration.inMilliseconds == 0
      ? 0
      : position.inMilliseconds / duration.inMilliseconds;

  MusicState() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    player.positionStream.listen((p) {
      position = p;
      notifyListeners();
    });
    player.durationStream.listen((d) {
      duration = d ?? Duration.zero;
      notifyListeners();
    });
    player.playerStateStream.listen((s) {
      playing = s.playing;
      if (s.processingState == ProcessingState.completed) _onComplete();
      notifyListeners();
    });
  }

  void _onComplete() {
    if (repMode == RepMode.one) {
      player.seek(Duration.zero);
      player.play();
    } else if (repMode == RepMode.all)
      next();
    else if (index < songs.length - 1) next();
  }

  Future<bool> requestPermission() async {
    var s = await Permission.audio.request();
    if (!s.isGranted) s = await Permission.storage.request();
    hasPermission = s.isGranted;
    notifyListeners();
    return hasPermission;
  }

  Future<void> loadSongs() async {
    loading = true;
    notifyListeners();
    songs = await _query.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
    );
    loading = false;
    notifyListeners();
  }

  Future<void> play(SongModel s, int i) async {
    current = s;
    index = i;
    notifyListeners();
    try {
      await player.setAudioSource(AudioSource.uri(Uri.parse(s.uri!)));
      await player.play();
    } catch (_) {}
  }

  Future<void> toggle() async =>
      playing ? await player.pause() : await player.play();

  Future<void> next() async {
    if (songs.isEmpty) return;
    final i = (index + 1) % songs.length;
    await play(songs[i], i);
  }

  Future<void> prev() async {
    if (songs.isEmpty) return;
    if (position.inSeconds > 3) {
      await player.seek(Duration.zero);
      return;
    }
    final i = index > 0 ? index - 1 : songs.length - 1;
    await play(songs[i], i);
  }

  Future<void> seekTo(double v) async => await player
      .seek(Duration(milliseconds: (v * duration.inMilliseconds).round()));

  void toggleRepeat() {
    repMode = repMode == RepMode.none
        ? RepMode.all
        : repMode == RepMode.all
            ? RepMode.one
            : RepMode.none;
    notifyListeners();
  }

  void toggleShuffle() {
    shuffled = !shuffled;
    if (shuffled) songs.shuffle();
    notifyListeners();
  }

  void setNav(int i) {
    navIndex = i;
    notifyListeners();
  }

  String fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════════
//  APP
// ═══════════════════════════════════════════
class AuraApp extends StatelessWidget {
  const AuraApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (_, __) => MaterialApp(
        title: 'Aura Music',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: C.bg,
          colorScheme:
              const ColorScheme.dark(primary: C.accent, secondary: C.cyan),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

final _state = MusicState();

// ═══════════════════════════════════════════
//  SPLASH SCREEN
// ═══════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _ring, _pulse, _wave;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _ring =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _wave =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_pulse);

    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted)
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, a, __) => const PermissionScreen(),
            transitionsBuilder: (_, a, __, child) =>
                FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 700),
          ),
        );
    });
  }

  @override
  void dispose() {
    _ring.dispose();
    _pulse.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(children: [
        // BG orbs
        AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Stack(children: [
                  Positioned(
                      top: -80,
                      left: -80,
                      child: _orb(280 + 20 * _pulseAnim.value, C.accent, 0.25)),
                  Positioned(
                      bottom: -60,
                      right: -60,
                      child: _orb(220 + 15 * _pulseAnim.value, C.cyan, 0.15)),
                ])),

        Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Rotating ring + icon
          AnimatedBuilder(
              animation: Listenable.merge([_ring, _pulseAnim]),
              builder: (_, __) => Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: _ring.value * 2 * math.pi,
                        child: Container(
                          width: 130 + 8 * _pulseAnim.value,
                          height: 130 + 8 * _pulseAnim.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const SweepGradient(
                                colors: [C.accent, C.cyan, C.pink, C.accent]),
                          ),
                        ),
                      ),
                      Container(
                          width: 112,
                          height: 112,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: C.bg)),
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient:
                              const LinearGradient(colors: [C.accent, C.cyan]),
                          boxShadow: [
                            BoxShadow(
                                color: C.accent.withOpacity(0.5),
                                blurRadius: 28,
                                spreadRadius: 4)
                          ],
                        ),
                        child: const Icon(Icons.music_note_rounded,
                            size: 40, color: Colors.white),
                      ),
                    ],
                  )),

          const SizedBox(height: 36),

          // Title
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (_, v, child) => Opacity(
                opacity: v,
                child: Transform.translate(
                    offset: Offset(0, 20 * (1 - v)), child: child)),
            child: const Text('AURA',
                style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: C.text,
                    letterSpacing: 14)),
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (_, v, child) => Opacity(opacity: v, child: child),
            child: const Text('MUSIC',
                style: TextStyle(fontSize: 13, color: C.sub, letterSpacing: 7)),
          ),

          const SizedBox(height: 48),

          // Wave bars
          AnimatedBuilder(
              animation: _wave,
              builder: (_, __) => SizedBox(
                    width: 56,
                    height: 22,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(5, (i) {
                        final h =
                            (math.sin((_wave.value + i * 0.2) * 2 * math.pi) *
                                            0.5 +
                                        0.5) *
                                    18 +
                                4;
                        return Container(
                          width: 5,
                          height: h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: const LinearGradient(
                                colors: [C.accent, C.cyan],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter),
                          ),
                        );
                      }),
                    ),
                  )),
        ])),

        Positioned(
          bottom: 48,
          left: 0,
          right: 0,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOut,
            builder: (_, v, child) => Opacity(opacity: v, child: child),
            child: const Text('Ton univers sonore',
                textAlign: TextAlign.center,
                style: TextStyle(color: C.sub, fontSize: 13, letterSpacing: 2)),
          ),
        ),
      ]),
    );
  }

  Widget _orb(double size, Color color, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
                colors: [color.withOpacity(opacity), Colors.transparent])),
      );
}

// ═══════════════════════════════════════════
//  PERMISSION SCREEN
// ═══════════════════════════════════════════
class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});
  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glow;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _glow =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    setState(() => _loading = true);
    final ok = await _state.requestPermission();
    if (ok) {
      await _state.loadSongs();
      if (mounted)
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, a, __) => const HomeScreen(),
            transitionsBuilder: (_, a, __, child) => SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(1, 0), end: Offset.zero)
                  .animate(
                      CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(children: [
          const SizedBox(height: 80),
          AnimatedBuilder(
              animation: _glow,
              builder: (_, __) => Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient:
                          const LinearGradient(colors: [C.accent, C.cyan]),
                      boxShadow: [
                        BoxShadow(
                            color:
                                C.accent.withOpacity(0.3 + 0.2 * _glow.value),
                            blurRadius: 40 + 20 * _glow.value,
                            spreadRadius: 4)
                      ],
                    ),
                    child: const Icon(Icons.folder_open_rounded,
                        size: 52, color: Colors.white),
                  )),
          const SizedBox(height: 44),
          const Text('Accès à ta\nMusique',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: C.text,
                  height: 1.1)),
          const SizedBox(height: 18),
          const Text(
              'Aura a besoin d\'accéder à tes fichiers audio pour lire ta musique locale.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: C.sub, height: 1.6)),
          const SizedBox(height: 40),
          ...[
            (
              Icons.library_music_rounded,
              'Ta bibliothèque complète',
              'Tous tes fichiers MP3/FLAC'
            ),
            (
              Icons.offline_bolt_rounded,
              'Hors ligne',
              'Aucune connexion requise'
            ),
            (Icons.security_rounded, 'Privé', 'Aucune donnée partagée'),
          ].map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(children: [
                  Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          color: C.accent.withOpacity(0.13)),
                      child: Icon(e.$1, color: C.accent, size: 22)),
                  const SizedBox(width: 14),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.$2,
                            style: const TextStyle(
                                color: C.text,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        Text(e.$3,
                            style: const TextStyle(color: C.sub, fontSize: 12)),
                      ]),
                ]),
              )),
          const Spacer(),
          GestureDetector(
            onTap: _loading ? null : _request,
            child: Container(
              height: 58,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(29),
                gradient: const LinearGradient(colors: [C.accent, C.cyan]),
                boxShadow: [
                  BoxShadow(
                      color: C.accent.withOpacity(0.4),
                      blurRadius: 18,
                      spreadRadius: 2)
                ],
              ),
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Icon(Icons.music_note_rounded, color: Colors.white),
                            SizedBox(width: 10),
                            Text('Autoriser l\'accès',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                          ]),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      )),
    );
  }
}

// ═══════════════════════════════════════════
//  HOME SCREEN
// ═══════════════════════════════════════════
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _tabs = [LibraryTab(), SearchTab(), SettingsTab()];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (_, __) => Scaffold(
        backgroundColor: C.bg,
        body: Stack(children: [
          _tabs[_state.navIndex],
          if (_state.current != null)
            Positioned(
                bottom: 80, left: 12, right: 12, child: const MiniPlayer()),
        ]),
        bottomNavigationBar: const AuraNavBar(),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  NAV BAR
// ═══════════════════════════════════════════
class AuraNavBar extends StatelessWidget {
  const AuraNavBar({super.key});

  static const _items = [
    (Icons.library_music_rounded, 'Biblio'),
    (Icons.search_rounded, 'Recherche'),
    (Icons.settings_rounded, 'Paramètres'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (_, __) => Container(
        height: 72,
        decoration: BoxDecoration(
          color: C.surface,
          border: const Border(top: BorderSide(color: C.div, width: 0.5)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, -4))
          ],
        ),
        child: SafeArea(
            child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: _items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            final sel = _state.navIndex == i;
            return GestureDetector(
              onTap: () => _state.setNav(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: sel ? C.accent.withOpacity(0.13) : Colors.transparent,
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedScale(
                    scale: sel ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    child: ShaderMask(
                      shaderCallback: (b) => LinearGradient(
                        colors: sel ? [C.accent, C.cyan] : [C.sub, C.sub],
                      ).createShader(b),
                      child: Icon(item.$1, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        color: sel ? C.accent : C.sub),
                    child: Text(item.$2),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: sel ? 4 : 0,
                    height: sel ? 4 : 0,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [C.accent, C.cyan])),
                  ),
                ]),
              ),
            );
          }).toList(),
        )),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  LIBRARY TAB
// ═══════════════════════════════════════════
class LibraryTab extends StatelessWidget {
  const LibraryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (_, __) => CustomScrollView(slivers: [
        SliverToBoxAdapter(
            child: SafeArea(
                child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bonne écoute 🎵',
                style:
                    TextStyle(color: C.sub, fontSize: 13, letterSpacing: 0.5)),
            const Text('Ta Bibliothèque',
                style: TextStyle(
                    color: C.text, fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            if (_state.songs.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _state.play(_state.songs[0], 0);
                  _openPlayer(context);
                },
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    gradient: const LinearGradient(colors: [C.accent, C.cyan]),
                    boxShadow: [
                      BoxShadow(
                          color: C.accent.withOpacity(0.35),
                          blurRadius: 14,
                          spreadRadius: 1)
                    ],
                  ),
                  child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        Text('Tout lire',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                      ]),
                ),
              ),
          ]),
        ))),
        if (_state.loading)
          const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(
                      color: C.accent, strokeWidth: 2)))
        else if (_state.songs.isEmpty)
          SliverFillRemaining(
              child: Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                Icon(Icons.music_off_rounded,
                    size: 64, color: C.accent.withOpacity(0.4)),
                const SizedBox(height: 16),
                const Text('Aucune musique trouvée',
                    style: TextStyle(
                        color: C.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('Ajoute des fichiers audio sur ton appareil',
                    style: TextStyle(color: C.sub, fontSize: 13)),
              ])))
        else
          SliverList(
              delegate: SliverChildBuilderDelegate(
            (ctx, i) => _SongTile(song: _state.songs[i], index: i),
            childCount: _state.songs.length,
          )),
        const SliverToBoxAdapter(child: SizedBox(height: 160)),
      ]),
    );
  }
}

void _openPlayer(BuildContext context) {
  Navigator.of(context).push(PageRouteBuilder(
    pageBuilder: (_, a, __) => const PlayerScreen(),
    transitionsBuilder: (_, a, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 450),
  ));
}

// ═══════════════════════════════════════════
//  SONG TILE
// ═══════════════════════════════════════════
class _SongTile extends StatelessWidget {
  final SongModel song;
  final int index;
  const _SongTile({required this.song, required this.index});

  @override
  Widget build(BuildContext context) {
    final isCurrent = _state.current?.id == song.id;
    final isPlaying = isCurrent && _state.playing;

    return GestureDetector(
      onTap: () {
        _state.play(song, index);
        _openPlayer(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: isCurrent ? C.accent.withOpacity(0.12) : C.card,
          border: Border.all(
              color:
                  isCurrent ? C.accent.withOpacity(0.3) : Colors.transparent),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: isCurrent
                  ? const LinearGradient(colors: [C.accent, C.cyan])
                  : null,
              color: isCurrent ? null : C.surface,
            ),
            child: isPlaying
                ? const _PlayingBars()
                : QueryArtworkWidget(
                    id: song.id,
                    type: ArtworkType.AUDIO,
                    artworkBorder: BorderRadius.circular(12),
                    artworkFit: BoxFit.cover,
                    nullArtworkWidget: Center(
                        child: Icon(Icons.music_note_rounded,
                            color: isCurrent ? Colors.white : C.sub, size: 22)),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(song.title,
                    style: TextStyle(
                        color: isCurrent ? C.accent : C.text,
                        fontSize: 14,
                        fontWeight:
                            isCurrent ? FontWeight.w600 : FontWeight.w400),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(song.artist ?? 'Artiste inconnu',
                    style: const TextStyle(color: C.sub, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ])),
          if (song.duration != null)
            Text(_fmtMs(song.duration!),
                style: const TextStyle(color: C.sub, fontSize: 11)),
        ]),
      ),
    );
  }

  String _fmtMs(int ms) {
    final d = Duration(milliseconds: ms);
    return '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }
}

class _PlayingBars extends StatefulWidget {
  const _PlayingBars();
  @override
  State<_PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<_PlayingBars>
    with TickerProviderStateMixin {
  late List<AnimationController> _cs;

  @override
  void initState() {
    super.initState();
    _cs = List.generate(
        3,
        (i) => AnimationController(
            vsync: this, duration: Duration(milliseconds: 350 + i * 80))
          ..repeat(reverse: true));
  }

  @override
  void dispose() {
    for (var c in _cs) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(
              3,
              (i) => AnimatedBuilder(
                    animation: _cs[i],
                    builder: (_, __) => Container(
                        width: 4,
                        height: 4 + 18 * _cs[i].value,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: Colors.white)),
                  )),
        ),
      );
}

// ═══════════════════════════════════════════
//  SEARCH TAB
// ═══════════════════════════════════════════
class SearchTab extends StatefulWidget {
  const SearchTab({super.key});
  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _ctrl = TextEditingController();
  List<SongModel> _results = [];

  @override
  void initState() {
    super.initState();
    _results = _state.songs;
  }

  void _search(String q) {
    setState(() => _results = q.isEmpty
        ? _state.songs
        : _state.songs
            .where((s) =>
                s.title.toLowerCase().contains(q.toLowerCase()) ||
                (s.artist ?? '').toLowerCase().contains(q.toLowerCase()))
            .toList());
  }

  @override
  Widget build(BuildContext context) => SafeArea(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Recherche',
                  style: TextStyle(
                      color: C.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Container(
                height: 50,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: C.card,
                    border: Border.all(color: C.div)),
                child: Row(children: [
                  const SizedBox(width: 14),
                  const Icon(Icons.search_rounded, color: C.sub),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                    controller: _ctrl,
                    onChanged: _search,
                    style: const TextStyle(color: C.text, fontSize: 14),
                    decoration: const InputDecoration(
                        hintText: 'Titres, artistes...',
                        hintStyle: TextStyle(color: C.sub),
                        border: InputBorder.none,
                        isDense: true),
                  )),
                  if (_ctrl.text.isNotEmpty)
                    IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: C.sub, size: 18),
                        onPressed: () {
                          _ctrl.clear();
                          _search('');
                        }),
                ]),
              ),
            ])),
        Expanded(
            child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 160),
          itemCount: _results.length,
          itemBuilder: (ctx, i) => _SongTile(
              song: _results[i], index: _state.songs.indexOf(_results[i])),
        )),
      ]));
}

// ═══════════════════════════════════════════
//  SETTINGS TAB
// ═══════════════════════════════════════════
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Paramètres',
              style: TextStyle(
                  color: C.text, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),

          // Tip banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                  colors: [Color(0xFF1A0E35), Color(0xFF0E1E35)]),
              border: Border.all(color: C.accent.withOpacity(0.3)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient:
                          const LinearGradient(colors: [C.accent, C.cyan]),
                      boxShadow: [
                        BoxShadow(
                            color: C.accent.withOpacity(0.4), blurRadius: 14)
                      ]),
                  child: const Center(
                      child: Text('🎧', style: TextStyle(fontSize: 22)))),
              const SizedBox(width: 14),
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('CONSEIL',
                        style: TextStyle(
                            color: C.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5)),
                    SizedBox(height: 5),
                    Text(
                        'Utilise tes écouteurs pour une meilleure expérience !',
                        style: TextStyle(
                            color: C.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.4)),
                    SizedBox(height: 5),
                    Text(
                        'Les basses et les détails sonores sont bien plus riches avec un bon casque.',
                        style:
                            TextStyle(color: C.sub, fontSize: 12, height: 1.5)),
                  ])),
            ]),
          ),

          const SizedBox(height: 24),
          _Section('Audio', [
            _Item(Icons.equalizer_rounded, 'Égaliseur'),
            _Item(Icons.volume_up_rounded, 'Normalisation du volume'),
            _Item(Icons.timer_rounded, 'Minuterie de sommeil'),
          ]),
          const SizedBox(height: 18),
          _Section('À propos', [
            _Item(Icons.info_rounded, 'Version 1.0.0'),
            _Item(Icons.star_rounded, 'Noter l\'app'),
          ]),
          const SizedBox(height: 160),
        ]),
      ));
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> items;
  const _Section(this.title, this.items);

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(),
            style: const TextStyle(
                color: C.sub,
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15), color: C.card),
          child: Column(
              children: items
                  .asMap()
                  .entries
                  .map((e) => Column(children: [
                        e.value,
                        if (e.key < items.length - 1)
                          const Divider(color: C.div, height: 1, indent: 52),
                      ]))
                  .toList()),
        ),
      ]);
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Item(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: C.accent.withOpacity(0.12)),
              child: Icon(icon, color: C.accent, size: 16)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: C.text, fontSize: 14))),
          const Icon(Icons.chevron_right_rounded, color: C.sub, size: 18),
        ]),
      );
}

// ═══════════════════════════════════════════
//  MINI PLAYER
// ═══════════════════════════════════════════
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (_, __) {
        final song = _state.current;
        if (song == null) return const SizedBox();
        return GestureDetector(
          onTap: () => _openPlayer(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(children: [
              Container(
                  height: 66,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: C.card,
                      border: Border.all(color: C.div))),
              LayoutBuilder(
                  builder: (_, c) => Container(
                        height: 66,
                        width: c.maxWidth * _state.progress,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(colors: [
                            C.accent.withOpacity(0.25),
                            C.cyan.withOpacity(0.1)
                          ]),
                        ),
                      )),
              SizedBox(
                  height: 66,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(11)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: QueryArtworkWidget(
                            id: song.id,
                            type: ArtworkType.AUDIO,
                            artworkFit: BoxFit.cover,
                            artworkBorder: BorderRadius.zero,
                            nullArtworkWidget: Container(
                              decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                      colors: [C.accent, C.cyan])),
                              child: const Icon(Icons.music_note_rounded,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(song.title,
                                style: const TextStyle(
                                    color: C.text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(song.artist ?? 'Artiste inconnu',
                                style:
                                    const TextStyle(color: C.sub, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ])),
                      IconButton(
                          icon: const Icon(Icons.skip_previous_rounded,
                              color: C.text, size: 22),
                          onPressed: _state.prev,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32)),
                      GestureDetector(
                        onTap: _state.toggle,
                        child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient:
                                    LinearGradient(colors: [C.accent, C.cyan])),
                            child: Icon(
                                _state.playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 20)),
                      ),
                      IconButton(
                          icon: const Icon(Icons.skip_next_rounded,
                              color: C.text, size: 22),
                          onPressed: _state.next,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32)),
                    ]),
                  )),
            ]),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════
//  PLAYER SCREEN
// ═══════════════════════════════════════════
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotate, _pulse;

  @override
  void initState() {
    super.initState();
    _rotate =
        AnimationController(vsync: this, duration: const Duration(seconds: 12));
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    if (_state.playing) _rotate.repeat();
    _state.addListener(_sync);
  }

  void _sync() {
    if (_state.playing && !_rotate.isAnimating)
      _rotate.repeat();
    else if (!_state.playing && _rotate.isAnimating) _rotate.stop();
  }

  @override
  void dispose() {
    _state.removeListener(_sync);
    _rotate.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (_, __) {
        final song = _state.current;
        if (song == null) return const SizedBox();
        return Scaffold(
          backgroundColor: C.bg,
          body: Stack(children: [
            // BG
            AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Stack(children: [
                      Positioned(
                          top: -50,
                          left: -50,
                          child: _orb(260 + 18 * _pulse.value, C.accent, 0.2)),
                      Positioned(
                          bottom: -40,
                          right: -40,
                          child: _orb(200, C.cyan, 0.13)),
                    ])),

            SafeArea(
                child: Column(children: [
              // Top bar
              Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.keyboard_arrow_down_rounded,
                              color: C.text, size: 30)),
                      const Text('EN COURS',
                          style: TextStyle(
                              color: C.sub,
                              fontSize: 10,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600)),
                      const Icon(Icons.more_horiz_rounded,
                          color: C.text, size: 24),
                    ],
                  )),

              const SizedBox(height: 12),

              // Album art rotating
              AnimatedBuilder(
                  animation: _rotate,
                  builder: (_, child) => Transform.rotate(
                        angle: _rotate.value * 2 * math.pi,
                        child: child,
                      ),
                  child: Container(
                    width: 230,
                    height: 230,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, boxShadow: [
                      BoxShadow(
                          color: C.accent.withOpacity(0.45),
                          blurRadius: 42,
                          spreadRadius: 8),
                      BoxShadow(
                          color: C.cyan.withOpacity(0.2),
                          blurRadius: 60,
                          spreadRadius: 14),
                    ]),
                    child: ClipOval(
                        child: QueryArtworkWidget(
                      id: song.id,
                      type: ArtworkType.AUDIO,
                      artworkFit: BoxFit.cover,
                      artworkBorder: BorderRadius.zero,
                      nullArtworkWidget: Container(
                        decoration: const BoxDecoration(
                            gradient: LinearGradient(
                                colors: [C.accent, C.cyan],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight)),
                        child: const Center(
                            child: Icon(Icons.music_note_rounded,
                                size: 80, color: Colors.white54)),
                      ),
                    )),
                  )),

              const SizedBox(height: 28),

              // Song info
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(song.title,
                              style: const TextStyle(
                                  color: C.text,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Text(song.artist ?? 'Artiste inconnu',
                              style:
                                  const TextStyle(color: C.sub, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ])),
                    const Icon(Icons.favorite_border_rounded,
                        color: C.pink, size: 24),
                  ])),

              const SizedBox(height: 24),

              // Progress bar
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const _GlowThumb(),
                        overlayShape: SliderComponentShape.noOverlay,
                        activeTrackColor: C.accent,
                        inactiveTrackColor: C.div,
                      ),
                      child: Slider(
                        value: _state.progress.clamp(0.0, 1.0),
                        onChanged: _state.seekTo,
                        min: 0,
                        max: 1,
                      ),
                    ),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_state.fmt(_state.position),
                                style: const TextStyle(
                                    color: C.sub, fontSize: 11)),
                            Text(_state.fmt(_state.duration),
                                style: const TextStyle(
                                    color: C.sub, fontSize: 11)),
                          ],
                        )),
                  ])),

              const SizedBox(height: 28),

              // Controls
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                          onTap: _state.toggleShuffle,
                          child: Icon(Icons.shuffle_rounded,
                              size: 22,
                              color: _state.shuffled ? C.accent : C.sub)),
                      GestureDetector(
                          onTap: _state.prev,
                          child: const Icon(Icons.skip_previous_rounded,
                              color: C.text, size: 34)),
                      GestureDetector(
                        onTap: _state.toggle,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                                colors: [C.accent, C.cyan]),
                            boxShadow: [
                              BoxShadow(
                                color: C.accent
                                    .withOpacity(_state.playing ? 0.6 : 0.3),
                                blurRadius: _state.playing ? 28 : 14,
                                spreadRadius: _state.playing ? 4 : 1,
                              )
                            ],
                          ),
                          child: Icon(
                              _state.playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 34),
                        ),
                      ),
                      GestureDetector(
                          onTap: _state.next,
                          child: const Icon(Icons.skip_next_rounded,
                              color: C.text, size: 34)),
                      GestureDetector(
                          onTap: _state.toggleRepeat,
                          child: Icon(
                            _state.repMode == RepMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                            size: 22,
                            color: _state.repMode != RepMode.none
                                ? C.accent
                                : C.sub,
                          )),
                    ],
                  )),

              const SizedBox(height: 28),

              // Bottom actions
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      (Icons.queue_music_rounded, 'File'),
                      (Icons.share_rounded, 'Partager'),
                      (Icons.equalizer_rounded, 'Égaliseur'),
                      (Icons.timer_rounded, 'Minuterie'),
                    ]
                        .map((e) => Column(children: [
                              Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      color: C.card,
                                      border: Border.all(color: C.div)),
                                  child: Icon(e.$1, color: C.sub, size: 22)),
                              const SizedBox(height: 5),
                              Text(e.$2,
                                  style: const TextStyle(
                                      color: C.sub, fontSize: 10)),
                            ]))
                        .toList(),
                  )),
            ])),
          ]),
        );
      },
    );
  }

  Widget _orb(double size, Color color, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
                colors: [color.withOpacity(opacity), Colors.transparent])),
      );
}

class _GlowThumb extends SliderComponentShape {
  const _GlowThumb();
  @override
  Size getPreferredSize(bool a, bool b) => const Size(20, 20);
  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final c = context.canvas;
    c.drawCircle(
        center,
        14,
        Paint()
          ..color = C.accent.withOpacity(0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    c.drawCircle(
        center,
        9,
        Paint()
          ..shader = const LinearGradient(colors: [C.accent, C.cyan])
              .createShader(Rect.fromCircle(center: center, radius: 9)));
    c.drawCircle(center, 4, Paint()..color = Colors.white);
  }
}
