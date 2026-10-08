// lib/widgets/bottom_nav_bar.dart
//
// Colourful bottom navigation (QNXMart mobile design):
//   * every tab has its own colour (Home blue, Products violet, Cart orange,
//     Orders teal, Account pink)
//   * inactive: outlined icon in the tab colour, grey label
//   * active:   filled icon on a tinted pill, bold coloured label, small bounce
//   * cart badge in amber
//
// Same API as before: BottomNavBar(currentIndex:, onTap:, cartCount:)

import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';

class _NavTab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Color color;
  const _NavTab(this.label, this.icon, this.activeIcon, this.color);
}

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int cartCount;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.cartCount = 0,
  });

  static const _tabs = <_NavTab>[
    _NavTab('Home', Icons.home_outlined, Icons.home_rounded, Color(0xFF1A68FA)), // blue
    _NavTab('Products', Icons.storefront_outlined, Icons.storefront_rounded, Color(0xFF7C3AED)), // violet
    _NavTab('Cart', Icons.shopping_cart_outlined, Icons.shopping_cart_rounded, Color(0xFFF97316)), // orange
    _NavTab('Orders', Icons.local_shipping_outlined, Icons.local_shipping_rounded, Color(0xFF0D9488)), // teal
    _NavTab('Account', Icons.person_outline_rounded, Icons.person_rounded, Color(0xFFDB2777)), // pink
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [BoxShadow(color: Color(0x140F172A), blurRadius: 12, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _NavItem(
                    tab: _tabs[i],
                    active: currentIndex == i,
                    badge: i == 2 ? cartCount : 0,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _NavTab tab;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  const _NavItem({required this.tab, required this.active, required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: active,
      button: true,
      label: badge > 0 ? '${tab.label}, $badge items' : tab.label,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        highlightColor: Colors.transparent,
        splashColor: tab.color.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: active ? 52 : 44,
                height: 30,
                decoration: BoxDecoration(
                  color: active ? tab.color.withValues(alpha: 0.14) : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedScale(
                      scale: active ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      child: Icon(
                        active ? tab.activeIcon : tab.icon,
                        size: 23,
                        color: active ? tab.color : tab.color.withValues(alpha: 0.85),
                      ),
                    ),
                    if (badge > 0)
                      Positioned(
                        right: active ? 6 : 2,
                        top: -3,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B), // amber-500
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            badge > 99 ? '99+' : '$badge',
                            style: DT.text(size: 9, weight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: DT.text(
                  size: 11,
                  weight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active ? tab.color : DT.slate500,
                ),
                child: Text(tab.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}