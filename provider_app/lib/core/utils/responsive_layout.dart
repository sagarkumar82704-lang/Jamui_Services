import 'package:flutter/material.dart';

enum ProviderDeviceSize {
  smallMobile, // 320 - 360 px
  standardMobile, // 361 - 430 px
  largeMobile, // 431 - 599 px
  tablet, // 600 - 1023 px
  laptop, // 1024 - 1439 px
  largeDesktop, // >= 1440 px
}

/// Centralized responsive breakpoint & layout helper for Jamui Services Provider App.
/// Supports:
/// - Small mobile phones: 320–360 px
/// - Standard mobile phones: 361–430 px
/// - Large mobile phones: 431–600 px
/// - Tablets: 600–1024 px
/// - Laptops: 1024–1440 px
/// - Large desktop screens: above 1440 px
class ResponsiveLayout {
  ResponsiveLayout._();

  static const double smallMobileMax = 360.0;
  static const double standardMobileMax = 430.0;
  static const double mobileMax = 600.0;
  static const double tabletMax = 1024.0;
  static const double laptopMax = 1440.0;

  static double screenWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  static ProviderDeviceSize deviceSizeOf(BuildContext context) {
    final width = screenWidth(context);
    return deviceSizeFromWidth(width);
  }

  static ProviderDeviceSize deviceSizeFromWidth(double width) {
    if (width <= smallMobileMax) return ProviderDeviceSize.smallMobile;
    if (width <= standardMobileMax) return ProviderDeviceSize.standardMobile;
    if (width < mobileMax) return ProviderDeviceSize.largeMobile;
    if (width < tabletMax) return ProviderDeviceSize.tablet;
    if (width <= laptopMax) return ProviderDeviceSize.laptop;
    return ProviderDeviceSize.largeDesktop;
  }

  static ProviderDeviceSize getDeviceSize(double width) => deviceSizeFromWidth(width);

  static bool isSmallMobile(BuildContext context) =>
      screenWidth(context) <= smallMobileMax;

  static bool isMobile(BuildContext context) =>
      screenWidth(context) < mobileMax;

  static bool isTablet(BuildContext context) {
    final w = screenWidth(context);
    return w >= mobileMax && w < tabletMax;
  }

  static bool isLaptop(BuildContext context) {
    final w = screenWidth(context);
    return w >= tabletMax && w < laptopMax;
  }

  static bool isLargeDesktop(BuildContext context) =>
      screenWidth(context) >= laptopMax;

  static bool isDesktop(BuildContext context) =>
      screenWidth(context) >= tabletMax;

  static bool isTabletOrDesktop(BuildContext context) =>
      screenWidth(context) >= mobileMax;

  /// Responsive horizontal padding based on screen width.
  static double horizontalPadding(BuildContext context) {
    final w = screenWidth(context);
    if (w <= smallMobileMax) return 12.0;
    if (w < mobileMax) return 16.0;
    if (w < tabletMax) return 24.0;
    if (w < laptopMax) return 28.0;
    return 36.0;
  }

  /// Responsive EdgeInsets for page content.
  static EdgeInsets pagePadding(BuildContext context, {double vertical = 16.0}) {
    final h = horizontalPadding(context);
    final v = isSmallMobile(context) ? 12.0 : vertical;
    return EdgeInsets.symmetric(horizontal: h, vertical: v);
  }

  /// Maximum content width so wide screens don't stretch cards edge-to-edge.
  static double maxContentWidth(BuildContext context) {
    final w = screenWidth(context);
    if (w < mobileMax) return double.infinity;
    if (w < tabletMax) return 960.0;
    if (w < laptopMax) return 1240.0;
    return 1400.0;
  }

  /// Ideal column count for KPI / summary metric grids.
  static int kpiColumnsForWidth(double availableWidth) {
    if (availableWidth >= 900) return 4;
    if (availableWidth >= 600) return 3;
    return 2;
  }

  /// Ideal column count for content cards (Leads, Listings, Products, Orders, Plans).
  static int cardColumnsForWidth(
    double availableWidth, {
    int desktopColumns = 2,
    int largeDesktopColumns = 3,
  }) {
    if (availableWidth >= 1180) return largeDesktopColumns;
    if (availableWidth >= 680) return desktopColumns;
    return 1;
  }

  /// Maximum width for dialogs & modals across breakpoints.
  static double dialogMaxWidth(BuildContext context) {
    final w = screenWidth(context);
    if (w < mobileMax) return w - 24;
    return 520.0;
  }
}

/// Constrains child to a centered max-width container on tablet/laptop/desktop
/// while keeping full width on mobile.
class ResponsiveContentContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  const ResponsiveContentContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth =
        maxWidth ?? ResponsiveLayout.maxContentWidth(context);
    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: content,
      ),
    );
  }
}

/// Centered responsive card wrapper for Auth, Onboarding, and single-column forms.
/// On mobile: renders cleanly with compact padding.
/// On tablet/laptop/desktop: renders inside an elevated centered card with constrained width.
class ResponsiveFormShell extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? mobilePadding;
  final EdgeInsetsGeometry? desktopPadding;
  final Color? cardColor;

  const ResponsiveFormShell({
    super.key,
    required this.child,
    this.maxWidth = 520.0,
    this.mobilePadding,
    this.desktopPadding,
    this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= ResponsiveLayout.mobileMax;
        final isSmall = constraints.maxWidth <= ResponsiveLayout.smallMobileMax;
        final pad = isWide
            ? (desktopPadding ?? const EdgeInsets.all(32.0))
            : (mobilePadding ??
                EdgeInsets.symmetric(
                  horizontal: isSmall ? 14.0 : 20.0,
                  vertical: isSmall ? 16.0 : 24.0,
                ));

        if (!isWide) {
          return Padding(
            padding: pad,
            child: child,
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              padding: pad,
              decoration: BoxDecoration(
                color: cardColor ?? Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Renders items in a 1-column list on mobile and a multi-column balanced rows grid on tablet/desktop.
/// Works safely inside a `SingleChildScrollView` or `ListView` without requiring fixed aspect ratios!
class ResponsiveCardGrid extends StatelessWidget {
  final List<Widget> children;
  final int tabletColumns;
  final int desktopColumns;
  final int largeDesktopColumns;
  final double spacing;
  final double runSpacing;

  const ResponsiveCardGrid({
    super.key,
    required this.children,
    this.tabletColumns = 2,
    this.desktopColumns = 2,
    this.largeDesktopColumns = 2,
    this.spacing = 14.0,
    this.runSpacing = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        int cols = 1;
        if (w >= 1180) {
          cols = largeDesktopColumns;
        } else if (w >= 840) {
          cols = desktopColumns;
        } else if (w >= 580) {
          cols = tabletColumns;
        }

        if (cols <= 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: runSpacing),
                children[i],
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (int i = 0; i < children.length; i += cols) {
          if (i > 0) {
            rows.add(SizedBox(height: runSpacing));
          }
          final rowChildren = <Widget>[];
          for (int j = 0; j < cols; j++) {
            if (j > 0) {
              rowChildren.add(SizedBox(width: spacing));
            }
            final idx = i + j;
            if (idx < children.length) {
              rowChildren.add(Expanded(child: children[idx]));
            } else {
              rowChildren.add(const Expanded(child: SizedBox.shrink()));
            }
          }
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rowChildren,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}
