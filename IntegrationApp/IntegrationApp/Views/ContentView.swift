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
                    NavigationLink("ironSource", destination: IronSourceSdkInitView())
                    NavigationLink("Firebase", destination: FirebaseView())
                    NavigationLink("Facebook", destination: FacebookView())
                    NavigationLink("UnityAds", destination: UnityAdsView())
                    NavigationLink("Google ODM", destination: GoogleOdmView())
                }
            }
            .navigationBarTitle("Integrations")
        }
    }
}
