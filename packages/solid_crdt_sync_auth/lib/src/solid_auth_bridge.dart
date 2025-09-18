/// Implementation of SolidAuthProvider using solid-auth library.
library;

import 'dart:async';

import 'package:solid_auth/solid_auth.dart';
import 'package:solid_crdt_sync_core/solid_crdt_sync_core.dart';

/// Concrete implementation of SolidAuthProvider using solid-auth library.
///
/// This class bridges the abstract authentication interface from the core
/// library with the solid-auth implementation.
class SolidAuthBridge implements Auth {
  final SolidAuth _solidAuth;

  SolidAuthBridge(this._solidAuth);

  @override
  Future<bool> isAuthenticated() async {
    return _solidAuth.isAuthenticated;
  }

  /// Clean up resources.
  void dispose() {
    // Solid Auth instance was provided externally; do not dispose it here.
  }
}
