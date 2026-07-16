import 'package:flow_reading/domain/models/reader_settings.dart';
import 'package:flutter/material.dart';

/// Edits a draft of the pagination-affecting reader preferences.
class ReaderLayoutControls extends StatefulWidget {
  /// Creates controls initialized from the persisted reader [settings].
  const ReaderLayoutControls({required this.settings, super.key});

  /// The settings copied into the editable draft.
  final ReaderSettings settings;

  @override
  State<ReaderLayoutControls> createState() => _ReaderLayoutControlsState();
}

class _ReaderLayoutControlsState extends State<ReaderLayoutControls> {
  late ReaderTheme _theme = widget.settings.theme;
  late double _fontSize = widget.settings.fontSize;
  late double _lineHeight = widget.settings.lineHeight;
  late double _horizontalMargin =
      (widget.settings.margins.left + widget.settings.margins.right) / 2;
  late double _verticalMargin =
      (widget.settings.margins.top + widget.settings.margins.bottom) / 2;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Reader layout',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Text('Theme', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<ReaderTheme>(
              key: const ValueKey('reader-theme-selector'),
              segments: const [
                ButtonSegment(value: ReaderTheme.light, label: Text('Light')),
                ButtonSegment(value: ReaderTheme.dark, label: Text('Dark')),
                ButtonSegment(value: ReaderTheme.paper, label: Text('Paper')),
              ],
              selected: {_theme},
              onSelectionChanged: (selection) {
                setState(() => _theme = selection.single);
              },
            ),
            const SizedBox(height: 24),
            _SliderSetting(
              label: 'Font size',
              valueLabel: _fontSize.toStringAsFixed(0),
              child: Slider(
                key: const ValueKey('reader-font-size-slider'),
                value: _fontSize,
                min: 12,
                max: 36,
                divisions: 24,
                onChanged: (value) => setState(() => _fontSize = value),
              ),
            ),
            _SliderSetting(
              label: 'Line spacing',
              valueLabel: _lineHeight.toStringAsFixed(1),
              child: Slider(
                key: const ValueKey('reader-line-height-slider'),
                value: _lineHeight,
                min: 1,
                max: 2.4,
                divisions: 14,
                onChanged: (value) => setState(() => _lineHeight = value),
              ),
            ),
            _SliderSetting(
              label: 'Horizontal margins',
              valueLabel: _horizontalMargin.toStringAsFixed(0),
              child: Slider(
                key: const ValueKey('reader-horizontal-margin-slider'),
                value: _horizontalMargin,
                min: 0,
                max: 64,
                divisions: 32,
                onChanged: (value) => setState(() => _horizontalMargin = value),
              ),
            ),
            _SliderSetting(
              label: 'Vertical margins',
              valueLabel: _verticalMargin.toStringAsFixed(0),
              child: Slider(
                key: const ValueKey('reader-vertical-margin-slider'),
                value: _verticalMargin,
                min: 0,
                max: 64,
                divisions: 32,
                onChanged: (value) => setState(() => _verticalMargin = value),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  key: const ValueKey('reader-layout-apply'),
                  onPressed: () => Navigator.pop(context, _result()),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ReaderSettings _result() => ReaderSettings(
    fontFamily: widget.settings.fontFamily,
    fontSize: _fontSize,
    lineHeight: _lineHeight,
    margins: ReaderMargins(
      left: _horizontalMargin,
      top: _verticalMargin,
      right: _horizontalMargin,
      bottom: _verticalMargin,
    ),
    theme: _theme,
    orientation: widget.settings.orientation,
    languageMode: widget.settings.languageMode,
  );
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.label,
    required this.valueLabel,
    required this.child,
  });

  final String label;
  final String valueLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(valueLabel),
          ],
        ),
        child,
      ],
    );
  }
}
