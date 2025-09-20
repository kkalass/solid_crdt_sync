import 'package:pacors_core/pacors_core.dart';

import 'auth/solid_auth_provider.dart';

class SolidBackend implements Backend {
  final SolidAuthProvider _authProvider;

  SolidBackend({
    required SolidAuthProvider auth,
  }) : _authProvider = auth;

  @override
  Auth get auth => _authProvider;

  @override
  RemoteStorage get remoteStorage => throw UnimplementedError();

  @override
  ResourceLocator get resourceLocator => throw UnimplementedError();
}
