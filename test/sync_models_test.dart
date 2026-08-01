import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/sync/sync_models.dart';

void main() {
  group('version vectors', () {
    test('distinguishes equal, descendant, and concurrent revisions', () {
      expect(
        compareVersionVectors({'phone': 1}, {'phone': 1}),
        VersionRelation.equal,
      );
      expect(
        compareVersionVectors({'phone': 2, 'desktop': 1}, {'phone': 1}),
        VersionRelation.localDescends,
      );
      expect(
        compareVersionVectors({'phone': 1}, {'phone': 2, 'desktop': 1}),
        VersionRelation.remoteDescends,
      );
      expect(
        compareVersionVectors({'phone': 2}, {'desktop': 2}),
        VersionRelation.concurrent,
      );
    });

    test('merges and encodes vectors deterministically', () {
      final merged = mergeVersionVectors(
        {'phone': 2, 'desktop': 1},
        {'phone': 1, 'tablet': 4},
      );
      expect(merged, {'phone': 2, 'desktop': 1, 'tablet': 4});
      expect(
        encodeVersionVector({'tablet': 4, 'desktop': 1, 'phone': 2}),
        '{"desktop":1,"phone":2,"tablet":4}',
      );
      expect(decodeVersionVector(encodeVersionVector(merged)), merged);
    });
  });

  test('wraps IPv6 peer addresses in WebSocket endpoints', () {
    const peer = SyncPeer(
      deviceId: 'desktop',
      name: 'Desktop',
      host: 'fe80::1234',
      port: 43123,
      pairingAvailable: true,
    );
    expect(peer.endpoint.toString(), 'ws://[fe80::1234]:43123/sync');
  });

  test('keeps every discovered address as a sync endpoint', () {
    const peer = SyncPeer(
      deviceId: 'desktop',
      name: 'Desktop',
      host: '192.168.1.8',
      alternativeHosts: ['2408:8221::8', 'desktop.local'],
      port: 43123,
      pairingAvailable: true,
    );

    expect(peer.endpoints.map((endpoint) => endpoint.toString()), [
      'ws://192.168.1.8:43123/sync',
      'ws://[2408:8221::8]:43123/sync',
      'ws://desktop.local:43123/sync',
    ]);
  });
}
