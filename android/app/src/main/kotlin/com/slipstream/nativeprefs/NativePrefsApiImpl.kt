package com.slipstream.nativeprefs

// Dart -> Kotlin: the app tells which language and which switches the service and the
// tile must use. A field that is null was not sent and stays as it was.
class NativePrefsApiImpl(private val store: NativePrefsStore) : NativePrefsApi {

    override fun save(prefs: NativePrefsMessage) {
        prefs.language?.let { store.saveLanguage(it) }
    }
}
