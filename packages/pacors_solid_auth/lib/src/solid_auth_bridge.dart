/// Implementation of SolidAuthProvider using solid-auth library.
library;

import 'dart:async';

import 'package:pacors_solid/pacors_solid.dart';
import 'package:solid_auth/solid_auth.dart';

/// Concrete implementation of SolidAuthProvider using solid-auth library.
///
/// This class bridges the abstract authentication interface from the core
/// library with the solid-auth implementation.
class SolidAuthBridge implements SolidAuthProvider {
  final SolidAuth _solidAuth;

  SolidAuthBridge(this._solidAuth);

  @override
  Future<bool> isAuthenticated() async {
    return _solidAuth.isAuthenticated;
  }

  @override
  Future<({String accessToken, String dPoP})> getDpopToken(
      String url, String method) async {
    final dpop = await _solidAuth.genDpopToken(url, method);
    return (accessToken: dpop.accessToken, dPoP: dpop.dpopToken);
  }

  /// Clean up resources.
  void dispose() {
    // Solid Auth instance was provided externally; do not dispose it here.
  }
}
