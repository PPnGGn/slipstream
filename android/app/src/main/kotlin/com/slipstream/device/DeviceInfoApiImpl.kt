package com.slipstream.device

import android.annotation.SuppressLint
import android.content.Context
import android.os.Build
import android.provider.Settings

// Thin on purpose: only reads raw values. Hashing and fallbacks live in Dart.
class DeviceInfoApiImpl(private val context: Context) : DeviceInfoApi {

    // ANDROID_ID never leaves the device as is: Dart hashes it into the HWID.
    @SuppressLint("HardwareIds")
    override fun getDeviceInfo(): DeviceInfoMessage {
        return DeviceInfoMessage(
                deviceId =
                        Settings.Secure.getString(
                                context.contentResolver,
                                Settings.Secure.ANDROID_ID,
                        ),
                os = "Android",
                osVersion = Build.VERSION.RELEASE,
                model = Build.MODEL,
        )
    }
}
