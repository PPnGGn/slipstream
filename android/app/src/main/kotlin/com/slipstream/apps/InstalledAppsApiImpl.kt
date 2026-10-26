package com.slipstream.apps

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Build
import android.util.Log
import java.io.ByteArrayOutputStream

internal fun isHiddenSystemApp(isPreinstalled: Boolean, hasLauncherActivity: Boolean): Boolean =
        isPreinstalled && !hasLauncherActivity

class InstalledAppsApiImpl(private val context: Context) : InstalledAppsApi {

    override fun installedApps(): List<InstalledAppMessage> {
        val pm = context.packageManager
        val launcherPackages = launcherPackages(pm)
        return installedApplications(pm)
                .filter { it.packageName != context.packageName }
                .map { info ->
                    InstalledAppMessage(
                            packageName = info.packageName,
                            label = info.loadLabel(pm).toString(),
                            isSystem =
                                    isHiddenSystemApp(
                                            isPreinstalled = isPreinstalled(info),
                                            hasLauncherActivity =
                                                    info.packageName in launcherPackages,
                                    ),
                    )
                }
    }

    override fun appIcon(packageName: String): ByteArray? =
            try {
                drawableToPng(context.packageManager.getApplicationIcon(packageName))
            } catch (e: Exception) {
                Log.w("INSTALLED_APPS", "No icon for $packageName: ${e.message}")
                null
            }

    private fun drawableToPng(drawable: Drawable): ByteArray {
        val bitmap = Bitmap.createBitmap(96, 96, Bitmap.Config.ARGB_8888)
        drawable.setBounds(0, 0, 96, 96)
        drawable.draw(Canvas(bitmap))
        val png = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, png)
        bitmap.recycle()
        return png.toByteArray()
    }

    private fun isPreinstalled(info: ApplicationInfo): Boolean =
            info.flags and (ApplicationInfo.FLAG_SYSTEM or ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0

    @Suppress("DEPRECATION")
    private fun installedApplications(pm: PackageManager): List<ApplicationInfo> =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(0))
            } else {
                pm.getInstalledApplications(0)
            }

    @Suppress("DEPRECATION")
    private fun launcherPackages(pm: PackageManager): Set<String> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolved =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0))
                } else {
                    pm.queryIntentActivities(intent, 0)
                }
        return resolved.map { it.activityInfo.packageName }.toSet()
    }
}
