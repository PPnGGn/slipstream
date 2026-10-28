package com.slipstream

import android.content.Context
import java.io.File

// The last launch the app started, on disk (see VpnLaunchConfig). Written by
// the service on every start from the app, read by it when the tile or the
// system starts it without the app.
//
// The folder is noBackupFilesDir: Auto Backup and device-to-device transfer
// never take it. The file holds the server's credentials, which must not end up
// on another phone or in a cloud backup.
class VpnLaunchStore(private val dir: File) {

    private val file = File(dir, "vpn_launch.json")
    private val tmp = File(dir, "vpn_launch.json.tmp")

    // Written aside and renamed: a kill in the middle of the write leaves the
    // previous launch whole, never half of the new one.
    @Synchronized
    fun save(launch: VpnLaunchConfig) {
        dir.mkdirs()
        tmp.writeText(launch.toJson())
        if (!tmp.renameTo(file)) {
            // Some file systems refuse to rename over an existing file.
            file.delete()
            check(tmp.renameTo(file)) { "Could not save the launch" }
        }
    }

    // Null when nothing was saved, or the file is not a usable launch.
    @Synchronized
    fun load(): VpnLaunchConfig? =
            try {
                if (file.exists()) VpnLaunchConfig.fromJson(file.readText()) else null
            } catch (e: java.io.IOException) {
                null
            }

    // Cheap enough for the tile to ask on every tap.
    fun exists(): Boolean = load() != null

    @Synchronized
    fun clear() {
        file.delete()
        tmp.delete()
    }

    companion object {
        fun of(context: Context) = VpnLaunchStore(context.noBackupFilesDir)
    }
}
