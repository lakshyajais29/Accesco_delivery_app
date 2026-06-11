import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../services/vibe_check_service.dart';
// ─── DESIGN TOKENS ───────────────────────────────────────────────────────────
class _C {
  static const white   = Color(0xFFFFFFFF);
  static const bg      = Color(0xFFFFFFFF);
  static const grey100 = Color(0xFFF5F5F5);
  static const grey150 = Color(0xFFEEEEEE);
  static const grey300 = Color(0xFFCCCCCC);
  static const grey500 = Color(0xFF999999);
  static const grey700 = Color(0xFF555555);
  static const dark    = Color(0xFF0D0D0D);
  static const magenta = Color(0xFFE91E8C);
  static const sale    = Color(0xFFE53935);
  static const amber   = Color(0xFFFF6F00);
  static const purple  = Color(0xFF7C3AED);
}

class _T {
  static TextStyle display(double size,
          {Color color = _C.dark, double spacing = 0}) =>
      GoogleFonts.bebasNeue(
          fontSize: size, color: color, letterSpacing: spacing);

  static TextStyle label(double size,
          {Color color = _C.dark,
          FontWeight fw = FontWeight.w600,
          double spacing = 0.5}) =>
      GoogleFonts.jost(
          fontSize: size, fontWeight: fw, color: color, letterSpacing: spacing);

  static TextStyle body(double size,
          {Color color = _C.grey700, FontWeight fw = FontWeight.w400}) =>
      GoogleFonts.jost(fontSize: size, fontWeight: fw, color: color);
}

// ─── MODEL ───────────────────────────────────────────────────────────────────
class AppFriend {
  final String  userId;
  final String  name;
  final String  initial;
  final Color   color;
  final String? phone;

  const AppFriend({
    required this.userId,
    required this.name,
    required this.initial,
    required this.color,
    this.phone,
  });
}


// ─── CONSTANTS ───────────────────────────────────────────────────────────────
const _kProductId        = 'saree_maison_kaira_001';
const _kProductName      = 'MAISON KAIRA';
const _kProductCategory  = 'Festive Saree';
const _kProductPrice     = '₹18,500';
const _kProductStock     = 2;
const _kProductImage     =
    'https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=600&q=85';
const _kUserName         = 'Priya';
const _kVibeCheckBaseUrl = 'https://tattered-yo-yo-duvet.ngrok-free.dev/vote';

// ─────────────────────────────────────────────────────────────────────────────
// VIBE CHECK SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class VibeCheckScreen extends StatefulWidget {
  const VibeCheckScreen({super.key});
  @override
  State<VibeCheckScreen> createState() => _VibeCheckScreenState();
}

