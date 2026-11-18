import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:catalogo_veiculos/main.dart';

void main() {
  testWidgets('exibe a identidade visual e o formulário de acesso', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Catalogo()));

    expect(find.text('GARAGEM'), findsOneWidget);
    expect(find.text('Bem-vindo de volta'), findsOneWidget);
    expect(find.text('Entrar no catálogo'), findsOneWidget);
    expect(find.byIcon(Icons.directions_car_filled_rounded), findsWidgets);
  });
}
