package br.com.definitivedownloader.app

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.spotify.sdk.android.auth.AuthorizationClient
import com.spotify.sdk.android.auth.AuthorizationRequest
import com.spotify.sdk.android.auth.AuthorizationResponse
import com.spotify.sdk.android.auth.IntentExtras
import com.spotify.sdk.android.auth.LoginActivity
import com.spotify.sdk.android.auth.PKCEInformation
import com.spotify.sdk.android.auth.app.SpotifyNativeAuthUtil
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Opens the signed Spotify client via its SDK without inspecting its session. */
class SpotifyAuthChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "br.com.definitivedownloader/spotify")
    private var active: SpotifyNativeAuthUtil? = null
    private var pending: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> connect(call, result)
                "cancel" -> { cancel(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    private fun connect(call: MethodCall, result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "Já há uma autorização Spotify em andamento.", null)
            return
        }
        try {
            if (!SpotifyNativeAuthUtil.isSpotifyVersionAtLeast(
                    activity, AuthorizationClient.MIN_SPOTIFY_VERSION_FOR_TOKEN_CONVERSION)) {
                result.success(null)
                return
            }
            val request = AuthorizationRequest.Builder(
                requireNotNull(call.argument<String>("clientId")),
                AuthorizationResponse.Type.CODE,
                requireNotNull(call.argument<String>("redirect"))
            ).setState(requireNotNull(call.argument<String>("state")))
                .setScopes(requireNotNull(call.argument<List<String>>("scopes")).toTypedArray())
                .setPkceInformation(PKCEInformation.sha256(
                    requireNotNull(call.argument<String>("verifier")),
                    requireNotNull(call.argument<String>("challenge"))))
                .build()
            val login = SpotifyNativeAuthUtil(activity, request)
            if (login.startAuthActivity()) {
                active = login
                pending = result
            } else {
                result.success(null)
            }
        } catch (_: Exception) {
            result.error("spotify", "Não foi possível abrir o Spotify oficial.", null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != LoginActivity.REQUEST_CODE) return false
        val result = pending ?: return true
        pending = null
        active = null
        if (resultCode == Activity.RESULT_CANCELED) {
            result.error("cancelled", "Conexão cancelada.", null)
            return true
        }
        try {
            @Suppress("DEPRECATION")
            val reply = data?.getParcelableExtra<Bundle>(LoginActivity.EXTRA_REPLY)
            val code = reply?.getString(IntentExtras.KEY_AUTHORIZATION_CODE)
            val state = reply?.getString(IntentExtras.KEY_STATE)
            if (resultCode == Activity.RESULT_OK &&
                reply?.getString(IntentExtras.KEY_RESPONSE_TYPE) == LoginActivity.RESPONSE_TYPE_CODE &&
                code != null && state != null) {
                result.success(mapOf("code" to code, "state" to state))
            } else {
                result.error("spotify", "O Spotify não autorizou a conexão.", null)
            }
        } catch (_: Exception) {
            result.error("spotify", "Retorno de autorização Spotify inválido.", null)
        }
        return true
    }

    private fun cancel() {
        val result = pending
        pending = null
        try { active?.stopAuthActivity() } catch (_: Exception) { }
        active = null
        result?.error("cancelled", "Conexão cancelada.", null)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        cancel()
    }
}
