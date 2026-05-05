import IronSource
import SwiftUI

struct AppLovinSdkInitView: View {
    private let customUserId = LocalCredentials.testUserId

    var body: some View {
        List {
			NavigationLink("Custom User ID", destination: AppLovinView(customUserId: LocalCredentials.testUserId))
			NavigationLink("No User ID", destination: AppLovinView())
        }
        .navigationTitle("Init the SDK")
    }
}
