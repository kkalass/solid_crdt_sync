/// Solid authentication implementation for solid_crdt_sync.
///
/// This library provides the bridge between solid_crdt_sync_core's
/// authentication interfaces and the solid-auth library, plus ready-to-use
/// UI components for Solid authentication.
library solid_crdt_sync_auth;

export 'src/solid_auth_bridge.dart';
export 'src/ui/login_page.dart';
export 'src/ui/solid_status_widget.dart';
export 'src/providers/solid_provider_service.dart';
export 'l10n/solid_auth_localizations.dart';
