package com.example.bridge_wear_os

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onStart() {
        super.onStart()
        // Start the Bridge Bluetooth service
        val intent = Intent(this, BridgeBluetoothService::class.java)
        startService(intent)
    }
}
