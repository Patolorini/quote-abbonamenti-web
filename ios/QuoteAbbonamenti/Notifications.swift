import Foundation
import UserNotifications

/// Una notifica da programmare (come nella versione Android).
struct PlannedNote {
    var at: Date
    var title: String
    var body: String
    var actions: [(title: String, items: [PayItem])]
}
struct PayItem: Codable { var s: String; var m: String; var p: String; var a: Double }

extension AppData {
    func notifActions(_ subList: [Sub], _ y: Int, _ m: Int) -> [(title: String, items: [PayItem])] {
        let ids = Set(subList.map(\.id)), key = mkey(y, m)
        var owed: [(name: String, sum: Double, items: [PayItem])] = []
        for p in peopleFor(y, m) {
            let its = p.items.filter { ids.contains($0.sub.id) && $0.paid == nil }
            if its.isEmpty { continue }
            owed.append((p.name, its.reduce(0) { $0 + $1.share }, its.map { PayItem(s: $0.sub.id, m: key, p: p.key, a: $0.share) }))
        }
        let ranked = owed.sorted { $0.sum > $1.sum }
        var actions = ranked.prefix(2).map { (title: "\($0.name) ha pagato", items: $0.items) }
        if ranked.count > 1 { actions.append((title: "Hanno pagato tutti", items: ranked.flatMap(\.items))) }
        return actions
    }

    func buildSchedule() -> [PlannedNote] {
        var list: [PlannedNote] = []
        let n = now(), fu = settings.fu
        // promemoria
        for r in reminders where r.on {
            let sl = subsOf(r); if sl.isEmpty { continue }
            for o in nextWithMonth(r, 3) {
                guard let t = notificationText(sl, o.y, o.m) else { continue }
                var body = t.body
                if r.rep == "mese", let last = lastOcc(r), sameDay(last, o.date) { body += "\nÈ l'ultimo promemoria: l'abbonamento sta per scadere." }
                list.append(PlannedNote(at: o.date, title: r.label.isEmpty ? t.title : r.label, body: body, actions: notifActions(sl, o.y, o.m)))
            }
        }
        // solleciti: un mese alla volta, solo chi non ha ancora pagato
        if fu > 0 {
            var months: [String: (at: Date, y: Int, m: Int, subs: [String: Sub])] = [:]
            for r in reminders where r.on { for k in -1...2 {
                let b = D(n.y, n.mo + k, 1)
                guard let d = belonging(r, b.y, b.mo) else { continue }
                let f = D(d.y, d.mo, d.d + fu, d.hh, d.mi)
                if f <= n { continue }
                let mk = mkey(b.y, b.mo)
                var e: (at: Date, y: Int, m: Int, subs: [String: Sub]) = months[mk] ?? (at: f, y: b.y, m: b.mo, subs: [String: Sub]())
                if f < e.at { e.at = f }
                for s in subsOf(r) { e.subs[s.id] = s }
                months[mk] = e
            } }
            for e in months.values {
                let unpaid = peopleFor(e.y, e.m).map { p in (p: p, items: p.items.filter { $0.paid == nil && e.subs[$0.sub.id] != nil }) }.filter { !$0.items.isEmpty }
                if unpaid.isEmpty { continue }
                let tot = unpaid.reduce(0) { $0 + $1.items.reduce(0) { $0 + $1.share } }
                list.append(PlannedNote(at: e.at, title: "Ancora da incassare: \(chf(tot))",
                                        body: unpaid.map { "\($0.p.name): \(chf($0.items.reduce(0) { $0 + $1.share })) (\($0.items.map(\.sub.name).joined(separator: ", ")))" }.joined(separator: "\n") + "\nTocca per mandare un sollecito.",
                                        actions: notifActions(Array(e.subs.values), e.y, e.m)))
            }
        }
        // rinnovi e prove gratuite
        for s in subs {
            let price = "\(chf(terms(s, keyOf(n)).total)) \(PER[s.cycle] ?? "")"
            if inTrial(s), let end = parseISO(s.trialEnd) {
                let at = D(end.y, end.mo, end.d - max(1, s.alertDays), 9)
                if at > n { list.append(PlannedNote(at: at, title: "La prova di \(s.name) finisce \(fmtShort(end))", body: "Dopo costerà \(price). Se non ti interessa, disdici prima di quella data.", actions: [])) }
                continue
            }
            if !s.renewalAlert { continue }
            var from = n
            for _ in 0..<2 {
                guard let c = nextCharge(s, from: from) else { break }
                from = D(c.y, c.mo, c.d + 1)
                let at = alertDate(c, s.notice, s.alertDays), dl = cancelDeadline(c, s.notice)
                if at > n {
                    list.append(PlannedNote(at: at, title: "\(s.name) si rinnova \(fmtShort(c))",
                                            body: s.notice > 0 ? "Costo \(price). Per disdire hai tempo fino a \(fmtDate(dl)) (preavviso di \(s.notice) giorni)." : "Costo \(price). Se vuoi disdire, fallo entro \(fmtDate(dl)).", actions: []))
                }
            }
        }
        return Array(list.filter { $0.at > n }.sorted { $0.at < $1.at }.prefix(60))
    }
}

