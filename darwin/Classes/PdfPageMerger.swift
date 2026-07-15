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
/// Returns `nil` if `pageDatas` is empty, if the PDF context can't be
/// created, or if any entry isn't a valid single-page PDF.
public func mergePdfPageSlices(
    pageDatas: [Data],
    pageWidth: Double,
    pageHeight: Double,
    marginTop: Double,
    marginLeft: Double
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
        // Content hangs from the top margin; its own height determines how
        // far down the page it reaches (shorter than a full page on the
        // last page of a document).
        let originY = pageHeight - marginTop - Double(sliceBounds.height)

        context.beginPDFPage(nil)
        context.saveGState()
        context.translateBy(x: CGFloat(marginLeft), y: CGFloat(originY))
        slicePage.draw(with: .mediaBox, to: context)
        context.restoreGState()
        context.endPDFPage()
    }

    context.closePDF()
    return outputData as Data
}
