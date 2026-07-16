import 'dart:convert';

import 'package:flow_reading/data/services/app_database.dart';
import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/repositories/table_of_contents_repository.dart';

/// Reads canonical EPUB navigation entries from the existing books table.
final class SqliteTableOfContentsRepository
    implements TableOfContentsRepository {
  SqliteTableOfContentsRepository(this.appDatabase);

  final AppDatabase appDatabase;

  @override
  Future<List<TableOfContentsEntry>> load(String bookId) async {
    try {
      final database = await appDatabase.open();
      final rows = await database.query(
        'books',
        columns: ['toc_json'],
        where: 'id = ?',
        whereArgs: [bookId],
        limit: 1,
      );
      if (rows.isEmpty) return const [];
      final decoded = jsonDecode(rows.single['toc_json'] as String) as List;
      return List.unmodifiable(
        decoded.map(
          (value) => TableOfContentsEntry.fromJson(
            (value as Map).cast<String, Object?>(),
          ),
        ),
      );
    } catch (_) {
      throw const DatabaseFailure();
    }
  }
}
