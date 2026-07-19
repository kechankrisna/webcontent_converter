package app.mylekha.webcontent_converter

import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.print.BitmapCallback
import android.print.inchToPx
import android.print.PaperFormat
import android.print.PdfPrinter
import android.print.PrintAttributes
import android.print.PrintManager
import android.util.Log
import android.view.View
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import com.izettle.html2bitmap.Html2Bitmap
import com.izettle.html2bitmap.Html2BitmapConfigurator
import com.izettle.html2bitmap.content.WebViewContent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import kotlin.math.absoluteValue


/** WebcontentConverterPlugin */
class WebcontentConverterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var activity: Activity
    private lateinit var context: Context
    private val sharedSession = SharedWebViewSession()
    private val conversionQueue = ConversionQueue(MAX_QUEUED_REQUESTS)

    companion object {
        private const val MAX_CONTENT_SIZE_BYTES = 100L * 1024 * 1024
        private const val MAX_QUEUED_REQUESTS = 32

        init {
            // Must run before ANY WebView is constructed anywhere in this process, or it's a
            // silent no-op (Android platform requirement) -- a companion `init` block is the
            // earliest hook this plugin has, firing when this class is loaded during Flutter's
            // plugin registration, before SharedWebViewSession/FLNativeViewFactory/
            // PrintPreviewWebView get a chance to construct their own WebViews.
            // Without it, WebView.draw(canvas) only rasters the tiles Chromium has already
            // composited for the visible viewport + a small overscan buffer, so screenshotting
            // content taller than roughly one screen leaves the remainder blank/white --
            // exactly the "bottom half is blank" symptom for long content.
            // If the host app creates a WebView earlier still (e.g. another plugin's own init,
            // or a custom Application.onCreate), this is already too late and the same call
            // must be made there instead.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                WebView.enableSlowWholeDocumentDraw()
            }
        }
    }

    private fun requestTimeoutMs(durationMs: Double): Long =
        maxOf(30_000L, durationMs.toLong() + 30_000L)

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val viewID = "webview-view-type"
        flutterPluginBinding.platformViewRegistry.registerViewFactory(viewID, FLNativeViewFactory())
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "webcontent_converter")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    @RequiresApi(Build.VERSION_CODES.JELLY_BEAN_MR1)
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        val method = call.method

        // Handled before the arguments-map cast below: this call carries no
        // "content" argument, and that cast is not null-safe.
        if (method == "isWebviewAvailable") {
            result.success(isWebViewAvailable())
            return
        }

        val arguments = call.arguments as Map<*, *>
        val content = arguments["content"] as String
        var duration = arguments["duration"] as Double?
        var savedPath = arguments["savedPath"] as? String

        // ✅ SAFE CASTING: Handle potential String to Map casting issues
        var margins: Map<String, Double>? = null
        var format: Map<String, *>? = null

        try {
            // Check if margins is actually a Map before casting
            val marginsArg = arguments["margins"]
            if (marginsArg is Map<*, *>) {
                margins = marginsArg as? Map<String, Double>
            } else if (marginsArg != null) {
                Log.w(
                    "webcontent_converter",
                    "margins is not a Map, it's a ${marginsArg::class.java.simpleName}: $marginsArg"
                )
            }

            // Check if format is actually a Map before casting
            val formatArg = arguments["format"]
            if (formatArg is Map<*, *>) {
                format = formatArg as? Map<String, Double>
            } else if (formatArg != null) {
                Log.w(
                    "webcontent_converter",
                    "format is not a Map, it's a ${formatArg::class.java.simpleName}: $formatArg"
                )
            }
        } catch (e: ClassCastException) {
            Log.e("webcontent_converter", "Casting error: ${e.message}")
            result.error("CAST_ERROR", "Invalid parameter types: ${e.message}", null)
            return
        }

        var is_html2bitmap = arguments["is_html2bitmap"] as? Boolean ?: false
        if (duration == null) duration = 2000.00
        val tag = "webcontent_converter";

        when (method) {
            "contentToImage" -> {
                if (content.toByteArray(Charsets.UTF_8).size > MAX_CONTENT_SIZE_BYTES) {
                    result.error("CONTENT_TOO_LARGE", "Content exceeds maximum size of 100MB", null)
                    return
                }
                if (conversionQueue.isQueueFull()) {
                    result.error(
                        "TOO_MANY_REQUESTS",
                        "Too many queued conversions (limit: $MAX_QUEUED_REQUESTS). Please wait for earlier ones to complete.",
                        null
                    )
                    return
                }
                if (is_html2bitmap) {
                    val bitmapWidth = arguments["bitmap_width"] as Double?
                    conversionQueue.startOrQueue {
                        runHtml2BitmapJob(content, bitmapWidth, duration!!, result)
                    }
                    return
                }
                conversionQueue.startOrQueue {
                    runContentToImageJob(content, format, margins, duration!!, result)
                }
            }

            "contentToPDF" -> {
                if (content.toByteArray(Charsets.UTF_8).size > MAX_CONTENT_SIZE_BYTES) {
                    result.error("CONTENT_TOO_LARGE", "Content exceeds maximum size of 100MB", null)
                    return
                }
                if (conversionQueue.isQueueFull()) {
                    result.error(
                        "TOO_MANY_REQUESTS",
                        "Too many queued conversions (limit: $MAX_QUEUED_REQUESTS). Please wait for earlier ones to complete.",
                        null
                    )
                    return
                }
                val path = savedPath
                val pdfFormat = format
                val pdfMargins = margins
                if (path == null || pdfFormat == null || pdfMargins == null) {
                    result.error("INVALID_ARGUMENT", "savedPath, format, and margins are required", null)
                    return
                }
                conversionQueue.startOrQueue {
                    runContentToPdfJob(content, path, pdfFormat, pdfMargins, duration!!, result)
                }
            }
            "printPreview" -> {
                if (content.toByteArray(Charsets.UTF_8).size > MAX_CONTENT_SIZE_BYTES) {
                    result.error("CONTENT_TOO_LARGE", "Content exceeds maximum size of 100MB", null)
                    return
                }
                if (conversionQueue.isQueueFull()) {
                    result.error(
                        "TOO_MANY_REQUESTS",
                        "Too many queued conversions (limit: $MAX_QUEUED_REQUESTS). Please wait for earlier ones to complete.",
                        null
                    )
                    return
                }
                conversionQueue.startOrQueue {
                    runPrintPreviewJob(content, duration!!, result)
                }
            }

            else
                -> result.notImplemented()
        }
    }

    private fun runContentToImageJob(
        content: String,
        format: Map<String, *>?,
        margins: Map<String, Double>?,
        duration: Double,
        result: Result
    ) {
        val watchdog = RequestWatchdog()
        var completed = false

        fun finish(action: () -> Unit) {
            if (completed) return
            completed = true
            watchdog.disarm()
            conversionQueue.onRequestFinished()
            action()
        }

        val webView = sharedSession.ensure(context)
        sharedSession.resetForNextJob()

        val dwidth = activity.window.windowManager.defaultDisplay.width
        val dheight = activity.window.windowManager.defaultDisplay.height
        webView.layout(0, 0, dwidth, dheight)
        webView.setInitialScale(1)

        watchdog.arm(requestTimeoutMs(duration)) {
            finish { result.error("TIMEOUT", "contentToImage timed out", null) }
        }

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView, url: String) {
                super.onPageFinished(view, url)
                val settleMs = (dheight / 1000).toInt() * 200
                Handler(Looper.getMainLooper()).postDelayed({
                    if (completed) return@postDelayed
                    if (format != null && format["name"] != null) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                            view.toPDFBitmap(format, margins, object : BitmapCallback {
                                override fun onSuccess(bitmapBytes: ByteArray) {
                                    finish { result.success(bitmapBytes) }
                                }
                                override fun onFailure() {
                                    finish {
                                        result.error("BITMAP_EXPORT_ERROR", "Failed to create bitmap from PDF", null)
                                    }
                                }
                            })
                        }
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                        view.evaluateJavascript(
                            "(function() { return [document.body.offsetWidth, document.body.offsetHeight]; })();"
                        ) { raw ->
                            if (completed) return@evaluateJavascript
                            val xy = JSONArray(raw)
                            val offsetWidth = xy[0].toString().toDouble()
                            val offsetHeight = xy[1].toString().toDouble()
                            val bitmap = view.toBitmap(offsetWidth, offsetHeight)
                            if (bitmap != null) {
                                finish { result.success(bitmap.toByteArray()) }
                            } else {
                                finish {
                                    result.error("BITMAP_EXPORT_ERROR", "Failed to measure content for bitmap", null)
                                }
                            }
                        }
                    }
                }, settleMs.toLong())
            }

            @Suppress("OVERRIDE_DEPRECATION")
            override fun onReceivedError(
                view: WebView,
                errorCode: Int,
                description: String?,
                failingUrl: String?
            ) {
                super.onReceivedError(view, errorCode, description, failingUrl)
                finish { result.error("WEBVIEW_LOAD_ERROR", description ?: "WebView failed to load content", null) }
            }

            override fun onReceivedError(
                view: WebView,
                request: WebResourceRequest,
                error: WebResourceError
            ) {
                super.onReceivedError(view, request, error)
                if (request.isForMainFrame) {
                    finish {
                        result.error(
                            "WEBVIEW_LOAD_ERROR",
                            error.description?.toString() ?: "WebView failed to load content",
                            null
                        )
                    }
                }
            }
        }

        webView.loadDataWithBaseURL(null, content, "text/HTML", "UTF-8", null)
    }

    private fun runContentToPdfJob(
        content: String,
        savedPath: String,
        format: Map<String, *>,
        margins: Map<String, Double>,
        duration: Double,
        result: Result
    ) {
        val watchdog = RequestWatchdog()
        var completed = false

        fun finish(action: () -> Unit) {
            if (completed) return
            completed = true
            watchdog.disarm()
            conversionQueue.onRequestFinished()
            action()
        }

        val webView = sharedSession.ensure(context)
        sharedSession.resetForNextJob()

        val dwidth = activity.window.windowManager.defaultDisplay.width
        val dheight = activity.window.windowManager.defaultDisplay.height
        webView.layout(0, 0, dwidth, dheight)
        webView.setInitialScale(1)

        watchdog.arm(requestTimeoutMs(duration)) {
            finish { result.error("TIMEOUT", "contentToPDF timed out", null) }
        }

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView, url: String) {
                super.onPageFinished(view, url)
                Handler(Looper.getMainLooper()).postDelayed({
                    if (completed) return@postDelayed
                    view.exportAsPdfFromWebView(savedPath, format, margins, object : PdfPrinter.Callback {
                        override fun onSuccess(filePath: String) {
                            finish { result.success(filePath) }
                        }
                        override fun onFailure() {
                            // Matches the pre-existing contract: failure resolves
                            // with a null path rather than a PlatformException.
                            finish { result.success(null) }
                        }
                    })
                }, duration.toLong())
            }

            @Suppress("OVERRIDE_DEPRECATION")
            override fun onReceivedError(
                view: WebView,
                errorCode: Int,
                description: String?,
                failingUrl: String?
            ) {
                super.onReceivedError(view, errorCode, description, failingUrl)
                finish { result.error("WEBVIEW_LOAD_ERROR", description ?: "WebView failed to load content", null) }
            }

            override fun onReceivedError(
                view: WebView,
                request: WebResourceRequest,
                error: WebResourceError
            ) {
                super.onReceivedError(view, request, error)
                if (request.isForMainFrame) {
                    finish {
                        result.error(
                            "WEBVIEW_LOAD_ERROR",
                            error.description?.toString() ?: "WebView failed to load content",
                            null
                        )
                    }
                }
            }
        }

        webView.loadDataWithBaseURL(null, content, "text/HTML", "UTF-8", null)
    }

    private fun runHtml2BitmapJob(
        content: String,
        bitmapWidth: Double?,
        duration: Double,
        result: Result
    ) {
        val watchdog = RequestWatchdog()
        var completed = false

        fun finish(action: () -> Unit) {
            if (completed) return
            completed = true
            watchdog.disarm()
            conversionQueue.onRequestFinished()
            action()
        }

        watchdog.arm(requestTimeoutMs(duration)) {
            finish { result.error("TIMEOUT", "contentToImage (html2bitmap) timed out", null) }
        }

        CoroutineScope(Dispatchers.IO).launch {
            val bitmap = try {
                val builder = Html2Bitmap.Builder()
                builder.setContext(context)
                builder.setContent(WebViewContent.html(content))
                builder.setConfigurator(Html2BitmapConfigurator())
                if (bitmapWidth != null && bitmapWidth > 0) {
                    builder.setBitmapWidth(bitmapWidth.toInt())
                }
                builder.setStrictMode(true)
                builder.build().bitmap
            } catch (e: Exception) {
                Log.e("webcontent_converter", e.stackTraceToString())
                null
            }
            withContext(Dispatchers.Main) {
                if (bitmap != null) {
                    finish { result.success(bitmap.toByteArray()) }
                } else {
                    finish { result.error("webview.build", "Failed to generate bitmap", null) }
                }
            }
        }
    }

    private fun runPrintPreviewJob(content: String, duration: Double, result: Result) {
        val watchdog = RequestWatchdog()
        var completed = false

        fun finish(action: () -> Unit) {
            if (completed) return
            completed = true
            watchdog.disarm()
            conversionQueue.onRequestFinished()
            action()
        }

        val printPreview = PrintPreviewWebView(context)
        val webView = printPreview.create()

        val dwidth = activity.window.windowManager.defaultDisplay.width
        val dheight = activity.window.windowManager.defaultDisplay.height
        webView.layout(0, 0, dwidth, dheight)
        webView.setInitialScale(1)

        watchdog.arm(requestTimeoutMs(duration)) {
            printPreview.destroy()
            finish { result.error("TIMEOUT", "printPreview timed out", null) }
        }

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView, url: String) {
                super.onPageFinished(view, url)
                Handler(Looper.getMainLooper()).postDelayed({
                    if (completed) return@postDelayed
                    val printManager = activity.getSystemService(Context.PRINT_SERVICE) as? PrintManager
                    if (printManager == null) {
                        printPreview.destroy()
                        finish { result.error("PRINT_UNAVAILABLE", "PrintManager unavailable", null) }
                        return@postDelayed
                    }
                    val jobName = "${activity.applicationContext.applicationInfo.name} print preview"
                    try {
                        printPreview.startPrintJob(printManager, jobName)
                        // Resolve at hand-off to the OS print flow, not at
                        // print completion -- matches the Windows plugin,
                        // which also resolves here. printPreview.destroy()
                        // for this successful case happens later, from
                        // PrintPreviewWebView's own PrintJob listener once
                        // the OS reports a terminal state.
                        finish { result.success(true) }
                    } catch (e: Exception) {
                        printPreview.destroy()
                        finish { result.error("PRINT_PREVIEW_FAILED", e.message, null) }
                    }
                }, duration.toLong())
            }

            @Suppress("OVERRIDE_DEPRECATION")
            override fun onReceivedError(
                view: WebView,
                errorCode: Int,
                description: String?,
                failingUrl: String?
            ) {
                super.onReceivedError(view, errorCode, description, failingUrl)
                if (completed) return
                printPreview.destroy()
                finish { result.error("WEBVIEW_LOAD_ERROR", description ?: "WebView failed to load content", null) }
            }

            override fun onReceivedError(
                view: WebView,
                request: WebResourceRequest,
                error: WebResourceError
            ) {
                super.onReceivedError(view, request, error)
                if (completed) return
                if (request.isForMainFrame) {
                    printPreview.destroy()
                    finish {
                        result.error(
                            "WEBVIEW_LOAD_ERROR",
                            error.description?.toString() ?: "WebView failed to load content",
                            null
                        )
                    }
                }
            }
        }

        webView.loadDataWithBaseURL(null, content, "text/HTML", "UTF-8", null)
    }

    // getCurrentWebViewPackage() (API 26+) returns null when no WebView
    // provider is installed on the device; below that, WebView still exists
    // as a bundled system component, so a failed WebView() construction
    // (e.g. MissingWebViewPackageException on OEM builds without it) is the
    // only signal available.
    private fun isWebViewAvailable(): Boolean {
        return try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                WebView.getCurrentWebViewPackage() != null
            } else {
                WebView(this.context)
                true
            }
        } catch (e: Throwable) {
            Log.w("webcontent_converter", "WebView unavailable: ${e.message}")
            false
        }
    }

    //test to save bitmap to file
    fun saveWebView(data: Bitmap): Boolean {
        var path = this.context.getExternalFilesDir(null).toString() + "/sample.jpg"
        var file = File(path)
        file.writeBitmap(data!!, Bitmap.CompressFormat.JPEG, 100)
        return true
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        sharedSession.ensure(context)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // TODO: the Activity your plugin was attached to was destroyed to change configuration.
        // This call will be followed by onReattachedToActivityForConfigChanges().
        print("onDetachedFromActivityForConfigChanges");
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        // TODO: your plugin is now attached to a new Activity after a configuration change.
        print("onAttachedToActivity")
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        // TODO: your plugin is no longer associated with an Activity. Clean up references.
        print("onDetachedFromActivity")
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        sharedSession.destroy()
    }

}

