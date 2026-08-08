// Design-system smoke tests.
//
// These cover the shared components rather than whole screens: screens pull in
// Firebase, which needs platform channels a unit test host doesn't have. The
// components below are pure widgets, so they can be verified directly — and
// they are where a regression would spread furthest.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instastyle/models/thrift_model.dart';
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
}
