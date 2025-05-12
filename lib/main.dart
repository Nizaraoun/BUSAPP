import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application_1/acceuil.dart';
import 'package:flutter_application_1/authentication.dart';
import 'package:flutter_application_1/login.dart';
// Fichier généré par FlutterFire CLI

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation de Firebase avec gestion d'erreur complète
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase initialisé avec succès");
  } catch (e) {
    debugPrint("Erreur d'initialisation Firebase: $e");
    rethrow; // Propager l'erreur pour un traitement ultérieur
  }

  runApp(const BusTrackerApp());
}

class DefaultFirebaseOptions {
  static var currentPlatform;
}

class BusTrackerApp extends StatelessWidget {
  const BusTrackerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bus Tracker',
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