fun WebView.exportAsPdfFromWebView(
    savedPath: String,
    format: Map<String, *>,
    margins: Map<String, Double>,
    callback: PdfPrinter.Callback
) {
    print("\nsavedPath ${savedPath}")
    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
        var width = (format["width"] as Number).toDouble();
        var height = (format["height"] as Number).toDouble();
        var attributes = PrintAttributes.Builder()
            .setMediaSize(
                PrintAttributes.MediaSize(
                    "${width}-${height}",
                    "android",
                    width.convertFromInchesToInt(),
                    height.convertFromInchesToInt()
                )
            )
            .setResolution(PrintAttributes.Resolution("pdf", "pdf", 600, 600))
            .setMinMargins(
                PrintAttributes.Margins(
                    (margins!!["left"] as Number).toDouble().convertFromInchesToInt(),
                    (margins!!["top"] as Number).toDouble().convertFromInchesToInt(),
                    (margins!!["right"] as Number).toDouble().convertFromInchesToInt(),
                    (margins!!["bottom"] as Number).toDouble().convertFromInchesToInt()
                )
            )
            .build()
        var file = File(savedPath)
        val fileName = file.absoluteFile.name
        var pdfPrinter = PdfPrinter(attributes)
        val adapter = this.createPrintDocumentAdapter(fileName)
        pdfPrinter.print(adapter, file, callback)
    } else {
        TODO("VERSION.SDK_INT < LOLLIPOP")
    }
}

