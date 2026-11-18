import XCTest
@testable import QuoteAbbonamenti

/// I valori attesi sono calcolati dalla versione web: le due versioni devono dare gli stessi risultati.
final class LogicTests: XCTestCase {
    private func R(_ edit: (inout Reminder) -> Void = { _ in }) -> Reminder {
        var r = Reminder(); r.id = "r"; r.day = 31; r.h = 9; r.m = 0; r.start = isoString(D(2026, 0, 1)); edit(&r); return r
    }
    private func f(_ d: Date?) -> String { guard let d else { return "nil" }; return "\(d.y)-\(d.mo + 1)-\(d.d) \(d.hh):\(d.mi)" }

    func testOccurrenceCalendarAndWeekend() {
        XCTAssertEqual(f(occurrence(R(), 2026, 1)), "2026-2-28 9:0")                       // febbraio: ultimo giorno
        XCTAssertEqual(f(occurrence(R { $0.day = 0 }, 2028, 1)), "2028-2-29 9:0")          // bisestile
        XCTAssertEqual(f(occurrence(R { $0.day = 14; $0.we = "prima" }, 2026, 1)), "2026-2-13 9:0")
        XCTAssertEqual(f(occurrence(R { $0.day = 15; $0.we = "dopo" }, 2026, 1)), "2026-2-16 9:0")
        XCTAssertEqual(f(occurrence(R { $0.we = "dopo" }, 2026, 4)), "2026-6-1 9:0")       // sabato 30/31 maggio → lunedì 1 giugno
        XCTAssertEqual(f(occurrence(R { $0.day = 30; $0.we = "prima" }, 2026, 10)), "2026-11-30 9:0")
    }

    func testSequenceEnds() {
        XCTAssertEqual(sequence(R { $0.day = 5; $0.endMode = "dopo"; $0.endCount = 4 }).map(f), ["2026-1-5 9:0", "2026-2-5 9:0", "2026-3-5 9:0", "2026-4-5 9:0"])
        XCTAssertEqual(sequence(R { $0.day = 20; $0.endMode = "data"; $0.endDate = isoString(D(2026, 4, 19)) }).map(f), ["2026-1-20 9:0", "2026-2-20 9:0", "2026-3-20 9:0", "2026-4-20 9:0"])
    }

    func testBelongingAcrossMonths() {
        XCTAssertEqual(f(belonging(R { $0.we = "dopo" }, 2026, 4)), "2026-6-1 9:0")
        XCTAssertEqual(f(belonging(R { $0.we = "dopo" }, 2026, 5)), "2026-6-30 9:0")
    }

    func testShares() {
        var s = Sub(id: "s"); s.cycle = 12; s.renewal = 3; s.split = "rate"; s.total = 99
        XCTAssertEqual([1, 2, 3, 4, 12].map { dueShare(s, 16.5, $0) }, [1.4, 1.1, 1.4, 1.4, 1.4])
        s.split = "unica"
        XCTAssertEqual([2, 3, 4].map { dueShare(s, 16.5, $0) }, [0, 16.5, 0])
        s.split = "rate"; s.renewal = 1
        XCTAssertEqual([1, 3, 6].map { c -> Double in var x = s; x.cycle = c; return dueShare(x, 10, 3) }, [10, 3.3, 1.65])
        XCTAssertEqual([rappen(1.374), rappen(5.725), rappen(16.5 / 12)], [1.35, 5.75, 1.4])
    }

    func testPinHashSameAsWeb() {
        XCTAssertEqual(hashPin("2580", "abc"), "922fb25f2cf8c60f")
        XCTAssertEqual(hashPin("1397", "S0m3+Salt/=="), "f7d7b7f9bdaa7e55")
    }

    func testPhoneNumbers() {
        XCTAssertEqual(["079 123 45 67", "+41 79 123 45 67", "0041791234567", "41791234567"].map(intlDigits), Array(repeating: "41791234567", count: 4))
    }

    func testPeopleAndArrears() {
        var d = AppData()
        var s = Sub(id: "n", name: "Netflix"); s.total = 20; s.members = [Member(name: "Luca", share: 10)]
        s.createdAt = isoString(D(now().y, now().mo - 2, 1))
        d.subs = [s]
        XCTAssertEqual(d.peopleFor(now().y, now().mo).first?.items.first?.share, 10)
        XCTAssertTrue(d.peopleFor(now().y, now().mo - 3).isEmpty, "prima dell'inizio non si paga")
        XCTAssertEqual(d.arrearsBefore(now().y, now().mo)["luca"]?.items.count, 2)
        d.setPaid(now().y, now().mo - 1, "n", "luca", 10, true)
        XCTAssertEqual(d.arrearsBefore(now().y, now().mo)["luca"]?.items.count, 1)
    }

    func testBackupRoundTripAndWebFormat() throws {
        let web = """
        {"v":1,"subs":[{"id":"a","name":"Spotify","cat":"musica","total":22.95,"cycle":1,"renewal":1,"split":"rate","members":[{"name":"Marco","share":5.75}],"history":[],"createdAt":"2026-06-01T00:00:00.000Z","billingDay":5,"renewalAlert":true,"alertDays":3,"notice":0,"trialEnd":null}],
         "payments":{"2026-07":{"a|marco":{"on":"2026-07-04T09:00:00.000Z","amount":5.75}}},"reminders":[{"id":"r1","day":3,"h":9,"m":0,"we":"no","rep":"mese","onceY":2026,"onceM":6,"endMode":"mai","endCount":12,"endDate":null,"start":"2026-06-01T00:00:00.000Z","label":"","all":true,"subs":[],"on":true}],
         "contacts":{"marco":"079 111 22 33"},"settings":{"theme":"lago","mode":"sistema","twint":"079","sign":"","fu":5,"lock":true,"lockDelay":0}}
        """
        let d = try JSONDecoder().decode(AppData.self, from: Data(web.utf8))
        XCTAssertEqual(d.subs.first?.name, "Spotify")
        XCTAssertEqual(d.payments["2026-07"]?["a|marco"]?.amount, 5.75)
        XCTAssertEqual(d.settings.theme, "predefinito")
        XCTAssertEqual(d.settings.accent, "#1D5FD1")
        XCTAssertEqual(d.settings.lockMode, "bio")
        let again = try JSONDecoder().decode(AppData.self, from: JSONEncoder().encode(d))
        XCTAssertEqual(again.subs, d.subs)
        XCTAssertEqual(again.reminders, d.reminders)
    }

    func testSQLiteSaveAndLoad() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID().uuidString).sqlite")
        var d = AppData()
        var s = Sub(id: "x", name: "iCloud"); s.total = 14.85; s.members = [Member(name: "Giulia", share: 4.95)]
        d.subs = [s]; d.contacts = ["giulia": "079"]; d.setPaid(2026, 0, "x", "giulia", 4.95, true)
        d.settings.twint = "079 123"
        Database(url: url).save(d)
        let back = Database(url: url).load()
        XCTAssertEqual(back.subs, d.subs)
        XCTAssertEqual(back.contacts, d.contacts)
        XCTAssertEqual(back.payments["2026-01"]?["x|giulia"]?.amount, 4.95)
        XCTAssertEqual(back.settings.twint, "079 123")
    }
}
