# Version and Release Management

With the multipackage structure, we now use Melos for coordinated version and release management instead of custom scripts.

## Version Management

**Update versions across all packages:**
```bash
dart pub run melos version
```

This will:
- Prompt for version type (patch, minor, major, or custom)
- Update all package versions consistently
- Generate changelog entries
- Create git commits and tags

**Preview version changes:**
```bash
dart pub run melos version --dry-run
```

## Release Management  

**Publish all packages:**
```bash
dart pub run melos publish
```

This will:
- Build and validate all packages
- Show what will be published
- Prompt for confirmation per package
- Publish to pub.dev

**Preview release:**
```bash
dart pub run melos release
```

This runs both version and publish in preview mode.

## Manual Per-Package Operations

**Version individual package:**
```bash
melos version --scope=pacors_core
```

**Publish individual package:**
```bash
melos publish --scope=pacors_core
```

## Migration from Old Scripts

The old `tool/update_version.dart` and `tool/release.dart` have been replaced by melos built-in functionality which is:
- More reliable for multipackage repos
- Better at handling cross-package dependencies  
- Integrates with conventional commits
- Provides better safety checks