/// Programma le notifiche e gestisce i pulsanti "… ha pagato".
final class Notifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifications()
    static let prefix = "qa-"

    static func requestPermission(_ done: @escaping (Bool) -> Void = { _ in }) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
            DispatchQueue.main.async { done(ok); if ok { reschedule(AppStore.shared.data) } }
        }
    }
    static func status(_ done: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { s in DispatchQueue.main.async { done(s.authorizationStatus) } }
    }

    static func reschedule(_ data: AppData) {
        let plan = data.buildSchedule()
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
            var cats = Set<UNNotificationCategory>()
            let enc = JSONEncoder()
            for (i, n) in plan.enumerated() {
                let content = UNMutableNotificationContent()
                content.title = n.title
                content.body = n.body
                content.sound = .default
                if !n.actions.isEmpty {
                    let catId = "qa-cat-\(i)"
                    var acts = n.actions.enumerated().map { j, a in
                        UNNotificationAction(identifier: "pay\(j)", title: a.title, options: [.authenticationRequired])
                    }
                    acts.append(UNNotificationAction(identifier: "snooze", title: "Ricordamelo domani", options: []))
                    cats.insert(UNNotificationCategory(identifier: catId, actions: acts, intentIdentifiers: [], options: []))
                    content.categoryIdentifier = catId
                    let payload = n.actions.map { $0.items }
                    if let j = try? enc.encode(payload) { content.userInfo = ["pay": String(decoding: j, as: UTF8.self)] }
                }
                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: n.at)
                let req = UNNotificationRequest(identifier: "\(prefix)\(i)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
                center.add(req)
            }
            center.setNotificationCategories(cats)
        }
    }

    // mostra le notifiche anche con l'app aperta
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.actionIdentifier
        let content = response.notification.request.content
        if id == "snooze" {
            let c = content.mutableCopy() as! UNMutableNotificationContent
            let req = UNNotificationRequest(identifier: "snooze-\(UUID().uuidString)", content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 24 * 3600, repeats: false))
            center.add(req)
            completionHandler(); return
        }
        if id.hasPrefix("pay"), let idx = Int(id.dropFirst(3)), let s = content.userInfo["pay"] as? String,
           let all = try? JSONDecoder().decode([[PayItem]].self, from: Data(s.utf8)), idx < all.count {
            DispatchQueue.main.async {
                let store = AppStore.shared
                var d = store.data
                var count = 0
                for it in all[idx] {
                    if d.payments[it.m]?["\(it.s)|\(it.p)"] == nil { d.payments[it.m, default: [:]]["\(it.s)|\(it.p)"] = Payment(on: isoString(Date()), amount: it.a); count += 1 }
                }
                store.data = d
                store.saveNow()
                if count > 0 { store.show(count == 1 ? "Pagamento segnato dalla notifica" : "\(count) pagamenti segnati dalla notifica") }
                completionHandler()
            }
            return
        }
        DispatchQueue.main.async { AppStore.shared.tab = "mese"; completionHandler() }
    }
}
