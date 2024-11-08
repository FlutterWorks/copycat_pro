import 'dart:async';

import 'package:copycat_base/db/clipboard_item/clipboard_item.dart';
import 'package:copycat_base/domain/services/cross_sync_listener.dart';
import 'package:copycat_pro/constants/strings.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_io/io.dart';

mixin SBClipCrossSyncListenerStatusChangeMixin {
  final _statusEvents = StreamController<CrossSyncStatusEvent>();

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
}

@LazySingleton(as: ClipCrossSyncListener)
class SBClipCrossSyncListener
    with SBClipCrossSyncListenerStatusChangeMixin
    implements ClipCrossSyncListener {
  RealtimeChannel? _channel;

  late final String channelID;

  final SupabaseClient client;
  final String deviceId;

  final _channelEvents =
      StreamController<CrossSyncEvent<Map<String, dynamic>>>();

  SBClipCrossSyncListener(this.client, @Named("device_id") this.deviceId) {
    channelID = "${Platform.operatingSystem}-$deviceId-rtc";
    _statusEvents.add((CrossSyncListenerStatus.unknown, null));
  }

  @override
  Future<void> start() async {
    if (isInitiated) return;
    _statusEvents.add((CrossSyncListenerStatus.connecting, null));
    _channel = client.channel(
      channelID,
      opts: const RealtimeChannelConfig(
        ack: true,
      ),
    );
    // _channel
    //     ?.onBroadcast(
    //       event: eventName,
    //       callback: (payload) => _channelEvents.add(
    //         (eventName, payload),
    //       ),
    //     )
    //     .subscribe();

    _channel
        ?.onPostgresChanges(
          schema: 'public', // Subscribes to the "public" schema in Postgres
          event: PostgresChangeEvent.all, // Listen to all changes
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
    if (await _channel?.unsubscribe() == "ok") {
      _channel = null;
      _statusEvents.add((CrossSyncListenerStatus.disconnected, null));
    }
  }

  @override
  bool get isInitiated => _channel != null;
}
