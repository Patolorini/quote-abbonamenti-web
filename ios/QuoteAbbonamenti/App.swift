import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = Notifications.shared
        return true
    }
}

@main
struct QuoteAbbonamentiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

/// Le cinque schede in basso.
let TABS: [(id: String, title: String, icon: String)] = [
    ("mese", "Questo mese", "calendar.badge.checkmark"), ("abbonamenti", "Abbonamenti", "creditcard"),
    ("statistiche", "Statistiche", "chart.pie"), ("promemoria", "Promemoria", "bell"), ("impostazioni", "Impostazioni", "slider.horizontal.3"),
]

struct RootView: View {
    @State private var store = AppStore.shared
    @State private var lock = LockModel()
    @Environment(\.scenePhase) private var phase

    var body: some View {
        let pal = store.pal
        ZStack {
            DecoBackground(pal: pal).ignoresSafeArea()
            VStack(spacing: 0) {
                Group {
                    switch store.tab {
                    case "abbonamenti": SubsView()
                    case "statistiche": StatsView()
                    case "promemoria": RemindersView()
                    case "impostazioni": SettingsView(lock: lock)
                    default: MonthView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                TabBar()
            }
            if let t = store.toast {
                VStack { Spacer(); ToastView(text: t).padding(.bottom, 92) }
                    .transition(.opacity).allowsHitTesting(false)
            }
            if !lock.visible && (store.data.settings.tutorialSeen != true || store.tutorialAgain) {
                TutorialView(again: store.tutorialAgain).transition(.move(edge: .bottom).combined(with: .opacity)).zIndex(5)
            }
            if lock.visible { LockScreen(lock: lock).transition(.opacity).zIndex(10) }
        }
        .animation(.easeOut(duration: 0.2), value: store.toast)
        .animation(.easeOut(duration: 0.3), value: store.tutorialAgain)
        .environment(store)
        .environment(\.pal, pal)
        .tint(pal.accent)
        .preferredColorScheme(pal.dark ? .dark : .light)
        .onAppear {
            // Modalità demo (solo per le foto automatiche su GitHub): -demo [-tab nome] [-theme nome]
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-demo") {
                if store.data.subs.isEmpty { store.loadSample() }
                store.toast = nil
                store.data.settings.tutorialSeen = true
                store.data.settings.lockMode = "nessuno"
                if let i = args.firstIndex(of: "-tab"), i + 1 < args.count { store.tab = args[i + 1] }
                if args.contains("-remNext") { let d = D(now().y, now().mo + 1, 1); store.remY = d.y; store.remM = d.mo }
                if args.contains("-remPrev") { let d = D(now().y, now().mo - 7, 1); store.remY = d.y; store.remM = d.mo }
                store.data.settings.theme = args.firstIndex(of: "-theme").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } ?? "predefinito"
                lock.visible = false
                if args.contains("-intro") { lock.start(store) }
                return
            }
            lock.start(store)
        }
        .onChange(of: phase) { _, p in
            if p == .background { store.saveNow(); lock.wentAway() }
            if p == .active { lock.cameBack(store) }
        }
    }
}

struct TabBar: View {
    @Environment(AppStore.self) private var store
    @Environment(\.pal) private var pal
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TABS, id: \.id) { t in
                let on = store.tab == t.id
                Button { store.tab = t.id } label: {
                    VStack(spacing: 3) {
                        Image(systemName: t.icon).font(.system(size: 21, weight: .regular)).frame(height: 26)
                        Text(t.title).font(.system(size: 10.5, weight: on ? .bold : .regular)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 7).padding(.bottom, 4)
                    .foregroundStyle(on ? pal.accent : pal.ink2)
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
        .background(alignment: .top) {
            Rectangle().fill(pal.deco != nil ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(pal.cellSolid))
                .overlay(alignment: .top) { Rectangle().fill(pal.sep).frame(height: 0.5) }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
