import BackgroundTasks
import SwiftUI

@main
struct RecallApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TabView {
                MemoriesView().tabItem { Label("Memories", systemImage: "brain") }
                CaptureView().tabItem { Label("Capture", systemImage: "plus.circle.fill") }
                AskView().tabItem { Label("Ask", systemImage: "waveform.circle") }
            }
            // Match the Memory Web's sci-fi HUD: deep-space dark, cyan accent.
            .preferredColorScheme(.dark)
            .tint(Color(red: 0.31, green: 0.84, blue: 0.95))
            .task {
                await NotificationSync.requestPermission()
                await NotificationSync.sync()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active: Task { await NotificationSync.sync() }
                case .background: AppDelegate.scheduleRefresh()
                default: break
                }
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    static let refreshID = "com.benlirio.recall.refresh"

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshID, using: nil) { task in
            Self.scheduleRefresh()
            Task {
                await NotificationSync.sync()
                task.setTaskCompleted(success: true)
            }
        }
        return true
    }

    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
