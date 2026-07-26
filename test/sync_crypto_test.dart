import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/sync/sync_crypto.dart';

void main() {
  test('encrypted frames round-trip and reject replay', () async {
    final sender = SyncSessionCipher(List<int>.generate(32, (index) => index));
    final receiver = SyncSessionCipher(
      List<int>.generate(32, (index) => index),
    );
    final frame = await sender.encrypt({
      'kind': 'syncSnapshot',
      'title': '一次安静的同步',
    });

    expect(await receiver.decrypt(frame), {
      'kind': 'syncSnapshot',
      'title': '一次安静的同步',
    });
    await expectLater(receiver.decrypt(frame), throwsFormatException);
  });

  test('encrypted frames reject modified authentication tags', () async {
    final key = List<int>.filled(32, 7);
    final sender = SyncSessionCipher(key);
    final receiver = SyncSessionCipher(key);
    final decoded =
        jsonDecode(await sender.encrypt({'kind': 'syncComplete'}))
            as Map<String, dynamic>;
    final tag = base64Decode(decoded['tag'] as String);
    tag[0] ^= 0xff;
    decoded['tag'] = base64Encode(tag);

    await expectLater(receiver.decrypt(jsonEncode(decoded)), throwsA(anything));
  });

  test('paired session proofs are bound to their transcript', () async {
    final crypto = SyncCrypto();
    final key = List<int>.generate(32, (index) => 31 - index);
    final proof = await crypto.proof(key: key, value: 'client|nonce|peer');
    expect(
      await crypto.verifyProof(
        key: key,
        value: 'client|nonce|peer',
        encodedProof: proof,
      ),
      isTrue,
    );
    expect(
      await crypto.verifyProof(
        key: key,
        value: 'client|other-nonce|peer',
        encodedProof: proof,
      ),
      isFalse,
    );
  });
}