class _VibeCheckScreenState extends State<VibeCheckScreen>
    with TickerProviderStateMixin {

  final _vibeService    = VibeCheckService();

  List<AppFriend> _appFriends     = [];
  bool            _loadingFriends = true;
  String?         _friendsError;

  int                 _phase           = 0;
  final Set<int>      _selectedFriends = {};
  Map<String, String> _reactions       = {};

  String?             _vibeCheckId;
  StreamSubscription? _reactionSub;
  StreamSubscription? _stockSub;
  bool                _creatingVibeCheck = false;

  late final AnimationController _barCtrl;
  late final Animation<double>   _barAnim;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;
  late final AnimationController _fomoCtrl;
  late final Animation<double>   _fomoAnim;
  late final AnimationController _ctaCtrl;
  bool _fomoActive = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    _barCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _barAnim = CurvedAnimation(parent: _barCtrl, curve: Curves.easeOut);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _fomoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fomoAnim = CurvedAnimation(parent: _fomoCtrl, curve: Curves.easeOut);

    _ctaCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _loadFriends();
  }

  @override
  void dispose() {
    _reactionSub?.cancel();
    _stockSub?.cancel();
    _barCtrl.dispose();
    _pulseCtrl.dispose();
    _fomoCtrl.dispose();
    _ctaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() { _loadingFriends = true; _friendsError = null; });
    try {
      if (mounted) setState(() { _appFriends = []; _loadingFriends = false; });
    } catch (e) {
      if (mounted) setState(() {
        _friendsError   = 'Could not load friends. Tap to retry.';
        _loadingFriends = false;
      });
    }
  }

  // ── Goes to Phase 1 purely for sharing the app invite (no friends yet) ────
  Future<void> _goToInviteOnly() async {
    await _goTo(1);  // ← same as normal flow, creates vibe check first
}

  // ── Main phase transition ─────────────────────────────────────────────────
  Future<void> _goTo(int phase) async {

    // PHASE 1 — create Firestore doc so share link has a real ID
    if (phase == 1) {
      if (_creatingVibeCheck) return;
      setState(() => _creatingVibeCheck = true);
      try {
        final ids = _selectedFriends
            .map((i) => _appFriends[i].userId)
            .toList();
        _vibeCheckId = await _vibeService.createVibeCheck(
          productId       : _kProductId,
          productName     : _kProductName,
          productCategory : _kProductCategory,
          productPrice    : _kProductPrice,
          productImage    : _kProductImage,
          productStock    : _kProductStock,
          friendUserIds   : ids,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to create Vibe Check: $e'),
            backgroundColor: _C.sale,
          ));
        }
        setState(() => _creatingVibeCheck = false);
        return;
      }
      setState(() => _creatingVibeCheck = false);
    }

    // PHASE 2 — attach Firestore listeners (doc already exists)
    if (phase == 2) {
      if (_vibeCheckId == null) return;

      _reactionSub?.cancel();
      _reactionSub = _vibeService
          .reactionsStream(_vibeCheckId!)
          .listen((reactions) {
        if (!mounted) return;
        setState(() => _reactions = reactions);
        if (reactions.length == _selectedFriends.length) {
          Future.delayed(const Duration(milliseconds: 900), () {
            if (mounted && _phase == 3) _goTo(4);
          });
        }
      }, onError: (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Connection issue: $e'),
            backgroundColor: _C.dark,
          ));
        }
      });

      _stockSub?.cancel();
      _stockSub = _vibeService.stockStream(_kProductId).listen((stock) {
        if (!mounted) return;
        if (stock <= 2 && !_fomoActive) {
          setState(() => _fomoActive = true);
          _fomoCtrl.forward();
        }
      });
    }

    if (phase == 4) _barCtrl.forward(from: 0);
    if (phase == 5) _ctaCtrl.forward(from: 0);
    setState(() => _phase = phase);
  }

  int get _yesCount   => _reactions.values.where((r) => r == 'YES').length;
  int get _maybeCount => _reactions.values.where((r) => r == 'MAYBE').length;
  int get _noCount    => _reactions.values.where((r) => r == 'NO').length;
  int get _total      => _selectedFriends.length;

  String? _reactionForIndex(int idx) {
    if (idx >= _appFriends.length) return null;
    return _reactions[_appFriends[idx].userId];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0.06, 0), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                ),
                child: _buildPhase(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _phaseTitles = [
    'ASK YOUR CREW', 'PREVIEW CARD', 'VIBE CHECK SENT!',
    'WAITING ON CREW...', 'RESULTS ARE IN', 'ORDER NOW',
  ];
  static const _phaseSubs = [
    'Select up to 5 friends',
    'This is what your friends will see',
    'Your squad got the notification',
    'Friends are reacting live...',
    'Your crew has spoken',
    'Your crew said YES',
  ];

  Widget _buildHeader() {
    final c = _phase.clamp(0, _phaseTitles.length - 1);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: _C.white,
        border: Border(bottom: BorderSide(color: _C.grey150)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              if (_phase > 0 && _phase < 3) setState(() => _phase--);
              else if (_phase == 0) Navigator.pop(context);
            },
            child: const Icon(Icons.arrow_back, size: 22, color: _C.dark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_phaseTitles[c], style: _T.display(20, spacing: 1.2)),
                Text(_phaseSubs[c], style: _T.body(11)),
              ],
            ),
          ),
          Row(
            children: List.generate(6, (i) {
              final done   = _phase > i;
              final active = _phase == i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                margin: const EdgeInsets.only(left: 3),
                width: active ? 18 : 5,
                height: 3,
                decoration: BoxDecoration(
                  color: done
                      ? _C.magenta.withOpacity(0.4)
                      : active ? _C.magenta : _C.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case 0:
        return _Phase0FriendSelect(
          key        : const ValueKey(0),
          appFriends : _appFriends,
          selected   : _selectedFriends,
          loading    : _loadingFriends,
          isCreating : _creatingVibeCheck,
          errorMsg   : _friendsError,
          onRetry    : _loadFriends,
          onInvite   : _goToInviteOnly,           // ← invite-only path
          onToggle   : (i) => setState(() {
            _selectedFriends.contains(i)
                ? _selectedFriends.remove(i)
                : _selectedFriends.length < 5
                    ? _selectedFriends.add(i)
                    : null;
          }),
          onNext     : (_selectedFriends.isNotEmpty && !_creatingVibeCheck)
              ? () => _goTo(1)
              : null,
        );
      case 1:
        return Phase1ShareCard(
          key         : ValueKey('phase1_${_vibeCheckId ?? 'null'}'), // ← rebuilds when ID arrives
          vibeCheckId : _vibeCheckId,
          onNext      : () => _goTo(2),
        );
      case 2:
        return _Phase2NotificationPreview(
          key           : const ValueKey(2),
          selectedCount : _selectedFriends.length,
          isCreating    : false,
          onNext        : () => _goTo(3),
        );
      case 3:
        return _Phase3ReactionsIncoming(
          key             : const ValueKey(3),
          appFriends      : _appFriends,
          selectedFriends : _selectedFriends,
          reactionForIdx  : _reactionForIndex,
          total           : _total,
          yesCount        : _yesCount,
        );
      case 4:
        return _Phase4Results(
          key             : const ValueKey(4),
          appFriends      : _appFriends,
          selectedFriends : _selectedFriends,
          reactionForIdx  : _reactionForIndex,
          yesCount        : _yesCount,
          maybeCount      : _maybeCount,
          noCount         : _noCount,
          total           : _total,
          fomoActive      : _fomoActive,
          fomoAnim        : _fomoAnim,
          barAnim         : _barAnim,
          pulseAnim       : _pulseAnim,
          onOrder         : () => _goTo(5),
        );
      case 5:
        return _Phase5CTA(
          key        : const ValueKey(5),
          yesCount   : _yesCount,
          total      : _total,
          fomoActive : _fomoActive,
          ctaCtrl    : _ctaCtrl,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PHASE 0 — FRIEND SELECTION
// ─────────────────────────────────────────────────────────────────────────────
class _Phase0FriendSelect extends StatelessWidget {
  final List<AppFriend>    appFriends;
  final Set<int>           selected;
  final bool               loading;
  final bool               isCreating;
  final String?            errorMsg;
  final VoidCallback       onRetry;
  final VoidCallback       onInvite;      // ← NEW
  final void Function(int) onToggle;
  final VoidCallback?      onNext;

  const _Phase0FriendSelect({
    super.key,
    required this.appFriends,
    required this.selected,
    required this.loading,
    required this.isCreating,
    required this.errorMsg,
    required this.onRetry,
    required this.onInvite,               // ← NEW
    required this.onToggle,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _OutfitMiniCard(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
          child: Row(
            children: [
              Text('YOUR CREW', style: _T.display(22, spacing: 1)),
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                color: selected.isNotEmpty ? _C.magenta : _C.grey150,
                child: Text(
                  '${selected.length} / 5',
                  style: _T.label(12,
                      color: selected.isNotEmpty ? _C.white : _C.grey500,
                      spacing: 0),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Tap to select · max 5 friends', style: _T.body(12)),
          ),
        ),
        Expanded(child: _buildBody()),
        _BottomCta(
          label    : isCreating ? 'CREATING VIBE CHECK...' : 'SEND VIBE CHECK',
          subLabel : isCreating
              ? 'Setting up your vibe check…'
              : selected.isNotEmpty
                  ? 'Asking ${selected.length} friend${selected.length > 1 ? 's' : ''}'
                  : 'Select at least 1 friend',
          enabled  : onNext != null,
          onTap    : onNext,
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (loading) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(strokeWidth: 2, color: _C.magenta),
          const SizedBox(height: 16),
          Text('Finding friends on InstaStyle…', style: _T.body(13)),
        ],
      );
    }
    if (errorMsg != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 36, color: _C.grey300),
          const SizedBox(height: 12),
          Text(errorMsg!, style: _T.body(13), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              color: _C.dark,
              child: Text('RETRY',
                  style: _T.label(12, color: _C.white, spacing: 1)),
            ),
          ),
        ],
      );
    }
    if (appFriends.isEmpty) {
      // ── FIXED: real invite button instead of dead text hint ───────────────
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.magenta.withOpacity(0.08),
            ),
            child: const Icon(Icons.group_add_outlined,
                size: 34, color: _C.magenta),
          ),
          const SizedBox(height: 16),
          Text('No friends on InstaStyle yet.',
              style: _T.label(14, color: _C.dark, spacing: 0)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Share the app with your crew and get them on board.',
              style: _T.body(12),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onInvite,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 14),
              color: _C.magenta,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.ios_share, color: _C.white, size: 16),
                  const SizedBox(width: 8),
                  Text('SHARE INVITE CARD',
                      style: _T.label(13, color: _C.white, spacing: 1)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onInvite,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chat, size: 15, color: _C.grey500),
                const SizedBox(width: 6),
                Text('Share via WhatsApp, Instagram & more',
                    style: _T.body(11, color: _C.grey500)),
              ],
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, mainAxisSpacing: 22,
        crossAxisSpacing: 10, childAspectRatio: 0.72,
      ),
      itemCount: appFriends.length,
      itemBuilder: (_, i) {
        final f          = appFriends[i];
        final isSelected = selected.contains(i);
        final isFull     = selected.length >= 5 && !isSelected;
        return GestureDetector(
          onTap: (isFull || isCreating) ? null : () => onToggle(i),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isFull ? 0.4 : 1.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 62, height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? _C.magenta : _C.grey300,
                      width: isSelected ? 2.5 : 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              f.color.withOpacity(isSelected ? 1.0 : 0.65),
                          child: Text(f.initial,
                              style: _T.label(20, color: _C.white, spacing: 0)),
                        ),
                        if (isSelected)
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              width: 19, height: 19,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _C.magenta,
                                border: Border.all(color: _C.white, width: 1.5),
                              ),
                              child: const Icon(Icons.check,
                                  size: 11, color: _C.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(f.name,
                    style: _T.label(10,
                        color: isSelected ? _C.dark : _C.grey500, spacing: 0),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PHASE 1 — SHARE CARD
// ─────────────────────────────────────────────────────────────────────────────
class Phase1ShareCard extends StatefulWidget {
  final String?      vibeCheckId;
  final VoidCallback onNext;

  const Phase1ShareCard({
    super.key,
    required this.vibeCheckId,
    required this.onNext,
  });

  @override
  State<Phase1ShareCard> createState() => _Phase1ShareCardState();
}

class _Phase1ShareCardState extends State<Phase1ShareCard> {
  final _screenshotCtrl = ScreenshotController();
  bool  _sharing        = false;

  Future<void> _shareCard() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final Uint8List? bytes = await _screenshotCtrl.capture(
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 100),
      );
      if (bytes == null) { _showError('Could not capture card.'); return; }

      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/instastyle_vibe_check.png');
      await file.writeAsBytes(bytes);

      final link = widget.vibeCheckId != null
    ? '$_kVibeCheckBaseUrl/${widget.vibeCheckId}'  // → /vote/{id}  ✓
    : _kVibeCheckBaseUrl;

      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text    : '$_kUserName wants your take on $_kProductName 👀\n'
                  'Should she get it? YES 🔥  MAYBE 🤔  NO ❌\n\n$link',
        subject : 'Vibe Check from $_kUserName — $_kProductName',
        sharePositionOrigin: _origin(),
      );

      if (result.status == ShareResultStatus.success) {
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      _showError('Share failed: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Rect _origin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return Rect.zero;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: _T.body(13, color: _C.white)),
      backgroundColor: _C.sale,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              children: [
                // Show different header depending on whether this is an
                // invite-only flow (no vibeCheckId) or a real vibe check
                Text(
                  widget.vibeCheckId != null
                      ? 'This is what your friends will see'
                      : 'Invite your crew to InstaStyle',
                  style: _T.body(13, color: _C.grey700),
                ),
                const SizedBox(height: 16),
                Screenshot(
                  controller: _screenshotCtrl,
                  child: const _ShareableCard(),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.vibeCheckId != null
                      ? 'Price visible only to you · $_kProductPrice'
                      : 'Share this card to invite friends',
                  style: _T.body(11, color: _C.grey500),
                ),
                const SizedBox(height: 24),
                _QuickShareRow(onTap: _shareCard),
              ],
            ),
          ),
        ),
        _ShareBottomCta(
          sharing      : _sharing,
          onShare      : _shareCard,
          // If invite-only, "skip" goes back to phase 0 instead of forward
          onNext       : widget.onNext,
          isInviteOnly : widget.vibeCheckId == null,
        ),
      ],
    );
  }
}

