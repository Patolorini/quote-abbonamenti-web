import SwiftUI
import LocalAuthentication
import Observation

/// Schermata d'entrata e blocco: nessuno, Face ID o codice di 4 cifre.
@Observable
final class LockModel {
    var visible = true
    var unlocking = false
    var error: String? = nil
    var showPin = false
    var introOnly = false
    var key = 0 // per far ripartire l'animazione
    @ObservationIgnored private var awayAt: Date? = nil
    @ObservationIgnored private var fails = 0
    @ObservationIgnored private var waitUntil = Date.distantPast
    @ObservationIgnored private var introTask: Task<Void, Never>?

    static var bioName: String {
        let c = LAContext(); _ = c.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return c.biometryType == .touchID ? "Touch ID" : "Face ID"
    }
    static var bioAvailable: Bool { LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) }

    func mode(_ s: Settings) -> String {
        let m = s.lockMode ?? "nessuno"
        if m == "pin" && s.pinHash.isEmpty { return "nessuno" }
        return m
    }

    func start(_ store: AppStore) {
        key += 1
        error = nil
        visible = true
        let m = mode(store.data.settings)
        introOnly = m == "nessuno"
        showPin = m == "pin"
        if m == "bio" { Task { @MainActor in try? await Task.sleep(nanoseconds: 900_000_000); self.tryBio() } }
        if introOnly {
            introTask?.cancel()
            introTask = Task { @MainActor in try? await Task.sleep(nanoseconds: 2_600_000_000); if !Task.isCancelled { self.open() } }
        }
    }
    func wentAway() { awayAt = Date() }
    func cameBack(_ store: AppStore) {
        guard let a = awayAt, !visible else { return }
        awayAt = nil
        let m = mode(store.data.settings)
        if m != "nessuno" && Date().timeIntervalSince(a) >= Double(store.data.settings.lockDelay) { start(store) }
    }

    func open() {
        introTask?.cancel()
        guard visible, !unlocking else { return }
        unlocking = true
        withAnimation(.easeIn(duration: 0.45).delay(0.35)) { visible = false }
        Task { @MainActor in try? await Task.sleep(nanoseconds: 900_000_000); self.unlocking = false }
    }

    func tryBio() {
        guard visible else { return }
        let c = LAContext()
        c.localizedFallbackTitle = "Usa il codice del telefono"
        c.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Sblocca Quote Abbonamenti") { ok, _ in
            DispatchQueue.main.async {
                if ok { self.error = nil; self.open() } else { self.error = "Sblocco annullato. Tocca “Sblocca” per riprovare." }
            }
        }
    }

    /// Codice inserito nella schermata di blocco.
    func checkPin(_ pin: String, _ s: Settings) -> Bool {
        if Date() < waitUntil { error = "Troppi tentativi: aspetta \(Int(waitUntil.timeIntervalSinceNow.rounded(.up))) secondi."; return false }
        if hashPin(pin, s.pinSalt) != s.pinHash {
            fails += 1
            if fails % 5 == 0 { waitUntil = Date().addingTimeInterval(30) }
            error = fails % 5 == 0 ? "Troppi tentativi: aspetta 30 secondi." : "Codice sbagliato"
            return false
        }
        fails = 0; error = nil; open(); return true
    }
}

func greeting(_ s: Settings) -> String {
    let h = Date().hh
    let b = h < 12 ? "Buongiorno" : h < 18 ? "Buon pomeriggio" : "Buonasera"
    let nm = s.sign.trimmingCharacters(in: .whitespaces)
    return nm.isEmpty ? b : "\(b), \(nm)"
}

struct LockScreen: View {
    @Environment(AppStore.self) private var store
    @Environment(\.pal) private var pal
    let lock: LockModel
    @State private var ring = false
    @State private var shown = false

