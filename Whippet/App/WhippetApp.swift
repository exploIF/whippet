import SwiftUI

@main
struct WhippetApp: App {
    @State private var model = AppModel()
    @State private var explainer = ImpactExplainer()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environment(model)
                .environment(explainer)
        } label: {
            Image("MenuBarIcon")
        }
        .menuBarExtraStyle(.window)
    }
}
