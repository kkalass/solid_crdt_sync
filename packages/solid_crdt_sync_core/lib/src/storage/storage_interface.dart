/// Abstract storage interface for local data persistence.
/// 
/// This interface defines the contract for local storage backends
/// that will be implemented by specific packages (e.g., Isar, Drift).
abstract interface class LocalStorage {
  /// Initialize the storage backend.
  Future<void> initialize();

  /// Store RDF data for a given resource IRI.
  Future<void> storeResource(String resourceIri, String rdfContent);

  /// Retrieve RDF data for a given resource IRI.
  /// Returns null if resource doesn't exist locally.
  Future<String?> getResource(String resourceIri);

  /// Delete a resource from local storage.
  Future<void> deleteResource(String resourceIri);

  /// Get all locally stored resource IRIs.
  Future<List<String>> getStoredResources();

  /// Check if a resource exists locally.
  Future<bool> hasResource(String resourceIri);

  /// Close the storage backend and free resources.
  Future<void> close();
}