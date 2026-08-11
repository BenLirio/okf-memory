import PhotosUI
import SwiftUI

struct CaptureView: View {
    @StateObject private var recorder = AudioRecorder()
    @State private var photoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var note = ""
    @State private var showCamera = false
    @State private var busy = false
    @State private var result: CaptureResponse?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Voice") {
                    Button {
                        toggleRecording()
                    } label: {
                        Label(recorder.isRecording ? "Stop & Save Memory" : "Record a Voice Note",
                              systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.title3)
                            .foregroundStyle(recorder.isRecording ? .red : .accentColor)
                    }
                    .disabled(busy)
                }
                Section("Photo") {
                    Button { showCamera = true } label: { Label("Take a Photo", systemImage: "camera") }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                    }
                    if let imageData, let ui = UIImage(data: imageData) {
                        Image(uiImage: ui).resizable().scaledToFit().frame(maxHeight: 200)
                    }
                }
                Section("Optional note") {
                    TextField("Add context…", text: $note, axis: .vertical).lineLimit(2...5)
                }
                if imageData != nil || !note.isEmpty {
                    Button { Task { await submit(fileData: imageData, filename: "photo.jpg", mime: "image/jpeg") } }
                        label: { Label("Save Memory", systemImage: "square.and.arrow.down") }
                        .disabled(busy)
                }
                if busy { Section { HStack { ProgressView(); Text("Thinking…") } } }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                if let result { resultSection(result) }
            }
            .navigationTitle("Capture")
            .sheet(isPresented: $showCamera) { CameraPicker { imageData = $0 } }
            .onChange(of: photoItem) {
                Task { imageData = try? await photoItem?.loadTransferable(type: Data.self) }
            }
        }
    }

    private func resultSection(_ r: CaptureResponse) -> some View {
        Section("Saved") {
            if let t = r.transcript { Text("“\(t)”").italic().foregroundStyle(.secondary) }
            Text(r.log_entry)
            ForEach(r.memories, id: \.path) { m in
                Label(m.frontmatter["title"]?.stringValue ?? m.path, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    private func toggleRecording() {
        if recorder.isRecording {
            guard let data = recorder.stop() else { return }
            Task { await submit(fileData: data, filename: "note.m4a", mime: "audio/m4a") }
        } else {
            error = nil; result = nil
            try? recorder.start()
        }
    }

    private func submit(fileData: Data?, filename: String?, mime: String?) async {
        busy = true; error = nil; result = nil
        defer { busy = false }
        do {
            let r = try await API.shared.capture(fileData: fileData, filename: filename,
                                                 mime: mime, text: note.isEmpty ? nil : note)
            result = r
            note = ""; imageData = nil; photoItem = nil
            await NotificationSync.sync()
        } catch { self.error = error.localizedDescription }
    }
}
