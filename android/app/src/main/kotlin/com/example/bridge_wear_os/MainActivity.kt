package com.example.bridge_wear_os

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Note: BridgeBluetoothService should only be started when the device
        // needs to act as a BLE peripheral (server). Many Wear OS devices
        // don't support peripheral mode, so auto-starting causes crashes.
        //
        // To enable peripheral mode, start the service explicitly from Dart:
        // final serviceIntent = Intent(Intent.ACTION_VIEW).setClassName(
        //     "com.example.bridge_wear_os",
        //     "com.example.bridge_wear_os.BridgeBluetoothService"
        // );
        // startService(serviceIntent);
    }
}
