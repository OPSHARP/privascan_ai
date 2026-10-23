import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum NavTabItem { home, camera }

class FloatingPillNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onCameraTap;

  const FloatingPillNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onCameraTap,
  });

  @override
  State<FloatingPillNavBar> createState() => _FloatingPillNavBarState();
}

class _FloatingPillNavBarState extends State<FloatingPillNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flareAnimController;
  late Animation<double> _flareAnim;
  double _currentFlarePercent = 0.30;

  // 2 items: Home (~30%) and Camera (~70%)
  static const List<double> _tabFractions = [0.30, 0.70];

  @override
  void initState() {
    super.initState();
    _currentFlarePercent = _tabFractions[widget.currentIndex.clamp(0, 1)];
    _flareAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _flareAnim = Tween<double>(
      begin: _currentFlarePercent,
      end: _currentFlarePercent,
    ).animate(
      CurvedAnimation(
        parent: _flareAnimController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant FloatingPillNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      final targetPercent = _tabFractions[widget.currentIndex.clamp(0, 1)];
      _flareAnim = Tween<double>(
        begin: _flareAnim.value,
        end: targetPercent,
      ).animate(
        CurvedAnimation(
          parent: _flareAnimController,
          curve: Curves.easeOutCubic,
        ),
      );
      _flareAnimController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _flareAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final effectiveBottom = bottomInset > 0 ? bottomInset + 10.0 : 22.0;

    return Positioned(
      left: 0,
      right: 0,
      bottom: effectiveBottom,
      child: Center(
        child: AnimatedBuilder(
          animation: _flareAnim,
          builder: (context, _) {
            return _GlowingPillWidget(
              currentIndex: widget.currentIndex,
              flarePercent: _flareAnim.value,
              onTabSelected: widget.onTabSelected,
              onCameraTap: widget.onCameraTap,
            );
          },
        ),
      ),
    );
  }
}

class _GlowingPillWidget extends StatelessWidget {
  final int currentIndex;
  final double flarePercent;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onCameraTap;

  const _GlowingPillWidget({
    required this.currentIndex,
    required this.flarePercent,
    required this.onTabSelected,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    // 2-item compact floating capsule matching reference image
    const pillWidth = 168.0;
    const pillHeight = 54.0;
    const pillRadius = 27.0;

    return Container(
      width: pillWidth,
      height: pillHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(pillRadius),
        // Multi-tier cyan atmospheric glow matching reference image
        boxShadow: [
          // 1. Tight intense cyan halo hugging the border
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.45),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 1),
          ),
          // 2. Wide atmospheric electric blue diffusion
          BoxShadow(
            color: const Color(0xFF0077FF).withValues(alpha: 0.30),
            blurRadius: 36,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
          // 3. Dark backdrop shadow for physical elevation
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _PillBorderAndFlarePainter(
          flarePercent: flarePercent,
          borderRadius: pillRadius,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(pillRadius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(pillRadius),
                // Deep obsidian translucent glass
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFA141923), // Deep charcoal obsidian
                    Color(0xFA0A0D13), // Pure dark midnight
                  ],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _NavBarIconItem(
                      index: 0,
                      selectedIcon: CupertinoIcons.house_fill,
                      unselectedIcon: CupertinoIcons.house,
                      isSelected: currentIndex == 0,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onTabSelected(0);
                      },
                    ),
                  ),
                  Expanded(
                    child: _NavBarIconItem(
                      index: 1,
                      selectedIcon: CupertinoIcons.camera_fill,
                      unselectedIcon: CupertinoIcons.camera,
                      isSelected: currentIndex == 1,
                      isCenterCamera: true,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        onCameraTap();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarIconItem extends StatefulWidget {
  final int index;
  final IconData selectedIcon;
  final IconData unselectedIcon;
  final bool isSelected;
  final bool isCenterCamera;
  final VoidCallback onTap;

  const _NavBarIconItem({
    required this.index,
    required this.selectedIcon,
    required this.unselectedIcon,
    required this.isSelected,
    this.isCenterCamera = false,
    required this.onTap,
  });

  @override
  State<_NavBarIconItem> createState() => _NavBarIconItemState();
}

class _NavBarIconItemState extends State<_NavBarIconItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.86).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) => _scaleController.forward();
  void _handleTapUp(TapUpDetails _) {
    _scaleController.reverse();
    widget.onTap();
  }

  void _handleTapCancel() => _scaleController.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: Center(
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(scale: anim, child: child),
            ),
            child: Icon(
              widget.isSelected ? widget.selectedIcon : widget.unselectedIcon,
              key: ValueKey('${widget.index}_${widget.isSelected}'),
              size: widget.isCenterCamera ? 24 : 22,
              // Pure crisp white when selected (matching reference image), subtle muted silver when unselected
              color: widget.isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.50),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter rendering the neon cyan border, top specular light flare,
/// and subtle downward ambient light wash matching the user's reference image.
class _PillBorderAndFlarePainter extends CustomPainter {
  final double flarePercent;
  final double borderRadius;

  _PillBorderAndFlarePainter({
    required this.flarePercent,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // 1. Neon Cyan Glowing Border Stroke
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF38BDF8), // Vivid electric cyan
          Color(0xFF00E5FF), // Bright neon cyan
          Color(0xFF0284C7), // Deep cyan-blue
          Color(0xFF38BDF8),
        ],
        stops: [0.0, 0.35, 0.70, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, strokePaint);

    // 2. Flare position along the top contour
    final flareX = size.width * flarePercent;
    final flareCenter = Offset(flareX, 0.8);

    // 3. Subtle downward ambient light wash directly from the flare
    final coneWashPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(flareX, 4),
        36.0,
        [
          const Color(0xFF00E5FF).withValues(alpha: 0.24),
          const Color(0xFF00E5FF).withValues(alpha: 0.08),
          Colors.transparent,
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawCircle(Offset(flareX, 12), 36, coneWashPaint);

    // 4. Horizontal specular light flare streak along top contour
    final streakRect = Rect.fromCenter(
      center: flareCenter,
      width: 52.0,
      height: 7.0,
    );
    final streakPaint = Paint()
      ..shader = ui.Gradient.radial(
        flareCenter,
        26.0,
        [
          const Color(0xFF00E5FF).withValues(alpha: 0.95),
          const Color(0xFF00E5FF).withValues(alpha: 0.35),
          Colors.transparent,
        ],
        [0.0, 0.45, 1.0],
      );
    canvas.drawOval(streakRect, streakPaint);

    // 5. Outer radial flare glow
    final flareGlowPaint = Paint()
      ..shader = ui.Gradient.radial(
        flareCenter,
        20.0,
        [
          const Color(0xFF00E5FF).withValues(alpha: 0.90),
          const Color(0xFF00E5FF).withValues(alpha: 0.30),
          Colors.transparent,
        ],
        [0.0, 0.4, 1.0],
      );
    canvas.drawCircle(flareCenter, 20, flareGlowPaint);

    // 6. Super-bright specular white hot core (matching reference image)
    final flareCorePaint = Paint()
      ..shader = ui.Gradient.radial(
        flareCenter,
        4.5,
        [
          Colors.white,
          const Color(0xFFE0F7FA),
          Colors.transparent,
        ],
        [0.0, 0.6, 1.0],
      );
    canvas.drawCircle(flareCenter, 4.5, flareCorePaint);
  }

  @override
  bool shouldRepaint(covariant _PillBorderAndFlarePainter oldDelegate) {
    return oldDelegate.flarePercent != flarePercent;
  }
}
