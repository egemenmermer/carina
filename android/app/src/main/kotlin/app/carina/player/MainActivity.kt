package app.carina.player

import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
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

    private fun isTelevision(): Boolean {
        val uiMode = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        return uiMode?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
    }

    private companion object {
        const val CHANNEL = "app.carina.player/platform"
    }
}
