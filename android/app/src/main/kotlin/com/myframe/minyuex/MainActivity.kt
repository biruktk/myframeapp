package com.myframe.minyuex

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult as BleScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val methodChannelName = "myframe/native_ble/methods"
    private val eventChannelName = "myframe/native_ble/events"
    private val mainHandler = Handler(Looper.getMainLooper())

    private var scanner: BluetoothLeScanner? = null
    private var callback: ScanCallback? = null
    private var eventSink: EventChannel.EventSink? = null
    private var nativeScanning = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "startNativeBleScan" -> result.success(startNativeBleScan())
                    "stopNativeBleScan" -> {
                        stopNativeBleScan()
                        result.success(true)
                    }
                    "isNativeBleScanning" -> result.success(nativeScanning)
                    "scanWifiNetworks" -> {
                        // Async: startScan results arrive via broadcast — do not block UI thread.
                        scanWifiNetworksAsync { list ->
                            mainHandler.post { result.success(list) }
                        }
                    }
                    "getWifiInfo" -> result.success(getWifiInfo())
                    else -> result.notImplemented()
                }
            }
    }

    private fun startNativeBleScan(): Boolean {
        if (nativeScanning) return true
        if (!hasScanPermission()) return false
        val adapter = bluetoothAdapter() ?: return false
        if (!adapter.isEnabled) return false
        scanner = adapter.bluetoothLeScanner ?: return false

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: BleScanResult?) {
                if (result == null) return
                emitResult(result)
            }

            override fun onBatchScanResults(results: MutableList<BleScanResult>?) {
                results?.forEach { emitResult(it) }
            }

            override fun onScanFailed(errorCode: Int) {
                eventSink?.success(
                    mapOf(
                        "type" to "error",
                        "message" to "native_scan_failed:$errorCode"
                    )
                )
            }
        }

        return try {
            scanner?.startScan(null, settings, callback)
            nativeScanning = true
            true
        } catch (_: Throwable) {
            nativeScanning = false
            false
        }
    }

    private fun stopNativeBleScan() {
        try {
            if (callback != null) {
                scanner?.stopScan(callback)
            }
        } catch (_: Throwable) {
        } finally {
            callback = null
            nativeScanning = false
        }
    }

    private fun emitResult(scanResult: BleScanResult) {
        val device = scanResult.device ?: return
        val scanRecord = scanResult.scanRecord
        // Advertised GAP name (e.g. "my ink_joy_frame_161c") lives on the scan record, not BluetoothDevice.name.
        val advertised = scanRecord?.deviceName?.trim().orEmpty()
        val resolvedName = when {
            advertised.isNotEmpty() -> advertised
            !device.name.isNullOrBlank() -> device.name!!.trim()
            else -> ""
        }
        val svcList = scanRecord?.serviceUuids?.map { it.uuid.toString() } ?: emptyList()
        val payload = mapOf(
            "type" to "result",
            "id" to (device.address ?: ""),
            "name" to resolvedName,
            "rssi" to scanResult.rssi,
            "hasRecord" to (scanRecord != null),
            "serviceUuids" to svcList
        )
        eventSink?.success(payload)
    }

    private fun bluetoothAdapter(): BluetoothAdapter? {
        val manager = getSystemService(BLUETOOTH_SERVICE) as? BluetoothManager ?: return null
        return manager.adapter
    }

    private fun hasScanPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
                ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun hasWifiScanPermission(): Boolean {
        val hasWifiState = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_WIFI_STATE
        ) == PackageManager.PERMISSION_GRANTED
        if (!hasWifiState) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val nearby = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.NEARBY_WIFI_DEVICES
            ) == PackageManager.PERMISSION_GRANTED
            val fine = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
            return nearby || fine
        }
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun collectWifiResults(wifiManager: WifiManager): List<Map<String, Any>> {
        return try {
            wifiManager.scanResults
                .asSequence()
                .filter { !it.SSID.isNullOrBlank() && it.SSID != "<unknown ssid>" }
                .sortedByDescending { it.level }
                .distinctBy { it.SSID }
                .take(40)
                .map {
                    mapOf(
                        "ssid" to it.SSID,
                        "rssi" to it.level,
                        "secure" to isSecureNetwork(it.capabilities ?: "")
                    )
                }
                .toList()
        } catch (_: Throwable) {
            emptyList()
        }
    }

    /**
     * Wi‑Fi scan is asynchronous on Android: startScan() only triggers a scan;
     * results arrive via SCAN_RESULTS_AVAILABLE_ACTION (or we fall back to cache).
     */
    private fun scanWifiNetworksAsync(callback: (List<Map<String, Any>>) -> Unit) {
        if (!hasWifiScanPermission()) {
            callback(emptyList())
            return
        }

        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        if (wifiManager == null || !wifiManager.isWifiEnabled) {
            callback(emptyList())
            return
        }

        thread(name = "myframe-wifi-scan") {
            val done = AtomicBoolean(false)
            val latch = CountDownLatch(1)
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == WifiManager.SCAN_RESULTS_AVAILABLE_ACTION) {
                        if (done.compareAndSet(false, true)) {
                            latch.countDown()
                        }
                    }
                }
            }

            try {
                val filter = IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
                } else {
                    @Suppress("UnspecifiedRegisterReceiverFlag")
                    registerReceiver(receiver, filter)
                }
            } catch (_: Throwable) {
                callback(collectWifiResults(wifiManager))
                return@thread
            }

            val started = try {
                @Suppress("DEPRECATION")
                wifiManager.startScan()
            } catch (_: Throwable) {
                false
            }

            if (started) {
                try {
                    latch.await(8, TimeUnit.SECONDS)
                } catch (_: InterruptedException) {
                }
            } else {
                // Throttled / denied — still return last cached scan results.
                try {
                    Thread.sleep(400)
                } catch (_: InterruptedException) {
                }
            }

            try {
                unregisterReceiver(receiver)
            } catch (_: Throwable) {
            }

            callback(collectWifiResults(wifiManager))
        }
    }

    private fun isSecureNetwork(capabilities: String): Boolean {
        val cap = capabilities.uppercase()
        return cap.contains("WPA") || cap.contains("WEP") || cap.contains("SAE") ||
            cap.contains("EAP") || cap.contains("OWE")
    }

    private fun getWifiInfo(): Map<String, Any> {
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            ?: return mapOf("enabled" to false, "ssid" to "")
        if (!wifiManager.isWifiEnabled) return mapOf("enabled" to false, "ssid" to "")
        val raw = try {
            @Suppress("DEPRECATION")
            wifiManager.connectionInfo?.ssid ?: ""
        } catch (_: Throwable) {
            ""
        }
        val ssid = raw.trim().trim('"')
        return mapOf("enabled" to true, "ssid" to ssid)
    }
}
