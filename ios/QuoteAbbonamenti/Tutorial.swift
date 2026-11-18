import SwiftUI

/// Tutorial: al primo accesso e da Impostazioni › Aiuto.
struct TutorialView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.pal) private var pal
    let again: Bool
    @State private var step = 0
    @State private var newSub = false

    struct Step { let symbol: String?; let tiles: [String]; let title: String; let text: AttributedString }
    private let steps: [Step] = [
        Step(symbol: nil, tiles: [], title: "Benvenuto in Quote Abbonamenti",
             text: try! AttributedString(markdown: "Dividi Spotify, Netflix e gli altri abbonamenti con amici e famiglia: l'app tiene il conto di **chi deve pagare, quanto e quando**.")),
        Step(symbol: "creditcard", tiles: ["musica", "video"], title: "Aggiungi gli abbonamenti",
             text: try! AttributedString(markdown: "In **Abbonamenti** tocca **+**: scrivi nome e costo, aggiungi le persone e tocca **Dividi in parti uguali**. Puoi scegliere anche da che giorno lo dividete.")),
        Step(symbol: "calendar.badge.checkmark", tiles: ["cloud", "software"], title: "Segna chi ha pagato",
             text: try! AttributedString(markdown: "In **Questo mese** vedi chi ti deve quanto. Tocca il **cerchio** accanto a una quota quando ti arrivano i soldi. I mesi non pagati restano negli **arretrati**.")),
        Step(symbol: "paperplane", tiles: ["internet", "notizie"], title: "Chiedi i soldi in un tocco",
             text: try! AttributedString(markdown: "Con **WhatsApp**, **SMS** o **Copia** mandi un messaggio già pronto con le quote. Metti il tuo **numero TWINT** in Impostazioni › Messaggi.")),
        Step(symbol: "bell", tiles: ["giochi", "fitness"], title: "Promemoria e scadenze",
             text: try! AttributedString(markdown: "In **Promemoria** scegli il giorno del mese: è la scadenza per pagare e ti arriva una notifica. Tenendola premuta segni subito **chi ha pagato**.")),
        Step(symbol: "slider.horizontal.3", tiles: ["musica", "cloud"], title: "Rendila tua",
             text: try! AttributedString(markdown: "In **Impostazioni** scegli un **tema**, proteggi l'app con **Face ID o un codice** ed esporta ogni tanto un **backup**. Questa guida la ritrovi lì, in Aiuto.")),
    ]

    var body: some View {
        let last = step == steps.count - 1
        let first = !again && store.data.subs.isEmpty
        VStack(spacing: 0) {
            HStack {
                Text("\(step + 1) di \(steps.count)").font(.system(size: 14)).foregroundStyle(pal.ink2)
                Spacer()
                if !last { Button("Salta") { close() }.foregroundStyle(pal.accent) }
            }.padding(.horizontal, 20).padding(.top, 10).frame(height: 44)
            TabView(selection: $step) {
                ForEach(steps.indices, id: \.self) { i in page(steps[i]).tag(i) }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            HStack(spacing: 8) {
                ForEach(steps.indices, id: \.self) { i in
                    Capsule().fill(i == step ? pal.accent : pal.sep).frame(width: i == step ? 22 : 8, height: 8)
                }
            }.animation(.easeOut(duration: 0.25), value: step).padding(.vertical, 18)
            VStack(spacing: 10) {
                Button {
                    if !last { withAnimation { step += 1 }; return }
                    close()
                    if first { store.tab = "abbonamenti"; newSub = true }
                } label: {
                    Text(last ? (first ? "Aggiungi il primo abbonamento" : "Fatto") : "Avanti").font(.system(size: 17, weight: .heavy))
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(pal.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous)).foregroundStyle(pal.onAccent)
                }.buttonStyle(.plain)
                Button {
                    if last && first { close(); store.loadSample() } else if step > 0 { withAnimation { step -= 1 } }
                } label: {
                    Text(last && first ? "Prova con dati di esempio" : "Indietro").font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(pal.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous)).foregroundStyle(pal.accent)
                }.buttonStyle(.plain).opacity(step == 0 ? 0 : 1).disabled(step == 0)
            }.padding(.horizontal, 20).padding(.bottom, 12)
        }
        .frame(maxWidth: 560).frame(maxWidth: .infinity)
        .background(pal.bg.ignoresSafeArea())
        .sheet(isPresented: $newSub) { SubEditor(sub: nil).environment(store).environment(\.pal, pal) }
    }

    private func page(_ s: Step) -> some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(pal.accentSoft).frame(width: 168, height: 168)
                if let sym = s.symbol {
                    Image(systemName: sym).font(.system(size: 64, weight: .light)).foregroundStyle(pal.accent)
                    if s.tiles.count == 2 {
                        Tile(cat: s.tiles[0], size: 38).rotationEffect(.degrees(10)).shadow(color: .black.opacity(0.25), radius: 6, y: 4).offset(x: 70, y: -62)
                        Tile(cat: s.tiles[1], size: 38).rotationEffect(.degrees(-9)).shadow(color: .black.opacity(0.25), radius: 6, y: 4).offset(x: -76, y: 58)
                    }
                } else {
                    CoinLogo(colors: pal.logo, animate: true).frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)).shadow(color: .black.opacity(0.3), radius: 10, y: 6)
                }
            }.padding(.bottom, 28)
            Text(s.title).font(.system(size: 25, weight: .heavy)).foregroundStyle(pal.fg).multilineTextAlignment(.center).padding(.bottom, 10)
            Text(s.text).font(.system(size: 16)).foregroundStyle(pal.ink2).multilineTextAlignment(.center).lineSpacing(3).frame(maxWidth: 380)
            Spacer()
        }.padding(.horizontal, 28)
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.3)) {
            store.data.settings.tutorialSeen = true
            store.tutorialAgain = false
        }
    }
}
