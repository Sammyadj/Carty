import 'dart:async';
import 'dart:convert';

import 'package:carty_app/auth/account_gateway.dart';
import 'package:carty_app/cloud/supabase_gateway.dart';
import 'package:carty_app/config/supabase_config.dart';
import 'package:carty_app/data/stored_workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_test_support.dart';

Future<void> identify(SupabaseClient client, String id) =>
    client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'test-token',
        'token_type': 'bearer',
        'refresh_token': 'test-refresh',
        'user': {
          'id': id,
          'aud': 'authenticated',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      }),
    );

SupabaseClient testClient(
  Future<http.Response> Function(http.Request) handler,
) {
  final client = SupabaseClient(
    'https://carty.example.invalid',
    'public-test-key',
    authOptions: AuthClientOptions(
      autoRefreshToken: false,
      pkceAsyncStorage: _PkceMemory(),
    ),
    httpClient: MockClient((request) async {
      final response = await handler(request);
      return http.Response(
        response.body,
        response.statusCode,
        request: request,
        headers: response.headers,
      );
    }),
  );
  addTearDown(client.dispose);
  return client;
}

class _PkceMemory extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

void main() {
  test(
    'cloud writes use the revision RPC and never accept an owner parameter',
    () async {
      final snapshot = await exampleSnapshot('Milk');
      final records = WorkspaceRows.fromSnapshot(snapshot);
      late http.Request request;
      final client = testClient((value) async {
        request = value;
        return http.Response(
          jsonEncode([
            {
              'user_id': 'alice',
              'revision': 1,
              'protocol': 2,
              'metadata': jsonDecode(records.metadata),
              'record_count': records.records.length,
            },
          ]),
          200,
          headers: {
            'content-type': 'application/json',
            'x-supabase-api-version': '2024-01-01',
          },
        );
      });
      await identify(client, 'alice');
      final result = await SupabaseGateway(client).save('alice', 0, snapshot);
      expect(request.url.path, '/rest/v1/rpc/carty_save_record_delta');
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Map;
      expect(body.keys.toSet(), {
        'p_protocol',
        'p_expected_revision',
        'p_metadata',
        'p_upserts',
        'p_deletes',
      });
      expect(body['p_expected_revision'], 0);
      expect(body['p_upserts'], hasLength(records.records.length));
      expect(body['p_deletes'], isEmpty);
      expect(result!.revision, 1);
      expect(result.ownerId, 'alice');
    },
  );

  test(
    'a mismatched owner is blocked before HTTP and after a delayed response',
    () async {
      final entered = Completer<void>();
      final response = Completer<http.Response>();
      var requests = 0;
      final client = testClient((request) async {
        requests++;
        entered.complete();
        return response.future;
      });
      await identify(client, 'alice');
      final gateway = SupabaseGateway(client);
      await expectLater(gateway.fetch('bob'), throwsA(isA<AccountProblem>()));
      expect(requests, 0);
      final fetching = gateway.fetch('alice');
      await entered.future;
      await identify(client, 'bob');
      response.complete(
        http.Response('[]', 200, headers: {'content-type': 'application/json'}),
      );
      await expectLater(fetching, throwsA(isA<AccountProblem>()));
    },
  );

  test(
    'an empty save result reports conflict and a foreign row is rejected',
    () async {
      final snapshot = await exampleSnapshot('Milk');
      var foreign = false;
      final client = testClient(
        (_) async => http.Response(
          foreign
              ? jsonEncode([
                  {
                    'user_id': 'bob',
                    'revision': 2,
                    'snapshot': jsonDecode(snapshot),
                  },
                ])
              : '[]',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await identify(client, 'alice');
      final gateway = SupabaseGateway(client);
      expect(await gateway.save('alice', 0, snapshot), isNull);
      foreign = true;
      await expectLater(
        gateway.save('alice', 0, snapshot),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'default email service restrictions produce a useful sign-in message',
    () async {
      late http.Request request;
      final client = testClient((value) async {
        request = value;
        return http.Response(
          jsonEncode({
            'code': 'email_address_not_authorized',
            'msg': 'Email address not authorized',
          }),
          400,
          headers: {
            'content-type': 'application/json',
            'x-supabase-api-version': '2024-01-01',
          },
        );
      });
      await expectLater(
        SupabaseGateway(client).sendSignInLink('shopper@example.invalid'),
        throwsA(
          isA<AccountProblem>().having(
            (problem) => problem.message,
            'message',
            contains('Carty test team'),
          ),
        ),
      );
      expect(request.url.path, '/auth/v1/otp');
      expect(
        request.url.queryParameters['redirect_to'],
        SupabaseConfig.authCallback,
      );
      expect(jsonDecode(request.body)['email'], 'shopper@example.invalid');
    },
  );
}
