/// Abstract authentication interface for Solid Pod access.
/// 
/// This interface defines the contract that authentication implementations
/// must provide to enable Pod synchronization. Concrete implementations
/// will integrate with specific auth libraries like solid-auth.
abstract interface class SolidAuthProvider {
  /// Get the currently authenticated WebID.
  /// Returns null if not authenticated.
  Future<String?> getWebId();

  /// Get a valid access token for the given resource.
  /// Handles token refresh automatically if needed.
  Future<String?> getAccessToken(String resourceUrl);

  /// Check if currently authenticated.
  Future<bool> isAuthenticated();

  /// Sign out the current user.
  Future<void> signOut();

  /// Stream of authentication state changes.
  Stream<bool> get authStateChanges;
}