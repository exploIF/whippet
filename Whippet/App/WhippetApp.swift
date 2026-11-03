import SwiftUI

@main
struct WhippetApp: App {
    @State private var settings: SettingsStore
    @State private var model: AppModel
    @State private var explainer = ImpactExplainer()

    init() {
        let settings = SettingsStore()
        _settings = State(initialValue: settings)
        _model = State(initialValue: AppModel(settings: settings))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environment(model)
                .environment(explainer)
        } label: {
            Image("MenuBarIcon")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(settings)
        }
    }
}
