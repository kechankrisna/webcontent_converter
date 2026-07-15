import Cocoa
import FlutterMacOS
import XCTest
import PDFKit
import webcontent_converter

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

  func testComputePdfPageSlices_contentShorterThanOnePage_returnsSingleSliceMatchingActualContent() {
    let slices = computePdfPageSlices(contentHeight: 300, pageHeight: 1000, marginTop: 50, marginBottom: 50)
    XCTAssertEqual(slices.count, 1)
    XCTAssertEqual(slices[0].sourceY, 0)
    XCTAssertEqual(slices[0].sourceHeight, 300)
  }

  func testComputePdfPageSlices_exactMultipleOfPageHeight_returnsExpectedPageCount() {
    // usableHeight = 1000 - 100 = 900; content = 1800 = exactly 2 pages.
    let slices = computePdfPageSlices(contentHeight: 1800, pageHeight: 1000, marginTop: 50, marginBottom: 50)
    XCTAssertEqual(slices.count, 2)
    XCTAssertEqual(slices[0].sourceY, 0)
    XCTAssertEqual(slices[0].sourceHeight, 900)
    XCTAssertEqual(slices[1].sourceY, 900)
    XCTAssertEqual(slices[1].sourceHeight, 900)
  }

  func testComputePdfPageSlices_withRemainder_lastPageIsShorter() {
    // usableHeight = 900; content = 2000 -> ceil(2000/900) = 3 pages, last = 2000 - 1800 = 200.
    let slices = computePdfPageSlices(contentHeight: 2000, pageHeight: 1000, marginTop: 50, marginBottom: 50)
    XCTAssertEqual(slices.count, 3)
    XCTAssertEqual(slices[2].sourceY, 1800)
    XCTAssertEqual(slices[2].sourceHeight, 200)
  }

  func testComputePdfPageSlices_zeroContent_returnsSingleSliceWithMinimumPositiveHeight() {
    let slices = computePdfPageSlices(contentHeight: 0, pageHeight: 1000, marginTop: 50, marginBottom: 50)
    XCTAssertEqual(slices.count, 1)
    XCTAssertEqual(slices[0].sourceHeight, 1)
  }

  func testComputePdfPageSlices_marginsExceedPageHeight_clampsUsableHeightToMinimumOne() {
    // usableHeight would be negative (100 - 120 = -20) and is clamped to a
    // minimum of 1, so degenerate margins degrade to many 1-unit-tall
    // pages instead of a negative-size rect or a crash.
    let slices = computePdfPageSlices(contentHeight: 10, pageHeight: 100, marginTop: 60, marginBottom: 60)
    XCTAssertEqual(slices.count, 10)
    XCTAssertEqual(slices.first?.sourceHeight, 1)
    XCTAssertEqual(slices.last?.sourceY, 9)
    XCTAssertEqual(slices.last?.sourceHeight, 1)
  }

  private func makeTestPdfPageData(width: CGFloat, height: CGFloat) -> Data {
    let pdfData = NSMutableData()
    var mediaBox = CGRect(x: 0, y: 0, width: width, height: height)
    guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
          let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
      fatalError("failed to create test PDF context")
    }
    context.beginPDFPage(nil)
    context.setFillColor(NSColor.red.cgColor)
    context.fill(mediaBox)
    context.endPDFPage()
    context.closePDF()
    return pdfData as Data
  }

  func testMergePdfPageSlices_emptyInput_returnsNil() {
    let result = mergePdfPageSlices(pageDatas: [], pageWidth: 800, pageHeight: 1000, marginTop: 50, marginLeft: 50)
    XCTAssertNil(result)
  }

  func testMergePdfPageSlices_invalidPdfData_returnsNil() {
    let result = mergePdfPageSlices(
      pageDatas: [Data([0x00, 0x01, 0x02])],
      pageWidth: 800, pageHeight: 1000, marginTop: 50, marginLeft: 50
    )
    XCTAssertNil(result)
  }

  func testMergePdfPageSlices_twoSlices_producesTwoPagesAtRequestedSize() {
    let slice1 = makeTestPdfPageData(width: 700, height: 900)
    let slice2 = makeTestPdfPageData(width: 700, height: 300)

    let merged = mergePdfPageSlices(
      pageDatas: [slice1, slice2],
      pageWidth: 800, pageHeight: 1000, marginTop: 50, marginLeft: 50
    )

    XCTAssertNotNil(merged)
    let document = PDFDocument(data: merged!)
    XCTAssertNotNil(document)
    XCTAssertEqual(document?.pageCount, 2)

    for pageIndex in 0..<2 {
      let bounds = document!.page(at: pageIndex)!.bounds(for: .mediaBox)
      XCTAssertEqual(Double(bounds.width), 800, accuracy: 0.5)
      XCTAssertEqual(Double(bounds.height), 1000, accuracy: 0.5)
    }
  }
}
