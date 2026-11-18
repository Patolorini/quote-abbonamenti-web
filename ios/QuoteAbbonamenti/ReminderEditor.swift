import SwiftUI

/// Scheda di un promemoria: giorno sul calendario, ripetizione, fine, fine settimana, ora, abbonamenti.
struct ReminderEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.pal) private var pal
    @Environment(\.dismiss) private var dismiss

    let original: Reminder?
    @State private var d: Reminder
    @State private var cy: Int
    @State private var cm: Int
    @State private var endDate: Date
    @State private var time: Date
    @State private var delConfirm = false

    init(rem: Reminder?) {
        original = rem
        let n = now()
        var r = rem ?? Reminder()
        if rem == nil { r.day = n.d > 28 ? 1 : n.d; r.start = isoString(n) }
        _d = State(initialValue: r)
        let x = rem.flatMap { nextOcc($0, 1).first ?? lastOcc($0) } ?? n
        _cy = State(initialValue: x.y); _cm = State(initialValue: x.mo)
        _endDate = State(initialValue: parseISO(r.endDate) ?? D(n.y + 1, n.mo, n.d))
        _time = State(initialValue: D(2000, 0, 1, r.h, r.m))
    }

    /// Il promemoria con le scelte attuali (data di fine solo se serve).
    private var spec: Reminder { var s = d; s.endDate = d.endMode == "data" ? isoString(endDate) : nil; s.h = time.hh; s.m = time.mi; return s }

    var body: some View {
        VStack(spacing: 0) {
            SheetBar(title: original == nil ? "Nuovo promemoria" : "Modifica promemoria", saveEnabled: d.all || !d.subs.isEmpty, onCancel: { dismiss() }, onSave: save)
            ScrollView {
                VStack(spacing: 6) {
                    daySection
                    repeatSection
                    weekendSection
                    timeSection
                    upcoming
                    titleSection
                    subsSection
                    preview
                    if original != nil { deleteRow }
                }.screen().padding(.bottom, 30).padding(.top, 6)
            }.scrollDismissesKeyboard(.interactively)
        }
        .background(pal.bg.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder private var daySection: some View {
        let s = spec, last = lastOcc(s), mStart = D(cy, cm, 1), mEnd = D(cy, cm + 1, 0, 23, 59)
        let active = s.rep == "una" ? (s.onceY == cy && s.onceM == cm) : (mEnd >= startOfDay(dateOf(s.start)) && (last == nil || mStart <= last!))
        let fires = Set(firesIn(s, cy, cm).map(\.d))
        let others = Set(store.data.reminders.filter { $0.id != d.id && $0.on }.flatMap { firesIn($0, cy, cm).map(\.d) })
        SecHead(text: "Giorno del mese")
        Card {
            CalendarGrid(y: $cy, m: $cm, mark: { day, nn in
                var c = Set<String>()
                let sel = active && (d.day == day || (d.day == 0 && day == nn))
                if sel { c.insert("on") }
                if fires.contains(day) && !sel { c.insert("fires") }
                if others.contains(day) { c.insert("dot") }
                return c
            }, onPick: { day in d.day = day; if d.rep == "una" { d.onceY = cy; d.onceM = cm } }, ghostTo: active && d.day > daysIn(cy, cm) ? d.day : 0)
            Button { d.day = 0; if d.rep == "una" { d.onceY = cy; d.onceM = cm } } label: {
                Text("Ultimo giorno del mese").font(.system(size: 14, weight: d.day == 0 ? .bold : .regular))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(d.day == 0 ? pal.accent : pal.accentSoft, in: Capsule())
                    .foregroundStyle(d.day == 0 ? pal.onAccent : pal.accent)
            }.buttonStyle(.plain)
            Text(dayNote(s, active: active, last: last)).font(.system(size: 13)).foregroundStyle(pal.ink2)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 12)
        }
    }

    private func dayNote(_ s: Reminder, active: Bool, last: Date?) -> String {
        let nn = daysIn(cy, cm), nom = nominal(s, cy, cm), eff = occurrence(s, cy, cm)
        var note: String
        if !active {
            note = s.rep == "una" ? "Il promemoria è fissato a \(MONTHS[s.onceM]) \(s.onceY). Tocca un giorno qui per spostarlo."
                : D(cy, cm + 1, 0, 23, 59) < startOfDay(dateOf(s.start)) ? "Il promemoria inizia a \(MONTHS[dateOf(s.start).mo])."
                : "Il promemoria è già finito: l'ultimo avviso è \(last.map(withYear) ?? "")."
        } else if d.day == 0 { note = "A \(MONTHS[cm]) l'ultimo giorno è il \(nn) (\(WD[nom.wd]))." }
        else if d.day > nn { note = "\(cap(MONTHS[cm])) ha solo \(nn) giorni: l'avviso del \(d.day) arriva \(WD[nom.wd]) \(nn)." }
        else { note = "A \(MONTHS[cm]) il \(d.day) è \(WDL[nom.wd])." }
        if active && !sameDay(nom, eff) { note += " Cade nel fine settimana: arriva \(fmtShort(eff))." }
        return note
    }

    @ViewBuilder private var repeatSection: some View {
        SecHead(text: "Ripetizione")
        Card {
            Row(last: true) {
                Seg(options: [("mese", "Ogni mese"), ("una", "Solo una volta")], value: Binding(get: { d.rep }, set: { v in
                    d.rep = v
                    if v == "una" {
                        var y = cy, m = cm
                        if occurrence(d, y, m) < now() { let nx = D(y, m + 1, 1); y = nx.y; m = nx.mo }
                        d.onceY = y; d.onceM = m; cy = y; cm = m
                    }
                }))
            }
        }
        SecFoot(d.rep == "una" ? "Arriva solo \(fmtDate(occurrence(spec, d.onceY, d.onceM))). Scegli mese e giorno nel calendario." : "Lo imposti una volta e si ripete ogni mese nello stesso giorno.")
        if d.rep == "mese" {
            SecHead(text: "Fine del promemoria")
            Card {
                Row(last: d.endMode == "mai") { Seg(options: [("mai", "Mai"), ("dopo", "Dopo N volte"), ("data", "In una data")], value: $d.endMode) }
                if d.endMode == "dopo" {
                    Row {
                        Text("Numero di avvisi: \(d.endCount)").frame(maxWidth: .infinity, alignment: .leading)
                        Stepper("", value: $d.endCount, in: 1...120).labelsHidden()
                    }
                    HStack(spacing: 8) {
                        ForEach([(3, "3 mesi"), (6, "6 mesi"), (12, "1 anno"), (24, "2 anni")], id: \.0) { c in chip(c.1, d.endCount == c.0) { d.endCount = c.0 } }
                    }.padding(.horizontal, 16).padding(.vertical, 10)
                }
                if d.endMode == "data" {
                    Row(last: true) {
                        Text("L'abbonamento scade il").frame(maxWidth: .infinity, alignment: .leading)
                        DatePicker("", selection: $endDate, displayedComponents: .date).labelsHidden()
                    }
                }
            }
            let l2 = lastOcc(spec), left = sequence(spec).filter { $0 > now() }.count
            SecFoot(d.endMode == "mai" ? "Continua finché non lo metti in pausa o lo elimini." : l2 == nil ? "Con questa data non arriva nessun avviso: scegline una più avanti."
                    : "Ultimo avviso: \(fmtDate(l2!)). " + (left > 0 ? "Ne restano \(left), poi si ferma da solo." : "Il promemoria è già finito."))
        }
    }

    @ViewBuilder private var weekendSection: some View {
        SecHead(text: "Se cade di sabato o domenica")
        Card { Row(last: true) { Seg(options: [("no", "Non spostare"), ("prima", "Venerdì prima"), ("dopo", "Lunedì dopo")], value: $d.we) } }
    }

    @ViewBuilder private var timeSection: some View {
        SecHead(text: "Ora")
        Card {
            Row {
                Text("Ora").frame(maxWidth: .infinity, alignment: .leading)
                DatePicker("", selection: $time, displayedComponents: .hourAndMinute).labelsHidden()
            }
            HStack(spacing: 8) {
                ForEach([("Mattina 08:00", 8, 0), ("Pranzo 12:30", 12, 30), ("Sera 18:30", 18, 30)], id: \.0) { c in
                    chip(c.0, time.hh == c.1 && time.mi == c.2) { time = D(2000, 0, 1, c.1, c.2) }
                }
            }.padding(.horizontal, 16).padding(.vertical, 10)
        }
    }

    @ViewBuilder private var upcoming: some View {
        let up = nextOcc(spec, 3), l3 = lastOcc(spec)
        SecHead(text: "Prossimi avvisi")
        Card {
            if up.isEmpty { Row(last: true) { Text("Nessun avviso in arrivo: la data è già passata.").foregroundStyle(pal.ink2) } }
            ForEach(Array(up.enumerated()), id: \.offset) { i, x in
                Row(last: i == up.count - 1) {
                    Text("\(cap(withYear(x))) · \(two(x.hh)):\(two(x.mi))").frame(maxWidth: .infinity, alignment: .leading)
                    let dd = daysBetween(now(), x)
                    Text(l3.map { sameDay(x, $0) } == true ? "ultimo" : dd == 0 ? "oggi" : dd == 1 ? "domani" : "tra \(dd) giorni").font(.system(size: 13)).foregroundStyle(pal.ink2)
                }
            }
        }
    }

    @ViewBuilder private var titleSection: some View {
        SecHead(text: "Titolo della notifica")
        Card { Row(last: true) { TextField("Facoltativo: se vuoto mostra il totale", text: $d.label) } }
    }

    @ViewBuilder private var subsSection: some View {
        SecHead(text: "Per quali abbonamenti")
        Card {
            Row(last: d.all) { Toggle("Tutti gli abbonamenti", isOn: $d.all).tint(pal.accent) }
            if !d.all {
                ForEach(Array(store.data.subs.enumerated()), id: \.element.id) { i, sb in
                    let on = d.subs.contains(sb.id)
                    Row(last: i == store.data.subs.count - 1, action: { if on { d.subs.removeAll { $0 == sb.id } } else { d.subs.append(sb.id) } }) {
                        CheckCircle(on: on)
                        Tile(cat: sb.cat)
                        Text(sb.name).foregroundStyle(pal.fg).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    @ViewBuilder private var preview: some View {
        let chosen = d.all ? store.data.subs : store.data.subs.filter { d.subs.contains($0.id) }
        SecHead(text: "Come arriverà la notifica")
        if chosen.isEmpty { SecFoot("Scegli almeno un abbonamento per vedere la notifica.") }
        else {
            let nx = nextWithMonth(spec, 1).first
            let t = nx.flatMap { store.data.notificationText(chosen, $0.y, $0.m) } ?? store.data.notificationText(chosen, now().y, now().mo)
            HStack(alignment: .top, spacing: 10) {
                CoinLogo(colors: pal.logo).frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Quote Abbonamenti").font(.system(size: 12)).foregroundStyle(pal.ink2)
                        Spacer()
                        if let nx { Text("\(fmtShort(nx.date)), \(two(time.hh)):\(two(time.mi))").font(.system(size: 12)).foregroundStyle(pal.ink2) }
                    }
                    Text(d.label.isEmpty ? (t?.title ?? "Nessuna quota") : d.label).font(.system(size: 15, weight: .bold)).foregroundStyle(pal.fg)
                    Text(t?.body ?? "In questo mese non c'è niente da chiedere.").font(.system(size: 14)).foregroundStyle(pal.fg)
                }
            }
            .padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            SecFoot("Tenendo premuta la notifica trovi “… ha pagato”, “Hanno pagato tutti” e “Ricordamelo domani”.")
        }
    }

    private var deleteRow: some View {
        Card {
            Row(last: true, action: {
                guard delConfirm else { delConfirm = true; return }
                store.data.reminders.removeAll { $0.id == d.id }
                store.show("Promemoria eliminato"); dismiss()
            }) { LinkText(delConfirm ? "Tocca di nuovo per eliminare" : "Elimina promemoria", danger: true) }
        }.padding(.top, 14)
    }

    private func chip(_ text: String, _ sel: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(.system(size: 13, weight: sel ? .bold : .regular)).lineLimit(1).minimumScaleFactor(0.8)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(sel ? pal.accent : pal.accentSoft, in: Capsule())
                .foregroundStyle(sel ? pal.onAccent : pal.accent)
        }.buttonStyle(.plain)
    }

    private func save() {
        guard d.all || !d.subs.isEmpty else { return }
        let out = spec
        if let i = store.data.reminders.firstIndex(where: { $0.id == out.id }) { store.data.reminders[i] = out } else { store.data.reminders.append(out) }
        store.show(original == nil ? "Promemoria aggiunto" : "Promemoria aggiornato")
        Notifications.requestPermission()
        dismiss()
    }
}
