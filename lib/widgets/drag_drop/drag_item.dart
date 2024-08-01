import 'dart:async';

import 'package:copycat_base/constants/widget_styles.dart';
import 'package:copycat_base/db/clipboard_item/clipboard_item.dart';
import 'package:copycat_base/enums/clip_type.dart';
import 'package:copycat_base/utils/common_extension.dart';
import 'package:copycat_base/widgets/clip_cards/file_clip_card.dart';
import 'package:copycat_base/widgets/clip_cards/media_clip_card.dart';
import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:universal_io/io.dart';

class DraggableItem extends StatelessWidget {
  final ClipboardItem item;
  final Widget child;

  const DraggableItem({
    super.key,
    required this.item,
    required this.child,
  });

  Widget previewBuilder(BuildContext context, Widget child) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    late Widget content;
    switch (item.type) {
      case ClipItemType.text:
      case ClipItemType.url:
        content = Center(
          child: Padding(
            padding: const EdgeInsets.all(padding12),
            child: Text(
              item.text ?? item.url!,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
        );
        break;
      case ClipItemType.media:
        content = ClipRRect(
          borderRadius: radius12,
          child: MediaClipCard(item: item),
        );
        break;
      case ClipItemType.file:
        content = FileClipCard(item: item);
        break;
    }

    return SizedBox.square(
      dimension: 150,
      child: Card.outlined(child: content),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (item.needDownload) return child;
    return DragItemWidget(
      canAddItemToExistingSession: true,
      dragItemProvider: dragItemProvider,
      allowedOperations: () => const [
        DropOperation.copy,
        DropOperation.userCancelled,
      ],
      liftBuilder: previewBuilder,
      dragBuilder: previewBuilder,
      child: DraggableWidget(child: child),
    );
  }

  FutureOr<DragItem?> dragItemProvider(request) async {
    final dragItem = DragItem(localData: {"itemId": item.id});

    switch (item.type) {
      case ClipItemType.text:
        dragItem.add(Formats.plainText(item.text!));
        break;
      case ClipItemType.url:
        dragItem.add(
          Formats.uri(
            NamedUri(Uri.parse(item.url!), name: item.title),
          ),
        );
        break;
      case ClipItemType.media:
      case ClipItemType.file:
        final fileUri = Formats.fileUri(
          Uri.file(
            item.localPath!,
            windows: Platform.isWindows,
          ),
        );
        dragItem.add(fileUri);
        break;
    }

    return dragItem;
  }
}
