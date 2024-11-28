import 'package:copycat_base/common/paginated_results.dart';
import 'package:copycat_base/constants/strings/strings.dart';
import 'package:copycat_base/db/clipboard_item/clipboard_item.dart';
import 'package:copycat_base/domain/sources/clipboard.dart';
import 'package:copycat_base/enums/clip_type.dart';
import 'package:copycat_base/enums/sort.dart';
import 'package:copycat_base/utils/utility.dart';
import 'package:copycat_pro/constants/strings.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@Named("remote")
@LazySingleton(as: ClipboardSource)
class RemoteClipboardSource implements ClipboardSource {
  final SupabaseClient client;

  RemoteClipboardSource(this.client);

  PostgrestClient get db => client.rest;

  @override
  Future<ClipboardItem> create(ClipboardItem item) async {
    final docs = await db.from(clipItemTable).insert(item.toJson()).select();
    final createdItem = item.copyWith(
      serverId: docs.first["id"],
      lastSynced: now(),
    )..applyId(item);

    return createdItem;
  }

  /// search, category, types, collectionId, sortBy,
  /// order, from, to are no-op
  @override
  Future<PaginatedResult<ClipboardItem>> getList({
    int limit = 50,
    int offset = 0,
    String? search, // no-op
    Set<TextCategory>? textCategories, // no-op
    Set<ClipItemType>? types, // no-op
    int? collectionId, // no-op
    ClipboardSortKey? sortBy, // no-op
    SortOrder order = SortOrder.desc, // no-op
    DateTime? from, // no-op
    DateTime? to, // no-op
  }) async {
    final items = await db
        .from(clipItemTable)
        .select()
        .order("modified")
        .range(offset, limit + offset);

    final clips = (items.map((e) => ClipboardItem.fromJson(e))).toList();

    return PaginatedResult(results: clips, hasMore: clips.length == limit);
  }

  @override
  Future<ClipboardItem> update(ClipboardItem item) async {
    if (item.serverId == null) {
      return await create(item);
    }

    await db.from(clipItemTable).update(item.toJson()).eq("id", item.serverId!);
    return item;
  }

  @override
  Future<bool> delete(ClipboardItem item) async {
    if (item.serverId == null || item.userId == kLocalUserId) {
      return true;
    }

    item = item.copyWith(deletedAt: now(), modified: now(), text: "", url: "");
    await db.from(clipItemTable).update(item.toJson()).eq("id", item.serverId!);
    return true;
  }

  @override
  Future<bool> deleteAll() {
    throw UnimplementedError();
  }

  @override
  Future<ClipboardItem?> get({int? id, int? serverId}) async {
    if (serverId == null && id == null) return null;
    final item =
        await db.from(clipItemTable).select().eq("id", (serverId ?? id)!);
    if (item.isEmpty) return null;
    final clipItem = ClipboardItem.fromJson(item.first);
    return clipItem;
  }

  @override
  Future<ClipboardItem?> getLatestFromOthers({bool? synced}) {
    throw UnimplementedError();
  }

  @override
  Future<void> decryptPending() {
    throw UnimplementedError();
  }

  @override
  Future<List<ClipboardItem>> deleteMany(List<ClipboardItem> items) async {
    final items_ = items
        .where((item) => item.serverId != null && item.userId != kLocalUserId)
        .map(
      (item) {
        final json = item
            .copyWith(
              deletedAt: now(),
              modified: now(),
              text: "",
              url: "",
            )
            .toJson();
        return {
          ...json,
          "id": item.serverId,
        };
      },
    ).toList();
    await db.from(clipItemTable).upsert(items_);
    return items;
  }

  @override
  Future<ClipboardItem> updateOrCreate(ClipboardItem item) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteAllEncrypted() async {
    await db.from(clipItemTable).delete().eq("encrypted", true);
  }

  @override
  Future<int> getClipCounts() async {
    final result = await db.from(clipItemTable).count(CountOption.estimated);
    return result;
  }
}
