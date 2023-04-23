import 'dart:async';
import 'package:edifiercontrol/app/layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

final flutterReactiveBle = FlutterReactiveBle();
final discoveredDevices = <String, DiscoveredDevice>{}.obs;
final selectedId = Rxn<String>();
final scanSubscription = Rxn<StreamSubscription<DiscoveredDevice>>();
final connectionSubscription = Rxn<StreamSubscription<ConnectionStateUpdate>>();
final characteristicSubscription = Rxn<StreamSubscription<List<int>>>();
final batteryTimer = Rxn<Timer>();
final ediTrackTitle = Rxn<List<int>>();
final ediTrackAuthor = Rxn<List<int>>();
final ediPromptVolume = 0.obs;
final ediGameMode = false.obs;
final ediAncAmbientMode = 1.obs;
final ediAmbientVolume = 6.obs;
final ediBtName = Rxn<List<int>>();
final ediTimerTime = 0.obs;
final ediTimerOn = false.obs;
final ediBattery = 0.obs;
final ediPlayState = "".obs;
final ediFW = "".obs;
final ediMAC = "".obs;
final ediFP = "".obs;

void main() async {
  runApp(const GetMaterialApp(home: Home()));
  await Permission.bluetoothScan.request();
  await Permission.bluetoothConnect.request();
}
