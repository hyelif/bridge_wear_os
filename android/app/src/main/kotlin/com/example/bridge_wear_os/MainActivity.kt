package com.example.bridge_wear_os

import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.bridge.wear_os/platform"

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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getSdkInt") {
                result.success(Build.VERSION.SDK_INT)
            } else {
                result.notImplemented()
            }
        }
    }
}
