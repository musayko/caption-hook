// lib/src/constants/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Colors based on Design Doc [cite: 1]
const Color kPrimaryAccent = Color(0xFFFFBB3F); // Gradient Start
const Color kPrimaryAccentEnd = Color(0xFFE41CB4); // Gradient End (can be used for secondary accent)
const Color kCharcoalText = Color(0xFF2E2E2E);
const Color kSoftGrayBackground = Color(0xFFF9F9F9);
const Color kLightGrayBorder = Color(0xFFDCDCDC);
const Color kMutedGrayText = Color(0xFF6F6F6F);
const Color kErrorRed = Color(0xFFE63946);
const Color kSuccessGreen = Color(0xFF52B788);

// Text Styles mapping from Design Doc [cite: 3]
final TextTheme kTextTheme = TextTheme(
  // Display: Poppins 40 ExtraBold
  displayLarge: GoogleFonts.poppins(fontSize: 40, fontWeight: FontWeight.w800, color: kCharcoalText),
  // Title: Sora 28 Bold
  titleLarge: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w700, color: kCharcoalText),
  // Subtitle: Sora 20 SemiBold
  titleMedium: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w600, color: kCharcoalText),
  // Body: Sora 16 Regular
  bodyMedium: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w400, color: kCharcoalText),
  // Default body large style if needed
  bodyLarge: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w400, color: kCharcoalText),
  // Caption: Inter 14 Medium
  labelSmall: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: kMutedGrayText),
  // Button Text: Poppins 16 SemiBold
  labelLarge: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600), // Used in ElevatedButtonTheme
);

// App Theme Definition
final ThemeData appTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: kSoftGrayBackground,
  textTheme: kTextTheme,
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: kPrimaryAccent,
    onPrimary: Colors.white, // Text on primary buttons
    secondary: kPrimaryAccentEnd, // Can use the gradient end color
    onSecondary: Colors.white,
    error: kErrorRed,
    onError: Colors.white,
    background: kSoftGrayBackground,
    onBackground: kCharcoalText, // Default text color on background
    surface: Colors.white, // Card backgrounds, dialogs etc.
    onSurface: kCharcoalText, // Default text color on surface
    outline: kLightGrayBorder, // Borders
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.white, // Or kSoftGrayBackground if preferred
    foregroundColor: kCharcoalText, // Title color
    elevation: 1, // Subtle elevation
    titleTextStyle: kTextTheme.titleMedium, // Use Subtitle style for AppBar title
    iconTheme: const IconThemeData(color: kCharcoalText), // Icons in AppBar
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimaryAccent, // Button background [cite: 5]
      foregroundColor: Colors.white, // Button text color [cite: 5]
      textStyle: kTextTheme.labelLarge?.copyWith(letterSpacing: 0.5), // Use Button Text style [cite: 3]
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), // Approx based on 48px height [cite: 5]
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // Regular button border radius [cite: 5]
      ),
      elevation: 2,
    ),
  ),
  // Add other theme properties as needed (InputDecorationTheme, CardTheme, etc.)
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    hintStyle: kTextTheme.labelSmall?.copyWith(color: kMutedGrayText), // Placeholder text style [cite: 5]
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12), // Consistent border radius
      borderSide: const BorderSide(color: kLightGrayBorder, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kLightGrayBorder, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kPrimaryAccent, width: 2), // Border on focus [cite: 5] - using primary accent
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kErrorRed, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kErrorRed, width: 2),
    ),
    labelStyle: kTextTheme.bodyMedium, // Style for floating labels
    errorStyle: kTextTheme.labelSmall?.copyWith(color: kErrorRed), // Helper text for errors [cite: 5]
  ),
  cardTheme: CardTheme(
      elevation: 2, // Subtle elevation instead of large shadow for performance
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0), // Corner radius [cite: 5]
      ),
      color: Colors.white,
      surfaceTintColor: Colors.white, // Prevents Material3 tinting if white card desired
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0) // Default margin for cards
  ),
);