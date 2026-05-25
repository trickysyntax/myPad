import SwiftUI
import MyPadKit

/// Root view with tab bar — Projects, Vendors, Assets.
/// Settings accessible via gear icon in each tab's toolbar.
struct ContentView: View {
    @State private var selectedTab = Tab.projects
    @State private var showSettings = false

    enum Tab: Hashable {
        case projects
        case vendors
        case assets
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ProjectListView()
                .tabItem {
                    Label("Projects", systemImage: "building.2")
                }
                .tag(Tab.projects)

            VendorListView()
                .tabItem {
                    Label("Vendors", systemImage: "bag")
                }
                .tag(Tab.vendors)

            AllAssetsView()
                .tabItem {
                    Label("Assets", systemImage: "cube.box")
                }
                .tag(Tab.assets)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .myPadOpenSettings)) { _ in
            showSettings = true
        }
    }
}

// MARK: - Settings Notification

extension Notification.Name {
    static let myPadOpenSettings = Notification.Name("myPadOpenSettings")
}


// MARK: - Shared UI helpers

func countLabel(_ count: Int, singular: String, plural: String? = nil) -> String {
    let word = count == 1 ? singular : (plural ?? singular + "s")
    return "\(count) \(word)"
}

struct AccountMenuButton: View {
    @State private var showProfile = false
    @State private var showPreferences = false

    var initial: String = "K"

    var body: some View {
        Menu {
            Button { showProfile = true } label: {
                Label("Profile", systemImage: "person.crop.circle")
            }
            Button { showPreferences = true } label: {
                Label("Preferences", systemImage: "slider.horizontal.3")
            }
            Divider()
            Button(role: .destructive) {
                Task {
                    await APIClient.shared.logout()
                    NotificationCenter.default.post(name: .myPadDidLogout, object: nil)
                }
            } label: {
                Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Text(initial.prefix(1).uppercased())
                .font(.studioCaption(size: 14))
                .fontWeight(.semibold)
                .foregroundStyle(Color.white)
                .frame(width: 34, height: 34)
                .background(Color.studioAccent)
                .clipShape(Circle())
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack { ProfileView() }
        }
        .sheet(isPresented: $showPreferences) {
            NavigationStack { PreferencesView() }
        }
    }
}

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Account") {
                HStack { Text("Name"); Spacer(); Text("Kassidy").foregroundStyle(Color.studioSecondary) }
                HStack { Text("Role"); Spacer(); Text("Designer").foregroundStyle(Color.studioSecondary) }
            }
            Section("Status") {
                Text("Profile editing route is ready; account fields can be connected when the backend exposes /me.")
                    .font(.studioCaption(size: 14))
                    .foregroundStyle(Color.studioSecondary)
            }
        }
        .navigationTitle("Profile")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
    }
}

struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("mypad.pref.cardDensity") private var compactCards = false
    @AppStorage("mypad.pref.showArchived") private var showArchived = true

    var body: some View {
        Form {
            Section("Browsing") {
                Toggle("Use compact cards", isOn: $compactCards)
                Toggle("Show archived projects", isOn: $showArchived)
            }
            Section("App") {
                Text("Preferences route is ready and stores local app preferences.")
                    .font(.studioCaption(size: 14))
                    .foregroundStyle(Color.studioSecondary)
            }
        }
        .navigationTitle("Preferences")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
    }
}
