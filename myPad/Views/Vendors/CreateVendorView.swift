import SwiftUI
import MyPadKit

/// Quick vendor creation modal. Returns the new vendor's id and name.
struct CreateVendorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var website = ""
    @State private var category = ""
    @State private var tagsText = ""
    @State private var prose = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    /// Called on success with (vendorId, vendorName).
    let onCreated: (String, String) -> Void

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Vendor Name *", text: $name)
                } header: {
                    Text("Name")
                }

                Section {
                    TextField("https://...", text: $website)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                } header: {
                    Text("Website")
                }

                Section {
                    TextField("e.g. Lighting, Furniture", text: $category)
                    TextField("Tags (comma-separated)", text: $tagsText)
                } header: {
                    Text("Classification")
                }

                Section {
                    TextEditor(text: $prose)
                        .frame(minHeight: 60)
                } header: {
                    Text("Notes")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.studioCaption())
                            .foregroundStyle(Color.studioRejected)
                    }
                }

                Section {
                    Button {
                        Task { await create() }
                    } label: {
                        HStack {
                            Spacer()
                            if isCreating {
                                ProgressView()
                            } else {
                                Text("Create Vendor")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(name.isEmpty || isCreating)
                }
            }
            .navigationTitle("New Vendor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func create() async {
        guard !name.isEmpty else { return }
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }

        do {
            let tags: [String]? = {
                let parts = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                return parts.isEmpty ? nil : parts
            }()

            let vendor = try await api.createVendor(
                name: name.trimmingCharacters(in: .whitespaces),
                website: website.isEmpty ? nil : website.trimmingCharacters(in: .whitespaces),
                category: category.isEmpty ? nil : category.trimmingCharacters(in: .whitespaces),
                tags: tags,
                prose: prose.isEmpty ? nil : prose.trimmingCharacters(in: .whitespaces)
            )
            onCreated(vendor.id, vendor.name)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
