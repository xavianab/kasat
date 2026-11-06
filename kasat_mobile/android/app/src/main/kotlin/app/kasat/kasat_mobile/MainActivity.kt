package app.kasat.kasat_mobile

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val PRIVACY_CHANNEL = "app.kasat/privacy"
        private const val DANGER_ACTION = "app.kasat.DANGER"
    }

    private var openedFromDanger = false

    override fun onCreate(savedInstanceState: Bundle?) {
        openedFromDanger = isDangerLaunch(intent)
        super.onCreate(savedInstanceState)
        // Blank out the app switcher (Recents) task snapshot and block screenshots
        // of sensitive survivor report forms.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PRIVACY_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "quickExitToHome" -> {
                    // Navigate straight to the Android Home Screen without opening
                    // a browser URL (leaves zero browser history) and remove this
                    // task from the Recent Apps carousel.
                    val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                        addCategory(Intent.CATEGORY_HOME)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(homeIntent)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        finishAndRemoveTask()
                    } else {
                        finish()
                    }
                    result.success(true)
                }
                "launchIsDanger" -> result.success(openedFromDanger)
                "setSecureScreen" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    if (enabled) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (isDangerLaunch(intent)) openedFromDanger = true
    }

    private fun isDangerLaunch(intent: Intent?): Boolean {
        if (intent == null) return false
        if (intent.action == DANGER_ACTION) return true
        return intent.getBooleanExtra("kasat_danger", false)
    }
}
