package com.shravangoswami.securevault

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.securevault/disguise"

    private val aliases = mapOf(
        "calculator" to ".CalculatorAlias",
        "notes" to ".NotesAlias",
        "clock" to ".ClockAlias",
        "moodspace" to ".MoodSpaceAlias"
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setDisguise" -> {
                    val disguiseId = call.argument<String>("disguiseId")
                    if (disguiseId != null) {
                        setDisguise(disguiseId)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "disguiseId is required", null)
                    }
                }
                "getCurrentDisguise" -> {
                    result.success(getCurrentDisguise())
                }
                "forceStopApp" -> {
                    result.success(true)
                    Handler(Looper.getMainLooper()).postDelayed({
                        finishAffinity()
                        android.os.Process.killProcess(android.os.Process.myPid())
                    }, 500)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun setDisguise(disguiseId: String) {
        val packageManager = packageManager
        val packageName = packageName

        // Enable the new alias FIRST to prevent app kill issues
        for ((id, alias) in aliases) {
            if (id == disguiseId) {
                packageManager.setComponentEnabledSetting(
                    ComponentName(packageName, "$packageName$alias"),
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
        }

        // Disable MainActivity (default entry point)
        packageManager.setComponentEnabledSetting(
            ComponentName(packageName, "$packageName.MainActivity"),
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP
        )

        // Disable other aliases
        for ((id, alias) in aliases) {
            if (id != disguiseId) {
                packageManager.setComponentEnabledSetting(
                    ComponentName(packageName, "$packageName$alias"),
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
        }
    }

    private fun getCurrentDisguise(): String {
        val packageManager = packageManager
        val packageName = packageName

        for ((id, alias) in aliases) {
            val state = packageManager.getComponentEnabledSetting(
                ComponentName(packageName, "$packageName$alias")
            )
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                return id
            }
        }
        return "default"
    }
}
