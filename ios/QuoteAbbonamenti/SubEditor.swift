import SwiftUI

/// Scheda di un abbonamento: nuovo o da modificare.
struct SubEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.pal) private var pal
    @Environment(\.dismiss) private var dismiss

    let original: Sub?
    @State private var d: Sub
    @State private var catTouched: Bool
    @State private var eff = 0
    @State private var startDate: Date
    @State private var pastPaid = true
    @State private var remOn: Bool
    @State private var remDay: Int
    @State private var remTime: Date
    @State private var trialEnd: Date
    @State private var delConfirm = false
    private let cur: Terms?
    private let origDate: Date
    private let ownRem: Reminder?

    init(sub: Sub?) {
        original = sub
        let st = AppStore.shared
        let c = sub.map { terms($0, "9999-12") }
        cur = c
        var draft = sub ?? Sub()
        if let c { draft.total = c.total; draft.members = c.members }
        if sub == nil { draft.members = [Member(name: "", share: 0)] }
        _d = State(initialValue: draft)
        _catTouched = State(initialValue: sub != nil)
        let od = sub.map { startOfDay(dateOf($0.createdAt)) } ?? startOfDay(now())
        origDate = od
        let viewFirst = D(st.viewY, st.viewM, 1)
        _startDate = State(initialValue: sub == nil && monthsAgo(viewFirst) > 0 ? viewFirst : od)
        let own = sub.flatMap { s in st.data.reminders.first { !$0.all && $0.subs == [s.id] } }
        ownRem = own
        _remOn = State(initialValue: own != nil)
        _remDay = State(initialValue: own?.day ?? (od.d > 28 ? 1 : od.d))
        _remTime = State(initialValue: D(2000, 0, 1, own?.h ?? 9, own?.m ?? 0))
        _trialEnd = State(initialValue: parseISO(sub?.trialEnd) ?? D(now().y, now().mo, now().d + 30))
        if let s = sub, st.data.payments[keyOf(now())]?.keys.contains(where: { $0.hasPrefix(s.id + "|") }) == true { _eff = State(initialValue: 1) }
    }

    private var isNew: Bool { original == nil }
    private func cleanMembers() -> [Member] { d.members.map { Member(name: $0.name.trimmingCharacters(in: .whitespaces), share: round2($0.share)) }.filter { !$0.name.isEmpty && $0.share > 0 } }
    private var dup: String? { var seen = Set<String>(); for x in cleanMembers() { let k = personKey(x.name); if seen.contains(k) { return x.name }; seen.insert(k) }; return nil }
    private var termsChanged: Bool {
        guard let cur else { return false }
        let a = cur.members.map { "\(personKey($0.name)):\(round2($0.share))" }, b = cleanMembers().map { "\(personKey($0.name)):\($0.share)" }
        return round2(cur.total) != round2(d.total) || a != b
    }
    private var canSave: Bool { !d.name.trimmingCharacters(in: .whitespaces).isEmpty && d.total > 0 && dup == nil }

    var body: some View {
        VStack(spacing: 0) {
            SheetBar(title: isNew ? "Nuovo abbonamento" : "Modifica", saveEnabled: canSave, onCancel: { dismiss() }, onSave: save)
            ScrollView {
                VStack(spacing: 6) {
                    nameCost
                    if d.cycle > 1 { renewal }
                    startSection
                    categories
                    people
                    if termsChanged { effective }
                    reminderSection
                    renewalAlerts
                    if !isNew { deleteRow }
                }.screen().padding(.bottom, 30).padding(.top, 6)
            }.scrollDismissesKeyboard(.interactively)
        }
        .background(pal.bg.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }

    // MARK: sezioni

    private var nameCost: some View {
        Card {
            Row {
                Tile(cat: d.cat)
                TextField("Nome (es. Spotify Family)", text: $d.name)
                    .onChange(of: d.name) { _, n in if !catTouched { d.cat = guessCat(n) } }
            }
            Row { Seg(options: [(1, "Mese"), (3, "3 mesi"), (6, "6 mesi"), (12, "Anno")], value: $d.cycle) }
            Row(last: true) {
                Text(COST[d.cycle] ?? "Costo").frame(maxWidth: .infinity, alignment: .leading)
                AmountField(placeholder: "0.00", value: $d.total).frame(maxWidth: 110)
                Text("CHF").font(.system(size: 13)).foregroundStyle(pal.ink2)
            }
        }
    }

    @ViewBuilder private var renewal: some View {
        SecHead(text: "Rinnovo")
        Card {
            Row {
                Text("Mese del rinnovo").frame(maxWidth: .infinity, alignment: .leading)
                Picker("", selection: $d.renewal) { ForEach(1...12, id: \.self) { Text(cap(MONTHS[$0 - 1])).tag($0) } }.labelsHidden()
            }
            Row(last: true) { Seg(options: [("rate", "Una rata al mese"), ("unica", "Tutto al rinnovo")], value: $d.split) }
        }
        SecFoot(d.split == "rate" ? "La quota viene divisa in rate mensili, arrotondate ai 5 centesimi; l'ultima rata del periodo corregge la differenza."
                : "Nel mese del rinnovo (\(MONTHS[d.renewal - 1])) ognuno paga la quota intera; negli altri mesi niente.")
    }

    @ViewBuilder private var startSection: some View {
        let ago = max(0, monthsAgo(startDate))
        let newPast = max(0, ago - (isNew ? 0 : max(0, monthsAgo(origDate))))
        SecHead(text: "Da quando lo dividete")
        Card {
            Row(last: newPast == 0) {
                Text("Dal giorno").frame(maxWidth: .infinity, alignment: .leading)
                DatePicker("", selection: $startDate, displayedComponents: .date).labelsHidden().environment(\.locale, Locale(identifier: "it_CH"))
            }
            if newPast > 0 {
                Row(last: true) {
                    Toggle(newPast == 1 ? "Il mese scorso è già stato pagato" : "I \(newPast) mesi passati sono già stati pagati", isOn: $pastPaid).tint(pal.accent)
                }
            }
        }
        SecFoot("Dal \(fmtDate(startDate))" + (startDate.d > 1 ? ": nel primo mese la scadenza è quel giorno." : ".") + " L'addebito è il \(startDate.d) di ogni \(d.cycle == 1 ? "mese" : "rinnovo").")
        if newPast > 0 { SecFoot(pastPaid ? "I mesi passati vengono segnati come pagati: li trovi con ‹ in Questo mese e puoi togliere la spunta a chi non ha pagato." : "I mesi passati restano da pagare: in Questo mese li trovi tra gli arretrati.") }
    }

    @ViewBuilder private var categories: some View {
        SecHead(text: "Tipo")
        Card {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 10) {
                ForEach(CAT_ORDER, id: \.self) { c in
                    Button { d.cat = c; catTouched = true } label: {
                        VStack(spacing: 6) {
                            Tile(cat: c, size: 42)
                            Text(CATS[c]!.name).font(.system(size: 12, weight: d.cat == c ? .bold : .regular)).multilineTextAlignment(.center).lineLimit(2).foregroundStyle(pal.fg)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(d.cat == c ? pal.accent : .clear, lineWidth: 2))
                    }.buttonStyle(.plain)
                }
            }.padding(12)
        }
    }

    @ViewBuilder private var people: some View {
        let others = d.members.reduce(0) { $0 + $1.share }, mine = d.total - others
        SecHead(text: d.cycle == 1 ? "Con chi lo dividi" : "Con chi lo dividi (quota \(PER[d.cycle] ?? ""))")
        Card {
            ForEach(d.members.indices, id: \.self) { i in
                Row {
                    TextField("Nome", text: $d.members[i].name)
                        .padding(.horizontal, 10).padding(.vertical, 8).background(pal.bg, in: RoundedRectangle(cornerRadius: 8))
                    AmountField(placeholder: "0.00", value: $d.members[i].share)
                        .padding(.horizontal, 10).padding(.vertical, 8).background(pal.bg, in: RoundedRectangle(cornerRadius: 8)).frame(maxWidth: 96)
                    Button { d.members.remove(at: i) } label: { Image(systemName: "xmark").foregroundStyle(pal.accent) }.buttonStyle(.plain).accessibilityLabel("Rimuovi persona")
                }
            }
            Row(action: { d.members.append(Member(name: "", share: 0)) }) { LinkText("+ Aggiungi persona") }
            Row(last: true, action: divideEqually) { LinkText("Dividi in parti uguali (te incluso)") }
        }
        if let dp = dup { SecFoot("\(dp) compare due volte: usa nomi diversi.", color: pal.late) }
        else if mine < -0.001 { SecFoot("Le quote superano il costo di \(chf(-mine)).", color: pal.late) }
        else { SecFoot("La tua quota: \(chf(mine)) \(PER[d.cycle] ?? "").") }
    }

    private func divideEqually() {
        let named = d.members.indices.filter { !d.members[$0].name.trimmingCharacters(in: .whitespaces).isEmpty }
        guard d.total > 0, !named.isEmpty else { store.show("Inserisci prima il costo e almeno un nome"); return }
        let each = rappen(d.total / Double(named.count + 1))
        for i in named { d.members[i].share = each }
    }

    @ViewBuilder private var effective: some View {
        let from = D(now().y, now().mo + eff, 1)
        let before = original.map { terms($0, keyOf(D(from.y, from.mo - 1, 1))) }
        SecHead(text: "Da quando vale il cambio")
        Card {
            Row(last: true) {
                Text("Vale da").frame(maxWidth: .infinity, alignment: .leading)
                Picker("", selection: $eff) {
                    ForEach(-6...12, id: \.self) { o in
                        let dd = D(now().y, now().mo + o, 1)
                        Text(o == 0 ? "Questo mese" : o == 1 ? "Il prossimo mese" : "\(cap(MONTHS[dd.mo])) \(dd.y)").tag(o)
                    }
                }.labelsHidden()
            }
        }
        if let before { SecFoot("Fino a \(MONTHS[(from.mo + 11) % 12]) resta \(chf(before.total)); da \(MONTHS[from.mo]) \(from.y) diventa \(chf(d.total)). I pagamenti già segnati non cambiano.") }
    }

    @ViewBuilder private var reminderSection: some View {
        let sid = original?.id ?? ""
        let shared = store.data.reminders.filter { r in r.on && (r.all || (!sid.isEmpty && r.subs.contains(sid))) && r.id != ownRem?.id }
        SecHead(text: "Promemoria")
        Card {
            ForEach(shared) { r in
                Row {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.label.isEmpty ? whenText(r) : r.label)
                        Text(r.all ? "Promemoria per tutti gli abbonamenti" : "Promemoria condiviso con altri abbonamenti").font(.system(size: 13)).foregroundStyle(pal.ink2)
                    }
                }
            }
            Row(last: !remOn) { Toggle(shared.isEmpty ? "Promemoria ogni mese" : "Aggiungi un promemoria solo per questo", isOn: $remOn).tint(pal.accent) }
            if remOn {
                Row {
                    Text("Giorno del mese").frame(maxWidth: .infinity, alignment: .leading)
                    Picker("", selection: $remDay) { ForEach(1...31, id: \.self) { Text($0 > 28 ? "Il \($0) (o l'ultimo giorno)" : "Il \($0)").tag($0) } }.labelsHidden()
                }
                Row(last: true) {
                    Text("Ora").frame(maxWidth: .infinity, alignment: .leading)
                    DatePicker("", selection: $remTime, displayedComponents: .hourAndMinute).labelsHidden()
                }
            }
        }
        SecFoot(remOn ? "Ogni mese il \(remDay)\(remDay > 28 ? " (nei mesi più corti l'ultimo giorno)" : ""): è la scadenza per pagare. " + (shared.isEmpty ? "" : "Con più promemoria vale il primo del mese. ") + "Lo trovi e lo modifichi anche in Promemoria."
                : shared.isEmpty ? "Senza promemoria la scadenza è il 1° del mese." : "La scadenza per pagare è il giorno del promemoria.")
    }

    @ViewBuilder private var renewalAlerts: some View {
        let trial = d.trialEnd != nil
        SecHead(text: "Rinnovo e disdetta")
        Card {
            Row { Toggle("È una prova gratuita", isOn: Binding(get: { d.trialEnd != nil }, set: { d.trialEnd = $0 ? isoString(trialEnd) : nil })).tint(pal.accent) }
            if trial {
                Row {
                    Text("La prova finisce il").frame(maxWidth: .infinity, alignment: .leading)
                    DatePicker("", selection: Binding(get: { trialEnd }, set: { trialEnd = $0; d.trialEnd = isoString(startOfDay($0)) }), displayedComponents: .date).labelsHidden()
                }
            }
            Row(last: !(d.renewalAlert || trial) && trial) {
                Toggle(trial ? "Avvisami prima della fine" : "Avvisami prima del rinnovo", isOn: Binding(get: { d.renewalAlert || trial }, set: { d.renewalAlert = $0 })).tint(pal.accent).disabled(trial)
            }
            if d.renewalAlert || trial {
                Row(last: trial) {
                    Text("\(d.alertDays) \(d.alertDays == 1 ? "giorno" : "giorni") prima").frame(maxWidth: .infinity, alignment: .leading)
                    Stepper("", value: $d.alertDays, in: 1...30).labelsHidden()
                }
            }
            if !trial {
                Row(last: true) {
                    Text("Preavviso di disdetta").frame(maxWidth: .infinity, alignment: .leading)
                    Picker("", selection: $d.notice) { ForEach([(0, "Nessuno"), (7, "7 giorni"), (14, "14 giorni"), (30, "1 mese"), (60, "2 mesi"), (90, "3 mesi")], id: \.0) { Text($0.1).tag($0.0) } }.labelsHidden()
                }
            }
        }
        SecFoot(summary)
    }

    private var summary: String {
        if let te = parseISO(d.trialEnd) {
            let al = D(te.y, te.mo, te.d - d.alertDays)
            return "La prova finisce \(fmtDate(te)). Ti avviso \(fmtDate(al)), così puoi disdire se non ti interessa."
        }
        var s = d; s.billingDay = startDate.d
        guard let c = nextCharge(s) else { return "" }
        return "Addebito il \(s.billingDay) (il giorno d'inizio). Prossimo rinnovo: \(fmtDate(c)). Per disdire: entro \(fmtDate(cancelDeadline(c, d.notice)))." + (d.renewalAlert ? " Ti avviso \(fmtDate(alertDate(c, d.notice, d.alertDays)))." : "")
    }

    private var deleteRow: some View {
        Card {
            Row(last: true, action: {
                guard delConfirm, let o = original else { delConfirm = true; return }
                var data = store.data
                data.subs.removeAll { $0.id == o.id }
                for mk in data.payments.keys { data.payments[mk] = data.payments[mk]?.filter { !$0.key.hasPrefix(o.id + "|") } }
                for i in data.reminders.indices { data.reminders[i].subs.removeAll { $0 == o.id } }
                data.reminders.removeAll { !$0.all && $0.subs.isEmpty && $0.id == ownRem?.id }
                store.data = data
                store.show("Abbonamento eliminato")
                dismiss()
            }) { LinkText(delConfirm ? "Tocca di nuovo per eliminare" : "Elimina abbonamento", danger: true) }
        }.padding(.top, 14)
    }

    // MARK: salvataggio

    private func save() {
        guard canSave else { return }
        var data = store.data
        let members = cleanMembers()
        var out = d
        out.name = d.name.trimmingCharacters(in: .whitespaces)
        out.total = round2(d.total)
        out.members = members
        out.billingDay = startDate.d
        let ago = max(0, monthsAgo(startDate))
        if startOfDay(startDate) != origDate { out.createdAt = isoString(startOfDay(startDate)) }
        if let o = original, let cur {
            if termsChanged {
                var hist = o.history
                if hist.isEmpty { hist.append(PriceChange(from: "0000-01", total: cur.total, members: cur.members)) }
                let from = keyOf(D(now().y, now().mo + eff, 1))
                hist = hist.filter { $0.from < from || $0.from == "0000-01" }
                hist.append(PriceChange(from: from, total: out.total, members: members))
                out.history = hist
            } else { out.history = o.history }
            if let i = data.subs.firstIndex(where: { $0.id == o.id }) { data.subs[i] = out }
        } else {
            data.subs.append(out)
        }
        // promemoria solo per questo abbonamento
        if remOn {
            if let own = ownRem, let i = data.reminders.firstIndex(where: { $0.id == own.id }) {
                data.reminders[i].day = remDay; data.reminders[i].h = remTime.hh; data.reminders[i].m = remTime.mi; data.reminders[i].on = true
                if own.label.isEmpty || own.label == original?.name { data.reminders[i].label = out.name }
            } else {
                var r = Reminder(); r.day = remDay; r.h = remTime.hh; r.m = remTime.mi
                r.start = isoString(startDate < startOfDay(now()) ? startDate : Date()); r.label = out.name; r.all = false; r.subs = [out.id]
                data.reminders.append(r)
                Notifications.requestPermission()
            }
        } else if let own = ownRem { data.reminders.removeAll { $0.id == own.id } }
        // mesi passati già pagati
        let markTo = isNew ? 0 : max(0, monthsAgo(origDate))
        if pastPaid && ago > markTo {
            for a in stride(from: ago, to: markTo, by: -1) {
                let dd = D(now().y, now().mo - a, 1)
                for p in data.peopleFor(dd.y, dd.mo) { for it in p.items where it.sub.id == out.id && it.paid == nil {
                    data.setPaid(dd.y, dd.mo, out.id, p.key, it.share, true, at: it.due)
                } }
            }
        }
        store.data = data
        store.show(isNew ? (ago > 0 ? "Abbonamento aggiunto dal \(fmtDate(startDate))" : "Abbonamento aggiunto") : "Salvato")
        dismiss()
    }
}

func monthsAgo(_ dt: Date) -> Int { (now().y - dt.y) * 12 + now().mo - dt.mo }
