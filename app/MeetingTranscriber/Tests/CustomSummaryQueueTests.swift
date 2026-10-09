import Foundation
import XCTest
#if canImport(MeetingTranscriber)
    @testable import MeetingTranscriber
#else
    @testable import CustomMeetingCore
#endif

@MainActor
final class CustomSummaryQueueTests: XCTestCase {
    private func drain(_ queue: SerialSummaryQueue) async {
        for _ in 0 ..< 1000 {
            if !queue.isRunning { return }
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("The summary queue did not drain")
    }

    func testRequestsAreSerialAndFIFO() async {
        let queue = SerialSummaryQueue()
        let ids = [UUID(), UUID(), UUID()]
        var order: [UUID] = []
        var concurrent = 0
        var maximum = 0
        for id in ids {
            queue.enqueue(id: id) { next in
                concurrent += 1
                maximum = max(maximum, concurrent)
                order.append(next)
                try? await Task.sleep(for: .milliseconds(5))
                concurrent -= 1
            }
        }
        await drain(queue)
        XCTAssertEqual(order, ids)
        XCTAssertEqual(maximum, 1)
        XCTAssertNil(queue.activeID)
    }

    func testDuplicateQueuedAndActiveRequestsAreIgnored() async {
        let queue = SerialSummaryQueue()
        let id = UUID()
        var calls = 0
        let run: @MainActor (UUID) async -> Void = { _ in
            calls += 1
            queue.enqueue(id: id) { _ in calls += 100 }
            await Task.yield()
        }
        queue.enqueue(id: id, run: run)
        queue.enqueue(id: id, run: run)
        await drain(queue)
        XCTAssertEqual(calls, 1)
    }

    func testRequestsAddedDuringProcessingAreNotLost() async {
        let queue = SerialSummaryQueue()
        let first = UUID()
        let second = UUID()
        var order: [UUID] = []
        queue.enqueue(id: first) { id in
            order.append(id)
            queue.enqueue(id: second) { id in order.append(id) }
            await Task.yield()
        }
        await drain(queue)
        XCTAssertEqual(order, [first, second])
    }

    func testFinishedRequestCanBeRetried() async {
        let queue = SerialSummaryQueue()
        let id = UUID()
        var calls = 0
        queue.enqueue(id: id) { _ in calls += 1 }
        await drain(queue)
        queue.enqueue(id: id) { _ in calls += 1 }
        await drain(queue)
        XCTAssertEqual(calls, 2)
    }
}
