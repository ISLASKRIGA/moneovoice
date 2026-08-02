package com.moneovoice.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SpeechPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler, ActivityAware {

    private var activity: Activity? = null
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel

    private var recognizer: SpeechRecognizer? = null
    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())

    private var isActive = false
    private var locale = "es-MX"
    private var currentIntent: Intent? = null
    private var audioManager: AudioManager? = null

    companion object {
        const val METHOD = "com.moneovoice.app/speech_method"
        const val EVENT  = "com.moneovoice.app/speech_event"
    }

    // ── FlutterPlugin ─────────────────────────────────────────
    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(b.binaryMessenger, METHOD)
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(b.binaryMessenger, EVENT)
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        handler.post { destroy() }
    }

    // ── ActivityAware ─────────────────────────────────────────
    override fun onAttachedToActivity(b: ActivityPluginBinding) {
        activity = b.activity
        audioManager = b.activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }
    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) {
        activity = b.activity
        audioManager = b.activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }
    override fun onDetachedFromActivityForConfigChanges() { activity = null; audioManager = null }
    override fun onDetachedFromActivity()                 { activity = null; audioManager = null }

    // ── EventChannel ──────────────────────────────────────────
    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) { eventSink = sink }
    override fun onCancel(arguments: Any?)                                 { eventSink = null }

    // ── Vibración ─────────────────────────────────────────────
    private fun vibrate(pattern: LongArray) {
        val ctx = activity ?: return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = ctx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                val v = ctx.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    v.vibrate(VibrationEffect.createWaveform(pattern, -1))
                } else {
                    @Suppress("DEPRECATION")
                    v.vibrate(pattern, -1)
                }
            }
        } catch (_: Exception) {}
    }

    // ── MethodChannel ─────────────────────────────────────────
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                locale   = call.argument<String>("locale") ?: "es-MX"
                isActive = true
                handler.post {
                    vibrate(longArrayOf(0, 50))
                    startSession()
                }
                result.success(null)
            }
            "stop" -> {
                isActive = false
                handler.post {
                    recognizer?.stopListening()
                    handler.postDelayed({
                        destroy()
                        vibrate(longArrayOf(0, 30, 60, 30))
                        emit("status", "idle")
                    }, 400)
                }
                result.success(null)
            }
            "cancel" -> {
                isActive = false
                handler.post {
                    recognizer?.cancel()
                    handler.postDelayed({
                        destroy()
                        vibrate(longArrayOf(0, 30, 60, 30))
                        emit("status", "idle")
                    }, 400)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ── Reconocimiento ────────────────────────────────────────
    private fun startSession() {
        destroy()
        if (!isActive) return
        val ctx = activity ?: return
        if (!SpeechRecognizer.isRecognitionAvailable(ctx)) {
            emit("error", "speech_not_available")
            return
        }

        currentIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 15_000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 4_000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 2_500L)
            // Forzar reconocimiento on-device: no libera el mic entre sesiones
            // y evita los sonidos de privacidad del sistema en Android 12+
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                putExtra("android.speech.extra.DICTATION_MODE", true)
            }
        }

        // API 31+: usar el recognizer on-device que mantiene el mic abierto continuamente
        recognizer = if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(ctx)
        ) {
            SpeechRecognizer.createOnDeviceSpeechRecognizer(ctx)
        } else {
            SpeechRecognizer.createSpeechRecognizer(ctx)
        }

        recognizer?.setRecognitionListener(object : RecognitionListener {
            // Silenciar aquí: onEndOfSpeech se dispara ANTES del sonido de fin de sesión
            override fun onEndOfSpeech()                 { if (isActive) muteSystemSounds() }
            // Cuando el recognizer está listo de nuevo, restaurar el audio
            override fun onReadyForSpeech(p: Bundle?)    { unmuteSystemSounds(); emit("status", "listening") }
            override fun onBeginningOfSpeech()           {}
            override fun onRmsChanged(v: Float)          {}
            override fun onBufferReceived(b: ByteArray?) {}
            override fun onEvent(type: Int, p: Bundle?)  {}

            override fun onPartialResults(bundle: Bundle?) {
                val text = bundle
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()?.trim() ?: return
                if (text.isNotEmpty()) emit("partial", text)
            }

            override fun onResults(bundle: Bundle?) {
                val text = bundle
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()?.trim() ?: ""
                if (text.isNotEmpty()) emit("final", text)
                if (isActive) {
                    handler.postDelayed({ restartListening() }, 80)
                    // Seguro: dessilenciar si onReadyForSpeech no llega
                    handler.postDelayed({ unmuteSystemSounds() }, 2000)
                }
            }

            override fun onError(code: Int) {
                if (!isActive) return
                muteSystemSounds()
                if (code == SpeechRecognizer.ERROR_RECOGNIZER_BUSY) {
                    handler.postDelayed({ if (isActive) startSession() }, 600)
                } else {
                    handler.postDelayed({ if (isActive) restartListening() }, 150)
                }
                handler.postDelayed({ unmuteSystemSounds() }, 2000)
            }
        })

        muteSystemSounds()   // silenciar ANTES de que el recognizer adquiera audio focus
        recognizer?.startListening(currentIntent)
    }

    // Reusar la misma instancia del recognizer — el mic no se cierra físicamente
    private fun restartListening() {
        if (!isActive) return
        muteSystemSounds()   // silenciar ANTES de que el recognizer adquiera audio focus
        recognizer?.startListening(currentIntent ?: return)
    }

    // ── Utilidades ────────────────────────────────────────────
    private fun emit(type: String, value: String) {
        handler.post { eventSink?.success(mapOf("type" to type, "value" to value)) }
    }

    private fun muteSystemSounds() {
        val am = audioManager ?: return
        try {
            am.adjustStreamVolume(AudioManager.STREAM_SYSTEM,       AudioManager.ADJUST_MUTE, 0)
            am.adjustStreamVolume(AudioManager.STREAM_MUSIC,        AudioManager.ADJUST_MUTE, 0)
            am.adjustStreamVolume(AudioManager.STREAM_RING,         AudioManager.ADJUST_MUTE, 0)
            am.adjustStreamVolume(AudioManager.STREAM_NOTIFICATION, AudioManager.ADJUST_MUTE, 0)
        } catch (_: Exception) {}
    }

    private fun unmuteSystemSounds() {
        val am = audioManager ?: return
        try {
            am.adjustStreamVolume(AudioManager.STREAM_SYSTEM,       AudioManager.ADJUST_UNMUTE, 0)
            am.adjustStreamVolume(AudioManager.STREAM_MUSIC,        AudioManager.ADJUST_UNMUTE, 0)
            am.adjustStreamVolume(AudioManager.STREAM_RING,         AudioManager.ADJUST_UNMUTE, 0)
            am.adjustStreamVolume(AudioManager.STREAM_NOTIFICATION, AudioManager.ADJUST_UNMUTE, 0)
        } catch (_: Exception) {}
    }

    private fun destroy() {
        recognizer?.destroy()
        recognizer = null
    }
}
