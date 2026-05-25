import SwiftUI
import MyPadKit

/// Settings tab — server config, sync status, account, logout.
struct SettingsView: View {
    @State private var serverURL: String
    @State private var isSyncing = false
    @State private var lastSyncText: String?
    @State private var errorText: String?

    private let syncEngine = SyncEngine.shared
    private let syncCoordinator = SyncCoordinator.shared

    init() {
        _serverURL = State(initialValue: UserDefaults.standard.string(forKey: "mypad.serverURL") ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                // Server section
                Section {
                    HStack {
                        Text("Server")
                        Spacer()
                        TextField("https://mypad.susie.cloud", text: $serverURL)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(Color.studioSecondary)
                            .onSubmit { saveServerURL() }
                    }

                    Button("Save Server URL") {
                        saveServerURL()
                    }
                    .disabled(serverURL.isEmpty)
                } header: {
                    Text("Server Configuration")
                }

                // Sync section
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(syncEngine.isOnline ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(syncEngine.isOnline ? "Online" : "Offline")
                                .foregroundStyle(Color.studioSecondary)
                        }
                    }

                    if let last = lastSyncText {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(last)
                                .foregroundStyle(Color.studioSecondary)
                        }
                    }

                    if isSyncing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Syncing...")
                                .foregroundStyle(Color.studioSecondary)
                        }
                    }

                    Button {
                        Task { await manualSync() }
                    } label: {
                        Text("Sync Now")
                    }
                    .disabled(isSyncing || !syncEngine.isOnline)

                    if let error = errorText {
                        Text(error)
                            .font(.studioCaption())
                            .foregroundStyle(Color.studioRejected)
                    }
                } header: {
                    Text("Sync")
                }

                // Account section
                Section {
                    Button("Log Out") {
                        Task { await logout() }
                    }
                    .foregroundStyle(Color.studioRejected)
                } header: {
                    Text("Account")
                }

                // About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("0.3.0")
                            .foregroundStyle(Color.studioSecondary)
                    }
                    HStack {
                        Text("Platform")
                        Spacer()
                        Text("iOS 17+ / iPadOS 17+")
                            .foregroundStyle(Color.studioSecondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func saveServerURL() {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: "mypad.serverURL")
        } else {
            UserDefaults.standard.set(trimmed, forKey: "mypad.serverURL")
        }
    }

    private func manualSync() async {
        isSyncing = true
        errorText = nil
        await syncCoordinator.syncNow()
        isSyncing = false

        if let error = syncEngine.syncError {
            errorText = error
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            lastSyncText = formatter.string(from: Date())
        }
    }

    @MainActor
    private func logout() async {
        await APIClient.shared.logout()
        NotificationCenter.default.post(name: .myPadDidLogout, object: nil)
    }
}
