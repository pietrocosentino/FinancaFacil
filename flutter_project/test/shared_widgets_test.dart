import 'dart:typed_data';

import 'package:financafacil/features/profile/data/profile_photo_source.dart';
import 'package:financafacil/features/profile/presentation/profile_controller.dart';
import 'package:financafacil/features/profile/presentation/screens/profile_screen.dart';
import 'package:financafacil/shared/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_repositories.dart';

class _FakePhotoSource implements ProfilePhotoSource {
  Uint8List? next;
  Object? error;
  int calls = 0;

  Future<Uint8List?> _pick() async {
    calls++;
    if (error != null) throw error!;
    return next;
  }

  @override
  Future<Uint8List?> fromFiles() => _pick();
  @override
  Future<Uint8List?> fromGallery() => _pick();
  @override
  Future<Uint8List?> fromGooglePhotos() => _pick();
  @override
  Future<Uint8List?> fromDrive() => _pick();
}

void main() {
  group('showConfirmDialog', () {
    Future<List<bool>> open(
      WidgetTester tester, {
      bool dismissible = true,
    }) async {
      final values = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => values.add(
                await showConfirmDialog(
                  context,
                  title: 'Excluir?',
                  message: 'Não pode ser desfeito.',
                  confirmLabel: 'Confirmar exclusão',
                  cancelLabel: 'Manter',
                  destructive: true,
                  barrierDismissible: dismissible,
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      );
      return values;
    }

    Future<void> show(WidgetTester tester) async {
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Não pode ser desfeito.'), findsOneWidget);
    }

    testWidgets('confirmar, cancelar e tocar fora', (tester) async {
      final values = await open(tester);
      await show(tester);
      await tester.tap(find.text('Confirmar exclusão'));
      await tester.pumpAndSettle();
      await show(tester);
      await tester.tap(find.text('Manter'));
      await tester.pumpAndSettle();
      await show(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(values, [true, false, false]);
      expect(find.text('Não pode ser desfeito.'), findsNothing);
    });

    testWidgets('ação destrutiva usa a cor de erro do tema', (tester) async {
      await open(tester);
      await show(tester);
      final label = tester.widget<Text>(find.text('Confirmar exclusão'));
      final context = tester.element(find.text('Confirmar exclusão'));
      expect(label.style?.color, Theme.of(context).colorScheme.error);
    });

    testWidgets('sem barrierDismissible exige uma escolha', (tester) async {
      final values = await open(tester, dismissible: false);
      await show(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Não pode ser desfeito.'), findsOneWidget);
      expect(values, isEmpty);
    });
  });

  group('Foto do perfil', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<(ProfileController, _FakePhotoSource)> openProfile(
      WidgetTester tester,
    ) async {
      final controller = ProfileController(FakeProfileRepository());
      addTearDown(controller.dispose);
      final source = _FakePhotoSource();
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(controller: controller, photoSource: source),
        ),
      );
      await tester.pumpAndSettle();
      return (controller, source);
    }

    Future<void> choose(WidgetTester tester, String option) async {
      await tester.tap(find.text('Alterar foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option));
      await tester.pumpAndSettle();
    }

    testWidgets('foto escolhida na galeria é salva para a conta', (
      tester,
    ) async {
      final (controller, source) = await openProfile(tester);
      source.next = Uint8List.fromList([1, 2, 3]);
      await choose(tester, 'Galeria do celular');
      expect(source.calls, 1);
      expect(controller.photo, [1, 2, 3]);
      expect(find.text('Foto atualizada.'), findsOneWidget);
      final saved = await SharedPreferences.getInstance();
      expect(saved.getString('profile_photo:pietro@example.com'), isNotNull);
    });

    testWidgets('cancelar a escolha não altera a foto', (tester) async {
      final (controller, source) = await openProfile(tester);
      await choose(tester, 'Arquivos do celular');
      expect(source.calls, 1);
      expect(controller.photo, isNull);
      expect(find.text('Foto atualizada.'), findsNothing);
    });

    testWidgets('imagem acima do limite após redução é recusada', (
      tester,
    ) async {
      final (controller, source) = await openProfile(tester);
      source.next = Uint8List(200 * 1024 + 1);
      await choose(tester, 'Galeria do celular');
      expect(controller.photo, isNull);
      expect(
        find.text('Escolha uma imagem menor, de até 200 KB após a redução.'),
        findsOneWidget,
      );
    });

    testWidgets('arquivo inválido mostra a mensagem do leitor', (tester) async {
      final (controller, source) = await openProfile(tester);
      source.error = const FormatException('Escolha uma imagem de até 5 MB.');
      await choose(tester, 'Arquivos do celular');
      expect(controller.photo, isNull);
      expect(find.text('Escolha uma imagem de até 5 MB.'), findsOneWidget);
    });
  });
}
