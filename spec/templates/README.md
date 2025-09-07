# Framework Templates Directory

This directory contains RDF document templates used during Pod initialization and as reference examples for the CRDT synchronization framework.

## Template Files

### Core Framework Templates

- **`installation-document.ttl`** - Client Installation Document template for identity management
- **`gc-index-template.ttl`** - Framework Garbage Collection Index for tombstoned resource cleanup  
- **`installation-index-template.ttl`** - Installation Index for efficient installation management
- **`type-index-entries.ttl`** - Type Index registrations required by the framework

## Template Usage

### Placeholder Substitution

Templates use placeholder syntax `{PLACEHOLDER_NAME}` that should be replaced during initialization:

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{POD_BASE_URI}` | Base URI of the Pod | `https://alice.podprovider.org/` |
| `{WEBID_URI}` | User's WebID | `https://alice.podprovider.org/profile/card#me` |
| `{INSTALLATION_URI}` | Full URI to the installation document | `https://alice.podprovider.org/apps/recipe-app/installation-xyz#installation` |
| `{INSTALLATION_ID}` | Unique installation identifier | `mobile-recipe-app-2024-09-04-xyz` |
| `{APP_ID}` | Application identifier | `https://meal-planning-app.example.org/id` |
| `{TIMESTAMP}` | ISO 8601 timestamp | `2024-09-04T17:30:00Z` |
| `{INDEX_HASH}` | SHA256 hash for index naming | `a1b2c3d4` |
| `{INSTALLATION_CONTAINER_URI}` | Container URI for installations (from Type Index) | `https://alice.podprovider.org/apps/` |
| `{FRAMEWORK_INDEX_CONTAINER_URI}` | Container URI for framework indices | `https://alice.podprovider.org/system/indices/` |

### Initialization Process

1. **Template Selection**: Choose appropriate templates based on required functionality
2. **Placeholder Replacement**: Substitute placeholders with Pod-specific values
3. **CRDT Merge**: Merge template content with existing Pod documents using framework CRDT rules
4. **Validation**: Verify all required Type Index registrations and document structures

### Template Merging

Templates are designed to be merged with existing Pod documents:

- **New Pod**: Templates create initial structure
- **Existing Pod**: Templates add missing framework components without overwriting user data
- **Version Upgrades**: New template versions can add features while preserving existing data

## Version Compatibility

Templates are versioned alongside the framework specification:

- Template modifications follow semantic versioning
- Breaking changes require new template versions
- Migration guides provided for template upgrades

## Development Usage

### Testing

Templates serve as ground truth for test fixtures:

```turtle
# Tests can validate against template structure
TEMPLATE_DIR=templates/
EXPECTED_STRUCTURE=$(cat $TEMPLATE_DIR/installation-document.ttl)
```

### Documentation

Templates provide concrete examples that supplement abstract documentation:

- Show exact RDF structure expected by the framework
- Demonstrate proper CRDT mapping usage
- Illustrate real-world Type Index configuration

## Framework Integration

The framework uses these templates during:

1. **Pod Setup Dialog**: Show users what will be created
2. **Automatic Initialization**: Copy templates with placeholder substitution
3. **Recovery Operations**: Restore missing system components
4. **Migration**: Upgrade existing Pods to new framework versions

## Contributing

When modifying templates:

1. Update corresponding documentation
2. Add migration notes for breaking changes  
3. Update placeholder documentation
4. Test with various Pod configurations
5. Validate RDF syntax and semantic correctness