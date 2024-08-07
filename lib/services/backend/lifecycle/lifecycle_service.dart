import 'dart:async';
import 'dart:isolate';
import 'dart:ui' hide window;

import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/services/rustpush/rustpush_service.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart';
import 'package:universal_io/io.dart';

LifecycleService ls = Get.isRegistered<LifecycleService>() ? Get.find<LifecycleService>() : Get.put(LifecycleService());

class LifecycleService extends GetxService with WidgetsBindingObserver {
  bool isBubble = false;
  bool isUiThread = true;
  bool windowFocused = true;
  bool? wasActiveAliveBefore;
  bool get isAlive => kIsWeb ? !(window.document.hidden ?? false)
      : kIsDesktop ? windowFocused : (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed
        || IsolateNameServer.lookupPortByName('bg_isolate') != null);
  
  bool isDead = false;
  Timer? closeTimer;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state != AppLifecycleState.resumed) {
      SystemChannels.textInput.invokeMethod('TextInput.hide').catchError((e) {
        Logger.error("Error caught while hiding keyboard: ${e.toString()}");
      });
      if (isBubble) {
        closeBubble();
      } else {
        close();
      }
    } else if (state == AppLifecycleState.resumed) {
      await storeStartup.future;
      open();
    }
    if (state == AppLifecycleState.detached && !(kIsDesktop || kIsWeb)) {
      isDead = true;
      if (!outq.isProcessing && !inq.isProcessing) {
        Logger.info("Engine exit");
        await mcs.invokeMethod("engine-done");
      }
    }
  }

  void open() {
    if (!kIsDesktop || wasActiveAliveBefore != false) {
      cm.setActiveToAlive();
    }
    if (cm.activeChat != null) {
      cm.activeChat!.chat.toggleHasUnread(false);
      ConversationViewController _cvc = cvc(cm.activeChat!.chat);
      if (!_cvc.showingOverlays && _cvc.editing.isEmpty) {
        _cvc.lastFocusedNode.requestFocus();
      }
    }
    pushService.tryWarnVpn();

    if (http.originOverride == null) {
      // NetworkTasks.detectLocalhost();
    }
    if (!kIsDesktop && !kIsWeb) {
      if (!isBubble) {
        createFakePort();
      }
      if (!ss.settings.keepAppAlive.value) {
        socket.reconnect();
      }
    }

    es.refreshCache();

    if (kIsDesktop) {
      windowFocused = true;
    }
  }

  // clever trick so we can see if the app is active in an isolate or not
  void createFakePort() {
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping('bg_isolate');
    IsolateNameServer.registerPortWithName(port.sendPort, 'bg_isolate');
  }

  void close() {
    if (kIsDesktop) {
      wasActiveAliveBefore = cm.activeChat?.isAlive;
    }
    if (!kIsDesktop || wasActiveAliveBefore != false) {
      cm.setActiveToDead();
    }
    if (!kIsDesktop && !kIsWeb) {
      IsolateNameServer.removePortNameMapping('bg_isolate');
      if (!ss.settings.keepAppAlive.value) {
        socket.disconnect();
      }
    }
    if (cm.activeChat != null) {
      ConversationViewController _cvc = cvc(cm.activeChat!.chat);
      _cvc.lastFocusedNode.unfocus();
    }
    if (kIsDesktop) {
      windowFocused = false;
    }
  }

  void closeBubble() {
    cm.setActiveToDead();
    socket.disconnect();
  }
}