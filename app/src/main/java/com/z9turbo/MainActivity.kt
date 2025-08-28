package com.z9turbo

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.*

@OptIn(ExperimentalMaterial3Api::class)
class MainActivity : ComponentActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContent {
      MaterialTheme {
        Scaffold(
          topBar = { TopAppBar(title = { Text("Z9 Turbo") }) }
        ) { padding ->
          Box(Modifier.padding(padding).fillMaxSize()) {
            Greeting()
          }
        }
      }
    }
  }
}

@Composable fun Greeting() { Text("Hello from Z9 Turbo!") }
@Preview @Composable fun PreviewGreeting() { Greeting() }
