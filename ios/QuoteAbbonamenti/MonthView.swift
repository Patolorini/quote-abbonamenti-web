import SwiftUI

/// "Questo mese": chi deve quanto, spunte dei pagamenti, arretrati, WhatsApp/SMS/Copia.
struct MonthView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.pal) private var pal
    @State private var expanded: Set<String> = []
    @State private var newSub = false

    var body: some View {
        let y = store.viewY, m = store.viewM
        VStack(spacing: 0) {
            TopBar("\(cap(MONTHS[m])) \(y)") {
                HStack(spacing: 14) {
                    Button { move(-1) } label: { Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold)) }.accessibilityLabel("Mese precedente")
                    Button("Oggi") { store.viewY = now().y; store.viewM = now().mo }
                    Button { move(1) } label: { Image(systemName: "chevron.right").font(.system(size: 20, weight: .semibold)) }.accessibilityLabel("Mese successivo")
                }
            }
            ScrollView {
                VStack(spacing: 6) {
                    if store.data.subs.isEmpty {
                        EmptyState(title: "Benvenuto!", text: "Aggiungi gli abbonamenti che dividi con altre persone: l'app ti ricorda chi deve pagare e quanto.",
                                   actions: [("Aggiungi il primo abbonamento", false, { newSub = true }), ("Prova con dati di esempio", true, { store.loadSample() })])
                    } else {
                        content(y, m)
                    }
                }.screen().padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $newSub) { SubEditor(sub: nil).environment(store).environment(\.pal, pal) }
    }

    private func move(_ k: Int) { let d = D(store.viewY, store.viewM + k, 1); store.viewY = d.y; store.viewM = d.mo }

    @ViewBuilder private func content(_ y: Int, _ m: Int) -> some View {
        let data = store.data
        let arr = data.arrearsBefore(y, m)
        let people: [Person] = {
            var ps = data.peopleFor(y, m)
            for (pk, a) in arr where !ps.contains(where: { $0.key == pk }) { ps.append(Person(key: pk, name: a.name)) }
            return ps.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        }()
        let all = people.flatMap(\.items)
        let total = all.reduce(0) { $0 + $1.share }, paid = all.filter { $0.paid != nil }.reduce(0) { $0 + $1.share }
        let pastTotal = arr.values.reduce(0) { $0 + $1.items.reduce(0) { $0 + $1.share } }
        let lateCount = people.filter { p in p.items.contains { $0.late > 0 } || arr[p.key] != nil }.count

        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    stat("Da incassare", chf(total), pal.fg)
                    stat("Incassato", chf(paid), pal.ok)
                    stat("Mancante", chf(total - paid), pal.warn)
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(pal.accentSoft)
                        Capsule().fill(pal.ok).frame(width: total > 0 ? g.size.width * paid / total : 0)
                    }
                }.frame(height: 7)
                if lateCount > 0 {
                    Text((lateCount == 1 ? "1 persona è in ritardo" : "\(lateCount) persone sono in ritardo") + (pastTotal > 0 ? " · \(chf(pastTotal)) dai mesi passati" : ""))
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(pal.late)
                }
            }.padding(16)
        }
        if people.isEmpty { SecFoot("Questo mese nessuno deve pagare niente.") }
        ForEach(people) { p in personBlock(p, past: arr[p.key]?.items ?? [], y, m) }
    }

    private func stat(_ label: String, _ value: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 12)).foregroundStyle(pal.ink2)
            Text(value).font(.system(size: 17, weight: .bold)).monospacedDigit().foregroundStyle(c).lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func personBlock(_ p: Person, past: [Item], _ y: Int, _ m: Int) -> some View {
        let owed = p.items.filter { $0.paid == nil }
        let owedSum = owed.reduce(0) { $0 + $1.share } + past.reduce(0) { $0 + $1.share }
        let late = max(0, (owed + past).map(\.late).max() ?? 0)
        let status = owedSum == 0 ? "Pagato" : !past.isEmpty ? "\(past.count) \(past.count == 1 ? "mese arretrato" : "mesi arretrati") · \(chf(owedSum))"
            : late > 0 ? "in ritardo di \(late) \(late == 1 ? "giorno" : "giorni") · \(chf(owedSum))" : "Deve \(chf(owedSum))"
        SecHead(text: p.name, trailing: status, trailingColor: owedSum == 0 ? pal.ok : late > 0 ? pal.late : pal.warn)
        Card {
            ForEach(p.items) { it in itemRow(it, pk: p.key, y: y, m: m) }
            if !past.isEmpty { pastBlock(p, past, y) }
            if !owed.isEmpty || !past.isEmpty {
                let text = store.data.messageFor(p, owed, y, m, past: past)
                let phone = store.data.contacts[p.key] ?? ""
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        ActButton(title: "WhatsApp") { open("https://wa.me/\(intlDigits(phone))?text=\(enc(text))") }
                        ActButton(title: "SMS") { open("sms:\(phone.isEmpty ? "" : "+" + intlDigits(phone))&body=\(enc(text))") }
                        ActButton(title: "Copia") { UIPasteboard.general.string = text; store.show("Messaggio copiato") }
                    }.padding(.horizontal, 16).padding(.vertical, 10)
                    Rectangle().fill(pal.sep).frame(height: 0.5).padding(.leading, 16)
                }
                Row(action: {
                    var d = store.data
                    for i in owed { d.setPaid(y, m, i.sub.id, p.key, i.share, true) }
                    for i in past { d.setPaid(i.y, i.m, i.sub.id, p.key, i.share, true) }
                    store.data = d
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    store.show("\(p.name) ha pagato tutto")
                }) { LinkText(past.isEmpty ? "Segna tutto pagato" : "Segna tutto pagato (\(chf(owedSum)))") }
            }
            PhoneRow(pk: p.key, name: p.name)
        }
    }

    private func itemRow(_ it: Item, pk: String, y: Int, m: Int) -> some View {
        Row {
            Button { store.togglePaid(it, pk); UIImpactFeedbackGenerator(style: .light).impactOccurred() } label: { CheckCircle(on: it.paid != nil) }
                .buttonStyle(.plain).accessibilityLabel("\(it.sub.name) pagato")
            Tile(cat: it.sub.cat)
            VStack(alignment: .leading, spacing: 2) {
                Text(it.sub.name).strikethrough(it.paid != nil).foregroundStyle(it.paid != nil ? pal.ink2 : pal.fg)
                if let pd = it.paid { Text("Pagato il \(fmtShort(dateOf(pd.on)))").font(.system(size: 13)).foregroundStyle(pal.ok) }
                else if it.late > 0 { Text("Scaduto il \(fmtShort(it.due)) · in ritardo di \(it.late) \(it.late == 1 ? "giorno" : "giorni")").font(.system(size: 13)).foregroundStyle(pal.late) }
                else { Text("Da pagare entro \(fmtShort(it.due))").font(.system(size: 13)).foregroundStyle(pal.ink2) }
                if it.sub.cycle > 1 { Text(it.sub.split == "rate" ? "Rata mensile (si paga \(PER[it.sub.cycle] ?? ""))" : "Rinnovo: quota intera").font(.system(size: 13)).foregroundStyle(pal.ink2) }
                if it.paid == nil, let h = it.sub.history.first(where: { $0.from == keyOf(D(y, m + 1, 1)) }) {
                    let ns = h.members.first { personKey($0.name) == pk }
                    let nv = ns.map { dueShare(it.sub, $0.share, (m + 1) % 12 + 1) } ?? 0
                    if abs(nv - it.share) > 0.004 { Text("Da \(MONTHS[(m + 1) % 12]): \(chf(nv)) (nuovo prezzo)").font(.system(size: 13, weight: .semibold)).foregroundStyle(pal.warn) }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Text(chf(it.share)).monospacedDigit().foregroundStyle(it.paid != nil ? pal.ink2 : pal.fg)
        }
    }

    @ViewBuilder private func pastBlock(_ p: Person, _ past: [Item], _ y: Int) -> some View {
        let open = expanded.contains(p.key)
        let sum = past.reduce(0) { $0 + $1.share }
        Button {
            withAnimation(.easeOut(duration: 0.2)) { if open { expanded.remove(p.key) } else { expanded.insert(p.key) } }
        } label: {
            HStack(spacing: 10) {
                Text(past.count == 1 ? "1 mese passato non pagato" : "\(past.count) mesi passati non pagati").font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity, alignment: .leading)
                Text(chf(sum)).font(.system(size: 15, weight: .bold)).monospacedDigit()
                Image(systemName: "chevron.right").rotationEffect(.degrees(open ? 90 : 0)).foregroundStyle(pal.ink2)
            }
            .foregroundStyle(pal.late).padding(.horizontal, 16).padding(.vertical, 12).contentShape(Rectangle())
        }.buttonStyle(.plain)
        Rectangle().fill(pal.sep).frame(height: 0.5).padding(.leading, 16)
        if open {
            ForEach(past) { it in
                Row {
                    Button {
                        var d = store.data; d.setPaid(it.y, it.m, it.sub.id, p.key, it.share, true); store.data = d
                        store.show("\(p.name): \(it.sub.name) di \(MONTHS[it.m]) pagato")
                    } label: { CheckCircle(on: false) }.buttonStyle(.plain)
                    Tile(cat: it.sub.cat)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(it.sub.name) · \(MONTHS[it.m])\(it.y != y ? " \(it.y)" : "")")
                        Text("Scaduto il \(fmtShort(it.due)) · in ritardo di \(it.late) \(it.late == 1 ? "giorno" : "giorni")").font(.system(size: 13)).foregroundStyle(pal.late)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Text(chf(it.share)).monospacedDigit()
                }
            }
        }
    }

    private func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "" }
    private func open(_ s: String) { if let u = URL(string: s) { UIApplication.shared.open(u) } }
}

/// Numero di telefono della persona (per WhatsApp e SMS).
struct PhoneRow: View {
    @Environment(AppStore.self) private var store
    @Environment(\.pal) private var pal
    let pk: String
    let name: String
    @State private var text = ""
    var body: some View {
        Row(last: true) {
            Text("Numero").foregroundStyle(pal.fg)
            TextField("Aggiungi il numero di \(name)", text: $text)
                .keyboardType(.phonePad).multilineTextAlignment(.trailing).foregroundStyle(pal.accent)
                .onAppear { text = store.data.contacts[pk] ?? "" }
                .onSubmit(saveNumber)
                .onChange(of: text) { _, _ in saveNumber() }
        }
    }
    private func saveNumber() {
        let v = text.trimmingCharacters(in: .whitespaces)
        if (store.data.contacts[pk] ?? "") == v { return }
        if v.isEmpty { store.data.contacts.removeValue(forKey: pk) } else { store.data.contacts[pk] = v }
    }
}
