// import 'package:flutter/material.dart';
// import 'features/home/home_page.dart';

// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   runApp(const WoodLoggerApp());
// }

// class WoodLoggerApp extends StatelessWidget {
//   const WoodLoggerApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Lorry Wood Logger',
//       theme: ThemeData(
//         useMaterial3: true,
//         colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
//         inputDecorationTheme: const InputDecorationTheme(
//           border: OutlineInputBorder(),
//         ),
//       ),
//       home: const HomePage(),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'features/home/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WoodLoggerApp());
}

class WoodLoggerApp extends StatelessWidget {
  const WoodLoggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      brightness: Brightness.light,
      seedColor: const Color(0xFF6D4C41), // brown seed
    ).copyWith(
      // warm, wood-shop vibes
      primary: const Color(0xFF5D4037),            // deep brown
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD7CCC8),   // light wood
      onPrimaryContainer: const Color(0xFF3E2723),

      secondary: const Color(0xFFFFC107),          // amber (CTA)
      onSecondary: Colors.black,
      secondaryContainer: const Color(0xFFFFE082),
      onSecondaryContainer: const Color(0xFF3E2723),

      surface: const Color(0xFFFFFBF2),            // warm off-white
      onSurface: const Color(0xFF3E2723),
      surfaceTint: const Color(0xFF5D4037),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lorry Wood Logger',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        appBarTheme: AppBarTheme(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const HomePage(),
    );
  }
}
