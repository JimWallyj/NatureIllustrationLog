import SwiftUI

/// Shown over the whole app while files are being imported: a progress
/// indicator, the Name Conflict choices, the "not enough space" message, and
/// the summary at the end. It sits under any open sheet and appears once that
/// sheet closes, so an import never gets stuck behind another screen.
struct ImportOverlay: View {
    let importer: ImportManager

    var body: some View {
        ZStack {
            if isShowingSomething {
                Color.black.opacity(0.3).ignoresSafeArea()
            }

            if let conflict = importer.conflict {
                NameConflictCard(conflict: conflict, importer: importer)
                    .id(conflict.id)
            } else if let problem = importer.spaceProblem {
                MessageCard(title: "Not Enough Space") {
                    Text("There isn't enough space on this device to import \(problem.fileCount) files (about \(StorageCheck.formatted(problem.bytesNeeded)) needed). Free up space, or offload some files to your Mac.")
                } onOK: {
                    importer.spaceProblem = nil
                }
            } else if let summary = importer.summary {
                MessageCard(title: "Import Complete") {
                    VStack(spacing: 8) {
                        if summary.unreadable > 0 {
                            Text("Imported: \(summary.imported) · Skipped: \(summary.skipped) · Couldn't read: \(summary.unreadable)")
                        } else {
                            Text("Imported: \(summary.imported) · Skipped: \(summary.skipped)")
                        }
                        if summary.restoredFromMac > 0 {
                            Text("Full files brought back from the Mac: \(summary.restoredFromMac)")
                        }
                        if summary.updated > 0 {
                            Text("Updated: \(summary.updated). The older versions were moved to Recently Replaced (gear icon on Home) for 30 days.")
                        }
                    }
                } onOK: {
                    importer.summary = nil
                }
            } else if importer.isImporting {
                ProgressView("Importing files…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .animation(.easeOut(duration: 0.15), value: isShowingSomething)
    }

    private var isShowingSomething: Bool {
        importer.isImporting || importer.conflict != nil || importer.summary != nil || importer.spaceProblem != nil
    }
}

/// The choices for one incoming file whose name is already taken.
/// There is never a plain "replace" choice.
struct NameConflictCard: View {
    let conflict: ImportManager.Conflict
    let importer: ImportManager

    @State private var newName = ""
    @State private var typedNameTaken = false
    @State private var applyToAll = false
    @State private var showingNewerWarning = false

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
        .alert("Update Anyway?", isPresented: $showingNewerWarning) {
            Button("Update Anyway") {
                importer.resolveConflict(.update, applyToAll: false)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The copy on this device was changed more recently. Update anyway?")
        }
        .frame(maxWidth: 440)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(24)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Name Conflict")
                .font(.title3.bold())

            Text("A file named \"\(conflict.incomingName)\" already exists on this device. What would you like to do with the incoming file?")

            Button {
                importer.resolveConflict(.useSuggested, applyToAll: applyToAll)
            } label: {
                Text("Use \"\(conflict.suggestedName)\"")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if conflict.canUpdate {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        if conflict.deviceCopyIsNewer {
                            showingNewerWarning = true
                        } else {
                            importer.resolveConflict(.update, applyToAll: false)
                        }
                    } label: {
                        Text("Update This File")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Text("This is the same file, sent from one of your devices. Update replaces the copy here with it; the current version goes to Recently Replaced for 30 days.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Or enter a new name:")
                    .font(.subheadline)
                TextField("New name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit(useTypedName)
                    .onChange(of: newName) { typedNameTaken = false }
                if typedNameTaken {
                    Text("That name is also taken. Please try another.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                Button("Use This Name", action: useTypedName)
                    .buttonStyle(.bordered)
                    .disabled(trimmedNewName.isEmpty)
            }

            if conflict.canApplyToAll {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Do this for all remaining conflicts", isOn: $applyToAll)
                    Text("Applies to the suggested name and Skip.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Button("Skip This File") {
                    importer.resolveConflict(.skip, applyToAll: applyToAll)
                }
                Spacer()
                Button("Cancel Transfer", role: .destructive) {
                    importer.resolveConflict(.cancelTransfer, applyToAll: false)
                }
            }
        }
        .padding(20)
    }

    private var trimmedNewName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func useTypedName() {
        guard !trimmedNewName.isEmpty else { return }
        if importer.isNameAvailable(trimmedNewName) {
            importer.resolveConflict(.useName(trimmedNewName), applyToAll: false)
        } else {
            typedNameTaken = true
        }
    }
}

/// A simple message with an OK button.
private struct MessageCard<Message: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let message: Message
    let onOK: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text(title)
                .font(.headline)
            message
                .multilineTextAlignment(.center)
            Button("OK", action: onOK)
                .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(24)
    }
}
