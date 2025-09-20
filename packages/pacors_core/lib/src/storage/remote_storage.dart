import 'package:rdf_core/rdf_core.dart';

abstract interface class RemoteStorage {
  Future<void> upload(String path, RdfGraph turtle);
  Future<RdfGraph> download(String path);
  Future<void> delete(String path);
}
