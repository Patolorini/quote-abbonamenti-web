import Foundation

// Date sul calendario gregoriano, mesi da 0 a 11 come nella versione web.

let MONTHS = ["gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre"]
let WD = ["dom", "lun", "mar", "mer", "gio", "ven", "sab"]
let WDL = ["domenica", "lunedì", "martedì", "mercoledì", "giovedì", "venerdì", "sabato"]
let PER: [Int: String] = [1: "al mese", 3: "al trimestre", 6: "al semestre", 12: "all'anno"]
let COST: [Int: String] = [1: "Costo mensile", 3: "Costo trimestrale", 6: "Costo semestrale", 12: "Costo annuale"]

let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.locale = Locale(identifier: "it_CH")
    c.timeZone = .current
    c.firstWeekday = 2
    return c
}()

/// Come `new Date(y, m, d, h, mi)` in JavaScript: mesi e giorni fuori intervallo scorrono.
func D(_ y: Int, _ m: Int, _ d: Int = 1, _ h: Int = 0, _ mi: Int = 0) -> Date {
    let t = y * 12 + m
    let yy = Int((Double(t) / 12).rounded(.down)), mm = t - yy * 12
    let first = cal.date(from: DateComponents(year: yy, month: mm + 1, day: 1, hour: h, minute: mi)) ?? Date()
    return cal.date(byAdding: .day, value: d - 1, to: first) ?? first
}

extension Date {
    var y: Int { cal.component(.year, from: self) }
    var mo: Int { cal.component(.month, from: self) - 1 }
    var d: Int { cal.component(.day, from: self) }
    var wd: Int { cal.component(.weekday, from: self) - 1 } // 0 = domenica
    var hh: Int { cal.component(.hour, from: self) }
    var mi: Int { cal.component(.minute, from: self) }
}

func now() -> Date { Date() }
func daysIn(_ y: Int, _ m: Int) -> Int { D(y, m + 1, 0).d }
func startOfDay(_ d: Date) -> Date { cal.startOfDay(for: d) }
func endOfDay(_ d: Date) -> Date { D(d.y, d.mo, d.d, 23, 59).addingTimeInterval(59) }
func sameDay(_ a: Date, _ b: Date) -> Bool { cal.isDate(a, inSameDayAs: b) }
func mkey(_ y: Int, _ m: Int) -> String { String(format: "%04d-%02d", y, m + 1) }
func keyOf(_ d: Date) -> String { mkey(d.y, d.mo) }
func two(_ n: Int) -> String { String(format: "%02d", n) }
func cap(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }
func fmtShort(_ d: Date) -> String { "\(WD[d.wd]) \(d.d) \(MONTHS[d.mo].prefix(3))" }
func fmtDate(_ d: Date) -> String { "\(WDL[d.wd]) \(d.d) \(MONTHS[d.mo]) \(d.y)" }
func withYear(_ d: Date) -> String { "\(fmtShort(d)) \(d.y)" }
func daysBetween(_ a: Date, _ b: Date) -> Int { cal.dateComponents([.day], from: startOfDay(a), to: startOfDay(b)).day ?? 0 }

func round2(_ x: Double) -> Double { (x * 100).rounded() / 100 }
func rappen(_ x: Double) -> Double { (x * 20).rounded() / 20 }
func chf(_ n: Double) -> String { "CHF " + String(format: "%.2f", round2(n)) }
func personKey(_ n: String) -> String { n.trimmingCharacters(in: .whitespaces).lowercased() }
func parseAmount(_ s: String) -> Double {
    let t = s.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")
    guard let v = Double(t), v.isFinite, v >= 0 else { return 0 }
    return v
}
func amountText(_ v: Double) -> String { v > 0 ? String(format: "%.2f", v) : "" }

private let isoFrac: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }()
private let isoPlain: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f }()
func isoString(_ d: Date) -> String { isoFrac.string(from: d) }
func parseISO(_ s: String?) -> Date? {
    guard let s, !s.isEmpty else { return nil }
    return isoFrac.date(from: s) ?? isoPlain.date(from: s)
}
func dateOf(_ s: String?) -> Date { parseISO(s) ?? Date(timeIntervalSince1970: 0) }

/// Numero in formato internazionale per WhatsApp (svizzero se inizia con 0).
func intlDigits(_ phone: String) -> String {
    var d = phone.filter(\.isNumber)
    if phone.trimmingCharacters(in: .whitespaces).hasPrefix("+") { return d }
    if d.hasPrefix("00") { d.removeFirst(2); return d }
    if d.hasPrefix("0") { return "41" + d.dropFirst() }
    return d
}
