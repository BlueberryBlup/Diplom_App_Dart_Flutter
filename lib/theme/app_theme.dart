import 'package:flutter/material.dart';

class AppTheme {
  //static const Color primaryColor = Color.fromARGB(255, 28, 90, 92);
  static const Color primaryColor = Color.fromARGB(255, 37, 126, 129);
  static const Color appBarColor = Color.fromARGB(255, 70, 126, 167);
  static const Color redApp = Color.fromARGB(226, 247, 78, 66);
  static const Color orangeApp = Color.fromARGB(255, 255, 188, 87);
  static const Color blueApp = Color.fromARGB(255, 128, 188, 238);
  static const Color greenApp = Color.fromARGB(255, 110, 212, 90);
  static const Color purpleApp = Color.fromARGB(255, 201, 119, 221);
  static const Color pinkApp = Color.fromARGB(255, 221, 119, 196);
  static const Color darkBlueApp = Color.fromARGB(255, 95, 140, 207);

  static const String _fontFamily = 'Raleway';

  static ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );
}
