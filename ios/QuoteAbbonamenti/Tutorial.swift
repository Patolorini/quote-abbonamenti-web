import SwiftUI
import AVKit

/// Mini video tutorial: al primo accesso e da Impostazioni › Aiuto.
struct TutorialView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.pal) private var pal
    let again: Bool
    @State private var player: AVPlayer? = Bundle.main.url(forResource: "tutorial", withExtension: "mp4").map { AVPlayer(url: $0) }
    @State private var ended = false
    @State private var newSub = false

    var body: some View {
        let first = !again && store.data.subs.isEmpty
        VStack(spacing: 0) {
            HStack {
                Text("Come funziona · 50 secondi").font(.system(size: 14)).foregroundStyle(pal.ink2)
                Spacer()
                Button(first ? "Salta" : "Chiudi") { close() }.foregroundStyle(pal.accent)
            }.padding(.horizontal, 20).frame(height: 44)
            Group {
                if let player {
                    VideoPlayer(player: player)
                        .aspectRatio(720.0 / 1558.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.35), radius: 16, y: 10)
                } else {
                    Text("Video non disponibile").foregroundStyle(pal.ink2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.horizontal, 16).padding(.vertical, 10)
            VStack(spacing: 10) {
                Button {
                    close()
                    if first { store.tab = "abbonamenti"; newSub = true }
                } label: {
                    Text(first ? "Aggiungi il primo abbonamento" : "Fatto").font(.system(size: 17, weight: .heavy))
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(pal.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous)).foregroundStyle(pal.onAccent)
                        .scaleEffect(ended ? 1.03 : 1)
                }.buttonStyle(.plain)
                Button {
                    if first { close(); store.loadSample() } else { player?.seek(to: .zero); player?.play(); ended = false }
                } label: {
                    Text(first ? "Prova con dati di esempio" : "Guarda di nuovo").font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(pal.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous)).foregroundStyle(pal.accent)
                }.buttonStyle(.plain)
            }.padding(.horizontal, 20).padding(.bottom, 12)
        }
        .frame(maxWidth: 560).frame(maxWidth: .infinity)
        .background(pal.bg.ignoresSafeArea())
        .onAppear {
            player?.isMuted = true
            player?.play()
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { _ in
            withAnimation(.easeInOut(duration: 0.4).repeatCount(3, autoreverses: true)) { ended = true }
        }
        .onDisappear { player?.pause() }
        .sheet(isPresented: $newSub) { SubEditor(sub: nil).environment(store).environment(\.pal, pal) }
    }

    private func close() {
        player?.pause()
        withAnimation(.easeOut(duration: 0.3)) {
            store.data.settings.tutorialSeen = true
            store.tutorialAgain = false
        }
    }
}
