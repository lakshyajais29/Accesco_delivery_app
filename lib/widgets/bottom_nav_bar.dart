import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class BottomNavBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.activeIndex,
    required this.onTap,
  });

  static const _items = [
    (Icons.home_outlined, Icons.home, 'HOME'),
    (Icons.search_outlined, Icons.search, 'EXPLORE'),
    (Icons.favorite_border, Icons.favorite, 'SAVED'),
    (Icons.shopping_bag_outlined, Icons.shopping_bag, 'BAG'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundBase.withOpacity(0.92),
        border: Border(
          top: BorderSide(color: AppColors.separator, width: 0.5),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_items.length, (i) {
          final isActive = i == activeIndex;
          final (outlined, filled, label) = _items[i];
          return GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? filled : outlined,
                  size: 22,
                  color: isActive
                      ? AppColors.brandWarmBrown // active = signature tone
                      : AppColors.mutedText,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: AppText.featureLabel(
                    size: 8,
                    color: isActive
                        ? AppColors.ivoryWhite
                        : AppColors.mutedText,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}