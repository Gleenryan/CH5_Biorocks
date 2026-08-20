import Foundation

struct HomeAlert: Identifiable {
    let id: UUID
    let title: String
    let detail: String
    let severity: String
    let message: String

    init(event: BlastDetectionEvent) {
        id = event.id
        title = event.narrative.split(separator: "\n").first.map(String.init) ?? "Blast detection"
        detail = "\(event.siteName) · \(event.onsetTime.formatted(date: .abbreviated, time: .shortened))"
        severity = event.severity
        message = event.narrative
    }

    init(title: String, detail: String, severity: String, message: String) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.severity = severity
        self.message = message
    }

    static let preview = [
        HomeAlert(title: "Suspected Bombing", detail: "Pemuteran 1 · August 11th, 01:22", severity: "High", message: "Two loud bangs in a span of 15 seconds."),
        HomeAlert(title: "Human Activity", detail: "Amed 1 · August 9th, 08:32", severity: "Medium", message: "Prolonged high frequency noise, suspected human activity increase for 30 minutes."),
        HomeAlert(title: "Decreased Fish Activity", detail: "Amed 1 · August 9th, 08:37", severity: "Low", message: "Lower than usual noise of detected fish activity.")
    ]
}
