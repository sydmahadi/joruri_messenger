package com.joruri.messenger

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
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
    }

    private lateinit var methodChannel: MethodChannel

    private var bluetoothGattServer: BluetoothGattServer? = null
    private var bluetoothLeAdvertiser: BluetoothLeAdvertiser? = null

    private var connectedDevice: BluetoothDevice? = null

    private val characteristic by lazy {
        BluetoothGattCharacteristic(
            CHARACTERISTIC_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or
                    BluetoothGattCharacteristic.PROPERTY_WRITE or
                    BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ or
                    BluetoothGattCharacteristic.PERMISSION_WRITE
        )
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
                    } else {
                        sendMessage(message)

                        result.success(true)
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isBluetoothEnabled(): Boolean {
        val manager =
            getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager

        val adapter: BluetoothAdapter? = manager.adapter

        return adapter?.isEnabled == true
    }

    private fun hasBluetoothPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            checkSelfPermission(
                Manifest.permission.BLUETOOTH_CONNECT
            ) == PackageManager.PERMISSION_GRANTED &&
                    checkSelfPermission(
                        Manifest.permission.BLUETOOTH_ADVERTISE
                    ) == PackageManager.PERMISSION_GRANTED
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

        val manager =
            getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager

        bluetoothGattServer =
            manager.openGattServer(
                this,
                gattServerCallback
            )

        val service =
            BluetoothGattService(
                SERVICE_UUID,
                BluetoothGattService.SERVICE_TYPE_PRIMARY
            )

        service.addCharacteristic(characteristic)

        bluetoothGattServer?.addService(service)

        startAdvertising()
    }

    private fun startAdvertising() {

        if (!hasBluetoothPermission()) {
            return
        }

        val adapter =
            (getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager)
                .adapter

        bluetoothLeAdvertiser =
            adapter.bluetoothLeAdvertiser

        if (bluetoothLeAdvertiser == null) {
            methodChannel.invokeMethod(
                "bluetoothError",
                "BLE advertising is not supported on this phone"
            )
            return
        }

        val settings =
            AdvertiseSettings.Builder()
                .setAdvertiseMode(
                    AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY
                )
                .setTxPowerLevel(
                    AdvertiseSettings.ADVERTISE_TX_POWER_HIGH
                )
                .setConnectable(true)
                .build()

        val data =
            AdvertiseData.Builder()
                .setIncludeDeviceName(true)
                .addServiceUuid(
                    android.os.ParcelUuid(SERVICE_UUID)
                )
                .build()

        bluetoothLeAdvertiser?.startAdvertising(
            settings,
            data,
            advertiseCallback
        )
    }

    private val advertiseCallback =
        object : AdvertiseCallback() {

            override fun onStartSuccess(
                settingsInEffect: AdvertiseSettings?
            ) {
                methodChannel.invokeMethod(
                    "advertisingStarted",
                    null
                )
            }

            override fun onStartFailure(errorCode: Int) {
                methodChannel.invokeMethod(
                    "bluetoothError",
                    "Advertising failed: $errorCode"
                )
            }
        }

    private val gattServerCallback =
        object : BluetoothGattServerCallback() {

            override fun onConnectionStateChange(
                device: BluetoothDevice?,
                status: Int,
                newState: Int
            ) {
                super.onConnectionStateChange(
                    device,
                    status,
                    newState
                )

                if (newState ==
                    android.bluetooth.BluetoothProfile.STATE_CONNECTED
                ) {
                    connectedDevice = device

                    methodChannel.invokeMethod(
                        "deviceConnected",
                        device?.address
                    )
                }

                if (newState ==
                    android.bluetooth.BluetoothProfile.STATE_DISCONNECTED
                ) {
                    if (connectedDevice?.address ==
                        device?.address
                    ) {
                        connectedDevice = null
                    }

                    methodChannel.invokeMethod(
                        "deviceDisconnected",
                        device?.address
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

                if (characteristic?.uuid ==
                    CHARACTERISTIC_UUID
                ) {

                    val message =
                        value?.toString(Charsets.UTF_8)
                            ?: ""

                    methodChannel.invokeMethod(
                        "messageReceived",
                        message
                    )

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

        val device = connectedDevice

        if (device == null) {
            methodChannel.invokeMethod(
                "bluetoothError",
                "No device is connected"
            )
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (
                checkSelfPermission(
                    Manifest.permission.BLUETOOTH_CONNECT
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                return
            }
        }

        characteristic.value =
            message.toByteArray(Charsets.UTF_8)

        val success =
            bluetoothGattServer?.notifyCharacteristicChanged(
                device,
                characteristic,
                false
            )

        if (success == true) {
            methodChannel.invokeMethod(
                "messageSent",
                message
            )
        }
    }

    private fun stopBluetoothServer() {

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (
                checkSelfPermission(
                    Manifest.permission.BLUETOOTH_ADVERTISE
                ) != PackageManager.PERMISSION_GRANTED ||
                checkSelfPermission(
                    Manifest.permission.BLUETOOTH_CONNECT
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                return
            }
        }

        bluetoothLeAdvertiser?.stopAdvertising(
            advertiseCallback
        )

        bluetoothLeAdvertiser = null

        bluetoothGattServer?.close()

        bluetoothGattServer = null
        connectedDevice = null
    }

    override fun onDestroy() {
        stopBluetoothServer()

        super.onDestroy()
    }
}
