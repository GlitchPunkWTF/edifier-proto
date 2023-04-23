import 'package:edifiercontrol/app/bluetooth.dart';
import 'package:edifiercontrol/app/layout.dart';
import 'package:edifiercontrol/main.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

int ediMagicCrc = 0x2019;
const delayTime = Duration(milliseconds: 50);

Future<void> ediFetch() async {
  await bleSend(ediPacket(cmd: 0x05));
  await Future.delayed(delayTime);
  await bleSend(ediPacket(cmd: 0x08));
  await Future.delayed(delayTime);
  await bleSend(ediPacket(cmd: 0xc3));
  await Future.delayed(delayTime);
  await bleSend(ediPacket(cmd: 0xc6));
  await Future.delayed(delayTime);
  await bleSend(ediPacket(cmd: 0xc8));
  await Future.delayed(delayTime);
  await bleSend(ediPacket(cmd: 0xc9));
  await Future.delayed(delayTime);
  await bleSend(ediPacket(cmd: 0xcc));
  await Future.delayed(delayTime);
  await bleSend(ediPacket(cmd: 0xd0));
  await Future.delayed(delayTime);
  await bleSend(ediPacket(cmd: 0xd3));
  await Future.delayed(delayTime);
  await bleSend(ediPacket(cmd: 0xd8));
}

List<int> ediPacket(
    {int init = 0xaa, required int cmd, List<int> data = const []}) {
  final len = data.length + 1;
  final payload = [init, len, cmd] + data;
  return payload + ediCrc(payload);
}

List<int> ediCrc(List<int> value) {
  var sum = value.sum + ediMagicCrc;
  return [(sum & 0xff00) >> 8, sum & 0xff];
}

bool ediCheckCrc(List<int> value) {
  final a = ediCrc(value.sublist(0, value.length - 2));
  final b = value.sublist(value.length - 2);
  return (a[0] == b[0]) && (a[1] == b[1]);
}

void ediHandleNotify(List<int> packet) {
  if (kDebugMode) {
    print("Recv: $packet");
  }
  final data = packet.sublist(3, packet.length - 2);
  if (packet[2] == 0x01) {
    // title
    ediTrackTitle.value = data;
  } else if (packet[2] == 0x02) {
    // author
    ediTrackAuthor.value = data;
  } else if (packet[2] == 0x05 || packet[2] == 0x06) {
    // prompt volume
    ediPromptVolume.value = data[0];
  } else if (packet[2] == 0x07) {
    // factory reset
    messageSnack("factory reset: $data");
  } else if (packet[2] == 0x08 || packet[2] == 0x09) {
    // game mode
    ediGameMode.value = data[0] > 0;
  } else if (packet[2] == 0xc1 || packet[2] == 0xcc) {
    // ANC mode
    ediAncAmbientMode.value = data[0];
    ediAmbientVolume.value = data[1];
  } else if (packet[2] == 0xc3) {
    // playback state
    ediPlayState.value = data[0] == 0x0d
        ? 'play'
        : data[0] == 0x03
            ? 'pause'
            : "${data[0]}";
  } else if (packet[2] == 0xc6) {
    // FW
    ediFW.value = "${data[0]}.${data[1]}.${data[2]}";
  } else if (packet[2] == 0xc8) {
    // MAC
    ediMAC.value = data
        .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
        .toList()
        .toString()
        .replaceAll(",", ":")
        .removeAllWhitespace;
  } else if (packet[2] == 0xc9 || packet[2] == 0xca) {
    // dev name
    if (packet[2] == 0xc9) ediBtName.value = data;
    if (packet[2] == 0xca && data[0] == 0x01) {
      bleSend(ediPacket(cmd: 0xc9));
    }
  } else if (packet[2] == 0xd0) {
    // battery
    ediBattery.value = data[0];
  } else if (packet[2] == 0xd1 || packet[2] == 0xd2 || packet[2] == 0xd3) {
    // timer
    if (packet[2] == 0xd1 || packet[2] == 0xd2) {
      bleSend(ediPacket(cmd: 0xd3));
    }
    if (packet[2] == 0xd3) {
      if (data.length == 1) {
        ediTimerOn.value = false;
        ediTimerTime.value = data[0];
      }
      if (data.length == 2) {
        ediTimerOn.value = true;
        ediTimerTime.value = (data[0] << 8) | data[1];
      }
    }
  } else if (packet[2] == 0xd5) {
    // some acknowledge
    messageSnack("game mode toggled");
  } else if (packet[2] == 0xd8) {
    // fingerprint
    ediFP.value = data
        .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
        .toList()
        .toString()
        .replaceAll(",", ":")
        .removeAllWhitespace;
  }
}
