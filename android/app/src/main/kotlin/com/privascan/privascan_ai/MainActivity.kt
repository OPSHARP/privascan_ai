package com.privascan.ai

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        enableHighRefreshRate()
    }

    private fun enableHighRefreshRate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val win = window ?: return
                val disp = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    display
                } else {
                    @Suppress("DEPRECATION")
                    windowManager.defaultDisplay
                }
                val currentRefreshRate = disp?.mode?.refreshRate ?: 60f
                val modes = disp?.supportedModes
                val maxRefreshRateMode = modes?.maxByOrNull { it.refreshRate }
                if (maxRefreshRateMode != null && maxRefreshRateMode.refreshRate > currentRefreshRate) {
                    val params = win.attributes
                    params.preferredDisplayModeId = maxRefreshRateMode.modeId
                    win.attributes = params
                }
            } catch (_: Exception) {
                // Silently fallback to standard display mode
            }
        }
    }
}