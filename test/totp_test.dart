import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/services/totp_service.dart';

void main() {
  group('TotpService Tests', () {
    // Secret "12345678901234567890" in Base32 is "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
    const testSecret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

    test('RFC 6238 standard test vectors', () {
      // 59s -> 287082
      final code1 = TotpService.generateCode(
        secret: testSecret,
        time: DateTime.fromMillisecondsSinceEpoch(59 * 1000),
      );
      expect(code1, '287082');

      // 1111111109s -> 081804
      final code2 = TotpService.generateCode(
        secret: testSecret,
        time: DateTime.fromMillisecondsSinceEpoch(1111111109 * 1000),
      );
      expect(code2, '081804');

      // 1234567890s -> 005924
      final code3 = TotpService.generateCode(
        secret: testSecret,
        time: DateTime.fromMillisecondsSinceEpoch(1234567890 * 1000),
      );
      expect(code3, '005924');

      // 2000000000s -> 279037
      final code4 = TotpService.generateCode(
        secret: testSecret,
        time: DateTime.fromMillisecondsSinceEpoch(2000000000 * 1000),
      );
      expect(code4, '279037');
    });

    test('Verification with exact and window tolerance', () {
      final now = DateTime.now();
      final code = TotpService.generateCode(secret: testSecret, time: now);

      // Exact match
      expect(TotpService.verifyCode(secret: testSecret, code: code, time: now), isTrue);

      // Wrong code
      expect(TotpService.verifyCode(secret: testSecret, code: '000000', time: now), isFalse);

      // 25 seconds later (same or adjacent window)
      final future = now.add(const Duration(seconds: 25));
      expect(TotpService.verifyCode(secret: testSecret, code: code, time: future, window: 1), isTrue);
    });

    test('Secret generation and URI building', () {
      final secret = TotpService.generateSecret(length: 16);
      expect(secret.length, 16);

      final uri = TotpService.buildOtpAuthUri(username: 'reyhan', secret: secret);
      expect(uri, contains('otpauth://totp/YourLog:reyhan'));
      expect(uri, contains('secret=$secret'));
      expect(uri, contains('issuer=YourLog'));
    });
  });
}
