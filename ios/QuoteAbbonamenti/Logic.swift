import Foundation

// Calcoli: quote, rinnovi, promemoria sul calendario vero, chi deve pagare.
// È la stessa logica della versione web, riga per riga.

struct Terms { var total: Double; var members: [Member] }

func terms(_ sub: Sub, _ key: String) -> Terms {
    let h = sub.history.sorted { $0.from < $1.from }
    if h.isEmpty { return Terms(total: sub.total, members: sub.members) }
    let c = h.reversed().first { $0.from <= key } ?? h[0]
    return Terms(total: c.total, members: c.members)
}
func myShareOf(_ t: Terms) -> Double { max(0, t.total - t.members.reduce(0) { $0 + $1.share }) }
func cyclePos(_ sub: Sub, _ m1: Int) -> Int { let c = max(1, sub.cycle); return (((m1 - sub.renewal) % c) + c) % c }
func isRenewal(_ sub: Sub, _ m1: Int) -> Bool { sub.cycle <= 1 || cyclePos(sub, m1) == 0 }
/// Quota del mese: tutta (mensile), una rata (l'ultima corregge l'arrotondamento) o tutto al rinnovo.
func dueShare(_ sub: Sub, _ share: Double, _ m1: Int) -> Double {
    let c = max(1, sub.cycle)
    if c == 1 { return share }
    if sub.split == "rate" { let rate = rappen(share / Double(c)); return cyclePos(sub, m1) == c - 1 ? round2(share - rate * Double(c - 1)) : rate }
    return cyclePos(sub, m1) == 0 ? share : 0
}
func monthly(_ sub: Sub, _ v: Double) -> Double { v / Double(max(1, sub.cycle)) }
func nextCharge(_ sub: Sub, from: Date = now()) -> Date? {
    if sub.cycle <= 1 && sub.billingDay == 0 { return nil }
    for k in 0..<26 {
        let mo = D(from.y, from.mo + k, 1)
        if !isRenewal(sub, mo.mo + 1) { continue }
        let d = D(mo.y, mo.mo, min(max(sub.billingDay, 1), daysIn(mo.y, mo.mo)), 9)
        if d >= startOfDay(from) { return d }
    }
    return nil
}
func cancelDeadline(_ charge: Date, _ notice: Int) -> Date { D(charge.y, charge.mo, charge.d - max(1, notice), 9) }
func alertDate(_ charge: Date, _ notice: Int, _ before: Int) -> Date { let d = cancelDeadline(charge, notice); return D(d.y, d.mo, d.d - max(0, before), 9) }
func inTrial(_ sub: Sub) -> Bool { guard let t = parseISO(sub.trialEnd) else { return false }; return endOfDay(t) >= now() }

// MARK: promemoria

func nominal(_ r: Reminder, _ y: Int, _ m: Int) -> Date { let n = daysIn(y, m); return D(y, m, r.day == 0 ? n : min(r.day, n), r.h, r.m) }
func occurrence(_ r: Reminder, _ y: Int, _ m: Int) -> Date {
    let d = nominal(r, y, m), wd = d.wd
    if r.we == "prima" && (wd == 6 || wd == 0) { return D(d.y, d.mo, d.d - (wd == 6 ? 1 : 2), r.h, r.m) }
    if r.we == "dopo" && (wd == 6 || wd == 0) { return D(d.y, d.mo, d.d + (wd == 6 ? 2 : 1), r.h, r.m) }
    return d
}
func sequence(_ r: Reminder, until: Date? = nil) -> [Date] {
    if r.rep == "una" { return [occurrence(r, r.onceY, r.onceM)] }
    let st = dateOf(r.start)
    let end: Date? = (r.endMode == "data" && r.endDate != nil) ? endOfDay(dateOf(r.endDate)) : nil
    var out: [Date] = []
    for i in -1..<240 {
        let b = D(st.y, st.mo + i, 1)
        if let until, b > until { break }
        let d = occurrence(r, b.y, b.mo)
        if d < st { continue }
        if let end, d > end { break }
        out.append(d)
        if r.endMode == "dopo" && out.count >= r.endCount { break }
    }
    return out
}
/// Avviso che appartiene al mese (anche se il fine settimana lo sposta nel mese dopo).
func belonging(_ r: Reminder, _ y: Int, _ m: Int) -> Date? {
    if r.rep == "una" { return r.onceY == y && r.onceM == m ? occurrence(r, y, m) : nil }
    let d = occurrence(r, y, m)
    return sequence(r, until: D(y, m + 1, 1)).contains(d) ? d : nil
}
func lastOcc(_ r: Reminder) -> Date? { (r.rep == "una" || r.endMode != "mai") ? sequence(r).last : nil }
func isEnded(_ r: Reminder) -> Bool { let l = lastOcc(r); if r.endMode == "data" && l == nil { return true }; return l.map { $0 < now() } ?? false }
func nextOcc(_ r: Reminder, _ count: Int) -> [Date] { let n = now(); return Array(sequence(r, until: D(n.y, n.mo + count + 2, 1)).filter { $0 > n }.prefix(count)) }
func nextWithMonth(_ r: Reminder, _ count: Int) -> [(date: Date, y: Int, m: Int)] {
    var out: [(date: Date, y: Int, m: Int)] = []
    let n = now()
    var k = -1
    while k < count + 4 && out.count < count {
        let b = D(n.y, n.mo + k, 1)
        if let d = belonging(r, b.y, b.mo), d > n { out.append((d, b.y, b.mo)) }
        k += 1
    }
    return out
}
func firesIn(_ r: Reminder, _ y: Int, _ m: Int) -> [Date] { sequence(r, until: D(y, m + 2, 1)).filter { $0.y == y && $0.mo == m } }
/// Promemoria da mostrare nel calendario: anche nei mesi passati (prima che fosse creato), come "già passato".
func shownIn(_ r: Reminder, _ y: Int, _ m: Int) -> [Date] {
    let f = firesIn(r, y, m), n = now()
    if !f.isEmpty || r.rep != "mese" || D(y, m, 1) > n { return f }
    let d = occurrence(r, y, m), last = lastOcc(r)
    return d < n && (last == nil || d <= last!) ? [d] : []
}
func dayText(_ r: Reminder) -> String { r.day == 0 ? "L'ultimo giorno del mese" : r.day > 28 ? "Il \(r.day) (o l'ultimo giorno)" : "Il \(r.day) del mese" }
func whenText(_ r: Reminder) -> String {
    r.rep == "una" ? "Una volta: \(withYear(occurrence(r, r.onceY, r.onceM))) alle \(two(r.h)):\(two(r.m))" : "\(dayText(r)) alle \(two(r.h)):\(two(r.m))"
}

