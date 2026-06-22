import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── DESIGN TOKENS (from home_screen.dart) ───────────────────────────────────
class _C {
  static const white   = Color(0xFFFFFFFF);
  static const bg      = Color(0xFFFFFFFF);
  static const cardBg  = Color(0xFFF2F2F2);
  static const grey100 = Color(0xFFF5F5F5);
  static const grey150 = Color(0xFFEEEEEE);
  static const grey300 = Color(0xFFCCCCCC);
  static const grey500 = Color(0xFF999999);
  static const grey700 = Color(0xFF555555);
  static const dark    = Color(0xFF0D0D0D);
  static const magenta = Color(0xFFE91E8C);
  static const sale    = Color(0xFFE53935);
  static const amber   = Color(0xFFFF6F00);

  // Profile-specific
  static const gold    = Color(0xFFB8892A);
  static const cream   = Color(0xFFF5F0EA);
  static const brown   = Color(0xFF7B4A2D);
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
          fontSize: size,
          fontWeight: fw,
          color: color,
          letterSpacing: spacing);

  static TextStyle body(double size,
          {Color color = _C.grey700, FontWeight fw = FontWeight.w400}) =>
      GoogleFonts.jost(fontSize: size, fontWeight: fw, color: color);

  static TextStyle mono(double size, {Color color = _C.dark}) =>
      GoogleFonts.robotoMono(fontSize: size, color: color, fontWeight: FontWeight.w500);
}

// ─── MODELS ──────────────────────────────────────────────────────────────────
class _BrandSize {
  final String brand, size, logoLetter;
  final Color logoColor;
  const _BrandSize({
    required this.brand,
    required this.size,
    required this.logoLetter,
    required this.logoColor,
  });
}

class _FitHistoryItem {
  final String name, date, status, reason, imageUrl;
  const _FitHistoryItem({
    required this.name,
    required this.date,
    required this.status,
    required this.reason,
    required this.imageUrl,
  });
}

class _WardrobeOccasion {
  final String occasion, count;
  final IconData icon;
  final bool hasGap;
  final String? gapText;
  const _WardrobeOccasion({
    required this.occasion,
    required this.count,
    required this.icon,
    this.hasGap = false,
    this.gapText,
  });
}

// ─── DATA ────────────────────────────────────────────────────────────────────
const _brandSizes = [
  _BrandSize(brand: 'ZARA', size: 'M', logoLetter: 'Z', logoColor: Color(0xFF0D0D0D)),
  _BrandSize(brand: 'H&M', size: 'L', logoLetter: 'H', logoColor: Color(0xFFE53935)),
  _BrandSize(brand: 'MANGO', size: 'S/M', logoLetter: 'M', logoColor: Color(0xFF7B4A2D)),
  _BrandSize(brand: 'UNIQLO', size: 'M', logoLetter: 'U', logoColor: Color(0xFFE91E8C)),
  _BrandSize(brand: 'FABINDIA', size: 'L', logoLetter: 'F', logoColor: Color(0xFFFF6F00)),
  _BrandSize(brand: 'WESTSIDE', size: 'M', logoLetter: 'W', logoColor: Color(0xFF7C3AED)),
];

const _fitHistory = [
  _FitHistoryItem(
    name: 'Maison Kaira Festive Saree',
    date: '12 May 2025',
    status: 'KEPT',
    reason: 'Perfect fit',
    imageUrl: 'https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=300&q=80',
  ),
  _FitHistoryItem(
    name: 'Atelier Sur Power Blazer',
    date: '04 May 2025',
    status: 'RETURNED',
    reason: 'Runs large',
    imageUrl: 'https://images.unsplash.com/photo-1551803091-e20673f15770?w=300&q=80',
  ),
  _FitHistoryItem(
    name: 'Indira & Co Ethnic Kurta',
    date: '28 Apr 2025',
    status: 'KEPT',
    reason: 'True to size',
    imageUrl: 'https://images.unsplash.com/photo-1566206091558-7f218b696731?w=300&q=80',
  ),
  _FitHistoryItem(
    name: 'Deco Noir Street Jacket',
    date: '15 Apr 2025',
    status: 'RETURNED',
    reason: 'Shoulder too tight',
    imageUrl: 'https://images.unsplash.com/photo-1509631179647-0177331693ae?w=300&q=80',
  ),
  _FitHistoryItem(
    name: 'Casa Modas Coord Set',
    date: '01 Apr 2025',
    status: 'KEPT',
    reason: 'Great drape',
    imageUrl: 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=300&q=80',
  ),
];

