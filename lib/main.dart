import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application_1/acceuil.dart';
import 'package:flutter_application_1/chauffeur_fixed.dart';
import 'package:flutter_application_1/firebase_options.dart';
import 'package:flutter_application_1/fourmulairabonn.dart';
import 'package:flutter_application_1/historique_abonnements.dart';
import 'package:flutter_application_1/login.dart';

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase initialisé avec succès");

    // Uncomment the line below to seed initial data for buses and bus stops
    // await FirebaseDataSeeder().seedAllData();
  } catch (e) {
    debugPrint("Erreur d'initialisation Firebase: $e");
  }

  runApp(const SotregamesApp());
}

class SotregamesApp extends StatelessWidget {
  const SotregamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sotregames',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF0E2A47),
          secondary: const Color(0xFF1E88E5),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0E2A47),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: LoginPage(),
      // Gestion des erreurs globales
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(1.0)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
