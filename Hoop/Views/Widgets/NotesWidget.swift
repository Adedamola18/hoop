import AppKit
import SwiftUI

struct NotesWidgetView: View {
    @State private var currentNote: String = ""
    @State private var recentNotes: [SavedNote] = NotesStorage.load()

    struct SavedNote: Identifiable, Codable {
        let id: UUID
        let text: String
        let timestamp: Date

        init(text: String) {
            self.id = UUID()
            self.text = text
            self.timestamp = Date()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "note.text")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Text("Quick Note")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            }

            // Text input
            HStack(spacing: 6) {
                TextField("Type a note...", text: $currentNote)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.06)))
                    .onSubmit {
                        saveNote()
                    }

                Button {
                    saveNote()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(currentNote.isEmpty ? .white.opacity(0.2) : .blue)
                }
                .buttonStyle(.plain)
                .disabled(currentNote.isEmpty)
            }

            // Recent notes
            if !recentNotes.isEmpty {
                ForEach(recentNotes.prefix(3)) { note in
                    noteRow(note)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.06))
        )
    }

    private func noteRow(_ note: SavedNote) -> some View {
        HStack(spacing: 6) {
            Text(note.text)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(note.text, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private func saveNote() {
        guard !currentNote.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let note = SavedNote(text: currentNote)
        recentNotes.insert(note, at: 0)
        if recentNotes.count > 20 {
            recentNotes.removeLast()
        }
        NotesStorage.save(recentNotes)
        // Copy to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(currentNote, forType: .string)
        currentNote = ""
    }
}

enum NotesStorage {
    private static let key = "notesWidgetHistory"

    static func save(_ notes: [NotesWidgetView.SavedNote]) {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> [NotesWidgetView.SavedNote] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let notes = try? JSONDecoder().decode([NotesWidgetView.SavedNote].self, from: data) else {
            return []
        }
        return notes
    }
}

// MARK: - Widget Conformance

final class NotesNotchWidget: NotchWidget {
    let id = "notes"
    let name = "Notes"
    let icon = "note.text"
    let size: WidgetSize = .large

    @MainActor
    func makeBody() -> AnyView {
        AnyView(NotesWidgetView())
    }
}
