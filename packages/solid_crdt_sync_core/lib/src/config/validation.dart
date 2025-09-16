/// Validation utilities for SyncConfig and related configuration classes.
library;

/// Result of a validation operation containing errors and warnings.
class ValidationResult {
  final List<ValidationError> errors = [];
  final List<ValidationWarning> warnings = [];

  /// True if validation passed (no errors, warnings are allowed).
  bool get isValid => errors.isEmpty;

  /// True if there are any issues (errors or warnings).
  bool get hasIssues => errors.isNotEmpty || warnings.isNotEmpty;

  /// Add a validation error (blocks operation).
  void addError(String message, {Object? context}) {
    errors.add(ValidationError(message, context: context));
  }

  /// Add a validation warning (informational).
  void addWarning(String message, {Object? context}) {
    warnings.add(ValidationWarning(message, context: context));
  }

  static ValidationResult merge(List<ValidationResult> results) {
    final combinedValidationResult = ValidationResult();
    for (final result in results) {
      combinedValidationResult.errors.addAll(result.errors);
      combinedValidationResult.warnings.addAll(result.warnings);
    }
    return combinedValidationResult;
  }

  /// Throw SyncConfigValidationException if validation failed.
  void throwIfInvalid() {
    if (!isValid) {
      throw SyncConfigValidationException(this);
    }
  }

  /// Get a formatted summary of all issues.
  String getSummary() {
    final buffer = StringBuffer();

    if (errors.isNotEmpty) {
      buffer.writeln('Validation Errors (${errors.length}):');
      for (int i = 0; i < errors.length; i++) {
        buffer.writeln('  ${i + 1}. ${errors[i].message}');
      }
    }

    if (warnings.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('Validation Warnings (${warnings.length}):');
      for (int i = 0; i < warnings.length; i++) {
        buffer.writeln('  ${i + 1}. ${warnings[i].message}');
      }
    }

    return buffer.toString();
  }
}

/// Base class for validation issues.
abstract class ValidationIssue {
  final String message;
  final Object? context;

  const ValidationIssue(this.message, {this.context});

  @override
  String toString() => message;
}

/// A validation error that prevents the configuration from being used.
class ValidationError extends ValidationIssue {
  const ValidationError(String message, {Object? context})
      : super(message, context: context);
}

/// A validation warning about potential issues.
class ValidationWarning extends ValidationIssue {
  const ValidationWarning(String message, {Object? context})
      : super(message, context: context);
}

/// Exception thrown when SyncConfig validation fails.
class SyncConfigValidationException implements Exception {
  final ValidationResult result;

  const SyncConfigValidationException(this.result);

  @override
  String toString() {
    return 'SyncConfig validation failed:\n${result.getSummary()}';
  }
}
