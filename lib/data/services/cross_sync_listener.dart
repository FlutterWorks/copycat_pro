import 'dart:async';

import 'package:copycat_base/db/clip_collection/clipcollection.dart';
import 'package:copycat_base/db/clipboard_item/clipboard_item.dart';
import 'package:copycat_base/domain/services/cross_sync_listener.dart';
import 'package:copycat_pro/constants/strings.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

mixin SBCrossSyncListenerStatusChangeMixin {
  final _statusEvents = StreamController<CrossSyncStatusEvent>();
  final _channelEvents =
      StreamController<CrossSyncEvent<Map<String, dynamic>>>();

  void _onStatusChange(RealtimeSubscribeStatus status, Object? obj) {
    switch (status) {
      case RealtimeSubscribeStatus.subscribed:
        _statusEvents.add((CrossSyncListenerStatus.connected, obj));
      case RealtimeSubscribeStatus.channelError:
        _statusEvents.add((CrossSyncListenerStatus.error, obj));
      case RealtimeSubscribeStatus.closed:
        _statusEvents.add((CrossSyncListenerStatus.disconnected, obj));
      case RealtimeSubscribeStatus.timedOut:
        _statusEvents.add((CrossSyncListenerStatus.disconnected, obj));
    }
  }

  void _onChange(PostgresChangePayload payload) {
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        _channelEvents.add((CrossSyncEventType.create, payload.newRecord));
      case PostgresChangeEvent.update:
        _channelEvents.add((CrossSyncEventType.update, payload.newRecord));
      case PostgresChangeEvent.delete:
        _channelEvents.add((CrossSyncEventType.delete, payload.newRecord));
      default:
    }
  }
}

@LazySingleton(as: ClipCrossSyncListener)
class SBClipCrossSyncListener
    with SBCrossSyncListenerStatusChangeMixin
    implements ClipCrossSyncListener {
  RealtimeChannel? _channel;

  final String channelID = "clips-rtc";

  final SupabaseClient client;
  final String deviceId;

  SBClipCrossSyncListener(this.client, @Named("device_id") this.deviceId) {
    _statusEvents.add((CrossSyncListenerStatus.unknown, null));
  }

  @override
  Future<void> start() async {
    if (isInitiated) return;
    _statusEvents.add((CrossSyncListenerStatus.connecting, null));
    _channel = client.channel(
      channelID,
      // opts: const RealtimeChannelConfig(ack: true),
    );
    _channel
        ?.onPostgresChanges(
          schema: 'public',
          event: PostgresChangeEvent.all,
          table: clipItemTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.neq,
            column: "deviceId",
            value: deviceId,
          ),
          callback: _onChange,
        )
        .subscribe(_onStatusChange);
  }

  @override
  get onChange {
    return _channelEvents.stream.map(
      (e) => (e.$1, ClipboardItem.fromJson(e.$2)),
    );
  }

  @override
  get onStatusChange => _statusEvents.stream;

  @override
  Future<void> send(ClipboardItem item) async {}

  @override
  Future<void> stop() async {
    if (!isInitiated) return;
    final result = await _channel?.unsubscribe();
    if (result == "ok") {
      _channel = null;
      _statusEvents.add((CrossSyncListenerStatus.disconnected, null));
    }
  }

  @override
  bool get isInitiated => _channel != null;
}

@LazySingleton(as: CollectionCrossSyncListener)
class SBCollectionCrossSyncListener
    with SBCrossSyncListenerStatusChangeMixin
    implements CollectionCrossSyncListener {
  RealtimeChannel? _channel;

  final String channelID = "collection-rtc";

  final SupabaseClient client;
  final String deviceId;

  SBCollectionCrossSyncListener(
      this.client, @Named("device_id") this.deviceId) {
    _statusEvents.add((CrossSyncListenerStatus.unknown, null));
  }

  @override
  Future<void> start() async {
    if (isInitiated) return;
    _statusEvents.add((CrossSyncListenerStatus.connecting, null));
    _channel = client.channel(
      channelID,
      // opts: const RealtimeChannelConfig(ack: true),
    );

    _channel
        ?.onPostgresChanges(
          schema: 'public',
          event: PostgresChangeEvent.all,
          table: clipCollectionTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.neq,
            column: "deviceId",
            value: deviceId,
          ),
          callback: _onChange,
        )
        .subscribe(_onStatusChange);
  }

  @override
  get onChange {
    return _channelEvents.stream.map(
      (e) => (e.$1, ClipCollection.fromJson(e.$2)),
    );
  }

  @override
  get onStatusChange => _statusEvents.stream;

  @override
  Future<void> send(ClipCollection item) async {}

  @override
  Future<void> stop() async {
    if (!isInitiated) return;
    if (await _channel?.unsubscribe() == "ok") {
      _channel = null;
      _statusEvents.add((CrossSyncListenerStatus.disconnected, null));
    }
  }

  @override
  bool get isInitiated => _channel != null;
}
