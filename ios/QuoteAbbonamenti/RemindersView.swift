import SwiftUI
import UserNotifications

/// Calendario del mese con i giorni segnati.
struct CalendarGrid: View {
    @Environment(\.pal) private var pal
    @Binding var y: Int
    @Binding var m: Int
    var mark: (Int, Int) -> Set<String>   // giorno, giorni del mese → "on", "paused", "fires", "dot"
    var onPick: ((Int) -> Void)? = nil
    var ghostTo = 0

    var body: some View {
        let n = daysIn(y, m), offset = (D(y, m, 1).wd + 6) % 7
        VStack(spacing: 8) {
            HStack {
                Button { step(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Mese precedente")
                Spacer()
                Text(verbatim: "\(cap(MONTHS[m])) \(y)").font(.system(size: 16, weight: .bold)).foregroundStyle(pal.fg)
                Spacer()
                Button { step(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Mese successivo")
            }.foregroundStyle(pal.accent).font(.system(size: 17, weight: .semibold))
            let cols = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(Array("LMMGVSD").indices, id: \.self) { i in Text(String(Array("LMMGVSD")[i])).font(.system(size: 11, weight: .semibold)).foregroundStyle(pal.ink2) }
                ForEach(0..<offset, id: \.self) { _ in Color.clear.frame(height: 36) }
                ForEach(1...n, id: \.self) { d in dayCell(d, n) }
                if ghostTo > n { ForEach((n + 1)...ghostTo, id: \.self) { d in Text("\(d)").font(.system(size: 15)).foregroundStyle(pal.ink2.opacity(0.4)).strikethrough().frame(height: 36) } }
            }
        }.padding(12)
    }

    @ViewBuilder private func dayCell(_ d: Int, _ n: Int) -> some View {
        let mk = mark(d, n), date = D(y, m, d), we = date.wd == 0 || date.wd == 6, today = sameDay(date, now())
        let label = Text("\(d)").font(.system(size: 15, weight: mk.contains("on") || today ? .bold : .regular))
            .foregroundStyle(mk.contains("on") ? pal.onAccent : mk.contains("paused") || mk.contains("fires") ? pal.accent : we ? pal.ink2 : pal.fg)
            .frame(width: 34, height: 34)
            .background {
                if mk.contains("on") { Circle().fill(pal.accent) }
                else if mk.contains("paused") || mk.contains("fires") { Circle().fill(pal.accentSoft) }
                else if today { Circle().strokeBorder(pal.accent, lineWidth: 1.5) }
            }
            .overlay(alignment: .bottom) { if mk.contains("dot") { Circle().fill(pal.warn).frame(width: 5, height: 5).offset(y: 4) } }
            .frame(height: 36)
        if let onPick { Button { onPick(d) } label: { label }.buttonStyle(.plain).accessibilityLabel("\(d) \(MONTHS[m])") } else { label }
    }

    private func step(_ k: Int) { let dd = D(y, m + k, 1); y = dd.y; m = dd.mo }
}

/// Promemoria: calendario e elenco.
struct RemindersView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.pal) private var pal
    @State private var editing: Reminder? = nil
    @State private var newOne = false
    @State private var auth: UNAuthorizationStatus = .authorized

    var body: some View {
        @Bindable var st = store
        VStack(spacing: 0) {
            TopBar("Promemoria") {
                Button { newOne = true } label: { Image(systemName: "plus").font(.system(size: 24, weight: .medium)) }.accessibilityLabel("Nuovo promemoria")
            }
            ScrollView {
                VStack(spacing: 6) {
                    if auth == .denied || auth == .notDetermined {
                        Card { Row(last: true, action: askPermission) { LinkText(auth == .denied ? "Attiva le notifiche nelle Impostazioni di iPhone" : "Attiva le notifiche") } }
                        SecFoot("Serve il tuo permesso perché l'app possa avvisarti nei giorni scelti.")
                    }
                    if store.data.reminders.isEmpty {
                        EmptyState(title: "Nessun promemoria", text: "Scegli tu il giorno: uno solo per tutti gli abbonamenti, oppure uno diverso per ogni rinnovo.",
                                   actions: [("Promemoria il 1° del mese alle 09:00", false, {
                                       var r = Reminder(); r.day = 1; store.data.reminders.append(r); askPermission()
                                   })])
                    } else {
                        Card {
                            CalendarGrid(y: $st.remY, m: $st.remM, mark: { d, _ in
                                var on = false, paused = false
                                for r in store.data.reminders where firesIn(r, store.remY, store.remM).contains(where: { $0.d == d }) { if r.on { on = true } else { paused = true } }
                                return on ? ["on"] : paused ? ["paused"] : []
                            })
                            Text("\(cap(MONTHS[store.remM])) ha \(daysIn(store.remY, store.remM)) giorni. Pieno = promemoria attivo, chiaro = in pausa.")
                                .font(.system(size: 13)).foregroundStyle(pal.ink2).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.bottom, 12)
                        }
                        SecHead(text: "I tuoi promemoria")
                        list
                        SecFoot("Le notifiche arrivano anche ad app chiusa. Tienile premute per segnare chi ha pagato.")
                    }
                }.screen().padding(.bottom, 24).padding(.top, 6)
            }
        }
        .onAppear { Notifications.status { auth = $0 } }
        .sheet(item: $editing) { r in ReminderEditor(rem: r).environment(store).environment(\.pal, pal) }
        .sheet(isPresented: $newOne) { ReminderEditor(rem: nil).environment(store).environment(\.pal, pal) }
    }

