import SwiftUI
import Charts

/// Statistiche: la tua spesa, per tipo, incassi degli ultimi 6 mesi, puntualità, più cari.
struct StatsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.pal) private var pal

    var body: some View {
        VStack(spacing: 0) {
            TopBar("Statistiche")
            ScrollView {
                VStack(spacing: 6) {
                    if store.data.subs.isEmpty {
                        EmptyState(title: "Ancora niente da mostrare", text: "Aggiungi un abbonamento: qui vedrai quanto spendi e chi paga puntuale.", actions: [("Prova con dati di esempio", true, { store.loadSample() })])
                    } else { content }
                }.screen().padding(.bottom, 24).padding(.top, 6)
            }
        }
    }

    struct Bar: Identifiable { let id = UUID(); let month: String; let kind: String; let value: Double }

    @ViewBuilder private var content: some View {
        let data = store.data, k = keyOf(now())
        let mine = data.subs.reduce(0.0) { $0 + monthly($1, myShareOf(terms($1, k))) }
        let all = data.subs.reduce(0.0) { $0 + monthly($1, terms($1, k).total) }
        let byCat: [(String, Double)] = {
            var m: [String: Double] = [:]
            for s in data.subs { m[s.cat, default: 0] += monthly(s, myShareOf(terms(s, k))) }
            return m.filter { $0.value > 0.004 }.sorted { $0.value > $1.value }
        }()

        Card {
            VStack(alignment: .leading, spacing: 0) {
                kpi("La tua parte", chf(mine), "al mese", big: true).padding(16)
                Rectangle().fill(pal.sep).frame(height: 0.5).padding(.horizontal, 16)
                HStack(alignment: .top) { kpi("All'anno", chf(mine * 12), "la tua parte"); kpi("Risparmi", chf((all - mine) * 12), "all'anno dividendo") }.padding(16)
            }
        }
        SecFoot("In tutto gli abbonamenti costano ≈ \(chf(all)) al mese.")

        SecHead(text: "La tua spesa per tipo")
        Card {
            HStack(spacing: 14) {
                ZStack {
                    Chart(byCat, id: \.0) { c in
                        SectorMark(angle: .value("CHF", c.1), innerRadius: .ratio(0.62), angularInset: 1).foregroundStyle(Color(hex: CATS[c.0]?.color ?? "#8A8A8E"))
                    }.frame(width: 116, height: 116)
                    VStack(spacing: 0) {
                        Text(String(format: "%.2f", mine)).font(.system(size: 14, weight: .bold)).foregroundStyle(pal.fg)
                        Text("CHF al mese").font(.system(size: 9)).foregroundStyle(pal.ink2)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    if byCat.isEmpty { Text("La tua parte è zero: paghi tutto con gli altri.").font(.system(size: 13)).foregroundStyle(pal.ink2) }
                    ForEach(byCat, id: \.0) { c in
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: CATS[c.0]?.color ?? "#8A8A8E")).frame(width: 8, height: 8)
                            Text(CATS[c.0]?.name ?? c.0).font(.system(size: 13)).foregroundStyle(pal.fg)
                            Spacer()
                            Text(chf(c.1)).font(.system(size: 13)).monospacedDigit().foregroundStyle(pal.ink2)
                        }
                    }
                }
            }.padding(16)
        }

        let months = (0..<6).reversed().map { i in D(now().y, now().mo - i, 1) }
        let bars: [Bar] = months.flatMap { dd -> [Bar] in
            let its = data.peopleFor(dd.y, dd.mo).flatMap(\.items)
            let paid = its.filter { $0.paid != nil }.reduce(0) { $0 + $1.share }, tot = its.reduce(0) { $0 + $1.share }
            let lab = String(MONTHS[dd.mo].prefix(3))
            return [Bar(month: lab, kind: "Incassato", value: paid), Bar(month: lab, kind: "Mancante", value: tot - paid)]
        }
        SecHead(text: "Incassi degli ultimi 6 mesi (CHF)")
        Card {
            Chart(bars) { b in
                BarMark(x: .value("Mese", b.month), y: .value("CHF", b.value), width: .ratio(0.6))
                    .foregroundStyle(by: .value("Tipo", b.kind))
                    .cornerRadius(3)
            }
            .chartForegroundStyleScale(["Incassato": pal.accent, "Mancante": pal.warn.opacity(0.55)])
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 190).padding(16)
        }

        punctuality(months)

        SecHead(text: "Più cari (al mese)")
        let ranked = data.subs.map { ($0, monthly($0, terms($0, k).total)) }.sorted { $0.1 > $1.1 }.prefix(5)
        let mx = ranked.first?.1 ?? 1
        Card {
            ForEach(Array(ranked.enumerated()), id: \.offset) { i, r in
                Row(last: i == ranked.count - 1) {
                    Tile(cat: r.0.cat)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack { Text(r.0.name).foregroundStyle(pal.fg); Spacer(); Text(chf(r.1)).monospacedDigit().foregroundStyle(pal.fg) }
                        GeometryReader { g in Capsule().fill(Color(hex: CATS[r.0.cat]?.color ?? "#8A8A8E")).frame(width: max(8, g.size.width * r.1 / mx)) }.frame(height: 6)
                    }
                }
            }
        }
    }

    @ViewBuilder private func punctuality(_ months: [Date]) -> some View {
        let rows: [(name: String, n: Int, unpaid: Int, avg: Double)] = {
            var st: [String: (name: String, delays: [Int], unpaid: Int)] = [:]
            for dd in months { for p in store.data.peopleFor(dd.y, dd.mo) { for i in p.items {
                var e: (name: String, delays: [Int], unpaid: Int) = st[p.key] ?? (name: p.name, delays: [Int](), unpaid: 0)
                if let pd = i.paid { e.delays.append(max(0, daysBetween(i.due, dateOf(pd.on)))) } else if i.due < now() { e.unpaid += 1 }
                st[p.key] = e
            } } }
            let list: [(name: String, n: Int, unpaid: Int, avg: Double)] = st.values.map { e in (name: e.name, n: e.delays.count, unpaid: e.unpaid, avg: e.delays.isEmpty ? 0 : Double(e.delays.reduce(0, +)) / Double(e.delays.count)) }
            return list
                .sorted { $0.unpaid != $1.unpaid ? $0.unpaid < $1.unpaid : $0.avg < $1.avg }
        }()
        if !rows.isEmpty {
            SecHead(text: "Puntualità")
            Card {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, x in
                    Row(last: i == rows.count - 1) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(x.name).fontWeight(.bold).foregroundStyle(pal.fg)
                            Text("\(x.n) pagamenti" + (x.unpaid > 0 ? " · \(x.unpaid) scaduti non pagati" : "")).font(.system(size: 13)).foregroundStyle(x.unpaid > 0 ? pal.late : pal.ink2)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        let dd = Int(x.avg.rounded())
                        Badge(text: x.n == 0 ? "—" : x.avg < 1 ? "Puntuale" : "in media \(dd) \(dd == 1 ? "giorno" : "giorni") dopo", kind: x.n == 0 ? "mid" : x.avg < 1 ? "ok" : x.avg > 7 ? "bad" : "mid")
                    }
                }
            }
            SecFoot("Il ritardo si conta dalla scadenza: il giorno del primo promemoria del mese.")
        }
    }

    private func kpi(_ label: String, _ value: String, _ sub: String, big: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 12)).foregroundStyle(pal.ink2)
            Text(value).font(.system(size: big ? 26 : 18, weight: .bold)).monospacedDigit().foregroundStyle(pal.fg).lineLimit(1).minimumScaleFactor(0.6)
            Text(sub).font(.system(size: 12)).foregroundStyle(pal.ink2)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
