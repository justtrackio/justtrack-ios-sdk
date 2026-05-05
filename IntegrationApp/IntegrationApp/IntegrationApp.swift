import GoogleAdsOnDeviceConversion
import SwiftUI

@main
struct IntegrationAppApp: App {
    init() {
        setupODMFirstLaunchTime()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func setupODMFirstLaunchTime() {
        let firstLaunchKey = "io.justtrack.firstLaunchTime"
        let defaults = UserDefaults.standard

        if defaults.object(forKey: firstLaunchKey) == nil {
            let now = Date()
            defaults.set(now, forKey: firstLaunchKey)
            ConversionManager.sharedInstance.setFirstLaunchTime(now)
            print("[IntegrationApp] Set ODM first launch time: \(now)")
        } else if let storedDate = defaults.object(forKey: firstLaunchKey) as? Date {
            ConversionManager.sharedInstance.setFirstLaunchTime(storedDate)
            print("[IntegrationApp] Restored ODM first launch time: \(storedDate)")
        }
    }
}
