import IronSource
import SwiftUI

struct IronSourceSdkInitView: View {
    var body: some View {
        List {
			NavigationLink("Custom User ID", destination: IronSourceView(customUserId: LocalCredentials.testUserId))
            NavigationLink("No User ID", destination: IronSourceView())
        }
        .navigationTitle("Init the SDK")
    }
}
