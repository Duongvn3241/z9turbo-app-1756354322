package com.z9turbo

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class BoostAccessibilityService : AccessibilityService() {

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Whenever App Info screen appears, try to click "Force stop" and "OK"
        val root = rootInActiveWindow ?: return

        // Click "Force stop" button if present
        val forceStopNodes = findText(root, listOf("Force stop", "Buộc dừng", "Buộc dừng ứng dụng"))
        if (forceStopNodes.isNotEmpty()) {
            val btn = forceStopNodes.first()
            if (btn.isEnabled) btn.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }

        // Confirm dialog "OK"
        val okNodes = findText(root, listOf("OK", "Ok", "Có", "Đồng ý"))
        if (okNodes.isNotEmpty()) {
            okNodes.first().performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }
    }

    override fun onInterrupt() { /* no-op */ }

    private fun findText(root: AccessibilityNodeInfo, texts: List<String>): List<AccessibilityNodeInfo> {
        val result = mutableListOf<AccessibilityNodeInfo>()
        val stack = ArrayDeque<AccessibilityNodeInfo>()
        stack.add(root)
        while (stack.isNotEmpty()) {
            val node = stack.removeFirst()
            val t = node.text?.toString()?.trim() ?: ""
            if (t.isNotEmpty() && texts.any { t.equals(it, ignoreCase = true) }) {
                result.add(node)
            }
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { stack.add(it) }
            }
        }
        return result
    }
}