fun Double.convertFromInchesToInt(): Int {
    if (this > 0) {
        return (this.toInt() * 1000)
    }
    return this.toInt()
}

// Conservative cap well under the common 8192px GPU texture ceiling: bitmaps taller/wider than
// this fail to decode on the Flutter/Android side with ImageDecoder "unimplemented" errors.
private const val MAX_BITMAP_DIMENSION = 4096

fun WebView.toBitmap(offsetWidth: Double, offsetHeight: Double): Bitmap? {
    if (offsetHeight > 0 && offsetWidth > 0) {
        val rawWidth = (offsetWidth * this.scale).absoluteValue.toInt()
        val rawHeight = (offsetHeight * this.scale).absoluteValue.toInt()

        val shrink = minOf(
            1.0,
            MAX_BITMAP_DIMENSION.toDouble() / rawWidth,
            MAX_BITMAP_DIMENSION.toDouble() / rawHeight
        )
        val width = (rawWidth * shrink).toInt().coerceAtLeast(1)
        val height = (rawHeight * shrink).toInt().coerceAtLeast(1)
        print("\nwidth $width (raw $rawWidth)")
        print("\nheight $height (raw $rawHeight)")
        this.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        );
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        if (shrink < 1.0) {
            canvas.scale(shrink.toFloat(), shrink.toFloat())
        }
        this.draw(canvas)
        return bitmap
    }
    return null
}

