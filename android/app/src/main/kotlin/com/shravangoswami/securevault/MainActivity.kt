package com.shravangoswami.securevault

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.securevault/disguise"

    // Components are named after the code's package, which stays the same when
    // a build changes the application id (a .dev build, for example).
    private val classPrefix = MainActivity::class.java.name.substringBeforeLast('.')

    private val aliases = mapOf(
        "calculator" to "CalculatorAlias",
        "notes" to "NotesAlias",
        "clock" to "ClockAlias",
        "moodspace" to "MoodSpaceAlias"
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "setDisguise" -> {
                    val disguiseId = call.argument<String>("disguiseId")
                    if (disguiseId != null && aliases.containsKey(disguiseId)) {
                        setDisguise(disguiseId)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Unknown disguiseId: $disguiseId", null)
                    }
                }
                "getCurrentDisguise" -> result.success(getCurrentDisguise())
                else -> result.notImplemented()
            }
        }
    }

    private fun component(simpleName: String) = ComponentName(packageName, "$classPrefix.$simpleName")

    private fun setEnabled(simpleName: String, enabled: Boolean) {
        packageManager.setComponentEnabledSetting(
            component(simpleName),
            if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP
        )
    }

    // The new icon is enabled before the old one is disabled, so the app always
    // has a launcher entry.
    private fun setDisguise(disguiseId: String) {
        setEnabled(aliases.getValue(disguiseId), true)
        setEnabled("MainActivity", false)
        for ((id, alias) in aliases) {
            if (id != disguiseId) setEnabled(alias, false)
        }
    }

    private fun getCurrentDisguise(): String {
        for ((id, alias) in aliases) {
            if (packageManager.getComponentEnabledSetting(component(alias)) ==
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            ) {
                return id
            }
        }
        return "default"
    }
}
