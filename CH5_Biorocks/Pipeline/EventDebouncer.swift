import Foundation

nonisolated struct DebounceDecision: Sendable {
    var promote: Bool
    var votes: Int
    var windowCount: Int
}

nonisolated struct EventDebouncer: Sendable {
    struct Candidate: Sendable {
        var time: TimeInterval
        var alertVote: Bool
        var pBlast: Double
    }

    private var recent: [Candidate] = []
    private var lastPromote: TimeInterval = -1_000

    mutating func consider(time: TimeInterval, pBlast: Double) -> DebounceDecision {
        let vote = pBlast >= PipelineConstants.blastThreshold
        recent.append(Candidate(time: time, alertVote: vote, pBlast: pBlast))
        recent.removeAll { time - $0.time > PipelineConstants.debounceSpanSeconds }
        let window = Array(recent.suffix(PipelineConstants.debounceN))
        let votes = window.filter(\.alertVote).count
        let promote = vote && votes >= PipelineConstants.debounceK && (time - lastPromote) >= 2.0
        if promote {
            lastPromote = time
        }
        return DebounceDecision(promote: promote, votes: votes, windowCount: window.count)
    }
}
