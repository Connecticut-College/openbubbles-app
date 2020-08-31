import 'dart:async';
import 'dart:io';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../conversation_view/conversation_view.dart';
import '../../repository/models/chat.dart';

import '../../helpers/utils.dart';

class ConversationTile extends StatefulWidget {
  final Chat chat;
  final bool replaceOnTap;
  final List<File> existingAttachments;
  final String existingText;

  ConversationTile(
      {Key key,
      this.chat,
      this.replaceOnTap,
      this.existingAttachments,
      this.existingText})
      : super(key: key);

  // final Chat chat;

  @override
  _ConversationTileState createState() => _ConversationTileState();
}

class _ConversationTileState extends State<ConversationTile> {
  MemoryImage contactImage;
  bool isPressed = false;

  @override
  void initState() {
    super.initState();

    fetchAvatar(null);
    ContactManager().stream.listen((List<String> addresses) {
      debugPrint("contact manager listen event ");
      fetchAvatar(addresses);

      // Check if any of the addresses are members of the chat
      List<Handle> participants = widget.chat.participants ?? [];
      dynamic handles = participants.map((Handle handle) => handle.address);
      for (String addr in addresses) {
        if (handles.contains(addr)) {
          setNewChatTitle();
          break;
        }
      }
      setNewChatTitle();
    });
  }

  void setNewChatTitle() async {
    String tmpTitle = await getFullChatTitle(widget.chat);
    if (tmpTitle != widget.chat.title) {
      if (this.mounted) setState(() {});
    }
    widget.chat.title = tmpTitle;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchAvatar(null);
  }

  void fetchAvatar(List<String> addresses) {
    loadAvatar(widget.chat, addresses).then((MemoryImage image) {
      if (image != null) {
        if (contactImage == null ||
            contactImage.bytes.length != image.bytes.length) {
          contactImage = image;
          if (this.mounted) setState(() {});
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var initials = getInitials(widget.chat.title, " ");
    return Slidable(
      actionPane: SlidableStrechActionPane(),
      secondaryActions: <Widget>[
        IconSlideAction(
          caption: widget.chat.isMuted ? 'Show Alerts' : 'Hide Alerts',
          color: Colors.purple[700],
          icon: widget.chat.isMuted
              ? Icons.notifications_active
              : Icons.notifications_off,
          onTap: () async {
            widget.chat.isMuted = !widget.chat.isMuted;
            await widget.chat.save(updateLocalVals: true);
            if (this.mounted) setState(() {});
          },
        ),
        IconSlideAction(
          caption: widget.chat.isArchived ? 'UnArchive' : 'Archive',
          color: widget.chat.isArchived ? Colors.blue : Colors.red,
          icon: widget.chat.isArchived ? Icons.replay : Icons.delete,
          onTap: () {
            if (widget.chat.isArchived) {
              ChatBloc().unArchiveChat(widget.chat);
            } else {
              ChatBloc().archiveChat(widget.chat);
            }
          },
        )
      ],
      child: Material(
        color: !isPressed
            ? Theme.of(context).backgroundColor
            : Theme.of(context).buttonColor,
        child: GestureDetector(
          onTapDown: (details) {
            setState(() {
              isPressed = true;
            });
          },
          onTapUp: (details) {
            MessageBloc messageBloc = new MessageBloc(widget.chat);
            if (widget.replaceOnTap != null && widget.replaceOnTap) {
              Navigator.of(context).pushAndRemoveUntil(
                CupertinoPageRoute(
                  builder: (BuildContext context) {
                    return ConversationView(
                      chat: widget.chat,
                      title: widget.chat.title,
                      messageBloc: messageBloc,
                      existingAttachments: widget.existingAttachments,
                      existingText: widget.existingText,
                    );
                  },
                ),
                (route) => route.isFirst,
              );
            } else {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (BuildContext context) {
                    return ConversationView(
                      chat: widget.chat,
                      title: widget.chat.title,
                      messageBloc: messageBloc,
                      existingAttachments: widget.existingAttachments,
                      existingText: widget.existingText,
                    );
                  },
                ),
              );
            }
            Future.delayed(Duration(milliseconds: 200), () {
              if (this.mounted)
                setState(() {
                  isPressed = false;
                });
            });
          },
          onTapCancel: () {
            setState(() {
              isPressed = false;
            });
          },
          child: Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(left: 35.0),
                child: Container(
                  decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(
                              color: Colors.white.withAlpha(40), width: 0.5))),
                  child: ListTile(
                    contentPadding: EdgeInsets.only(left: 0),
                    title: Text(
                      widget.chat.title != null ? widget.chat.title : "",
                      style: Theme.of(context).textTheme.bodyText1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: widget.chat.latestMessageText != null &&
                            !(widget.chat.latestMessageText is String)
                        ? widget.chat.latestMessageText
                        : Text(
                            widget.chat.latestMessageText != null
                                ? widget.chat.latestMessageText
                                : "",
                            style: Theme.of(context).textTheme.subtitle1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    leading: ContactAvatarWidget(
                      contactImage: contactImage,
                      initials: initials,
                    ),
                    trailing: Container(
                      width: 80,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          Container(
                            padding: EdgeInsets.only(right: 5),
                            child: Text(
                              widget.chat.getDateText(),
                              style: Theme.of(context).textTheme.subtitle2,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Theme.of(context).textTheme.subtitle1.color,
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Container(
                  height: 70,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      !widget.chat.isMuted
                          ? Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(35),
                                color: widget.chat.hasUnreadMessage
                                    ? Colors.blue[500].withOpacity(0.8)
                                    : Colors.transparent,
                              ),
                              width: 15,
                              height: 15,
                            )
                          : SvgPicture.asset(
                              "assets/icon/moon.svg",
                              color: widget.chat.hasUnreadMessage
                                  ? Colors.blue[500].withOpacity(0.8)
                                  : Theme.of(context).textTheme.subtitle1.color,
                              width: 15,
                              height: 15,
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
