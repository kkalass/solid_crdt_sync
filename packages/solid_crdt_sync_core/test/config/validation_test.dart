import 'package:test/test.dart';
import 'package:solid_crdt_sync_core/src/config/validation.dart';

void main() {
  group('ValidationResult', () {
    test('should start as valid with no issues', () {
      final result = ValidationResult();
      
      expect(result.isValid, isTrue);
      expect(result.hasIssues, isFalse);
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
    });
    
    test('should become invalid when error is added', () {
      final result = ValidationResult();
      result.addError('Test error');
      
      expect(result.isValid, isFalse);
      expect(result.hasIssues, isTrue);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.message, equals('Test error'));
    });
    
    test('should remain valid when only warnings are added', () {
      final result = ValidationResult();
      result.addWarning('Test warning');
      
      expect(result.isValid, isTrue);
      expect(result.hasIssues, isTrue);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.first.message, equals('Test warning'));
    });
    
    test('should include context in errors and warnings', () {
      final result = ValidationResult();
      final context = {'type': String, 'path': '/test'};
      
      result.addError('Error with context', context: context);
      result.addWarning('Warning with context', context: context);
      
      expect(result.errors.first.context, equals(context));
      expect(result.warnings.first.context, equals(context));
    });
    
    test('should throw validation exception when invalid', () {
      final result = ValidationResult();
      result.addError('Test error');
      
      expect(() => result.throwIfInvalid(), 
             throwsA(isA<SyncConfigValidationException>()));
    });
    
    test('should not throw when valid', () {
      final result = ValidationResult();
      result.addWarning('Just a warning');
      
      expect(() => result.throwIfInvalid(), returnsNormally);
    });
    
    test('should generate formatted summary', () {
      final result = ValidationResult();
      result.addError('First error');
      result.addError('Second error');
      result.addWarning('First warning');
      
      final summary = result.getSummary();
      
      expect(summary, contains('Validation Errors (2):'));
      expect(summary, contains('1. First error'));
      expect(summary, contains('2. Second error'));
      expect(summary, contains('Validation Warnings (1):'));
      expect(summary, contains('1. First warning'));
    });
  });
  
  group('SyncConfigValidationException', () {
    test('should include formatted summary in toString', () {
      final result = ValidationResult();
      result.addError('Test error');
      result.addWarning('Test warning');
      
      final exception = SyncConfigValidationException(result);
      final message = exception.toString();
      
      expect(message, contains('SyncConfig validation failed:'));
      expect(message, contains('Test error'));
      expect(message, contains('Test warning'));
    });
  });
  
  group('ValidationError and ValidationWarning', () {
    test('should preserve message and context', () {
      const message = 'Test message';
      final context = {'key': 'value'};
      
      final error = ValidationError(message, context: context);
      final warning = ValidationWarning(message, context: context);
      
      expect(error.message, equals(message));
      expect(error.context, equals(context));
      expect(error.toString(), equals(message));
      
      expect(warning.message, equals(message));
      expect(warning.context, equals(context));
      expect(warning.toString(), equals(message));
    });
  });
}