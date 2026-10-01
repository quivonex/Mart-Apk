import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';

/// Material 3 style bottom navigation with a pill indicator on the active tab.
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int cartCount;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.cartCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: DT.border)),
        boxShadow: DT.shadowBottomNav,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              _item(Icons.home_outlined, Icons.home_rounded, 'Home', 0),
              _item(Icons.storefront_outlined, Icons.storefront, 'Products', 1),
              _item(Icons.shopping_cart_outlined, Icons.shopping_cart,
                  'Cart', 2,
                  badge: cartCount),
              _item(Icons.local_shipping_outlined, Icons.local_shipping,
                  'Orders', 3),
              _item(Icons.person_outline, Icons.person, 'Account', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(
      IconData icon,
      IconData activeIcon,
      String label,
      int index, {
        int badge = 0,
      }) {
    final bool active = currentIndex == index;
    final Color color = active ? DT.blue900 : DT.onyx600;

    return Expanded(
      child: Semantics(
        selected: active,
        button: true,
        label: label,
        child: InkWell(
          onTap: () => onTap(index),
          borderRadius: BorderRadius.circular(DT.rMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: active ? DT.blue100 : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(active ? activeIcon : icon, color: color, size: 22),
                      if (badge > 0)
                        Positioned(
                          top: -4,
                          right: -8,
                          child: Container(
                            constraints: const BoxConstraints(
                                minWidth: 15, minHeight: 15),
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: DT.amber600,
                              borderRadius: BorderRadius.circular(8),
                              border:
                              Border.all(color: Colors.white, width: 1.5),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              badge > 99 ? '99+' : '$badge',
                              style: DT.text(
                                size: 8.5,
                                weight: FontWeight.w700,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  style: DT.text(
                    size: 10,
                    weight: active ? FontWeight.w700 : FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
