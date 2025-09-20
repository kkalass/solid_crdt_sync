# Solid Backend for PaCoRS

**Version:** 0.10.0-draft
**Last Updated:** September 2025
**Status:** Draft Specification
**Authors:** Klas Kalaß
**Target Audience:** Library implementers, Solid application developers

## Document Status

This document specifies how to implement PaCoRS (Passive Storage Collaborative RDF Sync System) using Solid Pods as the storage backend. It provides concrete implementation guidance for Solid-specific discovery, authentication, and storage operations.

**Parent Specification:** This document extends and implements the backend-agnostic [PaCoRS specification](PACORS-SPECIFICATION.md). Readers should be familiar with the core PaCoRS concepts before reading this specification.

## Document Changelog

### Version 0.10.0-draft (September 2025)
- **DOCUMENT CREATION:** Split from monolithic ARCHITECTURE.md to create Solid-specific backend specification
- **Solid Implementation:** Extracted Solid Pod-specific implementation details from core framework
- **Discovery Integration:** Solid Type Index isolation strategies and resource discovery protocols
- **Authentication:** Solid-OIDC integration patterns and Pod provider discovery
- **Storage Operations:** HTTP-based CRUD with ETag optimization and conflict resolution
- **Access Control:** ACL/ACP integration for collaborative permissions
- **Pod Setup:** Comprehensive Pod configuration and initialization workflows
- **Maintained Compatibility:** Full compatibility with PaCoRS core specification

---

## 1. Overview

This specification defines how to implement PaCoRS using Solid Pods as the storage backend. Solid Pods provide an ideal foundation for PaCoRS due to their:

- **Decentralized Architecture:** Each user controls their own data storage
- **Standards-Based:** Built on HTTP, RDF, and Web standards
- **Access Control:** Fine-grained permissions through ACL/ACP
- **Identity Integration:** WebID-based identity with OIDC authentication

**Key Implementation Areas:**
1. **Discovery Integration:** Using Solid Type Index for resource discovery
2. **Authentication:** Solid-OIDC integration for user authentication
3. **Storage Operations:** HTTP-based CRUD operations with ETag optimization
4. **Access Control:** ACL/ACP integration for collaborative permissions

## 2. Solid Discovery Integration

### 2.1. Discovery Isolation Strategy

CRDT-managed resources contain synchronization metadata and follow structural conventions that traditional RDF applications don't understand, creating a risk of data corruption. The Solid implementation solves this through Type Index isolation.

**The Challenge:** Traditional Solid discovery would expose CRDT-managed data to all applications, risking corruption by applications that don't understand CRDT metadata or Hybrid Logical Clocks.

**The Solution:** CRDT-managed resources are registered under `sync:ManagedDocument` in the Type Index rather than their semantic types (e.g., `schema:Recipe`). The semantic type is preserved via `sync:managedResourceType` property.

**Discovery Behavior:**
- **CRDT-enabled apps:** Query for `sync:ManagedDocument` where `sync:managedResourceType schema:Recipe` → Find managed resources
- **Traditional apps:** Query for `schema:Recipe` → Find nothing (managed data invisible)
- **Legacy data:** Remains discoverable through traditional registrations until explicitly migrated

This creates clean separation: compatible applications collaborate safely on managed data, while traditional apps work with unmanaged data, preventing cross-contamination.

### 2.2. Managed Resource Discovery Protocol

