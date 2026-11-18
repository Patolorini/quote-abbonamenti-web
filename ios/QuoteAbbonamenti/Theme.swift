import SwiftUI

// Tipi di abbonamento e temi, con gli stessi colori della versione web.

struct CatInfo { let name: String; let color: String; let keys: [String] }
let CAT_ORDER = ["musica", "video", "cloud", "giochi", "notizie", "fitness", "software", "internet", "altro"]
let CATS: [String: CatInfo] = [
    "musica": CatInfo(name: "Musica", color: "#E0457B", keys: ["spotify", "apple music", "deezer", "tidal", "youtube music", "soundcloud", "audible"]),
    "video": CatInfo(name: "Video", color: "#D9342B", keys: ["netflix", "disney", "prime video", "amazon prime", "apple tv", "sky", "dazn", "paramount", "youtube", "blue", "teleclub", "zattoo"]),
    "cloud": CatInfo(name: "Cloud", color: "#2F80ED", keys: ["icloud", "google one", "dropbox", "onedrive", "drive", "cloud"]),
    "giochi": CatInfo(name: "Giochi", color: "#7B5CF0", keys: ["playstation", "ps plus", "xbox", "game pass", "nintendo", "steam", "arcade"]),
    "notizie": CatInfo(name: "Notizie", color: "#C47F17", keys: ["giornale", "news", "corriere", "nzz", "tages", "blick", "rsi", "times", "kindle", "magazine"]),
    "fitness": CatInfo(name: "Fitness", color: "#1F9D5C", keys: ["palestra", "gym", "fitness", "strava", "peloton", "yoga"]),
    "software": CatInfo(name: "Software", color: "#55657A", keys: ["office", "microsoft 365", "adobe", "chatgpt", "claude", "notion", "1password", "canva"]),
    "internet": CatInfo(name: "Internet e telefono", color: "#0E97A6", keys: ["swisscom", "sunrise", "salt", "wingo", "yallo", "internet", "telefono", "mobile", "fibra", "wifi"]),
    "altro": CatInfo(name: "Altro", color: "#8A8A8E", keys: []),
]

struct ThemeDef {
    let name: String
    let light: (String, String)?   // colore principale, sfondo
    let dark: (String, String)?
    var forceDark = false
    var cell: String? = nil
    var deco: String? = nil
    var decoBg: ([String], [String])? = nil   // sfumatura dall'alto in basso (chiaro, scuro)
    var lockBg: [String]? = nil
    var onAccent: String? = nil
    var logo: (String, String)? = nil          // colori del logo (chiaro, scuro)
}

let THEME_ORDER = ["predefinito", "mare", "sakura", "stelle", "aurora", "autunno", "neve"]
let THEMES: [String: ThemeDef] = [
    "predefinito": ThemeDef(name: "Predefinito", light: nil, dark: nil),
    "mare": ThemeDef(name: "Mare", light: ("#0E7C9E", "#E4F3F8"), dark: ("#4FC3E0", "#06141B"), deco: "mare",
                     decoBg: (["#CDEFF8", "#E4F3F8", "#D2ECF4"], ["#08202B", "#06141B", "#041017"]), logo: ("#4FC9E0", "#0E5F86")),
    "sakura": ThemeDef(name: "Sakura", light: ("#C93D73", "#FCEFF4"), dark: ("#FF8FB8", "#1A0D12"), deco: "sakura",
                       decoBg: (["#FBE1EA", "#FCEFF4", "#FFF6F9"], ["#2A1220", "#1A0D12"]), logo: ("#FF9DBE", "#C93D73")),
    "stelle": ThemeDef(name: "Stelle", light: ("#FFD36E", "#070B1F"), dark: ("#FFD36E", "#070B1F"), forceDark: true, cell: "#121833", deco: "stelle",
                       decoBg: (["#1B2559", "#0B1233", "#050816"], ["#1B2559", "#0B1233", "#050816"]), lockBg: ["#2A3A80", "#0B1233", "#03050F"], onAccent: "#1A1405", logo: ("#2A3A80", "#070B1F")),
    "aurora": ThemeDef(name: "Aurora", light: ("#5BE7AE", "#050B12"), dark: ("#5BE7AE", "#050B12"), forceDark: true, cell: "#0F1A22", deco: "aurora",
                       decoBg: (["#071824", "#050B12"], ["#071824", "#050B12"]), lockBg: ["#0F6B5A", "#1B3D86", "#3B1D5E", "#05080F"], onAccent: "#04140C", logo: ("#0F6B5A", "#2A1D5E")),
    "autunno": ThemeDef(name: "Autunno", light: ("#B8501A", "#F8EEE3"), dark: ("#F09A5A", "#160E08"), deco: "autunno",
                        decoBg: (["#F6E1C9", "#F8EEE3"], ["#24150B", "#160E08"]), logo: ("#E9873F", "#8C3512")),
    "neve": ThemeDef(name: "Neve", light: ("#2F6FCC", "#EEF4FB"), dark: ("#8DB8FF", "#0A1019"), deco: "neve",
                     decoBg: (["#DCE9F8", "#EEF4FB", "#F7FAFE"], ["#0F1A2B", "#0A1019"]), logo: ("#8FB4EE", "#2F5FAF")),
]
let ACCENTS: [(String, String)] = [("#0F8A7A", "Alpino"), ("#007AFF", "Blu"), ("#1D5FD1", "Lago"), ("#5E5CE6", "Indaco"), ("#8E5BD8", "Viola"), ("#D6487E", "Rosa"),
                                   ("#D7372F", "Rosso"), ("#D2522A", "Tramonto"), ("#C98A06", "Oro"), ("#2F6B3A", "Bosco"), ("#5C6B73", "Grafite")]
