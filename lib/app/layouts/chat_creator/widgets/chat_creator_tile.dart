import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChatCreatorTile extends StatefulWidget {
  const ChatCreatorTile({
    Key? key,
    required this.title,
    required this.subtitle,
    this.chat,
    this.contact,
  }) : super(key: key);

  final String title;
  final String subtitle;
  final Chat? chat;
  final Contact? contact;

  @override
  _ChatCreatorTileState createState() => _ChatCreatorTileState();
}

class _ChatCreatorTileState extends OptimizedState<ChatCreatorTile> with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListTile(
      mouseCursor: MouseCursor.defer,
      enableFeedback: true,
      dense: ss.settings.denseChatTiles.value,
      minVerticalPadding: 10,
      horizontalTitleGap: 10,
      title: RichText(
        text: TextSpan(
          children: MessageHelper.buildEmojiText(
            widget.title,
            context.theme.textTheme.bodyLarge!,
          ),
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        widget.subtitle,
        style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.outline),
      ),
      leading: Padding(
        padding: const EdgeInsets.only(right: 5.0),
        child: widget.chat != null ? ContactAvatarGroupWidget(
          chat: widget.chat!,
          editable: false,
        ) : ContactAvatarWidget(
          handle: Handle(address: widget.subtitle),
          contact: widget.contact!,
          editable: false,
        ),
      ),
      trailing: widget.chat == null ? null : Icon(
        !material ? CupertinoIcons.forward : Icons.arrow_forward,
        color: context.theme.colorScheme.bubble(context, widget.chat!.isIMessage)
      )
    );
  }
}
