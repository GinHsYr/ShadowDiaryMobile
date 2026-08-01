import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/sync/lan_discovery_service.dart';

void main() {
  test('preserves routable mDNS addresses for connection fallback', () {
    expect(
      syncHostsFromService(const [
        '127.0.0.1',
        '192.168.1.8',
        '2408:8221:4f12:b780::8',
        'fe80::8%wlan0',
        '192.168.1.8',
      ], 'desktop.local'),
      const [
        '192.168.1.8',
        '2408:8221:4f12:b780::8',
        'fe80::8%wlan0',
        'desktop.local',
      ],
    );
  });

  test('falls back to the resolved mDNS hostname', () {
    expect(
      syncHostsFromService(const ['127.0.0.1', '::1'], 'desktop.local.'),
      const ['desktop.local.'],
    );
  });
}
