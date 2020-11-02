import 'dart:io';

import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/attachment_downloader_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_file.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/audio_player_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/contact_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/image_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/location_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/regular_file_opener.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/video_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MessageAttachment extends StatefulWidget {
  MessageAttachment({
    Key key,
    @required this.content,
    @required this.attachment,
    @required this.updateAttachment,
    @required this.message,
  }) : super(key: key);
  final content;
  final Attachment attachment;
  final Function() updateAttachment;
  final Message message;

  @override
  _MessageAttachmentState createState() => _MessageAttachmentState();
}

class _MessageAttachmentState extends State<MessageAttachment>
    with AutomaticKeepAliveClientMixin {
  String blurhash;
  Widget placeHolder;
  Widget attachmentWidget;
  var content;

  @override
  void initState() {
    super.initState();
    content = widget.content;
    if (content is AttachmentDownloader) {
      (content as AttachmentDownloader).stream.listen((event) {
        if (event is File && this.mounted) {
          setState(() {
            content = event;
          });
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Pull the blurhash from the attachment, based on the class type
    int width;
    int height;
    String blurhash;

    if (content is AttachmentDownloader) {
      blurhash = (content as AttachmentDownloader).attachment.blurhash;
      width = (content as AttachmentDownloader).attachment.width;
      height = (content as AttachmentDownloader).attachment.height;
    } else if (content is Attachment) {
      blurhash = (content as Attachment).blurhash;
      width = (content as Attachment).width;
      height = (content as Attachment).height;
    }

    placeHolder = ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        height: 150,
        width: 200,
        color: Theme.of(context).accentColor,
      ),
    );
    // (blurhash == null ||
    //         width == null ||
    //         height == null ||
    //         width == 0 ||
    //         height == 0)
    //     ?
    // : Container(
    //     constraints: BoxConstraints(
    //       maxWidth: MediaQuery.of(context).size.width * 3 / 4,
    //     ),
    //     child: ClipRRect(
    //       borderRadius: BorderRadius.circular(8.0),
    //       child: AspectRatio(
    //         aspectRatio: widget.attachment.width / widget.attachment.height,
    //         child: BlurHash(
    //           hash: blurhash,
    //           decodingWidth: (widget.attachment.width ~/ 200)
    //               .clamp(1, double.infinity),
    //           decodingHeight: (widget.attachment.height ~/ 200)
    //               .clamp(1, double.infinity),
    //         ),
    //       ),
    //     ),
    //   );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 3 / 4,
          // maxHeight: 600,
        ),
        child: _buildAttachmentWidget(),
      ),
    );
  }

  Widget _buildAttachmentWidget() {
    // If it's a file, it's already been downlaoded, so just display it
    if (content is File) {
      String mimeType = widget.attachment.mimeType;
      if (mimeType != null)
        mimeType = mimeType.substring(0, mimeType.indexOf("/"));
      if (mimeType == "image") {
        return MediaFile(
          attachment: widget.attachment,
          child: ImageWidget(
            savedAttachmentData:
                CurrentChat().getSavedAttachmentData(widget.message),
            attachment: widget.attachment,
            file: content,
          ),
        );
      } else if (mimeType == "video") {
        return MediaFile(
          attachment: widget.attachment,
          child: VideoWidget(
            attachment: widget.attachment,
            file: content,
            savedAttachmentData:
                CurrentChat().getSavedAttachmentData(widget.message),
          ),
        );
      } else if (mimeType == "audio" &&
          !widget.attachment.mimeType.contains("caf")) {
        return MediaFile(
          attachment: widget.attachment,
          child: AudioPlayerWiget(
            file: content,
          ),
        );
      } else if (widget.attachment.mimeType == "text/x-vlocation") {
        return MediaFile(
          attachment: widget.attachment,
          child: LocationWidget(
            file: content,
            attachment: widget.attachment,
          ),
        );
      } else if (widget.attachment.mimeType == "text/vcard") {
        return MediaFile(
          attachment: widget.attachment,
          child: ContactWidget(
            file: content,
            attachment: widget.attachment,
          ),
        );
      } else if (widget.attachment.mimeType == null) {
        return Container();
      } else {
        return MediaFile(
          attachment: widget.attachment,
          child: RegularFileOpener(
            file: content,
            attachment: widget.attachment,
          ),
        );
      }

      // If it's an attachment, then it needs to be manually downloaded
    } else if (content is Attachment) {
      return AttachmentDownloaderWidget(
        onPressed: () {
          content = new AttachmentDownloader(content);
          widget.updateAttachment();
          if (this.mounted) setState(() {});
        },
        attachment: content,
        placeHolder: placeHolder,
      );

      // If it's an AttachmentDownloader, it is currently being downloaded
    } else if (content is AttachmentDownloader) {
      if (widget.attachment.mimeType == null) return Container();
      (content as AttachmentDownloader).stream.listen((event) {
        if (event is File) {
          content = event;
          if (this.mounted) setState(() {});
        }
      }, onError: (error) {
        content = widget.attachment;
        if (this.mounted) setState(() {});
      });
      return StreamBuilder(
        stream: content.stream,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.hasError) {
            return Text(
              "Error loading",
              style: Theme.of(context).textTheme.bodyText1,
            );
          }
          if (snapshot.data is File) {
            // widget.updateAttachment();
            content = snapshot.data;
            return Container();
          } else {
            double progress = 0.0;
            if (snapshot.hasData) {
              progress = snapshot.data["Progress"];
            } else {
              progress = content.progress;
            }

            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                placeHolder,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        CircularProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                        ((content as AttachmentDownloader)
                                    .attachment
                                    .mimeType !=
                                null)
                            ? Container(height: 5.0)
                            : Container(),
                        (content.attachment.mimeType != null)
                            ? Text(
                                content.attachment.mimeType,
                                style: Theme.of(context).textTheme.bodyText1,
                              )
                            : Container()
                      ],
                    ),
                  ],
                ),
              ],
            );
          }
        },
      );
    } else {
      return Text(
        "Error loading",
        style: Theme.of(context).textTheme.bodyText1,
      );
      //     return Container();
    }
  }

  @override
  bool get wantKeepAlive => true;
}
