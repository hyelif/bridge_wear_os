package com.example.bridge_wear_os

import android.app.Service
import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.content.Context
import android.content.Intent
import android.os.Binder
import android.os.IBinder
import android.os.ParcelUuid
import android.util.Log
import java.util.*

class BridgeBluetoothService : Service() {
    private val tag = "BridgeBluetoothService"
    private var bluetoothManager: BluetoothManager? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothGattServer: BluetoothGattServer? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private val binder = LocalBinder()

    companion object {
        // Bridge Service UUIDs
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
        // Defer initialization to avoid crash on startup
        // The service will initialize when bound, not automatically
        Log.d(tag, "Service created, waiting for initialization")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        initializeBluetoothServer()
        return START_STICKY
    }

    private fun initializeBluetoothServer() {
        bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter

        if (bluetoothAdapter == null) {
            Log.e(tag, "Bluetooth adapter not available")
            return
        }

        if (!bluetoothAdapter!!.isEnabled) {
            Log.w(tag, "Bluetooth is not enabled")
            return
        }

        // Check if peripheral mode is supported (many Wear OS devices don't support this)
        if (!bluetoothAdapter?.isMultipleAdvertisementSupported!!) {
            Log.w(tag, "Peripheral mode not supported on this device")
            // Don't crash - just log and return
            return
        }

        startGattServer()
        startAdvertising()
    }

    @SuppressLint("MissingPermission")
    private fun startGattServer() {
        try {
            val gattServerCallback = object : BluetoothGattServerCallback() {
                override fun onConnectionStateChange(
                    device: BluetoothDevice?,
                    status: Int,
                    newState: Int
                ) {
                    super.onConnectionStateChange(device, status, newState)
                    Log.d(tag, "Connection state change: $newState from ${device?.address}")
                }

                override fun onCharacteristicReadRequest(
                    device: BluetoothDevice?,
                    requestId: Int,
                    offset: Int,
                    characteristic: BluetoothGattCharacteristic?
                ) {
                    super.onCharacteristicReadRequest(device, requestId, offset, characteristic)
                    Log.d(tag, "Read request from ${device?.address}")

                    val data = "Bridge Device Response".toByteArray()
                    bluetoothGattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, data)
                }

                override fun onCharacteristicWriteRequest(
                    device: BluetoothDevice?,
                    requestId: Int,
                    characteristic: BluetoothGattCharacteristic?,
                    preparedWrite: Boolean,
                    responseNeeded: Boolean,
                    offset: Int,
                    value: ByteArray?
                ) {
                    super.onCharacteristicWriteRequest(device, requestId, characteristic, preparedWrite, responseNeeded, offset, value)
                    Log.d(tag, "Write request from ${device?.address}: ${String(value ?: byteArrayOf())}")

                    if (responseNeeded) {
                        bluetoothGattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, null)
                    }
                }

                override fun onNotificationSent(device: BluetoothDevice?, status: Int) {
                    super.onNotificationSent(device, status)
                    Log.d(tag, "Notification sent to ${device?.address}, status: $status")
                }
            }

            bluetoothGattServer = bluetoothManager?.openGattServer(this, gattServerCallback)

            // Create Bridge Service
            val service = BluetoothGattService(
                UUID.fromString(BRIDGE_SERVICE_UUID),
                BluetoothGattService.SERVICE_TYPE_PRIMARY
            )

            // Create Write Characteristic
            val writeCharacteristic = BluetoothGattCharacteristic(
                UUID.fromString(BRIDGE_CHARACTERISTIC_UUID),
                BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_READ,
                BluetoothGattCharacteristic.PERMISSION_WRITE or BluetoothGattCharacteristic.PERMISSION_READ
            )

            // Create Notify Characteristic
            val notifyCharacteristic = BluetoothGattCharacteristic(
                UUID.fromString(NOTIFY_CHARACTERISTIC_UUID),
                BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                BluetoothGattCharacteristic.PERMISSION_READ
            )

            // Add Client Characteristic Configuration Descriptor for notifications
            val clientConfigDescriptor = BluetoothGattDescriptor(
                UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"),
                BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
            )
            notifyCharacteristic.addDescriptor(clientConfigDescriptor)

            service.addCharacteristic(writeCharacteristic)
            service.addCharacteristic(notifyCharacteristic)

            bluetoothGattServer?.addService(service)
            Log.d(tag, "Gatt server started")
        } catch (e: Exception) {
            Log.e(tag, "Error starting GATT server: ${e.message}")
        }
    }

    @SuppressLint("MissingPermission")
    private fun startAdvertising() {
        val advertiser = bluetoothAdapter?.bluetoothLeAdvertiser
        if (advertiser == null) {
            Log.e(tag, "BLE advertiser is not available")
            return
        }

        val advertiseSettings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(true)
            .build()

        val advertiseData = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .addServiceUuid(ParcelUuid(UUID.fromString(BRIDGE_SERVICE_UUID)))
            .build()

        advertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                super.onStartSuccess(settingsInEffect)
                Log.d(tag, "BLE advertising started successfully")
            }

            override fun onStartFailure(errorCode: Int) {
                super.onStartFailure(errorCode)
                Log.e(tag, "BLE advertising failed with error code: $errorCode")
            }
        }

        advertiser.startAdvertising(advertiseSettings, advertiseData, advertiseCallback)
    }

    @SuppressLint("MissingPermission")
    fun sendNotification(device: BluetoothDevice?, data: ByteArray) {
        if (bluetoothGattServer != null && device != null) {
            val service = bluetoothGattServer?.getService(UUID.fromString(BRIDGE_SERVICE_UUID))
            val characteristic = service?.getCharacteristic(UUID.fromString(NOTIFY_CHARACTERISTIC_UUID))

            if (characteristic != null) {
                characteristic.value = data
                bluetoothGattServer?.notifyCharacteristicChanged(device, characteristic, false)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        advertiseCallback?.let { callback ->
            bluetoothAdapter?.bluetoothLeAdvertiser?.stopAdvertising(callback)
        }
        bluetoothGattServer?.close()
    }
}
