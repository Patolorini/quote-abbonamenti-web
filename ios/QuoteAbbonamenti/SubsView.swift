import SwiftUI

/// Elenco degli abbonamenti.
struct SubsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.pal) private var pal
    @State private var editing: Sub? = nil
    @State private var newSub = false

    var body: some View {
        VStack(spacing: 0) {
            TopBar("Abbonamenti") {
                Button { newSub = true } label: { Image(systemName: "plus").font(.system(size: 24, weight: .medium)) }.accessibilityLabel("Nuovo abbonamento")
            }
            ScrollView {
                VStack(spacing: 6) {
                    if store.data.subs.isEmpty {
                        EmptyState(title: "Nessun abbonamento", text: "Aggiungi Spotify, Netflix o qualsiasi abbonamento che dividi.",
                                   actions: [("Aggiungi abbonamento", false, { newSub = true }), ("Prova con dati di esempio", true, { store.loadSample() })])
                    } else { list }
                }.screen().padding(.bottom, 24).padding(.top, 6)
            }
        }
        .sheet(item: $editing) { s in SubEditor(sub: s).environment(store).environment(\.pal, pal) }
        .sheet(isPresented: $newSub) { SubEditor(sub: nil).environment(store).environment(\.pal, pal) }
    }

    @ViewBuilder private var list: some View {
        let k = keyOf(now())
        let subs = store.data.subs.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        let tot = subs.reduce(0.0) { $0 + monthly($1, terms($1, k).total) }
        let mine = subs.reduce(0.0) { $0 + monthly($1, myShareOf(terms($1, k))) }
        Card {
            ForEach(subs.indices, id: \.self) { i in
                let s = subs[i], t = terms(s, k), my = myShareOf(t)
                Row(last: i == subs.count - 1, action: { editing = s }) {
                    Tile(cat: s.cat)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.name).fontWeight(.bold).foregroundStyle(pal.fg)
                        Text(t.members.isEmpty ? "Solo tu" : "Con \(t.members.map(\.name).joined(separator: ", ")) · tua quota \(chf(my))").font(.system(size: 13)).foregroundStyle(pal.ink2)
                        if let line = extraLine(s) { Text(line).font(.system(size: 13)).foregroundStyle(inTrial(s) ? pal.warn : pal.ink2) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(chf(t.total)).monospacedDigit().foregroundStyle(pal.fg)
                        if s.cycle > 1 { Text(PER[s.cycle] ?? "").font(.system(size: 12)).foregroundStyle(pal.ink2) }
                    }
                }
            }
        }
        SecFoot("In tutto ≈ \(chf(tot)) al mese; la tua parte ≈ \(chf(mine)).")
    }

    private func extraLine(_ s: Sub) -> String? {
        if inTrial(s), let e = parseISO(s.trialEnd) { return "Prova gratuita fino a \(fmtShort(e))" }
        if s.cycle > 1 && s.split == "unica" { return "Si chiede tutto al rinnovo · \(MONTHS[max(0, min(11, s.renewal - 1))])" }
        if let c = nextCharge(s) {
            var t = "Rinnovo \(fmtShort(c))"
            if s.renewalAlert { t += " · avviso \(fmtShort(alertDate(c, s.notice, s.alertDays)))" }
            return t
        }
        return nil
    }
}
