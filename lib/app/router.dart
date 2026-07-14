import 'package:flow_reading/features/library/presentation/library_screen.dart';
import 'package:flow_reading/features/reader/presentation/reader_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/reader/:bookId',
        name: 'reader',
        builder: (context, state) =>
            ReaderScreen(bookId: state.pathParameters['bookId']!),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
