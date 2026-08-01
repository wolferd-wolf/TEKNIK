package com.akila.claudepocket

import android.content.Context
import android.os.Build
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.zip.GZIPInputStream

class RuntimeBootstrap(private val context: Context) {

    private val runtimeDir: File get() = File(context.filesDir, "runtime")
    private val workspaceDir: File get() = File(context.filesDir, "workspace")
    private val claudeFile: File get() = File(runtimeDir, "claude")
    private val loaderFile: File get() = File(runtimeDir, "lib/ld-musl-aarch64.so.1")

    fun isInstalled(): Boolean =
        claudeFile.isFile && claudeFile.canExecute() &&
            loaderFile.isFile && loaderFile.canExecute()

    fun workspacePath(): String {
        if (!workspaceDir.exists()) workspaceDir.mkdirs()
        return workspaceDir.absolutePath
    }

    fun install(onProgress: (String) -> Unit, onDone: (Boolean, String) -> Unit) {
        Thread {
            val stagingDir = File(runtimeDir, ".installing")
            try {
                onProgress("Step 1/5: Checking device ABI.")
                val abi = Build.SUPPORTED_ABIS.firstOrNull()
                if (abi != "arm64-v8a") {
                    throw InstallException(
                        "Unsupported CPU ($abi). ClaudePocket requires arm64-v8a."
                    )
                }

                stagingDir.deleteRecursively()
                stagingDir.mkdirs()
                File(runtimeDir, "lib").mkdirs()

                onProgress("Step 2/5: Resolving the latest Claude Code GitHub release.")
                val release = JSONObject(downloadText(CLAUDE_LATEST_RELEASE_API))
                val tagName = release.optString("tag_name")
                val version = tagName.removePrefix("v")
                if (!VERSION_PATTERN.matches(version)) {
                    throw InstallException("GitHub returned an invalid Claude release tag: $tagName")
                }

                val assets = release.optJSONArray("assets")
                    ?: throw InstallException("Claude GitHub release contains no assets array.")
                var archiveName: String? = null
                var archiveUrl: String? = null
                var checksumsUrl: String? = null
                for (index in 0 until assets.length()) {
                    val asset = assets.getJSONObject(index)
                    val name = asset.optString("name")
                    val url = asset.optString("browser_download_url")
                    if (
                        name.contains("linux-arm64", ignoreCase = true) &&
                        name.contains("musl", ignoreCase = true) &&
                        name.endsWith(".tar.gz", ignoreCase = true)
                    ) {
                        archiveName = name
                        archiveUrl = url
                    }
                    if (name == CHECKSUMS_ASSET_NAME) {
                        checksumsUrl = url
                    }
                }

                val resolvedArchiveName = archiveName
                    ?: throw InstallException(
                        "Latest Claude GitHub release has no linux-arm64 musl .tar.gz asset."
                    )
                val resolvedArchiveUrl = archiveUrl
                    ?: throw InstallException("Claude musl asset has no browser_download_url.")
                val resolvedChecksumsUrl = checksumsUrl
                    ?: throw InstallException(
                        "Latest Claude GitHub release has no $CHECKSUMS_ASSET_NAME asset; " +
                            "installation stopped because the archive cannot be verified."
                    )

                onProgress("Step 2/5: Downloading $CHECKSUMS_ASSET_NAME for Claude Code $version.")
                val checksumsText = downloadText(resolvedChecksumsUrl)
                val expectedChecksum = findChecksum(checksumsText, resolvedArchiveName)
                    ?: throw InstallException(
                        "$CHECKSUMS_ASSET_NAME contains no checksum for $resolvedArchiveName."
                    )

                onProgress("Step 2/5: Downloading $resolvedArchiveName from GitHub Releases.")
                val archiveFile = File(stagingDir, resolvedArchiveName)
                downloadToFile(resolvedArchiveUrl, archiveFile)

                onProgress("Step 2/5: Verifying the Claude archive SHA-256.")
                val actualArchiveChecksum = sha256(archiveFile)
                if (!actualArchiveChecksum.equals(expectedChecksum, ignoreCase = true)) {
                    throw InstallException(
                        "Claude archive checksum mismatch. Expected $expectedChecksum, " +
                            "got $actualArchiveChecksum."
                    )
                }

                onProgress("Step 2/5: Extracting the verified Claude binary.")
                val stagedClaude = File(stagingDir, "claude")
                extractTarGzEntry(
                    archiveFile,
                    stagedClaude
                ) { path -> path.removePrefix("./") == "claude" }

                onProgress("Step 3/5: Reading Alpine's current aarch64 package index.")
                val alpineIndex = File(stagingDir, "APKINDEX.tar.gz")
                downloadToFile(ALPINE_INDEX_URL, alpineIndex)
                val indexText = extractTarGzTextEntry(alpineIndex) {
                    it.removePrefix("./") == "APKINDEX"
                }
                val muslVersion = findPackageVersion(indexText, "musl")
                    ?: throw InstallException("Alpine package index contains no aarch64 musl package.")
                val muslPackageUrl = "$ALPINE_REPOSITORY/musl-$muslVersion.apk"

                onProgress("Step 3/5: Downloading Alpine musl package: $muslPackageUrl")
                val muslPackage = File(stagingDir, "musl.apk")
                downloadToFile(muslPackageUrl, muslPackage)

                onProgress("Step 3/5: Extracting lib/ld-musl-aarch64.so.1.")
                val stagedLoader = File(stagingDir, "ld-musl-aarch64.so.1")
                extractTarGzEntry(
                    muslPackage,
                    stagedLoader
                ) { path ->
                    path.removePrefix("./") == "lib/ld-musl-aarch64.so.1"
                }

                onProgress("Step 4/5: Installing files and setting executable permissions.")
                replaceFile(stagedClaude, claudeFile)
                replaceFile(stagedLoader, loaderFile)
                if (!claudeFile.setExecutable(true, true) || !loaderFile.setExecutable(true, true)) {
                    throw InstallException("Android refused to mark the runtime files executable.")
                }

                onProgress("Step 5/5: Verifying Claude through the musl loader.")
                val verification = ProcessBuilder(
                    loaderFile.absolutePath,
                    claudeFile.absolutePath,
                    "--version"
                )
                    .directory(workspaceDir.apply { mkdirs() })
                    .redirectErrorStream(true)
                    .apply { environment().remove("LD_PRELOAD") }
                    .start()
                val versionOutput = verification.inputStream.bufferedReader().use { it.readText().trim() }
                val exitCode = verification.waitFor()
                if (exitCode != 0 || versionOutput.isBlank()) {
                    throw InstallException(
                        "Claude verification failed (exit $exitCode): " +
                            versionOutput.ifBlank { "no output" }
                    )
                }

                stagingDir.deleteRecursively()
                val installedBytes = directorySize(runtimeDir)
                val installedMiB = installedBytes / (1024L * 1024L)
                if (installedMiB !in 240L..300L) {
                    throw InstallException(
                        "Runtime verified, but installed size is ${installedMiB} MiB; " +
                            "expected roughly 265-270 MiB."
                    )
                }

                dumpRuntimeFiles(onProgress)
                onDone(
                    true,
                    "Installed Claude Code $version via Alpine musl loader " +
                        "(${installedMiB} MiB). Verified: $versionOutput"
                )
            } catch (e: Exception) {
                // TEMPORARY DIAGNOSTIC: report every runtime file before failure cleanup.
                dumpRuntimeFiles(onProgress)
                stagingDir.deleteRecursively()
                claudeFile.delete()
                loaderFile.delete()
                onDone(false, e.message ?: "Runtime installation failed.")
            }
        }.start()
    }

