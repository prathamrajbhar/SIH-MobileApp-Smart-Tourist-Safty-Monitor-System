import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modern, minimalistic color palette for SafeHorizon app
class AppColors {
  // Primary brand colors - Professional blue palette
  static const primary = Color(0xFF2563EB); // Vibrant blue
  static const primaryDark = Color(0xFF1E40AF);
  static const primaryLight = Color(0xFF60A5FA);
  static const primarySurface = Color(0xFFEFF6FF); // Light blue tint
  
  // Semantic colors
  static const success = Color(0xFF10B981); // Emerald green
  static const successLight = Color(0xFFD1FAE5);
  static const warning = Color(0xFFF59E0B); // Amber
  static const warningLight = Color(0xFFFEF3C7);
  static const error = Color(0xFFEF4444); // Bright red
  static const errorLight = Color(0xFFFEE2E2);
  static const info = Color(0xFF3B82F6); // Blue
  static const infoLight = Color(0xFFDBEAFE);
  
  // Text colors - Clear hierarchy
  static const textPrimary = Color(0xFF0F172A); // Almost black
  static const textSecondary = Color(0xFF475569); // Medium slate
  static const textTertiary = Color(0xFF94A3B8); // Light slate
  static const textDisabled = Color(0xFFCBD5E1); // Very light slate
  static const textOnPrimary = Color(0xFFFFFFFF); // White on colored backgrounds
  
  // Background colors - Clean and spacious
  static const background = Color(0xFFFAFAFA); // Off-white
  static const surface = Color(0xFFFFFFFF); // Pure white
  static const surfaceElevated = Color(0xFFFFFFFF); // Slightly elevated surface
  static const surfaceVariant = Color(0xFFF8FAFC); // Subtle gray
  static const overlay = Color(0x80000000); // Semi-transparent black
  
  // Border and divider colors
  static const border = Color(0xFFE2E8F0); // Light border
  static const borderLight = Color(0xFFF1F5F9); // Very light border
  static const divider = Color(0xFFE5E7EB); // Subtle divider
  static const borderFocus = Color(0xFF2563EB); // Primary focus
  
  // Special colors
  static const shadow = Color(0x0F000000); // Subtle shadow
  static const shimmer = Color(0xFFF3F4F6); // Loading shimmer
  
  // Status colors for safety score
  static const safeLow = Color(0xFF10B981); // Green
  static const safeMedium = Color(0xFFF59E0B); // Amber
  static const safeHigh = Color(0xFFEF4444); // Red
  static const safeCritical = Color(0xFFDC2626); // Dark red
}

/// Consistent spacing scale for the entire app
class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
  static const xxxl = 64.0;
  
  // Specific use cases
  static const screenPadding = md;
  static const cardPadding = md;
  static const sectionSpacing = lg;
  static const itemSpacing = xs;
}

/// Border radius scale for consistency
class AppRadius {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const full = 999.0;
  
  // Specific use cases
  static const button = md;
  static const card = lg;
  static const dialog = xl;
  static const bottomSheet = xxl;
}

/// Typography scale with clear hierarchy
class AppTypography {
  static const String fontFamily = 'Inter';
  
  // Display styles (large headings)
  static const displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );
  
  static const displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );
  
  // Heading styles
  static const headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );
  
  static const headingMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );
  
  static const headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );
  
  // Body styles
  static const bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );
  
  static const bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.1,
    color: AppColors.textSecondary,
  );
  
  static const bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.2,
    color: AppColors.textTertiary,
  );
  
  // Label styles (for buttons, tabs, etc.)
  static const labelLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: 0.3,
    color: AppColors.textPrimary,
  );
  
  static const labelMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.2,
    color: AppColors.textPrimary,
  );
  
  static const labelSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.3,
    color: AppColors.textSecondary,
  );
  
  // Special styles
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.3,
    color: AppColors.textTertiary,
  );
  
  static const overline = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    height: 1.6,
    letterSpacing: 1.5,
    color: AppColors.textSecondary,
  );
}

/// Elevation and shadow definitions
class AppElevation {
  static const none = 0.0;
  static const xs = 1.0;
  static const sm = 2.0;
  static const md = 4.0;
  static const lg = 8.0;
  static const xl = 16.0;
  
