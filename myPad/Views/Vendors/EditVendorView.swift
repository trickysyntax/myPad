import SwiftUI
import MyPadKit

/// Edit vendor details from Vendor Detail. Keeps the form lightweight but covers
/// the fields currently exposed by the vendor API.
struct EditVendorView: View {
    let vendor: VendorDetail
    let onSaved: (VendorDetail) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var website: String
    @State private var category: String
    @State private var pricingTier: String
    @State private var knownFor: String
    @State private var address: String
    @State private var email: String
    @State private var phone: String
    @State private var socials: String
    @State private var tagsText: String
    @State private var prose: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let api = APIClient.shared

    init(vendor: VendorDetail, onSaved: @escaping (VendorDetail) -> Void) {
        self.vendor = vendor
        self.onSaved = onSaved
        self._name = State(initialValue: vendor.name)
        self._website = State(initialValue: vendor.website ?? "")
        self._category = State(initialValue: vendor.category ?? "")
        self._pricingTier = State(initialValue: vendor.pricingTier ?? "")
        self._knownFor = State(initialValue: vendor.knownFor ?? "")
        self._address = State(initialValue: vendor.address ?? "")
        self._email = State(initialValue: vendor.email ?? "")
        self._phone = State(initialValue: vendor.phone ?? "")
        self._socials = State(initialValue: vendor.socials ?? "")
        self._tagsText = State(initialValue: (vendor.tags ?? []).joined(separator: ", "))
        self._prose = State(initialValue: vendor.prose ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Vendor Name *", text: $name)
                    TextField("Category", text: $category)
                    TextField("Pricing Tier", text: $pricingTier)
                }

                Section("Contact") {
                    TextField("Website", text: $website)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone", text: $phone)
                    TextField("Socials", text: $socials)
                    TextEditor(text: $address)
                        .frame(minHeight: 60)
                }

                Section("Profile") {
                    TextField("Known For", text: $knownFor)
                    TextField("Tags (comma-separated)", text: $tagsText)
                    TextEditor(text: $prose)
                        .frame(minHeight: 120)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.studioCaption())
                            .foregroundStyle(Color.studioRejected)
                    }
                }

                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Save Vendor")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.studioSurface)
            .navigationTitle("Edit Vendor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let tags = tagsText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let updated = try await api.updateVendor(
                id: vendor.id,
                name: trimmedName,
                website: nilIfEmpty(website),
                category: nilIfEmpty(category),
                pricingTier: nilIfEmpty(pricingTier),
                knownFor: nilIfEmpty(knownFor),
                address: nilIfEmpty(address),
                email: nilIfEmpty(email),
                phone: nilIfEmpty(phone),
                socials: nilIfEmpty(socials),
                prose: nilIfEmpty(prose),
                tags: tags
            )
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func nilIfEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
