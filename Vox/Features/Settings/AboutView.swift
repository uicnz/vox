import ComposableArchitecture
import Inject
import Sparkle
import SwiftUI

struct AboutView: View {
    @ObserveInjection var inject
    @Bindable var store: StoreOf<SettingsFeature>
    @State var viewModel = CheckForUpdatesViewModel.shared

    var body: some View {
        Form {
            Section {
                HStack {
                    Label("Version", systemImage: "info.circle")
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
                    Button("Check for Updates") {
                        viewModel.checkForUpdates()
                    }
                    .buttonStyle(.bordered)
                }
                HStack {
                    Label("Vox is open source", systemImage: "apple.terminal.on.rectangle")
                    Spacer()
                    Link("Visit our GitHub", destination: URL(string: "https://github.com/uicnz/vox/")!)
                }
                
                HStack {
                    Label("Support the developer", systemImage: "heart")
                    Spacer()
                    Link("Become a Sponsor", destination: URL(string: "https://github.com/sponsors/shaneholloman")!)
                }
            }
        }
        .formStyle(.grouped)
        .enableInjection()
    }
}
