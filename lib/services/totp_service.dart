import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Pure Dart implementation of RFC 6238 (TOTP) and RFC 4648 (Base32)
/// compatible with Google Authenticator.
class TotpService {
  static const String _base32Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Generates a cryptographically secure random Base32 secret (default 16 chars).
  static String generateSecret({int length = 16}) {
    final rand = Random.secure();
    final buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      buffer.write(_base32Chars[rand.nextInt(_base32Chars.length)]);
    }
    return buffer.toString();
  }

  /// Builds the standard Google Authenticator QR Code URI (`otpauth://...`)
  static String buildOtpAuthUri({
    required String username,
    required String secret,
    String issuer = 'YourLog',
  }) {
    final cleanIssuer = Uri.encodeComponent(issuer);
    final cleanUsername = Uri.encodeComponent(username);
    return 'otpauth://totp/$cleanIssuer:$cleanUsername?secret=$secret&issuer=$cleanIssuer&algorithm=SHA1&digits=6&period=30';
  }

  /// Calculates the 6-digit TOTP code for a given secret at a specific timestamp.
  static String generateCode({
    required String secret,
    DateTime? time,
    int period = 30,
    int digits = 6,
  }) {
    final targetTime = time ?? DateTime.now();
    final epochSeconds = targetTime.millisecondsSinceEpoch ~/ 1000;
    final counter = epochSeconds ~/ period;

    return _generateCodeForCounter(secret, counter, digits: digits);
  }

  /// Verifies a user-entered 6-digit code against the secret key.
  /// Includes a ±[window] period tolerance (default: ±1 period = 90s total window)
  /// to account for slight clock drift between the user's phone and server.
  static bool verifyCode({
    required String secret,
    required String code,
    DateTime? time,
    int period = 30,
    int digits = 6,
    int window = 1,
  }) {
    final cleanCode = code.trim().replaceAll(' ', '');
    if (cleanCode.length != digits) return false;

    final targetTime = time ?? DateTime.now();
    final epochSeconds = targetTime.millisecondsSinceEpoch ~/ 1000;
    final currentCounter = epochSeconds ~/ period;

    for (int i = -window; i <= window; i++) {
      final expected = _generateCodeForCounter(
        secret,
        currentCounter + i,
        digits: digits,
      );
      if (expected == cleanCode) {
        return true;
      }
    }
    return false;
  }

  static String _generateCodeForCounter(
    String secret,
    int counter, {
    int digits = 6,
  }) {
    final keyBytes = _decodeBase32(secret);
    if (keyBytes.isEmpty) return '';

    // Counter as 8-byte big-endian
    final counterBytes = Uint8List(8);
    for (int i = 7; i >= 0; i--) {
      counterBytes[i] = counter & 0xff;
      counter >>= 8;
    }

    // HMAC-SHA1
    final hmac = Hmac(sha1, keyBytes);
    final digest = hmac.convert(counterBytes).bytes;

    // Dynamic Truncation
    final offset = digest[digest.length - 1] & 0x0f;
    final binary = ((digest[offset] & 0x7f) << 24) |
        ((digest[offset + 1] & 0xff) << 16) |
        ((digest[offset + 2] & 0xff) << 8) |
        (digest[offset + 3] & 0xff);

    final mod = pow(10, digits).toInt();
    final otp = binary % mod;

    return otp.toString().padLeft(digits, '0');
  }

  /// Decodes RFC 4648 Base32 string into raw byte array.
  static Uint8List _decodeBase32(String input) {
    final cleaned = input.toUpperCase().replaceAll('=', '').replaceAll(' ', '');
    if (cleaned.isEmpty) return Uint8List(0);

    final List<int> output = [];
    int buffer = 0;
    int bitsLeft = 0;

    for (int i = 0; i < cleaned.length; i++) {
      final char = cleaned[i];
      final val = _base32Chars.indexOf(char);
      if (val < 0) continue; // skip invalid chars

      buffer = (buffer << 5) | val;
      bitsLeft += 5;

      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        output.add((buffer >> bitsLeft) & 0xff);
      }
    }

    return Uint8List.fromList(output);
  }
}