let BACKS: [(String, String)] = [("tinta", "Del colore"), ("neutro", "Neutro"), ("caldo", "Caldo")]

// MARK: colori

func rgb(_ hex: String) -> (Double, Double, Double) {
    var s = hex.trimmingCharacters(in: .whitespaces); if s.hasPrefix("#") { s.removeFirst() }
    let v = UInt32(s, radix: 16) ?? 0
    return (Double((v >> 16) & 255), Double((v >> 8) & 255), Double(v & 255))
}
/// Mescola due colori #rrggbb (p = quota del primo).
func mix(_ a: String, _ b: String, _ p: Double) -> String {
    let x = rgb(a), y = rgb(b)
    let c = [x.0 * p + y.0 * (1 - p), x.1 * p + y.1 * (1 - p), x.2 * p + y.2 * (1 - p)].map { Int($0.rounded()) }
    return String(format: "#%02X%02X%02X", c[0], c[1], c[2])
}
func lum(_ c: String) -> Double { let (r, g, b) = rgb(c); return 0.2126 * r / 255 + 0.7152 * g / 255 + 0.0722 * b / 255 }

extension Color {
    init(hex: String, opacity: Double = 1) { let (r, g, b) = rgb(hex); self.init(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: opacity) }
}

/// Tutti i colori del tema attivo.
struct Palette {
    var themeId = "predefinito"
    var dark = false
    var accentHex = "#0F8A7A"
    var bgHex = "#EAF2F0"
    var cellHex = "#FFFFFF"
    var deco: String? = nil
    var decoBg: [String]? = nil
    var lockBg: [String] = []
    var logo: (String, String) = ("#17A693", "#0A5F54")

    var accent: Color { Color(hex: accentHex) }
    var bg: Color { Color(hex: bgHex) }
    var cell: Color { deco != nil ? Color(hex: cellHex, opacity: 0.86) : Color(hex: cellHex) }
    var cellSolid: Color { Color(hex: cellHex) }
    var accentSoft: Color { Color(hex: mix(accentHex, cellHex, 0.2)) }
    var onAccent: Color = .white
    var fg: Color { dark ? Color(hex: "#F2F2F7") : Color(hex: "#14201E") }
    var ink2: Color { dark ? Color(hex: "#8D8D93") : Color(hex: "#6F7C79") }
    var sep: Color { dark ? Color(hex: mix(cellHex, "#FFFFFF", 0.8)) : Color(hex: "#DCDFE0") }
    var late: Color { dark ? Color(hex: "#FF6961") : Color(hex: "#D7372F") }
    var ok: Color { dark ? Color(hex: "#5FD38D") : Color(hex: "#1F9D5C") }
    var warn: Color { dark ? Color(hex: "#F0A35A") : Color(hex: "#B4540A") }
    var lockButtonText: Color { lum(accentHex) > 0.55 ? Color(hex: mix(accentHex, "#000000", 0.42)) : accent }
    /// Stile delle icone degli abbonamenti (cartella delle immagini).
    var iconSkin: String { THEMES[themeId]?.deco != nil ? themeId : "predefinito" }

    static func make(_ st: Settings) -> Palette {
        var p = Palette()
        let t = THEMES[st.theme] ?? THEMES["predefinito"]!
        p.themeId = THEMES[st.theme] != nil ? st.theme : "predefinito"
        p.dark = t.forceDark || st.mode == "scuro"
        if let l = t.light, let d = t.dark {
            let c = p.dark ? d : l
            p.accentHex = c.0; p.bgHex = c.1
            p.cellHex = p.dark ? (t.cell ?? "#1C1C1E") : "#FFFFFF"
            p.deco = t.deco
            p.decoBg = t.decoBg.map { p.dark ? $0.1 : $0.0 }
            p.logo = t.logo ?? p.logo
        } else {
            let base = st.accent.isEmpty ? ACCENTS[0].0 : st.accent
            p.accentHex = p.dark ? mix(base, "#FFFFFF", lum(base) > 0.5 ? 1 : 0.72) : base
            switch st.back {
            case "neutro": p.bgHex = p.dark ? "#000000" : "#F2F2F7"
            case "caldo": p.bgHex = p.dark ? "#14110D" : "#F7F1E8"
            default: p.bgHex = p.dark ? mix(base, "#0A0A0B", 0.1) : mix(base, "#F6F7F7", 0.09)
            }
            p.cellHex = p.dark ? (st.back == "tinta" ? mix(base, "#1C1C1E", 0.06) : "#1C1C1E") : "#FFFFFF"
            p.logo = (mix(base, "#FFFFFF", 0.82), mix(base, "#000000", 0.62))
        }
        p.onAccent = Color(hex: t.onAccent ?? (lum(p.accentHex) > 0.55 ? "#0B0B0B" : "#FFFFFF"))
        p.lockBg = t.lockBg ?? [p.accentHex, mix(p.accentHex, "#000000", 0.62), "#070B0A"]
        return p
    }
}

private struct PaletteKey: EnvironmentKey { static let defaultValue = Palette() }
extension EnvironmentValues {
    var pal: Palette { get { self[PaletteKey.self] } set { self[PaletteKey.self] = newValue } }
}
