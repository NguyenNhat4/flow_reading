import 'package:flow_reading/domain/models/bookmark.dart';
import 'package:flow_reading/domain/models/highlight.dart';
import 'package:flow_reading/domain/models/reader_note.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/repositories/bookmark_repository.dart';
import 'package:flow_reading/domain/repositories/highlight_repository.dart';
import 'package:flow_reading/domain/repositories/note_repository.dart';
import 'package:flow_reading/domain/repositories/utc_clock.dart';

final class ToggleBookmarkUseCase {
  const ToggleBookmarkUseCase(this._repository, this._clock);

  final BookmarkRepository _repository;
  final UtcClock _clock;

  Future<Bookmark?> call({
    required ReadingLocator locator,
    required bool isBookmarked,
  }) async {
    if (isBookmarked) {
      await _repository.delete(locator.anchor.id);
      return null;
    }
    final bookmark = Bookmark(locator: locator, createdAt: _clock.now());
    await _repository.save(bookmark);
    return bookmark;
  }
}

final class DeleteBookmarkUseCase {
  const DeleteBookmarkUseCase(this._repository);

  final BookmarkRepository _repository;

  Future<void> call(String id) => _repository.delete(id);
}

final class ToggleHighlightUseCase {
  const ToggleHighlightUseCase(this._repository, this._clock);

  final HighlightRepository _repository;
  final UtcClock _clock;

  Future<Highlight?> call({
    required TextAnchor range,
    required bool isHighlighted,
  }) async {
    if (isHighlighted) {
      await _repository.delete(range.id);
      return null;
    }
    final now = _clock.now();
    final highlight = Highlight(range: range, createdAt: now, updatedAt: now);
    await _repository.save(highlight);
    return highlight;
  }
}

final class UpsertNoteUseCase {
  const UpsertNoteUseCase(this._repository, this._clock);

  final NoteRepository _repository;
  final UtcClock _clock;

  Future<ReaderNote> call({
    required TextAnchor range,
    required String body,
    ReaderNote? existing,
  }) async {
    final now = _clock.now();
    final note = ReaderNote(
      range: range,
      body: body,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _repository.save(note);
    return note;
  }
}

final class DeleteNoteUseCase {
  const DeleteNoteUseCase(this._repository);

  final NoteRepository _repository;

  Future<void> call(String id) => _repository.delete(id);
}
