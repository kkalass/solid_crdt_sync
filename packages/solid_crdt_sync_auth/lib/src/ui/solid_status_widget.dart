import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:solid_auth/solid_auth.dart';

import '../../l10n/solid_auth_localizations.dart';
import '../providers/solid_provider_service.dart';
import 'login_page.dart';

final _log = Logger('SolidStatusWidget');

/// A combined connection and sync status widget for the app bar.
///
/// This widget shows the current Solid authentication status and sync state
/// in a compact format suitable for app bars. It handles the complete user
/// journey from "not connected" → "connecting" → "syncing" → "up to date".
///
/// The widget provides tap functionality to:
/// - Open login screen when not connected
/// - Show status information when connected
/// - Trigger manual sync when connected
class SolidStatusWidget extends StatefulWidget {
  /// The SolidAuth instance to monitor for authentication state.
  final SolidAuth solidAuth;

  /// The provider service for authentication UI.
  final SolidProviderService providerService;

  /// Optional callback for manual sync trigger.
  final VoidCallback? onManualSync;

  /// Whether the system is currently syncing.
  final bool isSyncing;

  /// Whether there's a sync error.
  final bool hasError;

  /// Custom error message to display.
  final String? errorMessage;

  const SolidStatusWidget({
    super.key,
    required this.solidAuth,
    required this.providerService,
    this.onManualSync,
    this.isSyncing = false,
    this.hasError = false,
    this.errorMessage,
  });

  @override
  State<SolidStatusWidget> createState() => _SolidStatusWidgetState();
}

class _SolidStatusWidgetState extends State<SolidStatusWidget> {
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();

    // Listen to authentication changes
    widget.solidAuth.isAuthenticatedNotifier.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    widget.solidAuth.isAuthenticatedNotifier.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    try {
      _log.info('Authentication state changed');
      _checkAuthStatus();
    } catch (e, stackTrace) {
      _log.severe('Error in authentication state change handler', e, stackTrace);
    }
  }

  Future<void> _checkAuthStatus() async {
    try {
      final isAuth = await widget.solidAuth.isAuthenticated;
      _log.fine('Authentication status checked: $isAuth');
      if (mounted) {
        setState(() {
          _isAuthenticated = isAuth;
        });
      }
    } catch (e, stackTrace) {
      _log.severe('Error checking authentication status', e, stackTrace);
      // Avoid setState if there's an error to prevent potential recursion
    }
  }

  Future<void> _showLoginScreen() async {
    final userInfo = await Navigator.of(context).push<UserAndWebId>(
      MaterialPageRoute(
        builder: (context) => SolidLoginScreen(
          solidAuth: widget.solidAuth,
          providerService: widget.providerService,
          onLoginSuccess: (userInfo) {
            Navigator.of(context).pop(userInfo);
          },
          onLoginError: (error) {
            // Error is already shown in the login screen
          },
        ),
      ),
    );

    if (userInfo != null) {
      // Refresh auth status after successful login
      _checkAuthStatus();
    }
  }

  Future<void> _disconnect() async {
    try {
      await widget.solidAuth.logout();
      _checkAuthStatus();
    } catch (e, stackTrace) {
      _log.severe('Error during logout', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              SolidAuthLocalizations.of(context)!.errorConnectingSolid(e.toString()),
            ),
          ),
        );
      }
    }
  }

  void _showStatusMenu() {
    final l10n = SolidAuthLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                _isAuthenticated ? Icons.cloud_done : Icons.cloud_off,
                color: _isAuthenticated ? Colors.green : Colors.grey,
              ),
              title: Text(_isAuthenticated ? l10n.connected : l10n.notConnected),
              subtitle: widget.solidAuth.currentWebId != null
                  ? Text(widget.solidAuth.currentWebId!)
                  : null,
            ),
            if (_isAuthenticated) ...[
              const Divider(),
              if (widget.onManualSync != null)
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: Text(l10n.syncNow),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onManualSync?.call();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(l10n.signOut),
                onTap: () {
                  Navigator.pop(context);
                  _disconnect();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = SolidAuthLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    // Determine the current status
    Widget icon;
    String tooltip;
    VoidCallback? onPressed;

    if (!_isAuthenticated) {
      // Not connected
      icon = Icon(Icons.cloud_off, color: colorScheme.onSurfaceVariant);
      tooltip = l10n.notConnected;
      onPressed = _showLoginScreen;
    } else if (widget.hasError) {
      // Connected but has error
      icon = Icon(Icons.cloud_off, color: colorScheme.error);
      tooltip = widget.errorMessage ?? l10n.syncError;
      onPressed = widget.onManualSync ?? _showStatusMenu;
    } else if (widget.isSyncing) {
      // Connected and syncing
      icon = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
        ),
      );
      tooltip = l10n.syncing;
      onPressed = null; // Disabled while syncing
    } else {
      // Connected and up to date
      icon = Icon(Icons.cloud_done, color: Colors.green);
      tooltip = l10n.upToDate;
      onPressed = _showStatusMenu;
    }

    return IconButton(
      onPressed: onPressed,
      icon: icon,
      tooltip: tooltip,
    );
  }
}