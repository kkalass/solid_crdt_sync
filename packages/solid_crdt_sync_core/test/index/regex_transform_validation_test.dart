import 'package:solid_crdt_sync_core/src/index/index_config.dart';
import 'package:solid_crdt_sync_core/src/index/regex_transform_validation.dart';
import 'package:test/test.dart';

void main() {
  group('RegexTransformValidator', () {
    group('pattern validation', () {
      test('accepts valid patterns from specification', () {
        final validPatterns = [
          r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$', // Date pattern
          r'^([a-zA-Z]+)[-_].*$', // Category extraction
          r'^([A-Z]{2})([0-9]+)$', // Identifier format
          r'[a-z]+', // Simple character class
          r'[^abc]', // Negated character class
          r'[0-9a-fA-F]+', // Combined ranges
          r'.*', // Any character
          r'test+', // One or more quantifier
          r'test*', // Zero or more quantifier
          r'test?', // Zero or one quantifier
          r'test{3}', // Exact quantifier
          r'test{2,5}', // Range quantifier
          r'test{2,}', // Open-ended quantifier
          r'(group)', // Capture group
          r'\.', // Escaped special character
        ];

        for (final pattern in validPatterns) {
          final transform = RegexTransform(pattern, r'${1}');
          final result = RegexTransformValidator.validate(transform);
          expect(result.isValid, isTrue,
              reason: 'Pattern should be valid: $pattern');
        }
      });

      test('rejects patterns with alternation', () {
        final invalidPatterns = [
          r'cat|dog',
          r'(cat|dog)',
          r'^(pattern1|pattern2)$',
        ];

        for (final pattern in invalidPatterns) {
          final transform = RegexTransform(pattern, r'${1}');
          final result = RegexTransformValidator.validate(transform);
          expect(result.isValid, isFalse,
              reason: 'Pattern with alternation should be invalid: $pattern');
          expect(result.errors.any((e) => e.message.contains('alternation')),
              isTrue);
        }
      });

      test('rejects patterns with named character classes', () {
        final invalidPatterns = [
          r'[:alpha:]',
          r'[[:digit:]]+',
          r'[[:upper:][:lower:]]',
          r'[:alnum:]',
          r'[:punct:]',
          r'[:space:]',
          r'[:xdigit:]',
          r'[:blank:]',
          r'[:cntrl:]',
          r'[:graph:]',
          r'[:print:]',
        ];

        for (final pattern in invalidPatterns) {
          final transform = RegexTransform(pattern, r'${1}');
          final result = RegexTransformValidator.validate(transform);
          expect(result.isValid, isFalse,
              reason:
                  'Pattern with named character class should be invalid: $pattern');
          expect(
              result.errors
                  .any((e) => e.message.contains('named character class')),
              isTrue);
        }
      });

      test('rejects invalid regex syntax', () {
        final invalidPatterns = [
          r'[',
          r'*',
          r'(',
          r'(?invalid)',
          r'{3,2}', // Invalid quantifier range
        ];

        for (final pattern in invalidPatterns) {
          final transform = RegexTransform(pattern, r'${1}');
          final result = RegexTransformValidator.validate(transform);
          expect(result.isValid, isFalse,
              reason: 'Invalid regex syntax should be rejected: $pattern');
          // Some errors are caught by structural validation, others by regex compilation
          expect(result.errors.isNotEmpty, isTrue,
              reason: 'Should have errors for invalid pattern: $pattern');
        }
      });

      test('rejects empty patterns', () {
        final transform = RegexTransform('', r'${1}');
        final result = RegexTransformValidator.validate(transform);
        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.message.contains('cannot be empty')),
            isTrue);
      });

      test('warns about potentially non-portable escape sequences', () {
        final patterns = [
          r'\#', // Non-standard escape (not alphanumeric or special)
          r'\@', // Non-standard escape
        ];

        for (final pattern in patterns) {
          final transform = RegexTransform(pattern, r'${1}');
          final result = RegexTransformValidator.validate(transform);
          expect(
              result.warnings
                  .any((w) => w.message.contains('may not be portable')),
              isTrue,
              reason: 'Pattern $pattern should generate portability warning');
        }
      });

      test('detects incomplete escape sequences', () {
        final transform = RegexTransform(r'test\', r'${1}');
        final result = RegexTransformValidator.validate(transform);
        expect(result.isValid, isFalse);
        expect(
            result.errors
                .any((e) => e.message.contains('incomplete escape sequence')),
            isTrue);
      });
    });

    group('replacement validation', () {
      test('accepts valid replacement patterns', () {
        final validReplacements = [
          r'${1}',
          r'${0}',
          r'${1}-${2}',
          r'prefix-${1}',
          r'${1}-suffix',
          r'$$', // Literal dollar
          r'${1}$$${2}', // Mixed with literal dollars
          r'${10}', // Double-digit groups
          r'${1}1', // Group followed by literal digit
        ];

        for (final replacement in validReplacements) {
          final transform = RegexTransform(r'(.+)', replacement);
          final result = RegexTransformValidator.validate(transform);
          expect(result.isValid, isTrue,
              reason: 'Replacement should be valid: $replacement');
        }
      });

      test('rejects invalid dollar usage', () {
        final invalidReplacements = [
          r'$1', // Missing braces
          r'$hello', // Invalid syntax
          r'${1}$2', // Mixed syntax
        ];

        for (final replacement in invalidReplacements) {
          final transform = RegexTransform(r'(.+)', replacement);
          final result = RegexTransformValidator.validate(transform);
          expect(result.isValid, isFalse,
              reason: 'Invalid dollar usage should be rejected: $replacement');
          expect(
              result.errors.any((e) => e.message.contains('invalid \$ usage')),
              isTrue);
        }
      });

      test('rejects empty braces', () {
        final transform = RegexTransform(r'(.+)', r'${}');
        final result = RegexTransformValidator.validate(transform);
        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.message.contains('empty braces')),
            isTrue);
      });

      test('rejects invalid backreferences', () {
        final invalidReplacements = [
          r'${abc}', // Non-numeric
          r'${1a}', // Mixed alphanumeric
        ];

        for (final replacement in invalidReplacements) {
          final transform = RegexTransform(r'(.+)', replacement);
          final result = RegexTransformValidator.validate(transform);
          expect(result.isValid, isFalse,
              reason: 'Invalid backreference should be rejected: $replacement');
          expect(
              result.errors
                  .any((e) => e.message.contains('invalid backreference')),
              isTrue);
        }
      });

      test('rejects empty replacements', () {
        final transform = RegexTransform(r'(.+)', '');
        final result = RegexTransformValidator.validate(transform);
        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.message.contains('cannot be empty')),
            isTrue);
      });
    });

    group('list validation', () {
      test('validates multiple transforms', () {
        final transforms = [
          RegexTransform(r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$', r'${1}-${2}'),
          RegexTransform(r'^([0-9]{4})/([0-9]{2})/([0-9]{2})$', r'${1}-${2}'),
        ];

        final result = RegexTransformValidator.validateList(transforms);
        expect(result.isValid, isTrue);
      });

      test('reports errors from all transforms', () {
        final transforms = [
          RegexTransform(r'cat|dog', r'${1}'), // Invalid: alternation
          RegexTransform(r'(.+)', r'$1'), // Invalid: replacement syntax
        ];

        final result = RegexTransformValidator.validateList(transforms);
        expect(result.isValid, isFalse);
        expect(result.errors.length, equals(2));
        expect(result.errors.any((e) => e.message.contains('alternation')),
            isTrue);
        expect(result.errors.any((e) => e.message.contains('invalid \$ usage')),
            isTrue);
      });

      test('handles empty list', () {
        final result = RegexTransformValidator.validateList([]);
        expect(result.isValid, isTrue);
        expect(result.errors.isEmpty, isTrue);
        expect(result.warnings.isEmpty, isTrue);
      });
    });

    group('real-world examples from specification', () {
      test('validates date transformation examples', () {
        final transforms = [
          // Monthly grouping
          RegexTransform(r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$', r'${1}-${2}'),
          // Yearly grouping
          RegexTransform(r'^([0-9]{4})-[0-9]{2}-[0-9]{2}$', r'${1}'),
          // Multiple date formats
          RegexTransform(r'^([0-9]{4})/([0-9]{2})/([0-9]{2})$', r'${1}-${2}'),
        ];

        for (final transform in transforms) {
          final result = RegexTransformValidator.validate(transform);
          expect(result.isValid, isTrue,
              reason: 'Date transform should be valid: ${transform.pattern}');
        }
      });

      test('validates string normalization examples', () {
        final transforms = [
          // Category extraction
          RegexTransform(r'^([a-zA-Z]+)[-_].*$', r'${1}'),
          // Identifier reformatting
          RegexTransform(r'^([A-Z]{2})([0-9]+)$', r'${1}-${2}'),
          // Project name extraction variants
          RegexTransform(r'^project[-_]([a-zA-Z0-9]+)$', r'${1}'),
          RegexTransform(r'^proj[-_]([a-zA-Z0-9]+)$', r'${1}'),
          RegexTransform(r'^([a-zA-Z0-9]+)[-_]project$', r'${1}'),
          RegexTransform(r'^([a-zA-Z0-9]+)[-_]proj$', r'${1}'),
        ];

        for (final transform in transforms) {
          final result = RegexTransformValidator.validate(transform);
          expect(result.isValid, isTrue,
              reason:
                  'String normalization transform should be valid: ${transform.pattern}');
        }
      });
    });
  });
}
