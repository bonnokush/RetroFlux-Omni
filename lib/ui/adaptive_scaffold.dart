import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/license_service.dart';
import 'pro_modal.dart';
import 'palette_switcher.dart';
import 'dashboard_screen.dart';
import 'studios/image_studio.dart';
import 'studios/media_studio.dart';
import 'studios/history_view.dart';

/// Responsive Adaptive Scaffold:
/// Refactored to Google Pixel Material 3 (Material You) Navigation Drawer & Tonal Surface System
class AdaptiveScaffold extends ConsumerStatefulWidget {
  const AdaptiveScaffold({super.key});

  @override
  ConsumerState<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends ConsumerState<AdaptiveScaffold> {
  int _selectedIndex = 0;

  final List<Widget> _views = const [
    DashboardScreen(),
    MediaStudio(),
    ImageStudio(),
    HistoryView(),
  ];

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(licenseStateProvider) == LicenseTier.pro;
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 768;

        if (isDesktop) {
          // Desktop Google Pixel Navigation Drawer layout (Zero vertical divider)
          return Scaffold(
            backgroundColor: colorScheme.surface,
            body: Row(
              children: [
                _buildPixelDrawer(context, isPro, colorScheme),
                Expanded(
                  child: Container(
                    color: colorScheme.surface,
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: _views,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          // Mobile Google Pixel Bottom Navigation Bar layout
          return Scaffold(
            backgroundColor: colorScheme.surface,
            appBar: AppBar(
              backgroundColor: colorScheme.surface,
              title: const Text('RetroFlux Omni 4.0'),
              actions: [
                IconButton(
                  tooltip: 'Material You Palette',
                  icon:
                      Icon(Icons.palette_outlined, color: colorScheme.primary),
                  onPressed: () => PaletteSwitcherSheet.show(context),
                ),
                IconButton(
                  icon: Icon(
                    Icons.workspace_premium,
                    color: isPro ? Colors.greenAccent : colorScheme.primary,
                  ),
                  onPressed: () => ProModal.show(context),
                ),
              ],
            ),
            body: IndexedStack(
              index: _selectedIndex,
              children: _views,
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex.clamp(0, 3),
                onTap: (idx) {
                  setState(() => _selectedIndex = idx);
                },
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedItemColor: colorScheme.primary,
                unselectedItemColor: colorScheme.onSurfaceVariant,
                selectedFontSize: 12,
                unselectedFontSize: 12,
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.all_inbox_outlined),
                      activeIcon: Icon(Icons.all_inbox),
                      label: 'Queue'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.movie_creation_outlined),
                      activeIcon: Icon(Icons.movie_creation),
                      label: '4K Media'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.image_outlined),
                      activeIcon: Icon(Icons.image),
                      label: 'Images'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.history_outlined),
                      activeIcon: Icon(Icons.history),
                      label: 'History'),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  /// Google Pixel-style Navigation Drawer using tonal surface containers and stadium active pills
  Widget _buildPixelDrawer(
      BuildContext context, bool isPro, ColorScheme colorScheme) {
    return Container(
      width: 280,
      color: colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Brand Header in Tonal Container (No cyan neon glow)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(Icons.swap_horiz_rounded,
                        color: colorScheme.primary, size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RETROFLUX',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.8,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'OMNI 4.0 PRO',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Section Subheader
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'CONVERSION STUDIOS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Google Pixel Tonal Menu Items with Full-Pill Stadium Container (BorderRadius.circular(100))
          _buildPillNavButton(Icons.all_inbox_outlined, Icons.all_inbox,
              'Batch Queue', 0, colorScheme),
          _buildPillNavButton(Icons.movie_creation_outlined,
              Icons.movie_creation, '4K Media Studio', 1, colorScheme),
          _buildPillNavButton(
              Icons.image_outlined, Icons.image, 'Image Tools', 2, colorScheme),
          _buildPillNavButton(Icons.history_outlined, Icons.history,
              'Conversion History', 3, colorScheme),

          const Spacer(),

          // Material 3 License Status Card (Soft tonal pill in tertiaryContainer with zero border)
          InkWell(
            onTap: () => ProModal.show(context),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isPro
                    ? colorScheme.secondaryContainer
                    : colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isPro
                          ? colorScheme.primary.withOpacity(0.2)
                          : colorScheme.onTertiaryContainer.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.star_rounded,
                      color: isPro
                          ? colorScheme.primary
                          : colorScheme.onTertiaryContainer,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPro ? 'PRO ACTIVE' : 'FREE TIER',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isPro
                                ? colorScheme.onSecondaryContainer
                                : colorScheme.onTertiaryContainer,
                          ),
                        ),
                        Text(
                          isPro ? 'Unlimited Queue & 4K' : 'Click to Upgrade',
                          style: TextStyle(
                            fontSize: 11,
                            color: isPro
                                ? colorScheme.onSecondaryContainer
                                    .withOpacity(0.8)
                                : colorScheme.onTertiaryContainer
                                    .withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: isPro
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onTertiaryContainer,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pill-shaped capsule menu item (Stadium border / BorderRadius.circular(100))
  Widget _buildPillNavButton(
    IconData unselectedIcon,
    IconData selectedIcon,
    String label,
    int index,
    ColorScheme colorScheme, {
    String? badge,
  }) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Material(
        color: isSelected ? colorScheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(100),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: () => setState(() => _selectedIndex = index),
          hoverColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  isSelected ? selectedIcon : unselectedIcon,
                  size: 20,
                  color: isSelected
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary.withOpacity(0.2)
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
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
