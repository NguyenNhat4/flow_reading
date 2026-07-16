import 'package:flow_reading/ui/features/settings/view_models/ai_settings_view_model.dart';
import 'package:flutter/material.dart';

/// Configures the user-owned key used by contextual reader features.
class AiSettingsSheet extends StatefulWidget {
  const AiSettingsSheet({required this.viewModel, super.key});

  final AiSettingsViewModel viewModel;

  @override
  State<AiSettingsSheet> createState() => _AiSettingsSheetState();
}

class _AiSettingsSheetState extends State<AiSettingsSheet> {
  final _keyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.viewModel.load();
  }

  @override
  void dispose() {
    _keyController.dispose();
    widget.viewModel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await widget.viewModel.validateAndSave(_keyController.text);
    if (!mounted || !saved) return;
    _keyController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OpenAI key validated and saved.')),
    );
  }

  Future<void> _remove() async {
    final removed = await widget.viewModel.removeKey();
    if (!mounted || !removed) return;
    _keyController.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('OpenAI key removed.')));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final viewModel = widget.viewModel;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'AI settings',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close AI settings',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Provider', style: Theme.of(context).textTheme.labelLarge),
                Text(viewModel.providerName),
                const SizedBox(height: 12),
                Text('Model', style: Theme.of(context).textTheme.labelLarge),
                Text(viewModel.model),
                const SizedBox(height: 16),
                if (viewModel.isLoading)
                  const LinearProgressIndicator()
                else
                  Text(
                    viewModel.isConfigured
                        ? 'A validated key is stored securely on this device.'
                        : 'No AI key is configured.',
                    key: const ValueKey('ai-key-status'),
                  ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('ai-api-key-field'),
                  controller: _keyController,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'OpenAI API key',
                    hintText: 'Enter a key to validate and save',
                  ),
                ),
                if (viewModel.errorMessage case final error?)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error,
                      key: const ValueKey('ai-settings-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const ValueKey('validate-ai-key'),
                  onPressed: viewModel.isValidating ? null : _save,
                  child: Text(
                    viewModel.isValidating ? 'Validating…' : 'Validate & save',
                  ),
                ),
                if (viewModel.isConfigured) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    key: const ValueKey('remove-ai-key'),
                    onPressed: viewModel.isValidating ? null : _remove,
                    child: const Text('Remove key'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
