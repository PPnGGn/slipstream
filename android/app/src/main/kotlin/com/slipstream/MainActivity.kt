package com.slipstream

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.FileProvider
import androidx.core.content.pm.PackageInfoCompat
import com.slipstream.updater.AppVersionMessage
import com.slipstream.updater.InstallResult
import com.slipstream.updater.UpdateInstaller
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterActivity(), VpnConnection, UpdateInstaller {

    private var pendingVpnCallback: ((Result<VpnResult>) -> Unit)? = null
    private var pendingConfig: String? = null

    companion object {
        private const val REQUEST_POST_NOTIFICATIONS = 42
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        ActivityCompat.checkSelfPermission(
                                this,
                                Manifest.permission.POST_NOTIFICATIONS
                        ) != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQUEST_POST_NOTIFICATIONS,
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        VpnConnection.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
        UpdateInstaller.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
        VpnEventBridge.receiver = VpnEventReceiver(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        VpnEventBridge.receiver = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun getStatus(callback: (Result<VpnStatusMessage>) -> Unit) {
        callback(Result.success(VpnEventBridge.currentStatus()))
    }

    override fun start(config: VpnConfigMessage, callback: (Result<VpnResult>) -> Unit) {
        Log.d("VPN_BRIDGE", "Requesting VPN start with dynamic config...")

        val configJson = config.configJson
        val intent = VpnService.prepare(this)

        if (intent != null) {
            pendingVpnCallback = callback
            pendingConfig = configJson
            startActivityForResult(intent, 24)
        } else {
            val serviceIntent =
                    android.content.Intent(
                            applicationContext,
                            com.slipstream.V2RayVpnService::class.java
                    )
            serviceIntent.putExtra("XRAY_CONFIG", configJson)
            startService(serviceIntent)

            callback(Result.success(VpnResult(successful = true)))
        }
    }

    override fun stop(callback: (Result<VpnResult>) -> Unit) {
        Log.d("VPN_BRIDGE", "Stopping VPN...")

        val serviceIntent =
                android.content.Intent(applicationContext, com.slipstream.V2RayVpnService::class.java)
        serviceIntent.action = "ACTION_STOP_VPN"
        startService(serviceIntent)

        callback(Result.success(VpnResult(successful = true)))
    }

    override fun onActivityResult(
            requestCode: Int,
            resultCode: Int,
            data: android.content.Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == 24) {
            if (resultCode == Activity.RESULT_OK) {
                Log.d("VPN_BRIDGE", "Permission granted, starting service")

                val config = pendingConfig
                if (config != null) {
                    val serviceIntent =
                            android.content.Intent(
                                    applicationContext,
                                    com.slipstream.V2RayVpnService::class.java
                            )
                    serviceIntent.putExtra("XRAY_CONFIG", config)
                    startService(serviceIntent)

                    pendingVpnCallback?.invoke(Result.success(VpnResult(successful = true)))
                } else {
                    Log.e("VPN_BRIDGE", "Error: pendingConfig is null")
                    pendingVpnCallback?.invoke(
                            Result.success(VpnResult(successful = false, error = "Config lost"))
                    )
                }
            } else {
                Log.d("VPN_BRIDGE", "Permission denied by user")
                pendingVpnCallback?.invoke(Result.success(VpnResult(successful = false)))
            }
            pendingVpnCallback = null
            pendingConfig = null
        }
    }

    override fun getAppVersion(): AppVersionMessage {
        val info = packageManager.getPackageInfo(packageName, 0)
        return AppVersionMessage(
                version = info.versionName ?: "0.0.0",
                buildNumber = PackageInfoCompat.getLongVersionCode(info),
        )
    }

    override fun canInstallPackages(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    override fun apkSignatureMatchesInstalled(filePath: String): Boolean {
        return try {
            val installed = signerDigests(packageManager.getPackageInfo(packageName, signingInfoFlag()))
            val incoming = signerDigests(packageManager.getPackageArchiveInfo(filePath, signingInfoFlag()))
            if (installed.isEmpty() || incoming.isEmpty()) {
                true
            } else {
                installed.intersect(incoming).isNotEmpty()
            }
        } catch (e: Exception) {
            Log.e("UPDATER_BRIDGE", "Failed to compare signatures", e)
            true
        }
    }

    override fun exportApkToDownloads(
            filePath: String,
            fileName: String,
            callback: (Result<String?>) -> Unit,
    ) {
        Thread {
                    val location =
                            try {
                                copyApkToDownloads(filePath, fileName)
                            } catch (e: Exception) {
                                Log.e("UPDATER_BRIDGE", "Failed to export APK", e)
                                null
                            }
                    runOnUiThread { callback(Result.success(location)) }
                }
                .start()
    }

    override fun uninstallSelf() {
        startActivity(
                Intent(Intent.ACTION_DELETE, Uri.parse("package:$packageName")).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
        )
    }

    @Suppress("DEPRECATION")
    private fun signingInfoFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }
    }

    @Suppress("DEPRECATION")
    private fun signerDigests(info: PackageInfo?): Set<String> {
        if (info == null) return emptySet()
        val signatures: Array<Signature>? =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    val signingInfo = info.signingInfo
                    when {
                        signingInfo == null -> null
                        signingInfo.hasMultipleSigners() -> signingInfo.apkContentsSigners
                        else -> signingInfo.signingCertificateHistory
                    }
                } else {
                    info.signatures
                }
        if (signatures.isNullOrEmpty()) return emptySet()
        val digest = MessageDigest.getInstance("SHA-256")
        return signatures
                .map { signature ->
                    digest.digest(signature.toByteArray()).joinToString("") { "%02x".format(it) }
                }
                .toSet()
    }

    private fun copyApkToDownloads(filePath: String, fileName: String): String? {
        val source = File(filePath)
        if (!source.exists()) return null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values =
                    ContentValues().apply {
                        put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                        put(MediaStore.Downloads.MIME_TYPE, "application/vnd.android.package-archive")
                        put(MediaStore.Downloads.IS_PENDING, 1)
                    }
            val resolver = contentResolver
            val uri =
                    resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: return null
            resolver.openOutputStream(uri).use { output ->
                source.inputStream().use { it.copyTo(output!!) }
            }
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return "Download/$fileName"
        }

        val downloads =
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!downloads.exists() && !downloads.mkdirs()) return null
        source.copyTo(File(downloads, fileName), overwrite = true)
        return "Download/$fileName"
    }

    override fun openInstallSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startActivity(
                    Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName"),
                    )
            )
        }
    }

    override fun installApk(filePath: String, callback: (Result<InstallResult>) -> Unit) {
        try {
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", File(filePath))
            val intent =
                    Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
            startActivity(intent)
            callback(Result.success(InstallResult(successful = true)))
        } catch (e: Exception) {
            Log.e("UPDATER_BRIDGE", "Failed to launch installer", e)
            callback(Result.success(InstallResult(successful = false, error = e.message)))
        }
    }
}
