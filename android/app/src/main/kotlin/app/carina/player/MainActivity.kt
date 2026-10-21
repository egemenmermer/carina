package app.carina.player

import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.view.KeyEvent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Read once at start-up by lib/app/platform/form_factor.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTv" -> result.success(isTelevision())
                    else -> result.notImplemented()
                }
            }
    }

    // The remote's Back and OK reach Flutter as Escape and Enter, the keys
    // every screen already handles (overlays close on Escape, lists open on
    // Enter). Escape that no screen handles pops a route or leaves the app,
    // see _AppShortcuts in lib/app/app.dart.
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val mapped = when (event.keyCode) {
            KeyEvent.KEYCODE_BACK -> KeyEvent.KEYCODE_ESCAPE
            KeyEvent.KEYCODE_DPAD_CENTER -> KeyEvent.KEYCODE_ENTER
            else -> return super.dispatchKeyEvent(event)
        }
        return super.dispatchKeyEvent(
            KeyEvent(
                event.downTime, event.eventTime, event.action, mapped,
                event.repeatCount, event.metaState, event.deviceId,
                if (mapped == KeyEvent.KEYCODE_ESCAPE) SCAN_ESCAPE else SCAN_ENTER,
                event.flags, event.source,
            ),
        )
    }

    // Debuggable builds take launch flags (lib/app/launch_options.dart) from
    // a string extra, e.g. `adb shell am start -n app.carina.player/.MainActivity
    // --es carina_args "--smoke-test --mock-url http://10.0.2.2:8787"`.
    // Release builds ignore extras, and a malformed extra never crashes start-up.
    override fun getDartEntrypointArgs(): List<String>? {
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) return null
        intent.getStringExtra(ARGS_EXTRA)?.let { raw ->
            return raw.split(' ').filter { it.isNotBlank() }
        }
        return try {
            super.getDartEntrypointArgs()
        } catch (e: ClassCastException) {
            null
        }
    }

    private fun isTelevision(): Boolean {
        val uiMode = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        return uiMode?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
    }

    private companion object {
        const val CHANNEL = "app.carina.player/platform"
        const val ARGS_EXTRA = "carina_args"

        // Linux scan codes, so Flutter maps the physical key consistently.
        const val SCAN_ESCAPE = 1
        const val SCAN_ENTER = 28
    }
}
