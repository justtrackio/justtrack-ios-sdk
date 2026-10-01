import SwiftUI

var rootVC: UIViewController {
    (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController ?? UIViewController()
}

struct ContentView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: SectionHeaderView("External")) {
                    NavigationLink("AppLovin", destination: AppLovinSdkInitView())
                    NavigationLink("ironSource", destination: IronSourceView())
                    NavigationLink("Firebase", destination: FirebaseView())
                    NavigationLink("UnityAds", destination: UnityAdsView())
                    NavigationLink("Google ODM", destination: GoogleOdmView())
                }
            }
            .navigationBarTitle("Integrations")
        }
    }
}
