import Foundation

/// Single model request at a time, including requests arriving while an earlier one is suspended.
/// The durable Pending records live in the vault; this queue owns only live execution order.
@MainActor
final class SerialSummaryQueue {
    private struct Request {
        let id: UUID
        let run: @MainActor (UUID) async -> Void
    }

    private var requests: [Request] = []
    private var worker: Task<Void, Never>?
    private(set) var activeID: UUID?
    var isRunning: Bool {
        worker != nil
    }

    func enqueue(id: UUID, run: @escaping @MainActor (UUID) async -> Void) {
        guard activeID != id, !requests.contains(where: { $0.id == id }) else { return }
        requests.append(Request(id: id, run: run))
        guard worker == nil else { return }
        worker = Task {
            while !requests.isEmpty {
                let request = requests.removeFirst()
                activeID = request.id
                await request.run(request.id)
                activeID = nil
            }
            worker = nil
        }
    }
}