// ── Capturable card ───────────────────────────────────────────────────────────
class _ShareableCard extends StatelessWidget {
  const _ShareableCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration:
          BoxDecoration(border: Border.all(color: _C.magenta, width: 2.5)),
      child: Column(
        children: [
          Container(
            color: _C.magenta,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.style, color: _C.white, size: 16),
                const SizedBox(width: 8),
                Text('INSTASTYLE',
                    style: _T.display(16, color: _C.white, spacing: 1.5)),
                const Spacer(),
                Text('VIBE CHECK',
                    style: _T.label(9,
                        color: _C.white.withOpacity(0.85), spacing: 2)),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(fit: StackFit.expand, children: [
              Image.network(_kProductImage,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, p) => p == null
                      ? child
                      : Container(
                          color: _C.grey150,
                          child: const Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5, color: _C.magenta))),
                  errorBuilder: (_, __, ___) =>
                      Container(color: _C.grey150)),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xCC000000)],
                    stops: [0.5, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 12, right: 12,
                child: Opacity(
                  opacity: 0.55,
                  child: Text('INSTASTYLE',
                      style: _T.display(11, color: _C.white, spacing: 2)),
                ),
              ),
              Positioned(
                bottom: 16, left: 14, right: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      color: _C.magenta,
                      child: Text('$_kUserName wants your take 👀',
                          style: _T.label(11, color: _C.white, spacing: 0.3)),
                    ),
                    const SizedBox(height: 8),
                    Text(_kProductName,
                        style: _T.display(28, color: _C.white, spacing: 0.5)),
                    Text(_kProductCategory,
                        style: _T.body(12, color: const Color(0xCCFFFFFF))),
                  ],
                ),
              ),
            ]),
          ),
          Container(
            color: _C.dark,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ReactionChip(label: 'YES',   emoji: '🔥', bg: _C.magenta),
                _ReactionChip(label: 'MAYBE', emoji: '🤔', bg: _C.amber),
                _ReactionChip(label: 'NO',    emoji: '❌', bg: _C.grey700),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String label, emoji;
  final Color  bg;
  const _ReactionChip(
      {required this.label, required this.emoji, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: bg,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text(label, style: _T.label(11, color: _C.white, spacing: 1)),
        ],
      ),
    );
  }
}

