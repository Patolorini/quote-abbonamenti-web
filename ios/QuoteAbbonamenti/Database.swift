import Foundation
import SQLite3

// Archivio SQLite nella cartella dell'app (Application Support/quote.sqlite).
// Tabelle: abbonamenti, promemoria, pagamenti, contatti e impostazioni.

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class Database {
    private var db: OpaquePointer?
    private let enc = JSONEncoder()
    private let dec = JSONDecoder()

    init(url: URL? = nil) {
        let file = url ?? Database.defaultURL()
        if sqlite3_open(file.path, &db) != SQLITE_OK { db = nil; return }
        exec("PRAGMA journal_mode=WAL;")
        exec("""
        CREATE TABLE IF NOT EXISTS subs (id TEXT PRIMARY KEY, pos INTEGER NOT NULL, data TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS reminders (id TEXT PRIMARY KEY, pos INTEGER NOT NULL, data TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS payments (month TEXT NOT NULL, item TEXT NOT NULL, paid_on TEXT NOT NULL, amount REAL NOT NULL, PRIMARY KEY (month, item));
        CREATE TABLE IF NOT EXISTS contacts (person TEXT PRIMARY KEY, phone TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS settings (id INTEGER PRIMARY KEY CHECK (id = 1), data TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
        """)
    }
    deinit { sqlite3_close(db) }

    static func defaultURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("quote.sqlite")
    }

    @discardableResult
    private func exec(_ sql: String) -> Bool { sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK }

    private func query(_ sql: String, _ args: [Any?] = [], row: (OpaquePointer) -> Void = { _ in }) -> Bool {
        var st: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &st, nil) == SQLITE_OK, let st else { return false }
        defer { sqlite3_finalize(st) }
        for (i, a) in args.enumerated() {
            let idx = Int32(i + 1)
            switch a {
            case let s as String: sqlite3_bind_text(st, idx, s, -1, SQLITE_TRANSIENT)
            case let d as Double: sqlite3_bind_double(st, idx, d)
            case let n as Int: sqlite3_bind_int64(st, idx, Int64(n))
            default: sqlite3_bind_null(st, idx)
            }
        }
        while true {
            let r = sqlite3_step(st)
            if r == SQLITE_ROW { row(st); continue }
            return r == SQLITE_DONE
        }
    }
    private func text(_ st: OpaquePointer, _ col: Int32) -> String { sqlite3_column_text(st, col).map { String(cString: $0) } ?? "" }

    /// true se il database non ha ancora mai salvato niente.
    var isEmpty: Bool {
        var n = 0
        _ = query("SELECT COUNT(*) FROM meta WHERE key = 'saved'") { n = Int(sqlite3_column_int64($0, 0)) }
        return n == 0
    }

    func load() -> AppData {
        var data = AppData()
        _ = query("SELECT data FROM subs ORDER BY pos") { st in
            if let s = try? self.dec.decode(Sub.self, from: Data(self.text(st, 0).utf8)) { data.subs.append(s) }
        }
        _ = query("SELECT data FROM reminders ORDER BY pos") { st in
            if let r = try? self.dec.decode(Reminder.self, from: Data(self.text(st, 0).utf8)) { data.reminders.append(r) }
        }
        _ = query("SELECT month, item, paid_on, amount FROM payments") { st in
            data.payments[self.text(st, 0), default: [:]][self.text(st, 1)] = Payment(on: self.text(st, 2), amount: sqlite3_column_double(st, 3))
        }
        _ = query("SELECT person, phone FROM contacts") { st in data.contacts[self.text(st, 0)] = self.text(st, 1) }
        _ = query("SELECT data FROM settings WHERE id = 1") { st in
            if let s = try? self.dec.decode(Settings.self, from: Data(self.text(st, 0).utf8)) { data.settings = s }
        }
        return data
    }

    /// Salva tutto in una sola transazione (i dati sono pochi: è veloce e sicuro).
    func save(_ data: AppData) {
        guard db != nil else { return }
        exec("BEGIN IMMEDIATE;")
        var ok = exec("DELETE FROM subs; DELETE FROM reminders; DELETE FROM payments; DELETE FROM contacts;")
        for (i, s) in data.subs.enumerated() {
            if let j = try? enc.encode(s) { ok = ok && query("INSERT INTO subs (id, pos, data) VALUES (?, ?, ?)", [s.id, i, String(decoding: j, as: UTF8.self)]) }
        }
        for (i, r) in data.reminders.enumerated() {
            if let j = try? enc.encode(r) { ok = ok && query("INSERT INTO reminders (id, pos, data) VALUES (?, ?, ?)", [r.id, i, String(decoding: j, as: UTF8.self)]) }
        }
        for (mk, items) in data.payments { for (k, p) in items {
            ok = ok && query("INSERT INTO payments (month, item, paid_on, amount) VALUES (?, ?, ?, ?)", [mk, k, p.on, p.amount])
        } }
        for (pk, ph) in data.contacts { ok = ok && query("INSERT INTO contacts (person, phone) VALUES (?, ?)", [pk, ph]) }
        if let j = try? enc.encode(data.settings) { ok = ok && query("INSERT OR REPLACE INTO settings (id, data) VALUES (1, ?)", [String(decoding: j, as: UTF8.self)]) }
        ok = ok && query("INSERT OR REPLACE INTO meta (key, value) VALUES ('saved', ?)", [isoString(Date())])
        exec(ok ? "COMMIT;" : "ROLLBACK;")
    }
}
