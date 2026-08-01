package com.akila.claudepocket

import android.content.Context
import java.io.File

/**
 * Everything this class touches lives under context.filesDir, e.g.:
 *   /data/data/com.akila.claudepocket/files/runtime/
 *   /data/data/com.akila.claudepocket/files/workspace/
 *
 * That folder is private to this app by default -- Android grants it with
 * zero permission prompts, and it is deleted automatically if the app is
 * uninstalled. Nothing here writes to shared storage, System, or root.
 *
 * STATUS: structural skeleton. The actual download URLs + checksums for the
 * patched claude binary and the glibc-runner helper are NOT filled in yet --
 * those need to be pulled from Anthropic's official release channel and
 * verified before this does anything real. Do not ship this as-is.
 */
class RuntimeBootstrap(private val context: Context) {

    private val runtimeDir: File get() = File(context.filesDir, "runtime")
    private val workspaceDir: File get() = File(context.filesDir, "workspace")

    fun isInstalled(): Boolean =
        File(runtimeDir, "bin/claude").exists()

    fun workspacePath(): String {
        if (!workspaceDir.exists()) workspaceDir.mkdirs()
        return workspaceDir.absolutePath
    }

    /**
     * Step-by-step plan (mirrors the community glibc-patch approach):
     *   1. Detect ABI. Only arm64-v8a is supported -- bail out clearly on
     *      armeabi-v7a devices instead of failing silently mid-download.
     *   2. Download glibc-runner + patchelf-glibc into runtimeDir/lib.
     *   3. Download the official linux-arm64 claude binary, verify its
     *      checksum against Anthropic's published hash before touching it.
     *   4. Patch the binary's ELF interpreter to point at the runner.
     *   5. Write a small launcher script into runtimeDir/bin/claude.
     *
     * Every step reports progress through the callback so the UI never
     * just sits on a spinner with no explanation.
     */
    fun install(onProgress: (String) -> Unit, onDone: (Boolean, String) -> Unit) {
        val abi = android.os.Build.SUPPORTED_ABIS.firstOrNull()
        if (abi != "arm64-v8a") {
            onDone(false, "Unsupported CPU ($abi). This needs a 64-bit ARM phone.")
            return
        }

        runtimeDir.mkdirs()

        // TODO: replace with verified download + checksum logic before real use.
        onProgress("Runtime download not wired up yet -- placeholder step.")
        onDone(false, "Bootstrap skeleton only. Next build session: wire up the real download.")
    }
}
