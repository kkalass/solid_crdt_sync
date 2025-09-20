import 'package:pacors_core/src/auth/auth_interface.dart';
import 'package:pacors_core/src/mapping/resource_locator.dart';
import 'package:pacors_core/src/storage/remote_storage.dart';

abstract interface class Backend {
  Auth get auth;
  RemoteStorage get remoteStorage;
  ResourceLocator get resourceLocator;
}