class _QuickShareRow extends StatelessWidget {
  final VoidCallback onTap;
  const _QuickShareRow({required this.onTap});

  static const _apps = [
    _AppShortcut(label: 'WhatsApp',  color: Color(0xFF25D366), icon: Icons.chat_bubble),
    _AppShortcut(label: 'Instagram', color: Color(0xFFE1306C), icon: Icons.camera_alt),
    _AppShortcut(label: 'Messages',  color: Color(0xFF34AADC), icon: Icons.sms),
    _AppShortcut(label: 'More',      color: _C.grey700,        icon: Icons.more_horiz),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SHARE TO',
            style: _T.display(13, color: _C.grey500, spacing: 1.5)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _apps.map((app) => GestureDetector(
            onTap: onTap,
            child: Column(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: app.color.withOpacity(0.12),
                    border: Border.all(
                        color: app.color.withOpacity(0.3), width: 1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(app.icon, color: app.color, size: 24),
                ),
                const SizedBox(height: 6),
                Text(app.label, style: _T.body(10)),
              ],
            ),
          )).toList(),
        ),
      ],
    );
  }
}

class _AppShortcut {
  final String   label;
  final Color    color;
  final IconData icon;
  const _AppShortcut(
      {required this.label, required this.color, required this.icon});
}

