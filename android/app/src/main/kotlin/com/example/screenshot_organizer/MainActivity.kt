package com.example.screenshot_organizer

import android.graphics.Bitmap
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.snapgrove.organizer/saf_utils"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getThumbnail") {
                val uriStr = call.argument<String>("uri")
                val width = call.argument<Int>("width") ?: 300
                val height = call.argument<Int>("height") ?: 400

                if (uriStr != null) {
                    val thumbnail = getThumbnail(uriStr, width, height)
                    if (thumbnail != null) {
                        result.success(thumbnail)
                    } else {
                        result.error("UNAVAILABLE", "Could not generate thumbnail", null)
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
            
            // Explicitly using android.graphics.Point to avoid any Size conflicts
            val bitmap = DocumentsContract.getDocumentThumbnail(
                contentResolver,
                uri,
                android.graphics.Point(width, height),
                null
            )
            
            if (bitmap != null) {
                val stream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.JPEG, 80, stream)
                val byteArray = stream.toByteArray()
                bitmap.recycle()
                byteArray
            } else {
                null
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