// MARK: chi deve pagare

struct Item: Identifiable {
    var sub: Sub
    var share: Double
    var paid: Payment?
    var due: Date
    var late: Int
    var y: Int = 0
    var m: Int = 0
    var id: String { "\(sub.id)|\(y)-\(m)" }
}
struct Person: Identifiable {
    var key: String
    var name: String
    var items: [Item] = []
    var id: String { key }
}

extension AppData {
    func subsOf(_ r: Reminder) -> [Sub] { r.all ? subs : subs.filter { r.subs.contains($0.id) } }

    func dueDate(_ sub: Sub, _ y: Int, _ m: Int) -> Date {
        let ds = reminders.filter { $0.on && ($0.all || $0.subs.contains(sub.id)) }.compactMap { belonging($0, y, m) }
        return ds.min() ?? D(y, m, 1, 9)
    }

    func peopleFor(_ y: Int, _ m: Int) -> [Person] {
        let key = mkey(y, m), n = now()
        var map: [String: Person] = [:], order: [String] = []
        for s in subs {
            if startOfDay(dateOf(s.createdAt)) > D(y, m + 1, 0) { continue } // abbonamento aggiunto dopo
            for mem in terms(s, key).members {
                let share = dueShare(s, mem.share, m + 1), pk = personKey(mem.name)
                if share == 0 || pk.isEmpty { continue }
                if map[pk] == nil { map[pk] = Person(key: pk, name: mem.name.trimmingCharacters(in: .whitespaces)); order.append(pk) }
                let paid = payments[key]?["\(s.id)|\(pk)"]
                var due = dueDate(s, y, m)
                let created = dateOf(s.createdAt)
                if created > due { due = D(created.y, created.mo, created.d, 9) }
                map[pk]!.items.append(Item(sub: s, share: paid?.amount ?? share, paid: paid, due: due, late: paid != nil ? 0 : max(0, daysBetween(due, n)), y: y, m: m))
            }
        }
        return order.compactMap { map[$0] }.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    mutating func setPaid(_ y: Int, _ m: Int, _ subId: String, _ pk: String, _ amount: Double, _ on: Bool, at: Date = Date()) {
        let key = mkey(y, m)
        if on { payments[key, default: [:]]["\(subId)|\(pk)"] = Payment(on: isoString(at), amount: amount) }
        else { payments[key]?.removeValue(forKey: "\(subId)|\(pk)") }
    }

    /// Quote non pagate dei mesi prima di (y, m), per persona (al massimo 5 anni indietro).
    func arrearsBefore(_ y: Int, _ m: Int) -> [String: (name: String, items: [Item])] {
        var out: [String: (name: String, items: [Item])] = [:]
        guard let first = subs.map({ startOfDay(dateOf($0.createdAt)) }).min() else { return out }
        var d = D(max(first.y, y - 5), first.y < y - 5 ? 0 : first.mo, 1)
        let stop = D(y, m, 1)
        while d < stop {
            for p in peopleFor(d.y, d.mo) { for it in p.items where it.paid == nil {
                out[p.key, default: (p.name, [])].items.append(it)
            } }
            d = D(d.y, d.mo + 1, 1)
        }
        return out
    }

    func messageFor(_ p: Person, _ owed: [Item], _ y: Int, _ m: Int, past: [Item] = []) -> String {
        var lines = ["Ciao \(p.name)! Quote abbonamenti di \(MONTHS[m]) \(y):"] + owed.map { "• \($0.sub.name): \(chf($0.share))" }
        if owed.isEmpty { lines[0] = "Ciao \(p.name)! Quote abbonamenti ancora da pagare:" }
        if !past.isEmpty {
            if !owed.isEmpty { lines.append("Mesi passati ancora da pagare:") }
            for i in past { lines.append("• \(i.sub.name) (\(MONTHS[i.m])\(i.y != y ? " \(i.y)" : "")): \(chf(i.share))") }
        }
        lines.append("Totale: \(chf((owed + past).reduce(0) { $0 + $1.share })).")
        if owed.contains(where: { $0.late > 0 }), let first = owed.map(\.due).min() { lines.append("Era da pagare entro \(fmtShort(first)).") }
        let t = settings.twint.trimmingCharacters(in: .whitespaces)
        lines.append(t.isEmpty ? "Puoi mandarmeli con TWINT? Grazie!" : "Puoi mandarmeli con TWINT al \(t)? Grazie!")
        let sg = settings.sign.trimmingCharacters(in: .whitespaces)
        if !sg.isEmpty { lines.append(sg) }
        return lines.joined(separator: "\n")
    }

    func notificationText(_ subList: [Sub], _ y: Int, _ m: Int) -> (title: String, body: String)? {
        let ids = Set(subList.map(\.id))
        var owed: [(key: String, name: String, total: Double, subs: [String])] = []
        for p in peopleFor(y, m) {
            let its = p.items.filter { ids.contains($0.sub.id) }
            if its.isEmpty { continue }
            owed.append((p.key, p.name, its.reduce(0) { $0 + $1.share }, its.map(\.sub.name)))
        }
        if owed.isEmpty {
            let ren = subList.filter { isRenewal($0, m + 1) }
            if ren.isEmpty { return nil }
            return (title: "Rinnovo abbonamenti", body: ren.map(\.name).joined(separator: ", "))
        }
        let total = owed.reduce(0) { $0 + $1.total }
        return (title: "Da incassare: \(chf(total))", body: owed.map { "\($0.name): \(chf($0.total)) (\($0.subs.joined(separator: ", ")))" }.joined(separator: "\n") + "\nTocca per segnare chi ha pagato.")
    }

    func paymentsCSV() -> String {
        let names = Dictionary(subs.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        let cell = { (x: String) in "\"" + x.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        var lines = ["Mese;Persona;Abbonamento;Importo CHF;Pagato il"]
        for mk in payments.keys.sorted() { for (k, p) in payments[mk]!.sorted(by: { $0.key < $1.key }) {
            let parts = k.split(separator: "|", maxSplits: 1).map(String.init)
            let d = dateOf(p.on)
            lines.append([cell(mk), cell(cap(parts.count > 1 ? parts[1] : "")), cell(names[parts[0]] ?? "(eliminato)"), String(format: "%.2f", p.amount), "\(two(d.d)).\(two(d.mo + 1)).\(d.y)"].joined(separator: ";"))
        } }
        return "\u{FEFF}" + lines.joined(separator: "\r\n")
    }
}

func guessCat(_ name: String) -> String {
    let n = name.lowercased()
    for k in CAT_ORDER { if (CATS[k]?.keys ?? []).contains(where: { n.contains($0) }) { return k } }
    return "altro"
}

// MARK: codice d'accesso (stessa impronta della versione web, così i backup restano validi)

func hashPin(_ pin: String, _ salt: String) -> String {
    var h1: UInt32 = 0xdeadbeef, h2: UInt32 = 0x41c6ce57
    var str = salt + ":" + pin
    for _ in 0..<2000 {
        for c in str.utf16 { let cc = UInt32(c); h1 = (h1 ^ cc) &* 2654435761; h2 = (h2 ^ cc) &* 1597334677 }
        let a = (h1 ^ (h1 >> 16)) &* 2246822507, b = (h2 ^ (h2 >> 13)) &* 3266489909
        h1 = a ^ b
        let c2 = (h2 ^ (h2 >> 16)) &* 2246822507, d2 = (h1 ^ (h1 >> 13)) &* 3266489909
        h2 = c2 ^ d2
        str = String(h1, radix: 16) + String(h2, radix: 16)
    }
    return str
}
