import SwiftUI

// Mattoncini dell'interfaccia: schede, titoli di sezione, righe, controlli segmentati, icone.

struct Card<Content: View>: View {
    @Environment(\.pal) private var pal
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(spacing: 0) { content }
            .background(pal.cell, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct SecHead: View {
    @Environment(\.pal) private var pal
    let text: String
    var trailing: String? = nil
    var trailingColor: Color? = nil
    var body: some View {
        HStack {
            Text(text.uppercased()).font(.system(size: 12.5)).foregroundStyle(pal.ink2).kerning(0.3)
            Spacer()
            if let trailing { Text(trailing).font(.system(size: 13, weight: .semibold)).foregroundStyle(trailingColor ?? pal.ink2) }
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)
    }
}

struct SecFoot: View {
    @Environment(\.pal) private var pal
    let text: String
    var color: Color? = nil
    init(_ text: String, color: Color? = nil) { self.text = text; self.color = color }
    var body: some View {
        Text(text).font(.system(size: 13)).foregroundStyle(color ?? pal.ink2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 4)
    }
}

/// Riga di una scheda, con il separatore sotto (tranne l'ultima).
struct Row<Content: View>: View {
    @Environment(\.pal) private var pal
    var last = false
    var action: (() -> Void)? = nil
    let content: Content
    init(last: Bool = false, action: (() -> Void)? = nil, @ViewBuilder _ content: () -> Content) { self.last = last; self.action = action; self.content = content() }
    var body: some View {
        let inner = HStack(spacing: 12) { content }
            .padding(.horizontal, 16).padding(.vertical, 11)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        VStack(spacing: 0) {
            if let action { Button(action: action) { inner }.buttonStyle(.plain) } else { inner }
            if !last { Rectangle().fill(pal.sep).frame(height: 0.5).padding(.leading, 16) }
        }
    }
}

struct LinkText: View {
    @Environment(\.pal) private var pal
    let text: String
    var danger = false
    init(_ text: String, danger: Bool = false) { self.text = text; self.danger = danger }
    var body: some View { Text(text).foregroundStyle(danger ? pal.late : pal.accent).frame(maxWidth: .infinity, alignment: .leading) }
}

/// Controllo segmentato nello stile dell'app.
struct Seg<T: Hashable>: View {
    @Environment(\.pal) private var pal
    let options: [(T, String)]
    @Binding var value: T
    var disabled: Set<T> = []
    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { i in
                let (v, lab) = options[i]
                let sel = v == value
                Button { if !disabled.contains(v) { withAnimation(.easeOut(duration: 0.15)) { value = v } } } label: {
                    Text(lab).font(.system(size: 14, weight: sel ? .bold : .regular)).lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity).padding(.vertical, 7)
                        .background(sel ? pal.cellSolid : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .shadow(color: sel ? .black.opacity(0.12) : .clear, radius: 2, y: 1)
                        .foregroundStyle(disabled.contains(v) ? pal.ink2.opacity(0.5) : pal.fg)
                }.buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(pal.dark ? Color.white.opacity(0.1) : Color(hex: "#767680", opacity: 0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// Icona del tipo di abbonamento, nello stile del tema.
struct Tile: View {
    @Environment(\.pal) private var pal
    let cat: String
    var size: CGFloat = 30
    var body: some View {
        Image("cat-\(pal.iconSkin)-\(CATS[cat] != nil ? cat : "altro")")
            .resizable().interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
    }
}

/// Cerchio di spunta "pagato".
struct CheckCircle: View {
    @Environment(\.pal) private var pal
    let on: Bool
    var body: some View {
        ZStack {
            Circle().strokeBorder(on ? pal.ok : pal.sep, lineWidth: 1.5).background(Circle().fill(on ? pal.ok : .clear))
            if on { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white) }
        }.frame(width: 26, height: 26)
    }
}

struct Badge: View {
    @Environment(\.pal) private var pal
    let text: String
    let kind: String // ok, mid, bad
    var body: some View {
        let c = kind == "ok" ? pal.ok : kind == "bad" ? pal.late : pal.warn
        Text(text).font(.system(size: 12, weight: .bold)).foregroundStyle(c)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(c.opacity(0.14), in: Capsule())
    }
}

struct ActButton: View {
    @Environment(\.pal) private var pal
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 9)
                .background(pal.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(pal.accent)
        }.buttonStyle(.plain)
    }
}

/// Campo per gli importi (accetta virgola e punto).
struct AmountField: View {
    @Environment(\.pal) private var pal
    let placeholder: String
    @Binding var value: Double
    @State private var text = ""
    @FocusState private var focused: Bool
    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).monospacedDigit()
            .focused($focused)
            .onAppear { text = amountText(value) }
            .onChange(of: text) { _, t in value = parseAmount(t) }
            .onChange(of: value) { _, v in if !focused && parseAmount(text) != v { text = amountText(v) } }
            .onChange(of: focused) { _, f in if !f { text = amountText(value) } }
    }
}

/// Barra del titolo grande in alto, con i pulsanti.
struct TopBar<Trailing: View>: View {
    @Environment(\.pal) private var pal
    let title: String
    let trailing: Trailing
    init(_ title: String, @ViewBuilder trailing: () -> Trailing) { self.title = title; self.trailing = trailing() }
    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(.system(size: 30, weight: .heavy)).foregroundStyle(pal.fg).lineLimit(1).minimumScaleFactor(0.7)
            Spacer()
            trailing.foregroundStyle(pal.accent)
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 4)
    }
}
extension TopBar where Trailing == EmptyView { init(_ title: String) { self.init(title) { EmptyView() } } }

struct EmptyState: View {
    @Environment(\.pal) private var pal
    let title: String
    let text: String
    let actions: [(String, Bool, () -> Void)]
    var body: some View {
        VStack(spacing: 10) {
            Image("logo-art").resizable().frame(width: 84, height: 84).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4).padding(.bottom, 6)
            Text(title).font(.system(size: 22, weight: .bold)).foregroundStyle(pal.fg)
            Text(text).font(.system(size: 15)).foregroundStyle(pal.ink2).multilineTextAlignment(.center).padding(.horizontal, 20)
            ForEach(actions.indices, id: \.self) { i in
                let a = actions[i]
                Button(action: a.2) {
                    Text(a.0).font(.system(size: 16, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(a.1 ? pal.accentSoft : pal.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(a.1 ? pal.accent : pal.onAccent)
                }.buttonStyle(.plain).padding(.horizontal, 16)
            }
        }.padding(.vertical, 40)
    }
}

/// Avviso breve in basso.
struct ToastView: View {
    @Environment(\.pal) private var pal
    let text: String
    var body: some View {
        Text(text).font(.system(size: 14)).multilineTextAlignment(.center)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(pal.fg, in: Capsule()).foregroundStyle(pal.cellSolid)
            .padding(.horizontal, 24)
    }
}

extension View {
    /// Contenuto di una schermata che scorre, con larghezza massima su iPad.
    func screen() -> some View { self.frame(maxWidth: 640).frame(maxWidth: .infinity).padding(.horizontal, 16) }
}
