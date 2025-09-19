/// Service interface for managing Solid Pod providers and registration.
///
/// This interface allows applications to provide their own list of Solid
/// providers and registration URLs, making the authentication UI flexible
/// and configurable.
abstract class SolidProviderService {
  /// Returns a list of available Solid Pod providers.
  ///
  /// These providers will be shown as quick-access buttons in the login UI.
  List<SolidProvider> getProviders();

  /// Returns the URL where users can register for a new Pod.
  ///
  /// This URL is used by the "Get a Pod" button in the login UI.
  String getNewPodUrl();
}

/// Represents a Solid Pod provider.
class SolidProvider {
  /// The display name of the provider.
  final String name;

  /// The base URL or issuer URI of the provider.
  final String url;

  /// Optional description of the provider.
  final String? description;

  const SolidProvider({
    required this.name,
    required this.url,
    this.description,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SolidProvider &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          url == other.url;

  @override
  int get hashCode => name.hashCode ^ url.hashCode;

  @override
  String toString() => 'SolidProvider(name: $name, url: $url)';
}

/// Default implementation of [SolidProviderService] with common providers.
///
/// Applications can use this as-is or extend it to add custom providers.
class DefaultSolidProviderService implements SolidProviderService {
  static const List<SolidProvider> _defaultProviders = [
    SolidProvider(
      name: 'Solidcommunity.net',
      url: 'https://solidcommunity.net',
      description: 'Community-run Solid Pod provider',
    ),
    SolidProvider(
      name: 'Inrupt Pod Spaces',
      url: 'https://login.inrupt.com',
      description: 'Commercial Solid Pod service by Inrupt',
    ),
    SolidProvider(
      name: 'SolidWeb.org',
      url: 'https://solidweb.org',
      description: 'Open source Solid Pod provider',
    ),
  ];

  static const String _defaultNewPodUrl = 'https://solidcommunity.net/register';

  @override
  List<SolidProvider> getProviders() => _defaultProviders;

  @override
  String getNewPodUrl() => _defaultNewPodUrl;
}