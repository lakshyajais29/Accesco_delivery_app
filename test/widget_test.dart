// Design-system smoke tests.
//
// These cover the shared components rather than whole screens: screens pull in
// Firebase, which needs platform channels a unit test host doesn't have. The
// components below are pure widgets, so they can be verified directly — and
// they are where a regression would spread furthest.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instastyle/theme/app_theme.dart';
import 'package:instastyle/widgets/ds/ds.dart';

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
}
