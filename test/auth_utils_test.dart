import 'package:flutter_test/flutter_test.dart';
import 'package:nook/utils/auth_utils.dart';

void main() {
  group('validators', () {
    test('name', () {
      expect(AuthValidators.name(''), isNotNull);
      expect(AuthValidators.name(' A '), isNotNull);
      expect(AuthValidators.name('Al'), isNull);
    });
    test('email', () {
      expect(AuthValidators.email(null), 'Enter your email address');
      expect(AuthValidators.email('nope'), 'Enter a valid email address');
      expect(AuthValidators.email(' a@b.com '), isNull);
    });
    test('phone', () {
      expect(AuthValidators.phone(''), 'Enter your phone number');
      expect(AuthValidators.phone('12'), 'Enter a valid phone number');
      expect(AuthValidators.phone('+91 98765 43210'), isNull);
    });
    test('passwords', () {
      expect(AuthValidators.currentPassword(''), isNotNull);
      expect(AuthValidators.currentPassword('x'), isNull);
      expect(AuthValidators.newPassword('12345'), 'Use at least 6 characters');
      expect(AuthValidators.newPassword('123456'), isNull);
      final confirm = AuthValidators.confirmPassword(() => 'secret1');
      expect(confirm(''), isNotNull);
      expect(confirm('secret2'), 'Passwords do not match');
      expect(confirm('secret1'), isNull);
    });
  });

  group('emailTypoHint', () {
    test('fixes mistyped .com endings', () {
      expect(AuthValidators.emailTypoHint('md@gmail.con'), 'md@gmail.com');
      expect(AuthValidators.emailTypoHint('md@college.cmo'), 'md@college.com');
    });
    test('fixes common provider typos and keeps the local part', () {
      expect(AuthValidators.emailTypoHint('Sam.K@gmial.com'), 'Sam.K@gmail.com');
      expect(AuthValidators.emailTypoHint('a@yahooo.com'), 'a@yahoo.com');
    });
    test('stays quiet for good or incomplete addresses', () {
      expect(AuthValidators.emailTypoHint('a@gmail.com'), isNull);
      expect(AuthValidators.emailTypoHint('a@college.edu'), isNull);
      expect(AuthValidators.emailTypoHint('a@'), isNull);
      expect(AuthValidators.emailTypoHint('plain'), isNull);
      expect(AuthValidators.emailTypoHint(null), isNull);
    });
  });

  group('PasswordStrength', () {
    test('scores', () {
      expect(PasswordStrength.score('abc'), 0);
      expect(PasswordStrength.score('abcdef'), 0);
      expect(PasswordStrength.score('abcdefgh'), 1);
      expect(PasswordStrength.score('Abcdefg1'), 3);
      expect(PasswordStrength.score('Abcdefg1!'), 4);
    });
    test('labels', () {
      expect(PasswordStrength.label(''), '');
      expect(PasswordStrength.label('abc'), 'Too short');
      expect(PasswordStrength.label('abcdef'), 'Weak');
      expect(PasswordStrength.label('Abcdefg1!'), 'Strong');
    });
  });

  group('AuthErrors.friendly', () {
    test('maps known Supabase messages', () {
      expect(AuthErrors.friendly('AuthApiException(message: Invalid login credentials, statusCode: 400, code: invalid_credentials)'),
          'Incorrect email or password.');
      expect(AuthErrors.friendly('AuthApiException(message: Email not confirmed, statusCode: 400)'),
          contains('confirm your email'));
      expect(AuthErrors.friendly('AuthApiException(message: User already registered, statusCode: 422)'),
          contains('already exists'));
      expect(AuthErrors.friendly('email rate limit exceeded'), contains('Too many attempts'));
      expect(AuthErrors.friendly('SocketException: Failed host lookup: x.supabase.co'),
          contains('No internet'));
    });
    test('extracts the message from unknown AuthExceptions', () {
      expect(AuthErrors.friendly('AuthException(message: signups are closed, statusCode: 400)'),
          'Signups are closed');
    });
    test('strips the Exception prefix and has a fallback', () {
      expect(AuthErrors.friendly(Exception('Registration failed.')), 'Registration failed.');
      expect(AuthErrors.friendly(''), 'Something went wrong. Please try again.');
    });
  });
}