    // TEMPORARY DIAGNOSTIC: remove after the on-device runtime-size investigation.
    private fun dumpRuntimeFiles(onProgress: (String) -> Unit) {
        onProgress("Runtime file diagnostic:")
        val files = runtimeDir.walkTopDown()
            .filter { it.isFile }
            .sortedBy { it.relativeTo(runtimeDir).invariantSeparatorsPath }
            .toList()
        var totalBytes = 0L
        for (file in files) {
            val size = file.length()
            totalBytes += size
            val relativePath = file.relativeTo(runtimeDir).invariantSeparatorsPath
            onProgress("runtime/$relativePath — $size bytes")
        }
        onProgress("Runtime diagnostic total: $totalBytes bytes")
    }

    private fun findChecksum(checksums: String, assetName: String): String? =
        checksums.lineSequence()
            .map { it.trim() }
            .mapNotNull { line ->
                val match = CHECKSUM_LINE_PATTERN.matchEntire(line) ?: return@mapNotNull null
                match.groupValues[1].lowercase() to match.groupValues[2].removePrefix("*")
            }
            .firstOrNull { it.second == assetName }
            ?.first

    private fun downloadText(url: String): String {
        val connection = openConnection(url)
        return try {
            connection.inputStream.bufferedReader().use { it.readText() }
        } finally {
            connection.disconnect()
        }
    }

