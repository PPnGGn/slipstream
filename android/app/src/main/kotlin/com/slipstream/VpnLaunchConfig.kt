package com.slipstream

import org.json.JSONArray
import org.json.JSONObject

// Everything the service needs to bring the tunnel up with no Flutter around:
// the same set the app sends in the start intent (VpnConfigMessage), plus the
// resolved geo directory. The last one the app started is kept on disk
// (VpnLaunchStore), so the quick settings tile (and Always-on VPN later) can
// start it again. Holds the server's credentials inside configJson: never log it.
data class VpnLaunchConfig(
        val configJson: String,
        val geoDir: String,
        val hijackDns: Boolean,
        val splitMode: VpnSplitMode?,
        val splitPackages: List<String>,
        val serverTitle: String?,
) {
    fun toJson(): String =
            JSONObject()
                    .put("configJson", configJson)
                    .put("geoDir", geoDir)
                    .put("hijackDns", hijackDns)
                    .put("splitMode", splitMode?.name ?: JSONObject.NULL)
                    .put("splitPackages", JSONArray(splitPackages))
                    .put("serverTitle", serverTitle ?: JSONObject.NULL)
                    .toString()

    companion object {
        // Null for anything that is not a usable launch: empty or broken text,
        // no config, no geo directory. Unknown details (a split mode a newer
        // build wrote) are dropped, not fatal: the tunnel should still start.
        fun fromJson(text: String): VpnLaunchConfig? =
                try {
                    val json = JSONObject(text)
                    val configJson = json.optString("configJson", "")
                    val geoDir = json.optString("geoDir", "")
                    if (configJson.isEmpty() || geoDir.isEmpty()) {
                        null
                    } else {
                        VpnLaunchConfig(
                                configJson = configJson,
                                geoDir = geoDir,
                                hijackDns = json.optBoolean("hijackDns", false),
                                splitMode =
                                        json.optString("splitMode", "").let { name ->
                                            VpnSplitMode.values().firstOrNull { it.name == name }
                                        },
                                splitPackages =
                                        json.optJSONArray("splitPackages")?.let { array ->
                                            (0 until array.length()).map { array.getString(it) }
                                        }
                                                ?: emptyList(),
                                serverTitle =
                                        if (json.isNull("serverTitle")) null
                                        else json.optString("serverTitle").ifEmpty { null },
                        )
                    }
                } catch (e: Exception) {
                    null
                }
    }
}
