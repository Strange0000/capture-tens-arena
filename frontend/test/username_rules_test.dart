import 'package:flutter_test/flutter_test.dart';
import 'package:capture_tens_arena/src/services/username_rules.dart';

void main() {
  group('username validation rules (client mirror of the server)', () {
    test('accepts a normal name', () {
      expect(validateUsernameLocally('Arjun_99'), isNull);
      expect(validateUsernameLocally('Meera'), isNull);
    });

    test('rejects names shorter than 3 or longer than 24 chars', () {
      expect(validateUsernameLocally('Ab'), contains('at least 3'));
      expect(validateUsernameLocally('A' * 25), contains('at most 24'));
    });

    test('rejects names that do not start with a letter', () {
      expect(validateUsernameLocally('9lives'), contains('start with a letter'));
      expect(validateUsernameLocally('_hidden'), isNotNull);
    });

    test('rejects spaces and special characters', () {
      expect(validateUsernameLocally('Sumit Jaiswal'), isNotNull);
      expect(validateUsernameLocally('cool-name'), isNotNull);
    });

    test('rejects reserved names and the Guest prefix, any casing', () {
      expect(validateUsernameLocally('Admin'), contains('reserved'));
      expect(validateUsernameLocally('Vector'), contains('reserved'));
      expect(validateUsernameLocally('GuestXyz'), contains('reserved'));
      expect(isReservedUsername('guestab12cd'), isTrue);
      expect(isReservedUsername('arjun'), isFalse);
    });

    test('sanitizes a Google profile name into a valid base', () {
      expect(sanitizeUsernameBase('Sumit Jaiswal'), 'SumitJaiswal');
      expect(sanitizeUsernameBase('  !!! '), 'Player');
      expect(sanitizeUsernameBase('a-very-long-name-that-keeps-going-forever').length,
          lessThanOrEqualTo(20));
    });
  });
}
