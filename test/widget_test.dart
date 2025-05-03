import 'package:flutter_test/flutter_test.dart';
// Assure-toi que l'import est correct

void main() {
  testWidgets('Test initial du Pictionary', (WidgetTester tester) async {
    // Construis le widget à tester
    await tester.pumpWidget(PictionisApp()); // Remplace MyApp par ton widget principal

    // Effectue tes vérifications de base
    expect(find.text('Dessine!'), findsOneWidget);
    expect(find.text('Deviner'), findsNothing);
  });
}
