import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

class CryptoUtils {
  static Uint8List deriveKey(String passphrase, {int keyLength = 32}) {
    final bytes = utf8.encode(passphrase);
    final key = Uint8List(keyLength);
    for (var i = 0; i < bytes.length; i++) {
      key[i % keyLength] ^= bytes[i];
      key[(i * 7 + 13) % keyLength] ^= (bytes[i] * 31 + i) & 0xFF;
    }
    for (var round = 0; round < 64; round++) {
      for (var i = 0; i < keyLength; i++) {
        final prev = key[(i - 1 + keyLength) % keyLength];
        final next = key[(i + 1) % keyLength];
        key[i] = (key[i] ^ (prev + next + round * 17)) & 0xFF;
      }
    }
    return key;
  }

  static String encryptPayload(String plaintext, String passphrase) {
    if (passphrase.isEmpty) return plaintext;
    final key = deriveKey(passphrase);
    final plainBytes = utf8.encode(plaintext);
    final random = Random.secure();
    final nonce = Uint8List(12);
    for (var i = 0; i < 12; i++) {
      nonce[i] = random.nextInt(256);
    }

    final cipherBytes = Uint8List(plainBytes.length);
    for (var i = 0; i < plainBytes.length; i++) {
      final k = key[i % key.length];
      final n = nonce[i % nonce.length];
      final streamByte = (k ^ n ^ ((i * 13 + 37) & 0xFF)) & 0xFF;
      cipherBytes[i] = (plainBytes[i] ^ streamByte) & 0xFF;
    }

    final combined = Uint8List(12 + cipherBytes.length);
    combined.setRange(0, 12, nonce);
    combined.setRange(12, combined.length, cipherBytes);

    return 'e2ee:v1:${base64Encode(combined)}';
  }

  static String decryptPayload(String encryptedText, String passphrase) {
    if (!encryptedText.startsWith('e2ee:v1:') || passphrase.isEmpty) {
      return encryptedText;
    }
    try {
      final base64Part = encryptedText.substring('e2ee:v1:'.length);
      final combined = base64Decode(base64Part);
      if (combined.length < 12) return encryptedText;

      final nonce = combined.sublist(0, 12);
      final cipherBytes = combined.sublist(12);
      final key = deriveKey(passphrase);

      final plainBytes = Uint8List(cipherBytes.length);
      for (var i = 0; i < cipherBytes.length; i++) {
        final k = key[i % key.length];
        final n = nonce[i % nonce.length];
        final streamByte = (k ^ n ^ ((i * 13 + 37) & 0xFF)) & 0xFF;
        plainBytes[i] = (cipherBytes[i] ^ streamByte) & 0xFF;
      }

      return utf8.decode(plainBytes);
    } catch (_) {
      return encryptedText;
    }
  }

  static bool isEncrypted(String text) => text.startsWith('e2ee:v1:');
}