  // Shadow definitions
  static const shadowXs = [
    BoxShadow(
      color: AppColors.shadow,
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];
  
  static const shadowSm = [
    BoxShadow(
      color: AppColors.shadow,
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];
  
  static const shadowMd = [
    BoxShadow(
      color: AppColors.shadow,
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];
  
  static const shadowLg = [
    BoxShadow(
      color: AppColors.shadow,
      offset: Offset(0, 8),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];
}

/// Animation durations for consistency
class AppDuration {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 350);
  static const verySlow = Duration(milliseconds: 500);
}

/// Animation curves
class AppCurves {
  static const easeIn = Curves.easeIn;
  static const easeOut = Curves.easeOut;
  static const easeInOut = Curves.easeInOut;
  static const smooth = Curves.easeInOutCubic;
}

/// Modern button styles with consistent design
final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: AppColors.primary,
  foregroundColor: AppColors.textOnPrimary,
  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
  elevation: 0,
  shadowColor: Colors.transparent,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.button),
  ),
  textStyle: AppTypography.labelLarge,
).copyWith(
  overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.1)),
);

final ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: AppColors.surfaceVariant,
  foregroundColor: AppColors.textPrimary,
  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
  elevation: 0,
  shadowColor: Colors.transparent,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.button),
  ),
  textStyle: AppTypography.labelLarge,
).copyWith(
  overlayColor: WidgetStateProperty.all(AppColors.textPrimary.withValues(alpha: 0.05)),
);

final ButtonStyle outlineButtonStyle = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
  side: const BorderSide(color: AppColors.border, width: 1.5),
  foregroundColor: AppColors.textPrimary,
  backgroundColor: Colors.transparent,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.button),
  ),
  textStyle: AppTypography.labelLarge,
).copyWith(
  overlayColor: WidgetStateProperty.all(AppColors.textPrimary.withValues(alpha: 0.05)),
  side: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.pressed)) {
      return const BorderSide(color: AppColors.primary, width: 1.5);
    }
    if (states.contains(WidgetState.hovered)) {
      return const BorderSide(color: AppColors.textSecondary, width: 1.5);
    }
    return const BorderSide(color: AppColors.border, width: 1.5);
  }),
);

final ButtonStyle textButtonStyle = TextButton.styleFrom(
  foregroundColor: AppColors.primary,
  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
  textStyle: AppTypography.labelMedium,
).copyWith(
  overlayColor: WidgetStateProperty.all(AppColors.primary.withValues(alpha: 0.08)),
);

final ButtonStyle dangerButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: AppColors.error,
  foregroundColor: Colors.white,
  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
  elevation: 0,
  shadowColor: Colors.transparent,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.button),
  ),
  textStyle: AppTypography.labelLarge,
).copyWith(
  overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.1)),
);

/// Modern input decoration theme
InputDecorationTheme get inputDecorationTheme => InputDecorationTheme(
  filled: true,
  fillColor: AppColors.surface,
  contentPadding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.md,
  ),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: const BorderSide(color: AppColors.border, width: 1.5),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: const BorderSide(color: AppColors.border, width: 1.5),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: const BorderSide(color: AppColors.borderFocus, width: 2),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: const BorderSide(color: AppColors.error, width: 1.5),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: const BorderSide(color: AppColors.error, width: 2),
  ),
  labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
  floatingLabelStyle: AppTypography.labelMedium.copyWith(color: AppColors.primary),
  hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
  errorStyle: AppTypography.bodySmall.copyWith(color: AppColors.error),
  prefixIconColor: AppColors.textTertiary,
  suffixIconColor: AppColors.textTertiary,
);

/// Card theme for consistent card design
CardThemeData get cardTheme => CardThemeData(
  elevation: 0,
  shadowColor: Colors.transparent,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.card),
    side: const BorderSide(color: AppColors.borderLight, width: 1),
  ),
  color: AppColors.surface,
  margin: EdgeInsets.zero,
);

