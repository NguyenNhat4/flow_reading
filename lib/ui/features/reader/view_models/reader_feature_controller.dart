import 'package:flow_reading/ui/features/reader/view_models/reader_annotations_view_model.dart';
import 'package:flow_reading/ui/features/reader/view_models/reader_pagination_view_model.dart';
import 'package:flow_reading/ui/features/reader/view_models/reader_search_view_model.dart';
import 'package:flow_reading/ui/features/reader/view_models/reader_view_model.dart';

/// Owns every state owner that participates in one reader feature lifetime.
final class ReaderFeatureController {
  ReaderFeatureController({required this.session, required this.pagination});

  final ReaderViewModel session;
  final ReaderPaginationViewModel pagination;

  ReaderAnnotationsViewModel get annotations => session.annotations;
  ReaderSearchViewModel get search => session.search;

  void dispose() {
    pagination.dispose();
    session.dispose();
  }
}
