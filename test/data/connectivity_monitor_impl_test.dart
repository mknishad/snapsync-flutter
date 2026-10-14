import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snapsync/data/connectivity/connectivity_monitor_impl.dart';
import 'package:snapsync/domain/entities/link_quality.dart';
import 'package:snapsync/domain/entities/probe_result.dart';

import '../support/fakes.dart';

class MockConnectivity extends Mock implements Connectivity {}

void main() {
  const debounce = Duration(seconds: 3);
  const maxLatency = Duration(seconds: 2);
  const stableRecheck = Duration(seconds: 15);
  const unstableRecheck = Duration(seconds: 5);

  late MockConnectivity connectivity;
  late StreamController<List<ConnectivityResult>> changes;
  late FakeReachabilityProbe probe;
  late FakeTimerFactory timers;
  late ConnectivityMonitorImpl monitor;
  late List<ConnectivityResult> initial;
  late List<LinkQuality> seen;
  StreamSubscription<LinkQuality>? subscription;

  const wifi = [ConnectivityResult.wifi];
  const none = [ConnectivityResult.none];

  /// Lets queued microtasks and the initial connectivity read settle.
  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void listen() {
    subscription = monitor.onLinkQualityChanged.listen(seen.add);
  }

  void connectivityChanges(List<ConnectivityResult> results) =>
      changes.add(results);

  setUp(() {
    connectivity = MockConnectivity();
    changes = StreamController<List<ConnectivityResult>>.broadcast();
    probe = FakeReachabilityProbe();
    timers = FakeTimerFactory();
    initial = wifi;
    seen = [];
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => changes.stream);
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => initial);
    monitor = ConnectivityMonitorImpl(
      connectivity: connectivity,
      probe: probe,
      stableDebounce: debounce,
      probeTimeout: const Duration(milliseconds: 50),
      probeMaxLatency: maxLatency,
      linkRecheckInterval: stableRecheck,
      unstableRecheckInterval: unstableRecheck,
      timerFactory: timers.create,
    );
  });

  tearDown(() async {
    await subscription?.cancel();
    await changes.close();
  });

  group('onLinkQualityChanged', () {
    test('a link that has just come up is unstable until verified', () async {
      listen();
      await settle();

      expect(seen, [LinkQuality.unstable]);
      expect(timers.active.single.duration, debounce);
      expect(probe.probeCount, 0, reason: 'no probe before the debounce ends');
    });

    test(
      'becomes stable only after the debounce AND a successful probe',
      () async {
        listen();
        await settle();

        timers.last.fire();
        await settle();

        expect(probe.probeCount, 1);
        expect(seen, [LinkQuality.unstable, LinkQuality.stable]);
      },
    );

    test('a failed probe leaves the link unstable and is retried', () async {
      probe.defaultResult = const ProbeResult.unreachable();
      listen();
      await settle();

      timers.last.fire();
      await settle();
      expect(seen, [LinkQuality.unstable]);
      expect(timers.active.single.duration, unstableRecheck);

      probe.defaultResult = const ProbeResult.reachable(
        Duration(milliseconds: 40),
      );
      timers.last.fire();
      await settle();

      expect(seen, [LinkQuality.unstable, LinkQuality.stable]);
    });

    test('a slow probe is not stable', () async {
      probe.defaultResult = const ProbeResult.reachable(Duration(seconds: 3));
      listen();
      await settle();

      timers.last.fire();
      await settle();

      expect(seen, [LinkQuality.unstable]);
    });

    test('a probe that never answers times out and is not stable', () async {
      probe.script.add(() => Completer<ProbeResult>().future);
      listen();
      await settle();

      timers.last.fire();
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(seen, [LinkQuality.unstable]);
      expect(timers.active.single.duration, unstableRecheck);
    });

    test(
      'a stable link is re-checked and drops to unstable when the probe fails',
      () async {
        listen();
        await settle();
        timers.last.fire();
        await settle();
        expect(seen.last, LinkQuality.stable);
        expect(timers.active.single.duration, stableRecheck);

        probe.defaultResult = const ProbeResult.unreachable();
        timers.last.fire();
        await settle();

        expect(seen, [
          LinkQuality.unstable,
          LinkQuality.stable,
          LinkQuality.unstable,
        ]);
      },
    );
  });

  group('offline and flapping', () {
    test('no connection starts offline', () async {
      initial = none;
      listen();
      await settle();

      expect(seen, [LinkQuality.offline]);
      expect(timers.timers, isEmpty);
    });

    test(
      'going offline is emitted immediately and cancels pending checks',
      () async {
        listen();
        await settle();
        final debounceTimer = timers.last;

        connectivityChanges(none);
        await settle();

        expect(seen, [LinkQuality.unstable, LinkQuality.offline]);
        expect(debounceTimer.isActive, isFalse);
        expect(timers.active, isEmpty);
      },
    );

    test('flapping restarts the debounce from zero', () async {
      listen();
      await settle();
      final first = timers.last;

      connectivityChanges(none);
      await settle();
      connectivityChanges(wifi);
      await settle();
      final second = timers.last;

      expect(second, isNot(same(first)));
      first.fire(); // cancelled, must do nothing
      await settle();
      expect(probe.probeCount, 0);
      expect(seen.last, LinkQuality.unstable);

      second.fire();
      await settle();
      expect(seen.last, LinkQuality.stable);
      expect(seen, [
        LinkQuality.unstable,
        LinkQuality.offline,
        LinkQuality.unstable,
        LinkQuality.stable,
      ]);
    });

    test(
      'a probe in flight when the link drops cannot make it stable',
      () async {
        final probeAnswer = Completer<ProbeResult>();
        probe.script.add(() => probeAnswer.future);
        listen();
        await settle();
        timers.last.fire(); // probe now in flight
        await settle();

        connectivityChanges(none);
        await settle();
        probeAnswer.complete(
          const ProbeResult.reachable(Duration(milliseconds: 10)),
        );
        await settle();

        expect(seen, [LinkQuality.unstable, LinkQuality.offline]);
        expect(timers.active, isEmpty, reason: 'no re-check scheduled either');
      },
    );

    test('switching networks (wifi to mobile) is verified again', () async {
      listen();
      await settle();
      timers.last.fire();
      await settle();
      expect(seen.last, LinkQuality.stable);

      connectivityChanges(const [ConnectivityResult.mobile]);
      await settle();

      expect(seen.last, LinkQuality.unstable);
      timers.last.fire();
      await settle();
      expect(seen.last, LinkQuality.stable);
    });

    test('bluetooth alone is not a usable network', () async {
      initial = const [ConnectivityResult.bluetooth];
      listen();
      await settle();

      expect(seen, [LinkQuality.offline]);
    });

    test('several active interfaces count as connected', () async {
      initial = const [ConnectivityResult.wifi, ConnectivityResult.vpn];
      listen();
      await settle();

      expect(seen, [LinkQuality.unstable]);
    });
  });

  group('listeners', () {
    test('a late listener receives the current value', () async {
      listen();
      await settle();
      timers.last.fire();
      await settle();

      final late = <LinkQuality>[];
      final sub = monitor.onLinkQualityChanged.listen(late.add);
      addTearDown(sub.cancel);
      await settle();

      expect(late, [LinkQuality.stable]);
    });

    test('monitoring stops, and timers are cancelled, when the last listener leaves', () async {
      listen();
      await settle();
      expect(changes.hasListener, isTrue);

      await subscription!.cancel();
      subscription = null;
      await settle();

      expect(changes.hasListener, isFalse);
      expect(timers.active, isEmpty);
    });

    test('monitoring restarts cleanly for a new listener', () async {
      listen();
      await settle();
      await subscription!.cancel();
      await settle();
      seen.clear();

      listen();
      await settle();

      expect(seen, [LinkQuality.unstable]);
    });

    test('equal consecutive values are not repeated', () async {
      listen();
      await settle();
      connectivityChanges(const [
        ConnectivityResult.wifi,
        ConnectivityResult.vpn,
      ]);
      await settle();

      expect(seen, [LinkQuality.unstable]);
    });
  });

  group('checkNow', () {
    test('offline when no interface is up, without probing', () async {
      initial = none;

      expect(await monitor.checkNow(), LinkQuality.offline);
      expect(probe.probeCount, 0);
    });

    test('stable when the probe is fast, with no debounce', () async {
      expect(await monitor.checkNow(), LinkQuality.stable);
      expect(probe.probeCount, 1);
      expect(timers.timers, isEmpty);
    });

    test('unstable when the probe fails or is slow', () async {
      probe.defaultResult = const ProbeResult.unreachable();
      expect(await monitor.checkNow(), LinkQuality.unstable);

      probe.defaultResult = const ProbeResult.reachable(Duration(seconds: 5));
      expect(await monitor.checkNow(), LinkQuality.unstable);
    });

    test('does not start monitoring or touch listeners', () async {
      await monitor.checkNow();

      expect(changes.hasListener, isFalse);
    });
  });
}
