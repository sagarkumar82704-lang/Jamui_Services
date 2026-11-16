import 'package:flutter/material.dart';
import '../utils/responsive_layout.dart';
import 'app_logo.dart';

class WorkspaceNavDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? badgeText;

  const WorkspaceNavDestination({
    required this.icon,
    IconData? activeIcon,
    required this.label,
    this.badgeText,
  }) : activeIcon = activeIcon ?? icon;
}

/// Adaptive navigation shell for Jamui Services Provider App.
/// - Mobile (< 600 px): BottomNavigationBar
/// - Tablet (600 - 1023 px): Left NavigationRail
/// - Laptop / Desktop (>= 1024 px): Full Left Sidebar Navigation + Main Workspace Area
class ResponsiveWorkspaceShell extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<WorkspaceNavDestination> destinations;
  final List<WorkspaceNavDestination>? mobileDestinations;
  final List<int>? mobileDestinationIndices;
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Color primaryColor;
  final Color unselectedColor;
  final Color backgroundColor;
  final String workspaceTitle;
  final String workspaceSubtitle;
  final String? businessName;
  final String? categoryLabel;
  final bool? isOnlineOrOpen;
  final String? statusLabel;
  final Widget? sidebarFooter;
  final Widget? headerAction;

  ResponsiveWorkspaceShell({
    super.key,
    int? currentIndex,
    int? selectedIndex,
    ValueChanged<int>? onDestinationSelected,
    ValueChanged<int>? onSelectIndex,
    required this.destinations,
    this.mobileDestinations,
    this.mobileDestinationIndices,
    this.appBar,
    required this.body,
    Color? primaryColor,
    Color? selectedColor,
    this.unselectedColor = const Color(0xFF64748B),
    this.backgroundColor = const Color(0xFFF8F9FA),
    String? workspaceTitle,
    String? brandTitle,
    String? workspaceSubtitle,
    String? brandSubtitle,
    this.businessName,
    this.categoryLabel,
    bool? isOnlineOrOpen,
    bool? isStatusPositive,
    String? statusLabel,
    String? statusBadgeText,
    this.sidebarFooter,
    this.headerAction,
  })  : currentIndex = currentIndex ?? selectedIndex ?? 0,
        onDestinationSelected = onDestinationSelected ?? onSelectIndex ?? ((_) {}),
        primaryColor = selectedColor ?? primaryColor ?? const Color(0xFF0F766E),
        workspaceTitle = brandTitle ?? workspaceTitle ?? 'JAMUI SERVICES',
        workspaceSubtitle = brandSubtitle ?? workspaceSubtitle ?? 'Partner Workspace',
        isOnlineOrOpen = isStatusPositive ?? isOnlineOrOpen,
        statusLabel = statusBadgeText ?? statusLabel;

  @override
  Widget build(BuildContext context) {
    final topBar = appBar;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < ResponsiveLayout.mobileMax;
        final isTablet =
            width >= ResponsiveLayout.mobileMax && width < ResponsiveLayout.tabletMax;

        if (isMobile) {
          final isSmall = width <= ResponsiveLayout.smallMobileMax;
          final effectiveMobileDests = mobileDestinations ?? destinations.take(5).toList();
          final effectiveIndices = mobileDestinationIndices ?? List.generate(effectiveMobileDests.length, (i) => i);

          int mobileNavIndex = effectiveIndices.indexOf(currentIndex);
          if (mobileNavIndex == -1) {
            mobileNavIndex = effectiveMobileDests.length - 1;
          }

          return Scaffold(
            backgroundColor: backgroundColor,
            appBar: topBar,
            body: body,
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: BottomNavigationBar(
                  currentIndex: mobileNavIndex,
                  onTap: (mIdx) {
                    final targetPageIdx = effectiveIndices[mIdx];
                    onDestinationSelected(targetPageIdx);
                  },
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.white,
                  selectedItemColor: primaryColor,
                  unselectedItemColor: const Color(0xFF64748B),
                  selectedFontSize: isSmall ? 10.0 : 11.5,
                  unselectedFontSize: isSmall ? 9.5 : 11.0,
                  selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
                  elevation: 0,
                  items: effectiveMobileDests
                      .map(
                        (d) => BottomNavigationBarItem(
                          icon: Icon(d.icon, size: isSmall ? 20 : 22),
                          activeIcon: Icon(d.activeIcon, size: isSmall ? 21 : 23),
                          label: d.label,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          );
        }

        if (isTablet) {
          return Scaffold(
            backgroundColor: backgroundColor,
            appBar: appBar,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      right: BorderSide(color: Colors.grey.shade200, width: 1),
                    ),
                  ),
                  child: SafeArea(
                    right: false,
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: IntrinsicHeight(
                          child: NavigationRail(
                            selectedIndex: currentIndex < destinations.length ? currentIndex : 0,
                            onDestinationSelected: onDestinationSelected,
                            backgroundColor: Colors.white,
                            labelType: NavigationRailLabelType.all,
                            minWidth: 88,
                            useIndicator: true,
                            indicatorColor: primaryColor.withValues(alpha: 0.12),
                            selectedIconTheme: IconThemeData(color: primaryColor, size: 24),
                            unselectedIconTheme:
                                const IconThemeData(color: Color(0xFF64748B), size: 22),
                            selectedLabelTextStyle: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                            unselectedLabelTextStyle: const TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                            ),
                            leading: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                children: [
                                  const AppLogo(size: 34),
                                  if (isOnlineOrOpen != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: isOnlineOrOpen!
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFFDC2626),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            destinations: destinations
                                .map(
                                  (d) => NavigationRailDestination(
                                    icon: Icon(d.icon),
                                    selectedIcon: Icon(d.activeIcon),
                                    label: Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        d.label,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          );
        }

        // Laptop & Large Desktop (>= 1024 px): Full Left Sidebar Navigation
        final sidebarWidth = width >= ResponsiveLayout.laptopMax ? 272.0 : 248.0;
        return Scaffold(
          backgroundColor: backgroundColor,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDesktopSidebar(context, sidebarWidth),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ?topBar,
                    Expanded(child: body),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopSidebar(BuildContext context, double width) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade100),
                ),
              ),
              child: Row(
                children: [
                  const AppLogo(size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workspaceTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: primaryColor,
                            letterSpacing: 0.6,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          workspaceSubtitle,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Business Summary Card (if provided)
            if ((businessName != null && businessName!.isNotEmpty) ||
                isOnlineOrOpen != null ||
                statusLabel != null)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (businessName != null && businessName!.isNotEmpty)
                      Text(
                        businessName!,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (categoryLabel != null && categoryLabel!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        categoryLabel!,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (isOnlineOrOpen != null || statusLabel != null) ...[
                      if (businessName != null && businessName!.isNotEmpty)
                        const SizedBox(height: 8),
                      Row(
                        children: [
                          if (isOnlineOrOpen != null) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isOnlineOrOpen!
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFDC2626),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              statusLabel ??
                                  (isOnlineOrOpen == true
                                      ? 'Online / Active'
                                      : 'Offline / Closed'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: (isOnlineOrOpen ?? true)
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFB91C1C),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (headerAction != null) ...[
                            const SizedBox(width: 6),
                            headerAction!,
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),

            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Text(
                'NAVIGATION',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.9,
                ),
              ),
            ),

            // Navigation Items & Scrollable Footer (Zero Overflow on 768p Laptops)
            Expanded(
              child: ListView(
                primary: false,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: [
                  for (int index = 0; index < destinations.length; index++) ...[
                    _buildNavItem(context, destinations[index], index),
                    const SizedBox(height: 4),
                  ],
                  if (sidebarFooter != null) ...[
                    const SizedBox(height: 8),
                    sidebarFooter!,
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, WorkspaceNavDestination dest, int index) {
    final isSelected = index == currentIndex;
    return Material(
      color: isSelected
          ? primaryColor.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: Key('sidebar_nav_item_$index'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => onDestinationSelected(index),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 11,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? dest.activeIcon : dest.icon,
                size: 21,
                color: isSelected
                    ? primaryColor
                    : const Color(0xFF64748B),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  dest.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.w600,
                    color: isSelected
                        ? primaryColor
                        : const Color(0xFF334155),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (dest.badgeText != null &&
                  dest.badgeText!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    dest.badgeText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (isSelected)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
