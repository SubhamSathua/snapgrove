package com.prism.snapgrove

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.os.BatteryManager
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import kotlinx.coroutines.*

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.snapgrove.organizer/saf_utils"
    private val BATTERY_CHANNEL = "com.snapgrove.organizer/battery"
    private val ioScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getBatteryLevel") {
                try {
                    val batteryManager = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
                    if (batteryManager != null) {
                        val batteryLevel = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                        if (batteryLevel in 0..100) {
                            result.success(batteryLevel)
                        } else {
                            result.success(null)
                        }
                    } else {
                        result.success(null)
                    }
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getThumbnail") {
                val uriStr = call.argument<String>("uri")
                val width = call.argument<Int>("width") ?: 350
                val height = call.argument<Int>("height") ?: 350

                if (uriStr != null) {
                    // Fossify Strategy: Run heavy IO and Bitmap processing on a background thread
                    ioScope.launch {
                        val thumbnail = getThumbnail(uriStr, width, height)
                        withContext(Dispatchers.Main) {
                            if (thumbnail != null) {
                                result.success(thumbnail)
                            } else {
                                result.error("UNAVAILABLE", "Could not generate thumbnail", null)
                            }
                        }
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "URI was null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getThumbnail(uriStr: String, width: Int, height: Int): ByteArray? {
        return try {
            val uri = Uri.parse(uriStr)
            
            // Native Android Thumbnailing (DocumentsContract)
            val bitmap = DocumentsContract.getDocumentThumbnail(
                contentResolver,
                uri,
                android.graphics.Point(width, height),
                null
            )

            if (bitmap != null) {
                val stream = ByteArrayOutputStream()
                // Fossify uses JPEG for small thumbnails to save memory
                bitmap.compress(Bitmap.CompressFormat.JPEG, 80, stream)
                val byteArray = stream.toByteArray()
                bitmap.recycle() // CRITICAL: Free GPU memory immediately
                byteArray
            } else {
                null
            }
        } catch (e: Exception) {
            null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        ioScope.cancel()
    }
}
