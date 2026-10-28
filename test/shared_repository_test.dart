import 'dart:async';
import 'dart:convert';

import 'package:carty_app/auth/account_gateway.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/models/cart_item.dart';
import 'package:carty_app/sharing/shared_list.dart';
import 'package:carty_app/sharing/shared_repository.dart';
import 'package:carty_app/sharing/supabase_shared_repository.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'supabase_gateway_test.dart' show identify, testClient;

SharedContent content({int count = 1}) => SharedContent(
  name: 'Weekly shop',
  budgetPence: 8000,
  isPlanning: true,
  items: List.generate(
    count,
    (i) => CartItem(
      id: 'item-$i',
      name: 'Milk $i',
      unitPricePence: 150,
      quantity: 1,
      plannedQuantity: 3,
      estimatedUnitPricePence: 140,
      priceConfirmed: true,
    ),
  ),
);

http.Response response(Object? value, {int status = 200, int? count}) =>
    http.Response(
      jsonEncode(value),
      status,
      headers: {
        'content-type': 'application/json',
        if (count != null)
          'content-range': '0-${count == 0 ? 0 : count - 1}/$count',
      },
    );

class _Household {
  _Household({int count = 1}) : products = content(count: count).items;
  final List<CartItem> products;
  int revision = 1, pages = 0;
  String owner = 'alice';
  String? role = 'editor';
  bool revoked = false, changeOnce = false, changeAlways = false;
  bool downgradeOnce = false, revokeDuringPage = false, omitLast = false;
  bool foreignItem = false, futureRow = false;
  Map<String, Object?> get header => {
    'id': 'list-1',
    'owner_id': owner,
    'name': 'Weekly shop',
    'budget_pence': 8000,
    'is_planning': true,
    'currency': 'GBP',
    'revision': revision,
    'updated_at': '2026-10-28T10:00:00Z',
  };
  Future<http.Response> handle(http.Request request) async {
    final url = request.url;
    if (url.path.endsWith('carty_shared_lists')) {
      if (url.queryParameters['select'] == 'id') {
        return response([
          {'id': 'list-1'},
        ]);
      }
      return response(revoked ? [] : [header]);
    }
    if (url.path.endsWith('carty_shared_members')) {
      return response(
        role == null || revoked
            ? []
            : [
                {'list_id': 'list-1', 'user_id': 'bob', 'role': role},
              ],
      );
    }
    if (url.path.endsWith('carty_shared_items')) {
      pages++;
      expect(request.headers['prefer'], contains('count=exact'));
      final offset = int.parse(url.queryParameters['offset'] ?? '0');
      final limit = int.parse(url.queryParameters['limit'] ?? '500');
      final rows = [
        for (var i = offset; i < products.length && i < offset + limit; i++)
          if (!omitLast || i != products.length - 1)
            {
              'list_id': foreignItem ? 'foreign' : 'list-1',
              'item_id': products[i].id,
              'position': i,
              'revision': futureRow ? revision + 1 : revision,
              'data': products[i].toJson(),
            },
      ];
      if (changeOnce || changeAlways) {
        changeOnce = false;
        revision++;
      }
      if (downgradeOnce) {
        downgradeOnce = false;
        role = 'viewer';
      }
      if (revokeDuringPage) revoked = true;
      return response(rows, count: products.length);
    }
    throw StateError('Unexpected request $url');
  }
}

