package io.github.navinkumar0007.arcvert

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var media: MediaEngine? = null
    private var share: ShareReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        media = MediaEngine(this, flutterEngine.dartExecutor.binaryMessenger)
        share = ShareReceiver(this, flutterEngine.dartExecutor.binaryMessenger)
        // Opens the newest version's page in the browser, or a report as an email draft. The app
        // itself has no permission to use the internet, and this needs none: the browser or the
        // email app does the sending, if the person chooses to.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "radial/pages")
            .setMethodCallHandler { call, result ->
                val url = call.argument<String>("url")
                val email = url?.startsWith("mailto:") == true
                if (call.method != "open" || url == null || !(url.startsWith("https://") || email)) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                try {
                    // An email draft goes only to email apps.
                    val action = if (email) Intent.ACTION_SENDTO else Intent.ACTION_VIEW
                    startActivity(Intent(action, Uri.parse(url)))
                    result.success(true)
                } catch (error: ActivityNotFoundException) {
                    result.success(false)
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        media?.stop()
        media = null
        share?.stop()
        share = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        share?.arrive(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (media?.onSaveResult(requestCode, resultCode, data) != true) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
}