class _ShareBottomCta extends StatelessWidget {
  final bool         sharing;
  final VoidCallback onShare;
  final VoidCallback onNext;
  final bool         isInviteOnly;   // ← NEW

  const _ShareBottomCta({
    required this.sharing,
    required this.onShare,
    required this.onNext,
    required this.isInviteOnly,     // ← NEW
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        border: Border(top: BorderSide(color: _C.grey150)),
      ),
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: sharing ? null : onShare,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: sharing ? _C.grey300 : _C.magenta,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (sharing)
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _C.white),
                    )
                  else
                    const Icon(Icons.ios_share, color: _C.white, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    sharing ? 'PREPARING SHARE...' : 'SHARE CARD',
                    style: _T.label(14, color: _C.white, spacing: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // In invite-only mode show "BACK" instead of "SKIP"
          GestureDetector(
            onTap: onNext,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: _C.dark,
              child: Center(
                child: Text(
                  isInviteOnly
                      ? '← BACK TO FRIEND SELECT'
                      : 'SKIP → WAIT FOR REACTIONS',
                  style: _T.label(12,
                      color: _C.white.withOpacity(0.7), spacing: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PHASE 2 — NOTIFICATION PREVIEW
// ─────────────────────────────────────────────────────────────────────────────
class _Phase2NotificationPreview extends StatefulWidget {
  final int          selectedCount;
  final bool         isCreating;
  final VoidCallback onNext;

  const _Phase2NotificationPreview({
    super.key,
    required this.selectedCount,
    required this.isCreating,
    required this.onNext,
  });

  @override
  State<_Phase2NotificationPreview> createState() =>
      _Phase2NotificationPreviewState();
}

class _Phase2NotificationPreviewState
    extends State<_Phase2NotificationPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset>   _slide;
  late final Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _slide = Tween<Offset>(
            begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF00C853)),
                      child: widget.isCreating
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _C.white))
                          : const Icon(Icons.check,
                              color: _C.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vibe Check Sent!',
                            style: _T.label(15, color: _C.dark, spacing: 0)),
                        Text(
                          widget.isCreating
                              ? 'Sending notifications…'
                              : 'Notified ${widget.selectedCount} friend${widget.selectedCount > 1 ? 's' : ''}',
                          style: _T.body(12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text('WHAT THEY SEE',
                    style: _T.display(14, color: _C.grey500, spacing: 1.5)),
                const SizedBox(height: 12),
                SlideTransition(
                  position: _slide,
                  child: FadeTransition(
                    opacity: _fade,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: _C.magenta,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: const Center(
                                      child: Icon(Icons.style,
                                          color: _C.white, size: 18)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Text('INSTASTYLE',
                                            style: _T.label(11,
                                                color: _C.dark, spacing: 0)),
                                        const Spacer(),
                                        Text('now',
                                            style: _T.body(11,
                                                color: _C.grey500)),
                                      ]),
                                      Text('$_kUserName wants your take 👀',
                                          style: _T.body(12,
                                              color: _C.dark,
                                              fw: FontWeight.w500)),
                                      Text(
                                          '$_kProductName · $_kProductCategory',
                                          style: _T.body(11,
                                              color: _C.grey500)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(_kProductImage,
                                      width: 44, height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          Container(
                                              width: 44, height: 44,
                                              color: _C.grey300)),
                                ),
                              ],
                            ),
                          ),
                          const Divider(
                              height: 1, color: Color(0xFFD8D8DC)),
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                _NotifAction(label: 'YES 🔥',
                                    color: _C.magenta, isFirst: true),
                                const VerticalDivider(
                                    width: 1, color: Color(0xFFD8D8DC)),
                                _NotifAction(label: 'MAYBE 🤔',
                                    color: _C.amber, isFirst: false),
                                const VerticalDivider(
                                    width: 1, color: Color(0xFFD8D8DC)),
                                _NotifAction(label: 'NO ❌',
                                    color: _C.grey700, isFirst: false),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text('WHAT HAPPENS NEXT',
                    style: _T.display(14, color: _C.grey500, spacing: 1.5)),
                const SizedBox(height: 14),
                ...[
                  ('👆', 'Friends react instantly',
                      'YES, MAYBE, or NO — no typing needed'),
                  ('📊', 'See the live tally',
                      'Real-time vote count with animated bar'),
                  ('⚡', 'FOMO alert if stock drops',
                      'Red banner fires if stock runs low'),
                  ('🛍️', 'One-tap to order',
                      'If your crew votes YES, checkout is instant'),
                ].map((e) => _NextStep(emoji: e.$1, title: e.$2, sub: e.$3)),
              ],
            ),
          ),
        ),
        _BottomCta(
          label    : 'SEE FRIEND REACTIONS',
          subLabel : 'Waiting for live reactions now',
          enabled  : !widget.isCreating,
          onTap    : widget.isCreating ? null : widget.onNext,
        ),
      ],
    );
  }
}

