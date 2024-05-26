package com.bluebubbles.messaging

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import com.bluebubbles.messaging.services.backend_ui_interop.MethodCallHandler
import com.bluebubbles.messaging.services.rustpush.APNService
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel


class MainActivity : FlutterFragmentActivity() {
    companion object {
        var engine: FlutterEngine? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(Intent(this, APNService::class.java))
        } else {
            startService(Intent(this, APNService::class.java))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        engine = flutterEngine
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.methodChannel).setMethodCallHandler { call, result ->
            if (call.method == "engine-done") {
                Log.i("BBEngine", "Destroyed");
                // this must be here in case another engine has been spawned in the meantime
                flutterEngine.destroy()
                if (engine == flutterEngine)
                    engine = null
            }
            MethodCallHandler().methodCallHandler(call, result, this)
        }
    }

    override fun createFlutterFragment(): FlutterFragment {
        val fragment = super.createFlutterFragment()
        // ARG_DESTROY_ENGINE_WITH_FRAGMENT
        fragment.requireArguments().putBoolean("destroy_engine_with_fragment", false)
        return fragment
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == Constants.notificationListenerRequestCode) {
            MethodCallHandler.getNotificationListenerResult?.success(resultCode == Activity.RESULT_OK)
        }
    }
}