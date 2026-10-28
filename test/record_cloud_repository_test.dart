import 'dart:convert';

import 'package:carty_app/auth/account_gateway.dart';
import 'package:carty_app/cloud/cloud_workspace.dart';
import 'package:carty_app/cloud/supabase_gateway.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/data/stored_workspace.dart';
import 'package:carty_app/models/cart_item.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'cloud_test_support.dart';
import 'supabase_gateway_test.dart' show identify, testClient;

class _Server {
  _Server(String snapshot) {
    final data = WorkspaceRows.fromSnapshot(snapshot);
    metadata = jsonDecode(data.metadata) as Map<String, dynamic>;
    records = {
      for (final row in data.records)
        row.key: {
          ...row.toRow(),
          'data': jsonDecode(row.data),
          'revision': revision,
          'user_id': 'alice',
        },
    };
  }
  int revision = 3;
  late Map<String, dynamic> metadata;
  late Map<String, Map<String, dynamic>> records;
  int pages = 0;
  bool changeDuringPage = false;
  bool keepChanging = false;
  bool omitRow = false;
  bool rejectSave = false;
  final patches = <Map<String, dynamic>>[];
  Map<String, dynamic> get head => {
    'user_id': 'alice',
    'revision': revision,
    'protocol': 2,
    'metadata': metadata,
    'record_count': records.length,
  };
  Future<http.Response> handle(http.Request request) async {
    Object? result;
    if (request.url.path.endsWith('carty_bootstrap_records') ||
        request.url.path.endsWith('carty_cloud_heads')) {
      result = [head];
    } else if (request.url.path.endsWith('carty_cloud_records')) {
      pages++;
      final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
      final limit = int.parse(request.url.queryParameters['limit'] ?? '500');
      final sorted = records.values.toList()
        ..sort(
          (a, b) => jsonEncode([
            a['kind'],
            a['parent_id'],
            a['record_id'],
          ]).compareTo(jsonEncode([b['kind'], b['parent_id'], b['record_id']])),
        );
      result = sorted.skip(offset).take(limit).toList();
      if (omitRow && (result as List).isNotEmpty) {
        result = result.skip(1).toList();
      }
      if (changeDuringPage || keepChanging) {
        changeDuringPage = false;
        revision++;
      }
    } else if (request.url.path.endsWith('carty_save_record_delta')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      patches.add(body);
      if (rejectSave || body['p_expected_revision'] != revision) {
        result = [];
      } else {
        revision++;
        metadata = Map<String, dynamic>.from(body['p_metadata'] as Map);
        for (final row in body['p_deletes'] as List) {
          records.remove(
            jsonEncode([row['kind'], row['parent_id'], row['record_id']]),
          );
        }
        for (final row in body['p_upserts'] as List) {
          records[jsonEncode([
            row['kind'],
            row['parent_id'],
            row['record_id'],
          ])] = {
            ...Map<String, dynamic>.from(row as Map),
            'user_id': 'alice',
            'revision': revision,
          };
        }
        result = [head];
      }
    } else {
      throw StateError('Unexpected request: ${request.url}');
    }
    return http.Response(
      jsonEncode(result),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

String largeSnapshot() => jsonEncode({
  'version': 3,
  'activeListId': null,
  'budgetPence': 50000,
  'isPlanning': true,
  'savedLists': [],
  'history': [],
  'productPreferences': [],
  'items': [
    for (var i = 0; i < 1050; i++)
      CartItem(
        id: 'item-${i.toString().padLeft(4, '0')}',
        name: 'Product $i',
        unitPricePence: 150,
        quantity: 0,
      ).toJson(),
  ],
});

void main() {
  test('a large workspace downloads all pages and one item edit uploads only its row', () async {
    final snapshot = largeSnapshot();
    final server = _Server(snapshot);
    final client = testClient(server.handle);
    await identify(client, 'alice');
    final gateway = SupabaseGateway(client);
    final fetched = await gateway.fetch('alice');
    expect(fetched!.snapshot, canonicalSnapshot(snapshot));
    expect(server.pages, 3);
    final store = CartStore(
      storage: InMemoryCartStorage()..value = fetched.snapshot,
    );
    addTearDown(store.dispose);
    await store.load();
    await store.incrementQuantity(store.items[17].id);
    final result = await gateway.save(
      'alice',
      fetched.revision,
      store.exportSnapshot(),
    );
    expect(result!.revision, 4);
    final patch = server.patches.single;
    expect(patch['p_upserts'], hasLength(1));
    expect((patch['p_upserts'] as List).single['record_id'], 'item-0017');
    expect(patch['p_deletes'], isEmpty);
    expect(jsonEncode(patch).length, lessThan(2000));
    expect(
      server.records.values.where((row) => row['revision'] == 4),
      hasLength(1),
    );
    expect(
      (await gateway.fetch('alice'))!.snapshot,
      canonicalSnapshot(store.exportSnapshot()),
    );
  });

  test(
    'record removals and metadata changes upload without rewriting other rows',
    () async {
      final snapshot = await exampleSnapshot('Milk');
      final server = _Server(snapshot);
      final client = testClient(server.handle);
      await identify(client, 'alice');
      final gateway = SupabaseGateway(client);
      final fetched = await gateway.fetch('alice');
      final value = jsonDecode(fetched!.snapshot) as Map;
      value['activeListId'] = null;
      value['items'] = [];
      value['budgetPence'] = 8000;
      await gateway.save('alice', fetched.revision, jsonEncode(value));
      expect(server.patches.single['p_deletes'], hasLength(1));
      expect(server.patches.single['p_upserts'], isEmpty);
      expect(
        (await gateway.fetch('alice'))!.snapshot,
        canonicalSnapshot(jsonEncode(value)),
      );
    },
  );

  test(
    'downloads restart when their head changes and never publish mixed pages',
    () async {
      final snapshot = largeSnapshot();
      final server = _Server(snapshot)..changeDuringPage = true;
      final client = testClient(server.handle);
      await identify(client, 'alice');
      final fetched = await SupabaseGateway(client).fetch('alice');
      expect(fetched!.revision, 4);
      expect(fetched.snapshot, canonicalSnapshot(snapshot));
      expect(server.pages, 6);
    },
  );

  test('repeated concurrent changes and incomplete downloads preserve the caller’s copy', () async {
    final server = _Server(largeSnapshot())..keepChanging = true;
    final client = testClient(server.handle);
    await identify(client, 'alice');
    final gateway = SupabaseGateway(client);
    await expectLater(gateway.fetch('alice'), throwsA(isA<AccountProblem>()));
    expect(server.pages, 9);
    server.keepChanging = false;
    server.omitRow = true;
    await expectLater(gateway.fetch('alice'), throwsFormatException);
  });

  test(
    'a restarted client reloads its base and cannot overwrite a newer revision',
    () async {
      final snapshot = await exampleSnapshot('Milk');
      final server = _Server(snapshot);
      final client = testClient(server.handle);
      await identify(client, 'alice');
      final gateway = SupabaseGateway(client);
      expect(await gateway.save('alice', 2, snapshot), isNull);
      expect(server.patches, isEmpty);
      server.rejectSave = true;
      expect(await gateway.save('alice', 3, snapshot), isNull);
      expect(server.revision, 3);
    },
  );
}