const _wardrobe = [
  _WardrobeOccasion(
    occasion: 'Casual',
    count: '14 outfits',
    icon: Icons.coffee_outlined,
    hasGap: false,
  ),
  _WardrobeOccasion(
    occasion: 'Work',
    count: '7 outfits',
    icon: Icons.work_outline,
    hasGap: false,
  ),
  _WardrobeOccasion(
    occasion: 'Festive',
    count: '5 outfits',
    icon: Icons.celebration_outlined,
    hasGap: false,
  ),
  _WardrobeOccasion(
    occasion: 'Evening',
    count: '2 outfits',
    icon: Icons.nights_stay_outlined,
    hasGap: true,
    gapText: 'You have no formal evening wear.',
  ),
  _WardrobeOccasion(
    occasion: 'Sport',
    count: '3 outfits',
    icon: Icons.fitness_center_outlined,
    hasGap: false,
  ),
];

// ─── STYLE PROFILE SCREEN ────────────────────────────────────────────────────
class StyleProfileScreen extends StatefulWidget {
  const StyleProfileScreen({super.key});

  @override
  State<StyleProfileScreen> createState() => _StyleProfileScreenState();
}

class _StyleProfileScreenState extends State<StyleProfileScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ringCtrl;
  late final Animation<double> _ringAnim;
  late final AnimationController _scoreCtrl;
  late final Animation<double> _scoreAnim;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  List<_BrandSize> _dynamicBrandSizes = [];

  // Style score out of 100
  static const double _styleScore = 78;
  static const double _sizeAccuracy = 0.94;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _ringAnim = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic);

    _scoreCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _scoreAnim = CurvedAnimation(parent: _scoreCtrl, curve: Curves.easeOutCubic);

    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            _userData = doc.data();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching user data: \$e');
    } finally {
      _generateDynamicBrandSizes();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _fadeCtrl.forward();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _ringCtrl.forward();
            _scoreCtrl.forward();
          }
        });
      }
    }
  }

  void _generateDynamicBrandSizes() {
    final sizes = (_userData?['preferredSizes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['M'];
    final defaultSize = sizes.isNotEmpty ? sizes.first : 'M';
    
    _dynamicBrandSizes = [
      _BrandSize(brand: 'ZARA', size: sizes.contains('M') ? 'M' : defaultSize, logoLetter: 'Z', logoColor: const Color(0xFF0D0D0D)),
      _BrandSize(brand: 'H&M', size: sizes.contains('L') ? 'L' : defaultSize, logoLetter: 'H', logoColor: const Color(0xFFE53935)),
      _BrandSize(brand: 'MANGO', size: sizes.contains('S') ? 'S/M' : defaultSize, logoLetter: 'M', logoColor: const Color(0xFF7B4A2D)),
      _BrandSize(brand: 'UNIQLO', size: defaultSize, logoLetter: 'U', logoColor: const Color(0xFFE91E8C)),
      _BrandSize(brand: 'FABINDIA', size: sizes.contains('L') ? 'L' : defaultSize, logoLetter: 'F', logoColor: const Color(0xFFFF6F00)),
      _BrandSize(brand: 'WESTSIDE', size: defaultSize, logoLetter: 'W', logoColor: const Color(0xFF7C3AED)),
    ];
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _ringCtrl.dispose();
    _scoreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _C.bg,
        body: const Center(child: CircularProgressIndicator(color: _C.dark)),
      );
    }
    return Scaffold(
      backgroundColor: _C.bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── AVATAR + STYLE DNA ────────────────────────────────
                  SliverToBoxAdapter(child: _buildAvatarSection()),

                  // ── SIZE MEMORY CARD ──────────────────────────────────
                  SliverToBoxAdapter(child: _buildSectionHeader('SIZE MEMORY', _C.gold)),
                  SliverToBoxAdapter(child: _buildSizeMemoryCard()),

                  // ── CONFIDENCE SCORE ──────────────────────────────────
                  SliverToBoxAdapter(child: _buildConfidenceScore()),

                  // ── FIT HISTORY TIMELINE ──────────────────────────────
                  SliverToBoxAdapter(child: _buildSectionHeader('FIT HISTORY', _C.dark)),
                  SliverToBoxAdapter(child: _buildFitHistoryTimeline()),

                  // ── OCCASION WARDROBE ─────────────────────────────────
                  SliverToBoxAdapter(child: _buildSectionHeader('OCCASION WARDROBE', _C.brown)),
                  SliverToBoxAdapter(child: _buildOccasionWardrobe()),

                  // ── GAP ANALYSIS CARD ─────────────────────────────────
                  SliverToBoxAdapter(child: _buildGapAnalysisCard()),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TOP BAR ─────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      color: _C.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 14,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, size: 24, color: _C.dark),
          ),
          const SizedBox(width: 12),
          Text('MY STYLE PROFILE', style: _T.display(22, spacing: 1.5)),
          const Spacer(),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: _C.dark,
              child: Text('EDIT', style: _T.label(11, color: _C.white, spacing: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── AVATAR + STYLE DNA ───────────────────────────────────────────────────
  Widget _buildAvatarSection() {
    return Container(
      color: _C.cream,
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Style Score Ring + Avatar
          AnimatedBuilder(
            animation: _ringAnim,
            builder: (_, __) {
              return SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: _StyleRingPainter(
                    progress: _ringAnim.value * (_styleScore / 100),
                    ringColor: _C.gold,
                    bgColor: _C.grey150,
                  ),
                  child: Center(
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _C.white,
                      ),
                      child: const Center(
                        child: Icon(Icons.person, size: 44, color: _C.dark),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 20),

          // Style DNA info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_userData?['name']?.toString().toUpperCase() ?? 'STYLE ENTHUSIAST', style: _T.display(28, spacing: 1)),
                const SizedBox(height: 6),

                // Style DNA tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: _C.gold, width: 1.5),
                    color: _C.white,
                  ),
                  child: Text(
                    "${_userData?['bodyType'] ?? 'Minimal Contemporary'} · ${(_userData?['preferredSizes'] as List?)?.first ?? 'L'} in most brands",
                    style: _T.body(11, color: _C.brown),
                    maxLines: 2,
                  ),
                ),

                const SizedBox(height: 10),

                // Style score label
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _scoreAnim,
                      builder: (_, __) {
                        final val = (_styleScore * _scoreAnim.value).round();
                        return Text(
                          '$val',
                          style: _T.display(32, color: _C.gold, spacing: 0),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('/100', style: _T.body(11, color: _C.grey500)),
                        Text('STYLE SCORE', style: _T.label(9, color: _C.grey700, spacing: 1)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── SECTION HEADER ───────────────────────────────────────────────────────
  Widget _buildSectionHeader(String label, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
      child: Row(
        children: [
          Container(width: 3, height: 20, color: accentColor),
          const SizedBox(width: 10),
          Text(label, style: _T.display(22, spacing: 0.5)),
        ],
      ),
    );
  }

  // ─── SIZE MEMORY CARD ─────────────────────────────────────────────────────
  Widget _buildSizeMemoryCard() {

  return Padding(

    padding: const EdgeInsets.symmetric(horizontal: 16),

    child: Container(

      decoration: BoxDecoration(

        color: _C.white,

        border: Border.all(
          color: _C.grey150,
          width: 1,
        ),

        boxShadow: [

          BoxShadow(

            color: _C.dark.withOpacity(0.04),

            blurRadius: 12,

            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          // HEADER
          Padding(

            padding: const EdgeInsets.fromLTRB(
              18,
              18,
              18,
              10,
            ),

            child: Row(

              children: [

                Container(

                  width: 34,
                  height: 34,

                  decoration: BoxDecoration(

                    color: _C.gold.withOpacity(0.12),

                    shape: BoxShape.circle,
                  ),

                  child: const Icon(
                    Icons.straighten,
                    color: _C.gold,
                    size: 18,
                  ),
                ),

                const SizedBox(width: 12),

                Column(

                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Text(

                      'SMART SIZE MEMORY',

                      style: _T.label(

                        13,

                        color: _C.dark,

                        spacing: 1,
                      ),
                    ),

                    Text(

                      'Synced across brands',

                      style: _T.body(
                        11,
                        color: _C.grey500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // SIZE CHIPS
          Padding(

            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ),

            child: Wrap(

              spacing: 10,
              runSpacing: 10,

              children: _dynamicBrandSizes
                  .map(
                    (b) => _BrandSizeTile(b: b),
                  )
                  .toList(),
            ),
          ),

          const SizedBox(height: 18),

          // INSIGHT CARD
          Container(

            width: double.infinity,

            margin: const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16,
            ),

            padding: const EdgeInsets.all(14),

            decoration: BoxDecoration(

              color: _C.cream,

              border: Border.all(
                color: _C.gold.withOpacity(0.15),
              ),
            ),

            child: Row(

              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Container(

                  width: 28,
                  height: 28,

                  decoration: const BoxDecoration(

                    color: _C.gold,

                    shape: BoxShape.circle,
                  ),

                  child: const Icon(

                    Icons.check,

                    size: 16,

                    color: _C.white,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(

                  child: Column(

                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [

                      Text(

                        '94% Fit Match Accuracy',

                        style: _T.label(

                          13,

                          color: _C.dark,

                          spacing: 0,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(

                        'Your sizing becomes more accurate after every kept order.',

                        style: _T.body(

                          11,

                          color: _C.grey700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  // ─── CONFIDENCE SCORE ─────────────────────────────────────────────────────
  Widget _buildConfidenceScore() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: _C.dark,
          // Glassmorphism-inspired subtle gradient
        ),
        child: Row(
          children: [
            // Accuracy percentage
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: _scoreAnim,
                  builder: (_, __) {
                    final pct = (_sizeAccuracy * _scoreAnim.value * 100).round();
                    return Text(
                      '$pct%',
                      style: _T.mono(32, color: _C.gold),
                    );
                  },
                ),
                Text(
                  'SIZE MATCH ACCURACY',
                  style: _T.label(9, color: _C.grey300, spacing: 1.5),
                ),
              ],
            ),
            const SizedBox(width: 20),
            // Vertical divider
            Container(width: 1, height: 50, color: _C.grey700),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'Based on ${_fitHistory.length} orders — ${_fitHistory.where((f) => f.status == "KEPT").length} kept, ${_fitHistory.where((f) => f.status == "RETURNED").length} returned.',
                style: _T.body(12, color: _C.grey500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── FIT HISTORY TIMELINE ─────────────────────────────────────────────────
  Widget _buildFitHistoryTimeline() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _fitHistory.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final isKept = item.status == 'KEPT';
          final statusColor = isKept ? const Color(0xFF2E7D32) : _C.sale;
          final isLast = i == _fitHistory.length - 1;

          // Reason chip color
          Color chipColor;
          if (item.reason.contains('large') || item.reason.contains('tight')) {
            chipColor = _C.amber;
          } else if (item.reason.contains('Perfect') || item.reason.contains('True')) {
            chipColor = const Color(0xFF2E7D32);
          } else {
            chipColor = _C.grey500;
          }

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline line + dot
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(top: 14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                          border: Border.all(color: _C.white, width: 2),
                          boxShadow: [
                            BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 4),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 1,
                            margin: const EdgeInsets.only(top: 4),
                            color: _C.grey150,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Card
                Expanded(
                  child: Container(
                    margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
                    decoration: BoxDecoration(
                      color: _C.white,
                      border: Border.all(color: _C.grey150),
                    ),
                    child: Row(
                      children: [
                        // Product image
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: Image.network(
                            item.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: _C.grey150),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name,
                                    style: _T.label(11, color: _C.dark, spacing: 0),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(item.date, style: _T.body(10)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    // KEPT / RETURNED tag
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 3),
                                      color: statusColor,
                                      child: Text(
                                        item.status,
                                        style: _T.label(8, color: _C.white, spacing: 0.8),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Reason chip
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: chipColor.withOpacity(0.12),
                                        border: Border.all(color: chipColor.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        item.reason,
                                        style: _T.body(9, color: chipColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── OCCASION WARDROBE ────────────────────────────────────────────────────
  Widget _buildOccasionWardrobe() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _wardrobe.map((occ) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: occ.hasGap ? _C.cream : _C.white,
              border: Border.all(
                color: occ.hasGap ? _C.gold.withOpacity(0.5) : _C.grey150,
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      Icon(occ.icon, size: 20, color: occ.hasGap ? _C.gold : _C.grey700),
                      const SizedBox(width: 12),
                      Text(occ.occasion, style: _T.label(13, color: _C.dark, spacing: 0)),
                      const Spacer(),
                      Text(occ.count, style: _T.body(12, color: _C.grey500)),
                      if (occ.hasGap) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          color: _C.gold,
                          child: Text('GAP', style: _T.label(8, color: _C.white, spacing: 1)),
                        ),
                      ],
                    ],
                  ),
                ),
                // Gap hint
                if (occ.hasGap && occ.gapText != null)
                  Container(
                    width: double.infinity,
                    color: _C.gold.withOpacity(0.1),
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 13, color: _C.gold),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            occ.gapText!,
                            style: _T.body(11, color: _C.brown),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── GAP ANALYSIS CARD ────────────────────────────────────────────────────
  Widget _buildGapAnalysisCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0D0D), Color(0xFF1A1410)],
          ),
          boxShadow: [
            BoxShadow(
              color: _C.gold.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative gold line top
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(height: 2, color: _C.gold),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 16, color: _C.gold),
                      const SizedBox(width: 8),
                      Text('AI GAP ANALYSIS', style: _T.label(11, color: _C.gold, spacing: 1.5)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Glassmorphism card feel — frosted text panel
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _C.white.withOpacity(0.06),
                      border: Border.all(color: _C.white.withOpacity(0.1)),
                    ),
                    child: Text(
                      '"You have no formal evening wear. 3 outfits curated just for you."',
                      style: GoogleFonts.jost(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: _C.white,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Curated outfit chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _GapOutfitChip(label: 'Formal Gown · ₹12,500'),
                      _GapOutfitChip(label: 'Cocktail Dress · ₹8,999'),
                      _GapOutfitChip(label: 'Saree Set · ₹15,000'),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // CTA
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                      color: _C.gold,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('SHOP THE GAP', style: _T.label(13, color: _C.white, spacing: 1.5)),
                          const SizedBox(width: 10),
                          const Icon(Icons.arrow_forward, size: 16, color: _C.white),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BODY SILHOUETTE PAINTER
// ─────────────────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────
// BRAND SIZE TILE
// ─────────────────────────────────────────────────────────────────────────────
class _BrandSizeTile extends StatelessWidget {
  final _BrandSize b;
  const _BrandSizeTile({required this.b});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _C.white,
        boxShadow: [
          BoxShadow(
            color: _C.dark.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Brand logo circle
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: b.logoColor,
            ),
            child: Center(
              child: Text(
                b.logoLetter,
                style: GoogleFonts.bebasNeue(
                  fontSize: 11,
                  color: _C.white,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(b.brand, style: _T.label(8, color: _C.grey500, spacing: 0.5)),
              Text(b.size, style: _T.label(11, color: _C.dark, spacing: 0)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STYLE SCORE RING PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _StyleRingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color bgColor;

  const _StyleRingPainter({
    required this.progress,
    required this.ringColor,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    const strokeWidth = 5.0;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress,
        false,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_StyleRingPainter old) =>
      old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// GAP OUTFIT CHIP
// ─────────────────────────────────────────────────────────────────────────────
class _GapOutfitChip extends StatelessWidget {
  final String label;
  const _GapOutfitChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: _C.gold.withOpacity(0.5)),
        color: _C.gold.withOpacity(0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add, size: 11, color: _C.gold),
          const SizedBox(width: 4),
          Text(label, style: _T.label(10, color: _C.gold, spacing: 0)),
        ],
      ),
    );
  }
}