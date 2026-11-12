package com.jinyu74.mobile_scanner

import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    // ML Kit 한국어 인식기(기기 안에서 처리, 무료). 한국어와 라틴 문자를 함께 읽는다.
    private val recognizer by lazy {
        TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.jinyu74.scanner/ocr")
            .setMethodCallHandler { call, result ->
                val path = call.argument<String>("path")
                if (call.method != "recognize" || path == null) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val image = try {
                    InputImage.fromFilePath(this, Uri.fromFile(File(path)))
                } catch (e: Exception) {
                    result.error("ocr_failed", "이미지를 읽을 수 없습니다.", null)
                    return@setMethodCallHandler
                }
                recognizer.process(image)
                    .addOnSuccessListener { text -> result.success(text.text) }
                    .addOnFailureListener { e -> result.error("ocr_failed", e.localizedMessage, null) }
            }
    }

    override fun onDestroy() {
        recognizer.close()
        super.onDestroy()
    }
}