class _NotifAction extends StatelessWidget {
  final String label;
  final Color  color;
  final bool   isFirst;
  const _NotifAction(
      {required this.label, required this.color, required this.isFirst});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(label,
                style: _T.label(11, color: color, spacing: 0.2)),
          ),
        ),
      );
}

class _NextStep extends StatelessWidget {
  final String emoji, title, sub;
  const _NextStep(
      {required this.emoji, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            color: _C.grey100,
            child: Center(
                child: Text(emoji,
                    style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: _T.label(12, color: _C.dark, spacing: 0)),
                Text(sub, style: _T.body(11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PHASE 3 — REACTIONS INCOMING
// ─────────────────────────────────────────────────────────────────────────────
class _Phase3ReactionsIncoming extends StatelessWidget {
  final List<AppFriend>       appFriends;
  final Set<int>              selectedFriends;
  final String? Function(int) reactionForIdx;
  final int                   total;
  final int                   yesCount;

  const _Phase3ReactionsIncoming({
    super.key,
    required this.appFriends,
    required this.selectedFriends,
    required this.reactionForIdx,
    required this.total,
    required this.yesCount,
  });

  @override
  Widget build(BuildContext context) {
    final selected     = selectedFriends.toList()..sort();
    final reactedCount =
        selected.where((i) => reactionForIdx(i) != null).length;
    final pending = total - reactedCount;

    return Column(
      children: [
        const _OutfitMiniCard(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
          child: Row(
            children: [
              Text('CREW REACTING', style: _T.display(22, spacing: 1)),
              const Spacer(),
              if (yesCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  color: _C.magenta,
                  child: Text('$yesCount YES',
                      style: _T.label(11, color: _C.white, spacing: 0)),
                ),
            ],
          ),
        ),
        if (pending > 0)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: _C.grey500),
                  ),
                  const SizedBox(width: 8),
                  Text('Waiting on $pending more...',
                      style: _T.body(12, color: _C.grey500)),
                ],
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: selected.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: _C.grey150),
            itemBuilder: (_, i) {
              final idx = selected[i];
              return _FriendReactionRow(
                friend   : appFriends[idx],
                reaction : reactionForIdx(idx),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FriendReactionRow extends StatelessWidget {
  final AppFriend friend;
  final String?   reaction;
  const _FriendReactionRow(
      {required this.friend, required this.reaction});

  @override
  Widget build(BuildContext context) {
    final reacted = reaction != null;
    Color  rc    = _C.grey500;
    String rl    = 'Thinking...';
    String emoji = '⏳';

    if (reaction == 'YES')   { rc = _C.magenta; rl = 'YES';   emoji = '🔥'; }
    if (reaction == 'MAYBE') { rc = _C.amber;   rl = 'MAYBE'; emoji = '🤔'; }
    if (reaction == 'NO')    { rc = _C.grey700; rl = 'NO';    emoji = '❌'; }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: reacted ? rc : _C.grey300,
                  width: reacted ? 2.0 : 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: CircleAvatar(
                backgroundColor:
                    friend.color.withOpacity(reacted ? 1.0 : 0.5),
                child: Text(friend.initial,
                    style: _T.label(16, color: _C.white, spacing: 0)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.name,
                    style: _T.label(13, color: _C.dark, spacing: 0)),
                Text(reacted ? 'Voted $reaction' : 'Waiting...',
                    style: _T.body(11,
                        color: reacted ? rc : _C.grey500)),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: reacted
                ? Container(
                    key: ValueKey(reaction),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    constraints: const BoxConstraints(minHeight: 44),
                    color: rc,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji,
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(rl,
                            style: _T.label(12,
                                color: _C.white, spacing: 0.8)),
                      ],
                    ),
                  )
                : Container(
                    key: const ValueKey('pending'),
                    width: 24, height: 24,
                    child: const CircularProgressIndicator(
                        strokeWidth: 2, color: _C.grey300),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PHASE 4 — RESULTS
// ─────────────────────────────────────────────────────────────────────────────
class _Phase4Results extends StatelessWidget {
  final List<AppFriend>       appFriends;
  final Set<int>              selectedFriends;
  final String? Function(int) reactionForIdx;
  final int                   yesCount, maybeCount, noCount, total;
  final bool                  fomoActive;
  final Animation<double>     fomoAnim, barAnim, pulseAnim;
  final VoidCallback          onOrder;

  const _Phase4Results({
    super.key,
    required this.appFriends,
    required this.selectedFriends,
    required this.reactionForIdx,
    required this.yesCount,
    required this.maybeCount,
    required this.noCount,
    required this.total,
    required this.fomoActive,
    required this.fomoAnim,
    required this.barAnim,
    required this.pulseAnim,
    required this.onOrder,
  });

  @override
  Widget build(BuildContext context) {
    final yf = total > 0 ? yesCount / total   : 0.0;
    final mf = total > 0 ? maybeCount / total  : 0.0;
    final nf = total > 0 ? noCount / total     : 0.0;

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$yesCount of $total say YES',
                            style: _T.display(34, spacing: 0.5)),
                        const SizedBox(width: 8),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text('🔥',
                              style: TextStyle(fontSize: 22)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      yesCount >= total * 0.7
                          ? 'Your crew loves it — go for it!'
                          : 'Mixed signals from your crew.',
                      style: _T.body(13, color: _C.grey700),
                    ),
                    const SizedBox(height: 22),
                    _VoteBar(label: 'YES',   fraction: yf,
                        count: yesCount,   color: _C.magenta,
                        barAnim: barAnim),
                    const SizedBox(height: 10),
                    _VoteBar(label: 'MAYBE', fraction: mf,
                        count: maybeCount, color: _C.amber,
                        barAnim: barAnim),
                    const SizedBox(height: 10),
                    _VoteBar(label: 'NO',    fraction: nf,
                        count: noCount,    color: _C.grey500,
                        barAnim: barAnim),
                    const SizedBox(height: 28),
                    Text('WHO VOTED',
                        style: _T.display(14,
                            color: _C.grey500, spacing: 1.5)),
                    const SizedBox(height: 12),
                    _StackedVoters(
                      appFriends      : appFriends,
                      selectedFriends : selectedFriends,
                      reactionForIdx  : reactionForIdx,
                    ),
                    const SizedBox(height: 28),
                    Text('THE OUTFIT',
                        style: _T.display(14,
                            color: _C.grey500, spacing: 1.5)),
                    const SizedBox(height: 10),
                    _OutfitResultCard(pulseAnim: pulseAnim),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            _BottomCta(
              label    : fomoActive
                  ? 'ORDER NOW — ALMOST GONE'
                  : 'ORDER NOW  →',
              subLabel : fomoActive
                  ? 'Only $_kProductStock left · $_kProductPrice'
                  : '$yesCount friends said YES · $_kProductPrice',
              enabled  : true,
              onTap    : onOrder,
              urgent   : fomoActive,
            ),
          ],
        ),
        if (fomoActive)
          Positioned(
            left: 0, right: 0, bottom: 90,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0, 1), end: Offset.zero)
                  .animate(fomoAnim),
              child: FadeTransition(
                  opacity: fomoAnim,
                  child: _FomoBanner(pulseAnim: pulseAnim)),
            ),
          ),
      ],
    );
  }
}

class _VoteBar extends StatelessWidget {
  final String            label;
  final double            fraction;
  final int               count;
  final Color             color;
  final Animation<double> barAnim;

  const _VoteBar({
    required this.label, required this.fraction,
    required this.count, required this.color,
    required this.barAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(label,
              style: _T.label(12, color: _C.dark, spacing: 0.5)),
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: barAnim,
            builder: (_, __) => Container(
              height: 10,
              decoration: BoxDecoration(
                  color: _C.grey150,
                  borderRadius: BorderRadius.circular(2)),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fraction * barAnim.value,
                  child: Container(
                    decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 18,
          child: Text('$count',
              style: _T.label(12, color: color, spacing: 0),
              textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

class _StackedVoters extends StatelessWidget {
  final List<AppFriend>       appFriends;
  final Set<int>              selectedFriends;
  final String? Function(int) reactionForIdx;

  const _StackedVoters({
    required this.appFriends,
    required this.selectedFriends,
    required this.reactionForIdx,
  });

  @override
  Widget build(BuildContext context) {
    final selected = selectedFriends.toList()..sort();
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: selected.map((idx) {
        final f  = appFriends[idx];
        final r  = reactionForIdx(idx);
        Color rc = _C.grey300;
        if (r == 'YES')   rc = _C.magenta;
        if (r == 'MAYBE') rc = _C.amber;
        if (r == 'NO')    rc = _C.grey700;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: rc, width: 2)),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  backgroundColor: f.color,
                  child: Text(f.initial,
                      style: _T.label(14, color: _C.white, spacing: 0)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(r ?? '—', style: _T.label(9, color: rc, spacing: 0)),
          ],
        );
      }).toList(),
    );
  }
}

class _OutfitResultCard extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _OutfitResultCard({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Image.network(_kProductImage,
              width: 80, height: 100, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(width: 80, height: 100, color: _C.grey150)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_kProductName,
                  style: _T.label(13, color: _C.dark, spacing: 0)),
              Text(_kProductCategory, style: _T.body(12)),
              const SizedBox(height: 6),
              Text(_kProductPrice,
                  style: _T.label(15, color: _C.dark, spacing: 0)),
              const SizedBox(height: 4),
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, __) => Row(
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _C.sale.withOpacity(
                            0.5 + 0.5 * pulseAnim.value),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text('Only $_kProductStock left in your size',
                        style: _T.label(10,
                            color: _C.sale, spacing: 0)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FomoBanner extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _FomoBanner({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, child) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: _C.sale,
          boxShadow: [
            BoxShadow(
              color: _C.sale.withOpacity(0.4 + 0.2 * pulseAnim.value),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
      child: Row(
        children: [
          const Text('⚡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stock dropping — $_kProductStock left in your size.',
                  style: _T.label(12, color: _C.white, spacing: 0.2),
                ),
                Text('Others are eyeing this right now.',
                    style: _T.body(11,
                        color: _C.white.withOpacity(0.75))),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios,
              color: _C.white, size: 14),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PHASE 5 — FINAL CTA
// ─────────────────────────────────────────────────────────────────────────────
class _Phase5CTA extends StatelessWidget {
  final int                 yesCount, total;
  final bool                fomoActive;
  final AnimationController ctaCtrl;

  const _Phase5CTA({
    super.key,
    required this.yesCount,
    required this.total,
    required this.fomoActive,
    required this.ctaCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctaCtrl,
      builder: (_, child) =>
          FadeTransition(opacity: ctaCtrl, child: child),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(_kProductImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: _C.grey150)),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        _C.dark.withOpacity(0.9),
                      ],
                      stops: const [0.3, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  left: 20, right: 20, bottom: 28,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 60, height: 24,
                            child: Stack(
                              children: List.generate(
                                  min(4, yesCount), (i) {
                                final cols = [
                                  _C.magenta, _C.purple,
                                  const Color(0xFF00BCD4), _C.amber,
                                ];
                                return Positioned(
                                  left: i * 14.0,
                                  child: Container(
                                    width: 24, height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: cols[i % cols.length],
                                      border: Border.all(
                                          color: _C.dark, width: 1.5),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$yesCount of $total friends said YES 🔥',
                            style: _T.label(12,
                                color: _C.white, spacing: 0.2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('THEY SAID YES.',
                          style: _T.display(48,
                              color: _C.white, spacing: -0.5)),
                      const SizedBox(height: 2),
                      Text(_kProductName,
                          style: _T.label(14,
                              color: _C.magenta, spacing: 1)),
                      Text('$_kProductCategory · $_kProductPrice',
                          style: _T.body(13,
                              color: const Color(0xCCFFFFFF))),
                      if (fomoActive) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          color: _C.sale,
                          child: Text(
                            '⚡  Only $_kProductStock left in your size',
                            style: _T.label(11,
                                color: _C.white, spacing: 0.3),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.heavyImpact();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('🛍  Added to cart — crew approved!',
                    style: _T.label(13, color: _C.white, spacing: 0)),
                backgroundColor: _C.dark,
                behavior: SnackBarBehavior.floating,
              ));
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                gradient: fomoActive
                    ? const LinearGradient(
                        colors: [Color(0xFFE53935), Color(0xFFE91E8C)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight)
                    : const LinearGradient(
                        colors: [Color(0xFFE91E8C), Color(0xFFC2185B)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    fomoActive
                        ? "ORDER NOW — BEFORE IT'S GONE"
                        : 'ORDER NOW  →',
                    style: _T.label(16, color: _C.white, spacing: 2),
                  ),
                ],
              ),
            ),
          ),
          Container(
            color: _C.dark,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_shipping_outlined,
                    color: _C.grey500, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Free delivery · Easy returns · Try at Doorstep',
                  style: _T.body(11, color: _C.grey500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED — OUTFIT MINI CARD
// ─────────────────────────────────────────────────────────────────────────────
class _OutfitMiniCard extends StatelessWidget {
  const _OutfitMiniCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.grey100,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Image.network(_kProductImage,
                width: 48, height: 60, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(width: 48, height: 60, color: _C.grey300)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  color: _C.magenta,
                  child: Text('VIBE CHECK',
                      style: _T.label(8, color: _C.white, spacing: 1.5)),
                ),
                const SizedBox(height: 4),
                Text(_kProductName,
                    style: _T.label(12, color: _C.dark, spacing: 0)),
                Text(_kProductCategory, style: _T.body(11)),
              ],
            ),
          ),
          Text(_kProductPrice,
              style: _T.label(13, color: _C.dark, spacing: 0)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED — BOTTOM CTA
// ─────────────────────────────────────────────────────────────────────────────
class _BottomCta extends StatelessWidget {
  final String        label;
  final String        subLabel;
  final bool          enabled;
  final bool          urgent;
  final VoidCallback? onTap;

  const _BottomCta({
    required this.label,
    required this.subLabel,
    required this.enabled,
    required this.onTap,
    this.urgent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        border: Border(top: BorderSide(color: _C.grey150)),
      ),
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: GestureDetector(
        onTap: enabled
            ? () { HapticFeedback.lightImpact(); onTap?.call(); }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          color: enabled ? (urgent ? _C.sale : _C.dark) : _C.grey300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: _T.label(14, color: _C.white, spacing: 1.5)),
              const SizedBox(height: 2),
              Text(subLabel,
                  style: _T.body(11,
                      color: _C.white.withOpacity(0.7))),
            ],
          ),
        ),
      ),
    );
  }
}