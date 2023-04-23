import 'package:edifiercontrol/app/edifier.dart';
import 'package:edifiercontrol/app/layout.dart';
import 'package:edifiercontrol/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

final discoveryUuid = [Uuid.parse("00003800-0000-1000-8000-00805F9B34FB")];
final serviceUuid = Uuid.parse("48093801-1a48-11e9-ab14-d663bd873d93");
final rxUuid = Uuid.parse("48090001-1a48-11e9-ab14-d663bd873d93");
final txUuid = Uuid.parse("48090002-1a48-11e9-ab14-d663bd873d93");
List<int> cache = [];

void bleDiscovery() {
  final discoveryStream = flutterReactiveBle.scanForDevices(
      withServices: discoveryUuid, scanMode: ScanMode.lowLatency);
  scanSubscription.value = discoveryStream.listen(
    (device) {
      discoveredDevices[device.id] = device;
      if (kDebugMode) {
        print(
            '${device.name} ${device.id} ${device.manufacturerData} ${device.rssi} ${device.serviceData} ${device.serviceUuids}');
      }
    },
    onError: errorSnack,
    cancelOnError: true,
    onDone: bleStopDiscovery,
  );
  Future.delayed(const Duration(seconds: 2)).then((_) => bleStopDiscovery());
}

void bleStopDiscovery() {
  if (scanSubscription.value != null) scanSubscription.value!.cancel();
  scanSubscription.value = null;
}

void bleConnect() {
  if (selectedId.value != null) {
    connectionSubscription.value = flutterReactiveBle
        .connectToDevice(
      id: selectedId.value!,
      connectionTimeout: const Duration(seconds: 5),
    )
        .listen((connectionState) {
      if (kDebugMode) {
        print(connectionState.connectionState);
      }
      // Handle connection state updates
    }, onError: errorSnack, onDone: bleDisconnect);
  }
  bleSubscribe();
}

void bleDisconnect() {
  bleUnsubscribe();
  connectionSubscription.value?.cancel();
  connectionSubscription.value = null;
}

void bleSubscribe() {
  if (selectedId.value != null) {
    final characteristic = QualifiedCharacteristic(
        serviceId: serviceUuid,
        characteristicId: rxUuid,
        deviceId: selectedId.value!);
    characteristicSubscription.value = flutterReactiveBle
        .subscribeToCharacteristic(characteristic)
        .listen(bleHandleReceive, onError: errorSnack, onDone: bleDisconnect);
  }
  ediFetch();
}

void bleUnsubscribe() {
  characteristicSubscription.value?.cancel();
  characteristicSubscription.value = null;
}

void bleHandleReceive(List<int> data) {
  if (ediCheckCrc(data)) {
    return ediHandleNotify(data);
  } else if (data.length == 20) {
    cache = data;
  } else if (ediCheckCrc(cache + data)) {
    return ediHandleNotify(cache + data);
  }
}

Future<void> bleSend(List<int> data) async {
  if (selectedId.value != null && connectionSubscription.value != null) {
    if (kDebugMode) {
      print("Send: $data");
    }
    final characteristic = QualifiedCharacteristic(
        serviceId: serviceUuid,
        characteristicId: txUuid,
        deviceId: selectedId.value!);
    if (data.length <= 20) {
      await flutterReactiveBle
          .writeCharacteristicWithResponse(characteristic, value: data)
          .onError((error, stackTrace) => errorSnack);
    } else {
      await flutterReactiveBle
          .writeCharacteristicWithResponse(characteristic,
              value: data.sublist(0, 20))
          .onError((error, stackTrace) => errorSnack);
      await flutterReactiveBle
          .writeCharacteristicWithResponse(characteristic,
              value: data.sublist(20))
          .onError((error, stackTrace) => errorSnack);
    }
  }
}
