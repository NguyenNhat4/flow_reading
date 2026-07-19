# UI Layer Structure (`lib/ui`)

Contains Flutter UI components, widgets, and MVVM ViewModels.

## Core (`lib/ui/core/`)
- `reader_theme.dart`: Global styling, colors, and typographies for the reader.
- `ui_command_result.dart`: Standardized return types for UI actions.
- `ui_failure_mapper.dart`: Maps domain `AppFailure`s to user-friendly messages.

## Features (`lib/ui/features/`)

### Library (`lib/ui/features/library/`)
- **view_models**:
  - `library_catalog.dart`: Manages the collection of books.
  - `library_view_model.dart`: State for the main library screen.
- **views**:
  - `library_screen.dart`: The main entry view showing user's books.

### Reader (`lib/ui/features/reader/`)
- **services**:
  - `flutter_content_measurer.dart`: Layout measuring for pagination.
- **view_models**:
  - `explanation_state.dart`: Shared state for AI explanations.
  - `grammar_explanation_view_model.dart`, `passage_explanation_view_model.dart`, `word_explanation_view_model.dart`: UI state for AI features.
  - `reader_annotations_view_model.dart`: State for highlights/notes/bookmarks.
  - `reader_feature_controller.dart`: Coordinates reader features.
  - `reader_pagination_view_model.dart`: Manages page calculation and active page.
  - `reader_search_view_model.dart`: Handles in-book search state.
  - `reader_selection.dart`: Tracks user text selection.
  - `reader_view_model.dart`: Primary ViewModel for the reading experience.
- **views**:
  - `grammar_explanation_sheet.dart`, `passage_explanation_sheet.dart`, `word_explanation_sheet.dart`: Bottom sheets for AI results.
  - `reader_action_menu.dart`: Contextual menu for text selection.
  - `reader_layout_controls.dart`: UI for changing font size, theme, etc.
  - `reader_screen.dart`: Main reading scaffold.
  - `saved_items_panel.dart`: Sidebar/drawer showing bookmarks and highlights.
  - `search_panel.dart`: UI for executing in-book searches.
  - `swipeable_reader.dart`: Gesture-driven pagination view.
  - `table_of_contents.dart`: Drawer displaying book chapters.

### Settings (`lib/ui/features/settings/`)
- **view_models**:
  - `ai_settings_view_model.dart`: Manages AI keys and preferences.
- **views**:
  - `ai_settings_sheet.dart`: Modal for entering OpenAI keys.
