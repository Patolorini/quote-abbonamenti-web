import SwiftUI
import UniformTypeIdentifiers
import LocalAuthentication

/// Documento per esportare e importare (backup JSON o pagamenti CSV).
struct TextFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText, .plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws { text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self) }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.pal) private var pal
    let lock: LockModel

    @State private var exportDoc: TextFile? = nil
    @State private var exportName = ""
    @State private var exportType: UTType = .json
    @State private var exporting = false
    @State private var importing = false
    @State private var pendingImport: AppData? = nil
    @State private var wipeConfirm = false
    @State private var setPin: (() -> Void)? = nil
    @State private var verifyPin: (() -> Void)? = nil

    var body: some View {
        @Bindable var st = store
        VStack(spacing: 0) {
            TopBar("Impostazioni")
            ScrollView {
                VStack(spacing: 6) {
                    themes
                    if store.data.settings.theme == "predefinito" { colors } else {
                        SecFoot("\(THEMES[store.data.settings.theme]?.name ?? ""): colori, sfondo animato e icone degli abbonamenti in tema. Le animazioni si fermano se nel telefono hai attivato \"Riduci movimento\".")
                    }
                    appearance
                    access
                    messages(st)
                    followUp
                    backup
                    dataSection
                }.screen().padding(.bottom, 30).padding(.top, 6)
            }.scrollDismissesKeyboard(.interactively)
        }
        .fileExporter(isPresented: $exporting, document: exportDoc, contentType: exportType, defaultFilename: exportName) { r in
            if case .success = r { store.show("File salvato") }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText]) { r in
            guard case .success(let url) = r else { return }
            let ok = url.startAccessingSecurityScopedResource(); defer { if ok { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url), let j = try? JSONDecoder().decode(AppData.self, from: data), j.v == 1 else {
                store.show("Questo file non è un backup di Quote Abbonamenti"); return
            }
            pendingImport = j
        }
        .alert("Importa backup", isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } })) {
            Button("Sostituisci", role: .destructive) {
                if var j = pendingImport { j.exportedAt = nil; j.settings.migrate(); store.data = j; store.show("Backup importato") }
                pendingImport = nil
            }
            Button("Annulla", role: .cancel) { pendingImport = nil }
        } message: {
            if let j = pendingImport {
                let when = parseISO(j.exportedAt).map(fmtDate) ?? "data sconosciuta"
                Text("Backup del \(when): \(j.subs.count) abbonamenti, \(j.payments.values.reduce(0) { $0 + $1.count }) pagamenti e \(j.reminders.count) promemoria. Tutti i dati attuali verranno sostituiti.")
            }
        }
        .sheet(isPresented: Binding(get: { setPin != nil }, set: { if !$0 { setPin = nil } })) {
            SetPinSheet(done: { setPin?(); setPin = nil }).environment(store).environment(\.pal, pal)
        }
        .sheet(isPresented: Binding(get: { verifyPin != nil }, set: { if !$0 { verifyPin = nil } })) {
            VerifyPinSheet(done: { let f = verifyPin; verifyPin = nil; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { f?() } }).environment(store).environment(\.pal, pal)
        }
    }

    // MARK: tema

    @ViewBuilder private var themes: some View {
        SecHead(text: "Tema")
        Card {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(THEME_ORDER, id: \.self) { id in
                    let on = store.data.settings.theme == id
                    Button { withAnimation(.easeOut(duration: 0.25)) { store.data.settings.theme = id } } label: {
                        VStack(spacing: 7) {
                            ThemeIcon(id: id, accent: store.data.settings.accent).frame(width: 44, height: 44)
                            Text(THEMES[id]!.name).font(.system(size: 13, weight: on ? .bold : .regular)).foregroundStyle(pal.fg)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(pal.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(on ? pal.accent : .clear, lineWidth: 2))
                    }.buttonStyle(.plain)
                }
            }.padding(12)
            HStack {
                ForEach(CAT_ORDER, id: \.self) { c in
                    Tile(cat: c)
                    if c != "altro" { Spacer(minLength: 0) }
                }
            }
                .padding(.horizontal, 16).padding(.bottom, 14)
        }
    }

    @ViewBuilder private var colors: some View {
        let cur = store.data.settings.accent.uppercased()
        let custom = !ACCENTS.contains { $0.0.uppercased() == cur }
        SecHead(text: "Colori")
        Card {
            Row {
                Text("Colore principale").frame(maxWidth: .infinity, alignment: .leading)
                Text(ACCENTS.first { $0.0.uppercased() == cur }?.1 ?? "Su misura").font(.system(size: 14)).foregroundStyle(pal.ink2)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(ACCENTS, id: \.0) { a in
                    Button { store.data.settings.accent = a.0 } label: { swatch(Color(hex: a.0), sel: a.0.uppercased() == cur) }.buttonStyle(.plain).accessibilityLabel(a.1)
                }
                ColorPicker("", selection: Binding(get: { Color(hex: store.data.settings.accent) }, set: { c in store.data.settings.accent = c.hexString }), supportsOpacity: false)
                    .labelsHidden().overlay { if custom { Circle().strokeBorder(pal.fg, lineWidth: 2).frame(width: 40, height: 40).allowsHitTesting(false) } }
            }.padding(.horizontal, 16).padding(.vertical, 12)
            Rectangle().fill(pal.sep).frame(height: 0.5).padding(.leading, 16)
            Row(last: true) {
                Text("Sfondo")
                Seg(options: BACKS.map { ($0.0, $0.1) }, value: Binding(get: { store.data.settings.back }, set: { store.data.settings.back = $0 }))
            }
        }
        SecFoot("L'ultimo cerchio colorato apre la tavolozza per un colore tutto tuo.")
    }

    private func swatch(_ c: Color, sel: Bool) -> some View {
        ZStack {
            Circle().fill(c).frame(width: 36, height: 36)
            if sel { Circle().strokeBorder(pal.fg, lineWidth: 2).frame(width: 44, height: 44); Image(systemName: "checkmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white) }
        }.frame(width: 44, height: 44)
    }

    @ViewBuilder private var appearance: some View {
        let forced = THEMES[store.data.settings.theme]?.forceDark == true
        SecHead(text: "Aspetto")
        Card {
            Row(last: true) {
                Seg(options: [("chiaro", "Chiaro"), ("scuro", "Scuro")], value: Binding(get: { forced ? "scuro" : store.data.settings.mode }, set: { if !forced { store.data.settings.mode = $0 } }),
                    disabled: forced ? ["chiaro"] : [])
            }
        }
        SecFoot(forced ? "Il tema \(THEMES[store.data.settings.theme]?.name ?? "") è sempre scuro." : "Scegli tu se usare l'app chiara o scura.")
    }

    // MARK: accesso

    @ViewBuilder private var access: some View {
        let s = store.data.settings, mode = lock.mode(s), bio = LockModel.bioName
        SecHead(text: "Accesso")
        Card {
            Row(last: mode == "nessuno") {
                Seg(options: [("nessuno", "Nessuno"), ("bio", bio), ("pin", "Codice")], value: Binding(get: { mode }, set: { changeMode($0) }),
                    disabled: LockModel.bioAvailable ? [] : ["bio"])
            }
            if mode != "nessuno" {
                Row(last: !(mode == "pin")) {
                    Text("Richiedi")
                    Seg(options: [(0, "Subito"), (60, "1 min"), (300, "5 min")], value: Binding(get: { store.data.settings.lockDelay }, set: { store.data.settings.lockDelay = $0 }))
                }
                if mode == "pin" {
                    Row(last: true, action: { verify { setPin = { store.show("Codice cambiato") } } }) { LinkText("Cambia codice") }
                }
            }
        }
        SecFoot(mode == "nessuno" ? "L'app si apre con la schermata d'entrata, senza chiedere niente."
                : mode == "bio" ? "All'apertura l'app chiede \(bio) (o il codice del telefono). Per cambiare devi prima sbloccare."
                : "All'apertura l'app chiede il codice di 4 cifre. Se lo dimentichi non si può recuperare: tieni un backup.")
    }

    private func verify(_ ok: @escaping () -> Void) {
        let mode = lock.mode(store.data.settings)
        if mode == "pin" { verifyPin = ok; return }
        if mode == "bio" {
            let c = LAContextHelper()
            c.authenticate { r in if r { ok() } else { store.show("Sblocco non riuscito") } }
            return
        }
        ok()
    }

    private func changeMode(_ to: String) {
        let mode = lock.mode(store.data.settings)
        guard to != mode else { return }
        verify {
            switch to {
            case "nessuno": store.data.settings.lockMode = "nessuno"; store.data.settings.lock = false; store.show("Accesso libero")
            case "pin": setPin = { store.data.settings.lockMode = "pin"; store.data.settings.lock = true; store.show("Codice attivato") }
            default:
                LAContextHelper().authenticate { r in
                    if r { store.data.settings.lockMode = "bio"; store.data.settings.lock = true; store.show("\(LockModel.bioName) attivato") } else { store.show("Sblocco non riuscito") }
                }
            }
        }
    }

    // MARK: messaggi, sollecito, backup, dati

    @ViewBuilder private func messages(_ st: AppStore) -> some View {
        @Bindable var st = st
        SecHead(text: "Messaggi")
        Card {
            Row {
                Text("Numero TWINT")
                TextField("079 123 45 67", text: $st.data.settings.twint).keyboardType(.phonePad).multilineTextAlignment(.trailing).foregroundStyle(pal.accent)
            }
            Row(last: true) {
                Text("Firma")
                TextField("Il tuo nome", text: $st.data.settings.sign).multilineTextAlignment(.trailing).foregroundStyle(pal.accent)
            }
        }
        SecFoot("Il numero viene aggiunto ai messaggi, così chi deve pagare sa subito dove mandare i soldi.")
    }

    @ViewBuilder private var followUp: some View {
        let fu = store.data.settings.fu
        SecHead(text: "Sollecito automatico")
        Card { Row(last: true) { Seg(options: [(0, "No"), (3, "3 g"), (5, "5 g"), (7, "7 g"), (14, "14 g")], value: Binding(get: { fu }, set: { store.data.settings.fu = $0 })) } }
        SecFoot(fu > 0 ? "\(fu) giorni dopo il promemoria, se qualcuno non ha ancora pagato, ricevi una notifica con chi manca. Se hanno pagato tutti, non arriva." : "Nessun sollecito: ricevi solo il promemoria.")
    }

    @ViewBuilder private var backup: some View {
        let day = "\(keyOf(now()))-\(two(now().d))"
        SecHead(text: "Backup")
        Card {
            Row(action: {
                var d = store.data; d.exportedAt = isoString(Date())
                let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
                exportDoc = TextFile(text: String(decoding: (try? enc.encode(d)) ?? Data(), as: UTF8.self))
                exportName = "QuoteAbbonamenti-backup-\(day).json"; exportType = .json; exporting = true
                store.data.settings.lastBackup = isoString(Date())
            }) { LinkText("Esporta backup") }
            Row(action: { importing = true }) { LinkText("Importa backup") }
            Row(last: true, action: {
                exportDoc = TextFile(text: store.data.paymentsCSV()); exportName = "QuoteAbbonamenti-pagamenti-\(day).csv"; exportType = .commaSeparatedText; exporting = true
            }) { LinkText("Esporta pagamenti per Excel (CSV)") }
        }
        SecFoot("I dati restano solo su questo iPhone, in un archivio SQLite dentro l'app. Esporta ogni tanto un backup (per esempio su iCloud Drive) per non perderli se cambi telefono. Il backup è lo stesso della versione web e Android." + (parseISO(store.data.settings.lastBackup).map { " Ultimo backup: \(fmtDate($0))." } ?? ""))
    }

    @ViewBuilder private var dataSection: some View {
        SecHead(text: "Aiuto")
        Card { Row(last: true, action: { store.tutorialAgain = true }) { LinkText("Rivedi il tutorial") } }
        SecFoot("Una breve guida su come usare l'app, in 6 passi.")
        SecHead(text: "Dati")
        Card {
            Row(action: { store.loadSample() }) { LinkText("Carica dati di esempio") }
            Row(last: true, action: { if wipeConfirm { store.wipe(); wipeConfirm = false } else { wipeConfirm = true } }) {
                LinkText(wipeConfirm ? "Tocca di nuovo per cancellare tutto" : "Cancella tutti i dati", danger: true)
            }
        }
        SecFoot("Quote Abbonamenti per iPhone · versione \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
    }
}

/// Icona del tema nella scelta dei temi.
struct ThemeIcon: View {
    let id: String
    let accent: String
    var body: some View {
        if id == "predefinito" {
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(hex: accent).opacity(0.55), Color(hex: accent)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image("palette").resizable()
                Circle().fill(Color(hex: accent)).overlay(Circle().strokeBorder(.white, lineWidth: 1)).frame(width: 5.2, height: 5.2).position(x: 29.6, y: 21.6)
            }.frame(width: 44, height: 44).clipShape(Circle())
        } else {
            Image("theme-\(id)").resizable().clipShape(Circle())
        }
    }
}

/// Richiesta di Face ID / codice del telefono.
final class LAContextHelper {
    func authenticate(_ done: @escaping (Bool) -> Void) {
        let c = LAContext()
        c.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Conferma per cambiare l'accesso") { ok, _ in DispatchQueue.main.async { done(ok) } }
    }
}

extension Color {
    /// Colore in formato #RRGGBB.
    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let c = [r, g, b].map { Int((max(0, min(1, $0)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", c[0], c[1], c[2])
    }
}
