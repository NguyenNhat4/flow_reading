import 'dart:typed_data';

import 'package:flow_reading/app/flow_reading_app.dart';
import 'package:flow_reading/shared/data/providers.dart';
import 'package:flow_reading/shared/domain/book.dart';
import 'package:flow_reading/shared/domain/repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows an accessible empty library in portrait and landscape', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWith(
            (ref) async => _EmptyBookRepository(),
          ),
        ],
        child: const FlowReadingApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your library is ready'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Empty library')), findsOneWidget);
    expect(find.text('Import EPUB'), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(900, 450));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpAndSettle();
    expect(find.text('Your library is ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

class _EmptyBookRepository implements BookRepository {
  @override
  Future<void> delete(
    String bookId, {
    required bool deleteAssociatedData,
    Set<AssociatedDataKind> retainedData = const {},
  }) async {}

  @override
  Future<Book?> getById(String id) async => null;

  @override
  Future<Book?> getBySourceFingerprint(String fingerprint) async => null;

  @override
  Future<void> import(Book book, Uint8List untouchedSourceBytes) async {}

  @override
  Stream<List<Book>> watchLibrary() => Stream.value(const []);
}
