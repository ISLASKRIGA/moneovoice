package com.moneovoice.app

import android.content.Intent
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(SpeechPlugin())

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.moneovoice.app/locale")
            .setMethodCallHandler { call, result ->
                if (call.method == "getLocale") {
                    val locale = Locale.getDefault()
                    result.success(mapOf(
                        "language" to locale.language,
                        "country"  to locale.country,
                    ))
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.moneovoice.app/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isListenerEnabled" -> {
                        val enabled = NotificationManagerCompat
                            .getEnabledListenerPackages(this)
                            .contains(packageName)
                        result.success(enabled)
                    }
                    "openListenerSettings" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
