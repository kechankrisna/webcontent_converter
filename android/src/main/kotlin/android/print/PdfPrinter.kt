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
}


private fun getOutputFile(file: File): ParcelFileDescriptor {
    File(file.absolutePath).let{
        it.createNewFile()
        return ParcelFileDescriptor.open(it, ParcelFileDescriptor.MODE_READ_WRITE)
    }
}
