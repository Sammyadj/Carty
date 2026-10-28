import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/account_gateway.dart';
import '../data/stored_workspace.dart';
import 'cloud_workspace.dart';

/// Pages records and transmits only changed rows. The head revision makes each
/// delta atomic and detects competing devices; conflicts are still reviewed as
/// whole workspaces until shared-list conflict handling is introduced.
class RecordCloudRepository implements CloudWorkspaceRepository {
  RecordCloudRepository(this.client, {required this.requireOwner});
  final SupabaseClient client;
  final void Function(String) requireOwner;
  final _bases = <String, _RecordBase>{};
  static const pageSize = 500;
  static const _timeout = Duration(seconds: 12);

  Future<_Head?> _bootstrap(String owner) async {
    requireOwner(owner);
    final result = await client
        .rpc('carty_bootstrap_records')
        .timeout(_timeout);
    requireOwner(owner);
    return _Head.fromResult(result, owner);
  }

  Future<_Head?> _head(String owner) async {
    requireOwner(owner);
    final row = await client
        .from('carty_cloud_heads')
        .select('user_id,revision,protocol,metadata,record_count')
        .eq('user_id', owner)
        .maybeSingle()
        .timeout(_timeout);
    requireOwner(owner);
    return row == null ? null : _Head.fromRow(row, owner);
  }

  @override
  Future<CloudWorkspace?> fetch(String ownerId) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final head = attempt == 0
          ? await _bootstrap(ownerId)
          : await _head(ownerId);
      if (head == null) {
        _bases.remove(ownerId);
        return null;
      }
      final records = <WorkspaceRecord>[];
      var newestRecordRevision = 0;
      for (var offset = 0; offset < head.count; offset += pageSize) {
        requireOwner(ownerId);
        final rows = await client
            .from('carty_cloud_records')
            .select('user_id,kind,parent_id,record_id,position,revision,data')
            .eq('user_id', ownerId)
            .order('kind')
            .order('parent_id')
            .order('record_id')
            .range(offset, offset + pageSize - 1)
            .timeout(_timeout);
        requireOwner(ownerId);
        for (final row in rows) {
          if (row['user_id'] != ownerId ||
              row['revision'] is! int ||
              row['revision'] < 1 ||
              row['data'] is! Map) {
            throw const FormatException('Invalid cloud record');
          }
          records.add(
            WorkspaceRecord.fromRow({
              ...row,
              'data': canonicalSnapshot(jsonEncode(row['data'])),
            }),
          );
          final revision = row['revision'] as int;
          if (revision > newestRecordRevision) newestRecordRevision = revision;
        }
        if (rows.length < pageSize) break;
      }
      final after = await _head(ownerId);
      if (after == null || after.revision != head.revision) continue;
      if (records.length != head.count ||
          newestRecordRevision > head.revision) {
        throw const FormatException('Incomplete cloud records');
      }
      final workspace = WorkspaceRows(head.metadata, records);
      final snapshot = workspace.toSnapshot();
      _bases[ownerId] = _RecordBase(head.revision, workspace);
      return CloudWorkspace(
        ownerId: ownerId,
        revision: head.revision,
        snapshot: snapshot,
      );
    }
    throw const AccountProblem(
      'Your cloud data changed during download. Please sync again shortly.',
    );
  }

  @override
  Future<CloudWorkspace?> save(
    String ownerId,
    int expectedRevision,
    String snapshot,
  ) async {
    requireOwner(ownerId);
    final desired = WorkspaceRows.fromSnapshot(snapshot);
    if (expectedRevision < 0) throw ArgumentError.value(expectedRevision);
    if (expectedRevision > 0 && _bases[ownerId]?.revision != expectedRevision) {
      final current = await fetch(ownerId);
      if (current?.revision != expectedRevision) return null;
    }
    final previous = expectedRevision == 0
        ? <String, WorkspaceRecord>{}
        : {for (final row in _bases[ownerId]!.rows.records) row.key: row};
    final next = {for (final row in desired.records) row.key: row};
    final upserts = [
      for (final row in next.values)
        if (previous[row.key]?.data != row.data ||
            previous[row.key]?.position != row.position)
          {...row.toRow(), 'data': jsonDecode(row.data)},
    ];
    final deletes = [
      for (final row in previous.values)
        if (!next.containsKey(row.key))
          {'kind': row.kind, 'parent_id': row.parent, 'record_id': row.id},
    ];
    if (upserts.length + deletes.length > 20000) {
      throw const AccountProblem(
        'This change is too large for one cloud save. Your data remains on this device; export a backup before reorganising it.',
      );
    }
    final result = await client
        .rpc(
          'carty_save_record_delta',
          params: {
            'p_protocol': 2,
            'p_expected_revision': expectedRevision,
            'p_metadata': jsonDecode(desired.metadata),
            'p_upserts': upserts,
            'p_deletes': deletes,
          },
        )
        .timeout(_timeout);
    requireOwner(ownerId);
    final accepted = _Head.fromResult(result, ownerId);
    if (accepted == null) return null;
    if (accepted.revision != expectedRevision + 1 ||
        accepted.count != next.length ||
        accepted.metadata != desired.metadata) {
      throw const FormatException('Invalid cloud save response');
    }
    _bases[ownerId] = _RecordBase(accepted.revision, desired);
    return CloudWorkspace(
      ownerId: ownerId,
      revision: accepted.revision,
      snapshot: canonicalSnapshot(snapshot),
    );
  }
}

class _RecordBase {
  const _RecordBase(this.revision, this.rows);
  final int revision;
  final WorkspaceRows rows;
}

class _Head {
  const _Head(this.revision, this.metadata, this.count);
  final int revision;
  final String metadata;
  final int count;
  factory _Head.fromRow(Map<String, dynamic> row, String owner) {
    if (row['user_id'] != owner ||
        row['protocol'] != 2 ||
        row['revision'] is! int ||
        row['revision'] < 1 ||
        row['record_count'] is! int ||
        row['record_count'] < 0 ||
        row['metadata'] is! Map) {
      throw const FormatException('Invalid cloud head');
    }
    return _Head(
      row['revision'] as int,
      canonicalSnapshot(jsonEncode(row['metadata'])),
      row['record_count'] as int,
    );
  }
  static _Head? fromResult(Object? result, String owner) {
    if (result is! List || result.length > 1) {
      throw const FormatException('Invalid cloud response');
    }
    return result.isEmpty
        ? null
        : _Head.fromRow(Map<String, dynamic>.from(result.single as Map), owner);
  }
}
