import 'dart:async';

import 'package:copycat_base/db/clipboard_item/clipboard_item.dart';
import 'package:copycat_base/domain/services/cross_sync_listener.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_io/io.dart';

@LazySingleton(as: ClipCrossSyncListener)
class SBClipCrossSyncListener implements ClipCrossSyncListener {
  RealtimeChannel? _channel;

  late final String channelID;

  final SupabaseClient client;
  final String deviceId;

  final eventName = "ClipEvent";
  final _channelEvents = StreamController<CrossSyncEvent>.broadcast();

  SBClipCrossSyncListener(this.client, @Named("device_id") this.deviceId) {
    channelID = "${Platform.operatingSystem}-$deviceId-rtc";
  }

  @override
  Future<void> start() async {
    if (isInitiated) return;
    _channel = client.channel(
      channelID,
      opts: const RealtimeChannelConfig(
        ack: true,
      ),
    );
    _channel
        ?.onBroadcast(
          event: eventName,
          callback: (payload) => _channelEvents.add(
            (eventName, payload),
          ),
        )
        .subscribe();
  }

  @override
  Stream<ClipboardItem> get events {
    return _channelEvents.stream.where((e) => e.$1 == eventName).map(
          (e) => ClipboardItem.fromJson(e.$2),
        );
  }

  @override
  Future<void> send(ClipboardItem item) async {}

  @override
  Future<void> stop() async {
    if (!isInitiated) return;
    if (await _channel?.unsubscribe() == "ok") {
      _channel = null;
    }
  }

  @override
  bool get isInitiated => _channel != null;
}
