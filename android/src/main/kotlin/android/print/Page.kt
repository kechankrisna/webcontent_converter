package android.print

// ✅ CONVERSION FUNCTIONS: Helper functions for unit conversions
fun pxToInches(px: Double): Double = px / 96.0

fun inchToPx(d: Double): Double = d * 96

fun cmToInches(cm: Double): Double = pxToInches(cm / 37.8)

fun mmToInches(mm: Double): Double = cmToInches(mm / 10.0)

// ✅ PAPER FORMAT CLASS: Kotlin equivalent of your Dart PaperFormat
data class PaperFormat(
    val width: Double,
    val height: Double
) {
    companion object {
        // ✅ PREDEFINED PAPER SIZES: Static constants like your Dart version
        val LETTER = PaperFormat(width = 8.5, height = 11.0)
        val LEGAL = PaperFormat(width = 8.5, height = 14.0)
        val TABLOID = PaperFormat(width = 11.0, height = 17.0)
        val LEDGER = PaperFormat(width = 17.0, height = 11.0)
        val A0 = PaperFormat(width = 33.1, height = 46.8)
        val A1 = PaperFormat(width = 23.4, height = 33.1)
        val A2 = PaperFormat(width = 16.54, height = 23.4)
        val A3 = PaperFormat(width = 11.7, height = 16.54)
        val A4 = PaperFormat(width = 8.27, height = 11.7)
        val A5 = PaperFormat(width = 5.83, height = 8.27)
        val A6 = PaperFormat(width = 4.13, height = 5.83)

        // ✅ FROM STRING FACTORY: Equivalent to your Dart factory constructor
        fun fromString(value: String): PaperFormat {
            return when (value.lowercase()) {
                "letter" -> LETTER
                "legal" -> LEGAL
                "tabloid" -> TABLOID
                "ledger" -> LEDGER
                "a0" -> A0
                "a1" -> A1
                "a2" -> A2
                "a3" -> A3
                "a4" -> A4
                "a5" -> A5
                "a6" -> A6
                else -> A4 // Default to A4
            }
        }

        // ✅ FACTORY CONSTRUCTORS: Different unit constructors
        fun inches(width: Double, height: Double): PaperFormat {
            return PaperFormat(width = width, height = height)
        }

        fun px(width: Int, height: Int): PaperFormat {
            return PaperFormat(
                width = pxToInches(width.toDouble()),
                height = pxToInches(height.toDouble())
            )
        }

        fun cm(width: Double, height: Double): PaperFormat {
            return PaperFormat(
                width = cmToInches(width),
                height = cmToInches(height)
            )
        }

        fun mm(width: Double, height: Double): PaperFormat {
            return PaperFormat(
                width = mmToInches(width),
                height = mmToInches(height)
            )
        }
    }

    // ✅ TO MAP: Convert to map for easy serialization
    fun toMap(): Map<String, Double> {
        return mapOf(
            "width" to width,
            "height" to height
        )
    }

    // ✅ PIXELS: Get dimensions in pixels (96 DPI)
    val widthPixels: Int get() = (width * 96).toInt()
    val heightPixels: Int get() = (height * 96).toInt()

    // ✅ TO STRING: Readable string representation
    override fun toString(): String {
        return "PaperFormat.inches(width: $width, height: $height)"
    }
}

// ✅ PDF MARGINS CLASS: Kotlin equivalent of your Dart PdfMargins
data class PdfMargins(
    val top: Double = 0.0,
    val bottom: Double = 0.0,
    val left: Double = 0.0,
    val right: Double = 0.0
) {
    companion object {
        // ✅ ZERO MARGINS: Static constant
        val ZERO = PdfMargins()

        // ✅ FACTORY CONSTRUCTORS: Different unit constructors
        fun inches(top: Double = 0.0, bottom: Double = 0.0, left: Double = 0.0, right: Double = 0.0): PdfMargins {
            return PdfMargins(top = top, bottom = bottom, left = left, right = right)
        }

        fun px(top: Int = 0, bottom: Int = 0, left: Int = 0, right: Int = 0): PdfMargins {
            return PdfMargins(
                top = pxToInches(top.toDouble()),
                bottom = pxToInches(bottom.toDouble()),
                left = pxToInches(left.toDouble()),
                right = pxToInches(right.toDouble())
            )
        }

        fun cm(top: Double = 0.0, bottom: Double = 0.0, left: Double = 0.0, right: Double = 0.0): PdfMargins {
            return PdfMargins(
                top = cmToInches(top),
                bottom = cmToInches(bottom),
                left = cmToInches(left),
                right = cmToInches(right)
            )
        }

        fun mm(top: Double = 0.0, bottom: Double = 0.0, left: Double = 0.0, right: Double = 0.0): PdfMargins {
            return PdfMargins(
                top = mmToInches(top),
                bottom = mmToInches(bottom),
                left = mmToInches(left),
                right = mmToInches(right)
            )
        }
    }

    // ✅ TO MAP: Convert to map for easy serialization
    fun toMap(): Map<String, Double> {
        return mapOf(
            "top" to top,
            "bottom" to bottom,
            "left" to left,
            "right" to right
        )
    }

    // ✅ TO STRING: Readable string representation
    override fun toString(): String {
        return "PdfMargins.inches(top: $top, bottom: $bottom, left: $left, right: $right)"
    }
}