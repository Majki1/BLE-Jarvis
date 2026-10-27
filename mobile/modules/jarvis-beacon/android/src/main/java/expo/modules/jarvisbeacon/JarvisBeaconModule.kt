package expo.modules.jarvisbeacon

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.content.Context
import android.os.ParcelUuid
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

// Advertises the Jarvis service UUID so the Mac's scanner can sense presence.
// Must stay in sync with mac/Jarvis/Presence/PresenceScanner.swift.
private const val JARVIS_SERVICE_UUID = "7E1C6B4A-9B3F-4C7D-8A2E-D4F5B6C7A8E9"

class JarvisBeaconModule : Module() {
  private var advertising = false
  private var lastError: String? = null

  private val adapter: BluetoothAdapter?
    get() {
      val manager = appContext.reactContext
        ?.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
      return manager?.adapter
    }

  private val advertiseCallback = object : AdvertiseCallback() {
    override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
      advertising = true
      lastError = null
      emitState()
    }

    override fun onStartFailure(errorCode: Int) {
      advertising = false
      lastError = "advertise failed with code $errorCode"
      emitState()
    }
  }

  override fun definition() = ModuleDefinition {
    Name("JarvisBeacon")

    Events("onStateChange")

    AsyncFunction("startAdvertising") {
      val advertiser = adapter?.bluetoothLeAdvertiser
        ?: throw IllegalStateException("Bluetooth LE advertising unavailable (adapter off or unsupported)")
      val settings = AdvertiseSettings.Builder()
        .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_POWER)
        .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
        .setConnectable(false)
        .build()
      val data = AdvertiseData.Builder()
        .addServiceUuid(ParcelUuid.fromString(JARVIS_SERVICE_UUID))
        .setIncludeDeviceName(false)
        .build()
      advertiser.startAdvertising(settings, data, advertiseCallback)
    }

    AsyncFunction("stopAdvertising") {
      adapter?.bluetoothLeAdvertiser?.stopAdvertising(advertiseCallback)
      advertising = false
      emitState()
    }

    Function("getState") {
      statePayload()
    }
  }

  private fun statePayload(): Map<String, Any?> = mapOf(
    "advertising" to advertising,
    "bluetooth" to if (adapter?.isEnabled == true) "poweredOn" else "poweredOff",
    "error" to lastError,
  )

  private fun emitState() {
    sendEvent("onStateChange", statePayload())
  }
}
