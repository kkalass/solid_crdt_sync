import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;

/// Updates version references in documentation and generates API docs.
///
/// This script ensures that all documentation references to the package version
/// stay in sync with the actual version defined in pubspec.yaml, and generates
/// up-to-date API documentation.
///
/// Usage:
///   dart run tool/update_version.dart [options]
///     --check: Only check if version references are up-to-date without modifying files
///     --skip-docs: Skip generating API documentation
///     --help: Show this help message
void main(List<String> args) async {
  if (args.contains('--help')) {
    _printUsage();
    exit(0);
  }

  // Parse arguments
  final checkOnly = args.contains('--check');
  final skipDocs = args.contains('--skip-docs');
  final mode = checkOnly ? 'Checking' : 'Updating';

  // Find workspace root (directory containing pubspec.yaml)
  final rootDir = _findWorkspaceRoot();
  if (rootDir == null) {
    print(
      'Error: Could not find workspace root (directory containing pubspec.yaml)',
    );
    exit(1);
  }

  // Change to workspace root
  Directory.current = rootDir;

  // Get the current version from pubspec.yaml
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('Error: pubspec.yaml not found');
    exit(1);
  }

  final pubspecContent = pubspecFile.readAsStringSync();
  final pubspec = loadYaml(pubspecContent) as Map;
  final currentVersion = pubspec['version'];

  if (currentVersion == null) {
    print('Error: No version field found in pubspec.yaml');
    exit(1);
  }

  print('Current version: $currentVersion');
  print('$mode documentation version references...');

  // Files to update
  final filesToUpdate = {
    'README.md': _updateReadme,
    'doc/index.html': _updateDocIndex,
  };

  var hasChanges = false;
  var hasErrors = false;

  // Update each file
  filesToUpdate.forEach((filePath, updateFunction) {
    final file = File(filePath);
    if (!file.existsSync()) {
      print('Warning: $filePath not found, skipping');
      return;
    }

    print('$mode $filePath...');
    final content = file.readAsStringSync();
    final updatedContent = updateFunction(content, currentVersion);

    if (content == updatedContent) {
      print('  ✓ $filePath is up-to-date');
    } else {
      if (checkOnly) {
        print('  ✗ $filePath contains outdated version references');
        hasErrors = true;
      } else {
        file.writeAsStringSync(updatedContent);
        print('  ✓ Updated $filePath successfully');
        hasChanges = true;
      }
    }
  });

  // Generate API documentation if not in check-only mode
  if (!skipDocs && !checkOnly) {
    print('\nGenerating API documentation...');
    try {
      final result = await Process.run('dart', [
        'pub',
        'global',
        'run',
        'dartdoc',
      ]);

      if (result.exitCode != 0) {
        print('Warning: Failed to generate API documentation');
        print(result.stderr);
      } else {
        print('  ✓ API documentation generated successfully');
        hasChanges = true;
      }
    } catch (e) {
      print('Error: Failed to generate API documentation: $e');
      print(
        'Make sure dartdoc is installed (dart pub global activate dartdoc)',
      );
    }
  }

  // Final message
  if (checkOnly) {
    if (hasErrors) {
      print(
        '\nError: Some documentation files contain outdated version references.',
      );
      print('Run "dart run tool/update_version.dart" to update them.');
      exit(1);
    } else {
      print('\nSuccess: All documentation version references are up-to-date.');
    }
  } else {
    if (hasChanges) {
      print('\nSuccess: Documentation updated to v$currentVersion');
    } else {
      print(
        '\nSuccess: No updates needed, all documentation is already up-to-date.',
      );
    }
  }
}

/// Prints usage information for the tool
void _printUsage() {
  print('Update Version Tool');
  print('------------------');
  print(
    'Updates version references in documentation files to match the current',
  );
  print('version in pubspec.yaml and generates API documentation.');
  print('');
  print('Usage:');
  print('  dart run tool/update_version.dart [options]');
  print('');
  print('Options:');
  print(
    '  --check       Only check if version references are up-to-date without modifying files',
  );
  print('  --skip-docs   Skip generating API documentation');
  print('  --help        Show this help message');
}

/// Finds the workspace root directory (containing pubspec.yaml)
Directory? _findWorkspaceRoot() {
  var dir = Directory.current;

  while (dir.path != dir.parent.path) {
    if (File(path.join(dir.path, 'pubspec.yaml')).existsSync()) {
      return dir;
    }
    dir = dir.parent;
  }

  return null;
}

/// Updates version references in README.md
String _updateReadme(String content, String version) {
  // Extract clean version without any -dev suffix for documentation
  final cleanVersion = version.split('-').first;
  var result = content;

  // Update pubspec.yaml example with a more robust pattern
  final pubspecPattern = RegExp(
    r'```yaml\s*\n\s*dependencies:\s*\n\s*solid_crdt_sync:\s*\^[0-9]+\.[0-9]+\.[0-9]+(?:[-+].+)?',
    multiLine: true,
  );
  final updatedPubspec =
      '```yaml\ndependencies:\n  solid_crdt_sync: ^$cleanVersion';
  if (pubspecPattern.hasMatch(result)) {
    result = result.replaceAll(pubspecPattern, updatedPubspec);
  }

  // Replace any complex dart pub add command with the simplified version
  final dartPubAddPattern = RegExp(
    r'```bash\s*\n\s*dart pub add solid_crdt_sync(?::.*)?',
    multiLine: true,
  );
  const updatedDartPubAdd = '```bash\ndart pub add solid_crdt_sync';
  if (dartPubAddPattern.hasMatch(result)) {
    result = result.replaceAll(dartPubAddPattern, updatedDartPubAdd);
  }

  return result;
}

/// Updates version references in doc/index.html
String _updateDocIndex(String content, String version) {
  // Extract clean version without any -dev suffix for documentation
  final cleanVersion = version.split('-').first;
  var result = content;

  // Update installation code block in Quick Start section - more robust pattern
  final dependencyPattern = RegExp(
    r'<code class="language-yaml">dependencies:\s*\n\s*solid_crdt_sync:\s*\^[0-9]+\.[0-9]+\.[0-9]+(?:[-+].+)?',
    multiLine: true,
  );
  final updatedDependency =
      '<code class="language-yaml">dependencies:\n  solid_crdt_sync: ^$cleanVersion';
  if (dependencyPattern.hasMatch(result)) {
    result = result.replaceAll(dependencyPattern, updatedDependency);
  }

  // Always simplify the dart pub add command
  final dartPubAddPattern = RegExp(
    r'<code class="language-bash">dart pub add solid_crdt_sync(?::[^\s<]+)?',
    multiLine: true,
  );
  const updatedDartPubAdd =
      '<code class="language-bash">dart pub add solid_crdt_sync';
  if (dartPubAddPattern.hasMatch(result)) {
    result = result.replaceAll(dartPubAddPattern, updatedDartPubAdd);
  }

  return result;
}