    private fun downloadToFile(url: String, destination: File) {
        destination.parentFile?.mkdirs()
        val connection = openConnection(url)
        try {
            BufferedInputStream(connection.inputStream).use { input ->
                FileOutputStream(destination).use { output ->
                    input.copyTo(output, DOWNLOAD_BUFFER_SIZE)
                }
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun openConnection(url: String): HttpURLConnection {
        var current = URL(url)
        repeat(MAX_REDIRECTS) {
            val connection = current.openConnection() as HttpURLConnection
            connection.instanceFollowRedirects = false
            connection.connectTimeout = CONNECT_TIMEOUT_MS
            connection.readTimeout = READ_TIMEOUT_MS
            connection.setRequestProperty("User-Agent", "ClaudePocket/1.0")
            connection.setRequestProperty("Accept", "application/vnd.github+json")
            connection.connect()

            when (connection.responseCode) {
                in 200..299 -> return connection
                in 300..399 -> {
                    val location = connection.getHeaderField("Location")
                        ?: throw InstallException("Redirect without Location from $current")
                    current = URL(current, location)
                    connection.disconnect()
                }
                else -> {
                    val code = connection.responseCode
                    connection.disconnect()
                    throw InstallException("HTTP $code while downloading $current")
                }
            }
        }
        throw InstallException("Too many redirects while downloading $url")
    }

    private fun findPackageVersion(index: String, packageName: String): String? =
        index.split("\n\n")
            .asSequence()
            .map { stanza ->
                stanza.lineSequence()
                    .mapNotNull { line ->
                        val separator = line.indexOf(':')
                        if (separator <= 0) null
                        else line.substring(0, separator) to line.substring(separator + 1)
                    }
                    .toMap()
            }
            .firstOrNull { it["P"] == packageName }
            ?.get("V")

    private fun extractTarGzTextEntry(
        archive: File,
        matches: (String) -> Boolean
    ): String {
        var result: String? = null
        readTarGz(archive) { path, size, input ->
            if (result == null && matches(path)) {
                result = readExactly(input, size).toString(Charsets.UTF_8)
                size
            } else {
                0L
            }
        }
        return result ?: throw InstallException("Required archive entry was not found.")
    }

    private fun extractTarGzEntry(
        archive: File,
        destination: File,
        matches: (String) -> Boolean
    ) {
        var found = false
        readTarGz(archive) { path, size, input ->
            if (!found && matches(path)) {
                destination.parentFile?.mkdirs()
                FileOutputStream(destination).use { output ->
                    copyExactly(input, output, size)
                }
                found = true
                size
            } else {
                0L
            }
        }
        if (!found) {
            throw InstallException("Required archive entry was not found in ${archive.name}.")
        }
    }

    private fun readTarGz(
        archive: File,
        visitor: (path: String, size: Long, input: InputStream) -> Long
    ) {
        GZIPInputStream(BufferedInputStream(FileInputStream(archive))).use { input ->
            val header = ByteArray(TAR_BLOCK_SIZE)
            while (true) {
                readFullyOrEof(input, header) ?: break
                if (header.all { it == 0.toByte() }) break

                val path = tarString(header, 0, 100)
                val size = tarOctal(header, 124, 12)
                val consumed = visitor(path, size, input)
                if (consumed < 0 || consumed > size) {
                    throw InstallException("Invalid tar reader state.")
                }
                skipExactly(input, size - consumed)
                val padding = (TAR_BLOCK_SIZE - (size % TAR_BLOCK_SIZE)) % TAR_BLOCK_SIZE
                skipExactly(input, padding)
            }
        }
    }

    private fun readExactly(input: InputStream, size: Long): ByteArray {
        if (size > Int.MAX_VALUE) throw InstallException("Archive entry is too large.")
        val bytes = ByteArray(size.toInt())
        var offset = 0
        while (offset < bytes.size) {
            val read = input.read(bytes, offset, bytes.size - offset)
            if (read < 0) throw InstallException("Unexpected end of archive.")
            offset += read
        }
        return bytes
    }

    private fun copyExactly(input: InputStream, output: FileOutputStream, size: Long) {
        val buffer = ByteArray(DOWNLOAD_BUFFER_SIZE)
        var remaining = size
        while (remaining > 0) {
            val read = input.read(buffer, 0, minOf(buffer.size.toLong(), remaining).toInt())
            if (read < 0) throw InstallException("Unexpected end of archive.")
            output.write(buffer, 0, read)
            remaining -= read
        }
    }

    private fun skipExactly(input: InputStream, count: Long) {
        var remaining = count
        while (remaining > 0) {
            val skipped = input.skip(remaining)
            if (skipped > 0) {
                remaining -= skipped
            } else if (input.read() >= 0) {
                remaining--
            } else {
                throw InstallException("Unexpected end of archive.")
            }
        }
    }

    private fun readFullyOrEof(input: InputStream, buffer: ByteArray): ByteArray? {
        var offset = 0
        while (offset < buffer.size) {
            val read = input.read(buffer, offset, buffer.size - offset)
            if (read < 0) {
                if (offset == 0) return null
                throw InstallException("Truncated tar header.")
            }
            offset += read
        }
        return buffer
    }

    private fun tarString(header: ByteArray, offset: Int, length: Int): String {
        val end = (offset until offset + length)
            .firstOrNull { header[it] == 0.toByte() }
            ?: offset + length
        return header.copyOfRange(offset, end).toString(Charsets.UTF_8)
    }

    private fun tarOctal(header: ByteArray, offset: Int, length: Int): Long {
        val text = tarString(header, offset, length).trim().trim('\u0000')
        return if (text.isEmpty()) 0L else text.toLong(8)
    }

    private fun replaceFile(source: File, destination: File) {
        destination.parentFile?.mkdirs()
        val temporary = File(destination.parentFile, "${destination.name}.new")
        source.copyTo(temporary, overwrite = true)
        if (destination.exists() && !destination.delete()) {
            temporary.delete()
            throw InstallException("Could not replace ${destination.absolutePath}.")
        }
        if (!temporary.renameTo(destination)) {
            temporary.delete()
            throw InstallException("Could not install ${destination.absolutePath}.")
        }
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(file).use { input ->
            val buffer = ByteArray(DOWNLOAD_BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    private fun directorySize(file: File): Long =
        if (file.isFile) file.length()
        else file.listFiles()?.sumOf(::directorySize) ?: 0L

    private class InstallException(message: String) : Exception(message)

    companion object {
        private const val CLAUDE_LATEST_RELEASE_API =
            "https://api.github.com/repos/anthropics/claude-code/releases/latest"
        private const val CHECKSUMS_ASSET_NAME = "SHASUMS256.txt"
        private const val ALPINE_REPOSITORY =
            "https://dl-cdn.alpinelinux.org/alpine/latest-stable/main/aarch64"
        private const val ALPINE_INDEX_URL = "$ALPINE_REPOSITORY/APKINDEX.tar.gz"
        private const val CONNECT_TIMEOUT_MS = 30_000
        private const val READ_TIMEOUT_MS = 120_000
        private const val MAX_REDIRECTS = 5
        private const val DOWNLOAD_BUFFER_SIZE = 64 * 1024
        private const val TAR_BLOCK_SIZE = 512
        private val VERSION_PATTERN = Regex("""\d+\.\d+\.\d+""")
        private val CHECKSUM_LINE_PATTERN = Regex("""([0-9a-fA-F]{64})\s+(.+)""")
    }
}
