import SwiftUI
import SwiftData
import MyPadKit

@main
struct myPadApp: App {
    @State private var syncEngine = SyncEngine.shared
    @State private var syncCoordinator = SyncCoordinator.shared
    @State private var isAuthenticated = false
    @State private var authCheckDone = false

    let modelContainer: ModelContainer

    init() {
        // ── Studio Design System ──
        let accentColor = UIColor(red: 0.78, green: 0.62, blue: 0.24, alpha: 1.0)
        let surfaceColor = UIColor(red: 0.97, green: 0.96, blue: 0.94, alpha: 1.0)
        let secondaryColor = UIColor(red: 0.55, green: 0.50, blue: 0.42, alpha: 1.0)

        UIView.appearance().tintColor = accentColor

        // List backgrounds — does not affect navigation titles
        UITableView.appearance().backgroundColor = surfaceColor

        // Window background — UIKit level, so no white flash during transitions
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.backgroundColor = surfaceColor
        }

        // Tab bar — studio palette, suppress grey selection indicator
        let tabAppearance = UITabBarAppearance()
        tabAppearance.backgroundColor = surfaceColor
        tabAppearance.shadowColor = UIColor(red: 0.90, green: 0.88, blue: 0.84, alpha: 0.5) // studioDivider

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = secondaryColor
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: secondaryColor]
        itemAppearance.selected.iconColor = accentColor
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: accentColor]

        tabAppearance.stackedLayoutAppearance = itemAppearance
        tabAppearance.inlineLayoutAppearance = itemAppearance
        tabAppearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        // Suppress the default grey selection indicator pill
        UITabBar.appearance().selectionIndicatorImage = UIImage()

        do {
            // Register all SwiftData models
            let schema = Schema([
                SDVendor.self,
                SDAssetTemplate.self,
                SDAssetFinish.self,
                SDSelectionFinish.self,
                SDClient.self,
                SDProject.self,
                SDRoom.self,
                SDSelection.self,
                SDSyncState.self,
                SDPendingChange.self,
            ])

            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.studioSurface
                    .ignoresSafeArea()

                Group {
                    if !authCheckDone {
                        // Brief loading spinner while we check Keychain/UserDefaults for an existing token
                        ProgressView("Loading…")
                            .task {
                                isAuthenticated = await AuthManager.shared.hasToken
                                authCheckDone = true
                            }
                    } else if isAuthenticated {
                        ContentView()
                            .modelContainer(modelContainer)
                            .environment(syncEngine)
                            .tint(Color.studioAccent)
                            .task {
                                syncCoordinator.configure(modelContainer: modelContainer)
                            }
                            .onReceive(NotificationCenter.default.publisher(for: .myPadDidLogout)) { _ in
                                withAnimation {
                                    isAuthenticated = false
                                }
                            }
                    } else {
                        LoginView(onLoginSuccess: {
                            withAnimation {
                                isAuthenticated = true
                            }
                        })
                    }
                }
            }
            .tint(Color.studioAccent)
        }
    }
}
