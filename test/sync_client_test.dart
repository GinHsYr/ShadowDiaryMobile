import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/sync/sync_client.dart';

void main() {
  test('falls back after a discovered endpoint cannot be reached', () async {
    final ipv4 = Uri.parse('ws://192.168.1.8:43123/sync');
    final ipv6 = Uri.parse('ws://[2408:8221::8]:43123/sync');
    final attempts = <Uri>[];

    final connected = await connectFirstAvailableSyncEndpoint([ipv4, ipv6], (
      endpoint,
    ) async {
      attempts.add(endpoint);
      if (endpoint == ipv4) {
        throw const SocketException('No route to host');
      }
      return endpoint;
    });

    expect(attempts, [ipv4, ipv6]);
    expect(connected, ipv6);
  });
}