    private func askPermission() {
        if auth == .denied { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }; return }
        Notifications.requestPermission { _ in Notifications.status { auth = $0 } }
    }

    @ViewBuilder private var list: some View {
        let rank = { (r: Reminder) in isEnded(r) ? 2 : r.on ? 0 : 1 }
        let sorted = store.data.reminders.sorted { a, b in
            rank(a) != rank(b) ? rank(a) < rank(b) : (nextOcc(a, 1).first ?? .distantFuture) < (nextOcc(b, 1).first ?? .distantFuture)
        }
        Card {
            ForEach(Array(sorted.enumerated()), id: \.element.id) { i, r in
                let ended = isEnded(r)
                Row(last: i == sorted.count - 1) {
                    Button { editing = r } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.label.isEmpty ? whenText(r) : r.label).fontWeight(.bold).foregroundStyle(pal.fg)
                            if !r.label.isEmpty { Text(whenText(r)).font(.system(size: 13)).foregroundStyle(pal.ink2) }
                            Text(details(r, ended)).font(.system(size: 13)).foregroundStyle(pal.ink2)
                        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).opacity(r.on && !ended ? 1 : 0.55)
                    if ended { Badge(text: "Terminato", kind: "mid") }
                    else {
                        Toggle("", isOn: Binding(get: { r.on }, set: { v in if let j = store.data.reminders.firstIndex(where: { $0.id == r.id }) { store.data.reminders[j].on = v } }))
                            .labelsHidden().tint(pal.accent)
                    }
                }
            }
        }
    }

    private func details(_ r: Reminder, _ ended: Bool) -> String {
        var parts: [String] = []
        let last = lastOcc(r), nx = nextOcc(r, 1).first
        if ended { parts.append("Terminato il \(last.map(withYear) ?? "")") }
        else if !r.on { parts.append("In pausa") }
        else {
            if let nx, r.rep == "mese" { parts.append("Prossimo: \(fmtShort(nx))") }
            if let last, r.rep == "mese" { parts.append("fino a \(withYear(last))") }
        }
        let names = store.data.subsOf(r).map(\.name).joined(separator: ", ")
        parts.append(r.all ? "Tutti gli abbonamenti" : names.isEmpty ? "Nessun abbonamento" : names)
        return parts.joined(separator: " · ")
    }
}