    var body: some View {
        let mode = lock.mode(store.data.settings)
        ZStack {
            LinearGradient(colors: pal.lockBg.map { Color(hex: $0) }, startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            FloatingTiles().ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: lock.showPin ? 30 : 120)
                ZStack {
                    Circle().stroke(.white.opacity(0.55), lineWidth: 2).frame(width: 132, height: 132)
                        .scaleEffect(ring ? 1.9 : 0.8).opacity(ring ? 0 : 0.9)
                    CoinLogo(colors: pal.logo, animate: true).id(lock.key)
                        .frame(width: lock.showPin ? 76 : 100, height: lock.showPin ? 76 : 100)
                        .clipShape(RoundedRectangle(cornerRadius: lock.showPin ? 18 : 23, style: .continuous))
                        .shadow(color: .black.opacity(0.45), radius: 14, y: 10)
                        .scaleEffect(shown ? 1 : 0.4).opacity(shown ? 1 : 0)
                }
                Text("Quote Abbonamenti").font(.system(size: lock.showPin ? 22 : 26, weight: .heavy)).padding(.top, 22)
                Text(greeting(store.data.settings)).opacity(0.85).padding(.top, 4)
                Spacer()
                if let e = lock.error {
                    Text(e).font(.system(size: 13, weight: .bold)).padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Color(hex: "#D7372F", opacity: 0.8), in: Capsule()).padding(.bottom, 12)
                }
                if lock.showPin {
                    let bioExtra: (String, () -> Void)? = mode == "bio" ? (LockModel.bioName, { lock.tryBio() }) : nil
                    PinPad(light: true, extra: bioExtra) { pin in
                        lock.checkPin(pin, store.data.settings)
                    }.padding(.bottom, 20)
                } else {
                    Button {
                        if lock.introOnly { lock.open() } else { lock.tryBio() }
                    } label: {
                        Text(lock.introOnly ? "Entra" : "Sblocca con \(LockModel.bioName)").font(.system(size: 17, weight: .heavy))
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(pal.lockButtonText)
                    }.buttonStyle(.plain)
                    if mode == "bio" && !store.data.settings.pinHash.isEmpty {
                        Button("Usa il codice") { lock.showPin = true }.font(.system(size: 15, weight: .bold)).foregroundStyle(.white.opacity(0.85)).padding(.top, 12)
                    }
                }
                Text("I tuoi dati restano solo su questo telefono.").font(.system(size: 13)).opacity(0.75).padding(.top, 12).padding(.bottom, 10)
            }
            .padding(.horizontal, 28)
            .foregroundStyle(.white)
            .frame(maxWidth: 520)
        }
        .contentShape(Rectangle())
        .onTapGesture { if lock.introOnly { lock.open() } }
        .scaleEffect(lock.unlocking ? 1.04 : 1)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { shown = true }
            withAnimation(.easeOut(duration: 1.6).delay(0.25)) { ring = true }
        }
    }
}

/// Icone degli abbonamenti che salgono piano dietro al logo.
struct FloatingTiles: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let items: [(String, Double, Double, Double, Double)] = [("musica", 0.12, 0.05, 26, 34), ("video", 0.8, 0.35, 31, 40), ("cloud", 0.32, 0.62, 28, 30), ("giochi", 0.88, 0.85, 35, 32), ("fitness", 0.58, 0.18, 30, 28), ("notizie", 0.04, 0.5, 37, 30), ("software", 0.68, 0.72, 27, 34)]
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                ZStack(alignment: .topLeading) {
                    ForEach(items.indices, id: \.self) { i in
                        let it = items[i]
                        let p = ((t / it.3) + it.2).truncatingRemainder(dividingBy: 1)
                        Tile(cat: it.0, size: it.4)
                            .rotationEffect(.degrees(-12 + 24 * p))
                            .opacity(0.38)
                            .position(x: it.1 * geo.size.width + it.4 / 2, y: geo.size.height + 70 - p * (geo.size.height + 140))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Tastierino del codice. onPin risponde true se il codice va bene.
struct PinPad: View {
    @Environment(\.pal) private var pal
    var light = false
    var extra: (String, () -> Void)? = nil
    let onPin: (String) -> Bool
    @State private var code = ""
    @State private var shake = 0

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { i in
                    Circle().strokeBorder(dotColor, lineWidth: 2).background(Circle().fill(i < code.count ? dotColor : .clear)).frame(width: 14, height: 14)
                }
            }
            .modifier(Shake(amount: CGFloat(shake)))
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(78), spacing: 22), count: 3), spacing: 14) {
                ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", "x", "0", "⌫"], id: \.self) { k in
                    if k == "x" {
                        if let extra { Button(extra.0, action: extra.1).font(.system(size: 14, weight: .bold)).foregroundStyle(light ? .white : pal.accent).frame(width: 74, height: 74) }
                        else { Color.clear.frame(width: 74, height: 74) }
                    } else {
                        Button { press(k) } label: {
                            Group { if k == "⌫" { Image(systemName: "delete.left").font(.system(size: 22)) } else { Text(k).font(.system(size: 30)) } }
                                .frame(width: 74, height: 74)
                                .background(k == "⌫" ? Color.clear : (light ? Color.white.opacity(0.2) : pal.cellSolid), in: Circle())
                                .foregroundStyle(light ? .white : (k == "⌫" ? pal.accent : pal.fg))
                        }.buttonStyle(.plain).accessibilityLabel(k == "⌫" ? "Cancella" : k)
                    }
                }
            }
        }
    }
    private var dotColor: Color { light ? .white : pal.accent }
    private func press(_ k: String) {
        if k == "⌫" { if !code.isEmpty { code.removeLast() }; return }
        guard code.count < 4 else { return }
        code += k
        if code.count == 4 {
            let pin = code
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                if !onPin(pin) { code = ""; withAnimation(.linear(duration: 0.4)) { shake += 1 }; UINotificationFeedbackGenerator().notificationOccurred(.error) }
            }
        }
    }
}

struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat { get { amount } set { amount = newValue } }
    func effectValue(size: CGSize) -> ProjectionTransform { ProjectionTransform(CGAffineTransform(translationX: 10 * sin(amount * .pi * 4), y: 0)) }
}

/// Foglio per scegliere un nuovo codice (due volte).
struct SetPinSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.pal) private var pal
    @Environment(\.dismiss) private var dismiss
    var title = "Scegli un codice di 4 cifre"
    let done: () -> Void
    @State private var first: String? = nil
    @State private var msg = "Lo chiederà l'app all'apertura."
    @State private var padKey = 0

    var body: some View {
        VStack(spacing: 6) {
            SheetBar(title: "Codice d'accesso", saveTitle: nil, onCancel: { dismiss() }, onSave: nil)
            Text(first == nil ? title : "Ripeti il codice").font(.system(size: 19, weight: .bold)).foregroundStyle(pal.fg).padding(.top, 18)
            Text(msg).font(.system(size: 14)).foregroundStyle(pal.ink2).frame(minHeight: 20)
            PinPad { pin in
                if first == nil {
                    if Set(pin).count == 1 || pin == "1234" { msg = "Troppo facile: scegline un altro."; return false }
                    first = pin; msg = ""; return false
                }
                if pin != first { first = nil; msg = "I codici non coincidono: riprova."; return false }
                let salt = Data((0..<12).map { _ in UInt8.random(in: 0...255) }).base64EncodedString()
                store.data.settings.pinSalt = salt
                store.data.settings.pinHash = hashPin(pin, salt)
                dismiss(); done(); return true
            }.padding(.top, 10)
            Spacer()
        }
        .background(pal.bg.ignoresSafeArea())
    }
}

/// Foglio per confermare il codice attuale prima di cambiare l'accesso.
struct VerifyPinSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.pal) private var pal
    @Environment(\.dismiss) private var dismiss
    let done: () -> Void
    @State private var msg = ""
    var body: some View {
        VStack(spacing: 6) {
            SheetBar(title: "Conferma", saveTitle: nil, onCancel: { dismiss() }, onSave: nil)
            Text("Inserisci il codice attuale").font(.system(size: 19, weight: .bold)).foregroundStyle(pal.fg).padding(.top, 18)
            Text(msg).font(.system(size: 14)).foregroundStyle(pal.late).frame(minHeight: 20)
            PinPad { pin in
                if hashPin(pin, store.data.settings.pinSalt) != store.data.settings.pinHash { msg = "Codice sbagliato"; return false }
                dismiss(); done(); return true
            }.padding(.top, 10)
            Spacer()
        }
        .background(pal.bg.ignoresSafeArea())
    }
}

/// Barra in cima ai fogli: Annulla · titolo · Salva.
struct SheetBar: View {
    @Environment(\.pal) private var pal
    let title: String
    var saveTitle: String? = "Salva"
    var saveEnabled = true
    let onCancel: () -> Void
    var onSave: (() -> Void)? = nil
    var body: some View {
        HStack {
            Button("Annulla", action: onCancel).foregroundStyle(pal.accent)
            Spacer()
            Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(pal.fg).lineLimit(1)
            Spacer()
            if let saveTitle, let onSave {
                Button(saveTitle, action: onSave).font(.system(size: 17, weight: .heavy)).foregroundStyle(pal.accent).disabled(!saveEnabled).opacity(saveEnabled ? 1 : 0.35)
            } else { Text("Annulla").opacity(0) }
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)
    }
}
