import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Mock de FirebaseFirestore pour les tests

void main() {
  testWidgets('Admin interface form validation test',
      (WidgetTester tester) async {
    // Vérifier que les champs de formulaire sont présents
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.text('Code du bus'), findsOneWidget);
    expect(find.text('Nom de la ligne'), findsOneWidget);
    expect(find.text('Stations (séparées par des virgules)'), findsOneWidget);

    // Vérifier que le bouton d'enregistrement est présent
    expect(find.text('Enregistrer'), findsOneWidget);

    // Tester la validation du formulaire (cas d'échec)
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    // Vérifier que les messages d'erreur s'affichent
    expect(find.text('Veuillez entrer le code du bus'), findsOneWidget);
    expect(find.text('Veuillez entrer le nom de la ligne'), findsOneWidget);
    expect(find.text('Veuillez entrer les stations'), findsOneWidget);

    // Remplir les champs du formulaire
    await tester.enterText(find.byType(TextFormField).at(0), 'BUS001');
    await tester.enterText(find.byType(TextFormField).at(1), 'Ligne Express');
    await tester.enterText(
        find.byType(TextFormField).at(2), 'Gare, Centre, Hôpital');
    await tester.pump();

    // Vérifier que les champs contiennent les valeurs saisies
    expect(find.text('BUS001'), findsOneWidget);
    expect(find.text('Ligne Express'), findsOneWidget);
    expect(find.text('Gare, Centre, Hôpital'), findsOneWidget);
  });
}
