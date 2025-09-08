/// Pod provider picker widget for Solid authentication.
library;

import 'package:flutter/material.dart';

/// Common Solid Pod providers for easy selection.
class SolidProvider {
  final String name;
  final String baseUrl;
  final String description;

  const SolidProvider({
    required this.name,
    required this.baseUrl,
    required this.description,
  });
}

/// Predefined list of common Solid Pod providers.
class SolidProviders {
  static const List<SolidProvider> common = [
    SolidProvider(
      name: 'solidcommunity.net',
      baseUrl: 'https://solidcommunity.net/',
      description: 'Community-run Solid Pod provider',
    ),
    SolidProvider(
      name: 'inrupt.net',
      baseUrl: 'https://inrupt.net/',
      description: 'Inrupt Pod Spaces',
    ),
    SolidProvider(
      name: 'solidweb.org',
      baseUrl: 'https://solidweb.org/',
      description: 'SolidWeb Pod provider',
    ),
  ];
}

/// Widget for picking a Solid Pod provider.
///
/// Allows users to choose from common providers or enter a custom one.
class SolidProviderPicker extends StatefulWidget {
  final Function(String) onProviderSelected;
  final String? initialProvider;

  const SolidProviderPicker({
    super.key,
    required this.onProviderSelected,
    this.initialProvider,
  });

  @override
  State<SolidProviderPicker> createState() => _SolidProviderPickerState();
}

class _SolidProviderPickerState extends State<SolidProviderPicker> {
  final TextEditingController _customController = TextEditingController();
  String? _selectedProvider;

  @override
  void initState() {
    super.initState();
    _selectedProvider = widget.initialProvider;
    if (widget.initialProvider != null) {
      _customController.text = widget.initialProvider!;
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose your Pod provider:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        ...SolidProviders.common.map((provider) => RadioListTile<String>(
              title: Text(provider.name),
              subtitle: Text(provider.description),
              value: provider.baseUrl,
              groupValue: _selectedProvider,
              onChanged: (value) {
                setState(() {
                  _selectedProvider = value;
                });
                if (value != null) {
                  widget.onProviderSelected(value);
                }
              },
            )),
        RadioListTile<String>(
          title: const Text('Custom provider'),
          subtitle: TextField(
            controller: _customController,
            decoration: const InputDecoration(
              hintText: 'https://your-pod-provider.com/',
              border: UnderlineInputBorder(),
            ),
            onChanged: (value) {
              if (value.isNotEmpty) {
                setState(() {
                  _selectedProvider = value;
                });
                widget.onProviderSelected(value);
              }
            },
          ),
          value:
              _customController.text.isNotEmpty ? _customController.text : '',
          groupValue: _selectedProvider,
          onChanged: (value) {
            // Focus the text field when custom is selected
            if (value != null) {
              setState(() {
                _selectedProvider = value;
              });
              widget.onProviderSelected(value);
            }
          },
        ),
      ],
    );
  }
}
