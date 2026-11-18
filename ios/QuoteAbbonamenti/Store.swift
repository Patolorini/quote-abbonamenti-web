import SwiftUI
import Observation

/// Stato dell'app: dati, tema, avvisi brevi. Ogni modifica viene salvata su SQLite.
@Observable
final class AppStore {
    static let shared = AppStore()

    var data: AppData { didSet { scheduleSave() } }
    var toast: String? = nil
    var tab = "mese"
    var viewY = Date().y
    var viewM = Date().mo
    var remY = Date().y
    var remM = Date().mo
    var tutorialAgain = false

    @ObservationIgnored private let db = Database()
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    init() {
        var d = db.load()
        d.settings.migrate()
        if d.settings.tutorialSeen == nil { d.settings.tutorialSeen = !d.subs.isEmpty } // chi usa già l'app non lo rivede
        data = d
    }

    var pal: Palette { Palette.make(data.settings) }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let self, !Task.isCancelled else { return }
            self.db.save(self.data)
            Notifications.reschedule(self.data)
        }
    }
    /// Salva subito (per esempio quando l'app va in secondo piano).
    func saveNow() { saveTask?.cancel(); db.save(data); Notifications.reschedule(data) }

    func show(_ msg: String) {
        toast = msg
        toastTask?.cancel()
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if !Task.isCancelled { self?.toast = nil }
        }
    }

    // MARK: azioni

    func togglePaid(_ item: Item, _ pk: String) {
        data.setPaid(item.y, item.m, item.sub.id, pk, item.share, item.paid == nil)
    }

    func loadSample() {
        let n = now()
        let created = isoString(D(n.y, n.mo - 5, 1))
        func sub(_ id: String, _ name: String, _ cat: String, _ total: Double, _ members: [(String, Double)], _ edit: (inout Sub) -> Void = { _ in }) -> Sub {
            var s = Sub(id: id, name: name); s.cat = cat; s.total = total; s.members = members.map { Member(name: $0.0, share: $0.1) }; s.createdAt = created
            edit(&s); return s
        }
        var d = data
        d.subs = [
            sub("ex-spotify", "Spotify Family", "musica", 22.95, [("Marco", 5.75), ("Giulia", 5.75)]) { $0.billingDay = 5; $0.renewalAlert = true },
            sub("ex-netflix", "Netflix", "video", 20.90, [("Marco", 10.45)]),
            sub("ex-disney", "Disney+", "video", 12.90, [("Luca", 6.45)]) { $0.trialEnd = isoString(D(n.y, n.mo, min(28, n.d + 16))) },
            sub("ex-icloud", "iCloud+ 2 TB", "cloud", 14.85, [("Giulia", 4.95), ("Luca", 4.95)]),
            sub("ex-m365", "Microsoft 365 Family", "software", 99, [("Giulia", 16.5), ("Luca", 16.5), ("Marco", 16.5)]) { $0.cycle = 12; $0.renewal = 3; $0.billingDay = 15; $0.renewalAlert = true; $0.notice = 30 },
        ]
        var r = Reminder(); r.id = "ex-r1"; r.day = 3; r.start = created
        d.reminders = [r]
        d.payments = [:]
        let delay = ["giulia": 0, "luca": 2, "marco": 6]
        func pay(_ y: Int, _ m: Int, only: String? = nil) {
            for p in d.peopleFor(y, m) where only == nil || p.key == only {
                for it in p.items {
                    let on = D(it.due.y, it.due.mo, it.due.d + (delay[p.key] ?? 1), 9)
                    d.setPaid(y, m, it.sub.id, p.key, it.share, true, at: min(on, n))
                }
            }
        }
        for k in stride(from: 5, through: 1, by: -1) { let x = D(n.y, n.mo - k, 1); pay(x.y, x.mo) }
        pay(n.y, n.mo, only: "giulia")
        data = d
        tab = "mese"; viewY = n.y; viewM = n.mo
        show("Dati di esempio caricati: puoi modificarli o cancellarli nelle Impostazioni")
    }

    func wipe() {
        let keep = data.settings
        var d = AppData(); d.settings = keep
        data = d
        show("Dati cancellati")
    }
}
