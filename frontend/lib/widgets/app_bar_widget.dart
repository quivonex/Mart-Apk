import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import 'logo_widget.dart';

/// Shared top app bar.
/// Same public API as before (title, showBackButton, actions, onBackPressed),
/// plus [showDivider] so the Home tab can merge it with its sticky search header.
class AppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;
  final bool showDivider;

  const AppBarWidget({
    super.key,
    this.title = '',
    this.showBackButton = false,
    this.actions,
    this.onBackPressed,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: showDivider
            ? const Border(bottom: BorderSide(color: DT.border))
            : null,
      ),
      // SafeArea alone handles the status bar (the old version padded it twice).
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (showBackButton) ...[
                  AppBarIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    iconSize: 18,
                    tooltip: 'Back',
                    onPressed: onBackPressed ?? () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                ],
                if (title.isNotEmpty)
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(
                        size: 18,
                        weight: FontWeight.w700,
                        color: DT.onyx900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  )
                else ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: LogoWidget(size: 36, useImage: true),
                  ),
                  const Spacer(),
                ],
                if (actions != null) ...actions!,
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);
}

/// Round icon button used in the app bar, with an optional count badge or dot.
class AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final int badgeCount;
  final bool showDot;
  final double iconSize;

  const AppBarIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.badgeCount = 0,
    this.showDot = false,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(icon, size: iconSize, color: DT.onyx800),
              if (badgeCount > 0)
                Positioned(
                  top: 4,
                  right: 3,
                  child: Container(
                    constraints:
                    const BoxConstraints(minWidth: 17, minHeight: 17),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: DT.amber600,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: DT.text(
                        size: 9,
                        weight: FontWeight.w700,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                )
              else if (showDot)
                Positioned(
                  top: 8,
                  right: 9,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: DT.amber500,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
