package com.example.bridge_wear_os

import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.IBinder
import android.util.Log

/**
 * Placeholder BLE GATT server service.
 *
 * This app acts as a BLE CENTRAL (scanner/connector), not a peripheral.
 * This service is retained as a placeholder for future use if the device
 * ever needs to act as a GATT server. It does NOT start a GATT server or
 * advertise — those operations are removed because many Wear OS devices
 * do not support peripheral mode.
 *
 * To activate this service in the future, start it explicitly from Dart:
 *   val intent = Intent(this, BridgeBluetoothService::class.java)
 *   startService(intent)
 */
class BridgeBluetoothService : Service() {
    private val tag = "BridgeBluetoothService"
    private val binder = LocalBinder()

    companion object {
        // Bridge Service UUIDs (reserved for future GATT server use)
        const val BRIDGE_SERVICE_UUID = "12345678-1234-5678-1234-56789012345a"
        const val BRIDGE_CHARACTERISTIC_UUID = "12345678-1234-5678-1234-56789012345b"
        const val NOTIFY_CHARACTERISTIC_UUID = "12345678-1234-5678-1234-56789012345c"
    }

    inner class LocalBinder : Binder() {
        fun getService(): BridgeBluetoothService = this@BridgeBluetoothService
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        Log.d(tag, "Service created (placeholder — no GATT server started)")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(tag, "Service started (placeholder — no GATT server started)")
        return START_STICKY
    }

    /**
     * Placeholder for future notification support.
     * Currently a no-op since this service does not run a GATT server.
     */
    fun sendNotification(device: android.bluetooth.BluetoothDevice?, data: ByteArray) {
        Log.d(tag, "sendNotification called but GATT server is not active (placeholder)")
    }

    override fun onDestroy() {
        Log.d(tag, "Service destroyed")
        super.onDestroy()
    }
}
