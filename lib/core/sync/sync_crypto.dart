import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class SyncEphemeralKeyPair {
  const SyncEphemeralKeyPair({required this.keyPair, required this.publicKey});

  final SimpleKeyPair keyPair;
  final List<int> publicKey;
}

class SyncCrypto {
  SyncCrypto({X25519? x25519, Hmac? hmac, Hkdf? hkdf, Sha256? sha256})
    : _x25519 = x25519 ?? X25519(),
      _hmac = hmac ?? Hmac.sha256(),
      _hkdf = hkdf ?? Hkdf(hmac: Hmac.sha256(), outputLength: 32),
      _sha256 = sha256 ?? Sha256();

  final X25519 _x25519;
  final Hmac _hmac;
  final Hkdf _hkdf;
  final Sha256 _sha256;

  Future<SyncEphemeralKeyPair> newEphemeralKeyPair() async {
    final keyPair = await _x25519.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    return SyncEphemeralKeyPair(keyPair: keyPair, publicKey: publicKey.bytes);
  }

  Future<List<int>> derivePairingKey({
    required SimpleKeyPair keyPair,
    required List<int> remotePublicKey,
    required String pairingCode,
    required List<int> nonce,
  }) async {
    final shared = await _x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: SimplePublicKey(
        remotePublicKey,
        type: KeyPairType.x25519,
      ),
    );
    final codeHash = await _sha256.hash(utf8.encode(pairingCode));
    final salt = await _hmac.calculateMac(
      nonce,
      secretKey: SecretKey(codeHash.bytes),
    );
    return (await _hkdf.deriveKey(
      secretKey: shared,
      nonce: salt.bytes,
      info: utf8.encode('shadowdiary-pair-v1'),
    )).bytes;
  }

  Future<List<int>> deriveSessionKey({
    required List<int> sharedSecret,
    required List<int> nonce,
  }) async {
    return (await _hkdf.deriveKey(
      secretKey: SecretKey(sharedSecret),
      nonce: nonce,
      info: utf8.encode('shadowdiary-sync-v1'),
    )).bytes;
  }

  Future<String> proof({required List<int> key, required String value}) async {
    final mac = await _hmac.calculateMac(
      utf8.encode(value),
      secretKey: SecretKey(key),
    );
    return base64Encode(mac.bytes);
  }

  Future<bool> verifyProof({
    required List<int> key,
    required String value,
    required String encodedProof,
  }) async {
    List<int> received;
    try {
      received = base64Decode(encodedProof);
    } on FormatException {
      return false;
    }
    final expected = await _hmac.calculateMac(
      utf8.encode(value),
      secretKey: SecretKey(key),
    );
    return expected == Mac(received);
  }
}

class SyncSessionCipher {
  SyncSessionCipher(List<int> key)
    : _secretKey = SecretKey(key),
      _cipher = AesGcm.with256bits();

  final SecretKey _secretKey;
  final AesGcm _cipher;
  int _outgoingSequence = 0;
  int _incomingSequence = 0;

  Future<String> encrypt(Map<String, Object?> message) async {
    final sequence = ++_outgoingSequence;
    final aad = utf8.encode('shadowdiary-sync-v1:$sequence');
    final secretBox = await _cipher.encrypt(
      utf8.encode(jsonEncode(message)),
      secretKey: _secretKey,
      aad: aad,
    );
    return jsonEncode({
      'kind': 'encrypted',
      'sequence': sequence,
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'tag': base64Encode(secretBox.mac.bytes),
    });
  }

  Future<Map<String, Object?>> decrypt(Object? rawMessage) async {
    if (rawMessage is! String || rawMessage.length > 48 * 1024 * 1024) {
      throw const FormatException('Invalid encrypted sync frame.');
    }
    final decoded = jsonDecode(rawMessage);
    if (decoded is! Map || decoded['kind'] != 'encrypted') {
      throw const FormatException('Expected an encrypted sync frame.');
    }
    final sequence = (decoded['sequence'] as num?)?.toInt();
    if (sequence == null || sequence != _incomingSequence + 1) {
      throw const FormatException('Invalid or replayed sync frame.');
    }
    final nonce = base64Decode(decoded['nonce']! as String);
    final ciphertext = base64Decode(decoded['ciphertext']! as String);
    final tag = base64Decode(decoded['tag']! as String);
    if (nonce.length != 12 || tag.length != 16) {
      throw const FormatException('Invalid encrypted sync frame lengths.');
    }
    final clearText = await _cipher.decrypt(
      SecretBox(ciphertext, nonce: nonce, mac: Mac(tag)),
      secretKey: _secretKey,
      aad: utf8.encode('shadowdiary-sync-v1:$sequence'),
    );
    final message = jsonDecode(utf8.decode(clearText));
    if (message is! Map) {
      throw const FormatException('Invalid sync message payload.');
    }
    _incomingSequence = sequence;
    return message.map((key, value) => MapEntry(key.toString(), value));
  }
}
