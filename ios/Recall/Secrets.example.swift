// Copy into Sources/Secrets.swift (gitignored). scripts/deploy-ios.sh generates it
// automatically from server/.env.
import Foundation

enum Secrets {
    static let serverURL = URL(string: "https://your-machine.your-tailnet.ts.net:8443")!
    static let apiToken = "matching API_TOKEN from server/.env"
}