fun WebView.toPDFBitmap(
    format: Map<String, *>,
    margins: Map<String, *>?,
    callback: BitmapCallback
): Bitmap? {

    var pageFormat = PaperFormat.fromString((format["name"] as String))
    // convert from inche into miles (96 DPI)
    var widthInMile = pageFormat.widthPixels * 1000 / 96; // 1 inches = 1000 miles
    var heightInMile = pageFormat.heightPixels * 1000 / 96;
    var marginTop = inchToPx(if (margins?.get("top") != null) (margins["top"] as Number).toDouble() else 0.5);
    var marginBottom = inchToPx(if (margins?.get("bottom") != null) (margins["bottom"] as Number).toDouble() else 0.5);
    var marginLeft = inchToPx(if (margins?.get("left") != null) (margins["left"] as Number).toDouble() else 0.5);
    var marginRight = inchToPx(if (margins?.get("right") != null) (margins["right"] as Number).toDouble() else 0.5);
//    println("marginTop ${marginTop}")
//    println("marginBottom ${marginBottom}")
//    println("marginLeft ${marginLeft}")
//    println("marginRight ${marginRight}")

    var attributes = PrintAttributes.Builder()
        .setMediaSize(PrintAttributes.MediaSize("${widthInMile}-${heightInMile}", "android", widthInMile, heightInMile))
        .setResolution(PrintAttributes.Resolution("pdf", "pdf", 600, 600))
        .setMinMargins(
            PrintAttributes.Margins(
                marginLeft.toInt(),
                marginTop.toInt(),
                marginRight.toInt(),
                marginBottom.toInt()
            )
        )
        .build()

    // ✅ USE YOUR CORRECTED PDF PRINTER: For bitmap generation
    val pdfPrinter = PdfPrinter(attributes)
    val adapter = this.createPrintDocumentAdapter("bitmap_export")

    // ✅ OPTION 1: PDF to bitmap conversion
    pdfPrinter.printBitmap(adapter, callback)
    return null
}

fun Bitmap.toByteArray(): ByteArray {
    ByteArrayOutputStream().apply {
        compress(Bitmap.CompressFormat.PNG, 100, this)
        return toByteArray()
    }
}

fun File.writeBitmap(bitmap: Bitmap, format: Bitmap.CompressFormat, quality: Int) {
    try {
        var fout = FileOutputStream(this.path)
        bitmap.compress(format, quality, fout)
        fout.flush()
        fout.close()
    } catch (e: Exception) {
        e.printStackTrace();
    }
}