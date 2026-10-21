import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_fetcher.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_parser_service.dart';

import '../../../client_identity/fakes.dart';

void main() {
  const vlessLink =
      'vless://11111111-1111-1111-1111-111111111111@example.com:443#One';
  const trojanLink = 'trojan://secret@example.com:8443#Two';

  Future<SubscriptionParserService> serviceOn(http.Client client) async {
    final identity = await identityRepositoryWith(FakeDeviceInfoApi());
    return SubscriptionParserService(
      Talker(),
      SubscriptionFetcher(identity, client: client),
    );
  }

  Future<SubscriptionParserService> serviceServing(String body) =>
      serviceOn(MockClient((_) async => http.Response(body, 200)));

  // For input that never reaches the network.
  Future<SubscriptionParserService> offlineService() => serviceOn(
    MockClient((_) async => throw StateError('unexpected request')),
  );

  group('SubscriptionParserService.parseFromInput', () {
    test('parses a pasted direct link', () async {
      final service = await offlineService();

      final result = await service.parseFromInput(vlessLink);

      expect(result, isA<Success<ParsedSubscription>>());
      expect(
        (result as Success<ParsedSubscription>).data.servers,
        hasLength(1),
      );
    });

    test('parses a pasted base64 block', () async {
      final encoded = base64.encode(utf8.encode('$vlessLink\n$trojanLink'));

      final service = await offlineService();

      final result = await service.parseFromInput(encoded);

      expect(
        (result as Success<ParsedSubscription>).data.servers,
        hasLength(2),
      );
    });

    test('rejects input that is neither a link, JSON nor base64', () async {
      final service = await offlineService();

      final result = await service.parseFromInput('what is this?!');

      expect(result, isA<Failure<ParsedSubscription>>());
    });

    test('parses a fetched base64 body', () async {
      final body = base64.encode(utf8.encode('$vlessLink\n$trojanLink'));
      final service = await serviceServing(body);

      final result = await service.parseFromInput('https://sub.example.com');

      expect(
        (result as Success<ParsedSubscription>).data.servers,
        hasLength(2),
      );
    });

    test('parses a fetched plain text body that is not base64', () async {
      final service = await serviceServing(
        '# my nodes\n$vlessLink\n$trojanLink\n',
      );

      final result = await service.parseFromInput('https://sub.example.com');

      expect(
        (result as Success<ParsedSubscription>).data.servers,
        hasLength(2),
      );
    });

    test('keeps the servers of every supported scheme in one body', () async {
      final service = await serviceServing(
        '$vlessLink\nssr://legacy-unsupported\n$trojanLink',
      );

      final result = await service.parseFromInput('https://sub.example.com');

      expect(
        (result as Success<ParsedSubscription>).data.servers,
        hasLength(2),
      );
    });

    test('keeps the servers in the order of the subscription lines', () async {
      final service = await serviceServing('$trojanLink\n$vlessLink');

      final result = await service.parseFromInput('https://sub.example.com');

      final servers = (result as Success<ParsedSubscription>).data.servers;
      expect(servers.map((s) => s.title), equals(['Two', 'One']));
    });

    test('numbers the ids by line, across different schemes', () async {
      final service = await serviceServing('$trojanLink\n$vlessLink');

      final result = await service.parseFromInput('https://sub.example.com');

      final servers = (result as Success<ParsedSubscription>).data.servers;
      expect(servers.first.id, endsWith(':#0'));
      expect(servers.last.id, endsWith(':#1'));
    });

    test('fails when the body has no supported server', () async {
      final service = await serviceServing(
        '# nothing here\ntuic://a@b.com:443',
      );

      final result = await service.parseFromInput('https://sub.example.com');

      expect(result, isA<Failure<ParsedSubscription>>());
    });

    test('carries subscription metadata from the response headers', () async {
      final client = MockClient(
        (_) async => http.Response(
          vlessLink,
          200,
          headers: {
            'profile-title': 'My Nodes',
            'profile-update-interval': '12',
            'subscription-userinfo': 'upload=1; download=2; total=100',
          },
        ),
      );
      final service = await serviceOn(client);

      final result = await service.parseFromInput('https://sub.example.com');

      final parsed = (result as Success<ParsedSubscription>).data;
      expect(parsed.suggestedName, equals('My Nodes'));
      expect(parsed.updateIntervalHours, equals(12));
      expect(parsed.usedBytes, equals(3));
      expect(parsed.dataLimitBytes, equals(100));
    });

    test('shows the device limit message to the user', () async {
      final client = MockClient(
        (_) async => http.Response(
          '',
          403,
          headers: {'x-hwid-max-devices-reached': 'true'},
        ),
      );
      final service = await serviceOn(client);

      final result = await service.parseFromInput('https://sub.example.com');

      expect(
        (result as Failure<ParsedSubscription>).message,
        contains('device limit'),
      );
    });

    test('fails instead of throwing when the fetch fails', () async {
      final client = MockClient((_) async => http.Response('nope', 500));
      final service = await serviceOn(client);

      final result = await service.parseFromInput('https://sub.example.com');

      expect(result, isA<Failure<ParsedSubscription>>());
    });
  });
}
