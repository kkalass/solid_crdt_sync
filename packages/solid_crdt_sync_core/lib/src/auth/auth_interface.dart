/// Abstract authentication interface for Solid Pod access.
///
/// This interface defines the contract that authentication implementations
/// must provide to enable Pod synchronization. Concrete implementations
/// will integrate with specific auth libraries like solid-auth.
abstract interface class Auth {
  Future<bool> isAuthenticated();
}
