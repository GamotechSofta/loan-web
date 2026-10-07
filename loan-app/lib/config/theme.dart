import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the mobile app. The palette is the blue system used across
/// the app screens; Sakaar's wordmark and logo are kept as the brand identity.
class AppColors {
  static const Color brand = Color(0xFF2563EB);
  static const Color brandDeep = Color(0xFF1D4ED8);
  static const Color brandDark = Color(0xFF1E40AF);
  static const Color brandSoft = Color(0xFFEFF6FF);
  static const Color brandSoftDeep = Color(0xFFDBEAFE);
  static const Color navy = Color(0xFF1E3A8A);

  /// Amber accent kept for the "in progress" states.
  static const Color gold = Color(0xFFF59E0B);
  static const Color goldDeep = Color(0xFFD97706);

  static const Color ink = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF8FAFC);
  static const Color line = Color(0xFFE2E8F0);

  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  static const Color heroMid = Color(0xFF1D4ED8);
  static const Color sky200 = Color(0xFFBAE6FD);

  static const Color amber50 = Color(0xFFFFFBEB);
  static const Color amber200 = Color(0xFFFDE68A);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber700 = Color(0xFFB45309);
  static const Color amber900 = Color(0xFF78350F);
  static const Color emerald50 = Color(0xFFECFDF5);
  static const Color emerald100 = Color(0xFFD1FAE5);
  static const Color emerald200 = Color(0xFFA7F3D0);
  static const Color emerald600 = Color(0xFF059669);
  static const Color emerald700 = Color(0xFF047857);
  static const Color emerald800 = Color(0xFF065F46);
  static const Color green50 = Color(0xFFF0FDF4);
  static const Color green100 = Color(0xFFDCFCE7);
  static const Color green200 = Color(0xFFBBF7D0);
  static const Color green600 = Color(0xFF16A34A);
  static const Color green700 = Color(0xFF15803D);
  static const Color green800 = Color(0xFF166534);
  static const Color red50 = Color(0xFFFEF2F2);
  static const Color red200 = Color(0xFFFECACA);
  static const Color red600 = Color(0xFFDC2626);
  static const Color rose50 = Color(0xFFFFF1F2);
  static const Color rose700 = Color(0xFFBE123C);

  /// Website palette (`frontend/src/index.css`), used by the home page.
  static const Color siteNavy = Color(0xFF0B254A);
  static const Color siteNavyDeep = Color(0xFF071A36);
  static const Color siteGold = Color(0xFFB5873E);
  static const Color siteGoldDeep = Color(0xFF9A7234);
  static const Color siteSoft = Color(0xFFF4EBE0);
  static const Color siteSurface = Color(0xFFF7F5F2);
}

/// Corner radii used by the cards, inputs and buttons.
class AppRadius {
  const AppRadius._();

  static const double field = 10;
  static const double button = 10;
  static const double card = 14;
  static const double feature = 18;
}

/// Fill of the primary feature cards (eligibility card, "Apply for Loan" card).
const LinearGradient brandCardGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppColors.brand, AppColors.brandDeep],
);

/// Retained for the screens that still paint a full-bleed brand background.
const LinearGradient brandHeroGradient = LinearGradient(
  begin: Alignment(-0.364, -1),
  end: Alignment(0.364, 1),
  stops: [0, 0.55, 1],
  colors: [AppColors.brand, AppColors.heroMid, AppColors.brandDark],
);

/// Port of the website `.brand-hero-bg` (160deg navy to black).
const LinearGradient siteHeroGradient = LinearGradient(
  begin: Alignment(-0.364, -1),
  end: Alignment(0.364, 1),
  stops: [0, 0.55, 1],
  colors: [AppColors.siteNavy, AppColors.siteNavyDeep, Colors.black],
);

const List<BoxShadow> shadowSm = [
  BoxShadow(color: Color(0x0D0F172A), blurRadius: 2, offset: Offset(0, 1)),
];

/// Resting elevation of the content cards.
const List<BoxShadow> shadowCard = [
  BoxShadow(color: Color(0x0F0F172A), blurRadius: 18, offset: Offset(0, 6)),
];

const List<BoxShadow> shadowCardHover = [
  BoxShadow(color: Color(0x1A2563EB), blurRadius: 28, offset: Offset(0, 12)),
];

const List<BoxShadow> shadowTestimonial = [
  BoxShadow(color: Color(0x0F0F172A), blurRadius: 24, offset: Offset(0, 8)),
];

/// Elevation of the blue feature cards.
const List<BoxShadow> shadowBrandCard = [
  BoxShadow(color: Color(0x332563EB), blurRadius: 24, offset: Offset(0, 10)),
];

ThemeData buildAppTheme() {
  final base = GoogleFonts.interTextTheme();
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      primary: AppColors.brand,
      secondary: AppColors.brandDeep,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.surfaceMuted,
    textTheme: base.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.slate900,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      space: 1,
      thickness: 1,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.brand;
        return null;
      }),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.slate300,
        disabledForegroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.slate700,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
