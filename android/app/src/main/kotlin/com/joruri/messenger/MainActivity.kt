package com.joruri.joruri_messenger

import android.Manifest
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothStatusCodes
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.ParcelUuid
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "joruri_messenger/bluetooth"

        private val SERVICE_UUID =
            UUID.fromString("0000FEE0-0000-1000-8000-00805F9B34FB")

        private val CHARACTERISTIC_UUID =
            UUID.fromString("0000FEE1-0000-1000-8000-00805F9B34FB")

        private val DESCRIPTOR_UUID =
            UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")
    }

    private lateinit var methodChannel: MethodChannel

    private var bluetoothGattServer: BluetoothGattServer? = null
    private var bluetoothLeAdvertiser: BluetoothLeAdvertiser? = null

    // একাধিক ফোনের connection address অনুযায়ী রাখা হবে।
    private val connectedDevices =
        ConcurrentHashMap<String, BluetoothDevice>()

    private val subscribedDevices =
        ConcurrentHashMap.newKeySet<String>()

    private val characteristic: BluetoothGattCharacteristic by lazy {
        BluetoothGattCharacteristic(
            CHARACTERISTIC_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or
                BluetoothGattCharacteristic.PROPERTY_WRITE or
                BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE or
                BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ or
                BluetoothGattCharacteristic.PERMISSION_WRITE
        ).apply {
            addDescriptor(
                BluetoothGattDescriptor(
                    DESCRIPTOR_UUID,
                    BluetoothGattDescriptor.PERMISSION_READ or
                        BluetoothGattDescriptor.PERMISSION_WRITE
                )
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startAdvertising" -> {
                    startBluetoothServer()
                    result.success(true)
                }

                "stopAdvertising" -> {
                    stopBluetoothServer()
                    result.success(true)
                }

                "getBluetoothState" -> {
                    result.success(isBluetoothEnabled())
                }

                "sendMessage" -> {
                    val message = call.argument<String>("message")
                    val targetAddress =
                        call.argument<String>("targetAddress")

                    if (message.isNullOrEmpty()) {
                        result.error(
                            "INVALID_MESSAGE",
                            "Message is empty",
                            null
                        )
                    } else {
                        val sent = sendMessage(message, targetAddress)

                        if (sent) {
                            result.success(true)
                        } else {
                            result.error(
                                "SEND_FAILED",
                                "Message could not be delivered",
                                null
                            )
                        }
                    }
                }

                "disconnectDevice" -> {
                    val address =
                        call.argument<String>("address")

                    if (address.isNullOrEmpty()) {
                        result.error(
                            "INVALID_ADDRESS",
                            "Device address is missing",
                            null
                        )
                    } else {
                        disconnectDevice(address)
                        result.success(true)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun isBluetoothEnabled(): Boolean {
        return try {
            val manager =
                getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            manager.adapter?.isEnabled == true
        } catch (_: Exception) {
            false
        }
    }

    private fun hasBluetoothPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) ==
                PackageManager.PERMISSION_GRANTED &&
                checkSelfPermission(Manifest.permission.BLUETOOTH_ADVERTISE) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun emit(method: String, value: Any? = null) {
        runOnUiThread {
            methodChannel.invokeMethod(method, value)
        }
    }

    private fun emitError(message: String) {
        emit("bluetoothError", message)
    }

    private fun startBluetoothServer() {
        if (!isBluetoothEnabled()) {
            emitError("Bluetooth is turned off")
            return
        }

        if (!hasBluetoothPermission()) {
            emitError("Bluetooth permission is required")
            return
        }

        try {
            stopBluetoothServer()

            val manager =
                getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager

            val server = manager.openGattServer(this, gattServerCallback)

            if (server == null) {
                emitError("Could not open Bluetooth GATT server")
                return
            }

            bluetoothGattServer = server

            val service = BluetoothGattService(
                SERVICE_UUID,
                BluetoothGattService.SERVICE_TYPE_PRIMARY
            )

            service.addCharacteristic(characteristic)

            if (!server.addService(service)) {
                emitError("Could not add Bluetooth service")
                stopBluetoothServer()
                return
            }

            startAdvertising()
        } catch (e: Exception) {
            emitError(e.message ?: "Could not start Bluetooth server")
            stopBluetoothServer()
        }
    }

    private fun startAdvertising() {
        if (!hasBluetoothPermission()) {
            emitError("Bluetooth permission is required")
            return
        }

        try {
            val manager =
                getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager

            val advertiser: BluetoothLeAdvertiser? =
                manager.adapter.bluetoothLeAdvertiser

            if (advertiser == null) {
                emitError("BLE advertising is not supported on this phone")
                return
            }

            bluetoothLeAdvertiser = advertiser

            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(
                    AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY
                )
                .setTxPowerLevel(
                    AdvertiseSettings.ADVERTISE_TX_POWER_HIGH
                )
                .setConnectable(true)
                .setTimeout(0)
                .build()

            val data = AdvertiseData.Builder()
                .setIncludeDeviceName(false)
                .addServiceUuid(ParcelUuid(SERVICE_UUID))
                .build()

            advertiser.startAdvertising(
                settings,
                data,
                advertiseCallback
            )
        } catch (e: Exception) {
            emitError(e.message ?: "Could not start advertising")
        }
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(
            settingsInEffect: AdvertiseSettings?
        ) {
            emit("advertisingStarted")
        }

        override fun onStartFailure(errorCode: Int) {
            emitError("Advertising failed: $errorCode")
        }
    }

    private val gattServerCallback =
        object : BluetoothGattServerCallback() {

            override fun onConnectionStateChange(
                device: BluetoothDevice?,
                status: Int,
                newState: Int
            ) {
                if (device == null) return

                val address = try {
                    device.address
                } catch (_: SecurityException) {
                    return
                }

                if (newState == BluetoothProfile.STATE_CONNECTED &&
                    status == BluetoothGatt.GATT_SUCCESS
                ) {
                    connectedDevices[address] = device

                    emit("deviceConnected", address)
                } else if (
                    newState == BluetoothProfile.STATE_DISCONNECTED ||
                    status != BluetoothGatt.GATT_SUCCESS
                ) {
                    connectedDevices.remove(address)
                    subscribedDevices.remove(address)

                    emit("deviceDisconnected", address)
                }
            }

            override fun onDescriptorWriteRequest(
                device: BluetoothDevice?,
                requestId: Int,
                descriptor: BluetoothGattDescriptor?,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray?
            ) {
                if (device == null || descriptor == null) return

                var status = BluetoothGatt.GATT_SUCCESS

                if (descriptor.uuid == DESCRIPTOR_UUID) {
                    if (offset != 0 || value == null) {
                        status = BluetoothGatt.GATT_INVALID_OFFSET
                    } else {
                        descriptor.value = value

                        val address = try {
                            device.address
                        } catch (_: SecurityException) {
                            ""
                        }

                        val enabled =
                            value.contentEquals(
                                BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                            ) ||
                            value.contentEquals(
                                BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
                            )

                        if (address.isNotEmpty()) {
                            if (enabled) {
                                subscribedDevices.add(address)
                            } else {
                                subscribedDevices.remove(address)
                            }
                        }
                    }
                } else {
                    status = BluetoothGatt.GATT_FAILURE
                }

                if (responseNeeded) {
                    bluetoothGattServer?.sendResponse(
                        device,
                        requestId,
                        status,
                        offset,
                        value
                    )
                }
            }

            override fun onCharacteristicReadRequest(
                device: BluetoothDevice?,
                requestId: Int,
                offset: Int,
                characteristic: BluetoothGattCharacteristic?
            ) {
                if (device == null || characteristic == null) return

                val value = characteristic.value ?: byteArrayOf()

                bluetoothGattServer?.sendResponse(
                    device,
                    requestId,
                    if (characteristic.uuid == CHARACTERISTIC_UUID) {
                        BluetoothGatt.GATT_SUCCESS
                    } else {
                        BluetoothGatt.GATT_FAILURE
                    },
                    offset,
                    if (offset <= value.size) {
                        value.copyOfRange(offset, value.size)
                    } else {
                        byteArrayOf()
                    }
                )
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
                if (device == null || characteristic == null) return

                val valid =
                    characteristic.uuid == CHARACTERISTIC_UUID &&
                    value != null &&
                    offset == 0 &&
                    !preparedWrite

                if (valid) {
                    val address = try {
                        device.address
                    } catch (_: SecurityException) {
                        ""
                    }

                    val message = value!!.toString(Charsets.UTF_8)

                    // Dart-এ raw string নয়, message + source address পাঠাই।
                    emit(
                        "messageReceived",
                        mapOf(
                            "message" to message,
                            "address" to address
                        )
                    )
                }

                if (responseNeeded) {
                    bluetoothGattServer?.sendResponse(
                        device,
                        requestId,
                        if (valid) {
                            BluetoothGatt.GATT_SUCCESS
                        } else {
                            BluetoothGatt.GATT_FAILURE
                        },
                        offset,
                        value
                    )
                }
            }
        }

    private fun sendMessage(
        message: String,
        targetAddress: String?
    ): Boolean {
        if (!hasBluetoothPermission()) {
            emitError("Bluetooth permission is required")
            return false
        }

        val server = bluetoothGattServer

        if (server == null) {
            emitError("Bluetooth server is not running")
            return false
        }

        val targets = if (targetAddress != null) {
            listOfNotNull(connectedDevices[targetAddress])
        } else {
            connectedDevices.values.toList()
        }

        if (targets.isEmpty()) {
            emitError(
                if (targetAddress != null) {
                    "Target phone is not connected: $targetAddress"
                } else {
                    "No connected phone is available"
                }
            )
            return false
        }

        val payload = message.toByteArray(Charsets.UTF_8)
        var successCount = 0

        for (device in targets) {
            val address = try {
                device.address
            } catch (_: SecurityException) {
                continue
            }

            if (!subscribedDevices.contains(address)) {
                continue
            }

            try {
                val status = if (
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                ) {
                    server.notifyCharacteristicChanged(
                        device,
                        characteristic,
                        false,
                        payload
                    )
                } else {
                    @Suppress("DEPRECATION")
                    run {
                        characteristic.value = payload

                        if (
                            server.notifyCharacteristicChanged(
                                device,
                                characteristic,
                                false
                            )
                        ) {
                            BluetoothStatusCodes.SUCCESS
                        } else {
                            BluetoothStatusCodes.ERROR_UNKNOWN
                        }
                    }
                }

                if (status == BluetoothStatusCodes.SUCCESS) {
                    successCount++
                }
            } catch (e: Exception) {
                emitError(
                    "Send failed to $address: ${e.message ?: "unknown error"}"
                )
            }
        }

        if (successCount > 0) {
            emit("messageSent", message)
            return true
        }

        emitError(
            "No target phone has an active notification subscription"
        )
        return false
    }

    private fun disconnectDevice(address: String) {
        if (!hasBluetoothPermission()) return

        try {
            val manager =
                getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager

            val device = connectedDevices[address] ?: return
            manager.getConnectionState(device, BluetoothProfile.GATT)

            // GATT server side disconnect API is not directly exposed here.
            // The peer can disconnect from its own client connection.
        } catch (_: Exception) {
            // Ignore disconnect cleanup errors.
        }
    }

    private fun stopBluetoothServer() {
        try {
            if (
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                !hasBluetoothPermission()
            ) {
                return
            }

            bluetoothLeAdvertiser?.stopAdvertising(advertiseCallback)
        } catch (_: Exception) {
            // Continue to close the GATT server.
        }

        bluetoothLeAdvertiser = null

        try {
            bluetoothGattServer?.close()
        } catch (_: Exception) {
            // Ignore close errors.
        }

        bluetoothGattServer = null
        connectedDevices.clear()
        subscribedDevices.clear()
    }

    override fun onDestroy() {
        stopBluetoothServer()
        super.onDestroy()
    }
}
