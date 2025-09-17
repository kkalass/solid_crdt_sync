/// Validation for RegexTransform patterns and replacements according to REGEX-TRANSFORMS.md specification.
library;

import '../config/validation.dart';
import 'index_config.dart';

/// Validates RegexTransform objects according to the cross-platform compatible regex subset.
class RegexTransformValidator {
  // Pattern-based validation patterns
  static final RegExp _alternationPattern = RegExp(r'\|');
  static final RegExp _namedCharClassPattern = RegExp(r'\[:[a-z]+:\]');
  static final RegExp _anyBracePattern = RegExp(r'\$\{([^}]*)\}');
  static final RegExp _invalidDollarPattern = RegExp(r'\$(?!\{|\$|$)');
  static final RegExp _emptyBracesPattern = RegExp(r'\$\{\}');
  static final Set<String> _specialChars = {
    '.',
    '^',
    '\$',
    '[',
    ']',
    '(',
    ')',
    '{',
    '}',
    '*',
    '+',
    '?',
    '\\'
  };
  static final RegExp _alphanumPattern = RegExp(r'[a-zA-Z0-9]');

  /// Validates a single RegexTransform according to the specification
  static ValidationResult validate(RegexTransform transform) {
    final result = ValidationResult();

    _validatePattern(transform.pattern, result);
    _validateReplacement(transform.replacement, result);

    return result;
  }

  /// Validates a list of RegexTransforms
  static ValidationResult validateList(List<RegexTransform> transforms) {
    final results = transforms.map(validate).toList();
    return ValidationResult.merge(results);
  }

  static void _validatePattern(String pattern, ValidationResult result) {
    if (pattern.isEmpty) {
      result.addError('RegexTransform pattern cannot be empty');
      return;
    }

    // Check for forbidden alternation using pattern matching
    if (_alternationPattern.hasMatch(pattern)) {
      result.addError(
        'RegexTransform pattern contains alternation (|) which is not supported in the cross-platform compatible subset. Use multiple transform rules instead.',
        context: pattern,
      );
    }

    // Check for forbidden named character classes using pattern matching
    final namedClassMatches = _namedCharClassPattern.allMatches(pattern);
    for (final match in namedClassMatches) {
      result.addError(
        'RegexTransform pattern contains named character class ${match.group(0)} which is not supported. Use explicit ranges like [a-zA-Z] or [0-9] instead.',
        context: pattern,
      );
    }

    // Check for proper escaping and structural issues first
    _validatePatternStructure(pattern, result);

    // Then validate that the pattern can be compiled as a regex if structure is OK
    if (result.errors.isEmpty) {
      try {
        RegExp(pattern);
      } catch (e) {
        result.addError(
          'RegexTransform pattern is not a valid regular expression: $e',
          context: pattern,
        );
      }
    }
  }

  static void _validateReplacement(
      String replacement, ValidationResult result) {
    if (replacement.isEmpty) {
      result.addError('RegexTransform replacement cannot be empty');
      return;
    }

    // Check for invalid dollar usage using pattern matching
    if (_invalidDollarPattern.hasMatch(replacement)) {
      result.addError(
        'RegexTransform replacement contains invalid \$ usage. Use \${n} for backreferences or \$\$ for literal \$ character.',
        context: replacement,
      );
    }

    // Check for empty braces using pattern matching
    if (_emptyBracesPattern.hasMatch(replacement)) {
      result.addError(
        'RegexTransform replacement contains empty braces \${} which is invalid.',
        context: replacement,
      );
    }

    // Validate all backreferences are valid numbers
    final anyBraceMatches = _anyBracePattern.allMatches(replacement);
    for (final match in anyBraceMatches) {
      final groupStr = match.group(1)!;
      // Check if it's empty braces (handled separately) or if it's not numeric
      if (groupStr.isNotEmpty && !RegExp(r'^\d+$').hasMatch(groupStr)) {
        result.addError(
          'RegexTransform replacement contains invalid backreference \${$groupStr}',
          context: replacement,
        );
      }
    }
  }

  static void _validatePatternStructure(
      String pattern, ValidationResult result) {
    // Validate escape sequences and bracket matching
    var bracketDepth = 0;
    var parenDepth = 0;
    var braceDepth = 0;
    var inCharClass = false;

    for (int i = 0; i < pattern.length; i++) {
      final char = pattern[i];

      switch (char) {
        case '\\':
          // Handle escape sequences
          if (i + 1 >= pattern.length) {
            result.addError(
              'RegexTransform pattern ends with incomplete escape sequence',
              context: pattern,
            );
            return;
          }

          final nextChar = pattern[i + 1];
          // Only warn about truly non-portable sequences, not standard alphanumeric escapes
          if (!_specialChars.contains(nextChar) &&
              !_alphanumPattern.hasMatch(nextChar) &&
              !RegExp(r'[nrtfvab]').hasMatch(nextChar)) {
            result.addWarning(
              'RegexTransform pattern contains escape sequence \\$nextChar which may not be portable across all platforms',
              context: pattern,
            );
          }
          i++; // Skip the escaped character

        case '[':
          if (!inCharClass) {
            inCharClass = true;
            bracketDepth++;
          }

        case ']':
          if (inCharClass) {
            inCharClass = false;
            bracketDepth--;
          }

        case '(':
          if (!inCharClass) parenDepth++;

        case ')':
          if (!inCharClass) {
            parenDepth--;
            if (parenDepth < 0) {
              result.addError(
                'RegexTransform pattern contains unmatched closing parenthesis',
                context: pattern,
              );
              return;
            }
          }

        case '{':
          if (!inCharClass) braceDepth++;

        case '}':
          if (!inCharClass) {
            braceDepth--;
            if (braceDepth < 0) {
              result.addError(
                'RegexTransform pattern contains unmatched closing brace',
                context: pattern,
              );
              return;
            }
          }
      }
    }

    // Check for unmatched brackets
    if (bracketDepth > 0) {
      result.addError(
        'RegexTransform pattern contains unmatched opening bracket [',
        context: pattern,
      );
    }
    if (parenDepth > 0) {
      result.addError(
        'RegexTransform pattern contains unmatched opening parenthesis (',
        context: pattern,
      );
    }
    if (braceDepth > 0) {
      result.addError(
        'RegexTransform pattern contains unmatched opening brace {',
        context: pattern,
      );
    }
  }
}
