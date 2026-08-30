package com.example.sutoriraita

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract as Docs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var picker: MethodChannel.Result? = null
    private val incoming = java.util.concurrent.ConcurrentLinkedQueue<Uri>()
    private val worker = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        if (intent?.action == Intent.ACTION_VIEW) intent.data?.let { incoming.add(it) }
        MethodChannel(engine.dartExecutor.binaryMessenger, "sutoriraita/documents")
            .setMethodCallHandler { call, result ->
                if (call.method == "pickTree") {
                    if (picker != null) { result.error("busy", "Picker already open", null); return@setMethodCallHandler }
                    picker = result
                    val request = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                        Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                    startActivityForResult(request, 4812)
                    return@setMethodCallHandler
                }
                worker.execute {
                    try {
                        val root = call.argument<String>("root")?.let(Uri::parse)
                        val path = call.argument<String>("path") ?: ""
                        val value: Any? = when (call.method) {
                            "read" -> resolve(root!!, path, false)?.let { uri ->
                                contentResolver.openInputStream(uri)?.use { it.readBytes() }
                            }
                            "write" -> {
                                val uri = resolve(root!!, path, true)!!
                                contentResolver.openOutputStream(uri, "wt")!!.use {
                                    it.write(call.argument<ByteArray>("bytes")!!)
                                }
                                null
                            }
                            "list" -> {
                                val output = mutableListOf<String>()
                                resolve(root!!, path, false)?.let { collect(root, it, path, output) }
                                output
                            }
                            "nextDocument" -> incoming.poll()?.let { uri ->
                                contentResolver.openInputStream(uri)!!.use {
                                    val bytes = it.readBytes()
                                    if (bytes.size > 128 * 1024 * 1024) error("Project exceeds 128 MiB")
                                    bytes
                                }
                            }
                            else -> throw IllegalArgumentException("Unknown document method")
                        }
                        runOnUiThread { result.success(value) }
                    } catch (error: Exception) {
                        runOnUiThread { result.error("documents", error.message, null) }
                    }
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == Intent.ACTION_VIEW) intent.data?.let { incoming.add(it) }
    }

    @Deprecated("Activity result API required by FlutterActivity integration")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 4812) return
        val result = picker ?: return
        picker = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { result.success(null); return }
        try {
            val flags = data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            if (flags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION == 0) error("Choose a writable project folder")
            contentResolver.takePersistableUriPermission(uri, flags)
            result.success(uri.toString())
        } catch (error: Exception) { result.error("permission", error.message, null) }
    }

    private fun children(tree: Uri, parent: Uri): List<Triple<String, Uri, Boolean>> {
        val result = mutableListOf<Triple<String, Uri, Boolean>>()
        val query = Docs.buildChildDocumentsUriUsingTree(tree, Docs.getDocumentId(parent))
        contentResolver.query(query, arrayOf(Docs.Document.COLUMN_DOCUMENT_ID,
            Docs.Document.COLUMN_DISPLAY_NAME, Docs.Document.COLUMN_MIME_TYPE), null, null, null)!!.use { cursor ->
            while (cursor.moveToNext()) result.add(Triple(cursor.getString(1),
                Docs.buildDocumentUriUsingTree(tree, cursor.getString(0)),
                cursor.getString(2) == Docs.Document.MIME_TYPE_DIR))
        }
        return result
    }

    private fun resolve(tree: Uri, path: String, create: Boolean): Uri? {
        val parts = path.split('/')
        require(parts.all { it.isNotEmpty() && it != "." && it != ".." && !it.contains('\\') })
        var parent = Docs.buildDocumentUriUsingTree(tree, Docs.getTreeDocumentId(tree))
        for ((index, part) in parts.withIndex()) {
            val child = children(tree, parent).firstOrNull { it.first == part }
            parent = child?.second ?: if (create) {
                Docs.createDocument(contentResolver, parent,
                    if (index < parts.lastIndex) Docs.Document.MIME_TYPE_DIR else "application/octet-stream", part)
                    ?: error("Provider cannot create $part")
            } else return null
        }
        return parent
    }

    private fun collect(tree: Uri, parent: Uri, path: String, output: MutableList<String>, depth: Int = 0) {
        require(depth < 64 && output.size < 10000) { "Project tree is too large" }
        for ((name, uri, directory) in children(tree, parent)) {
            require(!name.contains('/') && !name.contains('\\') && name != "." && name != "..")
            if (directory) collect(tree, uri, "$path/$name", output, depth + 1)
            else output.add("$path/$name")
        }
    }
}
