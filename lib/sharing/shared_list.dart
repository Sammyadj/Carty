import 'dart:convert';

import '../core/money.dart';
import '../models/cart_item.dart';
import '../state/cart_store.dart';

enum SharedRole {
  owner,
  editor,
  viewer;

  bool get canEdit => this != viewer;

  static SharedRole member(Object? value) => switch (value) {
    'editor' => editor,
    'viewer' => viewer,
    _ => throw const FormatException('Invalid household role'),
  };
}

/// Only this basket is shared. Private history, saved lists and recommendations
/// never travel through the household API.
class SharedContent {
  SharedContent({
    required String name,
    required this.budgetPence,
    required this.isPlanning,
    required Iterable<CartItem> items,
  }) : name = name.trim(),
       items = List.unmodifiable(items) {
    if (this.name.isEmpty ||
        this.name.length > 60 ||
        (budgetPence != null &&
            (budgetPence! < 1 || budgetPence! > Money.maxPence)) ||
        this.items.length > 1000) {
      throw const FormatException('Invalid shared list');
    }
    final ids = <String>{};
    for (final item in this.items) {
      if (!ids.add(item.id) ||
          item.id.length > 256 ||
          CartItem.fromJson(item.toJson()) == null) {
        throw const FormatException('Invalid shared product');
      }
    }
  }

  final String name;
  final int? budgetPence;
  final bool isPlanning;
  final List<CartItem> items;

  factory SharedContent.fromBasketSnapshot(String name, String snapshot) {
    if (!CartStore.isValidSnapshot(snapshot)) {
      throw const FormatException('Invalid shared basket');
    }
    final data = jsonDecode(snapshot) as Map<String, dynamic>;
    if (data['version'] != 3 ||
        data['activeListId'] != null ||
        data['isPlanning'] is! bool ||
        [
          'savedLists',
          'history',
          'productPreferences',
        ].any((key) => data[key] is! List || (data[key] as List).isNotEmpty)) {
      throw const FormatException(
        'Private data cannot be stored in a household list',
      );
    }
    return SharedContent(
      name: name,
      budgetPence: data['budgetPence'] as int?,
      isPlanning: data['isPlanning'] as bool,
      items: (data['items'] as List).map(
        (row) => CartItem.fromJson(row as Map<String, dynamic>)!,
      ),
    );
  }

  Map<String, Object?> toArguments() => {
    'name': name,
    'budgetPence': budgetPence,
    'isPlanning': isPlanning,
    'items': items.map((item) => item.toJson()).toList(),
  };

  String toBasketSnapshot() => jsonEncode({
    'version': 3,
    'activeListId': null,
    'budgetPence': budgetPence,
    'isPlanning': isPlanning,
    'items': items.map((item) => item.toJson()).toList(),
    'savedLists': [],
    'history': [],
    'productPreferences': [],
  });
}

class SharedListHeader {
  const SharedListHeader({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.budgetPence,
    required this.isPlanning,
    required this.revision,
    required this.updatedAt,
    required this.role,
  });

  final String id;
  final String ownerId;
  final String name;
  final int? budgetPence;
  final bool isPlanning;
  final int revision;
  final DateTime updatedAt;
  final SharedRole role;

  Map<String, Object?> toRow() => {
    'id': id,
    'owner_id': ownerId,
    'name': name,
    'budget_pence': budgetPence,
    'is_planning': isPlanning,
    'revision': revision,
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'currency': 'GBP',
  };

  factory SharedListHeader.fromRow(Map<String, dynamic> row, SharedRole role) {
    final budget = row['budget_pence'];
    if (row['currency'] != 'GBP' ||
        row['is_planning'] is! bool ||
        row['revision'] is! int ||
        row['revision'] < 1 ||
        (budget != null &&
            (budget is! int || budget < 1 || budget > Money.maxPence))) {
      throw const FormatException('Invalid household header');
    }
    return SharedListHeader(
      id: sharedText(row['id']),
      ownerId: sharedText(row['owner_id']),
      name: sharedText(row['name'], maximum: 60),
      budgetPence: budget as int?,
      isPlanning: row['is_planning'] as bool,
      revision: row['revision'] as int,
      updatedAt: sharedDate(row['updated_at']),
      role: role,
    );
  }

  bool sameVersion(SharedListHeader other) =>
      id == other.id &&
      ownerId == other.ownerId &&
      revision == other.revision &&
      role == other.role &&
      name == other.name &&
      budgetPence == other.budgetPence &&
      isPlanning == other.isPlanning &&
      updatedAt == other.updatedAt;
}

class SharedListDocument {
  SharedListDocument(this.header, Iterable<CartItem> items)
    : content = SharedContent(
        name: header.name,
        budgetPence: header.budgetPence,
        isPlanning: header.isPlanning,
        items: items,
      );
  final SharedListHeader header;
  final SharedContent content;
}

enum InvitationDelivery { inApp, sent, failed }

class SharedInvitation {
  SharedInvitation.fromRow(Map<String, dynamic> row)
    : id = sharedText(row['id']),
      listId = sharedText(row['list_id']),
      listName = sharedText(row['list_name'], maximum: 60),
      inviterName = sharedText(row['inviter_name'], maximum: 254),
      email = sharedText(row['recipient_email'], maximum: 254),
      role = SharedRole.member(row['role']),
      createdAt = sharedDate(row['created_at']),
      expiresAt = sharedDate(row['expires_at']),
      acceptedAt = row['accepted_at'] == null
          ? null
          : sharedDate(row['accepted_at']),
      revokedAt = row['revoked_at'] == null
          ? null
          : sharedDate(row['revoked_at']),
      acceptedBy = row['accepted_by'] == null
          ? null
          : sharedText(row['accepted_by']),
      delivery = parseDelivery(row['delivery_status']);
  final String id, listId, listName, inviterName, email;
  final SharedRole role;
  final DateTime createdAt, expiresAt;
  final DateTime? acceptedAt, revokedAt;
  final String? acceptedBy;
  final InvitationDelivery delivery;
  bool isPending(DateTime now) =>
      acceptedAt == null && revokedAt == null && expiresAt.isAfter(now);
}

class SharedMember {
  SharedMember.fromRow(Map<String, dynamic> row)
    : listId = sharedText(row['list_id']),
      userId = sharedText(row['user_id']),
      role = SharedRole.member(row['role']);
  final String listId, userId;
  final SharedRole role;
}

class SharedSaveReceipt {
  const SharedSaveReceipt(this.listId, this.revision, this.content);
  final String listId;
  final int revision;

  /// Exactly the acknowledged submission, never a subsequent device's save.
  final SharedContent content;
}

class InvitationReceipt {
  const InvitationReceipt(this.id, this.delivery);
  final String id;
  final InvitationDelivery delivery;
}

InvitationDelivery parseDelivery(Object? value) => switch (value) {
  'in_app' => InvitationDelivery.inApp,
  'sent' => InvitationDelivery.sent,
  'failed' => InvitationDelivery.failed,
  _ => throw const FormatException('Invalid invitation delivery status'),
};

String sharedText(Object? value, {int maximum = 256}) {
  if (value is! String || value.trim().isEmpty || value.length > maximum) {
    throw const FormatException('Invalid household text');
  }
  return value;
}

DateTime sharedDate(Object? value) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) throw const FormatException('Invalid household date');
  return parsed.toUtc();
}
