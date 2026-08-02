package com.akila.claudepocket

import android.content.Context
import java.io.File
import java.util.concurrent.TimeUnit

class ClaudeProcess(private val context: Context) {

    private val sendLock = Any()
    private var hasSentMessage = false
    private var activeProcess: Process? = null

    fun send(text: String, onOutputLine: (String) -> Unit) {
        Thread {
            synchronized(sendLock) {
                try {
                    val bootstrap = RuntimeBootstrap(context)
                    val loaderPath =
                        File(context.filesDir, "runtime/lib/ld-musl-aarch64.so.1").absolutePath
                    val claudePath = File(context.filesDir, "runtime/claude").absolutePath
                    val prootPath = File(context.filesDir, "runtime/bin/proot").absolutePath
                    val resolvConfPath =
                        File(context.filesDir, "runtime/etc/resolv.conf").absolutePath
                    val prootTmpDir =
                        File(context.filesDir, "runtime/tmp").apply { mkdirs() }
                    val workDir = File(bootstrap.workspacePath())

                    val command = mutableListOf(
                        prootPath,
                        "-b",
                        "$resolvConfPath:/etc/resolv.conf",
                        loaderPath,
                        claudePath,
                        "-p"
                    )
                    if (hasSentMessage) command += "-c"
                    command += text

                    val processBuilder = ProcessBuilder(command)
                        .directory(workDir)
                        .redirectErrorStream(true)

                    val environment = processBuilder.environment()
                    environment.remove("LD_PRELOAD")
                    environment["PROOT_TMP_DIR"] = prootTmpDir.absolutePath
                    val homeDir = File(context.filesDir, "home").apply { mkdirs() }
                    environment["HOME"] = homeDir.absolutePath
                    environment["USER"] = "claude"
                    environment["LOGNAME"] = "claude"
                    val authToken = SettingsActivity.getAuthToken(context)
                    if (authToken.isNotBlank()) {
                        environment["ANTHROPIC_AUTH_TOKEN"] = authToken
                        environment["ANTHROPIC_API_KEY"] = ""
                    } else {
                        environment.remove("ANTHROPIC_AUTH_TOKEN")
                        environment["ANTHROPIC_API_KEY"] = SettingsActivity.getApiKey(context)
                    }
                    val baseUrl = SettingsActivity.getBaseUrl(context)
                    if (baseUrl.isNotBlank()) {
                        environment["ANTHROPIC_BASE_URL"] = baseUrl
                    } else {
                        environment.remove("ANTHROPIC_BASE_URL")
                    }

                    val resolvConf = File(resolvConfPath)
                    onOutputLine(
                        "DNS bind: $resolvConfPath -> /etc/resolv.conf, " +
                            "source exists=${resolvConf.exists()}, " +
                            "readable=${resolvConf.canRead()}"
                    )

                    val process = processBuilder.start()
                    activeProcess = process
                    val finished = process.waitFor(PROCESS_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                    if (!finished) {
                        process.destroyForcibly()
                        process.waitFor()
                        activeProcess = null
                        onOutputLine("Timed out after ${PROCESS_TIMEOUT_SECONDS}s")
                        return@synchronized
                    }

                    val exitCode = process.exitValue()
                    val output = process.inputStream.bufferedReader().use { it.readText() }
                    val outputLength = output.toByteArray(Charsets.UTF_8).size
                    activeProcess = null

                    onOutputLine("Exit code: $exitCode, output length: $outputLength bytes")
                    if (output.isNotEmpty()) {
                        onOutputLine(output)
                    }
                    if (exitCode == 0) {
                        hasSentMessage = true
                    } else {
                        onOutputLine("Claude process failed with exit code $exitCode.")
                    }
                } catch (error: Throwable) {
                    activeProcess = null
                    onOutputLine("Claude process error:\n${error.stackTraceToString()}")
                }
            }
        }.start()
    }

    fun stop() {
        synchronized(sendLock) {
            activeProcess?.destroy()
            activeProcess = null
        }
    }

    companion object {
        private const val PROCESS_TIMEOUT_SECONDS = 30L
    }
}
