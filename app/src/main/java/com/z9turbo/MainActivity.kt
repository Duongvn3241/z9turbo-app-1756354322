package com.z9turbo

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

    private val usageAccessLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { /* just return */ }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    Z9TurboScreen()
                }
            }
        }
    }

    @Composable
    fun Z9TurboScreen() {
        val ctx = this
        var apps by remember { mutableStateOf(UsageRepo.loadTopApps(ctx)) }
        var selected by remember { mutableStateOf(apps.take(8).associate { it.packageName to true }.toMutableMap()) }
        var boosting by remember { mutableStateOf(false) }
        var log by remember { mutableStateOf(listOf<String>()) }

        fun refresh() {
            apps = UsageRepo.loadTopApps(ctx)
            selected = apps.take(8).associate { it.packageName to (selected[it.packageName] ?: true) }.toMutableMap()
        }

        Column(modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)) {

            Text("Z9 Turbo", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))

            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Button(onClick = {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    usageAccessLauncher.launch(intent)
                }) { Text("Cấp quyền Usage Access") }

                Spacer(Modifier.width(8.dp))

                Button(onClick = {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                }) { Text("Bật Accessibility") }
            }

            Spacer(Modifier.height(8.dp))

            Row(verticalAlignment = Alignment.CenterVertically) {
                Button(onClick = { refresh() }) { Text("Quét lại") }
                Spacer(Modifier.width(8.dp))
                Button(
                    enabled = !boosting,
                    onClick = {
                        boosting = true
                        log = listOf("Bắt đầu tăng tốc...")
                        lifecycleScope.launch {
                            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                            val chosen = apps.filter { selected[it.packageName] == true }
                            for (app in chosen) {
                                log = log + "Đóng: ${app.appName}"
                                // Try soft kill first
                                try {
                                    am.killBackgroundProcesses(app.packageName)
                                } catch (_: Exception) { }
                                // Launch App Info screen so Accessibility service can press Force stop
                                try {
                                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                        data = Uri.parse("package:${app.packageName}")
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    }
                                    startActivity(intent)
                                } catch (_: Exception) { }
                                delay(2200) // give the service time to act
                            }
                            log = log + "Hoàn tất."
                            boosting = false
                        }
                    }) { Text(if (boosting) "Đang xử lý..." else "Boost ngay") }
            }

            Spacer(Modifier.height(12.dp))

            Text("Ứng dụng tiêu tốn gần đây", fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            LazyColumn(modifier = Modifier.weight(1f)) {
                items(apps) { app ->
                    val checked = selected[app.packageName] == true
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                selected[app.packageName] = !(selected[app.packageName] ?: false)
                            }
                            .padding(vertical = 6.dp)
                    ) {
                        Checkbox(checked = checked, onCheckedChange = {
                            selected[app.packageName] = it
                        })
                        Column(Modifier.weight(1f)) {
                            Text(app.appName, fontWeight = FontWeight.SemiBold)
                            Text("${app.packageName}  •  fg=${app.fgMinutes} phút  •  launches=${app.launchCount}")
                        }
                        Button(onClick = {
                            // Open app storage/settings screen
                            try {
                                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.parse("package:${app.packageName}")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                            } catch (_: Exception) { }
                        }) { Text("Quản lý") }
                    }
                    Divider()
                }
            }

            if (log.isNotEmpty()) {
                Text("Nhật ký", fontWeight = FontWeight.Bold)
                log.takeLast(8).forEach { Text("• $it") }
            }
        }
    }
}