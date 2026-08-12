import SwiftUI

/// The Memories tab is the Memory Web itself — the server's 3D galaxy view.
/// Search, filtering, and the detail sheet all live inside the web page.
struct MemoriesView: View {
    var body: some View {
        GraphView()
            .ignoresSafeArea()
            .background(Color(red: 0.027, green: 0.031, blue: 0.055)) // #07080e
    }
}
