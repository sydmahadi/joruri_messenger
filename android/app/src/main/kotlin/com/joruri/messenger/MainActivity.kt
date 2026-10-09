
package com.joruri.joruri_messenger

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "joruri_messenger/bluetooth"

        private val SERVICE_UUID: UUID =
            UUID.fromString("0000FEE0-0000-1000-8000-00805F9B34FB")

        private val CHARACTERISTIC_UUID: UUID =
            UUID.fromString("0000FEE1-0000-1000-8000-00805F9B34FB")

        private val DESCRIPTOR_UUID: UUID =
            UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")
    }

    private lateinit var methodChannel: MethodChannel

    private var bluetoothGattServer: BluetoothGattServer? = null
    private var bluetoothLeAdvertiser: BluetoothLeAdvertiser? = null
    private var connectedDevice: BluetoothDevice? = null

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

                    if (message.isNullOrEmpty()) {
                        result.error(
                            "INVALID_MESSAGE",
                            "Message is empty",
                            null
                        )
                    } else if (connectedDevice == null) {
                        result.error(
                            "NOT_CONNECTED",
                            "No device is connected",
                            null
                        )
                    } else {
                        sendMessage(message)
                        result.success(true)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun isBluetoothEnabled(): Boolean {
        val manager =
            getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager

        return try {
            manager.adapter?.isEnabled == true
        } catch (_: SecurityException) {
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

    private fun startBluetoothServer() {
        if (!isBluetoothEnabled()) {
            methodChannel.invokeMethod(
                "bluetoothError",
                "Bluetooth is turned off"
            )
            return
        }

        if (!hasBluetoothPermission()) {
            methodChannel.invokeMethod(
                "bluetoothError",
                "Bluetooth permission is required"
            )
            return
        }

        try {
            stopBluetoothServer()

            val manager =
                getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager

            val server = manager.openGattServer(this, gattServerCallback)

            if (server == null) {
                methodChannel.invokeMethod(
                    "bluetoothError",
                    "Could not open Bluetooth server"
                )
                return
            }

            bluetoothGattServer = server

            val service = BluetoothGattService(
                SERVICE_UUID,
                BluetoothGattService.SERVICE_TYPE_PRIMARY
            )

            service.addCharacteristic(characteristic)

            val added = server.addService(service)
            if (!added) {
                methodChannel.invokeMethod(
                    "bluetoothError",
                    "Could not add Bluetooth service"
                )
                stopBluetoothServer()
                return
            }

            startAdvertising()
        } catch (e: SecurityException) {
            methodChannel.invokeMethod(
                "bluetoothError",
                "Bluetooth permission denied"
            )
        } catch (e: Exception) {
            methodChannel.invokeMethod(
                "bluetoothError",
                e.message ?: "Could not start Bluetooth server"
            )
        }
    }

    private fun startAdvertising() {
        if (!hasBluetoothPermission()) return

        try {
            val adapter =
                (getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager)
                    .adapter

            val advertiser: BluetoothLeAdvertiser? =
                adapter.bluetoothLeAdvertiser

            if (advertiser == null) {
                methodChannel.invokeMethod(
                    "bluetoothError",
                    "BLE advertising is not supported on this phone"
                )
                return
            }

            bluetoothLeAdvertiser = advertiser

            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
                .setConnectable(true)
                .setTimeout(0)
                .build()

            val data = AdvertiseData.Builder()
                .setIncludeDeviceName(false)
                .addServiceUuid(android.os.ParcelUuid(SERVICE_UUID))
                .build()

            advertiser.startAdvertising(settings, data, advertiseCallback)
        } catch (e: SecurityException) {
            methodChannel.invokeMethod(
                "bluetoothError",
                "Bluetooth permission denied"
            )
        } catch (e: Exception) {
            methodChannel.invokeMethod(
                "bluetoothError",
                e.message ?: "Could not start advertising"
            )
        }
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            runOnUiThread {
                methodChannel.invokeMethod("advertisingStarted", null)
            }
        }

        override fun onStartFailure(errorCode: Int) {
            runOnUiThread {
                methodChannel.invokeMethod(
                    "bluetoothError",
                    "Advertising failed: $errorCode"
                )
            }
        }
    }

    private val gattServerCallback = object : BluetoothGattServerCallback() {

        override fun onConnectionStateChange(
            device: BluetoothDevice?,
            status: Int,
            newState: Int
        ) {
            super.onConnectionStateChange(device, status, newState)

            if (device == null) return

            if (newState == BluetoothProfile.STATE_CONNECTED) {
                connectedDevice = device

                runOnUiThread {
                    methodChannel.invokeMethod(
                        "deviceConnected",
                        device.address
                    )
                }
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                if (connectedDevice?.address == device.address) {
                    connectedDevice = null
                }

                runOnUiThread {
                    methodChannel.invokeMethod(
                        "deviceDisconnected",
                        device.address
                    )
                }
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
            super.onDescriptorWriteRequest(
                device,
                requestId,
                descriptor,
                preparedWrite,
                responseNeeded,
                offset,
                value
            )

            if (descriptor?.uuid == DESCRIPTOR_UUID) {
                descriptor.value = value

                if (responseNeeded) {
                    bluetoothGattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
                        offset,
                        value
                    )
                }
            }
        }

        override fun onCharacteristicReadRequest(
            device: BluetoothDevice?,
            requestId: Int,
            offset: Int,
            characteristic: BluetoothGattCharacteristic?
        ) {
            super.onCharacteristicReadRequest(
                device,
                requestId,
                offset,
                characteristic
            )

            if (characteristic?.uuid == CHARACTERISTIC_UUID) {
                bluetoothGattServer?.sendResponse(
                    device,
                    requestId,
                    BluetoothGatt.GATT_SUCCESS,
                    offset,
                    characteristic.value ?: byteArrayOf()
                )
            }
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
            super.onCharacteristicWriteRequest(
                device,
                requestId,
                characteristic,
                preparedWrite,
                responseNeeded,
                offset,
                value
            )

            if (characteristic?.uuid == CHARACTERISTIC_UUID) {
                val message = value?.toString(Charsets.UTF_8) ?: ""

                runOnUiThread {
                    methodChannel.invokeMethod("messageReceived", message)
                }

                if (responseNeeded) {
                    bluetoothGattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
                        offset,
                        value
                    )
                }
            }
        }
    }

    private fun sendMessage(message: String) {
        val device = connectedDevice ?: run {
            methodChannel.invokeMethod(
                "bluetoothError",
                "No device is connected"
            )
            return
        }

        if (!hasBluetoothPermission()) {
            methodChannel.invokeMethod(
                "bluetoothError",
                "Bluetooth permission is required"
            )
            return
        }

        val server = bluetoothGattServer ?: run {
            methodChannel.invokeMethod(
                "bluetoothError",
                "Bluetooth server is not running"
            )
            return
        }

        try {
            characteristic.value = message.toByteArray(Charsets.UTF_8)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val status = server.notifyCharacteristicChanged(
                    device,
                    characteristic,
                    false
                )

                if (status == BluetoothGatt.GATT_SUCCESS) {
                    methodChannel.invokeMethod("messageSent", message)
                } else {
                    methodChannel.invokeMethod(
                        "bluetoothError",
                        "Message send failed: $status"
                    )
                }
            } else {
                @Suppress("DEPRECATION")
                val success = server.notifyCharacteristicChanged(
                    device,
                    characteristic,
                    false
                )

                if (success) {
                    methodChannel.invokeMethod("messageSent", message)
                } else {
                    methodChannel.invokeMethod(
                        "bluetoothError",
                        "Message send failed"
                    )
                }
            }
        } catch (e: SecurityException) {
            methodChannel.invokeMethod(
                "bluetoothError",
                "Bluetooth permission denied"
            )
        } catch (e: Exception) {
            methodChannel.invokeMethod(
                "bluetoothError",
                e.message ?: "Message send failed"
            )
        }
    }

    private fun stopBluetoothServer() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                !hasBluetoothPermission()
            ) {
                return
            }

            bluetoothLeAdvertiser?.stopAdvertising(advertiseCallback)
            bluetoothLeAdvertiser = null

            bluetoothGattServer?.close()
            bluetoothGattServer = null
            connectedDevice = null
        } catch (_: SecurityException) {
            bluetoothLeAdvertiser = null
            bluetoothGattServer = null
            connectedDevice = null
        } catch (_: Exception) {
            bluetoothLeAdvertiser = null
            bluetoothGattServer = null
            connectedDevice = null
        }
    }

    override fun onDestroy() {
        stopBluetoothServer()
        super.onDestroy()
    }
}