void main() {
  test(
    'invitation inbox is email scoped and roster rows remain list scoped',
    () async {
      var foreign = false;
      final client = testClient((request) async {
        if (request.url.path.endsWith('carty_shared_members')) {
          expect(request.url.queryParameters['list_id'], 'eq.list-1');
          return response([
            {
              'list_id': foreign ? 'other' : 'list-1',
              'user_id': 'bob',
              'role': 'viewer',
            },
          ]);
        }
        expect(
          request.url.queryParameters['recipient_email'],
          'eq.bob@example.com',
        );
        expect(request.url.queryParameters['accepted_at'], 'is.null');
        expect(request.url.queryParameters['revoked_at'], 'is.null');
        return response([
          {
            'id': 'invite-1',
            'list_id': 'list-1',
            'list_name': 'Weekly shop',
            'inviter_name': 'Alice',
            'recipient_email': foreign ? 'eve@example.com' : 'bob@example.com',
            'role': 'viewer',
            'created_at': '2026-10-28T10:00:00Z',
            'expires_at': '2026-11-04T10:00:00Z',
            'accepted_at': null,
            'accepted_by': null,
            'revoked_at': null,
            'delivery_status': 'in_app',
          },
        ]);
      });
      await identify(client, 'bob');
      final session = client.auth.currentSession!.toJson();
      session['user'] = {
        ...client.auth.currentUser!.toJson(),
        'email': 'BOB@example.com',
      };
      await client.auth.setInitialSession(jsonEncode(session));
      final repo = SupabaseSharedRepository(client, accountId: 'bob');
      final invitation = (await repo.invitations()).single;
      expect(invitation.isPending(DateTime.utc(2026, 10, 29)), true);
      expect(invitation.isPending(DateTime.utc(2026, 11, 4, 10)), false);
      expect((await repo.members('list-1')).single.role, SharedRole.viewer);
      foreign = true;
      await expectLater(repo.invitations(), throwsFormatException);
      await expectLater(repo.members('list-1'), throwsFormatException);
    },
  );

  test(
    'malformed acknowledgements cannot mark an edit or action as saved',
    () async {
      Object? payload = {'listId': 'other-list', 'revision': 2};
      final client = testClient((_) async => response(payload));
      await identify(client, 'alice');
      final repo = SupabaseSharedRepository(client, accountId: 'alice');
      await expectLater(
        repo.save('list-1', 1, content()),
        throwsFormatException,
      );
      payload = {'listId': 'list-1', 'revision': 9};
      await expectLater(
        repo.save('list-1', 1, content()),
        throwsFormatException,
      );
      payload = {'ok': false};
      await expectLater(repo.leave('list-1'), throwsFormatException);
      payload = {'invitationId': 'invite-1', 'deliveryStatus': 'unknown'};
      await expectLater(
        repo.invite('list-1', 'bob@example.com', SharedRole.viewer),
        throwsFormatException,
      );
    },
  );

  test(
    'shared content retains plans and creates an isolated basket snapshot',
    () async {
      final data = content();
      final storage = InMemoryCartStorage()..value = data.toBasketSnapshot();
      final store = CartStore(storage: storage);
      addTearDown(store.dispose);
      await store.load();
      expect(store.needsStorageReset, false);
      expect(store.items.single.plannedQuantity, 3);
      expect(store.items.single.estimatedUnitPricePence, 140);
      expect(store.items.single.quantity, 1);
      expect(store.items.single.priceConfirmed, true);
      expect(store.savedLists, isEmpty);
      expect(store.history, isEmpty);
      expect(() => data.items.clear(), throwsUnsupportedError);
      expect(
        () => SharedContent(
          name: 'x',
          budgetPence: null,
          isPlanning: true,
          items: [data.items.single, data.items.single],
        ),
        throwsFormatException,
      );
      expect(() => content(count: 1001), throwsFormatException);
      expect(() => SharedRole.member('owner'), throwsFormatException);
    },
  );

  test(
    'owner download pages all products with their estimates and ordering',
    () async {
      final server = _Household(count: 1000);
      final client = testClient(server.handle);
      await identify(client, 'alice');
      final repo = SupabaseSharedRepository(client, accountId: 'alice');
      final document = (await repo.fetch('list-1'))!;
      expect(server.pages, 3);
      expect(document.header.role, SharedRole.owner);
      expect(document.content.items, hasLength(1000));
      expect(document.content.items.last.id, 'item-999');
      expect(document.content.items.last.estimatedUnitPricePence, 140);
      expect((await repo.lists()).single.id, 'list-1');
    },
  );

  test('download retries concurrent edits and role downgrades without a revision change', () async {
    final server = _Household()..changeOnce = true;
    final client = testClient(server.handle);
    await identify(client, 'bob');
    final repo = SupabaseSharedRepository(client, accountId: 'bob');
    final first = (await repo.fetch('list-1'))!;
    expect(first.header.revision, 2);
    expect(first.header.role, SharedRole.editor);
    expect(server.pages, 2);
    server.downgradeOnce = true;
    final next = (await repo.fetch('list-1'))!;
    expect(next.header.revision, 2);
    expect(next.header.role, SharedRole.viewer);
    expect(next.header.role.canEdit, false);
    expect(server.pages, 4);
  });

  test(
    'revocation during download never publishes previously downloaded products',
    () async {
      final server = _Household()..revokeDuringPage = true;
      final client = testClient(server.handle);
      await identify(client, 'bob');
      expect(
        await SupabaseSharedRepository(
          client,
          accountId: 'bob',
        ).fetch('list-1'),
        isNull,
      );
    },
  );

  test('partial, foreign, future-version and repeatedly changing downloads fail safely', () async {
    final server = _Household(count: 501)..omitLast = true;
    final client = testClient(server.handle);
    await identify(client, 'alice');
    final repo = SupabaseSharedRepository(client, accountId: 'alice');
    await expectLater(repo.fetch('list-1'), throwsFormatException);
    server.omitLast = false;
    server.foreignItem = true;
    await expectLater(repo.fetch('list-1'), throwsFormatException);
    server.foreignItem = false;
    server.futureRow = true;
    await expectLater(repo.fetch('list-1'), throwsFormatException);
    server.futureRow = false;
    server.changeAlways = true;
    await expectLater(repo.fetch('list-1'), throwsA(isA<AccountProblem>()));
  });

  test('create and CAS saves acknowledge only the submitted basket', () async {
    final calls = <Map<String, dynamic>>[];
    var conflict = false;
    final client = testClient((request) async {
      expect(request.url.path, '/rest/v1/rpc/carty_shared_action');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      calls.add(body);
      final args = body['p_args'] as Map;
      return response(
        conflict
            ? {'conflict': true}
            : {
                'listId': 'list-1',
                'revision': body['p_action'] == 'create'
                    ? 1
                    : (args['expectedRevision'] as int) + 1,
              },
      );
    });
    await identify(client, 'alice');
    final repo = SupabaseSharedRepository(client, accountId: 'alice');
    final data = content();
    final created = await repo.create(data);
    expect(created.revision, 1);
    final saved = (await repo.save(created.listId, 1, data))!;
    expect(saved.revision, 2);
    expect(identical(saved.content, data), true);
    expect((calls.last['p_args'] as Map).keys.toSet(), {
      'name',
      'budgetPence',
      'isPlanning',
      'items',
      'listId',
      'expectedRevision',
    });
    expect(
      calls,
      hasLength(2),
    ); // No post-save fetch that could acknowledge a competing edit.
    conflict = true;
    expect(await repo.save('list-1', 1, data), isNull);
  });

  test(
    'invitations normalise email and report in-app delivery honestly',
    () async {
      late Map<String, dynamic> body;
      final client = testClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return response({
          'invitationId': 'invite-1',
          'deliveryStatus': 'in_app',
        });
      });
      await identify(client, 'alice');
      final repo = SupabaseSharedRepository(client, accountId: 'alice');
      final receipt = await repo.invite(
        'list-1',
        '  BOB@EXAMPLE.COM ',
        SharedRole.editor,
      );
      expect(receipt.delivery, InvitationDelivery.inApp);
      expect(body['p_args'], {
        'listId': 'list-1',
        'email': 'bob@example.com',
        'role': 'editor',
      });
      await expectLater(
        repo.invite('list-1', 'bad', SharedRole.viewer),
        throwsA(isA<AccountProblem>()),
      );
      await expectLater(
        repo.invite('list-1', 'bob@example.com', SharedRole.owner),
        throwsArgumentError,
      );
    },
  );

  test('membership and invitation actions use the guarded RPC and preserve delete conflicts', () async {
    final actions = <String>[];
    final client = testClient((request) async {
      final body = jsonDecode(request.body) as Map;
      final action = body['p_action'] as String;
      actions.add(action);
      if (action == 'member') expect(body['p_args']['role'], isNull);
      return response(
        action == 'delete'
            ? {'conflict': true}
            : {'ok': true, 'listId': 'list-1'},
      );
    });
    await identify(client, 'alice');
    final repo = SupabaseSharedRepository(client, accountId: 'alice');
    expect(await repo.accept('invite-1'), 'list-1');
    await repo.decline('invite-1');
    await repo.revoke('invite-1');
    await repo.changeMember('list-1', 'bob', null);
    await repo.leave('list-1');
    expect(await repo.delete('list-1', 3), false);
    expect(actions, [
      'accept',
      'decline',
      'revoke',
      'member',
      'leave',
      'delete',
    ]);
  });

  test(
    'server denial is distinct from a network failure or edit conflict',
    () async {
      final client = testClient(
        (_) async => response({
          'code': '42501',
          'message': 'Editor permission required',
        }, status: 403),
      );
      await identify(client, 'bob');
      final repo = SupabaseSharedRepository(client, accountId: 'bob');
      await expectLater(
        repo.save('list-1', 1, content()),
        throwsA(isA<SharedAccessProblem>()),
      );
    },
  );

  test(
    'account switches reject late responses and prevent subsequent requests',
    () async {
      final entered = Completer<void>();
      final delayed = Completer<http.Response>();
      var calls = 0;
      final client = testClient((_) async {
        calls++;
        entered.complete();
        return delayed.future;
      });
      await identify(client, 'alice');
      final repo = SupabaseSharedRepository(client, accountId: 'alice');
      final pending = repo.create(content());
      await entered.future;
      await identify(client, 'bob');
      delayed.complete(response({'listId': 'list-1', 'revision': 1}));
      await expectLater(pending, throwsA(isA<AccountProblem>()));
      await expectLater(repo.create(content()), throwsA(isA<AccountProblem>()));
      expect(calls, 1);
    },
  );
}
