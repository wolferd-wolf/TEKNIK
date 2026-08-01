package com.akila.claudepocket

import android.content.Context
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.io.OutputStreamWriter

/**
 * Spawns the claude binary confined to workspacePath, with the API key and
 * base URL passed as environment variables -- same mechanism the official
 * CLI already supports (ANTHROPIC_API_KEY / ANTHROPIC_BASE_URL), no custom
 * auth plumbing needed.
 */
class ClaudeProcess(private val context: Context) {

    private var process: Process? = null
    private var writer: OutputStreamWriter? = null

    fun start(onOutputLine: (String) -> Unit) {
        val bootstrap = RuntimeBootstrap(context)
        val binPath = File(context.filesDir, "runtime/bin/claude").absolutePath
        val workDir = File(bootstrap.workspacePath())

        val env = HashMap(System.getenv())
        env["ANTHROPIC_API_KEY"] = SettingsActivity.getApiKey(context)
        val baseUrl = SettingsActivity.getBaseUrl(context)
        if (baseUrl.isNotBlank()) env["ANTHROPIC_BASE_URL"] = baseUrl

        val pb = ProcessBuilder(binPath)
            .directory(workDir)
            .redirectErrorStream(true)
        pb.environment().putAll(env)

        process = pb.start()
        writer = OutputStreamWriter(process!!.outputStream)

        Thread {
            val reader = BufferedReader(InputStreamReader(process!!.inputStream))
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                onOutputLine(line ?: "")
            }
        }.start()
    }

    fun send(text: String) {
        writer?.write(text + "\n")
        writer?.flush()
    }

    fun stop() {
        process?.destroy()
    }
}
