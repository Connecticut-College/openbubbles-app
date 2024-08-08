import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/services/network/backend_service.dart';
import 'package:bluebubbles/services/rustpush/rustpush_service.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bluebubbles/src/rust/api/api.dart' as api;

class TroubleshootPanel extends StatefulWidget {

  @override
  State<StatefulWidget> createState() => _TroubleshootPanelState();
}

class _TroubleshootPanelState extends OptimizedState<TroubleshootPanel> {
  late final savedLogsDir = kIsDesktop ? Directory(join(Logger.logFile.parent.path, "Saved Logs")) : null;
  final RxList<File> savedLogs = <File>[].obs;
  final RxnBool resyncingHandles = RxnBool();
  final RxnBool reregisteringIds = RxnBool();

  @override
  void initState() {
    super.initState();
    if (kIsDesktop && savedLogsDir!.existsSync()) {
      savedLogs.value = savedLogsDir!.listSync().whereType<File>().toList().reversed.toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: "Troubleshooting",
      initialHeader: (kIsWeb || kIsDesktop) ? "Contacts" : "Logging",
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      tileColor: tileColor,
      headerColor: headerColor,
      bodySlivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            <Widget>[
              if (kIsWeb || kIsDesktop)
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    SettingsTile(
                      onTap: () async {
                        final RxList<String> log = <String>[].obs;
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: context.theme.colorScheme.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                            titlePadding: const EdgeInsets.only(top: 15),
                            title: Text("Fetching contacts...", style: context.theme.textTheme.titleLarge),
                            content: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(
                                width: ns.width(context) * 4 / 5,
                                height: context.height * 1 / 3,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(25),
                                    color: context.theme.colorScheme.background,
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  child: Obx(() => ListView.builder(
                                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                    itemBuilder: (context, index) {
                                      return Text(
                                        log[index],
                                        style: TextStyle(
                                          color: context.theme.colorScheme.onBackground,
                                          fontSize: 10,
                                        ),
                                      );
                                    },
                                    itemCount: log.length,
                                  )),
                                ),
                              ),
                            ),
                          )
                        );
                        await cs.fetchNetworkContacts(logger: (newLog) {
                          log.add(newLog);
                        });
                      },
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.group,
                        materialIcon: Icons.contacts,
                      ),
                      title: "Fetch Contacts With Verbose Logging",
                      subtitle: "This will fetch contacts from the server with extra info to help devs debug contacts issues",
                    ),
                  ],
                ),
              if (kIsWeb || kIsDesktop)
                SettingsHeader(
                  iosSubtitle: iosSubtitle,
                  materialSubtitle: materialSubtitle,
                  text: "Logging"
                ),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  if (!kIsDesktop)
                    Obx(() => SettingsTile(
                      onTap: () async {
                        if (Logger.saveLogs.value) {
                          await Logger.stopSavingLogs();
                          Logger.saveLogs.value = false;
                          savedLogs.value =
                              RxList.from(savedLogsDir!.listSync().whereType<File>().toList().reversed);
                        } else {
                          Logger.startSavingLogs();
                        }
                      },
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.pencil_ellipsis_rectangle,
                        materialIcon: Icons.history_edu,
                      ),
                      title: "${Logger.saveLogs.value ? "End" : "Start"} Logging",
                      subtitle: Logger.saveLogs.value
                          ? "Logging started, tap here to end and save"
                          : "Create a bug report for developers to analyze",
                    )),
                  if (kIsDesktop)
                    SettingsTile(
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.doc,
                        materialIcon: Icons.file_open,
                      ),
                      title: "Open Real-time Log File",
                      subtitle: Logger.logFile.path,
                      onTap: () async {
                        if (Logger.logFile.existsSync()) Logger.logFile.createSync();
                        await launchUrl(Uri.file(Logger.logFile.path));
                      }
                    ),
                  if (kIsDesktop)
                    const SettingsDivider(),
                  if (kIsDesktop)
                    SettingsTile(
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.doc,
                        materialIcon: Icons.file_open,
                      ),
                      title: "Open Startup Log File",
                      subtitle: Logger.startupFile.path,
                      onTap: () async {
                        if (Logger.startupFile.existsSync()) Logger.startupFile.createSync();
                        await launchUrl(Uri.file(Logger.startupFile.path));
                      }
                    ),
                  if (kIsDesktop)
                    const SettingsDivider(),
                  if (kIsDesktop)
                    SettingsTile(
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.folder,
                        materialIcon: Icons.folder,
                      ),
                      title: "Open App Data Location",
                      subtitle: fs.appDocDir.path,
                      onTap: () async => await launchUrl(Uri.file(fs.appDocDir.path)),
                    ),
                  SettingsTile(
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.share,
                        materialIcon: Icons.share,
                      ),
                      title: "Export OB logs",
                      subtitle: "Last 2 hours saved. Contains sensitive information (such as messages and identifiers); do not share publicly.",
                      onTap: () async {
                        var file = Directory("${fs.appDocDir.path}/../files/logs");
                        final List<FileSystemEntity> entities = await file.list().toList();
                        var current = entities.indexWhere((element) => element.path.endsWith("CURRENT.log"));
                        var item = entities.removeAt(current);
                        var end = await File(item.path).readAsBytes();
                        var b = BytesBuilder();
                        if (entities.isNotEmpty) {
                          var next = await File(entities.first.path).readAsBytes();
                          b.add(next);
                        }
                        b.add(end);
                        var total = b.toBytes();
                        Logger.writeLogToFile(total);
                      },
                    ),
                ]
              ),
              if (kIsDesktop)
                SettingsHeader(
                  iosSubtitle: iosSubtitle,
                  materialSubtitle: materialSubtitle,
                  text: "Saved Logs"
                ),
              if (kIsDesktop)
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    SettingsTile(
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.folder,
                        materialIcon: Icons.folder,
                      ),
                      title: "Open Saved Logs Location",
                      subtitle: savedLogsDir!.path,
                      onTap: () async {
                        if (!savedLogsDir!.existsSync()) savedLogsDir!.createSync(recursive: true);
                        await launchUrl(Uri.file(savedLogsDir!.path));
                      },
                    ),
                  const SettingsDivider(),
                  Obx(() => SettingsTile(
                    onTap: () async {
                      if (Logger.saveLogs.value) {
                        await Logger.stopSavingLogs();
                        Logger.saveLogs.value = false;
                        savedLogs.value = RxList.from(savedLogsDir!.listSync().whereType<File>().toList().reversed);
                      } else {
                        Logger.startSavingLogs();
                      }
                    },
                    leading: const SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.pencil_ellipsis_rectangle,
                      materialIcon: Icons.history_edu,
                    ),
                    title: "${Logger.saveLogs.value ? "Stop" : "Start"} Saving Logs",
                    subtitle: Logger.saveLogs.value
                        ? "Logging started, tap here to end and save"
                        : "Create a bug report for developers to analyze",
                  )),
                  const SettingsDivider(),
                  SettingsTile(
                    leading: const SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.refresh,
                      materialIcon: Icons.refresh,
                    ),
                    onTap: () {
                      savedLogs.value = RxList.from(savedLogsDir!.listSync().whereType<File>().toList().reversed);
                    },
                    title: "Refresh Saved Logs",
                    subtitle: "Reload the Saved Logs directory",
                  ),
                  const SettingsDivider(),
                  Obx(() {
                    if (savedLogs.isNotEmpty) {
                      return ListView.builder(
                        shrinkWrap: true,
                        itemBuilder: (BuildContext context, int index) {
                          String? dayString;
                          String? timeString;
                          File file = savedLogs[index];
                          String name = basename(file.path);
                          RegExpMatch? timestamp = RegExp("BlueBubbles_Logs_(.*)_(.*).txt").firstMatch(name);
                          if (timestamp == null) dayString = "Unknown";

                          String? date = timestamp?.group(1);
                          String? time = timestamp?.group(2);
                          if (date == null || time == null) dayString = "Unknown";

                          List<String> splitDate = date?.split("-") ?? [];
                          List<String> splitTime = time?.split("-") ?? [];
                          if (splitDate.length == 3 && splitTime.length == 3) {
                            int? year = int.tryParse(splitDate[0]);
                            int? month = int.tryParse(splitDate[1]);
                            int? day = int.tryParse(splitDate[2]);
                            int? hour = int.tryParse(splitTime[0]);
                            int? minute = int.tryParse(splitTime[1]);
                            int? second = int.tryParse(splitTime[2]);
                            if (year != null &&
                                month != null &&
                                day != null &&
                                hour != null &&
                                minute != null &&
                                second != null) {
                              DateTime dateTime = DateTime(year, month, day, hour, minute, second);
                              dayString = DateFormat(DateFormat.YEAR_ABBR_MONTH_WEEKDAY_DAY).format(dateTime);
                              timeString = DateFormat(ss.settings.use24HrFormat.value
                                  ? DateFormat.HOUR24_MINUTE_SECOND
                                  : DateFormat.HOUR_MINUTE_SECOND)
                                  .format(dateTime);
                            }
                          }
                          if (dayString == null) {
                            if ((date ?? "").length >= 6) {
                              List<String> chars = date!.characters.toList();
                              int? year = int.tryParse(chars.sublist(0, 4).join());
                              if (year == null) return const SizedBox.shrink();

                              bool twoDigit = chars[5] == "0";
                              int? month = int.tryParse(chars.sublist(4, twoDigit ? 6 : 5).join());
                              if (month == null) return const SizedBox.shrink();

                              if (twoDigit && date.length < 7) return const SizedBox.shrink();
                              int? day = int.tryParse(chars.sublist(twoDigit ? 6 : 5).join());
                              if (day == null) return const SizedBox.shrink();

                              DateTime dateTime = DateTime(year, month, day);
                              dayString = DateFormat(DateFormat.YEAR_ABBR_MONTH_WEEKDAY_DAY).format(dateTime);
                            }
                          }
                          return SettingsTile(
                            leading: const SettingsLeadingIcon(
                              iosIcon: CupertinoIcons.doc,
                              materialIcon: Icons.file_open,
                            ),
                            title: "$dayString${timeString != null ? " at $timeString" : ""}",
                            subtitle: basename(savedLogs[index].path),
                            onTap: () async => await launchUrl(Uri.file(savedLogs[index].path)),
                            trailing: IconButton(
                              icon: Icon(iOS ? CupertinoIcons.trash : Icons.delete_outlined),
                              onPressed: () {
                                savedLogs[index].deleteSync();
                                savedLogs.value =
                                    RxList.from(savedLogsDir!.listSync().whereType<File>().toList().reversed);
                              },
                            ),
                          );
                        },
                        itemCount: savedLogs.length,
                      );
                    }
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        child: Text("When you save logs, they'll show up here", style: context.textTheme.bodySmall),
                      ),
                    );
                  }),
                ]),
              if (!kIsWeb && backend.getRemoteService() != null)
                SettingsHeader(
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Database Re-syncing"
                ),
              if (!kIsWeb && backend.getRemoteService() != null)
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    SettingsTile(
                      title: "Re-Sync Handles & Contacts",
                      subtitle: "Run this troubleshooter if you are experiencing issues with missing or incorrect contact names and photos",
                      onTap: () async {
                          resyncingHandles.value = true;
                          try {
                            final handleSyncer = HandleSyncManager();
                            await handleSyncer.start();
                            eventDispatcher.emit("refresh-all", null);

                            showSnackbar("Success", "Successfully re-synced handles! You may need to close and re-open the app for changes to take effect.");
                          } catch (ex, stacktrace) {
                            Logger.error("Failed to reset contacts!");
                            Logger.error(ex.toString());
                            Logger.error(stacktrace.toString());

                            showSnackbar("Failed to re-sync handles!", "Error: ${ex.toString()}");
                          } finally {
                            resyncingHandles.value = false;
                          }
                      },
                      trailing: Obx(() => resyncingHandles.value == null
                          ? const SizedBox.shrink()
                          : resyncingHandles.value == true ? Container(
                          constraints: const BoxConstraints(
                            maxHeight: 20,
                            maxWidth: 20,
                          ),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                          )) : Icon(Icons.check, color: context.theme.colorScheme.outline)
                      )),
                  ]),
              if (usingRustPush)
                SettingsHeader(
                  iosSubtitle: iosSubtitle,
                  materialSubtitle: materialSubtitle,
                  text: "iMessage"
                ),
              if (usingRustPush)
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    SettingsTile(
                      title: "Clear identity cache",
                      subtitle: "Run this troubleshooter if you're having trouble sending messages.",
                      onTap: () async {
                        await api.invalidateIdCache(state: pushService.state);
                        showSnackbar("Success", "Identity cache cleared! Try re-sending any messages.");
                      }),
                    SettingsTile(
                      title: "Reregister",
                      subtitle: "Run this troubleshooter if you are told to do so.",
                      onTap: () async {
                        try {
                          reregisteringIds.value = true;
                          await api.doReregister(state: pushService.state);
                          showSnackbar("Success", "Registered");
                        } catch (e) {
                          showSnackbar("Failure", e.toString());
                          rethrow;
                        } finally {
                          reregisteringIds.value = false;
                        }
                      },
                      trailing: Obx(() => reregisteringIds.value == null
                          ? const SizedBox.shrink()
                          : reregisteringIds.value == true ? Container(
                          constraints: const BoxConstraints(
                            maxHeight: 20,
                            maxWidth: 20,
                          ),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                          )) : Icon(Icons.check, color: context.theme.colorScheme.outline))
                      )
                  ]),
              if (kIsDesktop)
                const SizedBox(height: 100),
            ],
          ),
        ),
      ]
    );
  }
}
