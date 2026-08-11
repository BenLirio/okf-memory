import AVFoundation
import SwiftUI

struct AskView: View {
    @StateObject private var recorder = AudioRecorder()
    @State private var typed = ""
    @State private var busy = false
    @State private var response: QueryResponse?
    @State private var error: String?
    @State private var player: AVAudioPlayer?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                if let response {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(response.question).font(.subheadline).foregroundStyle(.secondary).italic()
                            Text(response.answer).font(.body)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    Button { replay() } label: { Label("Play Again", systemImage: "speaker.wave.2") }
                }
                if busy { ProgressView("Thinking…") }
                if let error { Text(error).foregroundStyle(.red).font(.footnote).padding(.horizontal) }
                Spacer()
                Button { toggle() } label: {
                    Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 88))
                        .foregroundStyle(recorder.isRecording ? .red : .accentColor)
                        .symbolEffect(.pulse, isActive: recorder.isRecording)
                }
                .disabled(busy)
                Text(recorder.isRecording ? "Listening… tap to ask" : "Tap and ask about your memories")
                    .font(.footnote).foregroundStyle(.secondary)
                HStack {
                    TextField("…or type a question", text: $typed)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await ask(audio: nil, text: typed) } }
                    Button("Ask") { Task { await ask(audio: nil, text: typed) } }
                        .disabled(typed.isEmpty || busy)
                }
                .padding([.horizontal, .bottom])
            }
            .navigationTitle("Ask")
        }
    }

    private func toggle() {
        if recorder.isRecording {
            guard let data = recorder.stop() else { return }
            Task { await ask(audio: data, text: nil) }
        } else {
            error = nil
            try? recorder.start()
        }
    }

    private func ask(audio: Data?, text: String?) async {
        busy = true; error = nil
        defer { busy = false }
        do {
            let r = try await API.shared.query(audioData: audio, text: text)
            response = r
            typed = ""
            if let data = Data(base64Encoded: r.audio_b64) {
                try? AVAudioSession.sharedInstance().setCategory(.playback)
                player = try? AVAudioPlayer(data: data)
                player?.play()
            }
        } catch { self.error = error.localizedDescription }
    }

    private func replay() { player?.currentTime = 0; player?.play() }
}
