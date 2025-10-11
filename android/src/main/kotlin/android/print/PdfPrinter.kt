package android.print

import android.os.Build
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import java.io.File

class PdfPrinter(private val printAttributes: PrintAttributes) {

    interface Callback {
        fun onSuccess(filePath: String)
        fun onFailure()
    }


    fun print(printAdapter: PrintDocumentAdapter, file: File, callback: Callback) {
        // Support for min API 16 is required
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            printAdapter.onLayout(null, printAttributes, null, object : PrintDocumentAdapter.LayoutResultCallback() {

                override fun onLayoutFinished(info: PrintDocumentInfo, changed: Boolean) {
                    printAdapter.onWrite(arrayOf(PageRange.ALL_PAGES), getOutputFile(file),
                            CancellationSignal(), object : PrintDocumentAdapter.WriteResultCallback() {

                        override fun onWriteFinished(pages: Array<PageRange>) {
                            super.onWriteFinished(pages)

                            if (pages.isEmpty()) {
                                callback.onFailure()
                            }

                            File(file.absolutePath).let {
                                callback.onSuccess(it.absolutePath)
                            }

                        }
                    })
                }
            }, null)
        }
    }

    fun printBitmap(printAdapter: PrintDocumentAdapter, callback: BitmapCallback) {
        // Support for min API 16 is required
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            printAdapter.onLayout(null, printAttributes, null, object : PrintDocumentAdapter.LayoutResultCallback() {

                override fun onLayoutFinished(info: PrintDocumentInfo, changed: Boolean) {

                    // ✅ CREATE TEMP FILE: Still need file for PDF generation
                    val tempFile = File.createTempFile("temp_bitmap_", ".pdf")

                    printAdapter.onWrite(arrayOf(PageRange.ALL_PAGES), getOutputFile(tempFile),
                        CancellationSignal(), object : PrintDocumentAdapter.WriteResultCallback() {

                            override fun onWriteFinished(pages: Array<PageRange>) {
                                super.onWriteFinished(pages)

                                if (pages.isEmpty()) {
                                    callback.onFailure()
                                    return
                                }

                                // ✅ CONVERT PDF TO BITMAP: Read PDF and convert to bitmap bytes
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                    convertPdfToBitmapBytes(tempFile, callback)
                                } else {
                                    callback.onFailure()
                                }

                                // ✅ CLEANUP: Delete temp file after conversion
                                tempFile.delete()
                            }
                        })
                }
            }, null)
        } else {
            callback.onFailure()
        }
    }

    // ✅ CONVERT PDF TO BITMAP BYTES: Extract bitmap data from ALL pages of generated PDF
    private fun convertPdfToBitmapBytes(pdfFile: File, callback: BitmapCallback) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            try {
                val fileDescriptor = ParcelFileDescriptor.open(pdfFile, ParcelFileDescriptor.MODE_READ_ONLY)
                val pdfRenderer = android.graphics.pdf.PdfRenderer(fileDescriptor)

                if (pdfRenderer.pageCount > 0) {
                    // ✅ GET DIMENSIONS: Dynamically from print attributes instead of hardcoding
                    val mediaSize = printAttributes.mediaSize

                    // ✅ CALCULATE ACTUAL DIMENSIONS: Convert from print attributes to pixels
                    val widthPixels = if (mediaSize != null) {
                        // Convert from thousandths of an inch to pixels (96 DPI)
                        (mediaSize.widthMils / 1000.0 * 96).toInt()
                    } else {
                        794 // Fallback to A4 width if mediaSize is null
                    }

                    val heightPixels = if (mediaSize != null) {
                        // Convert from thousandths of an inch to pixels (96 DPI)
                        (mediaSize.heightMils / 1000.0 * 96).toInt()
                    } else {
                        1123 // Fallback to A4 height if mediaSize is null
                    }

                    println("[PdfPrinter] MediaSize: ${mediaSize?.widthMils}mil x ${mediaSize?.heightMils}mil")
                    println("[PdfPrinter] Converting PDF to bitmap - Pages: ${pdfRenderer.pageCount}")
                    println("[PdfPrinter] Calculated dimensions: ${widthPixels} x ${heightPixels} pixels")

                    // ✅ CALCULATE TOTAL HEIGHT: All pages stacked vertically
                    val totalPages = pdfRenderer.pageCount
                    val totalHeight = heightPixels * totalPages

                    println("[PdfPrinter] Creating combined bitmap: ${widthPixels} x ${totalHeight}")

                    // ✅ CREATE COMBINED BITMAP: For all pages
                    val combinedBitmap = android.graphics.Bitmap.createBitmap(
                        widthPixels,
                        totalHeight,
                        android.graphics.Bitmap.Config.ARGB_8888
                    )
                    val combinedCanvas = android.graphics.Canvas(combinedBitmap)

                    // ✅ WHITE BACKGROUND: Clean printable background
                    combinedCanvas.drawColor(android.graphics.Color.WHITE)

                    // ✅ RENDER ALL PAGES: Loop through each page
                    for (pageIndex in 0 until totalPages) {
                        println("[PdfPrinter] Rendering page ${pageIndex + 1}/${totalPages}")

                        val page = pdfRenderer.openPage(pageIndex)

                        // ✅ CREATE BITMAP FOR CURRENT PAGE
                        val pageBitmap = android.graphics.Bitmap.createBitmap(
                            widthPixels,
                            heightPixels,
                            android.graphics.Bitmap.Config.ARGB_8888
                        )
                        val pageCanvas = android.graphics.Canvas(pageBitmap)
                        pageCanvas.drawColor(android.graphics.Color.WHITE)

                        // ✅ RENDER CURRENT PAGE TO BITMAP
                        page.render(pageBitmap, null, null, android.graphics.pdf.PdfRenderer.Page.RENDER_MODE_FOR_PRINT)

                        // ✅ DRAW PAGE TO COMBINED CANVAS: Calculate Y position
                        val yPosition = pageIndex * heightPixels
                        combinedCanvas.drawBitmap(pageBitmap, 0f, yPosition.toFloat(), null)


                        // ✅ CLEANUP PAGE RESOURCES
                        page.close()
                        pageBitmap.recycle()
                    }

                    // ✅ CONVERT COMBINED BITMAP TO BYTE ARRAY
                    val outputStream = java.io.ByteArrayOutputStream()
                    combinedBitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, outputStream)
                    val bitmapBytes = outputStream.toByteArray()

                    // ✅ CLEANUP ALL RESOURCES
                    pdfRenderer.close()
                    fileDescriptor.close()
                    outputStream.close()
                    combinedBitmap.recycle()

                    println("[PdfPrinter] ✅ All ${totalPages} pages converted to bitmap bytes successfully")
                    callback.onSuccess(bitmapBytes)

                } else {
                    println("[PdfPrinter] ❌ PDF has no pages")
                    pdfRenderer.close()
                    fileDescriptor.close()
                    callback.onFailure()
                }

            } catch (e: Exception) {
                println("[PdfPrinter] ❌ Error converting PDF to bitmap: ${e.message}")
                callback.onFailure()
            }
        } else {
            callback.onFailure()
        }
    }
}

interface BitmapCallback {
    fun onSuccess(bitmapBytes: ByteArray)
    fun onFailure()
}


private fun getOutputFile(file: File): ParcelFileDescriptor {
    File(file.absolutePath).let{
        it.createNewFile()
        return ParcelFileDescriptor.open(it, ParcelFileDescriptor.MODE_READ_WRITE)
    }
}
