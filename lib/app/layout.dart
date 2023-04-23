import 'dart:async';
import 'dart:convert';
import 'package:edifiercontrol/app/bluetooth.dart';
import 'package:edifiercontrol/app/edifier.dart';
import 'package:edifiercontrol/app/textFieldChar.dart';
import 'package:edifiercontrol/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get/get.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ObxValue(
                  (data) => DropdownButton<DiscoveredDevice>(
                      hint: data.isEmpty
                          ? const Text("Start Scan")
                          : const Text("Select device"),
                      value:
                          data.isNotEmpty ? data.value[selectedId.value] : null,
                      items: data.entries
                          .map((e) => DropdownMenuItem(
                              value: e.value,
                              child: Text("${e.value.name} [${e.value.id}]")))
                          .toList(),
                      onChanged: (v) {
                        selectedId.value = v?.id;
                      }),
                  discoveredDevices,
                ),
                ObxValue(
                  (sub) => ElevatedButton(
                      onPressed: connectionSubscription.value == null
                          ? sub.value == null
                              ? bleDiscovery
                              : bleStopDiscovery
                          : null,
                      child: sub.value == null
                          ? const Text("Scan")
                          : const Text("Stop")),
                  scanSubscription,
                )
              ],
            ),
          ),
          Center(
            child: Obx(
              () => ElevatedButton(
                onPressed: connectionSubscription.value != null
                    ? bleDisconnect
                    : selectedId.value == null
                        ? null
                        : bleConnect,
                child: connectionSubscription.value != null
                    ? Text("Disconnect from [$selectedId]")
                    : selectedId.value == null
                        ? const Text("Select device")
                        : Text("Connect to [$selectedId]"),
              ),
            ),
          ),
          ObxValue(
            (volume) => Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Prompt volume:"),
                  Slider(
                    value: volume.value.toDouble(),
                    min: 0,
                    max: 15,
                    divisions: 15,
                    onChanged: (d) {
                      volume.value = d.toInt();
                    },
                    onChangeEnd: (d) {
                      volume.value = d.toInt();
                      bleSend(ediPacket(cmd: 0x06, data: [d.toInt()]));
                    },
                  ),
                  Text("$volume"),
                ],
              ),
            ),
            ediPromptVolume,
          ),
          ObxValue(
            (mode) => Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Game Mode"),
                  Switch(
                    value: mode.value,
                    onChanged: (v) {
                      mode.value = v;
                      bleSend(ediPacket(cmd: 0x09, data: [v ? 1 : 0]));
                    },
                  ),
                ],
              ),
            ),
            ediGameMode,
          ),
          ObxValue(
            (mode) {
              void onChanged(int? v) {
                mode.value = v ?? 1;
                bleSend(ediPacket(cmd: 0xc1, data: [mode.value]));
              }

              return Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Mode:"),
                    Column(
                      children: [
                        Radio(
                            value: 1,
                            groupValue: mode.value,
                            onChanged: onChanged),
                        const Text("Off"),
                      ],
                    ),
                    Column(
                      children: [
                        Radio(
                            value: 2,
                            groupValue: mode.value,
                            onChanged: onChanged),
                        const Text("ANC"),
                      ],
                    ),
                    Column(
                      children: [
                        Radio(
                            value: 3,
                            groupValue: mode.value,
                            onChanged: onChanged),
                        const Text("Ambient"),
                      ],
                    ),
                    if (mode.value == 3)
                      Column(
                        children: [
                          Slider(
                            value: ediAmbientVolume.value.toDouble(),
                            min: 3,
                            max: 9,
                            divisions: 6,
                            onChanged: (d) {
                              ediAmbientVolume.value = d.toInt();
                            },
                            onChangeEnd: (d) {
                              ediAmbientVolume.value = d.toInt();
                              bleSend(ediPacket(
                                  cmd: 0xc1, data: [mode.value, d.toInt()]));
                            },
                          ),
                          Text("${ediAmbientVolume.value - 6}"),
                        ],
                      )
                  ],
                ),
              );
            },
            ediAncAmbientMode,
          ),
          ObxValue(
            (name) {
              final TextEditingController utf8TextController =
                  ediBtName.value == null
                      ? TextEditingController()
                      : TextEditingController(
                          text: utf8.decode(ediBtName.value!,
                              allowMalformed: true),
                        );
              return Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    const Text("Name"),
                    const Spacer(),
                    Expanded(
                      flex: 8,
                      child: TextFormField(
                        controller: utf8TextController,
                        maxLength: 35,
                        inputFormatters: [
                          Utf8LengthLimitingTextInputFormatter(35),
                        ],
                        buildCounter: (context,
                            {required currentLength,
                            required isFocused,
                            maxLength}) {
                          int utf8Length =
                              utf8.encode(utf8TextController.text).length;
                          return Text(
                            '$utf8Length/$maxLength',
                            style: Theme.of(context).textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                        onPressed: () {
                          ediBtName.value =
                              utf8.encode(utf8TextController.text);
                          bleSend(ediPacket(cmd: 0xca, data: ediBtName.value!));
                        },
                        child: const Text("Set")),
                    const Spacer(),
                  ],
                ),
              );
            },
            ediBtName,
          ),
          ObxValue(
            (time) => Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Timer"),
                  Slider(
                    value: time.value.toDouble(),
                    min: 0,
                    max: 180,
                    divisions: 18,
                    onChanged: (d) {
                      time.value = d.toInt();
                    },
                    onChangeEnd: (d) {
                      time.value = d.toInt();
                    },
                  ),
                  Text("$time"),
                  Switch(
                    value: ediTimerOn.value,
                    onChanged: (v) {
                      if (ediTimerOn.isTrue) {
                        ediTimerOn.value = v;
                        bleSend(ediPacket(cmd: 0xd2));
                      } else if (time.value > 0) {
                        ediTimerOn.value = v;
                        bleSend(
                          ediPacket(
                            cmd: 0xd1,
                            data: [
                              (time.value & 0xff00) >> 8,
                              time.value & 0xff
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            ediTimerTime,
          ),
          ObxValue(
            (sub) {
              if (sub.value == null) {
                batteryTimer.value?.cancel();
                batteryTimer.value = null;
              }
              return Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Battery fetch"),
                    Switch(
                      value: batteryTimer.value != null,
                      onChanged: (v) {
                        if (v) {
                          batteryTimer.value = Timer.periodic(
                            const Duration(seconds: 15),
                            (_) => bleSend(ediPacket(cmd: 0xd0)),
                          );
                        } else {
                          batteryTimer.value?.cancel();
                          batteryTimer.value = null;
                        }
                      },
                    ),
                    ElevatedButton(
                      onPressed: sub.value != null ? ediFetch : null,
                      child: const Text(
                        "Fetch all",
                      ),
                    ),
                  ],
                ),
              );
            },
            characteristicSubscription,
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ObxValue((v) => Text("Battery: $v %"), ediBattery),
                ObxValue((v) => Text("Playback state: $v"), ediPlayState),
                ObxValue((v) => Text("Firmware version: $v"), ediFW),
                ObxValue((v) => Text("MAC: $v"), ediMAC),
                ObxValue((v) => Text("FP: $v"), ediFP),
              ],
            ),
          ),
          Obx(
            () => Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Track: "),
                  Text(
                    ((ediTrackAuthor.value?.isNotEmpty ?? false)
                            ? utf8.decode(ediTrackAuthor.value!,
                                allowMalformed: true)
                            : "") +
                        (((ediTrackAuthor.value?.isNotEmpty ?? false) &&
                                (ediTrackTitle.value?.isNotEmpty ?? false))
                            ? " - "
                            : "") +
                        ((ediTrackTitle.value?.isNotEmpty ?? false)
                            ? utf8.decode(ediTrackTitle.value!,
                                allowMalformed: true)
                            : ""),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                QuestionButton(
                    callback: () => bleSend(ediPacket(cmd: 0x07)),
                    caption: "Factory Reset"),
                QuestionButton(
                    callback: () => bleSend(ediPacket(cmd: 0xcf)),
                    caption: "Pairing"),
              ],
            ),
          ),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                QuestionButton(
                    callback: () => bleSend(ediPacket(cmd: 0xce)),
                    caption: "Power Off"),
                QuestionButton(
                    callback: () => bleSend(ediPacket(cmd: 0xcd)),
                    caption: "Disconnect"),
              ],
            ),
          ),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                    onPressed: () =>
                        bleSend(ediPacket(cmd: 0xc2, data: [0x01])),
                    child: const Icon(Icons.pause)),
                ElevatedButton(
                    onPressed: () =>
                        bleSend(ediPacket(cmd: 0xc2, data: [0x00])),
                    child: const Icon(Icons.play_arrow)),
              ],
            ),
          ),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                    onPressed: () =>
                        bleSend(ediPacket(cmd: 0xc2, data: [0x03])),
                    child: const Icon(Icons.volume_down)),
                ElevatedButton(
                    onPressed: () =>
                        bleSend(ediPacket(cmd: 0xc2, data: [0x02])),
                    child: const Icon(Icons.volume_up)),
              ],
            ),
          ),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                    onPressed: () =>
                        bleSend(ediPacket(cmd: 0xc2, data: [0x05])),
                    child: const Icon(Icons.skip_previous)),
                ElevatedButton(
                    onPressed: () =>
                        bleSend(ediPacket(cmd: 0xc2, data: [0x04])),
                    child: const Icon(Icons.skip_next)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QuestionButton extends StatelessWidget {
  const QuestionButton(
      {super.key, required this.callback, required this.caption, this.child});

  final VoidCallback callback;
  final String caption;
  final Widget? child;

  @override
  Widget build(context) {
    return ElevatedButton(
        onPressed: () => Get.dialog(
              AlertDialog(
                title: Text(caption),
                content: Text("Would you like to $caption?"),
                actions: [
                  ElevatedButton(
                    child: const Text("Cancel"),
                    onPressed: () => Get.back(),
                  ),
                  ElevatedButton(
                    child: const Text("Continue"),
                    onPressed: () {
                      callback();
                      Get.back();
                    },
                  ),
                ],
              ),
            ),
        child: child ?? Text(caption));
  }
}

void errorSnack(e) {
  bleDisconnect();
  Get.snackbar("Error", e.toString());
}

void messageSnack(String s) => Get.snackbar("Message", s);
