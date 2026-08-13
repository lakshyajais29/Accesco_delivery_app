// Design-system smoke tests.
//
// These cover the shared components rather than whole screens: screens pull in
// Firebase, which needs platform channels a unit test host doesn't have. The
// components below are pure widgets, so they can be verified directly — and
// they are where a regression would spread furthest.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instastyle/models/thrift_model.dart';
import 'package:instastyle/services/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:instastyle/theme/app_theme.dart';
import 'package:instastyle/widgets/ds/ds.dart';
import 'package:instastyle/widgets/thrift_marketplace_section.dart';

/// Wraps a widget in the app's theme so components resolve the same tokens
/// they would at runtime.
Widget _harness(Widget child, {Size size = const Size(390, 844)}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('AppButton', () {
    testWidgets('renders its label uppercased and fires onPressed',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _harness(
          AppButton(label: 'Add to Bag', onPressed: () => taps++),
        ),
      );

      expect(find.text('ADD TO BAG'), findsOneWidget);

      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('does not fire while loading', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _harness(
          AppButton(
            label: 'Place Order',
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('is inert when onPressed is null', (tester) async {
      await tester.pumpWidget(
        _harness(const AppButton(label: 'Disabled', onPressed: null)),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pump();
      // Nothing to assert beyond "it did not throw" — a disabled button must
      // swallow the gesture rather than calling a null callback.
      expect(find.text('DISABLED'), findsOneWidget);
    });
  });

  group('AppProductCard', () {
    testWidgets('shows price, sale price and reports wishlist taps',
        (tester) async {
      var toggled = 0;
      await tester.pumpWidget(
        _harness(
          SizedBox(
            width: 180,
            child: AppProductCard(
              name: 'Linen Blazer',
              subtitle: 'Studio Label',
              imageUrl: '',
              price: '₹4,200',
              originalPrice: '₹6,000',
              onTap: () {},
              onWishlistToggle: () => toggled++,
            ),
          ),
        ),
      );

      expect(find.text('Linen Blazer'), findsOneWidget);
      expect(find.text('₹4,200'), findsOneWidget);
      expect(find.text('₹6,000'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();
      expect(toggled, 1);
    });

    testWidgets('stamps sold-out items', (tester) async {
      await tester.pumpWidget(
        _harness(
          SizedBox(
            width: 180,
            child: AppProductCard(
              name: 'Sold Piece',
              imageUrl: '',
              price: '₹1,000',
              soldOut: true,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('SOLD OUT'), findsOneWidget);
    });
  });

  group('AppRefineBar', () {
    testWidgets('surfaces the active filter count and both actions',
        (tester) async {
      var refined = 0;
      var sorted = 0;

      await tester.pumpWidget(
        _harness(
          AppRefineBar(
            sortLabel: 'Newest',
            activeFilterCount: 2,
            onRefine: () => refined++,
            onSort: () => sorted++,
          ),
        ),
      );

      expect(find.text('REFINE (2)'), findsOneWidget);
      expect(find.text('NEWEST'), findsOneWidget);

      await tester.tap(find.text('REFINE (2)'));
      await tester.pump();
      await tester.tap(find.text('NEWEST'));
      await tester.pump();

      expect(refined, 1);
      expect(sorted, 1);
    });
  });

  group('AppResultCount', () {
    testWidgets('pluralises correctly', (tester) async {
      await tester.pumpWidget(_harness(const AppResultCount(count: 80)));
      expect(find.text('80 Items Found'), findsOneWidget);

      await tester.pumpWidget(_harness(const AppResultCount(count: 1)));
      expect(find.text('1 Item Found'), findsOneWidget);
    });
  });

  group('AppStateView', () {
    testWidgets('renders an empty state with a working action', (tester) async {
      var acted = false;
      await tester.pumpWidget(
        _harness(
          AppStateView.empty(
            title: 'Your wishlist is empty',
            message: 'Pieces you love will live here.',
            actionLabel: 'Start Browsing',
            onAction: () => acted = true,
          ),
        ),
      );

      expect(find.text('Your wishlist is empty'), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();
      expect(acted, isTrue);
    });
  });

  group('Responsive layout', () {
    testWidgets('product grid widens from 2 columns on phones to 4 on tablets',
        (tester) async {
      late int phoneColumns;
      late int tabletColumns;

      await tester.pumpWidget(
        _harness(
          Builder(
            builder: (context) {
              phoneColumns = AppBreakpoints.gridColumns(context);
              return const SizedBox();
            },
          ),
          size: const Size(390, 844),
        ),
      );

      await tester.pumpWidget(
        _harness(
          Builder(
            builder: (context) {
              tabletColumns = AppBreakpoints.gridColumns(context);
              return const SizedBox();
            },
          ),
          size: const Size(1024, 1366),
        ),
      );

      expect(phoneColumns, 2);
      expect(tabletColumns, 4);
    });

    testWidgets('page inset grows with available width', (tester) async {
      late double phoneInset;
      late double tabletInset;

      await tester.pumpWidget(
        _harness(
          Builder(
            builder: (context) {
              phoneInset = AppSpacing.page(context);
              return const SizedBox();
            },
          ),
          size: const Size(390, 844),
        ),
      );

      await tester.pumpWidget(
        _harness(
          Builder(
            builder: (context) {
              tabletInset = AppSpacing.page(context);
              return const SizedBox();
            },
          ),
          size: const Size(1024, 1366),
        ),
      );

      expect(phoneInset, AppSpacing.md);
      expect(tabletInset, greaterThan(phoneInset));
    });
  });

  group('ThriftMarketplaceBanner', () {
    testWidgets('renders the Figma copy and reports taps', (tester) async {
      var explored = 0;
      await tester.pumpWidget(
        _harness(ThriftMarketplaceBanner(onTap: () => explored++)),
      );

      expect(find.text('THRIFT\nMARKETPLACE'), findsOneWidget);
      expect(find.text('Pre-loved styles.\nConscious choices.'), findsOneWidget);
      expect(find.text('EXPLORE NOW'), findsOneWidget);

      await tester.tap(find.byType(ThriftMarketplaceBanner));
      await tester.pump();
      expect(explored, 1);
    });
  });

  group('Thrift models', () {
    test('formats prices with Indian digit grouping', () {
      ThriftItem item(int paise) => ThriftItem(
            id: 'i',
            name: 'n',
            brand: 'b',
            category: 'c',
            imageUrl: '',
            priceInPaise: paise,
            condition: ThriftCondition.gentlyUsed,
            size: 'M',
          );

      expect(item(50000).formattedPrice, '₹500');
      expect(item(349900).formattedPrice, '₹3,499');
      expect(item(1250000).formattedPrice, '₹12,500');
      // Indian grouping pairs digits above the first three: ₹1,23,456.
      expect(item(12345600).formattedPrice, '₹1,23,456');
    });

    test('computes discount only against a higher original price', () {
      ThriftItem item(int price, int? original) => ThriftItem(
            id: 'i',
            name: 'n',
            brand: 'b',
            category: 'c',
            imageUrl: '',
            priceInPaise: price,
            originalPriceInPaise: original,
            condition: ThriftCondition.likeNew,
            size: 'M',
          );

      expect(item(50000, 100000).discountPercent, 50);
      expect(item(50000, null).discountPercent, isNull);
      // Guards against a bad row producing a negative or infinite discount.
      expect(item(50000, 50000).discountPercent, isNull);
      expect(item(50000, 0).discountPercent, isNull);
    });

    test('renders distance in metres below 1 km', () {
      ThriftStore store(double km) => ThriftStore(
            id: 's',
            name: 'n',
            area: 'a',
            imageUrl: '',
            latitude: 0,
            longitude: 0,
            distanceKm: km,
            rating: 4.5,
            itemCount: 10,
          );

      expect(store(0.4).formattedDistance, '400 m');
      expect(store(2.35).formattedDistance, '2.4 km');
    });

    test('falls back to gentlyUsed for an unknown condition', () {
      expect(ThriftCondition.fromJson('likeNew'), ThriftCondition.likeNew);
      expect(ThriftCondition.fromJson('like_new'), ThriftCondition.likeNew);
      // A grade added server-side must not crash an older client.
      expect(ThriftCondition.fromJson('museumPiece'),
          ThriftCondition.gentlyUsed);
      expect(ThriftCondition.fromJson(null), ThriftCondition.gentlyUsed);
    });
  });

  group('AppBottomNav', () {
    testWidgets('reports the tapped destination', (tester) async {
      var selected = -1;
      await tester.pumpWidget(
        _harness(
          AppBottomNav(
            currentIndex: 0,
            onTap: (i) => selected = i,
            items: const [
              AppNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
              ),
              AppNavItem(
                icon: Icons.style_outlined,
                activeIcon: Icons.style,
                label: 'Swipe',
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('SWIPE'));
      await tester.pump();
      expect(selected, 1);
    });
  });

  group('ThriftListingDraft', () {
    test('serialises to the exact keys the FastAPI schema expects', () {
      const draft = ThriftListingDraft(
        sellerId: 'uid-1',
        title: 'Wool Blend Blazer',
        brand: 'Zara',
        category: 'Blazers',
        size: 'M',
        condition: ThriftCondition.likeNew,
        priceInPaise: 89900,
        originalPriceInPaise: 249900,
        imageUrls: ['/tmp/a.jpg'],
      );

      final json = draft.toJson();

      expect(json['seller_id'], 'uid-1');
      expect(json['title'], 'Wool Blend Blazer');
      expect(json['price_in_paise'], 89900);
      expect(json['original_price_in_paise'], 249900);
      // The wire value must be the backend enum spelling, not the label.
      expect(json['condition'], 'likeNew');
      expect(json['image_urls'], ['/tmp/a.jpg']);
      // The server owns status — a client must never send it.
      expect(json.containsKey('status'), isFalse);
    });

    test('omits empty optional fields rather than sending blanks', () {
      const draft = ThriftListingDraft(
        sellerId: 'uid-2',
        title: 'Slip Dress',
        priceInPaise: 64000,
        brand: '',
        description: '',
      );

      final json = draft.toJson();
      expect(json.containsKey('brand'), isFalse);
      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('original_price_in_paise'), isFalse);
    });
  });

  group('ThriftListingStatus', () {
    test('parses known values and defaults unknown ones to pending', () {
      expect(ThriftListingStatus.fromJson('live'), ThriftListingStatus.live);
      expect(ThriftListingStatus.fromJson('sold'), ThriftListingStatus.sold);
      expect(
        ThriftListingStatus.fromJson('rejected'),
        ThriftListingStatus.rejected,
      );
      // A status added server-side later must not crash an older client.
      expect(
        ThriftListingStatus.fromJson('escrowed'),
        ThriftListingStatus.pending,
      );
      expect(ThriftListingStatus.fromJson(null), ThriftListingStatus.pending);
    });
  });

  group('AppPreferences first-run flag', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a fresh install is treated as a first-time user', () async {
      await AppPreferences.instance.load();
      // The key is absent — routing must send this user to style setup.
      expect(AppPreferences.instance.isFirstTimeUser, isTrue);
    });

    test('completing setup flips the flag and stores the answers', () async {
      SharedPreferences.setMockInitialValues({});
      await AppPreferences.instance.load();

      await AppPreferences.instance.completeStyleSetup(
        sizes: ['S', 'M'],
        styles: ['Minimal'],
      );

      expect(AppPreferences.instance.isFirstTimeUser, isFalse);
      expect(AppPreferences.instance.preferredSizes, ['S', 'M']);
      expect(AppPreferences.instance.preferredStyles, ['Minimal']);
    });

    test('reset returns the user to the first-run path', () async {
      SharedPreferences.setMockInitialValues({
        'has_completed_style_setup': true,
      });
      await AppPreferences.instance.load();
      expect(AppPreferences.instance.isFirstTimeUser, isFalse);

      await AppPreferences.instance.reset();
      expect(AppPreferences.instance.isFirstTimeUser, isTrue);
    });
  });

  group('Outfit builder reorder semantics', () {
    /// Mirrors the index adjustment in _InstantOutfitBuilderScreenState._reorder.
    /// ReorderableListView reports newIndex as if the dragged row were still
    /// occupying its old slot, so a downward move is off by one without this.
    List<String> reorder(List<String> items, int oldIndex, int newIndex) {
      final copy = List<String>.of(items);
      final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
      final moved = copy.removeAt(oldIndex);
      copy.insert(target, moved);
      return copy;
    }

    const seed = ['Top', 'Bottom', 'Shoes', 'Accessory'];

    test('moving a piece down lands where the user dropped it', () {
      // Drag "Top" (0) to sit after "Shoes" — ReorderableListView reports 3.
      expect(reorder(seed, 0, 3), ['Bottom', 'Shoes', 'Top', 'Accessory']);
    });

    test('moving a piece up needs no adjustment', () {
      expect(reorder(seed, 3, 0), ['Accessory', 'Top', 'Bottom', 'Shoes']);
    });

    test('a no-op drag leaves the layering untouched', () {
      expect(reorder(seed, 2, 2), seed);
    });
  });

  group('Outfit builder price parsing', () {
    /// Mirrors _rupeesFrom — alternatives carry only a formatted price, so the
    /// integer the cart needs has to be recovered from the string.
    int rupeesFrom(String formatted) =>
        int.tryParse(formatted.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    test('strips currency and grouping separators', () {
      expect(rupeesFrom('₹4,800'), 4800);
      expect(rupeesFrom('₹1,23,456'), 123456);
      expect(rupeesFrom('₹899'), 899);
    });

    test('falls back to zero rather than throwing on junk', () {
      expect(rupeesFrom('—'), 0);
      expect(rupeesFrom(''), 0);
    });
  });

  group('AppEditorialBanner layout', () {
    // The real campaign copy from home_screen.dart — the longest headline is
    // what tripped the original clipping bug.
    const eyebrow = 'The Curation';
    const headline = 'Shop\nthe Edit';
    const body = 'Everything our stylists are reaching for this season.';
    const cta = 'View Edit';

    Widget banner() => const AppEditorialBanner(
          eyebrow: eyebrow,
          headline: headline,
          body: body,
          ctaLabel: cta,
        );

    testWidgets('renders every element on a narrow phone without overflow',
        (tester) async {
      // 320pt is the narrowest width the design system supports.
      await tester.pumpWidget(_harness(banner(), size: const Size(320, 640)));

      // A RenderFlex overflow raises an exception in tests, so reaching the
      // assertions at all proves the layout fits.
      expect(tester.takeException(), isNull);

      expect(find.text('THE CURATION'), findsOneWidget);
      expect(find.text(headline), findsOneWidget);
      expect(find.text(body), findsOneWidget);
      expect(find.text('VIEW EDIT'), findsOneWidget);
    });

    testWidgets('the headline is never clipped by its own box', (tester) async {
      await tester.pumpWidget(_harness(banner(), size: const Size(320, 640)));

      final headlineSize = tester.getSize(find.text(headline));
      // Two lines of the display face. If the box were constraining the Text
      // below its natural height — the original bug — this collapses toward
      // a single line.
      expect(headlineSize.height, greaterThan(40));
    });

    testWidgets('grows past its minimum rather than clipping content',
        (tester) async {
      await tester.pumpWidget(_harness(banner(), size: const Size(320, 640)));

      final rendered = tester.getSize(find.byType(AppEditorialBanner)).height;
      expect(rendered, greaterThanOrEqualTo(190));
    });

    testWidgets('CTA stays visible at the largest permitted text scale',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            // The app clamps accessibility scaling to 1.3x in main.dart.
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(body: banner()),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('VIEW EDIT'), findsOneWidget);
    });
  });
}
