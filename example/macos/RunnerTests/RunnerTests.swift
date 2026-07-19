import Cocoa
import FlutterMacOS
import XCTest
import PDFKit
import webcontent_converter

class ConversionQueueTests: XCTestCase {

    func testFifoOrdering() {
        let queue = ConversionQueue(maxQueuedRequests: 3)
        var order: [Int] = []

        // First job starts immediately (no busy slot)
        let exp1 = expectation(description: "job1")
        queue.startOrQueue {
            order.append(1)
            exp1.fulfill()
        }
        XCTAssertTrue(queue.requestInFlight)

        // Second and third jobs are queued
        let exp2 = expectation(description: "job2")
        let exp3 = expectation(description: "job3")
        queue.startOrQueue {
            order.append(2)
            exp2.fulfill()
        }
        queue.startOrQueue {
            order.append(3)
            exp3.fulfill()
        }
        XCTAssertFalse(queue.isQueueFull())

        // Complete job 1, job 2 should auto-start
        queue.onRequestFinished()
        wait(for: [exp2], timeout: 1.0)
        XCTAssertEqual(order, [1, 2])

        // Complete job 2, job 3 should auto-start
        queue.onRequestFinished()
        wait(for: [exp3], timeout: 1.0)
        XCTAssertEqual(order, [1, 2, 3])

        // After last job finishes, queue is idle
        queue.onRequestFinished()
        XCTAssertFalse(queue.requestInFlight)

        wait(for: [exp1], timeout: 0.1)
    }

    func testBusySlotSerialization_onlyOneJobRunsAtATime() {
        let queue = ConversionQueue(maxQueuedRequests: 5)
        var concurrentCount = 0
        var maxConcurrent = 0

        for i in 0..<3 {
            queue.startOrQueue {
                concurrentCount += 1
                maxConcurrent = max(maxConcurrent, concurrentCount)
                // Simulate work
                Thread.sleep(forTimeInterval: 0.05)
                concurrentCount -= 1
                queue.onRequestFinished()
            }
        }

        // After all jobs complete, verify only one was ever in flight
        XCTAssertEqual(maxConcurrent, 1)
    }

    func testIsQueueFull_boundary() {
        let queue = ConversionQueue(maxQueuedRequests: 2)
        XCTAssertFalse(queue.isQueueFull())

        // First job goes in-flight, queue is empty
        queue.startOrQueue { /* in-flight */ }
        XCTAssertFalse(queue.isQueueFull())

        // Two queued jobs = full
        queue.startOrQueue {}
        queue.startOrQueue {}
        XCTAssertTrue(queue.isQueueFull())

        // Complete in-flight job -> one queued job promoted -> queue slot opens
        queue.onRequestFinished()
        XCTAssertFalse(queue.isQueueFull())
    }

    func testStartOrQueue_runsImmediatelyWhenIdle() {
        let queue = ConversionQueue(maxQueuedRequests: 10)
        let exp = expectation(description: "runs")

        queue.startOrQueue {
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }

    func testOnRequestFinished_withEmptyQueue_staysIdle() {
        let queue = ConversionQueue(maxQueuedRequests: 10)
        queue.startOrQueue {}
        queue.onRequestFinished()
        XCTAssertFalse(queue.requestInFlight)

        // Multiple finishes on empty queue are harmless
        queue.onRequestFinished()
        XCTAssertFalse(queue.requestInFlight)
    }
}

class RequestWatchdogTests: XCTestCase {

    func testWatchdogFiresAfterTimeout() {
        let watchdog = RequestWatchdog()
        let exp = expectation(description: "timeout")

        watchdog.arm(timeoutMs: 100) {
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }

    func testDisarmPreventsStaleFire() {
        let watchdog = RequestWatchdog()
        let exp = expectation(description: "disarmed")
        exp.isInverted = true  // Should NOT fire

        watchdog.arm(timeoutMs: 100) {
            exp.fulfill()
        }
        watchdog.disarm()

        wait(for: [exp], timeout: 0.5)
    }

    func testRearmingCancelsPreviousTimer() {
        let watchdog = RequestWatchdog()
        let firstExp = expectation(description: "first")
        firstExp.isInverted = true  // Should NOT fire (overridden by second arm)
        let secondExp = expectation(description: "second")

        watchdog.arm(timeoutMs: 100) {
            firstExp.fulfill()
        }
        // Re-arm with shorter timeout
        watchdog.arm(timeoutMs: 50) {
            secondExp.fulfill()
        }

        wait(for: [secondExp], timeout: 1.0)
        wait(for: [firstExp], timeout: 0.2)
    }

    func testDisarmOnDeinit() {
        let exp = expectation(description: "deinit")
        exp.isInverted = true

        var watchdog: RequestWatchdog? = RequestWatchdog()
        watchdog?.arm(timeoutMs: 50) {
            exp.fulfill()
        }
        watchdog = nil  // deinit should disarm

        wait(for: [exp], timeout: 0.3)
    }

    func testMultipleArms_usesLatestTimeout() {
        let watchdog = RequestWatchdog()
        let exp = expectation(description: "latest")

        watchdog.arm(timeoutMs: 1000) { XCTFail("old timer should be cancelled") }
        watchdog.arm(timeoutMs: 10) { exp.fulfill() }

        wait(for: [exp], timeout: 1.0)
    }
}

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