**1. Standard Discovery:** Follow WebID → Profile Document → Public Type Index ([Type Index](https://github.com/solid/type-indexes)):

**Note:** This framework currently uses only the **Public Type Index** for discoverability. This design choice enables inter-application collaboration and resource sharing but means all CRDT-managed resources are discoverable by other applications. See [FUTURE-TOPICS.md](FUTURE-TOPICS.md) for planned Private Type Index support.

```turtle
# In Profile Document at https://alice.podprovider.org/profile/card#me
@prefix solid: <http://www.w3.org/ns/solid/terms#> .

<#me> solid:publicTypeIndex </settings/publicTypeIndex.ttl> .
```

**2. Framework Resource Resolution:** From the Type Index, resolve `sync:ManagedDocument` registrations to data containers:

```turtle
# In Public Type Index at https://alice.podprovider.org/settings/publicTypeIndex.ttl
@prefix sync: <https://w3id.org/rdf-crdt-sync/vocab/sync#> .
@prefix solid: <http://www.w3.org/ns/solid/terms#> .
@prefix schema: <https://schema.org/> .
@prefix meal: <https://example.org/vocab/meal#> .

<> a solid:TypeIndex;
   solid:hasRegistration [
      a solid:TypeRegistration;
      solid:forClass sync:ManagedDocument;
      sync:managedResourceType schema:Recipe;
      solid:instanceContainer <../data/recipes/>
   ], [
      a solid:TypeRegistration;
      solid:forClass sync:ManagedDocument;
      sync:managedResourceType meal:ShoppingListEntry;
      solid:instanceContainer <../data/shopping-entries/>
   ] .
```

**3. Specification Type Resolution:** Applications also register specification-defined types (indices and client installations) in the Type Index using the same mechanism:

```turtle
# Also in Public Type Index at https://alice.podprovider.org/settings/publicTypeIndex.ttl
@prefix idx: <https://w3id.org/rdf-crdt-sync/vocab/idx#> .
@prefix crdt: <https://w3id.org/rdf-crdt-sync/vocab/crdt-mechanics#> .

<> solid:hasRegistration [
      a solid:TypeRegistration;
      solid:forClass idx:FullIndex;
      idx:indexesClass schema:Recipe
      solid:instanceContainer <../indices/recipes/>;
   ], [
      a solid:TypeRegistration;
      solid:forClass idx:GroupIndexTemplate;
      idx:indexesClass meal:ShoppingListEntry
      solid:instanceContainer <../indices/shopping-entries/>;
   ], [
      a solid:TypeRegistration;
      solid:forClass sync:ManagedDocument;
      sync:managedResourceType crdt:ClientInstallation;
      solid:instanceContainer <../installations/>
   ] .
```

**4. Managed Resource Discovery:** CRDT-enabled applications query the Type Index for `sync:ManagedDocument` registrations with specific `sync:managedResourceType` values (e.g., `schema:Recipe`) and their corresponding index types (e.g., `idx:FullIndex`), enabling automatic discovery of the complete synchronization setup.

**Advantages:** Using TypeRegistration with `sync:ManagedDocument` and `sync:managedResourceType` enables managed resource discovery while protecting managed resources from incompatible applications. CRDT-enabled applications can find both data and indices through standard Solid mechanisms ([WebID Profile](https://www.w3.org/TR/webid/), [Type Index](https://github.com/solid/type-indexes)), while traditional applications remain unaware of CRDT-managed data, preventing accidental corruption.

### 2.3. Implementation Interface

```dart
class SolidResourceDiscovery implements ResourceDiscovery {
  final SolidClient solidClient;
  final IriTerm webId;

  SolidResourceDiscovery(this.solidClient, this.webId);

  @override
  Future<List<IriTerm>> discoverContainers(IriTerm managedResourceType) async {
    // 1. Fetch WebID profile to get Type Index location
    Document profile = await solidClient.getDocument(webId);
    IriTerm? typeIndexIri = extractTypeIndexIri(profile);

    if (typeIndexIri == null) {
      throw SolidDiscoveryException('No public type index found in WebID profile');
    }

    // 2. Query Type Index for managed resource registrations
    Document typeIndex = await solidClient.getDocument(typeIndexIri);
    List<TypeRegistration> registrations = extractManagedResourceRegistrations(
      typeIndex,
      managedResourceType
    );

    // 3. Return container IRIs from registrations
    return registrations
        .map((reg) => reg.instanceContainer)
        .where((container) => container != null)
        .cast<IriTerm>()
        .toList();
  }

  @override
  Future<void> registerContainer(IriTerm managedResourceType, IriTerm container) async {
    IriTerm typeIndexIri = await getOrCreateTypeIndex();

    // Create new type registration for managed resource
    TypeRegistration registration = TypeRegistration(
      forClass: IriTerm('https://w3id.org/rdf-crdt-sync/vocab/sync#ManagedDocument'),
      managedResourceType: managedResourceType,
      instanceContainer: container,
    );

    await addTypeRegistration(typeIndexIri, registration);
  }

  // Helper methods for Type Index manipulation
  Future<IriTerm> getOrCreateTypeIndex() async { /* ... */ }
  Future<void> addTypeRegistration(IriTerm typeIndexIri, TypeRegistration registration) async { /* ... */ }
}
```

## 3. Solid Authentication Integration

### 3.1. Solid-OIDC Authentication

The Solid backend implementation uses Solid-OIDC for user authentication:

```dart
class SolidAuthentication implements BackendAuth {
  final SolidOidcClient oidcClient;
  final String clientId;
  final String redirectUri;

  SolidAuthentication({
    required this.clientId,
    required this.redirectUri,
  }) : oidcClient = SolidOidcClient();

  @override
  Future<AuthResult> authenticate() async {
    try {
      // Initiate Solid-OIDC flow
      AuthSession session = await oidcClient.authenticate(
        clientId: clientId,
        redirectUri: redirectUri,
        scopes: ['openid', 'profile', 'offline_access'],
      );

      return AuthResult.success(
        webId: session.webId,
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
    } catch (e) {
      return AuthResult.failure(error: e.toString());
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    return oidcClient.hasValidSession();
  }

  @override
  Future<void> signOut() async {
    await oidcClient.logout();
  }
}
```

### 3.2. Pod Provider Discovery

For a complete authentication flow, applications need to discover the user's Pod provider:

```dart
class PodProviderDiscovery {
  static Future<String> discoverPodProvider(String webId) async {
    try {
      // Parse WebID to extract potential Pod provider
      Uri webIdUri = Uri.parse(webId);
      String potentialProvider = '${webIdUri.scheme}://${webIdUri.host}';

      // Verify this is actually a Solid Pod provider by checking for OIDC configuration
      Uri oidcConfigUri = Uri.parse('$potentialProvider/.well-known/openid-configuration');

      HttpResponse response = await httpClient.get(oidcConfigUri);
      if (response.statusCode == 200) {
        return potentialProvider;
      }

      throw PodProviderException('Could not verify Pod provider for WebID: $webId');
    } catch (e) {
      throw PodProviderException('Failed to discover Pod provider: $e');
    }
  }
}
```

## 4. Solid Storage Operations

### 4.1. HTTP-Based Storage Implementation

```dart
class SolidStorage implements BackendStorage {
  final HttpClient httpClient;
  final AuthenticationManager authManager;

  SolidStorage(this.httpClient, this.authManager);

  @override
  Future<Document?> getDocument(IriTerm documentIri) async {
    try {
      HttpResponse response = await httpClient.get(
        documentIri.value,
        headers: await getAuthHeaders(),
      );

      if (response.statusCode == 404) {
        return null;
      }

      if (response.statusCode != 200) {
        throw SolidStorageException('Failed to fetch document: ${response.statusCode}');
      }

      // Store ETag for later conditional operations
      String? etag = response.headers['etag'];
      if (etag != null) {
        await storeETag(documentIri, etag);
      }

      return parseRdfDocument(response.body, documentIri.value);
    } catch (e) {
      throw SolidStorageException('Error fetching document: $e');
    }
  }

  @override
  Future<void> putDocument(IriTerm documentIri, Document document) async {
    try {
      String? etag = await getStoredETag(documentIri);
      Map<String, String> headers = await getAuthHeaders();

      // Add conditional update header if we have an ETag
      if (etag != null) {
        headers['If-Match'] = etag;
      }

      headers['Content-Type'] = 'text/turtle';

      HttpResponse response = await httpClient.put(
        documentIri.value,
        body: serializeRdfDocument(document),
        headers: headers,
      );

      if (response.statusCode == 412) {
        // Precondition Failed - concurrent modification
        throw ConcurrentModificationException('Document was modified by another client');
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw SolidStorageException('Failed to store document: ${response.statusCode}');
      }

      // Update stored ETag
      String? newETag = response.headers['etag'];
      if (newETag != null) {
        await storeETag(documentIri, newETag);
      }
    } catch (e) {
      if (e is ConcurrentModificationException) rethrow;
      throw SolidStorageException('Error storing document: $e');
    }
  }

  @override
  Future<bool> deleteDocument(IriTerm documentIri) async {
    try {
      HttpResponse response = await httpClient.delete(
        documentIri.value,
        headers: await getAuthHeaders(),
      );

      if (response.statusCode == 404) {
        return false; // Already deleted
      }

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw SolidStorageException('Failed to delete document: ${response.statusCode}');
      }

      // Clear stored ETag
      await clearETag(documentIri);
      return true;
    } catch (e) {
      throw SolidStorageException('Error deleting document: $e');
    }
  }

  @override
  Future<List<IriTerm>> listDocuments(IriTerm containerIri) async {
    try {
      HttpResponse response = await httpClient.get(
        containerIri.value,
        headers: {
          ...await getAuthHeaders(),
          'Accept': 'text/turtle',
        },
      );

      if (response.statusCode != 200) {
        throw SolidStorageException('Failed to list container: ${response.statusCode}');
      }

      // Parse container RDF to extract contained resources
      Document containerDoc = parseRdfDocument(response.body, containerIri.value);
      return extractContainedResources(containerDoc);
    } catch (e) {
      throw SolidStorageException('Error listing container: $e');
    }
  }

  // Helper methods
  Future<Map<String, String>> getAuthHeaders() async {
    String? accessToken = await authManager.getAccessToken();
    if (accessToken == null) {
      throw SolidAuthException('No valid access token available');
    }
    return {'Authorization': 'Bearer $accessToken'};
  }
}
```

### 4.2. Conflict Resolution with ETags

Solid's HTTP interface provides excellent support for conflict detection through ETags:

```dart
class SolidConflictResolver {
  final SolidStorage storage;

  Future<void> handleConflictAndRetry(
    IriTerm documentIri,
    Document localDocument,
    Future<void> Function(Document) operation
  ) async {
    try {
      await operation(localDocument);
    } catch (ConcurrentModificationException e) {
      // Fetch current remote state
      Document? remoteDocument = await storage.getDocument(documentIri);
      if (remoteDocument == null) {
        throw SolidStorageException('Document deleted during conflict resolution');
      }

      // Perform CRDT merge
      Document mergedDocument = performCRDTMerge(localDocument, remoteDocument);

      // Retry operation with merged document
      await operation(mergedDocument);
    }
  }

  Document performCRDTMerge(Document local, Document remote) {
    // Apply RDF-CRDT merge algorithms based on property mappings
    // Implementation details depend on merge contracts and CRDT types
    // See RDF-CRDT-ARCHITECTURE.md Section 5.2 for details
    return CRDTMerger.merge(local, remote);
  }
}
```

## 5. Pod Setup and Configuration

### 5.1. Initial Pod Setup Workflow

When an application first encounters a Pod, it follows this setup sequence:

```dart
class SolidPodSetup {
  final SolidClient solidClient;
  final IriTerm webId;

  Future<SetupResult> initializePod(List<ManagedResourceType> requiredTypes) async {
    // 1. Check existing Type Index configuration
    TypeIndexStatus status = await checkTypeIndexStatus();

    if (status.missing.isNotEmpty) {
      // 2. Present setup dialog to user
      SetupChoice choice = await presentSetupDialog(status);

      if (choice == SetupChoice.automatic) {
        await performAutomaticSetup(status.missing);
      } else if (choice == SetupChoice.custom) {
        await performCustomSetup(status.missing);
      } else {
        // User declined - use hardcoded paths with warning
        return SetupResult.fallback(
          warning: 'Pod configuration incomplete. Using default paths with reduced interoperability.'
        );
      }
    }

    // 3. Verify all required registrations are now present
    await validateSetupComplete(requiredTypes);

    return SetupResult.success();
  }

  Future<TypeIndexStatus> checkTypeIndexStatus() async {
    try {
      Document profile = await solidClient.getDocument(webId);
      IriTerm? typeIndexIri = extractPublicTypeIndexIri(profile);

      if (typeIndexIri == null) {
        return TypeIndexStatus(missing: [MissingComponent.typeIndex]);
      }

      Document typeIndex = await solidClient.getDocument(typeIndexIri);
      List<MissingComponent> missing = [];

      // Check for required registrations
      if (!hasInstallationRegistration(typeIndex)) {
        missing.add(MissingComponent.installationRegistration);
      }

      if (!hasFrameworkGCRegistration(typeIndex)) {
        missing.add(MissingComponent.gcRegistration);
      }

      // Check application-specific registrations
      for (ManagedResourceType type in requiredTypes) {
        if (!hasManagedResourceRegistration(typeIndex, type)) {
          missing.add(MissingComponent.managedResource(type));
        }
      }

      return TypeIndexStatus(missing: missing);
    } catch (e) {
      throw PodSetupException('Failed to check Pod configuration: $e');
    }
  }
}
```

### 5.2. Setup Dialog and User Experience

```dart
enum SetupChoice { automatic, custom, cancel }

class SetupDialogResult {
  final SetupChoice choice;
  final Map<String, String>? customPaths;

  SetupDialogResult(this.choice, [this.customPaths]);
}

abstract class SetupDialogPresenter {
  Future<SetupDialogResult> presentSetupDialog(TypeIndexStatus status);
}

// Example implementation for Flutter
class FlutterSetupDialog implements SetupDialogPresenter {
  @override
  Future<SetupDialogResult> presentSetupDialog(TypeIndexStatus status) async {
    return showDialog<SetupDialogResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pod Configuration Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('This app needs to configure CRDT-managed data storage in your Pod.'),
            SizedBox(height: 16),
            Text('Missing configuration:'),
            ...status.missing.map((component) =>
              Padding(
                padding: EdgeInsets.only(left: 16),
                child: Text('• ${component.description}'),
              )
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, SetupDialogResult(SetupChoice.cancel)),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, SetupDialogResult(SetupChoice.custom)),
            child: Text('Custom Setup'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, SetupDialogResult(SetupChoice.automatic)),
            child: Text('Automatic Setup'),
          ),
        ],
      ),
    ) ?? SetupDialogResult(SetupChoice.cancel);
  }
}
```

### 5.3. Automatic Setup Implementation

```dart
Future<void> performAutomaticSetup(List<MissingComponent> missing) async {
  for (MissingComponent component in missing) {
    switch (component.type) {
      case ComponentType.typeIndex:
        await createTypeIndex();
        break;

      case ComponentType.installationRegistration:
        await addInstallationRegistration();
        break;

      case ComponentType.gcRegistration:
        await addGCRegistration();
        break;

      case ComponentType.managedResource:
        await addManagedResourceRegistration(component.resourceType!);
        break;
    }
  }
}

Future<void> createTypeIndex() async {
  IriTerm typeIndexIri = webId.resolve('../settings/publicTypeIndex.ttl');

  // Create empty Type Index document
  Document typeIndex = Document(
    baseIri: typeIndexIri,
    triples: [
      Triple(
        subject: typeIndexIri,
        predicate: IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
        object: IriTerm('http://www.w3.org/ns/solid/terms#TypeIndex'),
      ),
    ],
  );

  await solidClient.putDocument(typeIndexIri, typeIndex);

  // Update WebID profile to reference Type Index
  await addTypeIndexToProfile(typeIndexIri);
}

Future<void> addManagedResourceRegistration(ManagedResourceType resourceType) async {
  IriTerm containerIri = generateContainerIri(resourceType);

  // Ensure container exists
  await createContainerIfNeeded(containerIri);

  // Add Type Index registration
  TypeRegistration registration = TypeRegistration(
    forClass: IriTerm('https://w3id.org/rdf-crdt-sync/vocab/sync#ManagedDocument'),
    managedResourceType: resourceType.typeIri,
    instanceContainer: containerIri,
  );

  await addTypeRegistration(registration);

  // Create corresponding index registration
  await addIndexRegistration(resourceType, containerIri);
}
```

## 6. Access Control Integration

### 6.1. ACL/ACP Configuration

For collaborative applications, proper access control setup is essential:

```dart
class SolidAccessControl {
  final SolidClient solidClient;

  Future<void> setupCollaborativeACL(
    IriTerm resourceIri,
    List<IriTerm> collaboratorWebIds
  ) async {
    // Create ACL document for the resource
    IriTerm aclIri = resourceIri.resolve('.acl');

    Document aclDocument = Document(
      baseIri: aclIri,
      triples: [
        // Owner authorization (full control)
        ...createOwnerAuthorization(resourceIri, await getCurrentWebId()),

        // Collaborator authorizations (read/write)
        ...collaboratorWebIds.expand((webId) =>
          createCollaboratorAuthorization(resourceIri, webId)
        ),

        // Public read for discovery (optional)
        ...createPublicReadAuthorization(resourceIri),
      ],
    );

    await solidClient.putDocument(aclIri, aclDocument);
  }

  List<Triple> createOwnerAuthorization(IriTerm resourceIri, IriTerm ownerWebId) {
    IriTerm authIri = resourceIri.resolve('.acl#owner');
    return [
      Triple(authIri, rdfType, aclAuthorization),
      Triple(authIri, aclAgent, ownerWebId),
      Triple(authIri, aclAccessTo, resourceIri),
      Triple(authIri, aclMode, aclRead),
      Triple(authIri, aclMode, aclWrite),
      Triple(authIri, aclMode, aclControl),
    ];
  }

  List<Triple> createCollaboratorAuthorization(IriTerm resourceIri, IriTerm collaboratorWebId) {
    IriTerm authIri = resourceIri.resolve('.acl#collaborator-${collaboratorWebId.fragment}');
    return [
      Triple(authIri, rdfType, aclAuthorization),
      Triple(authIri, aclAgent, collaboratorWebId),
      Triple(authIri, aclAccessTo, resourceIri),
      Triple(authIri, aclMode, aclRead),
      Triple(authIri, aclMode, aclWrite),
    ];
  }
}
```

### 6.2. Collaborative Permission Patterns

**Container-Level Permissions:**
```turtle
# ACL for recipe container allowing collaborative access
@prefix acl: <http://www.w3.org/ns/auth/acl#> .

<#owner> a acl:Authorization;
    acl:agent <https://alice.example.org/profile/card#me>;
    acl:accessTo <./>;
    acl:default <./>;
    acl:mode acl:Read, acl:Write, acl:Control .

<#collaborators> a acl:Authorization;
    acl:agent <https://bob.example.org/profile/card#me>,
              <https://charlie.example.org/profile/card#me>;
    acl:accessTo <./>;
    acl:default <./>;
    acl:mode acl:Read, acl:Write .

<#public-read> a acl:Authorization;
    acl:agentClass acl:AuthenticatedAgent;
    acl:accessTo <./>;
    acl:mode acl:Read .
```

**Index-Specific Permissions:**
```turtle
# Indices typically need broader read access for discovery
<#index-read> a acl:Authorization;
    acl:agentClass acl:AuthenticatedAgent;
    acl:accessTo <../indices/recipes/>;
    acl:default <../indices/recipes/>;
    acl:mode acl:Read .

<#index-write> a acl:Authorization;
    acl:agent <https://alice.example.org/profile/card#me>,
              <https://bob.example.org/profile/card#me>;
    acl:accessTo <../indices/recipes/>;
    acl:default <../indices/recipes/>;
    acl:mode acl:Write .
```

## 7. Performance Optimization for Solid

### 7.1. Container Organization

Solid Pod performance can degrade with large numbers of files in a single container. The implementation should organize resources hierarchically:

```dart
class SolidContainerOrganizer {
  static IriTerm organizeResourceIri(IriTerm baseContainer, String resourceId, DateTime created) {
    // Organize by date to limit container size
    String year = created.year.toString();
    String month = created.month.toString().padLeft(2, '0');

    return baseContainer.resolve('$year/$month/$resourceId');
  }

  static IriTerm organizeIndexShard(IriTerm indexContainer, String shardId) {
    // Flat structure for index shards (limited number)
    return indexContainer.resolve(shardId);
  }
}
```

### 7.2. Caching and Offline Support

```dart
class SolidOfflineCache {
  final LocalStorage localStorage;
  final SolidStorage solidStorage;

  Future<Document?> getDocumentWithCache(IriTerm documentIri) async {
    // Try local cache first
    CachedDocument? cached = await localStorage.getCachedDocument(documentIri);

    if (cached != null && !cached.isExpired()) {
      return cached.document;
    }

    try {
      // Fetch from Solid Pod with conditional request
      Document? remote = await solidStorage.getDocument(documentIri);

      if (remote != null) {
        await localStorage.cacheDocument(documentIri, remote);
        return remote;
      }
    } catch (NetworkException e) {
      // If network fails, return cached version even if expired
      if (cached != null) {
        return cached.document;
      }
      rethrow;
    }

    return null;
  }
}
```

## 8. Integration Examples

### 8.1. Complete Backend Implementation

```dart
class SolidBackend implements Backend {
  final SolidClient _solidClient;
  final IriTerm _webId;

  late final SolidResourceDiscovery _discovery;
  late final SolidStorage _storage;
  late final SolidAuthentication _auth;

  SolidBackend({
    required String webId,
    required String clientId,
    required String redirectUri,
  }) : _webId = IriTerm(webId),
       _solidClient = SolidClient() {

    _discovery = SolidResourceDiscovery(_solidClient, _webId);
    _storage = SolidStorage(_solidClient, _auth);
    _auth = SolidAuthentication(
      clientId: clientId,
      redirectUri: redirectUri,
    );
  }

  @override
  ResourceDiscovery get discovery => _discovery;

  @override
  BackendStorage get storage => _storage;

  @override
  BackendAuth get auth => _auth;

  // Solid-specific methods
  Future<void> initializePod(List<ManagedResourceType> requiredTypes) async {
    SolidPodSetup setup = SolidPodSetup(_solidClient, _webId);
    await setup.initializePod(requiredTypes);
  }

  Future<void> setupCollaboration(IriTerm resourceIri, List<IriTerm> collaborators) async {
    SolidAccessControl acl = SolidAccessControl(_solidClient);
    await acl.setupCollaborativeACL(resourceIri, collaborators);
  }
}
```

### 8.2. Application Integration

```dart
// Example application using Solid backend
class RecipeApp {
  late final SolidBackend backend;
  late final RDFCRDTSyncSystem syncSystem;

  Future<void> initialize() async {
    // Initialize Solid backend
    backend = SolidBackend(
      webId: 'https://alice.example.org/profile/card#me',
      clientId: 'https://recipe-app.example.org/',
      redirectUri: 'https://recipe-app.example.org/callback',
    );

    // Authenticate with Solid Pod
    AuthResult authResult = await backend.auth.authenticate();
    if (!authResult.isSuccess) {
      throw Exception('Authentication failed: ${authResult.error}');
    }

    // Setup Pod for recipe management
    await backend.initializePod([
      ManagedResourceType(IriTerm('https://schema.org/Recipe')),
    ]);

    // Initialize RDF-CRDT sync system
    syncSystem = RDFCRDTSyncSystem(backend: backend);
    await syncSystem.initialize();
  }

  Future<void> createRecipe(Recipe recipe) async {
    await syncSystem.save(recipe);
  }

  Stream<Recipe> getRecipes() {
    return syncSystem.hydrateStreaming<Recipe>(
      getCurrentCursor: () => getLocalCursor(),
      onUpdate: (recipe) => updateLocalStorage(recipe),
      onDelete: (recipeId) => removeFromLocalStorage(recipeId),
      onCursorUpdate: (cursor) => saveLocalCursor(cursor),
    );
  }
}
```

## 9. Error Handling and Troubleshooting

### 9.1. Solid-Specific Error Types

```dart
abstract class SolidException implements Exception {
  final String message;
  SolidException(this.message);
}

class SolidAuthException extends SolidException {
  SolidAuthException(String message) : super(message);
}

class SolidDiscoveryException extends SolidException {
  SolidDiscoveryException(String message) : super(message);
}

class SolidStorageException extends SolidException {
  final int? statusCode;
  SolidStorageException(String message, [this.statusCode]) : super(message);
}

class PodSetupException extends SolidException {
  PodSetupException(String message) : super(message);
}

class ConcurrentModificationException extends SolidException {
  ConcurrentModificationException(String message) : super(message);
}
```

### 9.2. Common Issues and Solutions

**Issue: Type Index Not Found**
```dart
// Solution: Guide user through Pod provider selection and Type Index creation
if (e is SolidDiscoveryException && e.message.contains('No public type index')) {
  bool shouldCreateTypeIndex = await askUserPermission(
    'Your Pod needs a Type Index for app discovery. Create one?'
  );

  if (shouldCreateTypeIndex) {
    await createTypeIndexForUser();
  }
}
```

**Issue: Insufficient Permissions**
```dart
// Solution: Check ACL configuration and guide user
if (e is SolidStorageException && e.statusCode == 403) {
  await showPermissionGuidance(
    'This app needs write permission to your Pod. Please check your access control settings.'
  );
}
```

**Issue: Pod Provider Discovery Fails**
```dart
// Solution: Manual Pod provider input
if (e is PodProviderException) {
  String? manualProvider = await askUserForPodProvider();
  if (manualProvider != null) {
    await retryWithPodProvider(manualProvider);
  }
}
```

## 10. Future Considerations

### 10.1. Private Type Index Support

Future versions should support Private Type Index for sensitive data:

```turtle
# Private Type Index registration
<#private-recipes> a solid:TypeRegistration;
    solid:forClass sync:ManagedDocument;
    sync:managedResourceType meal:PersonalRecipe;
    solid:instanceContainer <../private/recipes/> .
```

### 10.2. Advanced ACL Patterns

Support for group-based permissions and dynamic access control:

```dart
class AdvancedSolidACL {
  Future<void> setupGroupBasedAccess(IriTerm resourceIri, IriTerm groupIri) async {
    // ACL referencing a group document for scalable permissions
  }

  Future<void> setupConditionalAccess(IriTerm resourceIri, AccessCondition condition) async {
    // Time-based or context-based access controls
  }
}
```

### 10.3. Performance Enhancements

- **Batch Operations:** Group multiple HTTP requests for efficiency
- **Streaming Updates:** Use WebSockets where supported by Pod providers
- **Selective Sync:** More granular control over what data syncs when

---

This specification provides a complete implementation guide for using Solid Pods as the backend for the RDF-CRDT Framework, maintaining full compatibility with the core framework while leveraging Solid's unique capabilities for decentralized, collaborative applications.