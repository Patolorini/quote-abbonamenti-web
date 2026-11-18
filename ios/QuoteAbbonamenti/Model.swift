import Foundation

// Dati dell'app. Il formato è lo stesso del backup della versione web e Android,
// così un backup si può importare in qualsiasi versione.

struct Member: Codable, Hashable {
    var name: String
    var share: Double
}

struct PriceChange: Codable, Hashable {
    var from: String          // "AAAA-MM"; "0000-01" = dall'inizio
    var total: Double
    var members: [Member]
}

struct Sub: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var cat: String = "altro"
    var total: Double = 0
    var cycle: Int = 1          // 1, 3, 6, 12 mesi
    var renewal: Int = 1        // mese del rinnovo (1-12)
    var split: String = "rate"  // "rate" o "unica"
    var members: [Member] = []
    var history: [PriceChange] = []
    var createdAt: String = isoString(Date())
    var billingDay: Int = 0
    var renewalAlert: Bool = false
    var alertDays: Int = 3
    var notice: Int = 0
    var trialEnd: String? = nil

    init(id: String = uid(), name: String = "") { self.id = id; self.name = name }

    enum CodingKeys: String, CodingKey { case id, name, cat, total, cycle, renewal, split, members, history, createdAt, billingDay, renewalAlert, alertDays, notice, trialEnd }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = c.v(.name, "")
        cat = c.v(.cat, "altro")
        total = c.v(.total, 0.0)
        cycle = c.v(.cycle, 1)
        renewal = c.v(.renewal, 1)
        split = c.v(.split, "rate")
        members = c.v(.members, [Member]())
        history = c.v(.history, [PriceChange]())
        createdAt = c.v(.createdAt, isoString(Date(timeIntervalSince1970: 0)))
        billingDay = c.v(.billingDay, 0)
        renewalAlert = c.v(.renewalAlert, false)
        alertDays = c.v(.alertDays, 3)
        notice = c.v(.notice, 0)
        trialEnd = try? c.decodeIfPresent(String.self, forKey: .trialEnd)
    }
}

struct Reminder: Codable, Identifiable, Hashable {
    var id: String = uid()
    var day: Int = 1            // 0 = ultimo giorno del mese
    var h: Int = 9
    var m: Int = 0
    var we: String = "no"       // "no", "prima", "dopo"
    var rep: String = "mese"    // "mese" o "una"
    var onceY: Int = Date().y
    var onceM: Int = Date().mo
    var endMode: String = "mai" // "mai", "dopo", "data"
    var endCount: Int = 12
    var endDate: String? = nil
    var start: String = isoString(Date())
    var label: String = ""
    var all: Bool = true
    var subs: [String] = []
    var on: Bool = true

    init() {}
    enum CodingKeys: String, CodingKey { case id, day, h, m, we, rep, onceY, onceM, endMode, endCount, endDate, start, label, all, subs, on }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = c.v(.id, uid())
        day = c.v(.day, 1); h = c.v(.h, 9); m = c.v(.m, 0)
        we = c.v(.we, "no"); rep = c.v(.rep, "mese")
        onceY = c.v(.onceY, Date().y); onceM = c.v(.onceM, Date().mo)
        endMode = c.v(.endMode, "mai"); endCount = c.v(.endCount, 12)
        endDate = try? c.decodeIfPresent(String.self, forKey: .endDate)
        start = c.v(.start, isoString(Date()))
        label = c.v(.label, ""); all = c.v(.all, true); subs = c.v(.subs, [String]()); on = c.v(.on, true)
    }
}

struct Payment: Codable, Hashable {
    var on: String
    var amount: Double
}

struct Settings: Codable, Hashable {
    var theme: String = "predefinito"
    var accent: String = "#0F8A7A"
    var back: String = "tinta"
    var mode: String = "chiaro"
    var twint: String = ""
    var sign: String = ""
    var fu: Int = 5
    var lock: Bool = false
    var lockDelay: Int = 0
    var lockMode: String? = "nessuno"
    var pinHash: String = ""
    var pinSalt: String = ""
    var webauthnId: String = ""
    var lastBackup: String? = nil

    init() {}
    enum CodingKeys: String, CodingKey { case theme, accent, back, mode, twint, sign, fu, lock, lockDelay, lockMode, pinHash, pinSalt, webauthnId, lastBackup }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        theme = c.v(.theme, "predefinito"); accent = c.v(.accent, "#0F8A7A"); back = c.v(.back, "tinta")
        mode = c.v(.mode, "chiaro"); twint = c.v(.twint, ""); sign = c.v(.sign, ""); fu = c.v(.fu, 5)
        lock = c.v(.lock, false); lockDelay = c.v(.lockDelay, 0)
        lockMode = try? c.decodeIfPresent(String.self, forKey: .lockMode)
        pinHash = c.v(.pinHash, ""); pinSalt = c.v(.pinSalt, ""); webauthnId = c.v(.webauthnId, "")
        lastBackup = try? c.decodeIfPresent(String.self, forKey: .lastBackup)
        migrate()
    }

    /// Temi e impostazioni delle versioni precedenti.
    mutating func migrate() {
        let old: [String: (String, String)] = ["classico": ("#007AFF", "neutro"), "alpino": ("#0F8A7A", "tinta"), "lago": ("#1D5FD1", "tinta"),
                                               "tramonto": ("#D2522A", "tinta"), "bosco": ("#2F6B3A", "tinta"), "notte": ("#8E5BD8", "neutro")]
        if let o = old[theme] { if theme == "notte" { mode = "scuro" }; theme = "predefinito"; accent = o.0; back = o.1 }
        if THEMES[theme] == nil { theme = "predefinito" }
        if mode != "chiaro" && mode != "scuro" { mode = "chiaro" }
        if lockMode == nil { lockMode = lock ? "bio" : "nessuno" }
    }
}

struct AppData: Codable {
    var v: Int = 1
    var subs: [Sub] = []
    var payments: [String: [String: Payment]] = [:]
    var reminders: [Reminder] = []
    var contacts: [String: String] = [:]
    var settings = Settings()
    var exportedAt: String? = nil

    init() {}
    enum CodingKeys: String, CodingKey { case v, subs, payments, reminders, contacts, settings, exportedAt }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        v = c.v(.v, 1)
        subs = try c.decode([Sub].self, forKey: .subs)
        payments = c.v(.payments, [String: [String: Payment]]())
        reminders = c.v(.reminders, [Reminder]())
        contacts = c.v(.contacts, [String: String]())
        settings = c.v(.settings, Settings())
        exportedAt = try? c.decodeIfPresent(String.self, forKey: .exportedAt)
    }
}

extension KeyedDecodingContainer {
    /// Valore se presente e leggibile, altrimenti quello predefinito.
    func v<T: Decodable>(_ key: Key, _ def: T) -> T { ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? def }
}

func uid() -> String {
    String(Int(Date().timeIntervalSince1970 * 1000), radix: 36) + String(UInt32.random(in: 0...UInt32.max), radix: 36).prefix(6)
}