/// AppBar theme for consistent header design
AppBarTheme get appBarTheme => AppBarTheme(
  elevation: 0,
  scrolledUnderElevation: 0,
  centerTitle: false,
  backgroundColor: AppColors.surface,
  foregroundColor: AppColors.textPrimary,
  surfaceTintColor: Colors.transparent,
  shadowColor: Colors.transparent,
  titleTextStyle: AppTypography.headingMedium,
  toolbarHeight: 64,
  systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.dark,
  ),
);

/// Bottom navigation bar theme
BottomNavigationBarThemeData get bottomNavigationBarTheme => BottomNavigationBarThemeData(
  backgroundColor: AppColors.surface,
  selectedItemColor: AppColors.primary,
  unselectedItemColor: AppColors.textTertiary,
  selectedLabelStyle: AppTypography.labelSmall,
  unselectedLabelStyle: AppTypography.labelSmall,
  type: BottomNavigationBarType.fixed,
  elevation: 8,
  showSelectedLabels: true,
  showUnselectedLabels: true,
);

/// Floating Action Button theme
FloatingActionButtonThemeData get fabTheme => FloatingActionButtonThemeData(
  backgroundColor: AppColors.error,
  foregroundColor: Colors.white,
  elevation: 4,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.full),
  ),
);

/// Dialog theme
DialogThemeData get dialogTheme => DialogThemeData(
  backgroundColor: AppColors.surface,
  elevation: 8,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.dialog),
  ),
  titleTextStyle: AppTypography.headingMedium,
  contentTextStyle: AppTypography.bodyMedium,
);

/// Chip theme
ChipThemeData get chipTheme => ChipThemeData(
  backgroundColor: AppColors.surfaceVariant,
  deleteIconColor: AppColors.textSecondary,
  disabledColor: AppColors.borderLight,
  selectedColor: AppColors.primarySurface,
  secondarySelectedColor: AppColors.primarySurface,
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
  labelStyle: AppTypography.labelSmall,
  secondaryLabelStyle: AppTypography.labelSmall,
  brightness: Brightness.light,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
  ),
);

/// Complete Material Design 3 theme
ThemeData get appTheme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  
  // Color scheme
  colorScheme: ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.textOnPrimary,
    primaryContainer: AppColors.primarySurface,
    secondary: AppColors.textSecondary,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.error,
    onError: Colors.white,
    outline: AppColors.border,
    shadow: AppColors.shadow,
  ),
  
  // Typography
  fontFamily: AppTypography.fontFamily,
  textTheme: TextTheme(
    displayLarge: AppTypography.displayLarge,
    displayMedium: AppTypography.displayMedium,
    headlineLarge: AppTypography.headingLarge,
    headlineMedium: AppTypography.headingMedium,
    headlineSmall: AppTypography.headingSmall,
    bodyLarge: AppTypography.bodyLarge,
    bodyMedium: AppTypography.bodyMedium,
    bodySmall: AppTypography.bodySmall,
    labelLarge: AppTypography.labelLarge,
    labelMedium: AppTypography.labelMedium,
    labelSmall: AppTypography.labelSmall,
  ),
  
  // Component themes
  scaffoldBackgroundColor: AppColors.background,
  appBarTheme: appBarTheme,
  cardTheme: cardTheme,
  inputDecorationTheme: inputDecorationTheme,
  bottomNavigationBarTheme: bottomNavigationBarTheme,
  floatingActionButtonTheme: fabTheme,
  dialogTheme: dialogTheme,
  chipTheme: chipTheme,
  
  // Button themes
  elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
  outlinedButtonTheme: OutlinedButtonThemeData(style: outlineButtonStyle),
  textButtonTheme: TextButtonThemeData(style: textButtonStyle),
  
  // Other component themes
  dividerTheme: const DividerThemeData(
    color: AppColors.divider,
    thickness: 1,
    space: 1,
  ),
  
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.primary,
    linearTrackColor: AppColors.borderLight,
  ),
  
  snackBarTheme: SnackBarThemeData(
    backgroundColor: AppColors.textPrimary,
    contentTextStyle: AppTypography.bodyMedium.copyWith(color: Colors.white),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
  ),
  
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.primary;
      return AppColors.border;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.primaryLight;
      return AppColors.borderLight;
    }),
  ),
  
  // Page transitions
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  ),
);
