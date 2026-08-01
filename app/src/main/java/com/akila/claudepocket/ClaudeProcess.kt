package com.akila.claudepocket

import android.content.Context
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.io.OutputStreamWriter

class ClaudeProcess(private val context: Context) {

    private var process: Process? = null
    private var writer: OutputStreamWriter? = null

    fun start(onOutputLine: (String) -> Unit) {
        val bootstrap = RuntimeBootstrap(context)
        val loaderPath =
            File(context.filesDir, "runtime/lib/ld-musl-aarch64.so.1").absolutePath
        val claudePath = File(context.filesDir, "runtime/claude").absolutePath
        val workDir = File(bootstrap.workspacePath())

        val pb = ProcessBuilder(loaderPath, claudePath)
            .directory(workDir)
            .redirectErrorStream(true)

        val env = pb.environment()
        env.remove("LD_PRELOAD")
        env["ANTHROPIC_API_KEY"] = SettingsActivity.getApiKey(context)
        val baseUrl = SettingsActivity.getBaseUrl(context)
        if (baseUrl.isNotBlank()) {
            env["ANTHROPIC_BASE_URL"] = baseUrl
        } else {
            env.remove("ANTHROPIC_BASE_URL")
        }

        process = pb.start()
        writer = OutputStreamWriter(process!!.outputStream)

        Thread {
            BufferedReader(InputStreamReader(process!!.inputStream)).use { reader ->
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    onOutputLine(line ?: "")
                }
            }
        }.start()
    }

    fun send(text: String) {
        writer?.write(text + "\n")
        writer?.flush()
    }

    fun stop() {
        writer?.close()
        writer = null
        process?.destroy()
        process = null
    }
}
