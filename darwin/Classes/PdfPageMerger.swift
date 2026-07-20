//
//  PdfPageMerger.swift
//  webcontent_converter
//

import Foundation
import CoreGraphics
import PDFKit

/// Compose a sequence of single-page PDF byte blobs (each already cropped
/// to one page's worth of source content, in page order) into one PDF
/// document. Each slice is drawn into a full `pageWidth` x `pageHeight`
/// page, offset by `marginLeft`/`marginTop` so the printable margin stays
/// blank around the content — mirroring the margin-as-inset semantics the
/// iOS pagination path already uses in `exportAsPdfFromWebView`.
///
/// `pageWidth`/`pageHeight`/`marginTop`/`marginLeft` are all in the same
/// *output* units as the slices' own MediaBox unless `contentScale` is
/// passed — in which case slices are drawn scaled by that factor, letting
/// callers capture content at one DPI (e.g. a WebView's native 96dpi CSS
/// pixels, so HTML lays out normally) while emitting a page sized in a
/// different unit (e.g. 72dpi PDF points, fixed by the PDF spec).
///
/// Returns `nil` if `pageDatas` is empty, if the PDF context can't be
/// created, or if any entry isn't a valid single-page PDF.
public func mergePdfPageSlices(
    pageDatas: [Data],
    pageWidth: Double,
    pageHeight: Double,
    marginTop: Double,
    marginLeft: Double,
    contentScale: Double = 1.0
) -> Data? {
    guard !pageDatas.isEmpty else { return nil }

    let outputData = NSMutableData()
    var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
    guard let consumer = CGDataConsumer(data: outputData as CFMutableData),
          let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
        return nil
    }

    for sliceData in pageDatas {
        guard let sliceDocument = PDFDocument(data: sliceData),
              let slicePage = sliceDocument.page(at: 0) else {
            return nil
        }

        let sliceBounds = slicePage.bounds(for: .mediaBox)
        // Content hangs from the top margin; its own (scaled) height
        // determines how far down the page it reaches (shorter than a full
        // page on the last page of a document).
        let scaledHeight = Double(sliceBounds.height) * contentScale
        let originY = pageHeight - marginTop - scaledHeight

        context.beginPDFPage(nil)
        context.saveGState()
        context.translateBy(x: CGFloat(marginLeft), y: CGFloat(originY))
        context.scaleBy(x: CGFloat(contentScale), y: CGFloat(contentScale))
        slicePage.draw(with: .mediaBox, to: context)
        context.restoreGState()
        context.endPDFPage()
    }

    context.closePDF()
    return outputData as Data
}
